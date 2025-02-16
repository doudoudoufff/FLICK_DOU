import SwiftUI

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    init(projects: [Project] = []) {
        self.projects = projects
        ProjectStore.shared = self
    }
    
    // 从云端加载项目
    func loadProjects() async {
        do {
            let cloudProjects = try await LCManager.shared.fetchProjects()
            DispatchQueue.main.async {
                self.projects = cloudProjects
            }
        } catch {
            print("加载项目失败：\(error)")
        }
    }
    
    // 添加项目
    func addProject(_ project: Project) {
        projects.append(project)
        
        // 保存到云端
        Task {
            do {
                try await LCManager.shared.saveProject(project)
            } catch {
                print("保存项目失败：\(error)")
            }
        }
    }
    
    // 删除项目
    func deleteProject(at index: Int) {
        projects.remove(at: index)
    }
    
    // 更新项目
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

// 添加测试数据的扩展
extension ProjectStore {
    static func withTestData() -> ProjectStore {
        let store = ProjectStore()
        
        // 测试项目1：筹备中的网剧
        let webSeries = Project(
            name: "《都市日记》",
            director: "陈晓明",
            producer: "王小明",
            startDate: Date().addingTimeInterval(86400 * 7),
            status: .planning,
            color: .orange,
            tasks: [
                ProjectTask(title: "完成演员试镜", assignee: "张助理", dueDate: Date().addingTimeInterval(86400 * 3)),
                ProjectTask(title: "场地考察", assignee: "李场务", dueDate: Date().addingTimeInterval(86400 * 5)),
                ProjectTask(title: "预算审核", assignee: "王制片", dueDate: Date().addingTimeInterval(86400 * 4))
            ],
            invoices: [
                Invoice(
                    name: "张艺谋",
                    phone: "13800138000",
                    idNumber: "110101199001011234",
                    bankAccount: "6222021234567890123",
                    bankName: "中国工商银行",
                    date: Date().addingTimeInterval(-86400 * 2)
                )
            ],
            accounts: [
                Account(
                    name: "星光场地服务公司",
                    type: .venue,
                    bankName: "中国建设银行",
                    bankBranch: "北京朝阳支行",
                    bankAccount: "6227002345678901234",
                    contactName: "李经理",
                    contactPhone: "13900139000",
                    notes: "常用场地供应商"
                ),
                Account(
                    name: "王小明",
                    type: .artist,
                    bankName: "招商银行",
                    bankBranch: "北京分行",
                    bankAccount: "6225884567890123",
                    idNumber: "110101199203034567",
                    contactName: "王小明",
                    contactPhone: "13700137000"
                )
            ]
        )
        
        // 测试项目2：拍摄中的电影
        let movie = Project(
            name: "《春天的声音》",
            director: "李大明",
            producer: "赵制片",
            startDate: Date().addingTimeInterval(-86400 * 15),
            status: .shooting,
            color: .blue,
            tasks: [
                ProjectTask(title: "今日拍摄进度确认", assignee: "场记", dueDate: Date()),
                ProjectTask(title: "道具采购", assignee: "道具组", dueDate: Date().addingTimeInterval(86400), isCompleted: true),
                ProjectTask(title: "群演调度", assignee: "副导演", dueDate: Date().addingTimeInterval(86400 * 2))
            ],
            invoices: [
                Invoice(
                    name: "李大明",
                    phone: "13600136000",
                    idNumber: "110101198801015678",
                    bankAccount: "6222020987654321",
                    bankName: "中国农业银行",
                    date: Date().addingTimeInterval(-86400 * 10)
                )
            ],
            accounts: [
                Account(
                    name: "专业摄影器材租赁",
                    type: .equipment,
                    bankName: "中国银行",
                    bankBranch: "北京西城支行",
                    bankAccount: "6216612345678901",
                    contactName: "张老板",
                    contactPhone: "13500135000",
                    notes: "摄影机和镜头供应商"
                ),
                Account(
                    name: "艺术道具工作室",
                    type: .props,
                    bankName: "浦发银行",
                    bankBranch: "北京分行",
                    bankAccount: "6225882345678901",
                    contactName: "刘道具",
                    contactPhone: "13400134000"
                )
            ]
        )
        
        // 测试项目3：后期制作的广告
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
