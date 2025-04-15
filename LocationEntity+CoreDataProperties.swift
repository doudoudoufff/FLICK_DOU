//
//  LocationEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension LocationEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocationEntity> {
        return NSFetchRequest<LocationEntity>(entityName: "LocationEntity")
    }

    @NSManaged public var address: String?
    @NSManaged public var contactName: String?
    @NSManaged public var contactPhone: String?
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var status: String?
    @NSManaged public var type: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var hasCoordinates: Bool
    @NSManaged public var photos: NSSet?
    @NSManaged public var project: ProjectEntity?

}

// MARK: Generated accessors for photos
extension LocationEntity {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: LocationPhotoEntity)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: LocationPhotoEntity)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

}

extension LocationEntity : Identifiable {

}
