import SwiftUI
import CoreData

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        print("========== ProjectStore 初始化 ==========")
        self.context = context
        ProjectStore.shared = self
        loadProjects()
        print("- Context: \(context)")
        print("- 已加载项目数量: \(projects.count)")
        print("=====================================")
    }
    
    private func loadProjects() {
        print("========== 开始加载项目 ==========")
        let request = ProjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.startDate, ascending: false)]
        
        do {
            let projectEntities = try context.fetch(request)
            print("从 CoreData 获取到 \(projectEntities.count) 个项目")
            
            projects = projectEntities.compactMap { entity -> Project? in
                guard let project = Project.fromEntity(entity) else {
                    print("❌ 项目实体转换失败")
                    return nil
                }
                
                print("""
                ✓ 成功加载项目:
                - ID: \(project.id)
                - 名称: \(project.name)
                - 场地数量: \(project.locations.count)
                - 任务数量: \(project.tasks.count)
                """)
                
                return project
            }
            print("✓ 成功加载 \(projects.count) 个项目")
        } catch {
            print("""
            ❌ 加载项目失败:
            错误类型: \(type(of: error))
            错误描述: \(error.localizedDescription)
            """)
        }
        print("================================")
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
    
    // 添加任务
    func addTask(_ task: ProjectTask, to project: Project) {
        print("========== 开始添加任务 ==========")
        print("任务信息:")
        print("- 标题: \(task.title)")
        print("- 负责人: \(task.assignee)")
        print("- 截止时间: \(task.dueDate)")
        if let reminder = task.reminder {
            print("- 提醒设置: \(reminder.rawValue) \(task.reminderHour):00")
        }
        
        guard let projectEntity = project.fetchEntity(in: context) else {
            print("❌ 错误：找不到项目实体")
            return
        }
        
        // 创建任务实体
        let taskEntity = task.toEntity(context: context)
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
    func updateLocation(_ location: Location, in project: Project) {
        print("========== 开始更新场地 ==========")
        print("场地信息:")
        print("- ID: \(location.id)")
        print("- 名称: \(location.name)")
        print("- 类型: \(location.type.rawValue)")
        print("- 状态: \(location.status.rawValue)")
        print("- 地址: \(location.address)")
        
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
            print("✓ 实体数据更新完成")
            
            do {
                // 3. 保存更改
                try context.save()
                print("✓ CoreData 保存成功")
                
                // 4. 更新内存中的数据
                if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
                   let locationIndex = projects[projectIndex].locations.firstIndex(where: { $0.id == location.id }) {
                    projects[projectIndex].locations[locationIndex] = location
                    print("✓ 内存数据更新成功")
                    objectWillChange.send()
                    print("✓ 发送视图更新通知")
                }
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
            return
        }
        
        let invoiceEntity = invoice.toEntity(context: context)
        invoiceEntity.project = projectEntity
        
        do {
            try context.save()
            print("发票保存成功")
            
            // 更新内存中的项目数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index].invoices.append(invoice)  // 添加到内存中的发票数组
                objectWillChange.send()  // 通知视图更新
            }
        } catch {
            print("保存发票失败: \(error)")
        }
    }
    
    // 更新发票
    func updateInvoice(_ invoice: Invoice, in project: Project) {
        print("开始更新发票...")
        
        // 1. 更新 CoreData
        guard let projectEntity = project.fetchEntity(in: context),
              let invoiceEntity = projectEntity.invoices?
                .first(where: { ($0 as? InvoiceEntity)?.id == invoice.id }) as? InvoiceEntity
        else {
            print("错误：找不到发票实体")
            return
        }
        
        // 更新发票实体
        invoiceEntity.name = invoice.name
        invoiceEntity.phone = invoice.phone
        invoiceEntity.idNumber = invoice.idNumber
        invoiceEntity.bankAccount = invoice.bankAccount
        invoiceEntity.bankName = invoice.bankName
        invoiceEntity.date = invoice.date
        
        do {
            try context.save()
            print("发票更新成功：\(invoice.name)")
            
            // 2. 更新内存中的数据
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                // 更新内存中的发票数组
                if let invoiceIndex = projects[projectIndex].invoices.firstIndex(where: { $0.id == invoice.id }) {
                    projects[projectIndex].invoices[invoiceIndex] = invoice
                    
                    // 3. 发送更新通知
                    objectWillChange.send()
                    
                    // 4. 重要：确保项目数据也被更新
                    let updatedProject = projects[projectIndex]
                    DispatchQueue.main.async {
                        self.projects[projectIndex] = updatedProject
                    }
                }
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
    func addAccount(_ account: Account, to project: Project) {
        print("========== 开始添加账户 ==========")
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
        
        guard let projectEntity = project.fetchEntity(in: context) else {
            print("❌ 错误：找不到项目实体")
            return
        }
        
        print("\n开始保存到 CoreData...")
        
        // 1. 创建 AccountEntity
        let accountEntity = account.toEntity(context: context)
        accountEntity.project = projectEntity  // 设置必需的关系
        print("✓ 账户实体创建成功")
        
        do {
            // 2. 保存到 CoreData
            try context.save()
            print("✓ CoreData 保存成功")
            
            // 3. 更新内存中的项目数据
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                let oldCount = projects[index].accounts.count
                projects[index].accounts.append(account)
                let newCount = projects[index].accounts.count
                print("✓ 内存数据更新成功")
                print("- 账户数量: \(oldCount) -> \(newCount)")
                
                // 4. 确保项目数据也被更新
                let updatedProject = projects[index]
                DispatchQueue.main.async {
                    self.projects[index] = updatedProject
                    self.objectWillChange.send()
                    print("✓ 视图更新通知已发送")
                }
            } else {
                print("❌ 错误：找不到对应的项目")
            }
        } catch {
            print("❌ 保存账户失败:")
            print("- 错误信息: \(error)")
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
    
    // 添加照片保存方法
    func addPhotos(_ photos: [LocationPhoto], to location: Location, in project: Project) async {
        guard let projectEntity = project.fetchEntity(in: context),
              let locationEntity = location.fetchEntity(in: context) else {
            return
        }
        
        for photo in photos {
            let photoEntity = LocationPhotoEntity(context: context)
            photoEntity.id = photo.id
            photoEntity.imageData = photo.imageData
            photoEntity.date = photo.date
            photoEntity.weather = photo.weather
            photoEntity.note = photo.note
            photoEntity.location = locationEntity
        }
        
        do {
            try context.save()
            if let index = projects.firstIndex(where: { $0.id == project.id }),
               let locationIndex = projects[index].locations.firstIndex(where: { $0.id == location.id }) {
                projects[index].locations[locationIndex].photos.append(contentsOf: photos)
                objectWillChange.send()
            }
        } catch {
            print("保存照片失败: \(error)")
        }
    }
    
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
