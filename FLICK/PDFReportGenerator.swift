import UIKit
import PDFKit

class PDFReportGenerator {
    // MARK: - 属性
    let project: Project
    let date: Date
    let photos: [(Location, LocationPhoto)]
    let title: String
    let footerText: String
    
    // PDF 设置
    private let pageWidth: CGFloat = 595.2  // A4 宽度 (72dpi)
    private let pageHeight: CGFloat = 841.8 // A4 高度 (72dpi)
    private let margin: CGFloat = 50
    private let contentWidth: CGFloat
    private let headerHeight: CGFloat = 80
    private let photoSize: CGFloat = 250
    private let spacing: CGFloat = 15
    private let timelineWidth: CGFloat = 2
    private let timelineDotRadius: CGFloat = 6
    private let timelineLeftMargin: CGFloat = 100 // 时间线左侧的边距
    private let compressionQuality: CGFloat = 0.7 // 图片压缩质量
    private let maxImageWidth: CGFloat = 400 // 图片最大宽度
    
    // 颜色和样式
    private let primaryColor: UIColor
    private let secondaryColor: UIColor
    private let backgroundColor: UIColor = UIColor(white: 0.97, alpha: 1.0)
    
    // MARK: - 初始化
    init(project: Project, date: Date, photos: [(Location, LocationPhoto)]) {
        self.project = project
        self.date = date
        self.photos = photos
        self.title = "\(project.name) - 堪景报告"
        self.footerText = "生成日期: \(Date().formatted(date: .long, time: .shortened))"
        self.contentWidth = pageWidth - (margin * 2)
        
        // 使用项目颜色作为主题色
        if let cgColor = project.color.cgColor {
            self.primaryColor = UIColor(cgColor: cgColor)
        } else {
            self.primaryColor = .systemBlue
        }
        
        // 设置次要颜色
        self.secondaryColor = UIColor(red: primaryColor.cgColor.components?[0] ?? 0.0,
                                     green: primaryColor.cgColor.components?[1] ?? 0.0,
                                     blue: primaryColor.cgColor.components?[2] ?? 0.0,
                                     alpha: 0.6)
    }
    
    // MARK: - 生成 PDF
    func generatePDF() -> Data? {
        print("开始生成PDF报告...")
        
        // 创建PDF文档
        let pdfMetaData = [
            kCGPDFContextCreator: "FLICK",
            kCGPDFContextAuthor: "FLICK",
            kCGPDFContextTitle: title,
            kCGPDFContextSubject: "堪景报告",
            kCGPDFContextKeywords: "堪景,照片,报告,\(project.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        print("PDF配置完成，开始渲染...")
        
        let pdfData = renderer.pdfData { context in
            // 添加封面
            addCoverPage(context: context)
            
            // 开始内容页面
            context.beginPage()
            
            // 添加页面标题
            addHeader(to: context, text: title)
            
            // 按时间排序照片
            let sortedPhotos = photos.sorted { $0.1.date < $1.1.date }
            var yPosition: CGFloat = margin + headerHeight
            
            if sortedPhotos.isEmpty {
                // 如果没有照片，显示提示信息
                let noPhotoText = "该日期没有堪景照片"
                let font = UIFont.systemFont(ofSize: 16)
                let attributes = [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: UIColor.darkGray
                ]
                
                let textSize = noPhotoText.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (pageWidth - textSize.width) / 2,
                    y: yPosition + CGFloat(50),
                    width: textSize.width,
                    height: textSize.height
                )
                
                noPhotoText.draw(in: textRect, withAttributes: attributes)
            } else {
                print("正在处理 \(sortedPhotos.count) 张照片...")
                // 添加照片时间线
                yPosition = addTimelineContent(to: context, photos: sortedPhotos, startY: yPosition)
            }
            
            // 添加页脚
            addFooter(to: context, text: footerText)
        }
        
        print("PDF生成完成，总大小：\(pdfData.count / 1024) KB")
        return pdfData
    }
    
    // MARK: - 时间线内容
    private func addTimelineContent(to context: UIGraphicsPDFRendererContext, photos: [(Location, LocationPhoto)], startY: CGFloat) -> CGFloat {
        var yPosition = startY
        let timelineX = margin + timelineLeftMargin
        var currentGroupTime: String?
        var isFirstGroup = true
        
        // 首先绘制日期标题
        let dateTitle = date.formatted(date: .long, time: .omitted)
        let dateTitleFont = UIFont.boldSystemFont(ofSize: 18)
        let dateTitleAttributes = [
            NSAttributedString.Key.font: dateTitleFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let dateTitleSize = dateTitle.size(withAttributes: dateTitleAttributes)
        let dateTitleRect = CGRect(
            x: margin,
            y: yPosition,
            width: contentWidth,
            height: dateTitleSize.height
        )
        
        dateTitle.draw(in: dateTitleRect, withAttributes: dateTitleAttributes)
        yPosition += dateTitleSize.height + spacing * 2
        
        // 添加时间线说明
        let timelineInfoText = "照片时间线（按时间先后顺序排列）"
        let timelineInfoFont = UIFont.italicSystemFont(ofSize: 12)
        let timelineInfoAttributes = [
            NSAttributedString.Key.font: timelineInfoFont,
            NSAttributedString.Key.foregroundColor: UIColor.darkGray
        ]
        
        let timelineInfoSize = timelineInfoText.size(withAttributes: timelineInfoAttributes)
        let timelineInfoRect = CGRect(
            x: margin,
            y: yPosition,
            width: contentWidth,
            height: timelineInfoSize.height
        )
        
        timelineInfoText.draw(in: timelineInfoRect, withAttributes: timelineInfoAttributes)
        yPosition += timelineInfoSize.height + spacing
        
        // 开始绘制时间线
        let timelinePath = UIBezierPath()
        var lastTimelineBottom: CGFloat = yPosition
        
        // 添加照片计数用于更紧凑的布局
        var photosInCurrentPage = 0
        let maxPhotosPerPage = 2 // 允许每页最多显示两张照片
        
        // 遍历每个照片
        for (index, (location, photo)) in photos.enumerated() {
            // 格式化当前照片的小时和分钟
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: photo.date)
            let minute = calendar.component(.minute, from: photo.date)
            let timeString = String(format: "%02d:%02d", hour, minute)
            
            // 预先计算这个照片项目所需的总高度
            var itemHeight: CGFloat = CGFloat(20) // 时间标题高度
            itemHeight += CGFloat(25) // 场地信息高度
            
            // 图片高度
            let photoHeight: CGFloat = 180
            itemHeight += photoHeight + CGFloat(15) // 照片高度加间距
            
            // 备注高度（如果有）
            if let note = photo.note, !note.isEmpty {
                let noteFont = UIFont.systemFont(ofSize: 11)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                paragraphStyle.lineSpacing = 1
                
                let noteAttributes = [
                    NSAttributedString.Key.font: noteFont,
                    NSAttributedString.Key.foregroundColor: UIColor.darkGray,
                    NSAttributedString.Key.paragraphStyle: paragraphStyle
                ]
                
                let maxNoteWidth = contentWidth - (timelineX - margin) - 60
                let noteHeight = note.boundingRect(
                    with: CGSize(width: maxNoteWidth, height: CGFloat.infinity),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: noteAttributes,
                    context: nil
                ).height
                
                itemHeight += noteHeight + CGFloat(50) // 备注高度加标题和足够间距
            } else {
                itemHeight += CGFloat(10) // 无备注的额外间距
            }
            
            itemHeight += spacing // 底部间距
            
            // 如果时间变化了，添加新的时间组
            if currentGroupTime != timeString || isFirstGroup {
                currentGroupTime = timeString
                isFirstGroup = false
                
                // 检查是否需要新页面 - 根据计算的项目高度决定
                // 注意：仅当页面剩余空间不足或已达到每页最大照片数时才创建新页面
                if yPosition + itemHeight > pageHeight - margin - CGFloat(60) || photosInCurrentPage >= maxPhotosPerPage {
                    // 绘制当前页时间线
                    primaryColor.setStroke()
                    timelinePath.lineWidth = timelineWidth
                    timelinePath.stroke()
                    
                    // 添加页脚
                    addFooter(to: context, text: footerText)
                    
                    // 创建新页面
                    context.beginPage()
                    photosInCurrentPage = 0 // 重置照片计数
                    yPosition = margin + headerHeight
                    
                    // 添加页面标题
                    addHeader(to: context, text: title)
                    
                    // 重置时间线起点
                    timelinePath.removeAllPoints()
                    timelinePath.move(to: CGPoint(x: timelineX, y: yPosition))
                    lastTimelineBottom = yPosition
                }
                
                // 添加时间标题
                let timeFont = UIFont.boldSystemFont(ofSize: 14)
                let timeAttributes = [
                    NSAttributedString.Key.font: timeFont,
                    NSAttributedString.Key.foregroundColor: primaryColor
                ]
                
                let timeRect = CGRect(
                    x: margin,
                    y: yPosition,
                    width: timelineX - margin - 20,
                    height: CGFloat(20)
                )
                
                timeString.draw(in: timeRect, withAttributes: timeAttributes)
            }
            
            // 添加时间线圆点
            let dotY = yPosition + CGFloat(10)
            let dotPath = UIBezierPath(arcCenter: CGPoint(x: timelineX, y: dotY),
                                       radius: timelineDotRadius,
                                       startAngle: 0,
                                       endAngle: CGFloat.pi * 2,
                                       clockwise: true)
            
            primaryColor.setFill()
            dotPath.fill()
            
            // 绘制时间线
            if index == 0 || timelinePath.isEmpty {
                timelinePath.move(to: CGPoint(x: timelineX, y: yPosition))
            }
            timelinePath.addLine(to: CGPoint(x: timelineX, y: dotY + timelineDotRadius))
            lastTimelineBottom = dotY + timelineDotRadius
            
            yPosition += CGFloat(20)
            
            // 添加场地信息
            let locationInfo = "场地: \(location.name)"
            let locationFont = UIFont.systemFont(ofSize: 12)
            let locationColor = UIColor.darkGray
            let locationAttributes = [
                NSAttributedString.Key.font: locationFont,
                NSAttributedString.Key.foregroundColor: locationColor
            ]
            
            let locationRect = CGRect(
                x: timelineX + 20,
                y: yPosition,
                width: contentWidth - (timelineX - margin) - 20,
                height: CGFloat(20)
            )
            
            locationInfo.draw(in: locationRect, withAttributes: locationAttributes)
            
            yPosition += CGFloat(25) // 场地信息后的间距
            
            // 添加照片 - 减小照片尺寸以实现更紧凑的布局
            if let image = photo.image {
                // 压缩图片并调整大小
                let compressedImage = compressImage(image, quality: compressionQuality)
                
                // 计算图片大小，保持纵横比，但更小以适应更多照片
                let photoHeight: CGFloat = 180 // 减小了照片高度
                let aspectRatio = compressedImage.size.width / compressedImage.size.height
                let photoWidth = min(photoHeight * aspectRatio, maxImageWidth)
                
                let imageRect = CGRect(
                    x: timelineX + 20,
                    y: yPosition,
                    width: min(photoWidth, contentWidth - (timelineX - margin) - 40),
                    height: photoHeight
                )
                
                // 添加图片背景和阴影效果
                let imageBackgroundRect = CGRect(
                    x: imageRect.minX - 4,
                    y: imageRect.minY - 4,
                    width: imageRect.width + 8,
                    height: imageRect.height + 8
                )
                
                // 绘制图片背景 - 增加了圆角和边框
                UIColor.white.setFill()
                let backgroundPath = UIBezierPath(roundedRect: imageBackgroundRect, cornerRadius: 8)
                backgroundPath.fill()
                
                // 绘制图片边框 - 使用主题颜色的浅色版本
                secondaryColor.withAlphaComponent(0.3).setStroke()
                backgroundPath.lineWidth = 1.0
                backgroundPath.stroke()
                
                // 绘制图片
                compressedImage.draw(in: imageRect)
                
                yPosition += photoHeight + CGFloat(15) // 增加了照片后的间距
                
                // 添加照片备注
                if let note = photo.note, !note.isEmpty {
                    // 创建带圆角和背景的备注框
                    let noteTitleFont = UIFont.boldSystemFont(ofSize: 11)
                    let noteTitleAttributes = [
                        NSAttributedString.Key.font: noteTitleFont,
                        NSAttributedString.Key.foregroundColor: primaryColor
                    ]
                    
                    let noteTitleRect = CGRect(
                        x: timelineX + 20,
                        y: yPosition,
                        width: contentWidth - (timelineX - margin) - 40,
                        height: CGFloat(15)
                    )
                    
                    "备注:".draw(in: noteTitleRect, withAttributes: noteTitleAttributes)
                    
                    yPosition += CGFloat(30) // 增加备注标题与内容之间的距离
                    
                    let noteFont = UIFont.systemFont(ofSize: 11)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineBreakMode = .byWordWrapping
                    paragraphStyle.lineSpacing = 2 // 略微增加行间距以提高可读性
                    
                    let noteAttributes = [
                        NSAttributedString.Key.font: noteFont,
                        NSAttributedString.Key.foregroundColor: UIColor.darkGray,
                        NSAttributedString.Key.paragraphStyle: paragraphStyle
                    ]
                    
                    // 计算文本高度
                    let maxNoteWidth = contentWidth - (timelineX - margin) - 60
                    let noteHeight = note.boundingRect(
                        with: CGSize(width: maxNoteWidth, height: CGFloat.infinity),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: noteAttributes,
                        context: nil
                    ).height
                    
                    // 更新备注框高度 - 增加额外的空间避免重叠
                    let noteBgRect = CGRect(
                        x: timelineX + 10,
                        y: yPosition - CGFloat(8),
                        width: contentWidth - (timelineX - margin) - 30,
                        height: noteHeight + CGFloat(16) // 增加填充空间
                    )
                    
                    // 绘制备注框背景
                    backgroundColor.setFill()
                    UIBezierPath(roundedRect: noteBgRect, cornerRadius: 6).fill()
                    
                    // 绘制文本
                    note.draw(
                        in: CGRect(x: noteBgRect.minX + 10, y: yPosition, width: maxNoteWidth, height: noteHeight),
                        withAttributes: noteAttributes
                    )
                    
                    yPosition += noteHeight + CGFloat(20) // 增加备注后的额外间距
                } else {
                    yPosition += CGFloat(10)
                }
                
                photosInCurrentPage += 1
            }
            
            // 添加间隔 - 确保元素不会重叠
            yPosition += spacing
            
            // 检查是否需要新页面 - 在照片绘制完成后再次检查
            if index < photos.count - 1 {
                // 获取下一个照片项目的预估高度
                var nextItemHeight: CGFloat = CGFloat(65) // 基本高度（时间标题、场地信息等）
                
                // 添加照片高度
                nextItemHeight += photoHeight + CGFloat(15)
                
                // 检查是否有足够空间展示下一张照片
                // 只有当页面剩余空间不足或已达到每页最大照片数时才创建新页面
                if (yPosition + nextItemHeight > pageHeight - margin - CGFloat(60)) || (photosInCurrentPage >= maxPhotosPerPage) {
                    // 绘制当前页时间线
                    primaryColor.setStroke()
                    timelinePath.lineWidth = timelineWidth
                    timelinePath.stroke()
                    
                    // 添加页脚
                    addFooter(to: context, text: footerText)
                    
                    // 创建新页面
                    context.beginPage()
                    photosInCurrentPage = 0 // 重置照片计数
                    yPosition = margin + headerHeight
                    
                    // 添加页面标题
                    addHeader(to: context, text: title)
                    
                    // 重新开始时间线
                    timelinePath.removeAllPoints()
                    timelinePath.move(to: CGPoint(x: timelineX, y: yPosition))
                    lastTimelineBottom = yPosition
                    
                    // 重置当前组时间，强制创建新的时间标题
                    currentGroupTime = nil
                }
            }
        }
        
        // 完成时间线绘制到页面底部
        timelinePath.addLine(to: CGPoint(x: timelineX, y: lastTimelineBottom + CGFloat(30)))
        primaryColor.setStroke()
        timelinePath.lineWidth = timelineWidth
        timelinePath.stroke()
        
        return yPosition
    }
    
    // MARK: - 辅助方法
    
    // 压缩图片
    private func compressImage(_ image: UIImage, quality: CGFloat) -> UIImage {
        guard let imageData = image.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: imageData) else {
            return image
        }
        
        // 限制图片大小
        let maxSize: CGFloat = 1200
        if compressedImage.size.width > maxSize || compressedImage.size.height > maxSize {
            let scale = maxSize / max(compressedImage.size.width, compressedImage.size.height)
            let newWidth = compressedImage.size.width * scale
            let newHeight = compressedImage.size.height * scale
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            compressedImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage ?? compressedImage
        }
        
        return compressedImage
    }
    
    // 在类的开头添加一个全局变量来跟踪页码
    private var currentPageNumber = 1
    
    // 添加封面页
    private func addCoverPage(context: UIGraphicsPDFRendererContext) {
        context.beginPage()
        currentPageNumber = 1  // 重置页码计数器
        
        // 绘制纯白色背景
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)).fill()
        
        // 顶部装饰条 - 使用纯色更符合示例
        let topGradientRect = CGRect(x: 0, y: 0, width: pageWidth, height: CGFloat(80))
        primaryColor.setFill()
        UIBezierPath(rect: topGradientRect).fill()
        
        // 在页面中部添加标题和内容
        let contentY = topGradientRect.maxY + 140
        
        // 标题
        let titleFont = UIFont.boldSystemFont(ofSize: 34)
        let titleAttributes = [
            NSAttributedString.Key.font: titleFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (pageWidth - titleSize.width) / 2,
            y: contentY,
            width: titleSize.width,
            height: titleSize.height
        )
        
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // 下划线 - 使用主色调
        let underlineRect = CGRect(
            x: (pageWidth - titleSize.width * 0.9) / 2,
            y: titleRect.maxY + 15,
            width: titleSize.width * 0.9,
            height: CGFloat(2)
        )
        primaryColor.setFill()
        UIBezierPath(rect: underlineRect).fill()
        
        // 日期
        let dateString = "日期: \(date.formatted(date: .complete, time: .omitted))"
        let dateFont = UIFont.systemFont(ofSize: 20)
        let dateAttributes = [
            NSAttributedString.Key.font: dateFont,
            NSAttributedString.Key.foregroundColor: UIColor.darkGray
        ]
        
        let dateSize = dateString.size(withAttributes: dateAttributes)
        let dateRect = CGRect(
            x: (pageWidth - dateSize.width) / 2,
            y: titleRect.maxY + 40,
            width: dateSize.width,
            height: dateSize.height
        )
        
        dateString.draw(in: dateRect, withAttributes: dateAttributes)
        
        // 项目信息框 - 使用简单明了的设计确保内容可见
        let infoBoxWidth: CGFloat = 350
        let infoBoxHeight: CGFloat = 160
        let infoBoxRect = CGRect(
            x: (pageWidth - infoBoxWidth) / 2,
            y: dateRect.maxY + 50,
            width: infoBoxWidth,
            height: infoBoxHeight
        )
        
        // 信息框使用灰色背景
        UIColor(white: 0.95, alpha: 1.0).setFill()
        let infoBoxPath = UIBezierPath(roundedRect: infoBoxRect, cornerRadius: 10)
        infoBoxPath.fill()
        
        // 项目信息标题
        let infoTitleFont = UIFont.boldSystemFont(ofSize: 16)
        let infoTitleAttributes = [
            NSAttributedString.Key.font: infoTitleFont,
            NSAttributedString.Key.foregroundColor: primaryColor
        ]
        
        let infoTitleRect = CGRect(
            x: infoBoxRect.minX + 20,
            y: infoBoxRect.minY + 15,
            width: infoBoxWidth - 40,
            height: CGFloat(20)
        )
        
        "项目详情".draw(in: infoTitleRect, withAttributes: infoTitleAttributes)
        
        // 项目信息内容 - 确保文字清晰可见
        let infoString = """
        项目名称: \(project.name)
        导演: \(project.director)
        制片: \(project.producer)
        项目状态: \(project.status.rawValue)
        照片数量: \(photos.count)
        """
        
        let infoFont = UIFont.systemFont(ofSize: 14)
        let infoParagraphStyle = NSMutableParagraphStyle()
        infoParagraphStyle.lineSpacing = 10
        
        let infoAttributes = [
            NSAttributedString.Key.font: infoFont,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.paragraphStyle: infoParagraphStyle
        ]
        
        let infoRect = CGRect(
            x: infoBoxRect.minX + 20,
            y: infoTitleRect.maxY + 10,
            width: infoBoxWidth - 40,
            height: infoBoxHeight - 50
        )
        
        // 确保内容绘制在最上层
        infoString.draw(in: infoRect, withAttributes: infoAttributes)
        
        // 添加FLICK标志
        let logoText = "FLICK"
        let logoFont = UIFont.boldSystemFont(ofSize: 20)
        let logoAttributes = [
            NSAttributedString.Key.font: logoFont,
            NSAttributedString.Key.foregroundColor: primaryColor
        ]
        
        let logoSize = logoText.size(withAttributes: logoAttributes)
        let logoRect = CGRect(
            x: (pageWidth - logoSize.width) / 2,
            y: pageHeight - CGFloat(120),
            width: logoSize.width,
            height: logoSize.height
        )
        
        logoText.draw(in: logoRect, withAttributes: logoAttributes)
        
        // 底部装饰条 - 使用纯色与顶部呼应
        let bottomGradientRect = CGRect(x: 0, y: pageHeight - CGFloat(50), width: pageWidth, height: CGFloat(50))
        primaryColor.setFill()
        UIBezierPath(rect: bottomGradientRect).fill()
    }
    
    // 添加页眉
    private func addHeader(to context: UIGraphicsPDFRendererContext, text: String) {
        let headerFont = UIFont.boldSystemFont(ofSize: 16)
        let headerAttributes = [
            NSAttributedString.Key.font: headerFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let headerRect = CGRect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: CGFloat(20)
        )
        
        text.draw(in: headerRect, withAttributes: headerAttributes)
        
        // 添加分隔线
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: margin + CGFloat(30)))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: margin + CGFloat(30)))
        primaryColor.setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()
    }
    
    // 添加页脚
    private func addFooter(to context: UIGraphicsPDFRendererContext, text: String) {
        addFooter(to: context, text: text, pageNumber: currentPageNumber)
        // 每次调用时增加页码计数
        currentPageNumber += 1
    }
    
    // 添加带有指定页码的页脚
    private func addFooter(to context: UIGraphicsPDFRendererContext, text: String, pageNumber: Int) {
        let footerFont = UIFont.systemFont(ofSize: 10)
        let footerAttributes = [
            NSAttributedString.Key.font: footerFont,
            NSAttributedString.Key.foregroundColor: UIColor.darkGray
        ]
        
        let footerText = "\(text) | 第 \(pageNumber) 页"
        
        let footerSize = footerText.size(withAttributes: footerAttributes)
        let footerRect = CGRect(
            x: (pageWidth - footerSize.width) / 2,
            y: pageHeight - margin,
            width: footerSize.width,
            height: footerSize.height
        )
        
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
        
        // 添加FLICK标志在页脚右侧
        let logoText = "FLICK"
        let logoAttributes = [
            NSAttributedString.Key.font: footerFont,
            NSAttributedString.Key.foregroundColor: secondaryColor
        ]
        
        let logoRect = CGRect(
            x: pageWidth - margin - 40,
            y: pageHeight - margin,
            width: 40,
            height: footerSize.height
        )
        
        logoText.draw(in: logoRect, withAttributes: logoAttributes)
    }
    
    // 按时间组织照片
    private func organizePhotosByTime() -> [(String, [(Location, LocationPhoto)])] {
        // 按照小时:分钟对照片进行分组
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: photos) { (location, photo) -> String in
            let hour = calendar.component(.hour, from: photo.date)
            let minute = calendar.component(.minute, from: photo.date)
            return String(format: "%02d:%02d", hour, minute)
        }
        
        // 按时间排序
        return grouped.sorted { $0.key < $1.key }
    }
} 