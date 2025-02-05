import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var projectStore: ProjectStore
    
    var body: some View {
        TabView {
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
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
        .environmentObject(projectStore)
    }
} 