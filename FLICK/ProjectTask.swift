import Foundation
import CoreData

struct ProjectTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String       // 任务内容
    var assignee: String    // 任务人员
    var startDate: Date     // 开始时间
    var dueDate: Date       // 截止时间
    var isCompleted: Bool
    var reminder: TaskReminder?
    
    enum TaskReminder: String, Codable, CaseIterable, Identifiable {
        case daily = "每日提醒"
        case sevenDays = "提前7天"
        case threeDays = "提前3天"
        case oneDay = "提前1天"
        
        var days: Int {
            switch self {
            case .daily: return 0
            case .sevenDays: return 7
            case .threeDays: return 3
            case .oneDay: return 1
            }
        }
        
        // 添加 id 属性以符合 Identifiable 协议
        var id: String { rawValue }
    }
    
    // 提醒时间（小时）
    var reminderHour: Int = 9 // 默认早上9点提醒
    
    enum CodingKeys: String, CodingKey {
        case id, title, assignee, startDate, dueDate, isCompleted, reminder, reminderHour
    }
    
    init(id: UUID = UUID(),
         title: String,
         assignee: String,
         startDate: Date? = nil,
         dueDate: Date,
         isCompleted: Bool = false,
         reminder: TaskReminder? = nil,
         reminderHour: Int = 9) {
        self.id = id
        self.title = title
        self.assignee = assignee
        self.startDate = startDate ?? dueDate // 如果没有提供开始日期，则默认与截止日期相同
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.reminder = reminder
        self.reminderHour = reminderHour
    }
    
    // 判断任务是否跨天
    var isCrossDays: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: dueDate)
    }
    
    // 计算任务持续天数
    var durationDays: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let dueDay = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: startDay, to: dueDay)
        return max(1, (components.day ?? 0) + 1) // 至少为1天
    }
}

extension ProjectTask {
    // Model -> Entity
    func toEntity(context: NSManagedObjectContext) -> TaskEntity {
        let entity = TaskEntity(context: context)
        entity.id = id
        entity.title = title
        entity.assignee = assignee
        entity.startDate = startDate
        entity.dueDate = dueDate
        entity.isCompleted = isCompleted
        entity.reminder = reminder?.rawValue
        entity.reminderHour = Int16(reminderHour)
        return entity
    }
    
    // Entity -> Model
    static func fromEntity(_ entity: TaskEntity) -> ProjectTask? {
        guard let id = entity.id,
              let title = entity.title,
              let assignee = entity.assignee,
              let dueDate = entity.dueDate
        else { return nil }
        
        // 从字符串转回枚举
        let reminder = entity.reminder.flatMap { TaskReminder(rawValue: $0) }
        
        return ProjectTask(
            id: id,
            title: title,
            assignee: assignee,
            startDate: entity.startDate ?? dueDate, // 使用startDate，如果为nil则使用dueDate
            dueDate: dueDate,
            isCompleted: entity.isCompleted,
            reminder: reminder,
            reminderHour: Int(entity.reminderHour)  // 转换回 Int
        )
    }
} 