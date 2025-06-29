import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingAddProject = false
    @State private var searchText = ""
    @State private var selectedStatus: Project.Status = .inProgress
    @State private var projectToDelete: Project? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题
                ZStack {
                    Text("项目")
                        .font(.title3)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        Button(action: { showingAddProject = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("添加项目")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索项目", text: $searchText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
            VStack(spacing: 0) {
                    // 替换StatusTabBar为分段选择器
                    HStack(spacing: 16) {
                        ForEach([Project.Status.inProgress, Project.Status.completed], id: \.self) { status in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedStatus = status
                                }
                            }) {
                                HStack(spacing: 7) {
                                    Image(systemName: status == .inProgress ? "bolt.horizontal.fill" : "checkmark.seal.fill")
                                        .font(.system(size: 19, weight: .bold))
                                    Text(status == .inProgress ? "进行中" : "已完成")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(selectedStatus == status ? .white : .primary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 24)
                                .background(
                                    ZStack {
                                        if selectedStatus == status {
                                            LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                        } else {
                                            Color(.systemGray5)
                                        }
                                    }
                                )
                                .cornerRadius(20)
                                .shadow(color: selectedStatus == status ? Color.accentColor.opacity(0.18) : .clear, radius: 6, x: 0, y: 2)
                                .scaleEffect(selectedStatus == status ? 1.06 : 1.0)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
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
                    ForEach(searchedProjects, id: \.id) { project in
                        ProjectListRow(project: project)
                            .environmentObject(projectStore)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .id(project.id) // 确保每个项目有唯一ID
                    }
                    .onDelete { indexSet in
                        // 使用SwiftUI原生的删除方法，更安全
                        for index in indexSet {
                            let project = searchedProjects[index]
                            projectToDelete = project
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                    }
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
                    // 设置为nil以关闭弹窗
                    projectToDelete = nil
                    
                    // 通知删除取消
                    if let project = projectToDelete {
                        NotificationCenter.default.post(
                            name: Notification.Name("ProjectDeleted"),
                            object: nil,
                            userInfo: ["projectId": project.id]
                        )
                    }
                }
                Button("删除", role: .destructive) {
                    if let project = projectToDelete {
                        // 清空删除项目引用，防止重复操作
                        projectToDelete = nil
                        
                        // 禁用UI交互，减少用户点击
                        isRefreshing = true
                        
                        // 立即执行删除操作
                        projectStore.deleteProject(project)
                        
                        // 立即恢复UI状态
                        isRefreshing = false
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
            .disabled(isRefreshing) // 禁用整个界面当正在刷新时
            .overlay(
                // 显示加载指示器
                isRefreshing ? 
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                    : nil
            )
        }
    }
    
    // 获取状态标题
    private func statusTitle(for status: Project.Status) -> String {
        switch status {
        case .all: return ""
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        default: return ""
        }
    }
    
    private var filteredProjects: [Project] {
        projectStore.projects.filter { project in
            switch selectedStatus {
            case .inProgress:
                return project.status == .inProgress
            case .completed:
                return project.status == .completed
            default:
                return false
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
    @ObservedObject var project: Project
    
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
    @ObservedObject var project: Project
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            ProjectCard(project: project)
            
            NavigationLink(destination: {
                if let binding = projectStore.binding(for: project.id) {
                    ProjectDetailView(project: binding)
                } else {
                    // 如果项目不存在，显示错误页面
                    ProjectNotFoundView()
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDeleting = true
                }
                
                // 使用更安全的方式发送删除通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("DeleteProject"),
                        object: nil,
                        userInfo: ["project": project]
                    )
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

// 项目未找到视图
struct ProjectNotFoundView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("项目不存在")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("该项目可能已被删除")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("返回") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("错误")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProjectsView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 
