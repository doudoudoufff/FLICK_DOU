import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var notificationHandler: AppNotificationHandler
    
    var body: some View {
        TabView {
            FeatureView()
                .environmentObject(notificationHandler)
                .tabItem {
                    Label("功能", systemImage: "square.grid.2x2")
                }
            NavigationStack {
                OverviewView()
            }
            .tabItem {
                Label("总览", systemImage: "calendar")
            }
            
            NavigationStack {
                ProjectsView()
            }
            .tabItem {
                Label("项目", systemImage: "folder")
            }
        }
        .preferredColorScheme(.light)
    }
} 
