//
//  VenueAttachmentEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/27.
//
//

import Foundation
import CoreData


extension VenueAttachmentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VenueAttachmentEntity> {
        return NSFetchRequest<VenueAttachmentEntity>(entityName: "VenueAttachmentEntity")
    }

    @NSManaged public var data: Data?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var fileName: String?
    @NSManaged public var fileType: String?
    @NSManaged public var id: UUID?
    @NSManaged public var venue: VenueEntity?

}

extension VenueAttachmentEntity : Identifiable {

}
