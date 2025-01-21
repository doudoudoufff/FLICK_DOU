import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var searchText = ""
    @State private var showingAddProject = false
    
    var body: some View {
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
                    ForEach($projectStore.projects) { $project in
                        if searchText.isEmpty || 
                           project.name.localizedCaseInsensitiveContains(searchText) ||
                           project.director.localizedCaseInsensitiveContains(searchText) ||
                           project.producer.localizedCaseInsensitiveContains(searchText) {
                            NavigationLink(destination: ProjectDetailView(project: $project)) {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(PlainButtonStyle())
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
            AddProjectView(isPresented: $showingAddProject, projects: $projectStore.projects)
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
    
    // 添加日期格式化器
    private let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    private let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年"
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧内容
            VStack(alignment: .leading, spacing: 16) {
                // 顶部：项目名称和任务数
                HStack(alignment: .center, spacing: 12) {
                    // 颜色标识
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.color)
                        .frame(width: 6, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        
                        Text("\(project.tasks.count)个任务")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 中间：项目信息
                HStack(spacing: 16) {
                    // 导演信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("导演")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(project.director)
                            .font(.subheadline)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // 制片信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("制片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(project.producer)
                            .font(.subheadline)
                    }
                }
                
                // 底部：进度条（如果有任务）
                if !project.tasks.isEmpty {
                    ProgressView(value: Double(project.tasks.filter { $0.isCompleted }.count) / Double(project.tasks.count))
                        .tint(project.color)
                }
            }
            
            // 右侧时间显示
            VStack(alignment: .trailing) {
                Text(monthDayFormatter.string(from: project.startDate))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.medium)
                
                Text(yearFormatter.string(from: project.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80) // 调整宽度以适应中文显示
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// 状态标签组件
struct StatusBadge: View {
    let status: Project.ProjectStatus
    
    var statusInfo: (text: String, color: Color) {
        switch status {
        case .planning:
            return ("筹备中", .orange)
        case .shooting:
            return ("拍摄中", .blue)
        case .postProduction:
            return ("后期中", .purple)
        case .completed:
            return ("已完成", .green)
        }
    }
    
    var body: some View {
        Text(statusInfo.text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusInfo.color.opacity(0.1))
            .clipShape(Capsule())
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
} 