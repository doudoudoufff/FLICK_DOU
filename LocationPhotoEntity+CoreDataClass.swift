//
//  LocationPhotoEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/22.
//
//

import Foundation
import CoreData
import UIKit

public class LocationPhotoEntity: NSManagedObject {
    func toModel() -> LocationPhoto? {
        guard let id = self.id,
              let imageData = self.imageData,
              let date = self.date,
              let image = UIImage(data: imageData)
        else { return nil }
        
        return LocationPhoto(
            id: id,
            image: image,
            date: date,
            weather: weather,
            note: note
        )
    }
}
