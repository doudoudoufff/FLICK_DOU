import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var selectedProject: Project?
    @State private var showingBaiBai = false
    
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
        withAnimation {
            // 使用 ProjectStore 的方法来切换任务状态
            projectStore.toggleTaskCompletion(taskWithProject.task, in: taskWithProject.project)
        }
    }
    
    var body: some View {
        NavigationStack {
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
                    
                    // 拜拜卡片 - 确保与日历组件等宽
                    NavigationLink(destination: BaiBaiView(projectColor: .orange)) {
                        HStack(spacing: 12) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("开机拜拜")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let weather = weatherManager.weatherInfo {
                                    HStack(spacing: 6) {
                                        Text("今日: \(weather.condition)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text(String(format: "%.1f°C", weather.temperature))
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                } else {
                                    Text("祈求今日拍摄顺利")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let weather = weatherManager.weatherInfo {
                                Image(systemName: weather.symbolName.isEmpty ? "sun.max.fill" : weather.symbolName)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 28))
                                    .padding(.trailing, 4)
                            }
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(.subheadline, weight: .medium))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)  // 确保占满全宽
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)  // 与日历组件使用相同的水平内边距
                    
                    // 功能卡片网格
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // 可以在这里添加其他功能卡片...
                    }
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
                                
                                Button(action: {
                                    // 如果没有选中项目，默认选择第一个项目
                                    if selectedProject == nil && !projectStore.projects.isEmpty {
                                        selectedProject = projectStore.projects[0]
                                    }
                                    showingAddTask = true
                                }) {
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
                            
                            Button(action: {
                                // 如果没有选中项目，默认选择第一个项目
                                if selectedProject == nil && !projectStore.projects.isEmpty {
                                    selectedProject = projectStore.projects[0]
                                }
                                showingAddTask = true
                            }) {
                                Text("添加任务")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("总览")
            .onAppear {
                weatherManager.fetchWeatherData()
            }
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationView {
                AddTaskView(isPresented: $showingAddTask)
                            .environmentObject(projectStore)
            }
            .presentationDetents([.height(500)])
        }
        .sheet(isPresented: $showingBaiBai) {
            NavigationView {
                BaiBaiView(projectColor: .orange)
            }
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

