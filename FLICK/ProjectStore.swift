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
        print("========== 开始加载项目 ==========")
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        
        do {
            let projectEntities = try context.fetch(fetchRequest)
            print("从 CoreData 加载到 \(projectEntities.count) 个项目")
            
            // 按照创建时间排序
            self.projects = projectEntities.compactMap { projectEntity -> Project? in
                guard let id = projectEntity.id,
                      let name = projectEntity.name,
                      let startDate = projectEntity.startDate else {
                    print("❌ 项目实体缺少必要属性")
                    return nil
                }
                
                // 获取项目的所有任务
                let tasks = (projectEntity.tasks?.allObjects as? [TaskEntity])?.compactMap { taskEntity -> ProjectTask? in
                    guard let taskId = taskEntity.id,
                          let title = taskEntity.title,
                          let assignee = taskEntity.assignee,
                          let dueDate = taskEntity.dueDate else {
                        print("❌ 任务实体缺少必要属性")
                        return nil
                    }
                    
                    let reminder = taskEntity.reminder.flatMap { ProjectTask.TaskReminder(rawValue: $0) }
                    
                    return ProjectTask(
                        id: taskId,
                        title: title,
                        assignee: assignee,
                        dueDate: dueDate,
                        isCompleted: taskEntity.isCompleted,
                        reminder: reminder,
                        reminderHour: Int(taskEntity.reminderHour)
                    )
                } ?? []
                
                let project = Project(
                    id: id,
                    name: name,
                    director: projectEntity.director ?? "",
                    producer: projectEntity.producer ?? "",
                    startDate: startDate,
                    status: Project.Status(rawValue: projectEntity.status ?? "") ?? .preProduction,
                    color: projectEntity.color.flatMap { Color(data: $0) } ?? .blue,
                    tasks: tasks,
                    invoices: [],
                    locations: [],
                    accounts: [],
                    isLocationScoutingEnabled: projectEntity.isLocationScoutingEnabled
                )
                
                print("✓ 成功加载项目: \(name)")
                print("  - ID: \(id)")
                print("  - 任务数量: \(tasks.count)")
                
                return project
            }
            
            print("✓ 成功加载 \(projects.count) 个项目")
        } catch {
            print("❌ 从 CoreData 加载项目失败: \(error)")
            print("错误描述: \(error.localizedDescription)")
            
            // 出错时尝试从 UserDefaults 加载
            if let data = UserDefaults.standard.data(forKey: "savedProjects"),
               let decoded = try? JSONDecoder().decode([Project].self, from: data) {
                self.projects = decoded
                print("✓ 从 UserDefaults 加载了 \(projects.count) 个项目")
            }
        }
        print("================================")
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
        print("========== 开始添加项目 ==========")
        print("项目信息: \(project.name), ID: \(project.id)")
        
        // 1. 检查是否已存在
        let checkRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        checkRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        
        do {
            let existingProjects = try context.fetch(checkRequest)
            if let existing = existingProjects.first {
                print("⚠️ 项目已存在，ID: \(existing.id?.uuidString ?? "nil")")
                return
            }
        } catch {
            print("❌ 检查现有项目失败: \(error)")
        }
        
        // 2. 创建 ProjectEntity
        let projectEntity = project.toEntity(context: context)
        print("✓ 已创建 ProjectEntity")
        print("Entity ID: \(projectEntity.id?.uuidString ?? "nil")")
        print("Entity 名称: \(projectEntity.name ?? "nil")")
        
        // 3. 保存到 CoreData
        do {
            try context.save()
            print("✓ 成功保存到 CoreData")
            
            // 4. 添加到内存中的数组
            projects.append(project)
            print("✓ 已添加到内存数组，当前共有 \(projects.count) 个项目")
            
            // 5. 验证数据
            let verifyRequest = ProjectEntity.fetchRequest()
            verifyRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            let verifyResult = try context.fetch(verifyRequest)
            print("验证查询结果: \(verifyResult.count) 个匹配项目")
            if let verified = verifyResult.first {
                print("✓ 验证成功")
                print("验证 ID: \(verified.id?.uuidString ?? "nil")")
                print("验证名称: \(verified.name ?? "nil")")
            }
        } catch {
            print("❌ 保存项目失败: \(error)")
            print("错误详情: \(error)")
        }
        print("================================")
    }
    
    // 删除项目
    func deleteProject(_ project: Project) {
        // 从 CoreData 中删除
        if let projectEntity = try? context.fetch(ProjectEntity.fetchRequest())
            .first(where: { $0.id == project.id }) {
            context.delete(projectEntity)
            saveContext()
        }
        
        // 从内存中删除
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects.remove(at: index)
        }
    }
    
    // 更新项目
    func updateProject(_ updatedProject: Project) {
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }),
           let projectEntity = try? context.fetch(ProjectEntity.fetchRequest())
            .first(where: { $0.id == updatedProject.id }) {
            
            // 更新 CoreData 实体
            projectEntity.name = updatedProject.name
            projectEntity.director = updatedProject.director
            projectEntity.producer = updatedProject.producer
            projectEntity.startDate = updatedProject.startDate
            projectEntity.status = updatedProject.status.rawValue
            projectEntity.color = updatedProject.color.toData()
            projectEntity.isLocationScoutingEnabled = updatedProject.isLocationScoutingEnabled
            
            // 保存更改
            saveContext()
            
            // 更新内存中的项目并触发视图刷新
            DispatchQueue.main.async {
                self.projects[index] = updatedProject
                self.objectWillChange.send()  // 显式通知视图更新
            }
        }
    }
    
    // 保存上下文的辅助方法
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("保存 CoreData 失败: \(error)")
            }
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
        print("========== 开始更新任务 ==========")
        print("任务信息: \(task.title), ID: \(task.id)")
        print("所属项目: \(project.name), ID: \(project.id)")
        
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
           let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == task.id }) {
            // 1. 更新内存中的数据
            projects[projectIndex].tasks[taskIndex] = task
            print("✓ 已更新内存中的任务")
            
            // 2. 更新或创建 CoreData 实体
            let taskFetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            taskFetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            
            do {
                let results = try context.fetch(taskFetchRequest)
                print("找到匹配的任务实体数量: \(results.count)")
                
                let taskEntity: TaskEntity
                if let existingTask = results.first {
                    print("✓ 找到任务实体，正在更新")
                    taskEntity = existingTask
                } else {
                    print("⚠️ 未找到任务实体，正在创建新实体")
                    taskEntity = TaskEntity(context: context)
                    taskEntity.id = task.id
                    
                    // 关联到项目
                    let projectFetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                    projectFetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
                    
                    if let projectEntity = try context.fetch(projectFetchRequest).first {
                        print("✓ 找到项目实体")
                        taskEntity.project = projectEntity
                    } else {
                        print("⚠️ 未找到项目实体，正在创建")
                        let projectEntity = project.toEntity(context: context)
                        taskEntity.project = projectEntity
                    }
                }
                
                // 更新任务实体的属性
                taskEntity.title = task.title
                taskEntity.assignee = task.assignee
                taskEntity.dueDate = task.dueDate
                taskEntity.isCompleted = task.isCompleted
                taskEntity.reminder = task.reminder?.rawValue
                taskEntity.reminderHour = Int16(task.reminderHour)
                
                try context.save()
                print("✓ 成功保存到 CoreData")
                
                // 处理提醒
                if task.isCompleted {
                    NotificationManager.shared.removeTaskReminders(for: task)
                    print("✓ 已移除任务提醒")
                } else if let reminder = task.reminder {
                    NotificationManager.shared.scheduleTaskReminder(for: task, in: project)
                    print("✓ 已更新任务提醒")
                }
            } catch {
                print("❌ 更新任务失败: \(error)")
                print("错误描述: \(error.localizedDescription)")
            }
        } else {
            print("❌ 未找到对应的任务或项目")
        }
        print("================================")
    }
    
    func addTask(_ task: ProjectTask, to project: Project) {
        print("========== 开始添加任务 ==========")
        print("任务信息: \(task.title), ID: \(task.id)")
        print("目标项目: \(project.name), ID: \(project.id)")
        
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            // 1. 更新内存中的数据
            projects[index].tasks.append(task)
            print("✓ 已添加到内存数组")
            print("当前内存中任务数量: \(projects[index].tasks.count)")
            
            // 2. 保存到 CoreData
            let taskEntity = task.toEntity(context: context)
            print("✓ TaskEntity 创建成功")
            print("TaskEntity ID: \(taskEntity.id?.uuidString ?? "nil")")
            print("TaskEntity 标题: \(taskEntity.title ?? "nil")")
            
            // 3. 设置与 Project 的关系
            let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            fetchRequest.fetchLimit = 1  // 限制只获取一个结果
            
            do {
                let projectEntities = try context.fetch(fetchRequest)
                print("查询结果数量: \(projectEntities.count)")
                
                if let projectEntity = projectEntities.first {
                    print("✓ 找到项目实体")
                    print("项目实体 ID: \(projectEntity.id?.uuidString ?? "nil")")
                    print("项目实体名称: \(projectEntity.name ?? "nil")")
                    
                    taskEntity.project = projectEntity
                    print("✓ 已建立任务与项目的关系")
                    
                    try context.save()
                    print("✓ 成功保存到 CoreData")
                } else {
                    print("❌ 错误：未找到项目实体，尝试重新创建")
                    // 如果找不到项目实体，重新创建一个
                    let newProjectEntity = project.toEntity(context: context)
                    taskEntity.project = newProjectEntity
                    try context.save()
                    print("✓ 已创建新的项目实体并保存")
                }
            } catch {
                print("❌ 错误：保存任务失败")
                print("错误详情: \(error)")
                print("错误描述: \(error.localizedDescription)")
            }
        } else {
            print("❌ 错误：未找到对应的项目")
            print("当前项目数量: \(projects.count)")
            print("查找的项目 ID: \(project.id)")
        }
        print("================================")
    }
    
    func deleteTask(_ task: ProjectTask, from project: Project) {
        print("========== 开始删除任务 ==========")
        print("任务信息: \(task.title), ID: \(task.id)")
        print("所属项目: \(project.name), ID: \(project.id)")
        
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            // 1. 从内存中删除
            projects[projectIndex].tasks.removeAll(where: { $0.id == task.id })
            print("✓ 已从内存中删除任务")
            
            // 2. 从 CoreData 中删除
            let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                print("找到匹配的任务实体数量: \(results.count)")
                
                if let taskEntity = results.first {
                    print("✓ 找到任务实体")
                    context.delete(taskEntity)
                    try context.save()
                    print("✓ 成功从 CoreData 中删除任务")
                    
                    // 移除提醒
                    NotificationManager.shared.removeTaskReminders(for: task)
                    print("✓ 已移除任务提醒")
                } else {
                    print("⚠️ 未找到对应的任务实体")
                }
            } catch {
                print("❌ 删除任务失败: \(error)")
                print("错误描述: \(error.localizedDescription)")
            }
        }
        print("================================")
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
            id: UUID(),
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
            locations: [],  // 确保 invoices 在 locations 之前
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
            id: UUID(),
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
            locations: [],  // 确保 invoices 在 locations 之前
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
            id: UUID(),
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
            locations: [],  // 确保 invoices 在 locations 之前
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
    
    func toggleTaskCompletion(_ task: ProjectTask, in project: Project) {
        print("========== 切换任务完成状态 ==========")
        print("任务信息: \(task.title), ID: \(task.id)")
        print("所属项目: \(project.name), ID: \(project.id)")
        
        // 创建新的任务对象，切换完成状态
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        print("任务状态: \(updatedTask.isCompleted ? "已完成" : "未完成")")
        
        // 更新任务
        updateTask(updatedTask, in: project)
        
        // 处理提醒
        if updatedTask.isCompleted {
            NotificationManager.shared.removeTaskReminders(for: task)
            print("✓ 已移除任务提醒")
        } else if let reminder = task.reminder {
            NotificationManager.shared.scheduleTaskReminder(for: task, in: project)
            print("✓ 已重新设置任务提醒")
        }
        print("================================")
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
