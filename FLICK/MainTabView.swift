import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var projectStore: ProjectStore
    
    var body: some View {
        TabView {
            FeatureView()
                .tabItem {
                    Label("功能", systemImage: "star")
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
    }
} 
