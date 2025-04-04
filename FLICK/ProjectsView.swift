import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingAddProject = false
    @State private var searchText = ""
    @State private var selectedStatus: Project.Status = .all
    @State private var projectToDelete: Project? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 项目统计卡片
                    HStack(spacing: 16) {
                        StatCard(
                            title: "全部项目",
                            value: "\(projectStore.projects.count)",
                            icon: "film.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "总任务数",
                            value: "\(projectStore.projects.flatMap { $0.tasks }.count)",
                            icon: "list.bullet.clipboard.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // 项目列表
                    LazyVStack(spacing: 16) {
                        ForEach(filteredProjects) { project in
                            if searchText.isEmpty || 
                               project.name.localizedCaseInsensitiveContains(searchText) ||
                               project.director.localizedCaseInsensitiveContains(searchText) ||
                               project.producer.localizedCaseInsensitiveContains(searchText) {
                                NavigationLink {
                                    if let binding = projectStore.binding(for: project.id) {
                                        ProjectDetailView(project: binding)
                                    }
                                } label: {
                                    ProjectCard(project: project)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {  // 使用长按菜单替代滑动
                                    Button(role: .destructive) {
                                        projectToDelete = project
                                    } label: {
                                        Label("删除项目", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "搜索项目")
            .navigationTitle("项目")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(isPresented: $showingAddProject)
                    .environmentObject(projectStore)
            }
            .alert("确认删除", isPresented: .init(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            )) {
                Button("取消", role: .cancel) {
                    projectToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let project = projectToDelete {
                        withAnimation {
                            projectStore.deleteProject(project)
                        }
                    }
                    projectToDelete = nil
                }
            } message: {
                if let project = projectToDelete {
                    Text("确定要删除项目「\(project.name)」吗？此操作不可撤销。")
                }
            }
            .refreshable {
                // 触发 CoreData 刷新和 iCloud 同步
                projectStore.loadProjects()
                projectStore.sync()
                
                // 如果需要异步等待
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
            }
        }
    }
    
    private var filteredProjects: [Project] {
        projectStore.projects.filter { project in
            switch selectedStatus {
            case .all: return true
            case .preProduction: return project.status == .preProduction
            case .production: return project.status == .production
            case .postProduction: return project.status == .postProduction
            case .completed: return project.status == .completed
            case .cancelled: return project.status == .cancelled
            }
        }
    }
}

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .imageScale(.small)
                Text(title)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// 项目卡片组件
struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：项目名称、状态和时间
            HStack(alignment: .center) {
                // 左侧：颜色标识和项目名称
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(project.color)
                        .frame(width: 4, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text("\(project.tasks.count)个任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 右侧：时间显示
                VStack(alignment: .trailing, spacing: 2) {
                    Text(project.startDate.chineseStyleShortString())
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                    Text("\(Calendar.current.component(.year, from: project.startDate))年")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 底部：项目信息
            HStack {
                // 导演信息
                if !project.director.isEmpty {
                    Label(project.director, systemImage: "megaphone")
                }
                
                // 制片信息
                if !project.producer.isEmpty {
                    if !project.director.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                    }
                    Label(project.producer, systemImage: "person")
                }
                
                Spacer()
                
                // 状态标签
                StatusBadge(status: project.status)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// 信息行组件
struct InfoRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            Text(content)
        }
        .font(.subheadline)
    }
}

#Preview {
    ProjectsView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 