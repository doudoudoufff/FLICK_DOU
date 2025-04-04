import CoreData
import CloudKit

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
        
        // 首先使用普通容器
        container = NSPersistentContainer(name: "FLICK")
        print("✓ 创建 NSPersistentContainer")
        
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
                
                // 如果是 CloudKit 集成错误，禁用 CloudKit
                if let nsError = error as NSError?,
                   nsError.domain == NSCocoaErrorDomain,
                   nsError.code == 134060,
                   let reason = nsError.userInfo["NSLocalizedFailureReason"] as? String,
                   reason.contains("CloudKit integration requires") {
                    
                    print("⚠️ 检测到 CloudKit 集成错误，禁用 CloudKit")
                    
                    // 禁用 CloudKit
                    UserDefaults.standard.set(false, forKey: "enableCloudSync")
                    self.syncStatus = .disabled
                    self.supportsCloudKit = false
                    
                    // 重新创建没有 CloudKit 的存储
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
                    self.supportsCloudKit = true
                } else {
                    self.syncStatus = .disabled
                    print("ℹ️ CloudKit 未启用")
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
            
            // 禁用 CloudKit
            storeDescription.cloudKitContainerOptions = nil
            print("✓ 禁用 CloudKit")
            
            // 重新加载存储
            container.loadPersistentStores { storeDescription, error in
                if let error = error {
                    print("❌ 重新加载存储失败: \(error)")
                    self.syncStatus = .error(error)
                } else {
                    print("✓ 重新加载存储成功（无 CloudKit）")
                    self.syncStatus = .disabled
                    print("ℹ️ CloudKit 已禁用")
                }
            }
        } catch {
            print("❌ 删除现有存储失败: \(error)")
            self.syncStatus = .error(error)
        }
    }
    
}

// 添加通知名称
extension Notification.Name {
    static let CoreDataDidSync = Notification.Name("CoreDataDidSync")
} 
