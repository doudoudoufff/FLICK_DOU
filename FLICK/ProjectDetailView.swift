import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Environment(\.managedObjectContext) private var context
    @State private var showingEditProject = false
    @State private var showingAddTask = false
    @State private var showingLocationScoutingView = false
    @State private var showingBaiBai = false
    
    // 添加进度计算属性
    private var taskProgress: Double {
        guard !project.tasks.isEmpty else { return 0.0 }
        let completedTasks = project.tasks.filter { $0.isCompleted }.count
        return Double(completedTasks) / Double(project.tasks.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 项目信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    Text("项目信息")
                        .font(.headline)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "开始时间", content: project.startDate.chineseStyleString())
                        DetailRow(title: "导演", content: project.director)
                        DetailRow(title: "制片", content: project.producer)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 开机拜拜按钮
                Button {
                    showingBaiBai = true
                } label: {
                    Label("开机拜拜", systemImage: "sparkles.rectangle.stack.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(project.color.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                // 任务列表卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("任务列表")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    // 添加任务进度显示
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(taskProgress * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(project.tasks.filter { $0.isCompleted }.count)/\(project.tasks.count)个任务")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: taskProgress)
                            .tint(project.color)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    if project.tasks.isEmpty {
                        Text("暂无任务")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        List {
                            ForEach($project.tasks) { $task in
                                TaskRow(
                                    task: $task,
                                    project: project,
                                    onDelete: {
                                        withAnimation {
                                            if let index = project.tasks.firstIndex(where: { $0.id == task.id }) {
                                                project.tasks.remove(at: index)
                                            }
                                        }
                                    }
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(project.tasks.count) * 110)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 发票列表卡片
                InvoiceListView(project: $project)
                
                // 账户列表卡片
                AccountListView(project: $project)
                
                // 堪景模块卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("堪景")
                        .font(.headline)
                    
                    Divider()
                    
                    VStack(spacing: 16) {
                        Toggle("启用堪景模块", isOn: $project.isLocationScoutingEnabled)
                            .tint(project.color)
                        
                        if project.isLocationScoutingEnabled {
                            NavigationLink {
                                LocationScoutingView(project: $project)
                                    .environmentObject(projectStore)
                            } label: {
                                Label("堪景", systemImage: "camera.viewfinder")
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(project.name)
                    .font(.headline)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showingEditProject = true
                }) {
                    Text("编辑")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // ... 现有的菜单项 ...
                    
                    NavigationLink {
                        BaiBaiView(projectColor: project.color)
                    } label: {
                        Label("开机拜拜", systemImage: "sparkles")
                    }
                    
                    // ... 其他菜单项 ...
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(
                project: $project,
                isPresented: $showingEditProject
            )
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(
                isPresented: $showingAddTask,
                project: project
            )
        }
        .navigationDestination(isPresented: $showingBaiBai) {
            BaiBaiView(projectColor: project.color)
        }
    }
}

// 详情行组件
struct DetailRow: View {
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(content)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: .constant(Project(name: "测试项目")))
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

