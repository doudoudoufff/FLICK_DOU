//
//  TransactionEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/20.
//
//

import Foundation
import CoreData


extension TransactionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionEntity> {
        return NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
    }

    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var transactionDescription: String?
    @NSManaged public var expenseType: String?
    @NSManaged public var group: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isVerified: Bool
    @NSManaged public var name: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var type: String?
    @NSManaged public var attachments: NSSet?
    @NSManaged public var project: ProjectEntity?

}

// MARK: Generated accessors for attachments
extension TransactionEntity {

    @objc(addAttachmentsObject:)
    @NSManaged public func addToAttachments(_ value: AttachmentEntity)

    @objc(removeAttachmentsObject:)
    @NSManaged public func removeFromAttachments(_ value: AttachmentEntity)

    @objc(addAttachments:)
    @NSManaged public func addToAttachments(_ values: NSSet)

    @objc(removeAttachments:)
    @NSManaged public func removeFromAttachments(_ values: NSSet)

}

extension TransactionEntity : Identifiable {

}
