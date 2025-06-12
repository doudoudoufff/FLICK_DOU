//
//  TagEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 11 on 6/12/25.
//
//

public import Foundation
public import CoreData


public typealias TagEntityCoreDataPropertiesSet = NSSet

extension TagEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagEntity> {
        return NSFetchRequest<TagEntity>(entityName: "TagEntity")
    }

    @NSManaged public var colorHex: String?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var tagType: String?
    @NSManaged public var order: Int32
    @NSManaged public var isDefault: Bool

}

extension TagEntity : Identifiable {

}
