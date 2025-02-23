//
//  LocationPhotoEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/22.
//
//

import Foundation
import CoreData


public class LocationPhotoEntity: NSManagedObject {
    func toModel() -> LocationPhoto? {
        guard let id = self.id,
              let imageData = self.imageData,
              let date = self.date
        else { return nil }
        
        return LocationPhoto(
            id: id,
            imageData: imageData,
            date: date,
            tags: [], // 暂时不处理 tags
            weather: weather,
            note: note
        )
    }
}
