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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
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
            .onAppear {
                print("ContentView已加载，项目数: \(projectStore.projects.count)")
            }
    }
}

#Preview {
    let previewContext = PersistenceController.preview.container.viewContext
    let store = ProjectStore(context: previewContext)
    
    return ContentView(context: previewContext)
        .environmentObject(store)
}
