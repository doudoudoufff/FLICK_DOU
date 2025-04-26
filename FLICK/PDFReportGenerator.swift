import UIKit
import PDFKit

class PDFReportGenerator {
    // MARK: - 属性
    let project: Project
    let location: Location?
    let title: String
    let footerText: String
    let photos: [(Location, LocationPhoto)]?
    
    // 新增LOGO属性
    var logoImage: UIImage?
    
    // PDF 设置 - 横版A4
    private let pageWidth: CGFloat = 841.8  // A4 高度 (72dpi) - 横版时为宽度
    private let pageHeight: CGFloat = 595.2 // A4 宽度 (72dpi) - 横版时为高度
    private let margin: CGFloat = 50
    private let contentWidth: CGFloat
    private let headerHeight: CGFloat = 80
    private let photoWidth: CGFloat = 250     // 调整照片宽度
    private let photoHeight: CGFloat = 400    // 调整照片高度
    private let photosPerRow: Int = 3         // 每行3张照片
    private let photoSpacing: CGFloat = 30    // 照片之间的间距
    private let noteHeight: CGFloat = 60      // 备注区域高度
    private let photoBlockHeight: CGFloat = 500  // 照片块的总高度
    private let spacing: CGFloat = 15
    private let timelineWidth: CGFloat = 2
    private let timelineDotRadius: CGFloat = 6
    private let timelineLeftMargin: CGFloat = 100 // 时间线左侧的边距
    private let compressionQuality: CGFloat = 0.3 // 保持低压缩质量以减小文件大小
    private let footerHeight: CGFloat = 40    // 页脚高度
    private let noteSpacing: CGFloat = 20     // 备注区域与页脚之间的间距
    
    // 颜色和样式
    private let primaryColor: UIColor
    private let secondaryColor: UIColor
    private let backgroundColor: UIColor = UIColor(white: 0.97, alpha: 1.0)
    
    // MARK: - 初始化
    init(project: Project, location: Location, logoImage: UIImage? = nil) {
        self.project = project
        self.location = location
        self.photos = nil
        self.title = "\(project.name) - \(location.name) 场景报告"
        self.footerText = "生成日期: \(Date().formatted(date: .long, time: .shortened))"
        self.contentWidth = pageWidth - (margin * 2)
        self.logoImage = logoImage
        
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
    
    // 添加支持多个场景照片的初始化方法
    init(project: Project, date: Date, photos: [(Location, LocationPhoto)], logoImage: UIImage? = nil) {
        self.project = project
        self.location = nil
        self.photos = photos
        self.title = "\(project.name) 堪景报告"
        self.footerText = "生成日期: \(Date().formatted(date: .long, time: .shortened))"
        self.contentWidth = pageWidth - (margin * 2)
        self.logoImage = logoImage
        
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
    func generatePDF() -> (Data?, String) {
        print("开始生成PDF报告...")
        
        do {
            // 防御性检查
            guard project.name.count > 0 else {
                print("项目名称为空，无法生成报告")
                return (nil, "")
            }
            
            if let location = location, location.name.isEmpty {
                print("场景名称为空，无法生成报告")
                return (nil, "")
            }
            
            // 生成文件名
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateStr = dateFormatter.string(from: Date())
            
            // 替换所有非字母数字为下划线
            func sanitize(_ str: String) -> String {
                return str.replacingOccurrences(of: "[^\\u4e00-\\u9fa5A-Za-z0-9]", with: "_", options: .regularExpression)
            }
            
            let sanitizedProjectName = sanitize(project.name)
            let locationName = location?.name ?? "全部场景"
            let sanitizedLocationName = sanitize(locationName)
            
            let fileName: String
            if let _ = location {
                fileName = "\(sanitizedProjectName)_\(sanitizedLocationName)_\(dateStr).pdf"
            } else {
                fileName = "\(sanitizedProjectName)_堪景报告_\(dateStr).pdf"
            }
            
            // 设置 PDF 元数据，Title 用 fileName
            let pdfMetaData = [
                kCGPDFContextCreator: "FLICK",
                kCGPDFContextAuthor: "FLICK",
                kCGPDFContextTitle: fileName,
                kCGPDFContextSubject: "场景报告",
                kCGPDFContextKeywords: "场景,照片,报告,\(project.name),\(location?.name ?? "")"
            ]
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = pdfMetaData as [String: Any]
            
            // 安全的PDF边界
            let safeBounds = CGRect(x: 0, y: 0, width: min(pageWidth, 2000), height: min(pageHeight, 2000))
            
            let renderer = UIGraphicsPDFRenderer(
                bounds: safeBounds,
                format: format
            )
            
            print("PDF配置完成，开始渲染...")
            
            // 使用 try/catch 包裹 PDF 渲染过程
            let pdfData = try renderer.pdfData { context in
                // 添加封面
                autoreleasepool {
                    addCoverPage(context: context)
                }
                
                // 处理单个场景报告
                if let location = location {
                    // 使用自动释放池管理内存
                    autoreleasepool {
                        // 按时间排序场景的照片
                        let sortedPhotos = location.photos.sorted { $0.date < $1.date }
                        
                        if sortedPhotos.isEmpty {
                            // 开始内容页面
                            context.beginPage()
                            
                            // 添加页面标题
                            addHeader(to: context, text: title)
                            
                            // 如果没有照片，显示提示信息
                            let noPhotoText = "该场景没有照片"
                            let font = UIFont.systemFont(ofSize: 16)
                            let attributes = [
                                NSAttributedString.Key.font: font,
                                NSAttributedString.Key.foregroundColor: UIColor.darkGray
                            ]
                            
                            let textSize = noPhotoText.size(withAttributes: attributes)
                            let textRect = CGRect(
                                x: (pageWidth - textSize.width) / 2,
                                y: (pageHeight - textSize.height) / 2,
                                width: textSize.width,
                                height: textSize.height
                            )
                            
                            noPhotoText.draw(in: textRect, withAttributes: attributes)
                            
                            // 添加页脚
                            addFooter(to: context, pageNumber: 1, totalPages: 1)
                        } else {
                            print("正在处理 \(sortedPhotos.count) 张照片...")
                            // 添加照片网格
                            addPhotoGrid(to: context, photos: sortedPhotos)
                        }
                    }
                } 
                // 处理多个场景的报告
                else if let photos = photos, !photos.isEmpty {
                    // 使用自动释放池管理内存
                    autoreleasepool {
                        // 创建按场景分组的照片字典
                        let photosByLocation = Dictionary(grouping: photos) { $0.0 }
                        
                        if photosByLocation.isEmpty {
                            // 开始内容页面
                            context.beginPage()
                            
                            // 添加页面标题
                            addHeader(to: context, text: title)
                            
                            // 如果没有照片，显示提示信息
                            let noPhotoText = "没有可用的照片"
                            let font = UIFont.systemFont(ofSize: 16)
                            let attributes = [
                                NSAttributedString.Key.font: font,
                                NSAttributedString.Key.foregroundColor: UIColor.darkGray
                            ]
                            
                            let textSize = noPhotoText.size(withAttributes: attributes)
                            let textRect = CGRect(
                                x: (pageWidth - textSize.width) / 2,
                                y: (pageHeight - textSize.height) / 2,
                                width: textSize.width,
                                height: textSize.height
                            )
                            
                            noPhotoText.draw(in: textRect, withAttributes: attributes)
                            
                            // 添加页脚
                            addFooter(to: context, pageNumber: 1, totalPages: 1)
                        } else {
                            // 开始内容页面
                            context.beginPage()
                            
                            // 添加页面标题
                            addHeader(to: context, text: title)
                            
                            var yPosition = margin + headerHeight
                            
                            // 添加项目概述
                            let summaryTitle = "项目概述"
                            let summaryTitleFont = UIFont.boldSystemFont(ofSize: 18)
                            let summaryTitleAttributes = [
                                NSAttributedString.Key.font: summaryTitleFont,
                                NSAttributedString.Key.foregroundColor: UIColor.black
                            ]
                            
                            let summaryTitleSize = summaryTitle.size(withAttributes: summaryTitleAttributes)
                            let summaryTitleRect = CGRect(
                                x: margin,
                                y: yPosition,
                                width: contentWidth,
                                height: summaryTitleSize.height
                            )
                            
                            summaryTitle.draw(in: summaryTitleRect, withAttributes: summaryTitleAttributes)
                            yPosition += summaryTitleSize.height + spacing
                            
                            // 添加项目信息
                            let projectInfoText = """
                            项目名称: \(project.name)
                            导演: \(project.director)
                            制片人: \(project.producer)
                            场景数量: \(photosByLocation.count)
                            照片总数: \(photos.count)
                            """
                            
                            let infoFont = UIFont.systemFont(ofSize: 14)
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.lineSpacing = 8
                            
                            let infoAttributes = [
                                NSAttributedString.Key.font: infoFont,
                                NSAttributedString.Key.foregroundColor: UIColor.black,
                                NSAttributedString.Key.paragraphStyle: paragraphStyle
                            ]
                            
                            let infoHeight = projectInfoText.boundingRect(
                                with: CGSize(width: contentWidth, height: 1000),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: infoAttributes,
                                context: nil
                            ).height
                            
                            let infoRect = CGRect(
                                x: margin,
                                y: yPosition,
                                width: contentWidth,
                                height: infoHeight
                            )
                            
                            projectInfoText.draw(in: infoRect, withAttributes: infoAttributes)
                            
                            // 添加页脚
                            addFooter(to: context, pageNumber: 1, totalPages: 1)
                            
                            // 为每个场景处理照片，使用单独的自动释放池
                            for (index, (location, locationPhotos)) in photosByLocation.enumerated() {
                                autoreleasepool {
                                    let locationTitle = "\(location.name) - \(location.address)"
                                    
                                    // 按时间排序照片并准备数据结构
                                    let sortedLocationPhotos = locationPhotos.sorted { $0.1.date < $1.1.date }
                                    // 我们需要将元组数组中的照片提取出来，只传递 LocationPhoto 对象
                                    let photosOnly = sortedLocationPhotos.map { $0.1 }
                                    
                                    // 添加照片网格
                                    addPhotoGrid(to: context, photos: photosOnly, locationTitle: locationTitle)
                                }
                            }
                        }
                    }
                }
            }
            
            print("PDF生成完成，总大小：\(pdfData.count / 1024) KB")
            return (pdfData, fileName)
        } catch {
            print("PDF生成过程中发生错误: \(error.localizedDescription)")
            return (nil, "")
        }
    }
    
    // MARK: - 照片网格
    private func addPhotoGrid(to context: UIGraphicsPDFRendererContext, photos: [LocationPhoto], locationTitle: String? = nil) {
        // 计算照片的总页数 - 每页3张照片
        let photosPerPage = photosPerRow  // 每页1行3张
        let pageCount = Int(ceil(Double(photos.count) / Double(photosPerPage)))
        
        for pageIndex in 0..<pageCount {
            autoreleasepool {
                // 开始新页面
                context.beginPage()
                
                // 添加页面标题
                if let locationTitle = locationTitle {
                    addHeader(to: context, text: "\(title) - \(locationTitle)")
                } else {
                    addHeader(to: context, text: title)
                }
                
                // 计算本页的照片索引范围
                let startIndex = pageIndex * photosPerPage
                let endIndex = min(startIndex + photosPerPage - 1, photos.count - 1)
                
                // 计算一行照片加备注的总高度
                let rowHeight = photoHeight + noteHeight + 20 // 照片高度 + 备注高度 + 间距
                
                // 计算可用空间（页面高度减去页眉和页脚）
                let availableHeight = pageHeight - headerHeight - footerHeight
                
                // 计算起始Y坐标，使内容垂直居中
                let startY = headerHeight + (availableHeight - rowHeight) / 2
                
                // 计算照片布局 - 水平居中显示
                let totalWidth = CGFloat(photosPerRow) * photoWidth + CGFloat(photosPerRow - 1) * photoSpacing
                let startX = (pageWidth - totalWidth) / 2
                
                // 处理本页照片
                for photoIndex in startIndex...endIndex {
                    autoreleasepool {
                        let photo = photos[photoIndex]
                        let col = (photoIndex - startIndex) % photosPerRow
                        
                        let x = startX + CGFloat(col) * (photoWidth + photoSpacing)
                        let y = startY  // 所有照片都在同一行
                        
                        // 绘制照片
                        if let image = photo.image {
                            // 创建照片容器
                            let photoRect = CGRect(x: x, y: y, width: photoWidth, height: photoHeight)
                            
                            // 计算缩放比例并居中显示
                            let imageAspectRatio = image.size.width / image.size.height
                            let containerAspectRatio = photoWidth / photoHeight
                            
                            var drawWidth: CGFloat
                            var drawHeight: CGFloat
                            var xOffset: CGFloat
                            var yOffset: CGFloat
                            
                            if imageAspectRatio > containerAspectRatio {
                                // 横向图片，以宽度为准
                                drawWidth = photoWidth
                                drawHeight = photoWidth / imageAspectRatio
                                xOffset = 0
                                yOffset = (photoHeight - drawHeight) / 2
                            } else {
                                // 纵向图片，以高度为准
                                drawHeight = photoHeight
                                drawWidth = photoHeight * imageAspectRatio
                                xOffset = (photoWidth - drawWidth) / 2
                                yOffset = 0
                            }
                            
                            // 绘制照片背景
                            context.cgContext.setFillColor(UIColor.white.cgColor)
                            context.cgContext.fill(photoRect)
                            
                            // 绘制照片
                            if let compressedImage = compressImage(image, quality: compressionQuality) {
                                let drawRect = CGRect(
                                    x: x + xOffset,
                                    y: y + yOffset,
                                    width: drawWidth,
                                    height: drawHeight
                                )
                                compressedImage.draw(in: drawRect)
                            }
                            
                            // 绘制照片编号和时间
                            let timeText = photo.date.formatted(date: .abbreviated, time: .shortened)
                            let indexText = "\(photoIndex + 1). \(timeText)"
                            let indexFont = UIFont.boldSystemFont(ofSize: 12)
                            let indexAttributes = [
                                NSAttributedString.Key.font: indexFont,
                                NSAttributedString.Key.foregroundColor: primaryColor
                            ]
                            
                            // 调整备注区域的位置
                            if let note = photo.note, !note.isEmpty {
                                // 绘制时间和编号
                                indexText.draw(
                                    at: CGPoint(x: x + 5, y: y + photoHeight + 15),
                                    withAttributes: indexAttributes
                                )
                                
                                let noteFont = UIFont.systemFont(ofSize: 11)
                                let noteParagraphStyle = NSMutableParagraphStyle()
                                noteParagraphStyle.lineBreakMode = .byTruncatingTail
                                noteParagraphStyle.lineSpacing = 2
                                
                                let noteAttributes = [
                                    NSAttributedString.Key.font: noteFont,
                                    NSAttributedString.Key.foregroundColor: UIColor.darkGray,
                                    NSAttributedString.Key.paragraphStyle: noteParagraphStyle
                                ]
                                
                                let noteText = "备注: \(note)"
                                let noteRect = CGRect(
                                    x: x + 5,
                                    y: y + photoHeight + 35,
                                    width: photoWidth - 10,
                                    height: noteHeight - 30
                                )
                                
                                noteText.draw(in: noteRect, withAttributes: noteAttributes)
                            } else {
                                // 如果没有备注，只显示时间和编号
                                let indexText = "\(photoIndex + 1). \(timeText)"
                                indexText.draw(
                                    at: CGPoint(x: x + 5, y: y + photoHeight + 15),
                                    withAttributes: indexAttributes
                                )
                            }
                        }
                    }
                }
                
                // 添加页脚
                addFooter(to: context, pageNumber: pageIndex + 1, totalPages: pageCount)
            }
        }
    }
    
    // MARK: - 工具方法
    private func compressImage(_ inputImage: UIImage, quality: CGFloat) -> UIImage? {
        // 检查图像尺寸，如果太大则进一步缩小
        let maxDimension: CGFloat = 800 // 限制图片最大尺寸
        var processedImage = inputImage
        
        if inputImage.size.width > maxDimension || inputImage.size.height > maxDimension {
            let scale = maxDimension / max(inputImage.size.width, inputImage.size.height)
            let newSize = CGSize(width: inputImage.size.width * scale, height: inputImage.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
            inputImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resizedImage
            }
            UIGraphicsEndImageContext()
        }
        
        // 使用较低质量压缩JPEG
        let actualQuality = min(quality, 0.4) // 限制最大质量
        guard let imageData = processedImage.jpegData(compressionQuality: actualQuality) else {
            print("无法压缩图像数据")
            return nil
        }
        
        // 如果图像数据太大，尝试进一步降低质量
        if imageData.count > 300000 { // 如果大于300KB
            // 尝试更低的质量
            let lowerQuality = actualQuality * 0.7
            if let furtherCompressedData = processedImage.jpegData(compressionQuality: lowerQuality) {
                return UIImage(data: furtherCompressedData)
            }
        }
        
        return UIImage(data: imageData)
    }
    
    // MARK: - 页面元素
    private func addCoverPage(context: UIGraphicsPDFRendererContext) {
        // 在PDF上下文中进行绘制
        context.beginPage()
        
        // 背景 - 使用context的CGContext进行绘制
        let cgContext = context.cgContext
        cgContext.setFillColor(UIColor.white.cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        // 绘制顶部横幅
        cgContext.setFillColor(primaryColor.cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 60))
        
        // 标题
        let titleText = title
        let titleFont = UIFont.boldSystemFont(ofSize: 34)
        let titleAttributes = [
            NSAttributedString.Key.font: titleFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: margin,
            y: 100,
            width: contentWidth,
            height: titleSize.height
        )
        
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        
        // 日期
        let dateText = Date().formatted(date: .long, time: .omitted)
        let dateFont = UIFont.systemFont(ofSize: 20)
        let dateAttributes = [
            NSAttributedString.Key.font: dateFont,
            NSAttributedString.Key.foregroundColor: UIColor.darkGray
        ]
        
        let dateSize = dateText.size(withAttributes: dateAttributes)
        let dateRect = CGRect(
            x: margin,
            y: 100 + titleSize.height + 20,
            width: contentWidth,
            height: dateSize.height
        )
        
        dateText.draw(in: dateRect, withAttributes: dateAttributes)
        
        // 项目信息
        let infoY = 100 + titleSize.height + dateSize.height + 60
        let infoTitleText = "项目信息"
        let infoTitleFont = UIFont.boldSystemFont(ofSize: 20)
        let infoTitleAttributes = [
            NSAttributedString.Key.font: infoTitleFont,
            NSAttributedString.Key.foregroundColor: primaryColor
        ]
        
        let infoTitleRect = CGRect(
            x: margin,
            y: infoY,
            width: contentWidth,
            height: 30
        )
        
        infoTitleText.draw(in: infoTitleRect, withAttributes: infoTitleAttributes)
        
        // 信息详情
        let infoItems = [
            "项目名称: \(project.name)",
            "导演: \(project.director)",
            "制片人: \(project.producer)",
            "项目开始日期: \(project.startDate.formatted(date: .long, time: .omitted))"
        ]
        
        let infoFont = UIFont.systemFont(ofSize: 16)
        let infoAttributes = [
            NSAttributedString.Key.font: infoFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        var itemY = infoY + 40
        
        for item in infoItems {
            let itemRect = CGRect(
                x: margin + 20,
                y: itemY,
                width: contentWidth - 40,
                height: 25
            )
            
            item.draw(in: itemRect, withAttributes: infoAttributes)
            itemY += 30
        }
        
        // 如果是单个场景报告，添加场景信息
        if let location = location {
            let locationY = itemY + 20
            let locationTitleText = "场景信息"
            
            let locationTitleRect = CGRect(
                x: margin,
                y: locationY,
                width: contentWidth,
                height: 30
            )
            
            locationTitleText.draw(in: locationTitleRect, withAttributes: infoTitleAttributes)
            
            let locationItems = [
                "场景名称: \(location.name)",
                "场景类型: \(location.type.rawValue)",
                "地址: \(location.address)"
            ]
            
            var locationItemY = locationY + 40
            
            for item in locationItems {
                let itemRect = CGRect(
                    x: margin + 20,
                    y: locationItemY,
                    width: contentWidth - 40,
                    height: 25
                )
                
                item.draw(in: itemRect, withAttributes: infoAttributes)
                locationItemY += 30
            }
        }
        
        // 绘制LOGO
        let logoSize: CGFloat = 60
        let logoRect = CGRect(
            x: pageWidth - margin - logoSize,
            y: pageHeight - margin - logoSize,
            width: logoSize,
            height: logoSize
        )
        if let logo = logoImage, let cgImage = logo.cgImage {
            context.cgContext.saveGState()
            // 平移到logo中心
            context.cgContext.translateBy(x: logoRect.midX, y: logoRect.midY)
            // 旋转180度
            context.cgContext.rotate(by: .pi)
            // 平移回左上角
            context.cgContext.translateBy(x: -logoRect.midX, y: -logoRect.midY)
            // 绘制logo
            context.cgContext.draw(cgImage, in: logoRect)
            context.cgContext.restoreGState()
        }
    }
    
    private func drawLogo(in context: UIGraphicsPDFRendererContext, at rect: CGRect) {
        if let logo = logoImage {
            context.cgContext.saveGState()
            // 计算logo的实际绘制尺寸，保持宽高比
            let scale = min(rect.width / logo.size.width, rect.height / logo.size.height)
            let drawWidth = logo.size.width * scale
            let drawHeight = logo.size.height * scale
            // 计算logo目标区域
            let logoRect = CGRect(
                x: rect.origin.x + (rect.width - drawWidth) / 2,
                y: rect.origin.y + (rect.height - drawHeight) / 2,
                width: drawWidth,
                height: drawHeight
            )
            // 绘制带有背景的矩形
            let path = UIBezierPath(rect: CGRect(
                x: logoRect.origin.x - 10,
                y: logoRect.origin.y - 10,
                width: logoRect.width + 20,
                height: logoRect.height + 20
            ))
            UIColor.white.setFill()
            path.fill()
            // 无论 orientation，强制生成 .up 的 UIImage
            UIGraphicsBeginImageContextWithOptions(logo.size, false, logo.scale)
            logo.draw(in: CGRect(origin: .zero, size: logo.size))
            let fixedLogo = UIGraphicsGetImageFromCurrentImageContext() ?? logo
            UIGraphicsEndImageContext()
            if let fixedCGImage = fixedLogo.cgImage {
                context.cgContext.draw(fixedCGImage, in: logoRect)
            }
            context.cgContext.restoreGState()
        } else {
            // 如果没有logo，绘制默认文字
            let logoText = "FLICK"
            let logoFont = UIFont.boldSystemFont(ofSize: 24)
            let logoAttributes = [
                NSAttributedString.Key.font: logoFont,
                NSAttributedString.Key.foregroundColor: primaryColor
            ]
            let logoTextSize = logoText.size(withAttributes: logoAttributes)
            let x = rect.origin.x + (rect.width - logoTextSize.width) / 2
            let y = rect.origin.y + (rect.height - logoTextSize.height) / 2
            let path = UIBezierPath(rect: CGRect(
                x: x - 10,
                y: y - 10,
                width: logoTextSize.width + 20,
                height: logoTextSize.height + 20
            ))
            UIColor.white.setFill()
            path.fill()
            logoText.draw(at: CGPoint(x: x, y: y), withAttributes: logoAttributes)
        }
    }
    
    private func addHeader(to context: UIGraphicsPDFRendererContext, text: String) {
        // 获取CGContext
        let cgContext = context.cgContext
        
        // 绘制顶部头部区域
        cgContext.setFillColor(primaryColor.withAlphaComponent(0.1).cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 60))
        
        // 绘制页眉文本
        let headerFont = UIFont.boldSystemFont(ofSize: 16)
        let headerAttributes = [
            NSAttributedString.Key.font: headerFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let headerTextSize = text.size(withAttributes: headerAttributes)
        let headerTextRect = CGRect(
            x: margin,
            y: (60 - headerTextSize.height) / 2,
            width: contentWidth - 100, // 为LOGO留出空间
            height: headerTextSize.height
        )
        
        text.draw(in: headerTextRect, withAttributes: headerAttributes)
        
        // 绘制小型LOGO（正方形，直接旋转180度）
        let logoSize: CGFloat = 30
        let logoRect = CGRect(
            x: pageWidth - margin - logoSize - 10,
            y: 15,
            width: logoSize,
            height: logoSize
        )
        
        if let logo = logoImage, let cgImage = logo.cgImage {
            context.cgContext.saveGState()
            // 平移到logo中心
            context.cgContext.translateBy(x: logoRect.midX, y: logoRect.midY)
            // 旋转180度
            context.cgContext.rotate(by: .pi)
            // 平移回左上角
            context.cgContext.translateBy(x: -logoRect.midX, y: -logoRect.midY)
            // 绘制旋转后的logo
            context.cgContext.draw(cgImage, in: logoRect)
            context.cgContext.restoreGState()
        }
    }
    
    private func addFooter(to context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int) {
        // 绘制底部页脚区域
        context.cgContext.setFillColor(primaryColor.withAlphaComponent(0.1).cgColor)
        context.cgContext.fill(CGRect(x: 0, y: pageHeight - footerHeight, width: pageWidth, height: footerHeight))
        
        // 绘制页码文本
        let footerText = "第 \(pageNumber) 页，共 \(totalPages) 页"
        let footerFont = UIFont.systemFont(ofSize: 12)
        let footerAttributes = [
            NSAttributedString.Key.font: footerFont,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        
        let footerTextSize = footerText.size(withAttributes: footerAttributes)
        let footerTextRect = CGRect(
            x: (pageWidth - footerTextSize.width) / 2,
            y: pageHeight - footerHeight + (footerHeight - footerTextSize.height) / 2,
            width: footerTextSize.width,
            height: footerTextSize.height
        )
        
        footerText.draw(in: footerTextRect, withAttributes: footerAttributes)
    }
} 