import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Environment(\.managedObjectContext) private var context
    @State private var showingEditProject = false
    @State private var showingAddTask = false
    @State private var showingLocationScoutingView = false
    @State private var showingBaiBai = false
    @State private var editingTask: ProjectTask? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProjectInfoCard(project: project)
                BaiBaiButton(project: project, showingBaiBai: $showingBaiBai)
                TaskListCard(
                    project: $project,
                    showingAddTask: $showingAddTask,
                    editingTask: $editingTask
                )
                InvoiceListView(project: $project)
                    .environmentObject(projectStore)
                AccountListView(project: $project, showManagement: true)
                    .environmentObject(projectStore)
                LocationScoutingCard(project: $project)
                    .environmentObject(projectStore)
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: $project, isPresented: $showingEditProject)
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationView {
                AddTaskView(
                    isPresented: $showingAddTask,
                    project: $project
                )
                .environmentObject(projectStore)
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(
                task: Binding(
                    get: { task },
                    set: { newTask in
                        projectStore.updateTask(newTask, in: project)
                        editingTask = nil
                    }
                ),
                project: project,
                isPresented: Binding(
                    get: { editingTask != nil },
                    set: { if !$0 { editingTask = nil } }
                )
            )
        }
        .navigationDestination(isPresented: $showingBaiBai) {
            BaiBaiView(projectColor: project.color)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(project.name)
                .font(.headline)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button("编辑") {
                showingEditProject = true
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Menu {
                NavigationLink {
                    BaiBaiView(projectColor: project.color)
                } label: {
                    Label("开机拜拜", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
            }
        }
    }
}

// 项目信息卡片
struct ProjectInfoCard: View {
    let project: Project
    
    var body: some View {
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
    }
}

// 开机拜拜按钮
struct BaiBaiButton: View {
    let project: Project
    @Binding var showingBaiBai: Bool
    
    var body: some View {
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
    }
}

// 任务列表卡片
struct TaskListCard: View {
    @Binding var project: Project
    @Binding var showingAddTask: Bool
    @Binding var editingTask: ProjectTask?
    @EnvironmentObject var projectStore: ProjectStore
    
    private var taskProgress: Double {
        let totalTasks = project.tasks.count
        guard totalTasks > 0 else { return 0.0 }
        return Double(project.tasks.filter { $0.isCompleted }.count) / Double(totalTasks)
    }
    
    var body: some View {
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
                    ForEach(project.tasks) { task in
                        TaskRow(task: task, project: project)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        projectStore.deleteTask(task, from: project)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(project.tasks.count) * 100) // 设置固定高度
                .background(Color.clear)
                .scrollContentBackground(.hidden)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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

// 堪景模块卡片
struct LocationScoutingCard: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("堪景")
                .font(.headline)
            
            Divider()
            
            VStack(spacing: 16) {
                Toggle("启用堪景模块", isOn: $project.isLocationScoutingEnabled)
                    .tint(project.color)
                    .onChange(of: project.isLocationScoutingEnabled) { _, newValue in
                        print("堪景状态已更改为: \(newValue)")
                        // 确保立即更新到 CoreData
                        projectStore.updateProject(project)
                    }
                
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
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: .constant(Project(name: "测试项目")))
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

