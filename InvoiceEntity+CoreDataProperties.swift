//
//  InvoiceEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension InvoiceEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InvoiceEntity> {
        return NSFetchRequest<InvoiceEntity>(entityName: "InvoiceEntity")
    }

    @NSManaged public var bankAccount: String?
    @NSManaged public var bankName: String?
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var idNumber: String?
    @NSManaged public var name: String?
    @NSManaged public var phone: String?
    @NSManaged public var project: ProjectEntity?

}

extension InvoiceEntity : Identifiable {

}
