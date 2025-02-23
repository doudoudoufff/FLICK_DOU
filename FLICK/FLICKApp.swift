//
//  FLICKApp.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI

@main
struct FLICKApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(ProjectStore(context: persistenceController.container.viewContext))
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
