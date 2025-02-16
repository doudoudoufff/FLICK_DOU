//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI

@main
struct FLICKApp: App {
    @StateObject private var projectStore = ProjectStore()
    
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
