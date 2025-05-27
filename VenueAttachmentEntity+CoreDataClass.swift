//
//  VenueAttachmentEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/27.
//
//

import Foundation
import CoreData
import SwiftUI

public class VenueAttachmentEntity: NSManagedObject {
    // 便利属性
    var wrappedFileName: String {
        fileName ?? "未命名文件"
    }
    
    var wrappedFileType: String {
        fileType ?? "unknown"
    }
    
    var wrappedDateAdded: Date {
        dateAdded ?? Date()
    }
    
    // 文件类型
    enum AttachmentType: String {
        case image = "image"
        case pdf = "pdf"
        case unknown = "unknown"
        
        var icon: String {
            switch self {
            case .image:
                return "photo"
            case .pdf:
                return "doc.text"
            case .unknown:
                return "questionmark.circle"
            }
        }
        
        var canPreview: Bool {
            self != .unknown
        }
    }
    
    var attachmentType: AttachmentType {
        guard let type = fileType else { return .unknown }
        return AttachmentType(rawValue: type) ?? .unknown
    }
    
    // 判断是否是图片
    var isImage: Bool {
        attachmentType == .image
    }
    
    // 判断是否是PDF
    var isPDF: Bool {
        attachmentType == .pdf
    }
    
    // 获取UIImage (如果是图片类型)
    var uiImage: UIImage? {
        guard let data = data, isImage else { return nil }
        return UIImage(data: data)
    }
    
    // 获取Image (SwiftUI)
    var image: Image? {
        guard let uiImage = uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
