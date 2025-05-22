import SwiftUI

struct TaskManagementView: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTask = false
    @State private var editingTask: ProjectTask? = nil
    @State private var searchText = ""
    @State private var refreshID = UUID()
    @State private var sortOrder: SortOrder = .date
    @State private var filterCompleted: Bool? = nil  // nil表示显示全部
    
    enum SortOrder {
        case date
        case title
        case completed
    }
    
    var filteredTasks: [ProjectTask] {
        var tasks = project.tasks
        
        // 根据完成状态筛选
        if let filterCompleted = filterCompleted {
            tasks = tasks.filter { $0.isCompleted == filterCompleted }
        }
        
        // 根据搜索文本筛选
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.assignee.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 排序逻辑：
        // 1. 首先按完成状态分组：未完成任务在前，已完成任务在后
        // 2. 然后在各自组内按照截止日期排序
        tasks.sort { task1, task2 in
            // 首先按完成状态排序：未完成的排在前面
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            
            // 然后在各自分组内（已完成或未完成）按照截止日期排序
            return task1.dueDate < task2.dueDate
        }
        
        return tasks
    }
    
    var body: some View {
        List {
            // 添加筛选和排序控件
            Section {
                // 筛选选项
                Picker("显示", selection: $filterCompleted) {
                    Text("全部").tag(nil as Bool?)
                    Text("未完成").tag(false as Bool?)
                    Text("已完成").tag(true as Bool?)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            
            // 显示任务列表
            Section {
                if filteredTasks.isEmpty {
                    Text("没有匹配的任务")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                        .listRowBackground(Color(.systemBackground))
                } else {
                    ForEach(filteredTasks) { task in
                        TaskRow(task: task, project: project)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        projectStore.deleteTask(task, from: project)
                                        refreshID = UUID()
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
                            // 移除点击任务即编辑的功能
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: task.isCompleted)
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: filteredTasks)
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
        .id(refreshID)
        .onChange(of: project.tasks) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                refreshID = UUID()
            }
        }
        .searchable(text: $searchText, prompt: "搜索任务")
        .navigationTitle("任务管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationView {
                AddTaskView(isPresented: $showingAddTask)
                    .environmentObject(projectStore)
            }
            .presentationDetents([.height(500)])
            .onDisappear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    refreshID = UUID()
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(
                isPresented: Binding(
                    get: { editingTask != nil },
                    set: { if !$0 { editingTask = nil } }
                ),
                task: Binding(
                    get: { task },
                    set: { newTask in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            projectStore.updateTask(newTask, in: project)
                            editingTask = nil
                            refreshID = UUID()
                        }
                    }
                )
            )
            .onDisappear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    refreshID = UUID()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskManagementView(project: .constant(Project(
            name: "",
            tasks: []
        )))
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
    }
} 