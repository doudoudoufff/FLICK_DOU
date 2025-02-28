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
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environmentObject(ProjectStore(context: persistenceController.container.viewContext))
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
