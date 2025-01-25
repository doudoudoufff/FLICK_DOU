import Foundation

struct ProjectTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String       // 任务内容
    var assignee: String    // 任务人员
    var dueDate: Date      // 截止时间
    var isCompleted: Bool
    var reminder: TaskReminder?
    
    enum TaskReminder: String, Codable, CaseIterable {
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
    }
    
    // 提醒时间（小时）
    var reminderHour: Int = 9 // 默认早上9点提醒
    
    enum CodingKeys: String, CodingKey {
        case id, title, assignee, dueDate, isCompleted, reminder, reminderHour
    }
    
    init(id: UUID = UUID(),
         title: String,
         assignee: String,
         dueDate: Date,
         isCompleted: Bool = false,
         reminder: TaskReminder? = nil,
         reminderHour: Int = 9) {
        self.id = id
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.reminder = reminder
        self.reminderHour = reminderHour
    }
} 