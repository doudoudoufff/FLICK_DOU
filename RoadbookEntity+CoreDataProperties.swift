//
//  RoadbookEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 11 on 6/26/25.
//
//

public import Foundation
public import CoreData


public typealias RoadbookEntityCoreDataPropertiesSet = NSSet

extension RoadbookEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RoadbookEntity> {
        return NSFetchRequest<RoadbookEntity>(entityName: "RoadbookEntity")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var modificationDate: Date?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var photos: NSOrderedSet?
    @NSManaged public var project: ProjectEntity?

}

// MARK: Generated accessors for photos
extension RoadbookEntity {

    @objc(insertObject:inPhotosAtIndex:)
    @NSManaged public func insertIntoPhotos(_ value: RoadbookPhotoEntity, at idx: Int)

    @objc(removeObjectFromPhotosAtIndex:)
    @NSManaged public func removeFromPhotos(at idx: Int)

    @objc(insertPhotos:atIndexes:)
    @NSManaged public func insertIntoPhotos(_ values: [RoadbookPhotoEntity], at indexes: NSIndexSet)

    @objc(removePhotosAtIndexes:)
    @NSManaged public func removeFromPhotos(at indexes: NSIndexSet)

    @objc(replaceObjectInPhotosAtIndex:withObject:)
    @NSManaged public func replacePhotos(at idx: Int, with value: RoadbookPhotoEntity)

    @objc(replacePhotosAtIndexes:withPhotos:)
    @NSManaged public func replacePhotos(at indexes: NSIndexSet, with values: [RoadbookPhotoEntity])

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: RoadbookPhotoEntity)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: RoadbookPhotoEntity)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSOrderedSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSOrderedSet)

}

extension RoadbookEntity : Identifiable {

}
