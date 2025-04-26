//
//  ProjectEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension ProjectEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectEntity> {
        return NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
    }

    @NSManaged public var color: Data?
    @NSManaged public var director: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isLocationScoutingEnabled: Bool
    @NSManaged public var logoData: Data?
    @NSManaged public var name: String?
    @NSManaged public var producer: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var status: String?
    @NSManaged public var accounts: NSSet?
    @NSManaged public var invoices: NSSet?
    @NSManaged public var locations: NSSet?
    @NSManaged public var tasks: NSSet?

}

// MARK: Generated accessors for accounts
extension ProjectEntity {

    @objc(addAccountsObject:)
    @NSManaged public func addToAccounts(_ value: AccountEntity)

    @objc(removeAccountsObject:)
    @NSManaged public func removeFromAccounts(_ value: AccountEntity)

    @objc(addAccounts:)
    @NSManaged public func addToAccounts(_ values: NSSet)

    @objc(removeAccounts:)
    @NSManaged public func removeFromAccounts(_ values: NSSet)

}

// MARK: Generated accessors for invoices
extension ProjectEntity {

    @objc(addInvoicesObject:)
    @NSManaged public func addToInvoices(_ value: InvoiceEntity)

    @objc(removeInvoicesObject:)
    @NSManaged public func removeFromInvoices(_ value: InvoiceEntity)

    @objc(addInvoices:)
    @NSManaged public func addToInvoices(_ values: NSSet)

    @objc(removeInvoices:)
    @NSManaged public func removeFromInvoices(_ values: NSSet)

}

// MARK: Generated accessors for locations
extension ProjectEntity {

    @objc(addLocationsObject:)
    @NSManaged public func addToLocations(_ value: LocationEntity)

    @objc(removeLocationsObject:)
    @NSManaged public func removeFromLocations(_ value: LocationEntity)

    @objc(addLocations:)
    @NSManaged public func addToLocations(_ values: NSSet)

    @objc(removeLocations:)
    @NSManaged public func removeFromLocations(_ values: NSSet)

}

// MARK: Generated accessors for tasks
extension ProjectEntity {

    @objc(addTasksObject:)
    @NSManaged public func addToTasks(_ value: TaskEntity)

    @objc(removeTasksObject:)
    @NSManaged public func removeFromTasks(_ value: TaskEntity)

    @objc(addTasks:)
    @NSManaged public func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged public func removeFromTasks(_ values: NSSet)

}

extension ProjectEntity : Identifiable {

}
