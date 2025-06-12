//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import CoreData
import WeatherKit
import CloudKit
import Combine

@main
struct FLICKApp: App {
    let persistenceController: PersistenceController
    @StateObject private var projectStore: ProjectStore
    @Environment(\.scenePhase) private var scenePhase
    
    // 添加通知处理器
    @StateObject private var notificationHandler = AppNotificationHandler()
    
    init() {
        // 确保 PersistenceController 完全初始化
        persistenceController = PersistenceController.shared
        
        // 初始化 ProjectStore 并保存到属性中以确保其生命周期
        let store = ProjectStore(context: persistenceController.container.viewContext)
        _projectStore = StateObject(wrappedValue: store)
        
        // 配置应用程序
        configureApp()
        
        // 打印iCloud同步设置状态
        let isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "enableCloudSync")
        print("应用初始化时的iCloud同步设置: \(isCloudSyncEnabled ? "已启用" : "已禁用")")
    }
    
    // 配置应用程序的各种服务
    private func configureApp() {
        // 清除可能导致 UserDefaults 存储过多数据的备份
        UserDefaults.standard.removeObject(forKey: "savedProjects")
        print("✓ 已清除 UserDefaults 中的项目备份数据")
        
        // 预先配置通知权限请求，但不在启动时立即执行
        // 因为这可能会触发系统权限弹窗
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: self.persistenceController.container.viewContext)
                .environmentObject(projectStore)
                .environmentObject(notificationHandler)
                .preferredColorScheme(.light)
                .onAppear {
                    // 应用启动后，异步请求通知权限，避免阻塞UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        NotificationManager.shared.requestAuthorization()
                    }
                    
                    // 异步加载天气数据，避免阻塞UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        WeatherManager.shared.fetchWeatherData()
                    }
                    
                    // 检查并显示iCloud同步设置
                    let shouldEnableCloudSync = UserDefaults.standard.bool(forKey: "enableCloudSync")
                    print("应用启动完成，当前iCloud同步设置：\(shouldEnableCloudSync ? "已启用" : "未启用")")
                    
                    // 强制加载项目数据
                    print("🔄 应用启动后强制重新加载项目数据")
                    projectStore.loadProjects()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // 应用进入后台时保存数据
                print("应用进入后台，正在保存数据...")
                saveAppData()
            case .inactive:
                // 应用变为非活动状态时保存数据
                print("应用变为非活动状态，正在保存数据...")
                saveAppData()
            case .active:
                // 应用变为活动状态时，检查设置并加载数据
                let isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "enableCloudSync")
                print("应用变为活动状态，当前iCloud同步设置: \(isCloudSyncEnabled ? "已启用" : "已禁用")")
                
                // 当应用重新进入前台时，确保项目数据已加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 应用进入前台后强制重新加载项目数据")
                    projectStore.loadProjects()
                }
            @unknown default:
                break
            }
        }
    }
    
    // 保存应用数据
    private func saveAppData() {
        // 打印当前项目数量，用于调试
        print("保存前的项目数量: \(projectStore.projects.count)")
        
        // 打印每个项目的预算值
        for project in projectStore.projects {
            print("保存前项目 '\(project.name)' 的预算: \(project.budget)")
        }
        
        // 保存CoreData上下文
        persistenceController.save()
        
        // 直接使用 StateObject 的 projectStore 保存，确保使用的是同一个实例
        projectStore.saveProjects()
        
        // 强制再次保存到持久化存储
        do {
            try persistenceController.container.viewContext.save()
            print("✓ 强制保存视图上下文成功")
            
            // 验证预算是否正确保存
            let request = ProjectEntity.fetchRequest()
            if let projectEntities = try? persistenceController.container.viewContext.fetch(request) {
                for entity in projectEntities {
                    print("验证 - 项目 '\(entity.name ?? "未命名")' 的预算值为: \(entity.budget)")
                }
            }
        } catch {
            print("❌ 强制保存视图上下文失败: \(error)")
        }
        
        // 确保iCloud同步设置被保存
        let isCloudSyncEnabled = UserDefaults.standard.bool(forKey: "enableCloudSync")
        print("保存应用状态：iCloud同步设置为 \(isCloudSyncEnabled ? "已启用" : "已禁用")")
        UserDefaults.standard.synchronize()
    }
}

// 应用通知处理器
class AppNotificationHandler: ObservableObject {
    @Published var showAddAccountView = false
    @Published var selectedProjectId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听打开添加账户视图的通知
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddAccountView"))
            .sink { [weak self] notification in
                if let projectId = notification.userInfo?["projectId"] as? UUID {
                    self?.selectedProjectId = projectId
                    self?.showAddAccountView = true
                }
            }
            .store(in: &cancellables)
    }
}
