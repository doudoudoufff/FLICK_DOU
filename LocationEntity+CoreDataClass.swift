//
//  LocationEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/22.
//
//

import Foundation
import CoreData


public class LocationEntity: NSManagedObject {
    func toModel() -> Location? {
        guard let id = self.id,
              let name = self.name,
              let type = self.type,
              let status = self.status,
              let address = self.address,
              let date = self.date,
              let typeEnum = LocationType(rawValue: type),
              let statusEnum = LocationStatus(rawValue: status)
        else { return nil }
        
        // 转换照片数组
        let photosArray = (photos?.allObjects as? [LocationPhotoEntity])?
            .compactMap { $0.toModel() } ?? []
        
        // 创建 Location 对象
        let location = Location(
            id: id,
            name: name,
            type: typeEnum,
            status: statusEnum,
            address: address,
            latitude: hasCoordinates ? latitude : nil,
            longitude: hasCoordinates ? longitude : nil,
            contactName: contactName,
            contactPhone: contactPhone,
            photos: photosArray,
            notes: notes,
            date: date
        )
        
        return location
    }
}
