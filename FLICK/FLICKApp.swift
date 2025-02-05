//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import LeanCloud

@main
struct FLICKApp: App {
    @StateObject private var projectStore = ProjectStore()
    
    init() {
        // 确保 LCManager 在应用启动时初始化
        _ = LCManager.shared
        do {
                // 替换成你的LeanCloud应用信息（下一步教你怎么找）
                try LCApplication.default.set(
                    id: "uUImyopEtEIc2swq7A2S4Zij-gzGzoHsz",
                    key: "775aKsl0DyGLJ9B45KB5scJn",
                    serverURL: "https://uuimyope.lc-cn-n1-shared.com"
                )
            } catch {
                print("初始化失败：\(error)")
            }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
