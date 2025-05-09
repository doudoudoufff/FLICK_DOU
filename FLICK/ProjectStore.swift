import SwiftUI
import CoreData

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @Published var syncStatus: CloudKitSyncStatus = .unknown  // 添加同步状态
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    let context: NSManagedObjectContext
    private var syncObserver: Any?  // 添加同步观察器
    @Published var lastError: Error?
    
    // 修改同步状态枚举
    enum CloudKitSyncStatus: Equatable {
        case unknown
        case syncing
        case synced
        case error(Error)
        
        var description: String {
            switch self {
            case .unknown: return "等待同步"
            case .syncing: return "正在同步..."
            case .synced: return "已同步"
            case .error(let error): return "同步错误: \(error.localizedDescription)"
            }
        }
        
        // 添加 Equatable 实现
        static func == (lhs: CloudKitSyncStatus, rhs: CloudKitSyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown),
                 (.syncing, .syncing),
                 (.synced, .synced):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        print("========== ProjectStore 初始化 ==========")
        self.context = context
        ProjectStore.shared = self
        loadProjects()
        setupSyncMonitoring()  // 添加同步监控
        print("- Context: \(context)")
        print("- 已加载项目数量: \(projects.count)")
        print("=====================================")
    }
    
    // 添加同步监控设置
    private func setupSyncMonitoring() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            
            switch cloudEvent.type {
            case .setup, .import, .export:
                self.syncStatus = .syncing
            @unknown default:
                break
            }
            
            if cloudEvent.endDate != nil {
                self.syncStatus = .synced
                // 同步完成后重新加载数据
                self.loadProjects()
            }
            
            if let error = cloudEvent.error {
                self.syncStatus = .error(error)
            }
        }
    }
    
    // 修改 ProjectStore 类中的 sync 方法
    func sync() {
        syncStatus = .syncing
        
        // 使用 PersistenceController 的同步方法
        PersistenceController.shared.syncWithCloud { success, error in
            DispatchQueue.main.async {
                if success {
                    self.syncStatus = .synced
                    print("✓ 同步成功")
                    
                    // 更新上次同步时间
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSyncTime")
                    
                    // 同步成功后重新加载项目
                    self.loadProjects()
                } else if let error = error {
                    self.syncStatus = .error(error)
                    print("❌ 同步失败: \(error.localizedDescription)")
                }
                
                // 通知 UI 刷新
                NotificationCenter.default.post(name: .CoreDataDidSync, object: nil)
            }
        }
    }
    
    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func loadProjects() {
        print("开始加载项目数据...")
        let request = ProjectEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            print("从 CoreData 加载了 \(entities.count) 个项目实体")
            
            var loadedProjects: [Project] = []
            for entity in entities {
                let project = mapProjectEntityToProject(entity)
                loadedProjects.append(project)
            }
            
            DispatchQueue.main.async {
                self.projects = loadedProjects
                print("✓ 成功加载 \(loadedProjects.count) 个项目")
            }
        } catch {
            print("❌ 加载项目失败: \(error)")
        }
    }
    
    func saveProjects() {
        print("========== 开始保存项目 ==========")
        print("待保存项目数量: \(projects.count)")
        
        // 保存到 CoreData
        for project in projects {
            print("""
            处理项目:
            - ID: \(project.id)
            - 名称: \(project.name)
            - 场地数量: \(project.locations.count)
            """)
            
            let projectEntity = project.toEntity(context: context)
            
            // 保存场地和照片
            for location in project.locations {
                print("""
                处理场地:
                - ID: \(location.id)
                - 名称: \(location.name)
                - 照片数量: \(location.photos.count)
                """)
                
                let locationEntity = location.toEntity(context: context)
                locationEntity.project = projectEntity
                
                // 保存照片
                for photo in location.photos {
                    print("创建照片实体: \(photo.id)")
                    let photoEntity = photo.toEntity(context: context)
                    photoEntity.location = locationEntity
                }
            }
            
            // 保存任务
            for task in project.tasks {
                let taskEntity = task.toEntity(context: context)
                taskEntity.project = projectEntity
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
            print("✓ CoreData 保存成功")
        } catch {
            print("""
            ❌ 保存失败:
            错误类型: \(type(of: error))
            错误描述: \(error.localizedDescription)
            堆栈跟踪: \(error)
            """)
        }
        
        // 临时：同时保存到 UserDefaults（作为备份）
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
        }
        
        // 如果启用了 iCloud 同步，则触发同步
        if enableCloudSync {
            print("iCloud 同步已启用，触发自动同步")
            sync()
        } else {
            print("iCloud 同步未启用，跳过自动同步")
        }
        
        print("================================")
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
            
            // 4. 添加到内存中的数组（插入到最前面）
            projects.insert(project, at: 0)
            print("✓ 已添加到内存数组，当前共有 \(projects.count) 个项目")
            
            // 5. 验证数据
            let verifyRequest = ProjectEntity.fetchRequest()
            verifyRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            let verifyResult = try context.fetch(verifyRequest)
            print("验证查询结果: \(verifyResult.count) 个匹配项目")
            if let verified = verifyResult.first {
                print("✓ 验证成功")
                print("验证项目名称: \(verified.name ?? "nil")")
            }
        } catch {
            print("❌ 保存失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
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
            projectEntity.logoData = updatedProject.logoData  // 添加LOGO数据的更新
            
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
    
    // 添加任务
    func addTask(_ task: ProjectTask, to project: Project) {
        print("========== 开始添加任务 ==========")
        print("任务信息:")
        print("- 标题: \(task.title)")
        print("- 负责人: \(task.assignee ?? "")")
        print("- 截止时间: \(task.dueDate)")
        
        guard let projectEntity = project.fetchEntity(in: context) else {
            print("❌ 错误：找不到项目实体")
            return
        }
        
        // 创建任务实体
        let taskEntity = TaskEntity(context: context)
        taskEntity.id = task.id
        taskEntity.title = task.title
        taskEntity.assignee = task.assignee
        taskEntity.dueDate = task.dueDate
        taskEntity.isCompleted = task.isCompleted
        taskEntity.project = projectEntity
        
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            // 更新内存中的数据
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                projects[projectIndex].tasks.append(task)
                objectWillChange.send()
                print("✓ 内存数据更新成功")
            }
            
            // 触发 CoreData 同步
            PersistenceController.shared.save()
            
            // 手动触发 CloudKit 同步
            PersistenceController.shared.syncWithCloud { success, error in
                if success {
                    print("✓ 任务信息同步到 iCloud 成功")
                    
                    // 同步成功后重新加载项目
                    self.loadProjects()
                } else if let error = error {
                    print("❌ 任务信息同步到 iCloud 失败: \(error)")
                }
                }
            } catch {
            print("❌ 保存失败:")
            print("错误类型: \(type(of: error))")
                print("错误描述: \(error.localizedDescription)")
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
    
    // 添加场地
    func addLocation(_ location: Location, to project: Project) {
        print("========== 开始添加场地 ==========")
        print("场地信息:")
        print("- ID: \(location.id)")
        print("- 名称: \(location.name)")
        print("- 类型: \(location.type.rawValue)")
        print("- 状态: \(location.status.rawValue)")
        print("- 地址: \(location.address)")
        if let contactName = location.contactName {
            print("- 联系人: \(contactName)")
        }
        if let contactPhone = location.contactPhone {
            print("- 电话: \(contactPhone)")
        }
        if let notes = location.notes {
            print("- 备注: \(notes)")
        }
        print("- 照片数量: \(location.photos.count)")
        print("- 创建日期: \(location.date)")
        
        print("\n所属项目:")
        print("- 名称: \(project.name)")
        print("- ID: \(project.id)")
        
        // 1. 获取或创建 ProjectEntity
        guard let projectEntity = project.fetchEntity(in: context) else {
            print("❌ 错误：找不到项目实体")
            return
        }
        print("✓ 找到项目实体")
        
        // 2. 创建 LocationEntity
        let locationEntity = location.toEntity(context: context)
        locationEntity.project = projectEntity
        print("✓ 创建场地实体并设置关系")
        
        do {
            // 3. 保存到 CoreData
            try context.save()
            print("✓ CoreData 保存成功")
            
            // 4. 更新内存中的数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].locations.append(location)
                objectWillChange.send()
                print("✓ 内存数据更新成功")
                print("当前场地数量: \(projects[index].locations.count)")
            }
            
            // 5. 验证数据
            let verifyRequest = LocationEntity.fetchRequest()
            verifyRequest.predicate = NSPredicate(format: "id == %@", location.id as CVarArg)
            if let verifiedLocation = try context.fetch(verifyRequest).first {
                print("\n✓ 数据验证成功:")
                print("- 实体ID: \(verifiedLocation.id?.uuidString ?? "nil")")
                print("- 实体名称: \(verifiedLocation.name ?? "nil")")
                print("- 实体地址: \(verifiedLocation.address ?? "nil")")
                print("- 实体照片数: \(verifiedLocation.photos?.count ?? 0)")
            }
        } catch {
            print("❌ 保存失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
        }
        
        print("================================")
    }
    
    // 更新位置
    func updateLocation(_ location: Location, in project: Project) async {
        print("========== 开始更新场地 ==========")
        print("场地信息:")
        print("- ID: \(location.id)")
        print("- 名称: \(location.name)")
        print("- 类型: \(location.type.rawValue)")
        print("- 状态: \(location.status.rawValue)")
        print("- 地址: \(location.address)")
        if location.hasCoordinates {
            print("- 坐标: 纬度 \(location.latitude!), 经度 \(location.longitude!)")
        } else {
            print("- 坐标: 未设置")
        }
        
        // 1. 查找要更新的 LocationEntity
        let request = LocationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", 
            location.id as CVarArg, project.id as CVarArg)
        
        if let entity = try? context.fetch(request).first {
            print("✓ 找到场地实体")
            
            // 2. 更新实体
            entity.name = location.name
            entity.type = location.type.rawValue
            entity.status = location.status.rawValue
            entity.address = location.address
            entity.contactName = location.contactName
            entity.contactPhone = location.contactPhone
            entity.notes = location.notes
            
            // 更新坐标信息
            if location.hasCoordinates, let lat = location.latitude, let lng = location.longitude {
                print("✓ 更新坐标: 纬度 \(lat), 经度 \(lng)")
                entity.latitude = lat
                entity.longitude = lng
                entity.hasCoordinates = true
            } else {
                print("✓ 清除坐标信息")
                entity.latitude = 0
                entity.longitude = 0
                entity.hasCoordinates = false
            }
            
            print("✓ 实体数据更新完成")
            
            do {
                // 3. 保存更改
                try context.save()
                print("✓ CoreData 保存成功")
                
                // 4. 更新内存中的数据
                await MainActor.run {
                    if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
                       let locationIndex = projects[projectIndex].locations.firstIndex(where: { $0.id == location.id }) {
                        // 创建更新后的位置对象
                        var updatedLocation = location
                        
                        // 确保坐标信息正确
                        if location.hasCoordinates {
                            print("✓ 内存模型保留坐标: 纬度 \(location.latitude!), 经度 \(location.longitude!)")
                        } else {
                            print("✓ 内存模型清除坐标")
                        }
                        
                        // 更新内存中的位置
                        projects[projectIndex].locations[locationIndex] = updatedLocation
                        print("✓ 内存数据更新成功")
                        objectWillChange.send()
                        print("✓ 发送视图更新通知")
                    }
                }
                
                // 5. 触发 CoreData 同步
                PersistenceController.shared.save()
                print("✓ 触发 CoreData 保存")
            } catch {
                print("❌ 保存失败:")
                print("- 错误信息: \(error)")
            }
        } else {
            print("❌ 错误：找不到场地实体")
        }
        print("================================")
    }
    
    // 删除位置
    func deleteLocation(_ location: Location, from project: Project) {
        print("========== 开始删除场地 ==========")
        print("场地信息:")
        print("- ID: \(location.id)")
        print("- 名称: \(location.name)")
        
        // 1. 查找要删除的 LocationEntity
        let request = LocationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", 
            location.id as CVarArg, project.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                print("✓ 找到场地实体")
                
                // 2. 删除实体
                context.delete(entity)
                try context.save()
                print("✓ CoreData 删除成功")
                
                // 3. 更新内存中的数据
                if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[projectIndex].locations.removeAll { $0.id == location.id }
                    print("✓ 内存数据更新成功")
                    objectWillChange.send()
                    print("✓ 发送视图更新通知")
                }
            } else {
                print("❌ 错误：找不到场地实体")
            }
        } catch {
            print("❌ 删除失败:")
            print("- 错误信息: \(error)")
        }
        print("================================")
    }
    
    // 添加发票
    func addInvoice(_ invoice: Invoice, to project: Project) {
        guard let projectEntity = project.fetchEntity(in: context) else {
            print("找不到项目实体")
            lastError = NSError(domain: "ProjectStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到项目实体"])
            return
        }
        
        let invoiceEntity = invoice.toEntity(context: context)
        invoiceEntity.project = projectEntity
        
        do {
            try context.save()
            print("发票保存成功")
            lastError = nil
            
            // 更新内存中的项目数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].invoices.append(invoice)  // 添加到内存中的发票数组
                objectWillChange.send()  // 通知视图更新
            }
            
            // 触发 CoreData 同步
            PersistenceController.shared.save()
            
            // 手动触发 CloudKit 同步
            PersistenceController.shared.syncWithCloud { success, error in
                if success {
                    print("✓ 发票信息同步到 iCloud 成功")
                    
                    // 同步成功后重新加载项目
                    self.loadProjects()
                } else if let error = error {
                    print("❌ 发票信息同步到 iCloud 失败: \(error)")
                }
            }
        } catch {
            print("保存发票失败: \(error)")
            lastError = error
        }
    }
    
    // 更新发票
    func updateInvoice(_ invoice: Invoice, in project: Project) {
        print("开始更新发票...")
        // 1. 先更新内存中的数据
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
           let invoiceIndex = projects[projectIndex].invoices.firstIndex(where: { $0.id == invoice.id }) {
            projects[projectIndex].invoices[invoiceIndex] = invoice
            objectWillChange.send()
        } else {
            print("❌ 未找到对应的项目或发票")
            return
        }
        // 2. 更新 CoreData 实体
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        do {
            if let projectEntity = try context.fetch(fetchRequest).first,
               let invoiceEntity = (projectEntity.invoices?.allObjects as? [InvoiceEntity])?.first(where: { $0.id == invoice.id }) {
                invoiceEntity.name = invoice.name
                invoiceEntity.phone = invoice.phone
                invoiceEntity.idNumber = invoice.idNumber
                invoiceEntity.bankAccount = invoice.bankAccount
                invoiceEntity.bankName = invoice.bankName
                invoiceEntity.date = invoice.date
                invoiceEntity.amount = invoice.amount
                invoiceEntity.category = invoice.category.rawValue
                invoiceEntity.status = invoice.status.rawValue
                invoiceEntity.dueDate = invoice.dueDate
                invoiceEntity.notes = invoice.notes
                invoiceEntity.invoiceCode = invoice.invoiceCode
                invoiceEntity.invoiceNumber = invoice.invoiceNumber
                invoiceEntity.sellerName = invoice.sellerName
                invoiceEntity.sellerTaxNumber = invoice.sellerTaxNumber
                invoiceEntity.sellerAddress = invoice.sellerAddress
                invoiceEntity.sellerBankInfo = invoice.sellerBankInfo
                invoiceEntity.buyerAddress = invoice.buyerAddress
                invoiceEntity.buyerBankInfo = invoice.buyerBankInfo
                invoiceEntity.goodsList = invoice.goodsList?.joined(separator: ",")
                invoiceEntity.totalAmount = invoice.totalAmount ?? 0.0
                try context.save()
                print("✓ 发票已保存到 CoreData")
            } else {
                print("❌ 未找到发票实体")
            }
        } catch {
            print("发票更新失败：\(error)")
        }
    }
    
    // 删除发票
    func deleteInvoice(_ invoice: Invoice, from project: Project) {
        print("开始删除发票...")
        guard let projectEntity = project.fetchEntity(in: context),
              let invoiceEntity = projectEntity.invoices?
                .first(where: { ($0 as? InvoiceEntity)?.id == invoice.id }) as? InvoiceEntity
        else {
            print("错误：找不到发票实体")
            return
        }
        
        context.delete(invoiceEntity)
        
        do {
            try context.save()
            print("发票删除成功：\(invoice.name)")
            
            // 更新内存中的项目数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                // 从内存中移除已删除的发票
                projects[index].invoices.removeAll { $0.id == invoice.id }
                objectWillChange.send()  // 通知视图更新
            }
            // 强制刷新所有项目数据
            self.loadProjects()
        } catch {
            print("发票删除失败：\(error)")
        }
    }
    
    // 删除账户
    func deleteAccount(_ account: Account, from project: Project) {
        print("========== 开始删除账户 ==========")
        print("账户名称: \(account.name)")
        print("账户ID: \(account.id)")
        print("项目名称: \(project.name)")
        print("项目ID: \(project.id)")
        
        // 1. 首先获取所有 AccountEntity
        let fetchRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND project.id == %@", account.id as CVarArg, project.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let accountEntity = results.first {
                // 2. 删除找到的实体
                context.delete(accountEntity)
                try context.save()
                print("✓ CoreData 删除成功")
                
                // 3. 更新内存中的项目数据
                if let index = projects.firstIndex(where: { $0.id == project.id }) {
                    let oldCount = projects[index].accounts.count
                    projects[index].accounts.removeAll { $0.id == account.id }
                    let newCount = projects[index].accounts.count
                    print("账户数量变化: \(oldCount) -> \(newCount)")
                    
                    // 4. 确保项目数据也被更新
                    let updatedProject = projects[index]
                    DispatchQueue.main.async {
                        self.projects[index] = updatedProject
                        self.objectWillChange.send()
                        print("✓ 内存数据更新完成")
                    }
                } else {
                    print("❌ 找不到对应的项目")
                }
            } else {
                print("❌ 错误：找不到账户实体")
            }
        } catch {
            print("❌ 删除失败：\(error)")
        }
        print("================================")
    }
    
    // 添加账户
    func addAccount(to project: Project, account: Account) {
        print("========== 添加账户信息 ==========")
        print("项目: \(project.name)")
        print("账户: \(account.name)")
        
        // 获取项目实体
        guard let projectEntity = fetchProjectEntity(id: project.id) else {
            print("❌ 找不到项目实体")
            return
        }
        
        // 创建账户实体
        let accountEntity = AccountEntity(context: context)
        accountEntity.id = account.id
        accountEntity.name = account.name
        accountEntity.type = account.type.rawValue  // 使用 rawValue 转换为字符串
        accountEntity.bankName = account.bankName
        accountEntity.bankBranch = account.bankBranch
        accountEntity.bankAccount = account.bankAccount
        accountEntity.contactName = account.contactName
        accountEntity.contactPhone = account.contactPhone
        accountEntity.idNumber = account.idNumber
        accountEntity.notes = account.notes
        
        // 关联到项目
        accountEntity.project = projectEntity
        
        // 保存上下文
        do {
            try context.save()
            print("✓ 账户信息保存成功")
            
            // 更新内存中的项目对象
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                // 创建新的账户对象
                let newAccount = Account(
                    id: account.id,
                    name: account.name,
                    type: account.type,
                    bankName: account.bankName,
                    bankBranch: account.bankBranch,
                    bankAccount: account.bankAccount,
                    idNumber: account.idNumber,
                    contactName: account.contactName,
                    contactPhone: account.contactPhone,
                    notes: account.notes
                )
                
                // 添加到项目的账户列表中
                projects[index].accounts.append(newAccount)
                print("✓ 账户已添加到内存中的项目")
                
                // 通知视图更新
                objectWillChange.send()
            }
            
            // 触发 CoreData 同步
            PersistenceController.shared.save()
            
            // 手动触发 CloudKit 同步
            PersistenceController.shared.syncWithCloud { success, error in
                if success {
                    print("✓ 账户信息同步到 iCloud 成功")
                    
                    // 同步成功后重新加载项目
                    self.loadProjects()
                } else if let error = error {
                    print("❌ 账户信息同步到 iCloud 失败: \(error)")
                }
            }
        } catch {
            print("❌ 账户信息保存失败: \(error)")
        }
        
        print("================================")
    }
    
    // 更新账户
    func updateAccount(_ account: Account, in project: Project) {
        print("========== 开始更新账户 ==========")
        print("账户信息:")
        print("- ID: \(account.id)")
        print("- 名称: \(account.name)")
        print("- 类型: \(account.type.rawValue)")
        print("- 开户行: \(account.bankName)")
        print("- 支行: \(account.bankBranch)")
        print("- 账号: \(account.bankAccount)")
        print("- 联系人: \(account.contactName)")
        print("- 联系电话: \(account.contactPhone)")
        if let notes = account.notes {
            print("- 备注: \(notes)")
        }
        
        print("\n所属项目:")
        print("- 名称: \(project.name)")
        print("- ID: \(project.id)")
        
        // 1. 更新 CoreData
        guard let projectEntity = project.fetchEntity(in: context),
              let accountEntity = projectEntity.accounts?
                .first(where: { ($0 as? AccountEntity)?.id == account.id }) as? AccountEntity
        else {
            print("❌ 错误：找不到账户实体")
            return
        }
        
        print("\n开始更新 CoreData...")
        
        // 更新账户实体
        accountEntity.name = account.name
        accountEntity.type = account.type.rawValue
        accountEntity.bankName = account.bankName
        accountEntity.bankBranch = account.bankBranch
        accountEntity.bankAccount = account.bankAccount
        accountEntity.contactName = account.contactName
        accountEntity.contactPhone = account.contactPhone
        accountEntity.notes = account.notes
        print("✓ 账户实体更新成功")
        
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            // 2. 更新内存中的数据
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                // 更新内存中的账户数组
                if let accountIndex = projects[projectIndex].accounts.firstIndex(where: { $0.id == account.id }) {
                    projects[projectIndex].accounts[accountIndex] = account
                    print("✓ 内存数据更新成功")
                    
                    // 3. 确保项目数据也被更新
                    let updatedProject = projects[projectIndex]
                    DispatchQueue.main.async {
                        self.projects[projectIndex] = updatedProject
                        self.objectWillChange.send()
                        print("✓ 视图更新通知已发送")
                    }
                }
            } else {
                print("❌ 错误：找不到对应的项目")
            }
        } catch {
            print("❌ 更新失败:")
            print("- 错误信息: \(error)")
        }
        print("================================")
    }
    
    // 添加照片
    func addPhotos(_ photos: [LocationPhoto], to location: Location, in project: Project) async {
        print("========== 开始添加照片 ==========")
        print("项目: \(project.name)")
        print("场地: \(location.name)")
        print("照片数量: \(photos.count)")
        
        guard let projectEntity = project.fetchEntity(in: context),
              let locationEntity = location.fetchEntity(in: context) else {
            print("❌ 错误：找不到项目或场地实体")
            return
        }
        print("✓ 已找到项目和场地实体")
        
        for photo in photos {
            print("\n处理照片:")
            print("- ID: \(photo.id)")
            print("- 日期: \(photo.date)")
            if let note = photo.note {
                print("- 备注: \(note)")
            }
            
            let photoEntity = LocationPhotoEntity(context: context)
            photoEntity.id = photo.id
            photoEntity.imageData = photo.imageData
            photoEntity.date = photo.date
            photoEntity.weather = photo.weather
            photoEntity.note = photo.note
            photoEntity.location = locationEntity
            print("✓ 已创建照片实体")
        }
        
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            if let index = projects.firstIndex(where: { $0.id == project.id }),
               let locationIndex = projects[index].locations.firstIndex(where: { $0.id == location.id }) {
                projects[index].locations[locationIndex].photos.append(contentsOf: photos)
                objectWillChange.send()
                print("✓ 内存数据更新成功")
                print("当前场地照片总数: \(projects[index].locations[locationIndex].photos.count)")
            }
        } catch {
            print("❌ 保存照片失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
        }
        print("================================")
    }
    
    // 更新照片
    func updatePhoto(_ photo: LocationPhoto, in location: Location, project: Project) async {
        print("========== 开始更新照片 ==========")
        print("项目: \(project.name)")
        print("场地: \(location.name)")
        print("照片ID: \(photo.id)")
        if let note = photo.note {
            print("新备注: \(note)")
        }
        
        guard let projectEntity = project.fetchEntity(in: context),
              let locationEntity = location.fetchEntity(in: context),
              let photoEntity = (locationEntity.photos?.allObjects as? [LocationPhotoEntity])?
                .first(where: { $0.id == photo.id }) else {
            print("❌ 错误：找不到照片实体")
            return
        }
        print("✓ 已找到照片实体")
        
        // 更新照片实体
        photoEntity.note = photo.note
        print("✓ 已更新照片备注")
        
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
               let locationIndex = projects[projectIndex].locations.firstIndex(where: { $0.id == location.id }),
               let photoIndex = projects[projectIndex].locations[locationIndex].photos.firstIndex(where: { $0.id == photo.id }) {
                // 更新内存中的数据
                projects[projectIndex].locations[locationIndex].photos[photoIndex] = photo
                objectWillChange.send()
                print("✓ 内存数据更新成功")
            }
        } catch {
            print("❌ 更新照片失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
        }
        print("================================")
    }
    
    // 删除照片
    func deletePhoto(_ photo: LocationPhoto, from location: Location, in project: Project) async {
        print("========== 开始删除照片 ==========")
        print("项目: \(project.name)")
        print("场地: \(location.name)")
        print("照片ID: \(photo.id)")
        
        guard let projectEntity = project.fetchEntity(in: context),
              let locationEntity = location.fetchEntity(in: context),
              let photoEntity = (locationEntity.photos?.allObjects as? [LocationPhotoEntity])?
                .first(where: { $0.id == photo.id }) else {
            print("❌ 错误：找不到照片实体")
            return
        }
        print("✓ 已找到照片实体")
        
        // 从CoreData中删除照片实体
        context.delete(photoEntity)
        print("✓ 已从CoreData中删除照片实体")
        
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
               let locationIndex = projects[projectIndex].locations.firstIndex(where: { $0.id == location.id }) {
                // 更新内存中的数据
                projects[projectIndex].locations[locationIndex].photos.removeAll { $0.id == photo.id }
                objectWillChange.send()
                print("✓ 内存数据更新成功")
                print("当前场地照片总数: \(projects[projectIndex].locations[locationIndex].photos.count)")
            }
        } catch {
            print("❌ 删除照片失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
        }
        print("================================")
    }
    
    static func withTestData(context: NSManagedObjectContext) -> ProjectStore {
        let store = ProjectStore(context: context)
        
        // 先清除现有数据
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ProjectEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("✓ 已清除现有数据")
        } catch {
            print("❌ 清除数据失败: \(error)")
        }
        
        // 短片项目
        let shortFilm = Project(
            id: UUID(),
            name: "春天的声音",
            director: "王导演",
            producer: "赵制片",
            startDate: Date().addingTimeInterval(86400 * 7), // 一周后开机
            status: .preProduction,
            color: .blue,
            tasks: [
                ProjectTask(
                    title: "完成最终分镜",
                    assignee: "导演组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                ),
                ProjectTask(
                    title: "确定主要演员",
                    assignee: "选角导演",
                    dueDate: Date().addingTimeInterval(86400 * 4)
                ),
                ProjectTask(
                    title: "场地合同签订",
                    assignee: "制片组",
                    dueDate: Date().addingTimeInterval(86400 * 5)
                )
            ],
            invoices: [
                Invoice(
                    name: "星光场地公司",
                    phone: "13800138000",
                    idNumber: "110101199001011234",
                    bankAccount: "6222021234567890",
                    bankName: "中国建设银行",
                    date: Date()
                )
            ],
            locations: [
                Location(
                    name: "老街区",
                    address: "北京市东城区东四胡同",
                    photos: [],
                    notes: "需要注意早晚高峰时段的环境音"
                ),
                Location(
                    name: "音乐教室",
                    address: "北京市海淀区中关村音乐学院",
                    photos: [],
                    notes: "已获得场地使用许可"
                )
            ],
            accounts: [
                Account(
                    name: "星光场地公司",
                    type: .location,
                    bankName: "中国建设银行",
                    bankBranch: "北京东城支行",
                    bankAccount: "6222021234567890",
                    contactName: "李经理",
                    contactPhone: "13800138000"
                )
            ]
        )
        
        // 广告项目
        let commercial = Project(
            id: UUID(),
            name: "新春饮料广告",
            director: "张导演",
            producer: "李制片",
            startDate: Date().addingTimeInterval(86400 * 3), // 三天后开机
            status: .preProduction,
            color: .orange,
            tasks: [
                ProjectTask(
                    title: "确认产品展示要求",
                    assignee: "制片组",
                    dueDate: Date().addingTimeInterval(86400)
                ),
                ProjectTask(
                    title: "道具采购清单",
                    assignee: "美术组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                ),
                ProjectTask(
                    title: "完成灯光设计",
                    assignee: "灯光组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                )
            ],
            invoices: [
                Invoice(
                    name: "城市影棚",
                    phone: "13900139000",
                    idNumber: "110101199001011235",
                    bankAccount: "6222021234567891",
                    bankName: "中国工商银行",
                    date: Date()
                )
            ],
            locations: [
                Location(
                    name: "影棚A",
                    address: "北京市朝阳区影视基地A区",
                    photos: [],
                    notes: "需要提前一天进场搭建"
                )
            ],
            accounts: [
                Account(
                    name: "城市影棚",
                    type: .location,
                    bankName: "中国工商银行",
                    bankBranch: "北京朝阳支行",
                    bankAccount: "6222021234567891",
                    contactName: "王经理",
                    contactPhone: "13900139000"
                )
            ]
        )
        
        // 添加项目到 store
        store.projects = [shortFilm, commercial]
        
        // 保存到 CoreData
        do {
            // 为每个项目创建实体
            for project in [shortFilm, commercial] {
                let projectEntity = project.toEntity(context: context)
                
                // 保存任务
                for task in project.tasks {
                    let taskEntity = task.toEntity(context: context)
                    taskEntity.project = projectEntity
                }
                
                // 保存场地
                for location in project.locations {
                    let locationEntity = location.toEntity(context: context)
                    locationEntity.project = projectEntity
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
            
            try context.save()
            print("✓ 测试数据已成功保存到 CoreData")
            
            // 重新加载数据以确保数据被正确保存
            store.loadProjects()
        } catch {
            print("❌ 保存测试数据失败: \(error)")
        }
        
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
    
    // 确保 mapProjectEntityToProject 方法正确加载账户信息
    private func mapProjectEntityToProject(_ entity: ProjectEntity) -> Project {
        // 初始化项目，使用正确的颜色处理方法
        var project = Project(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            director: entity.director ?? "",
            producer: entity.producer ?? "",
            startDate: entity.startDate ?? Date(),
            status: Project.Status(rawValue: entity.status ?? "") ?? .preProduction,
            color: entity.color != nil ? (Color(data: entity.color!) ?? .blue) : .blue,
            isLocationScoutingEnabled: entity.isLocationScoutingEnabled,
            logoData: entity.logoData  // 添加logo数据的加载
        )
        
        // 确保打印出状态，以便调试
        print("加载项目 \(project.name) 的堪景状态: \(project.isLocationScoutingEnabled)")
        
        // 加载任务信息
        if let taskEntities = entity.tasks?.allObjects as? [TaskEntity], !taskEntities.isEmpty {
            print("找到 \(taskEntities.count) 个任务实体")
            
            var validTasks: [ProjectTask] = []
            for taskEntity in taskEntities {
                guard let id = taskEntity.id,
                      let title = taskEntity.title,
                      let dueDate = taskEntity.dueDate else { 
                    print("⚠️ 跳过无效任务实体")
                    continue
                }
                
                let task = ProjectTask(
                    id: id,
                    title: title,
                    assignee: taskEntity.assignee ?? "",
                    dueDate: dueDate,
                    isCompleted: taskEntity.isCompleted,
                    reminder: taskEntity.reminder != nil ? ProjectTask.TaskReminder(rawValue: taskEntity.reminder!) : nil,
                    reminderHour: Int(taskEntity.reminderHour)
                )
                print("  - 加载任务: \(task.title), ID: \(task.id)")
                validTasks.append(task)
            }
            project.tasks = validTasks
            print("✓ 加载了 \(project.tasks.count) 个任务信息")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的任务实体")
        }
        
        // 加载发票信息
        if let invoiceEntities = entity.invoices?.allObjects as? [InvoiceEntity], !invoiceEntities.isEmpty {
            print("找到 \(invoiceEntities.count) 个发票实体")
            var validInvoices: [Invoice] = []
            for invoiceEntity in invoiceEntities {
                // 使用 fromEntity 方法加载发票数据
                let invoice = Invoice.fromEntity(invoiceEntity)
                print("  - 加载发票: \(invoice.name), ID: \(invoice.id)")
                print("    - 发票代码: \(invoice.invoiceCode ?? "nil")")
                print("    - 发票号码: \(invoice.invoiceNumber ?? "nil")")
                print("    - 销售方名称: \(invoice.sellerName ?? "nil")")
                print("    - 销售方税号: \(invoice.sellerTaxNumber ?? "nil")")
                print("    - 销售方地址: \(invoice.sellerAddress ?? "nil")")
                print("    - 销售方银行: \(invoice.sellerBankInfo ?? "nil")")
                print("    - 购买方地址: \(invoice.buyerAddress ?? "nil")")
                print("    - 购买方银行: \(invoice.buyerBankInfo ?? "nil")")
                print("    - 商品列表: \(invoice.goodsList?.joined(separator: ", ") ?? "nil")")
                print("    - 价税合计: \(invoice.totalAmount ?? 0.0)")
                validInvoices.append(invoice)
            }
            // 按日期排序
            validInvoices = Invoice.sortedByDate(validInvoices)
            project.invoices = validInvoices
            print("✓ 加载了 \(project.invoices.count) 个发票信息")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的发票实体")
        }
        
        // 加载账户信息
        if let accountEntities = entity.accounts?.allObjects as? [AccountEntity], !accountEntities.isEmpty {
            print("找到 \(accountEntities.count) 个账户实体")
            
            project.accounts = accountEntities.map { entity in
                let account = Account(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    type: AccountType(rawValue: entity.type ?? "") ?? .other,
                    bankName: entity.bankName ?? "",
                    bankBranch: entity.bankBranch ?? "",
                    bankAccount: entity.bankAccount ?? "",
                    idNumber: entity.idNumber ?? "",
                    contactName: entity.contactName ?? "",
                    contactPhone: entity.contactPhone ?? "",
                    notes: entity.notes ?? ""
                )
                print("  - 加载账户: \(account.name), ID: \(account.id)")
                return account
            }
            print("✓ 加载了 \(project.accounts.count) 个账户信息")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的账户实体")
        }
        
        // 加载位置信息
        if let locationEntities = entity.locations?.allObjects as? [LocationEntity], !locationEntities.isEmpty {
            print("找到 \(locationEntities.count) 个位置实体")
            
            var validLocations: [Location] = []
            for locationEntity in locationEntities {
                guard let id = locationEntity.id,
                      let name = locationEntity.name,
                      let typeStr = locationEntity.type,
                      let statusStr = locationEntity.status,
                      let address = locationEntity.address,
                      let date = locationEntity.date else { 
                    print("⚠️ 跳过无效位置实体")
                    continue
                }
                
                // 使用正确的枚举类型
                let locationType = LocationType(rawValue: typeStr) ?? .other
                let locationStatus = LocationStatus(rawValue: statusStr) ?? .pending
                
                // 添加坐标调试信息
                print("坐标信息检查:")
                print("- hasCoordinates: \(locationEntity.hasCoordinates)")
                if locationEntity.hasCoordinates {
                    print("- 纬度: \(locationEntity.latitude), 经度: \(locationEntity.longitude)")
                }
                
                var location = Location(
                    id: id,
                    name: name,
                    type: locationType,
                    status: locationStatus,
                    address: address,
                    latitude: locationEntity.hasCoordinates ? locationEntity.latitude : nil,
                    longitude: locationEntity.hasCoordinates ? locationEntity.longitude : nil,
                    contactName: locationEntity.contactName,
                    contactPhone: locationEntity.contactPhone,
                    photos: [],  // 先创建空照片数组，稍后填充
                    notes: locationEntity.notes,
                    date: date
                )
                
                // 验证创建的 Location 对象
                print("创建的 Location 对象:")
                print("- hasCoordinates: \(location.hasCoordinates)")
                if location.hasCoordinates {
                    print("- 纬度: \(location.latitude!), 经度: \(location.longitude!)")
                }
                
                // 加载位置照片
                if let photoEntities = locationEntity.photos?.allObjects as? [LocationPhotoEntity], !photoEntities.isEmpty {
                    var validPhotos: [LocationPhoto] = []
                    for photoEntity in photoEntities {
                        guard let photoId = photoEntity.id,
                              let photoDate = photoEntity.date,
                              let imageData = photoEntity.imageData,
                              let image = UIImage(data: imageData) else {
                            continue
                        }
                        
                        let photo = LocationPhoto(
                            id: photoId,
                            image: image,
                            date: photoDate,
                            weather: photoEntity.weather,
                            note: photoEntity.note
                        )
                        validPhotos.append(photo)
                    }
                    location.photos = validPhotos
                }
                
                print("  - 加载位置: \(location.name), ID: \(location.id), 照片数: \(location.photos.count)")
                validLocations.append(location)
            }
            project.locations = validLocations
            print("✓ 加载了 \(project.locations.count) 个位置信息")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的位置实体")
        }
        
        return project
    }
    
    // 添加 fetchProjectEntity 方法
    private func fetchProjectEntity(id: UUID) -> ProjectEntity? {
        let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("❌ 获取项目实体失败: \(error)")
            return nil
        }
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
