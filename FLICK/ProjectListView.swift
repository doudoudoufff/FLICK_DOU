import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingAddProject = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(projectStore.projects) { project in
                    NavigationLink {
                        if let binding = projectStore.binding(for: project.id) {
                            ProjectDetailView(project: binding)
                        }
                    } label: {
                        ProjectRowView(project: project)
                    }
                }
                .onDelete { indexSet in
                    projectStore.projects.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("项目")
            .toolbar {
                Button {
                    showingAddProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(isPresented: $showingAddProject, projectStore: projectStore)
            }
        }
    }
}

// 抽取项目行视图为单独的组件
struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
                Text(project.name)
                    .font(.headline)
            }
            
            HStack {
                Label(project.director, systemImage: "megaphone")
                Spacer()
                Text(project.startDate.chineseStyleShortString())
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectListView()
        .environmentObject(ProjectStore())
} 