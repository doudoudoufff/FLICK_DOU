import SwiftUI

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    init(projects: [Project] = []) {
        self.projects = projects
        ProjectStore.shared = self
        loadProjects()  // 改为加载本地数据
    }
    
    // 从本地加载项目
    func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            self.projects = decoded
        }
    }
    
    // 保存到本地
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
        }
    }
    
    // 添加项目
    func addProject(_ project: Project) {
        projects.append(project)
        saveProjects()
    }
    
    // 删除项目
    func deleteProject(at index: Int) {
        projects.remove(at: index)
        saveProjects()
    }
    
    // 更新项目
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
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
            saveProjects()
        }
    }
    
    func addTask(_ task: ProjectTask, to project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].tasks.append(task)
            handleTaskChange(task: task, in: project)
            saveProjects()
        }
    }
    
    func deleteTask(_ task: ProjectTask, from project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            projects[projectIndex].tasks.removeAll(where: { $0.id == task.id })
            NotificationManager.shared.removeTaskReminders(for: task)
            saveProjects()
        }
    }
    
    static func withTestData() -> ProjectStore {
        let store = ProjectStore()
        
        // 测试项目1：网剧
        let webSeries = Project(
            name: "迷失东京",
            director: "张导演",
            producer: "李制片",
            startDate: Date().addingTimeInterval(-86400 * 15),
            status: .preProduction,
            color: .blue,
            tasks: [
                ProjectTask(title: "选景完成", assignee: "场务组", dueDate: Date(), isCompleted: true),
                ProjectTask(title: "演员试镜", assignee: "选角导演", dueDate: Date().addingTimeInterval(86400 * 3)),
                ProjectTask(title: "剧本终稿", assignee: "编剧组", dueDate: Date().addingTimeInterval(86400 * 7))
            ],
            invoices: [
                Invoice(
                    name: "场地公司",
                    phone: "13100131000",
                    idNumber: "110101199001011234",
                    bankAccount: "6222021234567890",
                    bankName: "工商银行",
                    date: Date()
                )
            ],
            accounts: [
                Account(
                    name: "场地公司",
                    type: .location,
                    bankName: "工商银行",
                    bankBranch: "北京分行",
                    bankAccount: "6222021234567890",
                    contactName: "王场地",
                    contactPhone: "13100131000"
                )
            ]
        )
        
        // 测试项目2：电影
        let movie = Project(
            name: "春天的声音",
            director: "王导演",
            producer: "赵制片",
            startDate: Date(),
            status: .production,
            color: .green,
            tasks: [
                ProjectTask(title: "拍摄第一场", assignee: "摄影组", dueDate: Date().addingTimeInterval(86400)),
                ProjectTask(title: "道具采购", assignee: "美术组", dueDate: Date().addingTimeInterval(86400 * 2)),
                ProjectTask(title: "服装定做", assignee: "服装组", dueDate: Date().addingTimeInterval(86400 * 4))
            ],
            invoices: [
                Invoice(
                    name: "道具公司",
                    phone: "13200132000",
                    idNumber: "110101199001012345",
                    bankAccount: "6225881234567890",
                    bankName: "建设银行",
                    date: Date()
                )
            ],
            accounts: [
                Account(
                    name: "道具工作室",
                    type: .prop,
                    bankName: "浦发银行",
                    bankBranch: "北京分行",
                    bankAccount: "6225882345678901",
                    contactName: "刘道具",
                    contactPhone: "13400134000"
                )
            ]
        )
        
        // 测试项目3：广告
        let commercial = Project(
            name: "小米品牌广告",
            director: "张小导",
            producer: "刘制片",
            startDate: Date().addingTimeInterval(-86400 * 30),
            status: .postProduction,
            color: .purple,
            tasks: [
                ProjectTask(title: "剪辑初稿", assignee: "剪辑师", dueDate: Date(), isCompleted: true),
                ProjectTask(title: "音效制作", assignee: "声音设计", dueDate: Date().addingTimeInterval(86400 * 2)),
                ProjectTask(title: "客户审核", assignee: "项目经理", dueDate: Date().addingTimeInterval(86400 * 5))
            ],
            invoices: [
                Invoice(
                    name: "后期特效工作室",
                    phone: "13200132000",
                    idNumber: "110101199501012345",
                    bankAccount: "6228480123456789",
                    bankName: "中信银行",
                    date: Date()
                )
            ],
            accounts: [
                Account(
                    name: "声音后期工作室",
                    type: .other,
                    bankName: "民生银行",
                    bankBranch: "北京分行",
                    bankAccount: "6226220123456789",
                    contactName: "王声音",
                    contactPhone: "13300133000",
                    notes: "专业音效制作团队"
                )
            ]
        )
        
        store.projects = [webSeries, movie, commercial]
        return store
    }
}

// 用于获取项目 Binding 的扩展
extension ProjectStore {
    func binding(for projectId: UUID) -> Binding<Project>? {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return nil
        }
        
        return Binding(
            get: { self.projects[index] },
            set: { self.projects[index] = $0 }
        )
    }
} 
