import Foundation

struct ProjectTask: Identifiable {
    let id = UUID()
    var title: String       // 任务内容
    var assignee: String    // 任务人员
    var dueDate: Date      // 截止时间
    var isCompleted: Bool
    
    init(title: String, assignee: String, dueDate: Date, isCompleted: Bool = false) {
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
} 