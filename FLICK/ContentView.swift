//
//  ContentView.swift
//  FLICK
//
//  Created by 11 on 2025/1/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("总览", systemImage: "chart.bar")
                }
            
            ProjectsView()
                .tabItem {
                    Label("项目", systemImage: "folder")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
