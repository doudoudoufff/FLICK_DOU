import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @State private var tasks: [ProjectTask] = [
        ProjectTask(
            title: "完成剧本终稿",
            assignee: "张三",
            dueDate: Date().addingTimeInterval(86400 * 7)
        ),
        ProjectTask(
            title: "确定主要演员阵容",
            assignee: "李四",
            dueDate: Date().addingTimeInterval(86400 * 14)
        ),
        ProjectTask(
            title: "场地勘察",
            assignee: "王五",
            dueDate: Date().addingTimeInterval(86400 * 3)
        ),
        ProjectTask(
            title: "道具采购清单确认",
            assignee: "赵六",
            dueDate: Date().addingTimeInterval(86400 * 5)
        )
    ]
    @State private var showingEditProject = false
    @State private var showingAddTask = false
    
    // 添加进度计算属性
    private var taskProgress: Double {
        guard !tasks.isEmpty else { return 0.0 }
        let completedTasks = tasks.filter { $0.isCompleted }.count
        return Double(completedTasks) / Double(tasks.count)
    }
    
    // 添加排序后的任务计算属性
    private var sortedTasks: Binding<[ProjectTask]> {
        Binding(
            get: {
                tasks.sorted { task1, task2 in
                    if task1.isCompleted == task2.isCompleted {
                        return task1.dueDate < task2.dueDate  // 相同完成状态按截止日期排序
                    }
                    return !task1.isCompleted  // 未完成的任务排在前面
                }
            },
            set: { newValue in
                tasks = newValue
            }
        )
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
                        DetailRow(title: "开始时间", content: project.startDate.formatted(date: .long, time: .omitted))
                        DetailRow(title: "导演", content: project.director)
                        DetailRow(title: "制片", content: project.producer)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
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
                            
                            Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)个任务")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: taskProgress)
                            .tint(project.color) // 使用项目颜色
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    if tasks.isEmpty {
                        Text("暂无任务")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        List {
                            ForEach(sortedTasks) { $task in
                                TaskRow(task: $task) {
                                    withAnimation {
                                        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                                            tasks.remove(at: index)
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.opacity)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(tasks.count) * 110)
                        .animation(.easeInOut, value: tasks.map { $0.isCompleted })
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .padding()
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
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(isPresented: $showingEditProject, project: $project)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(isPresented: $showingAddTask, tasks: $tasks)
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