//
//  TaskEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


public class TaskEntity: NSManagedObject {
    // 转换为 Model
    func toModel() -> ProjectTask? {
        guard let id = self.id,
              let title = self.title,
              let assignee = self.assignee,
              let dueDate = self.dueDate
        else { return nil }
        
        // 从字符串转回枚举
        let reminder = self.reminder.flatMap { ProjectTask.TaskReminder(rawValue: $0) }
        
        return ProjectTask(
            id: id,
            title: title,
            assignee: assignee,
            dueDate: dueDate,
            isCompleted: isCompleted,
            reminder: reminder,
            reminderHour: Int(reminderHour)  // 从 Int16 转换为 Int
        )
    }
}
