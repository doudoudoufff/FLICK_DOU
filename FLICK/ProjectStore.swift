import SwiftUI
import CoreData

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        ProjectStore.shared = self
        loadProjects()
    }
    
    private func loadProjects() {
        // 从 CoreData 加载所有项目
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        
        do {
            let projectEntities = try context.fetch(fetchRequest)
            print("从 CoreData 加载到 \(projectEntities.count) 个项目")
            
            // 转换为 Project 模型
            self.projects = projectEntities.compactMap { projectEntity in
                projectEntity.toModel()
            }
            
            if projects.isEmpty {
                print("CoreData 中没有数据，尝试从 UserDefaults 加载")
                // 临时：如果 CoreData 没有数据，从 UserDefaults 加载
                if let data = UserDefaults.standard.data(forKey: "savedProjects"),
                   let decoded = try? JSONDecoder().decode([Project].self, from: data) {
                    self.projects = decoded
                    
                    // 将 UserDefaults 中的数据保存到 CoreData
                    for project in projects {
                        _ = project.toEntity(context: context)
                    }
                    try? context.save()
                }
            }
        } catch {
            print("从 CoreData 加载项目失败: \(error)")
            
            // 出错时尝试从 UserDefaults 加载
            if let data = UserDefaults.standard.data(forKey: "savedProjects"),
               let decoded = try? JSONDecoder().decode([Project].self, from: data) {
                self.projects = decoded
            }
        }
    }
    
    func saveProjects() {
        // 保存到 CoreData
        for project in projects {
            let projectEntity = project.toEntity(context: context)
            
            // 保存任务
            for task in project.tasks {
                let taskEntity = task.toEntity(context: context)
                taskEntity.project = projectEntity
            }
            
            // 保存位置和照片
            for location in project.locations {
                let locationEntity = location.toEntity(context: context)
                locationEntity.project = projectEntity
                
                // 保存照片
                for photo in location.photos {
                    let photoEntity = photo.toEntity(context: context)
                    photoEntity.location = locationEntity
                }
            }
            
            // 保存发票
            for invoice in project.invoices {
                let invoiceEntity = invoice.toEntity(context: context)
                invoiceEntity.project = projectEntity
            }
            
            // 保存账户
            for account in project.accounts {
                let accountEntity = account.toEntity(context: context)
                accountEntity.project = projectEntity
            }
        }
        
        do {
            try context.save()
            print("成功保存到 CoreData")
        } catch {
            print("保存到 CoreData 失败: \(error)")
        }
        
        // 临时：同时保存到 UserDefaults（作为备份）
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
            // 更新内存中的数据
            projects[projectIndex].tasks[taskIndex] = task
            
            // 更新 CoreData
            let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            
            if let taskEntity = try? context.fetch(fetchRequest).first {
                // 更新实体属性
                taskEntity.title = task.title
                taskEntity.assignee = task.assignee
                taskEntity.dueDate = task.dueDate
                taskEntity.isCompleted = task.isCompleted
                taskEntity.reminder = task.reminder?.rawValue  // 使用枚举的原始值
                taskEntity.reminderHour = Int16(task.reminderHour)  // 转换为 Int16
                
                do {
                    try context.save()
                    print("任务更新成功")
                } catch {
                    print("更新任务失败: \(error)")
                }
            }
            
            handleTaskChange(task: task, in: project)
        }
    }
    
    func addTask(_ task: ProjectTask, to project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            // 更新内存中的数据
            projects[index].tasks.append(task)
            
            // 保存到 CoreData
            let taskEntity = task.toEntity(context: context)
            
            // 设置与 Project 的关系
            if let projectEntity = try? context.fetch(ProjectEntity.fetchRequest())
                .first(where: { $0.id == project.id }) {
                taskEntity.project = projectEntity
            }
            
            do {
                try context.save()
                print("任务保存到 CoreData 成功")
            } catch {
                print("保存任务失败: \(error)")
            }
            
            handleTaskChange(task: task, in: project)
        }
    }
    
    func deleteTask(_ task: ProjectTask, from project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            // 从内存中删除
            projects[projectIndex].tasks.removeAll(where: { $0.id == task.id })
            
            // 从 CoreData 中删除
            let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            
            if let taskEntity = try? context.fetch(fetchRequest).first {
                context.delete(taskEntity)
                
                do {
                    try context.save()
                    print("任务删除成功")
                } catch {
                    print("删除任务失败: \(error)")
                }
            }
            
            NotificationManager.shared.removeTaskReminders(for: task)
        }
    }
    
    // 添加 CoreData 相关方法
    func saveLocation(_ location: Location, for project: Project) {
        // 1. 先获取或创建 ProjectEntity
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        
        let projectEntity: ProjectEntity
        if let existingProject = try? context.fetch(fetchRequest).first {
            projectEntity = existingProject
        } else {
            // 如果项目不存在，创建新的
            projectEntity = project.toEntity(context: context)
        }
        
        // 2. 创建 LocationEntity 并设置关系
        let locationEntity = location.toEntity(context: context)
        locationEntity.project = projectEntity  // 设置必需的关系
        
        // 3. 保存到 CoreData
        do {
            try context.save()
            print("位置保存到 CoreData 成功")
            
            // 4. 更新内存中的数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].locations.append(location)
            }
        } catch {
            print("保存位置失败: \(error)")
        }
    }
    
    // 其他 CoreData 相关方法...
    
    static func withTestData(context: NSManagedObjectContext) -> ProjectStore {
        let store = ProjectStore(context: context)
        
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
                    phone: "131001000",
                    idNumber: "110101199001011234",
                    bankAccount: "62220212347890",
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
