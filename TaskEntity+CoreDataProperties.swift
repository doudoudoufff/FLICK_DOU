//
//  TaskEntity+CoreDataProperties.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


extension TaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged public var assignee: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var reminder: String?
    @NSManaged public var reminderHour: Int16
    @NSManaged public var title: String?
    @NSManaged public var project: ProjectEntity?

}

extension TaskEntity : Identifiable {

}
