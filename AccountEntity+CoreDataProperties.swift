//
//  AccountEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension AccountEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AccountEntity> {
        return NSFetchRequest<AccountEntity>(entityName: "AccountEntity")
    }

    @NSManaged public var bankAccount: String?
    @NSManaged public var bankBranch: String?
    @NSManaged public var bankName: String?
    @NSManaged public var contactName: String?
    @NSManaged public var contactPhone: String?
    @NSManaged public var id: UUID?
    @NSManaged public var idNumber: String?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var type: String?
    @NSManaged public var project: ProjectEntity?

}

extension AccountEntity : Identifiable {

}
