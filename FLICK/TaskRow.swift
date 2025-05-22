import SwiftUI

struct TaskRow: View {
    let task: ProjectTask
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingEditTask = false
    // 添加本地状态以实现立即响应
    @State private var isCompleted: Bool
    
    init(task: ProjectTask, project: Project) {
        self.task = task
        self.project = project
        // 初始化本地状态
        _isCompleted = State(initialValue: task.isCompleted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 任务标题和提醒图标
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                    
                    if task.reminder != nil {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // 完成状态滑块按钮
                Toggle("", isOn: $isCompleted)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()
                    .frame(width: 45)
                    .onChange(of: isCompleted) { newValue in
                        // 简单直接的动画
                        withAnimation(.easeInOut(duration: 0.2)) {
                            var updatedTask = task
                            updatedTask.isCompleted = newValue
                            projectStore.updateTask(updatedTask, in: project)
                        }
                    }
            }
            
            // 任务详情
            HStack(spacing: 16) {
                // 负责人
                Label {
                    Text(task.assignee)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                } icon: {
                    Image(systemName: "person")
                        .foregroundColor(isCompleted ? .secondary : .primary)
                }
                
                // 截止日期
                Label {
                    Text(task.dueDate.formatted(date: .numeric, time: .omitted))
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted, color: .secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(isCompleted ? .secondary : .primary)
                }
                
                // 提醒时间
                if task.reminder != nil {
                    Label {
                        Text("\(task.reminderHour):00")
                            .foregroundColor(isCompleted ? .secondary : .blue)
                            .strikethrough(isCompleted, color: .secondary)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(isCompleted ? .secondary : .blue)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .opacity(isCompleted ? 0.8 : 1.0)
        .sheet(isPresented: $showingEditTask) {
            // TODO: 实现编辑任务视图
            Text("编辑任务")
        }
        // 添加监听，确保当父视图的任务状态变化时同步更新本地状态
        .onChange(of: task.isCompleted) { newValue in
            if isCompleted != newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = newValue
                }
            }
        }
    }
} 