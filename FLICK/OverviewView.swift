import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    
    // 检查指定日期是否有任务
    private func hasTasksOnDate(_ date: Date) -> Bool {
        for project in projectStore.projects {
            if project.tasks.contains(where: { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }) {
                return true
            }
        }
        return false
    }
    
    // 获取选中日期的所有任务
    private var tasksForSelectedDate: [TaskWithProject] {
        var result: [TaskWithProject] = []
        for project in projectStore.projects {
            let tasks = project.tasks.filter { task in
                Calendar.current.isDate(task.dueDate, inSameDayAs: selectedDate)
            }
            for task in tasks {
                result.append(TaskWithProject(task: task, project: project))
            }
        }
        // 先按完成状态排序，未完成的在前，然后按时间排序
        return result.sorted { task1, task2 in
            if task1.task.isCompleted != task2.task.isCompleted {
                return !task1.task.isCompleted // 未完成的排在前面
            }
            return task1.task.dueDate < task2.task.dueDate
        }
    }
    
    // 修改任务状态切换方法
    private func toggleTaskCompletion(_ taskWithProject: TaskWithProject) {
        withAnimation {  // 添加动画包装
            if let projectIndex = projectStore.projects.firstIndex(where: { $0.id == taskWithProject.project.id }),
               let taskIndex = projectStore.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskWithProject.task.id }) {
                projectStore.projects[projectIndex].tasks[taskIndex].isCompleted.toggle()
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日历卡片
                VStack(spacing: 0) {
                    ChineseCalendarView(selectedDate: $selectedDate, hasTasksOnDate: hasTasksOnDate)
                        .padding(.horizontal)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                .padding(.horizontal)
                
                // 任务统计
                HStack(spacing: 16) {
                    StatisticCard(
                        title: "今日任务",
                        value: "\(tasksForSelectedDate.count)",
                        icon: "calendar",
                        color: .blue
                    )
                    
                    StatisticCard(
                        title: "待完成",
                        value: "\(tasksForSelectedDate.filter { !$0.task.isCompleted }.count)",
                        icon: "clock",
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // 任务列表
                if !tasksForSelectedDate.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("任务列表")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showingAddTask = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 修改任务列表的显示方式
                        LazyVStack(spacing: 16) {  // 使用 LazyVStack 替代 ForEach
                            ForEach(tasksForSelectedDate) { taskWithProject in
                                DailyTaskRow(taskWithProject: taskWithProject) {
                                    toggleTaskCompletion(taskWithProject)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("今天没有待办任务")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingAddTask = true }) {
                            Text("添加任务")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .animation(.easeInOut, value: tasksForSelectedDate.map { $0.task.isCompleted })
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("总览")
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(isPresented: $showingAddTask, selectedDate: selectedDate, projectStore: projectStore)
        }
    }
}

// 用于关联任务和所属项目的结构
struct TaskWithProject: Identifiable, Equatable {
    let id = UUID()
    let task: ProjectTask
    let project: Project
    
    static func == (lhs: TaskWithProject, rhs: TaskWithProject) -> Bool {
        lhs.task.id == rhs.task.id && lhs.project.id == rhs.project.id
    }
}

// 统计卡片组件
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// 任务行组件
struct DailyTaskRow: View {
    let taskWithProject: TaskWithProject
    let onToggleCompletion: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                // 任务标题
                Text(taskWithProject.task.title)
                    .font(.headline)
                    .foregroundColor(taskWithProject.task.isCompleted ? .secondary : .primary)
                
                // 项目信息和时间
                HStack {
                    Text(taskWithProject.project.name)
                    Text("•")
                    Text(taskWithProject.task.dueDate.formatted(date: .omitted, time: .shortened))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 负责人
            Text(taskWithProject.task.assignee)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            
            // 完成状态切换开关
            Toggle("", isOn: .init(
                get: { taskWithProject.task.isCompleted },
                set: { _ in onToggleCompletion() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: taskWithProject.project.color))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .opacity(taskWithProject.task.isCompleted ? 0.8 : 1.0)
    }
}

#Preview {
    NavigationStack {
        OverviewView()
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
    }
} 

