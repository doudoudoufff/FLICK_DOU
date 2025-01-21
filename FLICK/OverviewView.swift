import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var selectedDate = Date()
    
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
        return result.sorted { $0.task.dueDate < $1.task.dueDate }
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
                        Text("任务列表")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(tasksForSelectedDate) { taskWithProject in
                            DailyTaskRow(taskWithProject: taskWithProject)
                                .padding(.horizontal)
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("总览")
    }
}

// 用于关联任务和所属项目的结构
struct TaskWithProject: Identifiable {
    let id = UUID()
    let task: ProjectTask
    let project: Project
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
    
    var body: some View {
        HStack(spacing: 16) {
            // 项目标记
            Circle()
                .fill(taskWithProject.project.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // 任务标题
                Text(taskWithProject.task.title)
                    .font(.headline)
                
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
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        OverviewView()
            .environmentObject(ProjectStore())
    }
} 

