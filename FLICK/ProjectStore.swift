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
        
        // 使用创建日期作为排序依据，确保稳定排序
        // 在CoreData中，通常新创建的对象ID较大，因此按ID降序可以近似实现按创建时间排序
        let primarySort = NSSortDescriptor(key: "id", ascending: false)
        // 使用项目名称作为次要排序条件，在创建时间相同时保持名称字母顺序
        let secondarySort = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [primarySort, secondarySort]
        
        do {
            let entities = try context.fetch(request)
            print("从 CoreData 加载了 \(entities.count) 个项目实体")
            
            // 预先验证实体的预算值
            for entity in entities {
                print("预先验证 - 项目 '\(entity.name ?? "未命名")' 预算值: \(entity.budget)")
            }
            
            var loadedProjects: [Project] = []
            for entity in entities {
                let project = mapProjectEntityToProject(entity)
                // 验证预算值正确传递到Project对象
                print("映射后 - 项目 '\(project.name)' 预算值: \(project.budget)")
                loadedProjects.append(project)
            }
            
            // 确保UI更新在主线程进行
            DispatchQueue.main.async {
                // 直接替换整个数组，避免部分更新
                self.projects = loadedProjects
                print("✓ 成功加载 \(loadedProjects.count) 个项目")
                
                // 最终验证
                for project in self.projects {
                    print("最终验证 - 项目 '\(project.name)' 预算值: \(project.budget)")
                }
                
                // 显式通知视图更新
                self.objectWillChange.send()
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
            
            // 检查项目是否已存在
            let fetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
            
            var projectEntity: ProjectEntity
            
            do {
                let results = try context.fetch(fetchRequest)
                if let existingEntity = results.first {
                    print("✓ 找到现有项目实体，进行更新")
                    projectEntity = existingEntity
                    
                    // 更新基本属性
                    projectEntity.name = project.name
                    projectEntity.director = project.director
                    projectEntity.producer = project.producer
                    projectEntity.startDate = project.startDate
                    projectEntity.status = project.status.rawValue
                    projectEntity.color = project.color.toData()
                    projectEntity.isLocationScoutingEnabled = project.isLocationScoutingEnabled
                    projectEntity.logoData = project.logoData
                    
                    // 明确设置预算值并打印日志
                    print("设置项目实体预算值: \(project.budget)")
                    projectEntity.budget = project.budget
                    print("设置后预算值: \(projectEntity.budget)")
                } else {
                    print("✓ 未找到现有项目实体，创建新实体")
                    projectEntity = project.toEntity(context: context)
                }
            } catch {
                print("❌ 查询项目实体失败: \(error)")
                projectEntity = project.toEntity(context: context)
                print("✓ 创建新实体替代: \(projectEntity.id?.uuidString ?? "未知ID")")
            }
            
            // 保存场地和照片
            for location in project.locations {
                print("""
                处理场地:
                - ID: \(location.id)
                - 名称: \(location.name)
                - 照片数量: \(location.photos.count)
                """)
                
                // 检查场地是否已存在
                let locationRequest: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
                locationRequest.predicate = NSPredicate(format: "id == %@", location.id as CVarArg)
                
                var locationEntity: LocationEntity
                
                do {
                    let results = try context.fetch(locationRequest)
                    if let existingLocation = results.first {
                        print("✓ 找到现有场地实体，进行更新")
                        locationEntity = existingLocation
                        
                        // 更新基本属性
                        locationEntity.name = location.name
                        locationEntity.address = location.address
                        locationEntity.type = location.type.rawValue
                        locationEntity.status = location.status.rawValue
                        locationEntity.contactName = location.contactName
                        locationEntity.contactPhone = location.contactPhone
                        locationEntity.notes = location.notes
                        locationEntity.date = location.date
                        
                        if location.hasCoordinates, let lat = location.latitude, let lng = location.longitude {
                            locationEntity.latitude = lat
                            locationEntity.longitude = lng
                            locationEntity.hasCoordinates = true
                        } else {
                            locationEntity.hasCoordinates = false
                        }
                    } else {
                        print("✓ 未找到现有场地实体，创建新实体")
                        locationEntity = location.toEntity(context: context)
                        locationEntity.project = projectEntity
                    }
                } catch {
                    print("❌ 查询场地实体失败: \(error)")
                    locationEntity = location.toEntity(context: context)
                    locationEntity.project = projectEntity
                    print("✓ 创建新场地实体替代")
                }
                
                // 保存照片
                for photo in location.photos {
                    print("处理照片: \(photo.id)")
                    
                    // 检查照片是否已存在
                    let photoRequest: NSFetchRequest<LocationPhotoEntity> = LocationPhotoEntity.fetchRequest()
                    photoRequest.predicate = NSPredicate(format: "id == %@", photo.id as CVarArg)
                    
                    do {
                        let results = try context.fetch(photoRequest)
                        if let existingPhoto = results.first {
                            print("✓ 找到现有照片实体，进行更新")
                            existingPhoto.date = photo.date
                            existingPhoto.weather = photo.weather
                            existingPhoto.note = photo.note
                            // 避免重复存储大型图像数据
                            if existingPhoto.imageData == nil {
                                existingPhoto.imageData = photo.imageData
                            }
                        } else {
                            print("✓ 创建新照片实体")
                            let photoEntity = photo.toEntity(context: context)
                            photoEntity.location = locationEntity
                        }
                    } catch {
                        print("❌ 查询照片实体失败: \(error)")
                        let photoEntity = photo.toEntity(context: context)
                        photoEntity.location = locationEntity
                        print("✓ 创建新照片实体替代")
                    }
                }
            }
            
            // 保存任务
            for task in project.tasks {
                // 检查任务是否已存在
                let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
                taskRequest.predicate = NSPredicate(format: "id == %@", task.id as CVarArg)
                
                do {
                    let results = try context.fetch(taskRequest)
                    if let existingTask = results.first {
                        print("✓ 找到现有任务实体，进行更新")
                        existingTask.title = task.title
                        existingTask.assignee = task.assignee
                        existingTask.dueDate = task.dueDate
                        existingTask.isCompleted = task.isCompleted
                        existingTask.reminder = task.reminder?.rawValue
                        existingTask.reminderHour = Int16(task.reminderHour)
                    } else {
                        print("✓ 创建新任务实体")
                        let taskEntity = task.toEntity(context: context)
                        taskEntity.project = projectEntity
                    }
                } catch {
                    print("❌ 查询任务实体失败: \(error)")
                    let taskEntity = task.toEntity(context: context)
                    taskEntity.project = projectEntity
                    print("✓ 创建新任务实体替代")
                }
            }
            
            // 保存发票
            for invoice in project.invoices {
                // 检查发票是否已存在
                let invoiceRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
                invoiceRequest.predicate = NSPredicate(format: "id == %@", invoice.id as CVarArg)
                
                do {
                    let results = try context.fetch(invoiceRequest)
                    if let existingInvoice = results.first {
                        print("✓ 找到现有发票实体，进行更新")
                        existingInvoice.name = invoice.name
                        existingInvoice.phone = invoice.phone
                        existingInvoice.idNumber = invoice.idNumber
                        existingInvoice.bankAccount = invoice.bankAccount
                        existingInvoice.bankName = invoice.bankName
                        existingInvoice.date = invoice.date
                        existingInvoice.amount = invoice.amount
                        existingInvoice.category = invoice.category.rawValue
                        existingInvoice.status = invoice.status.rawValue
                        existingInvoice.dueDate = invoice.dueDate
                        existingInvoice.notes = invoice.notes
                    } else {
                        print("✓ 创建新发票实体")
                        let invoiceEntity = invoice.toEntity(context: context)
                        invoiceEntity.project = projectEntity
                    }
                } catch {
                    print("❌ 查询发票实体失败: \(error)")
                    let invoiceEntity = invoice.toEntity(context: context)
                    invoiceEntity.project = projectEntity
                    print("✓ 创建新发票实体替代")
                }
            }
            
            // 保存账户
            for account in project.accounts {
                // 检查账户是否已存在
                let accountRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
                accountRequest.predicate = NSPredicate(format: "id == %@", account.id as CVarArg)
                
                do {
                    let results = try context.fetch(accountRequest)
                    if let existingAccount = results.first {
                        print("✓ 找到现有账户实体，进行更新")
                        existingAccount.name = account.name
                        existingAccount.type = account.type.rawValue
                        existingAccount.bankName = account.bankName
                        existingAccount.bankBranch = account.bankBranch
                        existingAccount.bankAccount = account.bankAccount
                        existingAccount.idNumber = account.idNumber
                        existingAccount.contactName = account.contactName
                        existingAccount.contactPhone = account.contactPhone
                        existingAccount.notes = account.notes
                    } else {
                        print("✓ 创建新账户实体")
                        let accountEntity = account.toEntity(context: context)
                        accountEntity.project = projectEntity
                    }
                } catch {
                    print("❌ 查询账户实体失败: \(error)")
                    let accountEntity = account.toEntity(context: context)
                    accountEntity.project = projectEntity
                    print("✓ 创建新账户实体替代")
                }
            }
        }
        
        // 批量保存所有更改
        do {
            try context.save()
            print("✓ CoreData 保存成功")
            
            // 立即验证预算值是否正确保存
            print("=== 立即验证预算值是否保存成功 ===")
            let budgetVerifyRequest = ProjectEntity.fetchRequest()
            let projectEntities = try context.fetch(budgetVerifyRequest)
            for entity in projectEntities {
                print("验证保存后 - 项目 '\(entity.name ?? "未命名")' 预算值: \(entity.budget)")
            }
            print("=== 验证完成 ===")
            
            // 记录保存时间
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSaveTime")
            
            // 验证保存结果
            let verifyRequest = ProjectEntity.fetchRequest()
            let count = try context.count(for: verifyRequest)
            print("✓ 验证: 数据库中有 \(count) 个项目实体")
        } catch {
            print("""
            ❌ 保存失败:
            错误类型: \(type(of: error))
            错误描述: \(error.localizedDescription)
            堆栈跟踪: \(error)
            """)
            
            // 尝试进一步诊断错误
            if let nsError = error as NSError? {
                print("错误代码: \(nsError.code), 域: \(nsError.domain)")
                for (key, value) in nsError.userInfo {
                    print("- \(key): \(value)")
                }
            }
        }
        
        // 临时：同时保存到 UserDefaults（作为备份）
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            print("✓ 已保存备份到 UserDefaults")
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
            
            // 6. 强制调用saveProjects确保所有关联数据也被保存
            print("✓ 开始调用saveProjects保存全部项目数据")
            self.saveProjects()
            
            // 7. 手动触发CoreData同步到CloudKit
            print("✓ 开始触发PersistenceController同步")
            PersistenceController.shared.save()
            
            // 8. 触发iCloud同步（如果已启用）
            if enableCloudSync {
                print("✓ iCloud同步已启用，开始同步")
                PersistenceController.shared.syncWithCloud { success, error in
                    if success {
                        print("✓ 项目已成功同步到iCloud")
                    } else if let error = error {
                        print("⚠️ iCloud同步警告: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("❌ 保存失败:")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("错误代码: \(nsError.code), 域: \(nsError.domain)")
                for (key, value) in nsError.userInfo {
                    print("- \(key): \(value)")
                }
            }
        }
        
        print("================================")
    }
    
    // 删除项目
    func deleteProject(_ project: Project) {
        print("========== 开始删除项目 ==========")
        print("项目名称: \(project.name), ID: \(project.id)")
        
        // 保持数据引用，避免在处理过程中其他地方修改数据
        let projectId = project.id
        
        // 使用主线程处理所有数据变更，避免并发问题
        DispatchQueue.main.async {
        // 从 CoreData 中删除
            let fetchRequest = ProjectEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
            
            do {
                let results = try self.context.fetch(fetchRequest)
                print("找到匹配的项目实体数量: \(results.count)")
                
                if let projectEntity = results.first {
                    print("✓ 找到项目实体，正在删除")
                    
                    // 手动删除相关实体，确保级联删除生效
                    
                    // 删除所有任务
                    if let tasks = projectEntity.tasks?.allObjects as? [TaskEntity], !tasks.isEmpty {
                        print("- 删除\(tasks.count)个关联任务")
                        for task in tasks {
                            self.context.delete(task)
                        }
                    }
                    
                    // 删除所有场景及其照片
                    if let locations = projectEntity.locations?.allObjects as? [LocationEntity], !locations.isEmpty {
                        print("- 删除\(locations.count)个关联场景")
                        for location in locations {
                            // 删除场景下的所有照片
                            if let photos = location.photos?.allObjects as? [LocationPhotoEntity], !photos.isEmpty {
                                print("  - 删除\(photos.count)个照片")
                                for photo in photos {
                                    self.context.delete(photo)
                                }
                            }
                            self.context.delete(location)
                        }
                    }
                    
                    // 删除所有账户
                    if let accounts = projectEntity.accounts?.allObjects as? [AccountEntity], !accounts.isEmpty {
                        print("- 删除\(accounts.count)个关联账户")
                        for account in accounts {
                            self.context.delete(account)
                        }
        }
        
                    // 删除所有发票
                    if let invoices = projectEntity.invoices?.allObjects as? [InvoiceEntity], !invoices.isEmpty {
                        print("- 删除\(invoices.count)个关联发票")
                        for invoice in invoices {
                            self.context.delete(invoice)
                        }
                    }
                    
                    // 最后删除项目实体本身
                    self.context.delete(projectEntity)
                    
                    // 立即保存上下文
                    try self.context.save()
                    print("✓ CoreData 删除成功")
                    
                    // 触发 CloudKit 同步
                    PersistenceController.shared.save()
                    print("✓ 已触发CloudKit同步")
                    
                    // 重新加载项目列表以获取最新数据
                    // 这里不单独更新内存中的数据，而是直接从数据库重新加载所有项目
                    self.loadProjects()
                    print("✓ 已重新加载项目列表")
                } else {
                    print("❌ 未找到项目实体")
                }
            } catch {
                print("❌ 删除项目失败: \(error)")
                print("错误描述: \(error.localizedDescription)")
                
                // 恢复内存中的项目数据
                self.loadProjects()
            }
            
            print("================================")
        }
    }
    
    // 更新项目
    func updateProject(_ updatedProject: Project) {
        print("更新项目预算值: \(updatedProject.budget)")
        
        // 更新内存中的项目
        if let index = projects.firstIndex(where: { $0.id == updatedProject.id }) {
            projects[index] = updatedProject
            print("✓ 已更新内存中的项目数据")
        }
        
        // 更新CoreData实体
        if let projectEntity = try? context.fetch(ProjectEntity.fetchRequest())
            .first(where: { $0.id == updatedProject.id }) {
            
            print("CoreData中原始预算值: \(projectEntity.budget)")
            
            // 更新 CoreData 实体
            projectEntity.name = updatedProject.name
            projectEntity.director = updatedProject.director
            projectEntity.producer = updatedProject.producer
            projectEntity.startDate = updatedProject.startDate
            projectEntity.status = updatedProject.status.rawValue
            projectEntity.color = updatedProject.color.toData()
            projectEntity.isLocationScoutingEnabled = updatedProject.isLocationScoutingEnabled
            projectEntity.logoData = updatedProject.logoData  // 添加LOGO数据的更新
            projectEntity.budget = updatedProject.budget      // 添加预算数据的更新
            
            print("更新后CoreData中的预算值: \(projectEntity.budget)")
            
            // 保存更改
            saveContext()
            
            // 通知UI刷新，但不重新加载项目列表
            objectWillChange.send()
        }
    }
    
    // 保存上下文的辅助方法
    private func saveContext() {
        if context.hasChanges {
            do {
                // 添加保存前的数据验证日志
                if let projectEntities = try? context.fetch(ProjectEntity.fetchRequest()) {
                    for entity in projectEntities {
                        print("保存前验证 - 项目: \(entity.name ?? "未命名"), 预算: \(entity.budget)")
                    }
                }
                
                try context.save()
                print("✓ 成功保存到CoreData本地存储")
                
                // 确保数据持久化和同步到iCloud
                PersistenceController.shared.save()
                
                // 强制刷新持久化存储
                try PersistenceController.shared.container.viewContext.save()
                
                // 添加保存后的数据验证日志
                if let projectEntities = try? context.fetch(ProjectEntity.fetchRequest()) {
                    for entity in projectEntities {
                        print("保存后验证 - 项目: \(entity.name ?? "未命名"), 预算: \(entity.budget)")
                    }
                }
                
                // 检查是否启用了iCloud同步
                if UserDefaults.standard.bool(forKey: "enableCloudSync") {
                    // 异步触发iCloud同步
                    DispatchQueue.global(qos: .background).async {
                        PersistenceController.shared.syncWithCloud { success, error in
                            if success {
                                print("✓ 数据成功同步到iCloud")
                            } else if let error = error {
                                print("⚠️ iCloud同步警告: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    print("ℹ️ iCloud同步未启用，仅保存到本地")
                }
            } catch {
                print("❌ 保存CoreData失败: \(error)")
                
                // 尝试诊断错误
                if let nsError = error as NSError? {
                    print("错误代码: \(nsError.code), 域: \(nsError.domain)")
                    print("错误详情: \(nsError.userInfo)")
                }
            }
        } else {
            print("ℹ️ 没有CoreData变更需要保存")
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
        
        // 使用动画更新任务
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            // 立即更新内存中的数据，确保UI能立即响应
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
               let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                projects[projectIndex].tasks[taskIndex].isCompleted = updatedTask.isCompleted
                // 主动通知视图刷新
                objectWillChange.send()
            }
            
            // 更新任务到CoreData
            updateTask(updatedTask, in: project)
            
            // 处理提醒
            if updatedTask.isCompleted {
                NotificationManager.shared.removeTaskReminders(for: task)
                print("✓ 已移除任务提醒")
            } else if let reminder = task.reminder {
                NotificationManager.shared.scheduleTaskReminder(for: task, in: project)
                print("✓ 已重新设置任务提醒")
            }
            
            // 确保数据已保存并同步
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.saveProjects()
            }
        }
        print("================================")
    }
    
    // 确保 mapProjectEntityToProject 方法正确加载账户信息
    private func mapProjectEntityToProject(_ entity: ProjectEntity) -> Project {
        // 打印预算信息
        print("从CoreData加载预算值: \(entity.budget)")
        
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
            logoData: entity.logoData,  // 添加logo数据的加载
            budget: entity.budget       // 添加预算数据的加载
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
            
            project.locations = locationEntities.compactMap { entity -> Location? in
                guard let typeString = entity.type,
                      let typeEnum = LocationType(rawValue: typeString),
                      let statusString = entity.status,
                      let statusEnum = LocationStatus(rawValue: statusString) else {
                    return nil
                }

                // 提前获取坐标信息
                let latitude: Double? = entity.hasCoordinates ? entity.latitude : nil
                let longitude: Double? = entity.hasCoordinates ? entity.longitude : nil
                
                let location = Location(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    type: typeEnum,
                    status: statusEnum,
                    address: entity.address ?? "",
                    latitude: latitude,
                    longitude: longitude,
                    contactName: entity.contactName,
                    contactPhone: entity.contactPhone,
                    notes: entity.notes,
                    date: entity.date ?? Date()
                )
                
                // 加载照片
                var locationWithPhotos = location
                if let photoEntities = entity.photos?.allObjects as? [LocationPhotoEntity] {
                    locationWithPhotos.photos = photoEntities.compactMap { photoEntity in
                        return LocationPhoto.fromEntity(photoEntity)
                    }
                }
                
                return locationWithPhotos
            }
            print("✓ 加载了 \(project.locations.count) 个位置信息")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的位置实体")
        }
        
        // 加载交易记录
        if let transactionEntities = entity.transactions?.allObjects as? [TransactionEntity], !transactionEntities.isEmpty {    
            print("找到 \(transactionEntities.count) 个交易记录实体")
            
            project.transactions = transactionEntities.compactMap { $0.toModel() }
            print("✓ 加载了 \(project.transactions.count) 个交易记录")
        } else {
            print("⚠️ 项目 \(project.name) 没有关联的交易记录")
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
    
    // 添加交易记录
    func addTransaction(to project: Project, transaction: Transaction) {
        print("========== 添加交易记录 ==========")
        print("项目: \(project.name)")
        print("交易: \(transaction.name), 金额: \(transaction.amount)")
        
        // 获取项目实体
        guard let projectEntity = fetchProjectEntity(id: project.id) else {
            print("❌ 找不到项目实体")
            return
        }
        
        // 创建交易实体
        let transactionEntity = TransactionEntity(context: context)
        transactionEntity.id = transaction.id
        transactionEntity.name = transaction.name
        transactionEntity.amount = transaction.amount
        transactionEntity.date = transaction.date
        transactionEntity.transactionDescription = transaction.transactionDescription
        transactionEntity.expenseType = transaction.expenseType
        transactionEntity.group = transaction.group
        transactionEntity.paymentMethod = transaction.paymentMethod
        transactionEntity.type = transaction.transactionType.rawValue
        transactionEntity.isVerified = transaction.isVerified
        
        // 如果有附件，创建附件实体
        if let attachmentData = transaction.attachmentData {
            let attachmentEntity = AttachmentEntity(context: context)
            attachmentEntity.id = UUID()
            attachmentEntity.name = "附件_\(transaction.id)"
            attachmentEntity.data = attachmentData
            attachmentEntity.transaction = transactionEntity
            transactionEntity.addToAttachments(attachmentEntity)
        }
        
        // 关联到项目
        transactionEntity.project = projectEntity
        
        // 添加到内存中的项目模型
        project.transactions.append(transaction)
        
        // 保存上下文
        saveContext()
        
        print("✓ 成功添加交易记录")
        print("================================")
    }
    
    // 更新交易记录
    func updateTransaction(in project: Project, transaction: Transaction) {
        print("========== 更新交易记录 ==========")
        print("项目: \(project.name)")
        print("交易ID: \(transaction.id)")
        
        // 获取交易实体
        let request = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", transaction.id as CVarArg, project.id as CVarArg)
        
        do {
            if let transactionEntity = try context.fetch(request).first {
                // 更新实体属性
                transactionEntity.name = transaction.name
                transactionEntity.amount = transaction.amount
                transactionEntity.date = transaction.date
                transactionEntity.transactionDescription = transaction.transactionDescription
                transactionEntity.expenseType = transaction.expenseType
                transactionEntity.group = transaction.group
                transactionEntity.paymentMethod = transaction.paymentMethod
                transactionEntity.type = transaction.transactionType.rawValue
                transactionEntity.isVerified = transaction.isVerified
                
                // 处理附件更新
                if let attachmentData = transaction.attachmentData {
                    // 检查是否已有附件
                    if let existingAttachments = transactionEntity.attachments, existingAttachments.count > 0 {
                        // 更新现有附件
                        if let attachment = existingAttachments.allObjects.first as? AttachmentEntity {
                            attachment.data = attachmentData
                        }
                    } else {
                        // 创建新附件
                        let attachmentEntity = AttachmentEntity(context: context)
                        attachmentEntity.id = UUID()
                        attachmentEntity.name = "附件_\(transaction.id)"
                        attachmentEntity.data = attachmentData
                        attachmentEntity.transaction = transactionEntity
                        transactionEntity.addToAttachments(attachmentEntity)
                    }
                } else {
                    // 如果没有附件数据，删除现有附件
                    if let existingAttachments = transactionEntity.attachments {
                        for attachment in existingAttachments.allObjects {
                            if let attachment = attachment as? AttachmentEntity {
                                context.delete(attachment)
                            }
                        }
                    }
                }
                
                // 保存上下文
                saveContext()
                
                // 更新内存中的交易记录
                if let index = project.transactions.firstIndex(where: { $0.id == transaction.id }) {
                    project.transactions[index] = transaction
                }
                
                print("✓ 成功更新交易记录")
            } else {
                print("⚠️ 找不到要更新的交易记录，尝试添加新记录")
                addTransaction(to: project, transaction: transaction)
            }
        } catch {
            print("❌ 更新交易记录时出错: \(error)")
        }
        
        print("================================")
    }
    
    // 删除交易记录
    func deleteTransaction(from project: Project, transactionId: UUID) {
        print("========== 删除交易记录 ==========")
        print("项目: \(project.name)")
        print("交易ID: \(transactionId)")
        
        // 获取交易实体
        let request = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", transactionId as CVarArg, project.id as CVarArg)
        
        do {
            if let transactionEntity = try context.fetch(request).first {
                // 删除实体
                context.delete(transactionEntity)
                
                // 保存上下文
                saveContext()
                
                // 从内存中删除交易记录
                project.transactions.removeAll { $0.id == transactionId }
                
                print("✓ 成功删除交易记录")
            } else {
                print("⚠️ 找不到要删除的交易记录")
            }
        } catch {
            print("❌ 删除交易记录时出错: \(error)")
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
