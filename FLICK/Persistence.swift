import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    // 预览用的持久化控制器
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // 创建示例数据
        let project = Project(context: context)
        project.id = UUID()
        project.name = "示例项目"
        project.director = "张导"
        project.producer = "李制片"
        project.startDate = Date()
        project.colorHex = "#007AFF"
        project.status = 0
        project.createdAt = Date()
        project.updatedAt = Date()
        
        try? context.save()
        return controller
    }()
    
    let container: NSPersistentContainer
    
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
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // 保存上下文
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
} 