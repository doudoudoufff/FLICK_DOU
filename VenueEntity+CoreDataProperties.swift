//
//  VenueEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/27.
//
//

import Foundation
import CoreData


extension VenueEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VenueEntity> {
        return NSFetchRequest<VenueEntity>(entityName: "VenueEntity")
    }

    @NSManaged public var address: String?
    @NSManaged public var contactName: String?
    @NSManaged public var contactPhone: String?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var type: String?
    @NSManaged public var attachments: NSSet?

}

// MARK: Generated accessors for attachments
extension VenueEntity {

    @objc(addAttachmentsObject:)
    @NSManaged public func addToAttachments(_ value: VenueAttachmentEntity)

    @objc(removeAttachmentsObject:)
    @NSManaged public func removeFromAttachments(_ value: VenueAttachmentEntity)

    @objc(addAttachments:)
    @NSManaged public func addToAttachments(_ values: NSSet)

    @objc(removeAttachments:)
    @NSManaged public func removeFromAttachments(_ values: NSSet)

}

extension VenueEntity : Identifiable {

}
