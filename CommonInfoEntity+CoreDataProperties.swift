//
//  CommonInfoEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/28.
//
//

import Foundation
import CoreData


extension CommonInfoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CommonInfoEntity> {
        return NSFetchRequest<CommonInfoEntity>(entityName: "CommonInfoEntity")
    }

    @NSManaged public var content: String?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var tag: String?
    @NSManaged public var title: String?
    @NSManaged public var type: String?
    @NSManaged public var userData: Data?

}

extension CommonInfoEntity : Identifiable {

}
