import CoreData
import SwiftUI

extension Project {
    // 从 ProjectModel 创建 CoreData Project
    static func create(from model: ProjectModel, in context: NSManagedObjectContext) -> Project {
        let project = Project(context: context)
        project.id = model.id
        project.name = model.name
        project.director = model.director
        project.producer = model.producer
        project.startDate = model.startDate
        project.colorHex = model.color.toHex()
        project.status = Int16(model.status.rawValue)
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
    
    // 转换为 ProjectModel
    var toModel: ProjectModel {
        ProjectModel(
            id: id ?? UUID(),
            name: name ?? "",
            director: director ?? "",
            producer: producer ?? "",
            startDate: startDate ?? Date(),
            color: Color(hex: colorHex ?? "") ?? .blue,
            status: ProjectModel.ProjectStatus(rawValue: Int(status)) ?? .preProduction,
            tasks: tasks?.allObjects as? [Task] ?? []
        )
    }
    
    // 获取项目颜色
    var color: Color {
        get { Color(hex: colorHex ?? "#007AFF") ?? .blue }
        set { colorHex = newValue.toHex() }
    }
    
    // 获取项目状态
    var projectStatus: ProjectModel.ProjectStatus {
        get { ProjectModel.ProjectStatus(rawValue: Int(status)) ?? .preProduction }
        set { status = Int16(newValue.rawValue) }
    }
}

// 为了区分旧的数据模型，我们可以将现有的 Project 结构体重命名为 OldProject
typealias OldProject = Project 