//
//  ContentView.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var notificationHandler: AppNotificationHandler
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedProject: Project?
    @State private var isAddAccountPresented = false
    
    init(context: NSManagedObjectContext) {
        // 注意：ProjectStore将从FLICKApp通过environmentObject传入，
        // 这里不再创建新实例，避免多个实例导致数据不一致
    }
    
    var body: some View {
        MainTabView()
            .sheet(isPresented: .constant(!hasSeenOnboarding)) {
                OnboardingView()
                    .presentationDetents([.fraction(0.75), .large])
            }
            .sheet(isPresented: $isAddAccountPresented) {
                if let project = selectedProject {
                    AddAccountView(isPresented: $isAddAccountPresented, project: .constant(project))
                        .environmentObject(projectStore)
                }
            }
            .onAppear {
                print("ContentView已加载，项目数: \(projectStore.projects.count)")
            }
            .onChange(of: notificationHandler.showAddAccountView) { show in
                if show {
                    // 找到选中的项目
                    if let projectId = notificationHandler.selectedProjectId,
                       let project = projectStore.projects.first(where: { $0.id == projectId }) {
                        selectedProject = project
                        isAddAccountPresented = true
                        // 重置通知处理器状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            notificationHandler.showAddAccountView = false
                        }
                    }
                }
            }
    }
}

#Preview {
    let previewContext = PersistenceController.preview.container.viewContext
    let store = ProjectStore(context: previewContext)
    
    return ContentView(context: previewContext)
        .environmentObject(store)
}
