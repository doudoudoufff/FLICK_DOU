//
//  LocationPhotoEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/22.
//
//

import Foundation
import CoreData


extension LocationPhotoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocationPhotoEntity> {
        return NSFetchRequest<LocationPhotoEntity>(entityName: "LocationPhotoEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var date: Date?
    @NSManaged public var weather: String?
    @NSManaged public var note: String?
    @NSManaged public var location: LocationEntity?

     func toModel() -> LocationPhoto? {
        guard let imageData = self.imageData,
              let date = self.date else { return nil }
        
        return LocationPhoto(
            id: id ?? UUID(),
            imageData: imageData,
            date: date,
            tags: [],  // 如果需要处理 tags，可以在这里添加
            weather: weather,
            note: note
        )
    }

}

extension LocationPhotoEntity : Identifiable {

}
