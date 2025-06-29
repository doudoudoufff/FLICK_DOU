//
//  RoadbookPhotoEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 11 on 6/26/25.
//
//

public import Foundation
public import CoreData


public typealias RoadbookPhotoEntityCoreDataPropertiesSet = NSSet

extension RoadbookPhotoEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RoadbookPhotoEntity> {
        return NSFetchRequest<RoadbookPhotoEntity>(entityName: "RoadbookPhotoEntity")
    }

    @NSManaged public var captureDate: Date?
    @NSManaged public var editedImageData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var note: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var originalImageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var drawingElements: NSSet?
    @NSManaged public var roadbook: RoadbookEntity?

}

// MARK: Generated accessors for drawingElements
extension RoadbookPhotoEntity {

    @objc(addDrawingElementsObject:)
    @NSManaged public func addToDrawingElements(_ value: DrawingElementEntity)

    @objc(removeDrawingElementsObject:)
    @NSManaged public func removeFromDrawingElements(_ value: DrawingElementEntity)

    @objc(addDrawingElements:)
    @NSManaged public func addToDrawingElements(_ values: NSSet)

    @objc(removeDrawingElements:)
    @NSManaged public func removeFromDrawingElements(_ values: NSSet)

}

extension RoadbookPhotoEntity : Identifiable {

}
