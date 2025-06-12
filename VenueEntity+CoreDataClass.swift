//
//  VenueEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/27.
//
//

import Foundation
import CoreData


public class VenueEntity: NSManagedObject {
    // 便利属性
    var wrappedName: String {
        name ?? "未命名场地"
    }
    
    var wrappedContactName: String {
        contactName ?? "未知"
    }
    
    var wrappedContactPhone: String {
        contactPhone ?? "未知"
    }
    
    var wrappedAddress: String {
        address ?? "未知"
    }
    
    var wrappedNotes: String {
        notes ?? ""
    }
    
    var wrappedType: String {
        type ?? "其他"
    }
    
    var wrappedDateAdded: Date {
        dateAdded ?? Date()
    }
    
    var attachmentsArray: [VenueAttachmentEntity] {
        let set = attachments as? Set<VenueAttachmentEntity> ?? []
        return set.sorted { $0.dateAdded ?? Date() < $1.dateAdded ?? Date() }
    }
}
