//
//  LocationPhotoEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension LocationPhotoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocationPhotoEntity> {
        return NSFetchRequest<LocationPhotoEntity>(entityName: "LocationPhotoEntity")
    }

    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var note: String?
    @NSManaged public var weather: String?
    @NSManaged public var location: LocationEntity?

}

extension LocationPhotoEntity : Identifiable {

}
