import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingAddProject = false
    @State private var searchText = ""
    @State private var selectedStatus: Project.Status = .preProduction
    @State private var projectToDelete: Project? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 简化版状态筛选器
                    StatusTabBar(selectedStatus: $selectedStatus)
                        .padding(.top, 10)
                    
                    if projectStore.projects.isEmpty {
                        // 无项目时的提示
                        VStack(spacing: 16) {
                            Spacer()
                            
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.bottom, 8)
                            
                            Text("暂无项目")
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Text("点击右上角的+按钮创建您的第一个项目")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: { showingAddProject = true }) {
                                Text("创建项目")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                            
                            Spacer()
                        }
                    } else if filteredProjects.isEmpty {
                        // 筛选结果为空的提示
                        VStack(spacing: 12) {
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("没有\(statusTitle(for: selectedStatus))项目")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding()
                    } else {
                        // 项目列表
                        List {
                            ForEach(searchedProjects) { project in
                                ProjectListRow(project: project)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
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
    
    // 获取状态标题
    private func statusTitle(for status: Project.Status) -> String {
        switch status {
        case .all: return ""
        case .preProduction: return "前期"
        case .production: return "拍摄"
        case .postProduction: return "后期"
        case .completed: return "完成"
        case .cancelled: return "已取消"
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

// 简化版状态标签栏
struct StatusTabBar: View {
    @Binding var selectedStatus: Project.Status
    @Namespace private var animation
    
    // 定义状态选项
    private let statusOptions: [Project.Status] = [
        .preProduction, .production, .postProduction, .completed
    ]
    
    // 获取状态显示名称
    private func getStatusName(_ status: Project.Status) -> String {
        switch status {
        case .preProduction: return "前期"
        case .production: return "拍摄"
        case .postProduction: return "后期"
        case .completed: return "完成"
        default: return ""
        }
    }
    
    // 获取状态对应图标
    private func getStatusIcon(_ status: Project.Status) -> String {
        switch status {
        case .preProduction: return "doc.text"
        case .production: return "camera"
        case .postProduction: return "slider.horizontal.3"
        case .completed: return "checkmark.circle"
        default: return ""
        }
    }
    
    // 获取状态对应颜色
    private func getStatusColor(_ status: Project.Status) -> Color {
        switch status {
        case .preProduction: return .orange
        case .production: return .green
        case .postProduction: return .purple
        case .completed: return .gray
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            HStack(spacing: 0) {
                ForEach(statusOptions, id: \.self) { status in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedStatus = status
                        }
                    }) {
                        VStack(spacing: 6) {
                            // 图标
                            Image(systemName: getStatusIcon(status))
                                .font(.system(size: selectedStatus == status ? 18 : 16))
                                .foregroundColor(selectedStatus == status ? getStatusColor(status) : .secondary)
                                .frame(height: 24)
                                .scaleEffect(selectedStatus == status ? 1.1 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: selectedStatus == status)
                            
                            // 文字
                            Text(getStatusName(status))
                                .font(.system(size: 15, weight: selectedStatus == status ? .semibold : .medium))
                                .foregroundColor(selectedStatus == status ? .primary : .secondary)
                                .opacity(selectedStatus == status ? 1.0 : 0.7)
                            
                            // 选中指示器
                            ZStack {
                                if selectedStatus == status {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(getStatusColor(status))
                                        .frame(width: 24, height: 3)
                                        .matchedGeometryEffect(id: "underline", in: animation)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 24, height: 3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                if selectedStatus == status {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(getStatusColor(status).opacity(0.1))
                                        .matchedGeometryEffect(id: "background", in: animation)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                            }
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 2)
            .background(Color(.systemBackground))
            
            // 分隔线
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
        }
    }
}

// 自定义按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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

// 新增项目行组件
struct ProjectListRow: View {
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            ProjectCard(project: project)
            
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
