//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import CoreData
import WeatherKit

@main
struct FLICKApp: App {
    let persistenceController: PersistenceController
    
    init() {
        // 确保 PersistenceController 完全初始化
        persistenceController = PersistenceController.shared
        
        // 配置应用程序
        configureApp()
    }
    
    // 配置应用程序的各种服务
    private func configureApp() {
        // 预先配置通知权限请求，但不在启动时立即执行
        // 因为这可能会触发系统权限弹窗
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: self.persistenceController.container.viewContext)
                .environmentObject(ProjectStore(context: self.persistenceController.container.viewContext))
                .onAppear {
                    // 应用启动后，异步请求通知权限，避免阻塞UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        NotificationManager.shared.requestAuthorization()
                    }
                    
                    // 异步加载天气数据，避免阻塞UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        WeatherManager.shared.fetchWeatherData()
                    }
                }
        }
    }
}
