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
            VStack(spacing: 0) {
                    // 项目统计卡片（并排显示，无滚动）
                ProjectStatCards()
                    .environmentObject(projectStore)
                    .padding(.top)
                
                    // 项目列表
                List {
                    ForEach(searchedProjects) { project in
                        ProjectListRow(project: project)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 0)
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
                        // 禁用Alert防止用户连续操作
                        projectToDelete = nil
                        
                        // 使用Task异步处理删除操作
                        Task {
                            // 先在UI上延迟一下，让弹窗完全关闭
                            try? await Task.sleep(nanoseconds: 300_000_000) // 等待300毫秒
                            
                            // 在主线程上调用删除方法
                            await MainActor.run {
                            projectStore.deleteProject(project)
                            }
                        }
                    }
                }
            } message: {
                if let project = projectToDelete {
                    Text("确定要删除项目「\(project.name)」吗？此操作不可撤销。")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DeleteProject"))) { notification in
                if let project = notification.userInfo?["project"] as? Project {
                    projectToDelete = project
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
    
    private var searchedProjects: [Project] {
        filteredProjects.filter { project in
            searchText.isEmpty ||
            project.name.localizedCaseInsensitiveContains(searchText) ||
            project.director.localizedCaseInsensitiveContains(searchText) ||
            project.producer.localizedCaseInsensitiveContains(searchText)
        }
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

// 项目统计卡片组件
struct ProjectStatCards: View {
    @EnvironmentObject var projectStore: ProjectStore

    // 计算独立的统计数据
    private var totalProjects: Int {
        projectStore.projects.count
    }
    
    private var totalTasks: Int {
        // 计算所有项目中的任务总数（排除重复）
        var taskCount = 0
        for project in projectStore.projects {
            taskCount += project.tasks.count
        }
        return taskCount
    }
    
    private var activeTasks: Int {
        // 计算未完成的任务数量
        var count = 0
        for project in projectStore.projects {
            count += project.tasks.filter { !$0.isCompleted }.count
        }
        return count
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max((geometry.size.width - 16 - 32) / 2, 0)
            HStack(spacing: 16) {
                StatCard(
                    title: "项目总数",
                    value: "\(totalProjects)",
                    color: .blue,
                    icon: "folder.fill"
                )
                .frame(width: width)
                StatCard(
                    title: "任务总数",
                    value: "\(totalTasks)",
                    color: .orange,
                    icon: "list.bullet.clipboard.fill"
            
                )
                .frame(width: width)
            }
            .padding(.horizontal)
        }
        .frame(height: 100)
    }
}

// 新增项目行组件
struct ProjectListRow: View {
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            ProjectCard(project: project)
                .padding(.horizontal, 16)
            
            NavigationLink(destination: {
                if let binding = projectStore.binding(for: project.id) {
                    ProjectDetailView(project: binding)
                }
            }) {
                EmptyView()
            }
            .opacity(0)
        }
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.6 : 1.0)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // 防止重复点击
                guard !isDeleting else { return }
                
                // 设置状态防止重复操作
                isDeleting = true
                
                // 使用Task包装删除操作
                Task {
                    // 先在UI上延迟一下，让滑动动画完成
                    try? await Task.sleep(nanoseconds: 300_000_000) // 等待300毫秒
                    
                    // 发送删除通知
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Notification.Name("DeleteProject"),
                            object: nil,
                            userInfo: ["project": project]
                        )
                    }
                    
                    // 重置状态
                    isDeleting = false
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

#Preview {
    ProjectsView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 
