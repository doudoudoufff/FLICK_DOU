//
//  DrawingElementEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 11 on 6/26/25.
//
//

public import Foundation
public import CoreData


public typealias DrawingElementEntityCoreDataPropertiesSet = NSSet

extension DrawingElementEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrawingElementEntity> {
        return NSFetchRequest<DrawingElementEntity>(entityName: "DrawingElementEntity")
    }

    @NSManaged public var color: String?
    @NSManaged public var id: UUID?
    @NSManaged public var lineWidth: Double
    @NSManaged public var pointsData: Data?
    @NSManaged public var text: String?
    @NSManaged public var type: String?
    @NSManaged public var roadbookPhoto: RoadbookPhotoEntity?

}

extension DrawingElementEntity : Identifiable {

}
