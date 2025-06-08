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
    private let headerHeight: CGFloat = 60
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
    
    // 美化相关的新属性
    private let cardCornerRadius: CGFloat = 12      // 照片卡片圆角
    private let cardShadowRadius: CGFloat = 8       // 卡片阴影半径
    private let cardShadowOpacity: Float = 0.15     // 阴影透明度
    private let cardShadowOffset: CGSize = CGSize(width: 0, height: 4)  // 阴影偏移
    private let gradientHeight: CGFloat = 120       // 渐变背景高度
    
    // 颜色和样式 - 专业级配色方案
    private let primaryColor: UIColor
    private let secondaryColor: UIColor
    private let accentColor: UIColor
    private let backgroundColor: UIColor = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)  // 极简灰白
    private let cardBackgroundColor: UIColor = UIColor.white
    private let textColor: UIColor = UIColor(white: 0.15, alpha: 1.0)  // 深炭色文字
    private let subtleTextColor: UIColor = UIColor(white: 0.45, alpha: 1.0)  // 优雅灰色
    private let headerGradientStartColor: UIColor = UIColor(white: 0.98, alpha: 1.0)
    private let headerGradientEndColor: UIColor = UIColor(white: 0.95, alpha: 1.0)
    private let shadowColor: UIColor = UIColor(white: 0.0, alpha: 0.08)  // 微妙阴影
    
    // MARK: - 初始化
    init(project: Project, location: Location, logoImage: UIImage? = nil) {
        self.project = project
        self.location = location
        self.photos = nil
        self.title = "\(project.name) - \(location.name) 场景报告"
        self.footerText = "生成日期: \(Date().formatted(date: .long, time: .shortened))"
        self.contentWidth = pageWidth - (margin * 2)
        self.logoImage = logoImage
        
        // 使用项目颜色作为主题色，并创建配色方案
        if let cgColor = project.color.cgColor {
            self.primaryColor = UIColor(cgColor: cgColor)
        } else {
            self.primaryColor = .systemBlue
        }
        
        // 创建更丰富的配色方案
        let components = primaryColor.cgColor.components ?? [0.0, 0.0, 1.0, 1.0]
        let red = components[0]
        let green = components[1] 
        let blue = components[2]
        
        // 辅助色：主色的淡化版本
        self.secondaryColor = UIColor(red: red, green: green, blue: blue, alpha: 0.3)
        
        // 强调色：主色的饱和版本或互补色
        self.accentColor = UIColor(red: min(red * 1.2, 1.0), green: min(green * 1.1, 1.0), blue: min(blue * 0.9, 1.0), alpha: 1.0)
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
        
        // 使用项目颜色作为主题色，并创建配色方案
        if let cgColor = project.color.cgColor {
            self.primaryColor = UIColor(cgColor: cgColor)
        } else {
            self.primaryColor = .systemBlue
        }
        
        // 创建更丰富的配色方案
        let components = primaryColor.cgColor.components ?? [0.0, 0.0, 1.0, 1.0]
        let red = components[0]
        let green = components[1] 
        let blue = components[2]
        
        // 辅助色：主色的淡化版本
        self.secondaryColor = UIColor(red: red, green: green, blue: blue, alpha: 0.3)
        
        // 强调色：主色的饱和版本或互补色
        self.accentColor = UIColor(red: min(red * 1.2, 1.0), green: min(green * 1.1, 1.0), blue: min(blue * 0.9, 1.0), alpha: 1.0)
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
            dateFormatter.locale = Locale(identifier: "zh_CN")
            dateFormatter.dateFormat = "yyyy年M月d日 HH:mm"
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
                
                // 计算本页的照片索引范围
                let startIndex = pageIndex * photosPerPage
                let currentPhoto = photos[startIndex]
                
                // 添加页面标题 - 传递当前照片信息给页眉
                addHeader(to: context, text: title, currentPhoto: currentPhoto)
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
                            
                            // 绘制现代化照片卡片
                            let cgContext = context.cgContext
                            
                            // 绘制照片卡片背景和阴影
                            drawModernPhotoCard(in: context, rect: photoRect)
                            
                            // 绘制照片，添加圆角和间距
                            if let compressedImage = compressImage(image, quality: compressionQuality) {
                                let cardInset: CGFloat = 6  // 卡片内边距
                                let imageRect = CGRect(
                                    x: x + xOffset + cardInset,
                                    y: y + yOffset + cardInset,
                                    width: drawWidth - (cardInset * 2),
                                    height: drawHeight - (cardInset * 2)
                                )
                                
                                // 创建圆角蒙版
                                cgContext.saveGState()
                                let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: 4)
                                cgContext.addPath(imagePath.cgPath)
                                cgContext.clip()
                                
                                compressedImage.draw(in: imageRect)
                                cgContext.restoreGState()
                            }
                            
                            // 绘制现代化照片标签
                            let dateFormatter = DateFormatter()
                            dateFormatter.locale = Locale(identifier: "zh_CN")
                            dateFormatter.dateFormat = "MM/dd HH:mm"
                            let timeText = dateFormatter.string(from: photo.date)
                            
                            // 现代化编号标签
                            let indexNumber = photoIndex + 1
                            drawModernPhotoLabel(
                                in: context,
                                rect: CGRect(x: x, y: y + photoHeight + 8, width: photoWidth, height: 45),
                                indexNumber: indexNumber,
                                timeText: timeText,
                                note: photo.note
                            )
                        }
                    }
                }
                
                // 添加页脚
                addFooter(to: context, pageNumber: pageIndex + 1, totalPages: pageCount)
            }
        }
    }
    
    // MARK: - 美化辅助方法
    
    // 修正UIImage方向，确保logo在PDF中不倒置
    private func fixedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalizedImage
    }
    
    // 绘制现代化Logo容器
    private func drawModernLogoContainer(in context: UIGraphicsPDFRendererContext, rect: CGRect) {
        let cgContext = context.cgContext
        
        cgContext.saveGState()
        
        // 创建圆角矩形路径
        let cornerRadius: CGFloat = 8
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        
        // 绘制微妙的阴影
        cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: shadowColor.cgColor)
        
        // 绘制白色背景
        cgContext.setFillColor(UIColor.white.cgColor)
        cgContext.addPath(path.cgPath)
        cgContext.fillPath()
        
        cgContext.restoreGState()
        
        // 绘制精致的边框
        cgContext.setStrokeColor(UIColor(white: 0.9, alpha: 1.0).cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.addPath(path.cgPath)
        cgContext.strokePath()
    }
    
    // 绘制现代化照片卡片
    private func drawModernPhotoCard(in context: UIGraphicsPDFRendererContext, rect: CGRect) {
        let cgContext = context.cgContext
        
        cgContext.saveGState()
        
        // 创建圆角矩形路径
        let cornerRadius: CGFloat = 12
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        
        // 绘制卡片阴影
        cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: shadowColor.cgColor)
        
        // 绘制白色卡片背景
        cgContext.setFillColor(UIColor.white.cgColor)
        cgContext.addPath(path.cgPath)
        cgContext.fillPath()
        
        cgContext.restoreGState()
        
        // 绘制精致的边框
        cgContext.setStrokeColor(UIColor(white: 0.92, alpha: 1.0).cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.addPath(path.cgPath)
        cgContext.strokePath()
    }
    
    // 绘制现代化照片标签
    private func drawModernPhotoLabel(in context: UIGraphicsPDFRendererContext, rect: CGRect, indexNumber: Int, timeText: String, note: String?) {
        let cgContext = context.cgContext
        
        // 编号标签 - 现代圆形设计
        let numberSize: CGFloat = 24
        let numberRect = CGRect(
            x: rect.minX + 8,
            y: rect.minY + 2,
            width: numberSize,
            height: numberSize
        )
        
        // 绘制编号圆圈背景
        cgContext.saveGState()
        cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: shadowColor.cgColor)
        cgContext.setFillColor(primaryColor.cgColor)
        cgContext.addEllipse(in: numberRect)
        cgContext.fillPath()
        cgContext.restoreGState()
        
        // 绘制编号文字
        let numberText = "\(indexNumber)"
        let numberFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let numberAttributes = [
            NSAttributedString.Key.font: numberFont,
            NSAttributedString.Key.foregroundColor: UIColor.white
        ] as [NSAttributedString.Key : Any]
        
        let numberTextSize = numberText.size(withAttributes: numberAttributes)
        let numberTextRect = CGRect(
            x: numberRect.midX - numberTextSize.width / 2,
            y: numberRect.midY - numberTextSize.height / 2,
            width: numberTextSize.width,
            height: numberTextSize.height
        )
        numberText.draw(in: numberTextRect, withAttributes: numberAttributes)
        
        // 时间标签
        let timeFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let timeAttributes = [
            NSAttributedString.Key.font: timeFont,
            NSAttributedString.Key.foregroundColor: subtleTextColor,
            NSAttributedString.Key.kern: 0.2
        ] as [NSAttributedString.Key : Any]
        
        let timeRect = CGRect(
            x: rect.minX + numberSize + 15,
            y: rect.minY + 6,
            width: rect.width - numberSize - 25,
            height: 16
        )
        timeText.draw(in: timeRect, withAttributes: timeAttributes)
        
        // 备注（如果有）
        if let note = note, !note.isEmpty {
            let noteFont = UIFont.systemFont(ofSize: 10, weight: .regular)
            let noteParagraphStyle = NSMutableParagraphStyle()
            noteParagraphStyle.lineBreakMode = .byTruncatingTail
            
            let noteAttributes = [
                NSAttributedString.Key.font: noteFont,
                NSAttributedString.Key.foregroundColor: textColor,
                NSAttributedString.Key.paragraphStyle: noteParagraphStyle,
                NSAttributedString.Key.kern: 0.1
            ] as [NSAttributedString.Key : Any]
            
            let noteRect = CGRect(
                x: rect.minX + 8,
                y: rect.minY + 26,
                width: rect.width - 16,
                height: 15
            )
            
            let noteText = "💬 \(note)"
            noteText.draw(in: noteRect, withAttributes: noteAttributes)
        }
    }
    
    // 绘制带阴影的圆角卡片背景
    private func drawCardBackground(in context: UIGraphicsPDFRendererContext, rect: CGRect) {
        let cgContext = context.cgContext
        
        // 创建卡片路径
        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: cardCornerRadius)
        
        // 绘制阴影
        cgContext.saveGState()
        cgContext.setShadow(offset: cardShadowOffset, blur: cardShadowRadius, color: UIColor.black.withAlphaComponent(CGFloat(cardShadowOpacity)).cgColor)
        
        // 绘制卡片背景
        cgContext.setFillColor(cardBackgroundColor.cgColor)
        cgContext.addPath(cardPath.cgPath)
        cgContext.fillPath()
        
        cgContext.restoreGState()
        
        // 绘制卡片边框
        cgContext.setStrokeColor(secondaryColor.cgColor)
        cgContext.setLineWidth(1.0)
        cgContext.addPath(cardPath.cgPath)
        cgContext.strokePath()
    }
    
    // 绘制渐变背景
    private func drawGradientBackground(in context: UIGraphicsPDFRendererContext, rect: CGRect, startColor: UIColor, endColor: UIColor) {
        let cgContext = context.cgContext
        
        // 创建渐变
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [startColor.cgColor, endColor.cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
        
        cgContext.saveGState()
        cgContext.clip(to: rect)
        cgContext.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        cgContext.restoreGState()
    }
    
    // 绘制装饰性分割线
    private func drawDecorativeLine(in context: UIGraphicsPDFRendererContext, startPoint: CGPoint, endPoint: CGPoint, color: UIColor = UIColor.lightGray, lineWidth: CGFloat = 1.0) {
        let cgContext = context.cgContext
        
        cgContext.saveGState()
        cgContext.setStrokeColor(color.cgColor)
        cgContext.setLineWidth(lineWidth)
        cgContext.move(to: startPoint)
        cgContext.addLine(to: endPoint)
        cgContext.strokePath()
        cgContext.restoreGState()
    }
    
    // 绘制装饰性圆点
    private func drawDecorativeDot(in context: UIGraphicsPDFRendererContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        let cgContext = context.cgContext
        
        cgContext.saveGState()
        cgContext.setFillColor(color.cgColor)
        cgContext.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        cgContext.fillPath()
        cgContext.restoreGState()
    }
    
    // 绘制带图标的文字标签
    private func drawIconLabel(in context: UIGraphicsPDFRendererContext, text: String, icon: String, rect: CGRect, font: UIFont, textColor: UIColor, iconColor: UIColor) {
        // 这里可以绘制SF Symbols图标，不过PDF中比较复杂，我们用简单的图形代替
        let iconSize: CGFloat = font.pointSize
        let iconRect = CGRect(x: rect.minX, y: rect.minY, width: iconSize, height: iconSize)
        
        // 绘制简单的圆形图标
        let cgContext = context.cgContext
        cgContext.setFillColor(iconColor.cgColor)
        cgContext.addEllipse(in: iconRect)
        cgContext.fillPath()
        
        // 绘制文字
        let textRect = CGRect(x: rect.minX + iconSize + 8, y: rect.minY, width: rect.width - iconSize - 8, height: rect.height)
        let attributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor
        ]
        text.draw(in: textRect, withAttributes: attributes)
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
        
        let cgContext = context.cgContext
        
        // 简单的背景色
        cgContext.setFillColor(backgroundColor.cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        // 顶部简洁横幅
        let bannerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 80)
        cgContext.setFillColor(primaryColor.cgColor)
        cgContext.fill(bannerRect)
        
        // 主标题
        let titleText = title
        let titleFont = UIFont.boldSystemFont(ofSize: 36)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: titleFont,
            NSAttributedString.Key.foregroundColor: textColor
        ]
        
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: margin,
            y: 120,
            width: contentWidth,
            height: titleSize.height
        )
        
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        
        // 简单分割线
        let lineY = 120 + titleSize.height + 15
        cgContext.setStrokeColor(primaryColor.cgColor)
        cgContext.setLineWidth(2)
        cgContext.move(to: CGPoint(x: margin, y: lineY))
        cgContext.addLine(to: CGPoint(x: margin + 250, y: lineY))
        cgContext.strokePath()
        
        // 日期
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年M月d日 HH:mm"
        let dateText = "生成时间：\(dateFormatter.string(from: Date()))"
        let dateFont = UIFont.systemFont(ofSize: 16)
        let dateAttributes = [
            NSAttributedString.Key.font: dateFont,
            NSAttributedString.Key.foregroundColor: subtleTextColor
        ]
        
        let dateSize = dateText.size(withAttributes: dateAttributes)
        let dateRect = CGRect(
            x: margin,
            y: lineY + 25,
            width: contentWidth,
            height: dateSize.height
        )
        
        dateText.draw(in: dateRect, withAttributes: dateAttributes)
        
        // 项目信息
        let infoY = lineY + 70
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
            NSAttributedString.Key.foregroundColor: textColor
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
            let locationY = itemY + 30
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
        } else {
            // 默认LOGO
            let logoText = "FLICK"
            let logoFont = UIFont.boldSystemFont(ofSize: 24)
            let logoAttributes = [
                NSAttributedString.Key.font: logoFont,
                NSAttributedString.Key.foregroundColor: primaryColor
            ]
            let logoTextSize = logoText.size(withAttributes: logoAttributes)
            let logoTextRect = CGRect(
                x: logoRect.midX - logoTextSize.width / 2,
                y: logoRect.midY - logoTextSize.height / 2,
                width: logoTextSize.width,
                height: logoTextSize.height
            )
            logoText.draw(in: logoTextRect, withAttributes: logoAttributes)
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
    
    private func addHeader(to context: UIGraphicsPDFRendererContext, text: String, currentPhoto: LocationPhoto? = nil) {
        // 获取CGContext
        let cgContext = context.cgContext
        
        // 绘制现代化渐变背景
        let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: headerHeight)
        drawGradientBackground(in: context, rect: headerRect, startColor: headerGradientStartColor, endColor: headerGradientEndColor)
        
        // 添加微妙的底部阴影线
        cgContext.setStrokeColor(shadowColor.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: 0, y: headerHeight))
        cgContext.addLine(to: CGPoint(x: pageWidth, y: headerHeight))
        cgContext.strokePath()
        
        // Logo尺寸
        let logoSize: CGFloat = 40
        let logoMargin: CGFloat = 10
        
        // 左上角FLICK App logo
        let flickLogoRect = CGRect(
            x: margin,
            y: logoMargin+5,
            width: logoSize,
            height: logoSize
        )
        
        // 绘制FLICK App logo（使用Asset中的FLICKLogo）
        if let appLogoImage = UIImage(named: "FLICKLogo") {
            let fixedLogo = fixedImage(appLogoImage)
            if let cgImage = fixedLogo.cgImage {
                // 绘制现代化Logo容器
                drawModernLogoContainer(in: context, rect: flickLogoRect)
                // 翻转坐标系，确保logo方向正确
                cgContext.saveGState()
                cgContext.translateBy(x: flickLogoRect.midX, y: flickLogoRect.midY)
                cgContext.scaleBy(x: 1, y: -1)
                cgContext.translateBy(x: -flickLogoRect.midX, y: -flickLogoRect.midY)
                // 绘制logo，稍微缩小一点留出边距
                let logoInset: CGFloat = 4
                let logoContentRect = CGRect(
                    x: flickLogoRect.origin.x + logoInset,
                    y: flickLogoRect.origin.y + logoInset,
                    width: flickLogoRect.width - (logoInset * 2),
                    height: flickLogoRect.height - (logoInset * 2)
                )
                cgContext.draw(cgImage, in: logoContentRect)
                cgContext.restoreGState()
            }
        } else {
            // 如果找不到FLICKLogo，绘制现代化文字logo
            drawModernLogoContainer(in: context, rect: flickLogoRect)
            
            let flickLogoText = "FLICK"
            let flickLogoFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
            let flickLogoAttributes = [
                NSAttributedString.Key.font: flickLogoFont,
                NSAttributedString.Key.foregroundColor: primaryColor,
                NSAttributedString.Key.kern: 0.5  // 字母间距
            ] as [NSAttributedString.Key : Any]
            
            let flickLogoTextSize = flickLogoText.size(withAttributes: flickLogoAttributes)
            let flickLogoTextRect = CGRect(
                x: flickLogoRect.midX - flickLogoTextSize.width / 2,
                y: flickLogoRect.midY - flickLogoTextSize.height / 2,
                width: flickLogoTextSize.width,
                height: flickLogoTextSize.height
            )
            flickLogoText.draw(in: flickLogoTextRect, withAttributes: flickLogoAttributes)
        }
        
        // 右上角项目logo
        let projectLogoRect = CGRect(
            x: pageWidth - margin - logoSize,
            y: logoMargin,
            width: logoSize,
            height: logoSize
        )
        
        if let logo = logoImage, let cgImage = logo.cgImage {
            // 直接绘制项目logo，不加边框和背景（适合PNG透明logo）
            cgContext.saveGState()
            // 平移到logo中心
            cgContext.translateBy(x: projectLogoRect.midX, y: projectLogoRect.midY)
            // 旋转180度
            cgContext.rotate(by: .pi)
            // 平移回左上角
            cgContext.translateBy(x: -projectLogoRect.midX, y: -projectLogoRect.midY)
            // 绘制旋转后的logo
            cgContext.draw(cgImage, in: projectLogoRect)
            cgContext.restoreGState()
        }
        
        // 中间的两行文字区域
        let textStartX = margin + logoSize + 15
        let textWidth = pageWidth - (margin * 2) - (logoSize * 2) - 30 // 减去两个logo和间距
        
        // 解析文本内容，提取项目名称、场景名称和地址
        let projectName = project.name
        var locationName = ""
        var locationAddress = ""
        
        // 如果是单个场景报告
        if let location = location {
            locationName = location.name
            locationAddress = location.address
        } else if let currentPhoto = currentPhoto {
            // 如果是多场景报告，从当前照片的位置信息获取
            // 需要找到当前照片所属的位置
            if let photos = photos {
                for (photoLocation, photo) in photos {
                    if photo.id == currentPhoto.id {
                        locationName = photoLocation.name
                        locationAddress = photoLocation.address
                        break
                    }
                }
            }
        } else if let photos = photos, !photos.isEmpty {
            // 如果没有指定当前照片，从第一个照片获取信息
            let firstLocation = photos[0].0
            locationName = firstLocation.name
            locationAddress = firstLocation.address
        }
        
        // 第一行：项目名称-场景名称（现代化排版）
        let firstLineText = locationName.isEmpty ? projectName : "\(projectName) • \(locationName)"
        let firstLineFont = UIFont.systemFont(ofSize: 17, weight: .medium)
        let firstLineParagraphStyle = NSMutableParagraphStyle()
        firstLineParagraphStyle.lineBreakMode = .byTruncatingTail
        
        let firstLineAttributes = [
            NSAttributedString.Key.font: firstLineFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: firstLineParagraphStyle,
            NSAttributedString.Key.kern: 0.3  // 字母间距
        ] as [NSAttributedString.Key : Any]
        
        let firstLineRect = CGRect(
            x: textStartX,
            y: 12,
            width: textWidth,
            height: 28
        )
        
        firstLineText.draw(in: firstLineRect, withAttributes: firstLineAttributes)
        
        // 第二行：场景地址（优雅显示）
        if !locationAddress.isEmpty {
            let secondLineFont = UIFont.systemFont(ofSize: 13, weight: .regular)
            let secondLineParagraphStyle = NSMutableParagraphStyle()
            secondLineParagraphStyle.lineBreakMode = .byTruncatingTail
            
            let secondLineAttributes = [
                NSAttributedString.Key.font: secondLineFont,
                NSAttributedString.Key.foregroundColor: subtleTextColor,
                NSAttributedString.Key.paragraphStyle: secondLineParagraphStyle,
                NSAttributedString.Key.kern: 0.2
            ] as [NSAttributedString.Key : Any]
            
            // 添加图标前缀
            let locationIcon = "📍 "
            let fullLocationText = locationAddress
            
            let secondLineRect = CGRect(
                x: textStartX,
                y: 42,
                width: textWidth,
                height: 25
            )
            
            fullLocationText.draw(in: secondLineRect, withAttributes: secondLineAttributes)
        }
    }
    
    private func addFooter(to context: UIGraphicsPDFRendererContext, pageNumber: Int, totalPages: Int) {
        let cgContext = context.cgContext
        let footerRect = CGRect(x: 0, y: pageHeight - footerHeight, width: pageWidth, height: footerHeight)
        
        // 绘制现代化页脚背景渐变
        drawGradientBackground(in: context, rect: footerRect, startColor: headerGradientEndColor, endColor: headerGradientStartColor)
        
        // 添加顶部分割线
        cgContext.setStrokeColor(shadowColor.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: 0, y: pageHeight - footerHeight))
        cgContext.addLine(to: CGPoint(x: pageWidth, y: pageHeight - footerHeight))
        cgContext.strokePath()
        
        // 页码文本 - 现代化设计
        let footerText = "\(pageNumber) / \(totalPages)"
        let footerFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let footerAttributes = [
            NSAttributedString.Key.font: footerFont,
            NSAttributedString.Key.foregroundColor: subtleTextColor,
            NSAttributedString.Key.kern: 0.3
        ] as [NSAttributedString.Key : Any]
        
        let footerTextSize = footerText.size(withAttributes: footerAttributes)
        let footerTextRect = CGRect(
            x: (pageWidth - footerTextSize.width) / 2,
            y: pageHeight - footerHeight + (footerHeight - footerTextSize.height) / 2,
            width: footerTextSize.width,
            height: footerTextSize.height
        )
        
        footerText.draw(in: footerTextRect, withAttributes: footerAttributes)
        
        // 左下角版权信息
        let copyrightText = "© FLICK"
        let copyrightFont = UIFont.systemFont(ofSize: 9, weight: .light)
        let copyrightAttributes = [
            NSAttributedString.Key.font: copyrightFont,
            NSAttributedString.Key.foregroundColor: subtleTextColor
        ] as [NSAttributedString.Key : Any]
        
        let copyrightRect = CGRect(
            x: margin,
            y: pageHeight - footerHeight + (footerHeight - 12) / 2,
            width: 100,
            height: 12
        )
        
        copyrightText.draw(in: copyrightRect, withAttributes: copyrightAttributes)
        
        // 右下角生成时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        let dateText = dateFormatter.string(from: Date())
        
        let dateRect = CGRect(
            x: pageWidth - margin - 80,
            y: pageHeight - footerHeight + (footerHeight - 12) / 2,
            width: 80,
            height: 12
        )
        
        dateText.draw(in: dateRect, withAttributes: copyrightAttributes)
    }
} 


