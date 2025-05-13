//
//  ContentView.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var projectStore: ProjectStore
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    init(context: NSManagedObjectContext) {
        _projectStore = StateObject(wrappedValue: ProjectStore(context: context))
    }
    
    var body: some View {
        MainTabView()
            .environmentObject(projectStore)
            .sheet(isPresented: .constant(!hasSeenOnboarding)) {
                OnboardingView()
                    .environmentObject(projectStore)
                    .presentationDetents([.fraction(0.75), .large])
        }
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.container.viewContext)
}
