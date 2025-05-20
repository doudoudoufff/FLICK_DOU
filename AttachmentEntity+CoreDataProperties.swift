//
//  AttachmentEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/4/28.
//
//

import Foundation
import CoreData


extension AttachmentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AttachmentEntity> {
        return NSFetchRequest<AttachmentEntity>(entityName: "AttachmentEntity")
    }

    @NSManaged public var data: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var invoice: InvoiceEntity?
    @NSManaged public var transaction: TransactionEntity?

}

extension AttachmentEntity : Identifiable {

}
