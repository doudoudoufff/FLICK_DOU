import Foundation

struct ProjectTask: Identifiable, Codable {
    let id: UUID
    var title: String       // 任务内容
    var assignee: String    // 任务人员
    var dueDate: Date      // 截止时间
    var isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, assignee, dueDate, isCompleted
    }
    
    init(id: UUID = UUID(),
         title: String,
         assignee: String,
         dueDate: Date,
         isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
} 