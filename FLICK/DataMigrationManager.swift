import Foundation
import CoreData

class DataMigrationManager {
    static let shared = DataMigrationManager()
    private let userDefaults = UserDefaults.standard
    private let hasPerformedMigrationKey = "hasPerformedInitialMigration"
    
    func checkAndMigrateDataIfNeeded(context: NSManagedObjectContext) {
        guard !userDefaults.bool(forKey: hasPerformedMigrationKey) else { return }
        
        // 从 UserDefaults 读取旧数据
        if let data = userDefaults.data(forKey: "savedProjects"),
           let oldProjects = try? JSONDecoder().decode([ProjectModel].self, from: data) {
            
            // 迁移每个项目
            for oldProject in oldProjects {
                let _ = Project.create(from: oldProject, in: context)
            }
            
            // 保存 CoreData 上下文
            do {
                try context.save()
                userDefaults.set(true, forKey: hasPerformedMigrationKey)
            } catch {
                print("Migration error: \(error)")
            }
        }
    }
} 