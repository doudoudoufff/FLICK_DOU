import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var selectedProject: Project?
    @State private var showingBaiBai = false
    @State private var taskFilter: TaskFilter = .all // 添加任务筛选状态
    
    // 任务筛选枚举
    enum TaskFilter {
        case all         // 全部（今日任务）
        case pending     // 待完成
        case completed   // 已完成
    }
    
    // 检查指定日期是否有任务
    private func hasTasksOnDate(_ date: Date) -> Bool {
        for project in projectStore.projects {
            if project.tasks.contains(where: { task in
                let calendar = Calendar.current
                let taskStartDay = calendar.startOfDay(for: task.startDate)
                let taskEndDay = calendar.startOfDay(for: task.dueDate)
                let checkDay = calendar.startOfDay(for: date)
                
                // 检查日期是否在任务开始日期和截止日期之间（含边界）
                return (checkDay >= taskStartDay && checkDay <= taskEndDay)
            }) {
                return true
            }
        }
        return false
    }
    
    // 获取所有任务用于日历显示
    private func getAllTasksForCalendar() -> [ProjectTask] {
        return projectStore.projects.flatMap { $0.tasks }
    }
    
    // 获取选中日期的所有任务，并根据筛选条件过滤
    private var tasksForSelectedDate: [TaskWithProject] {
        var result: [TaskWithProject] = []
        for project in projectStore.projects {
            let tasks = project.tasks.filter { task in
                let calendar = Calendar.current
                let taskStartDay = calendar.startOfDay(for: task.startDate)
                let taskEndDay = calendar.startOfDay(for: task.dueDate)
                let checkDay = calendar.startOfDay(for: selectedDate)
                
                // 检查选中日期是否在任务开始日期和截止日期之间（含边界）
                return (checkDay >= taskStartDay && checkDay <= taskEndDay)
            }
            for task in tasks {
                result.append(TaskWithProject(task: task, project: project))
            }
        }
        
        // 应用筛选条件
        switch taskFilter {
        case .all:
            // 全部显示（不额外筛选）
            break
        case .pending:
            // 只显示未完成的任务
            result = result.filter { !$0.task.isCompleted }
        case .completed:
            // 只显示已完成的任务
            result = result.filter { $0.task.isCompleted }
        }
        
        // 先按完成状态排序，未完成的在前，然后按时间排序
        return result.sorted { task1, task2 in
            if task1.task.isCompleted != task2.task.isCompleted {
                return !task1.task.isCompleted // 未完成的排在前面
            }
            return task1.task.dueDate < task2.task.dueDate
        }
    }
    
    // 计算每种类型的任务数量
    private var allTasksCount: Int {
        return tasksForSelectedDate.count
    }
    
    private var pendingTasksCount: Int {
        return tasksForSelectedDate.filter { !$0.task.isCompleted }.count
    }
    
    private var completedTasksCount: Int {
        return tasksForSelectedDate.filter { $0.task.isCompleted }.count
    }
    
    // 修改任务状态切换方法
    private func toggleTaskCompletion(_ taskWithProject: TaskWithProject) {
        withAnimation(.easeInOut(duration: 0.2)) {
            // 执行状态切换
            projectStore.toggleTaskCompletion(taskWithProject.task, in: taskWithProject.project)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题
                Text("总览")
                    .font(.title3)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .background(Color(.systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 日历卡片 - 获得更多空间
                        VStack(spacing: 0) {
                            ChineseCalendarView(
                                selectedDate: $selectedDate, 
                                hasTasksOnDate: hasTasksOnDate,
                                getTasksForCalendar: getAllTasksForCalendar
                            )
                            .padding(.horizontal, 0) // 去掉内边距，让日历更宽
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                        .padding(.horizontal, 16) // 增加水平边距，让卡片看起来更独立
                        
                        // 拜拜卡片已隐藏 
                        // NavigationLink(destination: BaiBaiView(projectColor: .orange)) { ... }
                        
                        
                        // 功能卡片网格
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            // 可以在这里添加其他功能卡片...
                        }
                        .padding(.horizontal)
                        
                        // 任务统计 - 改为可点击筛选的卡片
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            FilterStatisticCard(
                                title: "今日任务",
                                value: "\(allTasksCount)",
                                icon: "calendar",
                                color: .blue,
                                isSelected: taskFilter == .all,
                                action: { taskFilter = .all }
                            )
                            
                            FilterStatisticCard(
                                title: "待完成",
                                value: "\(pendingTasksCount)",
                                icon: "clock",
                                color: .orange,
                                isSelected: taskFilter == .pending,
                                action: { taskFilter = .pending }
                            )
                            
                            FilterStatisticCard(
                                title: "已完成",
                                value: "\(completedTasksCount)",
                                icon: "checkmark.circle",
                                color: .green,
                                isSelected: taskFilter == .completed,
                                action: { taskFilter = .completed }
                            )
                        }
                        .padding(.horizontal)
                        
                        // 任务列表 - 未完成和已完成分开显示
                        if !pendingTasks.isEmpty || !completedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    // 动态显示标题，根据筛选条件变化
                                    Text(taskFilter == .all ? "今日任务" : 
                                        (taskFilter == .pending ? "待完成任务" : "已完成任务"))
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
                                
                                // 根据筛选条件显示相应任务
                                if taskFilter == .all || taskFilter == .pending {
                                    // 未完成任务
                                    if !pendingTasks.isEmpty {
                                        VStack(spacing: 12) {
                                            ForEach(pendingTasks) { taskWithProject in
                                                DailyTaskRow(taskWithProject: taskWithProject) {
                                                    toggleTaskCompletion(taskWithProject)
                                                }
                                                .transition(.opacity)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .animation(.easeInOut(duration: 0.2), value: pendingTasks.map { $0.id })
                                    }
                                }
                                
                                // 显示已完成任务（如果需要）
                                if (taskFilter == .all || taskFilter == .completed) && !completedTasks.isEmpty {
                                    VStack(alignment: .leading) {
                                        if taskFilter == .all && !pendingTasks.isEmpty {
                                            // 仅当显示全部且有未完成任务时才显示此分隔线
                                            Divider()
                                                .padding(.vertical, 8)
                                            
                                            Text("已完成")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.bottom, 8)
                                        }
                                        
                                        VStack(spacing: 12) {
                                            ForEach(completedTasks) { taskWithProject in
                                                DailyTaskRow(taskWithProject: taskWithProject) {
                                                    toggleTaskCompletion(taskWithProject)
                                                }
                                                .transition(.opacity)
                                            }
                                        }
                                        .animation(.easeInOut(duration: 0.2), value: completedTasks.map { $0.id })
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text(emptyStateMessage)
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
            }
            .background(Color(.systemGroupedBackground))
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
    
    // 根据筛选状态显示不同的空状态消息
    private var emptyStateMessage: String {
        switch taskFilter {
        case .all:
            return "今日没有任务"
        case .pending:
            return "今日没有待完成任务"
        case .completed:
            return "今日没有已完成任务"
        }
    }
    
    // 将任务分为已完成和未完成两个数组
    private var pendingTasks: [TaskWithProject] {
        tasksForSelectedDate.filter { !$0.task.isCompleted }
    }
    
    private var completedTasks: [TaskWithProject] {
        tasksForSelectedDate.filter { $0.task.isCompleted }
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

// 添加可筛选的统计卡片组件
struct FilterStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? .white : color)
                    Text(title)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .lineLimit(2)
                }
                .font(.subheadline)
                
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 85) // 降低高度
            .padding(12) // 减小内边距
            .background(isSelected ? color : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 0, maxWidth: .infinity) // 确保按钮填充可用空间
    }
}

// 任务行组件
struct DailyTaskRow: View {
    let taskWithProject: TaskWithProject
    let onToggleCompletion: () -> Void
    @State private var isCompleted: Bool
    
    init(taskWithProject: TaskWithProject, onToggleCompletion: @escaping () -> Void) {
        self.taskWithProject = taskWithProject
        self.onToggleCompletion = onToggleCompletion
        _isCompleted = State(initialValue: taskWithProject.task.isCompleted)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                // 任务标题
                Text(taskWithProject.task.title)
                    .font(.headline)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary) // 添加删除线
                
                // 项目信息和时间
                HStack {
                    Text(taskWithProject.project.name)
                    Text("•")
                    
                    // 显示日期范围（如果跨天）
                    if taskWithProject.task.isCrossDays {
                        Text("\(taskWithProject.task.startDate.chineseStyleShortString())-\(taskWithProject.task.dueDate.chineseStyleShortString())")
                    } else {
                        Text(taskWithProject.task.dueDate.formatted(date: .omitted, time: .shortened))
                    }
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
            Toggle("", isOn: $isCompleted)
                .toggleStyle(SwitchToggleStyle(tint: taskWithProject.project.color))
                .onChange(of: isCompleted) { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        onToggleCompletion()
                    }
                }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .opacity(isCompleted ? 0.8 : 1.0)
        // 添加监听，确保当父视图的任务状态变化时同步更新本地状态
        .onChange(of: taskWithProject.task.isCompleted) { newValue in
            if isCompleted != newValue {
                isCompleted = newValue
            }
        }
    }
}

// 扩展Calendar以获取一天的结束时间
extension Calendar {
    func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfDay(for: date))!
    }
}

#Preview {
    NavigationStack {
        OverviewView()
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
    }
} 

