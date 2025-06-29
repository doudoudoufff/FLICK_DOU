import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingAddProject = false
    
    var body: some View {
        List {
            ForEach(projectStore.projects) { project in
                ProjectRowView(project: project)
                    .environmentObject(projectStore)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let project = projectStore.projects[index]
                    projectStore.deleteProject(project)
                }
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
            AddProjectView(isPresented: $showingAddProject)
                .environmentObject(projectStore)
        }
    }
}

// 抽取项目行视图为单独的组件
struct ProjectRowView: View {
    @ObservedObject var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    
    var body: some View {
        NavigationLink {
            if let binding = projectStore.binding(for: project.id) {
                ProjectDetailView(project: binding)
            } else {
                Text("项目不存在")
            }
        } label: {
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
}

#Preview {
    ProjectListView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 