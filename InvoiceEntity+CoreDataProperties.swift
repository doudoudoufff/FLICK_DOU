//
//  InvoiceEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/4/28.
//
//

import Foundation
import CoreData


extension InvoiceEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InvoiceEntity> {
        return NSFetchRequest<InvoiceEntity>(entityName: "InvoiceEntity")
    }

    @NSManaged public var amount: Double
    @NSManaged public var bankAccount: String?
    @NSManaged public var bankName: String?
    @NSManaged public var category: String?
    @NSManaged public var date: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var idNumber: String?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var phone: String?
    @NSManaged public var status: String?
    @NSManaged public var attachments: NSSet?
    @NSManaged public var project: ProjectEntity?

}

// MARK: Generated accessors for attachments
extension InvoiceEntity {

    @objc(addAttachmentsObject:)
    @NSManaged public func addToAttachments(_ value: AttachmentEntity)

    @objc(removeAttachmentsObject:)
    @NSManaged public func removeFromAttachments(_ value: AttachmentEntity)

    @objc(addAttachments:)
    @NSManaged public func addToAttachments(_ values: NSSet)

    @objc(removeAttachments:)
    @NSManaged public func removeFromAttachments(_ values: NSSet)

}

extension InvoiceEntity : Identifiable {

}
