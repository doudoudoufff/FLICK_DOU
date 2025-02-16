//
//  ContentView.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var projectStore = ProjectStore.withTestData()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else {
                MainTabView()
                    .environmentObject(projectStore)
                    .task {
                        await projectStore.loadProjects()
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
