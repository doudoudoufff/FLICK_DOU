//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import CoreData

@main
struct FLICKApp: App {
    let persistenceController: PersistenceController
    
    init() {
        // 确保 PersistenceController 完全初始化
        persistenceController = PersistenceController.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environmentObject(ProjectStore(context: persistenceController.container.viewContext))
                .onAppear {
                    // 应用启动后，请求通知权限
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
