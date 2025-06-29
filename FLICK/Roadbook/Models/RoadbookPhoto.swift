import Foundation
import SwiftUI
import CoreGraphics

/// 路书照片模型，表示路书中的单张照片及其编辑状态
struct RoadbookPhoto: Identifiable {
    /// 唯一标识符
    var id: UUID
    /// 拍摄日期
    var captureDate: Date
    /// 原始图片数据
    var originalImageData: Data?
    /// 编辑后的图片数据（如果有）
    var editedImageData: Data?
    /// 绘制的标记数据
    var drawingData: [DrawingElement]
    /// 照片备注
    var note: String
    /// 在路书中的序号
    var orderIndex: Int
    /// 照片位置信息（可选）
    var location: PhotoLocation?
    /// 缩略图数据（可选）
    var thumbnailData: Data?
    
    /// 初始化一个新的路书照片
    /// - Parameters:
    ///   - id: 唯一标识符，默认为新生成的UUID
    ///   - image: 原始UIImage
    ///   - note: 照片备注，默认为空
    ///   - orderIndex: 在路书中的序号，默认为0
    ///   - location: 照片位置信息，默认为nil
    init(
        id: UUID = UUID(),
        image: UIImage,
        note: String = "",
        orderIndex: Int = 0,
        location: PhotoLocation? = nil
    ) {
        self.id = id
        self.captureDate = Date()
        
        // 压缩图片数据
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            self.originalImageData = imageData
        } else {
            // 如果JPEG压缩失败，尝试PNG格式（虽然文件会更大）
            self.originalImageData = image.pngData()
        }
        
        // 先初始化其他必需的属性
        self.drawingData = []
        self.note = note
        self.orderIndex = orderIndex
        self.location = location
        
        // 生成缩略图（在所有必需属性初始化后）
        self.thumbnailData = RoadbookPhoto.generateThumbnail(from: image)
    }
    
    /// 获取原始图片
    var originalImage: UIImage? {
        if let data = originalImageData {
            return UIImage(data: data)
        }
        return nil
    }
    
    /// 获取编辑后的图片
    var editedImage: UIImage? {
        if let data = editedImageData {
            return UIImage(data: data)
        }
        return nil
    }
    
    /// 获取缩略图
    var thumbnail: UIImage? {
        if let data = thumbnailData {
            return UIImage(data: data)
        }
        return nil
    }
    
    /// 获取显示图片（优先使用编辑后的图片，如果没有则使用原始图片）
    var displayImage: UIImage? {
        if let editedImageData = editedImageData, let image = UIImage(data: editedImageData) {
            return image
        }
        return originalImage
    }
    
    /// 添加绘制元素
    /// - Parameter element: 要添加的绘制元素
    mutating func addDrawingElement(_ element: DrawingElement) {
        drawingData.append(element)
    }
    
    /// 清除所有绘制元素
    mutating func clearDrawing() {
        drawingData.removeAll()
        editedImageData = nil
    }
    
    /// 更新编辑后的图片
    /// - Parameter image: 编辑后的图片
    mutating func updateEditedImage(_ image: UIImage) {
        editedImageData = image.jpegData(compressionQuality: 0.8)
    }
    
    /// 获取拍摄时间的格式化字符串
    var formattedCaptureDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: captureDate)
    }
    
    /// 生成缩略图
    /// - Parameter image: 原始图片
    /// - Returns: 缩略图数据
    static func generateThumbnail(from image: UIImage) -> Data? {
        // 定义缩略图尺寸
        let maxDimension: CGFloat = 300
        
        // 计算缩放比例
        let originalSize = image.size
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let scale = min(widthRatio, heightRatio)
        
        // 如果图片已经小于目标尺寸，不需要缩放
        if scale >= 1.0 {
            return image.jpegData(compressionQuality: 0.7)
        }
        
        // 计算新尺寸
        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // 创建缩略图
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // 压缩为JPEG
        return thumbnailImage.jpegData(compressionQuality: 0.7)
    }
}

/// 照片位置信息
struct PhotoLocation: Codable {
    /// 纬度
    var latitude: Double
    /// 经度
    var longitude: Double
    /// 地址描述（可选）
    var address: String?
}

/// 绘制元素类型
enum DrawingElementType: String, Codable {
    case line
    case arrow
    case text
    case rectangle
    case ellipse
}

/// 绘制元素基类
struct DrawingElement: Identifiable, Codable {
    /// 唯一标识符
    var id: UUID
    /// 元素类型
    var type: DrawingElementType
    /// 线条颜色（十六进制表示）
    var color: String
    /// 线条宽度
    var lineWidth: CGFloat
    /// 点数组（存储绘制路径的点）
    var points: [CGPoint]
    /// 文本内容（用于文本元素）
    var text: String?
    
    /// 编码自定义类型
    enum CodingKeys: String, CodingKey {
        case id, type, color, lineWidth, points, text
    }
    
    /// 自定义编码方法，处理CGPoint等类型
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(color, forKey: .color)
        try container.encode(lineWidth, forKey: .lineWidth)
        try container.encode(text, forKey: .text)
        
        // 编码CGPoint数组
        var pointsArray: [[CGFloat]] = []
        for point in points {
            pointsArray.append([point.x, point.y])
        }
        try container.encode(pointsArray, forKey: .points)
    }
    
    /// 自定义解码方法，处理CGPoint等类型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try DrawingElementType(rawValue: container.decode(String.self, forKey: .type)) ?? .line
        color = try container.decode(String.self, forKey: .color)
        lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        
        // 解码CGPoint数组
        let pointsArray = try container.decode([[CGFloat]].self, forKey: .points)
        points = pointsArray.map { CGPoint(x: $0[0], y: $0[1]) }
    }
    
    /// 标准初始化方法
    init(
        id: UUID = UUID(),
        type: DrawingElementType,
        color: String,
        lineWidth: CGFloat,
        points: [CGPoint] = [],
        text: String? = nil
    ) {
        self.id = id
        self.type = type
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.text = text
    }
} 