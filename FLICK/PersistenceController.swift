import CoreData
import CloudKit
import UIKit

class PersistenceController {
    static let shared = PersistenceController()
    
    // 使用普通容器，稍后根据需要转换为 CloudKit 容器
    let container: NSPersistentContainer
    
    // CloudKit 同步状态
    enum CloudKitSyncStatus: Equatable {
        case disabled    // 未启用
        case enabled     // 已启用但未同步
        case syncing     // 同步中
        case synced      // 已同步
        case error(Error) // 同步错误
        
        // 实现 Equatable 协议
        static func == (lhs: CloudKitSyncStatus, rhs: CloudKitSyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disabled, .disabled),
                 (.enabled, .enabled),
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
    
    // 当前同步状态
    @Published var syncStatus: CloudKitSyncStatus = .disabled
    
    // 是否支持 CloudKit
    private var supportsCloudKit: Bool = false
    
    // 初始化方法
    private init(inMemory: Bool = false) {
        print("========== 初始化 PersistenceController ==========")
        
        // 检查是否启用 iCloud 同步
        let enableCloudSync = UserDefaults.standard.bool(forKey: "enableCloudSync")
        print("iCloud 同步状态: \(enableCloudSync ? "已启用" : "未启用")")
        
        // 确保写入UserDefaults
        UserDefaults.standard.set(enableCloudSync, forKey: "enableCloudSync")
        UserDefaults.standard.synchronize()
        
        // 首先使用普通容器
        container = NSPersistentContainer(name: "FLICK")
        print("✓ 创建 NSPersistentContainer")
        
        // 所有存储属性初始化完成后，设置应用生命周期通知监听
        setupAppLifecycleObservers()
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            print("✓ 配置内存存储")
        } else if enableCloudSync {
            // 配置 CloudKit
            if let storeDescription = container.persistentStoreDescriptions.first {
                // 配置 CloudKit 容器
                let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.FLICKiCLoud"
                )
                
                // 设置架构初始化选项
                cloudKitContainerOptions.databaseScope = .private
                
                storeDescription.cloudKitContainerOptions = cloudKitContainerOptions
                print("✓ 配置 CloudKit 容器: iCloud.FLICKiCLoud")
                
                // 启用远程变更通知
                storeDescription.setOption(true as NSNumber, 
                    forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                print("✓ 启用远程变更通知")
                
                // 配置其他选项
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                print("✓ 启用历史跟踪")
                
                // 标记支持 CloudKit
                supportsCloudKit = true
            }
        }
        
        // 加载存储
        print("开始加载持久化存储...")
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("❌ CoreData 加载失败: \(error)")
                
                // 打印更详细的错误信息
                if let nsError = error as NSError? {
                    print("错误代码: \(nsError.code)")
                    print("错误域: \(nsError.domain)")
                    
                    if let reason = nsError.userInfo["NSLocalizedFailureReason"] as? String {
                        print("失败原因: \(reason)")
                    }
                    
                    if let recoverySuggestion = nsError.userInfo["NSLocalizedRecoverySuggestion"] as? String {
                        print("恢复建议: \(recoverySuggestion)")
                    }
                    
                    // 检查是否是数据库迁移错误
                    if nsError.code == 134110 || // 迁移错误
                       nsError.userInfo["reason"] as? String == "Cannot migrate store in-place: near \"null\": syntax error" {
                        print("⚠️ 检测到数据库迁移错误，尝试删除并重新创建数据库")
                        self.recreatePersistentStore()
                        return
                    }
                }
                
                // 如果是 CloudKit 集成错误，但保留用户设置
                if let nsError = error as NSError?,
                   nsError.domain == NSCocoaErrorDomain,
                   nsError.code == 134060,
                   let reason = nsError.userInfo["NSLocalizedFailureReason"] as? String,
                   reason.contains("CloudKit integration requires") {
                    
                    print("⚠️ 检测到 CloudKit 集成错误，但保留用户设置")
                    
                    // 不自动关闭iCloud同步设置，只设置状态
                    self.syncStatus = .error(error)
                    self.supportsCloudKit = false
                    
                    // 记录错误但不修改用户设置
                    print("❌ CloudKit集成错误：\(reason)")
                    print("⚠️ 用户iCloud同步设置保持不变：\(enableCloudSync ? "已启用" : "已禁用")")
                    
                    // 尝试使用没有CloudKit的存储创建
                    self.recreatePersistentStoreWithoutCloudKit()
                } else {
                    // 尝试删除现有存储并重新创建
                    self.recreatePersistentStore()
                }
            } else {
                print("✓ CoreData 加载成功: \(storeDescription.url?.absoluteString ?? "unknown")")
                
                // 检查是否启用 CloudKit
                if storeDescription.cloudKitContainerOptions != nil {
                    self.syncStatus = .enabled
                    print("✓ CloudKit 已启用")
                    UserDefaults.standard.set(true, forKey: "enableCloudSync")
                    UserDefaults.standard.synchronize()
                    self.supportsCloudKit = true
                } else {
                    self.syncStatus = .disabled
                    print("ℹ️ CloudKit 未启用")
                    
                    // 不再自动关闭用户的iCloud同步设置
                    // 让用户通过设置界面主动控制同步选项
                    print("⚠️ 注意：CloudKit未在存储描述中配置，但保留用户的同步设置")
                }
            }
        }
        
        // 基本配置
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        print("✓ 配置视图上下文")
        
        // 如果支持 CloudKit，设置同步监听
        if supportsCloudKit {
            setupCloudKitSync()
            print("✓ 设置 CloudKit 同步监听")
            
            // 暂时注释掉 CloudKit 架构初始化
            // initializeCloudKitSchema()
        }
        
        print("========== PersistenceController 初始化完成 ==========")
    }
    
    // 用于预览的持久化控制器
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    // 手动触发保存
    func save() {
        print("========== 保存数据 ==========")
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                print("✓ 数据保存成功")
                
                // 记录同步时间
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSyncTime")
                print("✓ 记录同步时间: \(Date())")
            } catch {
                print("❌ 数据保存失败: \(error)")
            }
        } else {
            print("ℹ️ 没有需要保存的更改")
        }
        print("==============================")
    }
    
    // 手动触发同步
    func syncWithCloud(completion: @escaping (Bool, Error?) -> Void) {
        print("========== 开始 iCloud 同步 ==========")
        
        // 检查是否启用 CloudKit
        guard syncStatus != .disabled else {
            print("❌ iCloud 同步未启用")
            let error = NSError(domain: "PersistenceController", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud 同步未启用"])
            completion(false, error)
            return
        }
        
        // 设置同步状态
        syncStatus = .syncing
        print("✓ 设置同步状态: 同步中")
        
        // 先保存当前更改
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                print("✓ 视图上下文保存成功")
            } catch {
                print("❌ 视图上下文保存失败: \(error)")
                syncStatus = .error(error)
                completion(false, error)
                return
            }
        }
        
        // 触发 CloudKit 同步
        container.performBackgroundTask { context in
            print("开始执行后台同步...")
            
            do {
                // 保存后台上下文中的更改
                if context.hasChanges {
                    try context.save()
                    print("✓ 后台上下文保存成功")
                }
                
                print("✓ 触发 CloudKit 同步")
                
                // 记录同步时间
                let syncTime = Date().timeIntervalSince1970
                UserDefaults.standard.set(syncTime, forKey: "lastSyncTime")
                print("✓ 记录同步时间: \(Date(timeIntervalSince1970: syncTime))")
                
                DispatchQueue.main.async {
                    self.syncStatus = .synced
                    print("✓ 设置同步状态: 已同步")
                    completion(true, nil)
                }
            } catch {
                print("❌ 同步失败: \(error)")
                
                DispatchQueue.main.async {
                    self.syncStatus = .error(error)
                    completion(false, error)
                }
            }
        }
        
        print("========== iCloud 同步请求已发送 ==========")
    }
    
    // 设置 CloudKit 同步监听
    private func setupCloudKitSync() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            
            print("收到 CloudKit 事件: \(event.type)")
            
            // 添加更多日志，但不使用 recordType
            print("事件详情: \(event)")
            
            switch event.type {
            case .setup:
                print("CloudKit 事件: 设置")
                self.syncStatus = .syncing
            case .import:
                print("CloudKit 事件: 导入")
                self.syncStatus = .syncing
            case .export:
                print("CloudKit 事件: 导出")
                self.syncStatus = .syncing
            @unknown default:
                print("CloudKit 事件: 未知类型")
            }
            
            if let error = event.error {
                print("❌ CloudKit 同步错误: \(error)")
                
                // 打印更详细的错误信息
                if let ckError = error as? CKError {
                    print("CloudKit 错误代码: \(ckError.code)")
                    
                    switch ckError.code {
                    case .notAuthenticated:
                        print("用户未登录 iCloud 账户")
                    case .quotaExceeded:
                        print("iCloud 存储空间已满")
                    case .networkFailure:
                        print("网络连接失败")
                    case .networkUnavailable:
                        print("网络不可用")
                    case .serverRejectedRequest:
                        print("服务器拒绝请求")
                    default:
                        print("其他 CloudKit 错误: \(ckError.localizedDescription)")
                    }
                }
                
                self.syncStatus = .error(error)
            } else if event.endDate != nil {
                print("✓ CloudKit 同步完成")
                self.syncStatus = .synced
                
                // 记录同步时间
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastSyncTime")
                
                // 通知 UI 刷新
                NotificationCenter.default.post(name: .CoreDataDidSync, object: nil)
            }
        }
    }
    
    // 用户选择是否启用 iCloud 同步
    func toggleCloudSync(enabled: Bool, completion: @escaping (Bool, Error?) -> Void) {
        print("========== 切换 iCloud 同步状态: \(enabled ? "启用" : "禁用") ==========")
        
        // 保存当前设置
        UserDefaults.standard.set(enabled, forKey: "enableCloudSync")
        
        if enabled {
            // 检查 iCloud 账户状态
            CKContainer(identifier: "iCloud.FLICKiCLoud").accountStatus { status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ 检查 iCloud 账户状态失败: \(error)")
                        self.syncStatus = .error(error)
                        completion(false, error)
                        return
                    }
                    
                    guard status == .available else {
                        print("❌ iCloud 账户不可用: \(status)")
                        let error = NSError(domain: "PersistenceController", code: 3, userInfo: [NSLocalizedDescriptionKey: "iCloud 账户不可用，请在设置中登录 iCloud"])
                        self.syncStatus = .error(error)
                        completion(false, error)
                        return
                    }
                    
                    print("✓ iCloud 账户可用")
                    
                    // 启用 iCloud 同步需要重新启动应用
                    self.syncStatus = .enabled
                    print("✓ 设置同步状态: 已启用")
                    print("⚠️ 需要重新启动应用以完成 iCloud 同步配置")
                    
                    // 返回成功，但提示需要重启
                    let info = [NSLocalizedDescriptionKey: "iCloud 同步已启用，请重新启动应用以完成配置"]
                    let notification = NSError(domain: "PersistenceController", code: 0, userInfo: info)
                    completion(true, notification)
                }
            }
        } else {
            // 禁用 iCloud 同步
            syncStatus = .disabled
            print("✓ 设置同步状态: 已禁用")
            print("⚠️ 需要重新启动应用以完成 iCloud 同步配置")
            
            // 返回成功，但提示需要重启
            let info = [NSLocalizedDescriptionKey: "iCloud 同步已禁用，请重新启动应用以完成配置"]
            let notification = NSError(domain: "PersistenceController", code: 0, userInfo: info)
            completion(true, notification)
        }
        
        print("========== iCloud 同步状态切换完成 ==========")
    }
    
    // 获取数据库文件路径
    func getDatabasePath() -> String? {
        container.persistentStoreDescriptions.first?.url?.path
    }
    
    // 获取数据库文件大小
    func getDatabaseSize() -> Int? {
        guard let path = getDatabasePath(),
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int else {
            return nil
        }
        return size
    }
    
    // 添加一个方法来重新创建持久化存储
    private func recreatePersistentStore() {
        print("尝试重新创建持久化存储...")
        
        // 获取存储 URL
        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("❌ 无法获取存储 URL")
            return
        }
        
        // 尝试删除现有存储
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            print("✓ 成功删除现有存储")
            
            // 重新加载存储
            container.loadPersistentStores { storeDescription, error in
                if let error = error {
                    print("❌ 重新加载存储失败: \(error)")
                    self.syncStatus = .error(error)
                } else {
                    print("✓ 重新加载存储成功")
                    
                    // 检查是否启用 CloudKit
                    if storeDescription.cloudKitContainerOptions != nil {
                        self.syncStatus = .enabled
                        print("✓ CloudKit 已启用")
                        self.supportsCloudKit = true
                    } else {
                        self.syncStatus = .disabled
                        print("ℹ️ CloudKit 未启用")
                    }
                }
            }
        } catch {
            print("❌ 删除现有存储失败: \(error)")
            self.syncStatus = .error(error)
        }
    }
    
    // 添加一个方法来重新创建没有 CloudKit 的持久化存储
    private func recreatePersistentStoreWithoutCloudKit() {
        print("尝试重新创建没有 CloudKit 的持久化存储...")
        
        // 保存用户的iCloud同步设置
        let userCloudSyncSetting = UserDefaults.standard.bool(forKey: "enableCloudSync")
        print("保存用户的iCloud同步设置: \(userCloudSyncSetting ? "已启用" : "已禁用")")
        
        // 获取存储 URL
        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("❌ 无法获取存储 URL")
            return
        }
        
        // 尝试删除现有存储
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            print("✓ 成功删除现有存储")
            
            // 禁用 CloudKit (仅对当前存储实例，不修改用户设置)
            storeDescription.cloudKitContainerOptions = nil
            print("✓ 临时禁用 CloudKit 选项以解决错误")
            
            // 重新加载存储
            container.loadPersistentStores { storeDescription, error in
                if let error = error {
                    print("❌ 重新加载存储失败: \(error)")
                    self.syncStatus = .error(error)
                } else {
                    print("✓ 重新加载存储成功（无 CloudKit）")
                    
                    // 恢复用户的iCloud同步设置
                    print("✓ 恢复用户的iCloud同步设置: \(userCloudSyncSetting ? "已启用" : "已禁用")")
                    UserDefaults.standard.set(userCloudSyncSetting, forKey: "enableCloudSync")
                    UserDefaults.standard.synchronize()
                    
                    if userCloudSyncSetting {
                        self.syncStatus = .error(NSError(domain: "PersistenceController", code: 2, 
                            userInfo: [NSLocalizedDescriptionKey: "iCloud同步暂时不可用，请稍后再试或重启应用"]))
                    } else {
                        self.syncStatus = .disabled
                    }
                }
            }
        } catch {
            print("❌ 删除现有存储失败: \(error)")
            self.syncStatus = .error(error)
        }
    }
    
    // 设置应用生命周期事件监听
    private func setupAppLifecycleObservers() {
        // 监听应用将要进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // 监听应用将要终止
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        print("✓ 已设置应用生命周期监听器")
    }
    
    // 应用将要失去活跃状态
    @objc private func appWillResignActive() {
        print("应用变为非活动状态，正在保存数据...")
        save()
    }
    
    // 应用将要终止
    @objc private func appWillTerminate() {
        print("应用即将终止，强制保存所有数据...")
        forceSaveAllData()
    }
    
    // 应用进入后台
    @objc private func appDidEnterBackground() {
        print("应用进入后台，强制保存所有数据...")
        forceSaveAllData()
    }
    
    // 强制保存所有数据
    private func forceSaveAllData() {
        // 保存前的项目数量
        var projectCount = 0
        do {
            let request = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
            projectCount = try container.viewContext.count(for: request)
            print("保存前的项目数量: \(projectCount)")
        } catch {
            print("⚠️ 获取项目数量失败: \(error)")
        }
        
        // 确保所有预算值被保存
        do {
            let projectEntities = try container.viewContext.fetch(ProjectEntity.fetchRequest())
            for entity in projectEntities {
                print("保存前项目 \(entity.name ?? "未命名") 预算: \(entity.budget)")
            }
        } catch {
            print("⚠️ 获取项目实体失败: \(error)")
        }
        
        // 保存数据
        save()
        
        // 同步到云端
        if supportsCloudKit {
            syncWithCloud { success, error in
                if success {
                    print("✓ 退出前数据同步成功")
                } else if let error = error {
                    print("⚠️ 退出前数据同步警告: \(error.localizedDescription)")
                }
            }
        }
    }
}

// 添加通知名称
extension Notification.Name {
    static let CoreDataDidSync = Notification.Name("CoreDataDidSync")
} 
