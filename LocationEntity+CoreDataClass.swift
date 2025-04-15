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
        
        // 调试输出
        print("从 Core Data 获取位置数据:")
        print("- ID: \(id)")
        print("- 名称: \(name)")
        print("- 坐标状态: \(hasCoordinates ? "有坐标" : "无坐标")")
        if hasCoordinates {
            print("- 纬度: \(latitude), 经度: \(longitude)")
        }
        
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
        
        // 验证创建的对象
        print("创建的 Location 对象验证:")
        print("- hasCoordinates: \(location.hasCoordinates)")
        if location.hasCoordinates {
            print("- 纬度: \(location.latitude!), 经度: \(location.longitude!)")
        }
        
        return location
    }
}
