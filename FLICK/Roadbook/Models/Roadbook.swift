import Foundation
import SwiftUI

/// 路书模型，表示一个完整的路书项目
struct Roadbook: Identifiable {
    /// 唯一标识符
    var id: UUID
    /// 路书名称
    var name: String
    /// 创建日期
    var creationDate: Date
    /// 最后修改日期
    var modificationDate: Date
    /// 相关项目ID（可选）
    var projectId: UUID?
    /// 路书照片数组
    var photos: [RoadbookPhoto]
    /// 备注信息
    var notes: String
    
    /// 初始化一个新的路书
    /// - Parameters:
    ///   - id: 唯一标识符，默认为新生成的UUID
    ///   - name: 路书名称
    ///   - projectId: 相关项目ID（可选）
    ///   - photos: 初始照片数组，默认为空
    ///   - notes: 备注信息，默认为空
    init(
        id: UUID = UUID(),
        name: String,
        projectId: UUID? = nil,
        photos: [RoadbookPhoto] = [],
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.creationDate = Date()
        self.modificationDate = Date()
        self.projectId = projectId
        self.photos = photos
        self.notes = notes
    }
    
    /// 添加照片到路书
    /// - Parameter photo: 要添加的照片
    mutating func addPhoto(_ photo: RoadbookPhoto) {
        var newPhoto = photo
        // 设置序号为当前照片数量
        newPhoto.orderIndex = photos.count
        photos.append(newPhoto)
        modificationDate = Date()
    }
    
    /// 移除指定索引的照片
    /// - Parameter index: 照片索引
    mutating func removePhoto(at index: Int) {
        guard index >= 0 && index < photos.count else { return }
        photos.remove(at: index)
        
        // 更新剩余照片的序号
        for i in index..<photos.count {
            photos[i].orderIndex = i
        }
        
        modificationDate = Date()
    }
    
    /// 更新照片
    /// - Parameters:
    ///   - photo: 更新后的照片
    ///   - index: 照片索引
    mutating func updatePhoto(_ photo: RoadbookPhoto, at index: Int) {
        guard index >= 0 && index < photos.count else { return }
        photos[index] = photo
        modificationDate = Date()
    }
    
    /// 移动照片位置
    /// - Parameters:
    ///   - fromIndex: 原始索引
    ///   - toIndex: 目标索引
    mutating func movePhoto(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < photos.count,
              toIndex >= 0 && toIndex < photos.count else { return }
        
        let photo = photos.remove(at: fromIndex)
        photos.insert(photo, at: toIndex)
        
        // 更新所有照片的序号
        for i in 0..<photos.count {
            photos[i].orderIndex = i
        }
        
        modificationDate = Date()
    }
    
    /// 获取照片数量
    var photoCount: Int {
        return photos.count
    }
    
    /// 获取路书创建时间的格式化字符串
    var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: creationDate)
    }
    
    /// 获取路书修改时间的格式化字符串
    var formattedModificationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: modificationDate)
    }
} 