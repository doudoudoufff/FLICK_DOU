import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    // 用于预览的持久化控制器
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FLICK")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // 打印数据库相关路径
        printDatabasePaths()
    }
    
    // 打印所有相关路径信息
    private func printDatabasePaths() {
        print("\n=== CoreData 数据库信息 ===")
        
        #if targetEnvironment(simulator)
        // 模拟器环境
        print("运行环境：模拟器")
        // 获取模拟器的 Home 目录
        if let simulatorHome = ProcessInfo.processInfo.environment["HOME"] {
            print("模拟器 Home 目录：\(simulatorHome)")
        }
        
        // 获取模拟器设备 UUID
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path,
           let deviceUUID = documentsPath.split(separator: "/").first(where: { $0.count == 36 }) {
            print("模拟器设备 UUID：\(deviceUUID)")
        }
        #else
        // 真机环境
        print("运行环境：真机")
        #endif
        
        // 数据库文件路径
        if let dbURL = container.persistentStoreDescriptions.first?.url {
            print("\n数据库文件路径：")
            print(dbURL.path)
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: dbURL.path) {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: dbURL.path) {
                    print("\n数据库文件信息：")
                    print("- 大小：\(attributes[.size] ?? 0) bytes")
                    print("- 创建时间：\(attributes[.creationDate] ?? Date())")
                    print("- 修改时间：\(attributes[.modificationDate] ?? Date())")
                }
                
                #if targetEnvironment(simulator)
                // 模拟器环境下的访问命令
                print("\n在终端中访问数据库：")
                print("1. 获取应用容器路径：")
                print("   xcrun simctl get_app_container booted douzi.FLICK data")
                print("2. 访问数据库：")
                print("   sqlite3 `xcrun simctl get_app_container booted douzi.FLICK data`/Library/Application\\ Support/FLICK.sqlite")
                #endif
            } else {
                print("\n数据库文件尚未创建")
            }
        }
        
        print("\n=== 信息打印完成 ===\n")
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
} 