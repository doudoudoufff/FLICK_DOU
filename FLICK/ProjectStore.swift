import SwiftUI

class ProjectStore: ObservableObject {
    static var shared: ProjectStore?
    @Published var projects: [Project]
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    init(projects: [Project] = [
        Project(
            name: "流浪地球3",
            director: "郭帆",
            producer: "刘慈欣",
            color: .blue,
            tasks: [
                ProjectTask(
                    title: "特效分镜脚本确认",
                    assignee: "郭帆",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                ),
                ProjectTask(
                    title: "主要演员试镜",
                    assignee: "张三",
                    dueDate: Date().addingTimeInterval(86400 * 5)
                ),
                ProjectTask(
                    title: "场景搭建方案评估",
                    assignee: "李四",
                    dueDate: Date().addingTimeInterval(86400 * 7)
                )
            ],
            invoices: [
                Invoice(
                    name: "张三",
                    phone: "13800138000",
                    idNumber: "110101199001011234",
                    bankAccount: "6222021234567890123",
                    bankName: "中国工商银行北京分行",
                    date: Date().addingTimeInterval(-86400 * 5)
                ),
                Invoice(
                    name: "李四",
                    phone: "13900139000",
                    idNumber: "110101199001011235",
                    bankAccount: "6222021234567890124",
                    bankName: "中国建设银行北京分行",
                    date: Date()
                )
            ],
            accounts: [
                Account(
                    name: "张艺谋",
                    type: .artist,
                    bankName: "中国工商银行",
                    bankBranch: "北京东城支行",
                    bankAccount: "6222021234567890123",
                    idNumber: "110101196001011234",
                    contactName: "王助理",
                    contactPhone: "13800138000",
                    notes: "导演账户"
                ),
                Account(
                    name: "北京影视器材租赁有限公司",
                    type: .equipment,
                    bankName: "中国建设银行",
                    bankBranch: "北京西城支行",
                    bankAccount: "6227001234567890123",
                    contactName: "李经理",
                    contactPhone: "13900139000",
                    notes: "摄影器材供应商"
                )
            ]
        ),
        Project(
            name: "满江红",
            director: "张艺谋",
            producer: "陈红",
            color: .red,
            tasks: [
                ProjectTask(
                    title: "剧本终稿修改",
                    assignee: "王五",
                    dueDate: Date().addingTimeInterval(86400 * 1)
                ),
                ProjectTask(
                    title: "服装设计确认",
                    assignee: "赵六",
                    dueDate: Date().addingTimeInterval(86400 * 3)
                )
            ],
            invoices: [],
            accounts: []
        ),
        Project(
            name: "独行月球2",
            director: "张吃鱼",
            producer: "沈腾",
            color: .purple,
            tasks: [
                ProjectTask(
                    title: "特效公司甄选",
                    assignee: "张吃鱼",
                    dueDate: Date().addingTimeInterval(86400 * 4)
                ),
                ProjectTask(
                    title: "预算评估会议",
                    assignee: "马飞",
                    dueDate: Date().addingTimeInterval(86400 * 6)
                )
            ],
            invoices: [
                Invoice(
                    name: "王五",
                    phone: "13700137000",
                    idNumber: "110101199001011236",
                    bankAccount: "6222021234567890125",
                    bankName: "中国农业银行北京分行",
                    date: Date()
                )
            ],
            accounts: []
        )
    ]) {
        self.projects = projects
        ProjectStore.shared = self
    }
    
    // 添加、删除、更新项目的方法
    func addProject(_ project: Project) {
        projects.append(project)
    }
    
    func deleteProject(at index: Int) {
        projects.remove(at: index)
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }
    
    private func handleTaskChange(task: ProjectTask, in project: Project) {
        if enableNotifications {
            if task.isCompleted {
                // 如果任务完成，移除提醒
                NotificationManager.shared.removeTaskReminders(for: task)
            } else if task.reminder != nil {
                // 如果设置了提醒，更新提醒
                NotificationManager.shared.scheduleTaskReminder(for: task, in: project)
            }
        }
    }
    
    func updateTask(_ task: ProjectTask, in project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
           let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == task.id }) {
            projects[projectIndex].tasks[taskIndex] = task
            handleTaskChange(task: task, in: project)
        }
    }
    
    func addTask(_ task: ProjectTask, to project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].tasks.append(task)
            handleTaskChange(task: task, in: project)
        }
    }
    
    func deleteTask(_ task: ProjectTask, from project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            projects[projectIndex].tasks.removeAll(where: { $0.id == task.id })
            NotificationManager.shared.removeTaskReminders(for: task)
        }
    }
}

// 用于获取项目 Binding 的扩展
extension ProjectStore {
    func binding(for projectId: UUID) -> Binding<Project>? {  // 返回可选的 Binding
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return nil
        }
        
        return Binding(
            get: { self.projects[index] },
            set: { self.projects[index] = $0 }
        )
    }
} 
