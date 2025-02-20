//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI

@main
struct FLICKApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // 执行数据迁移
        DataMigrationManager.shared.checkAndMigrateDataIfNeeded(
            context: persistenceController.container.viewContext
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
