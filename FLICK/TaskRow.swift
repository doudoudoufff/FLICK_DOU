import SwiftUI

struct TaskRow: View {
    let task: ProjectTask
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingEditTask = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 任务标题和提醒图标
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    if task.reminder != nil {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // 完成状态滑块按钮
                Toggle("", isOn: Binding(
                    get: { task.isCompleted },
                    set: { newValue in
                        var updatedTask = task
                        updatedTask.isCompleted = newValue
                        projectStore.updateTask(updatedTask, in: project)
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
                .frame(width: 45)
            }
            
            // 任务详情
            HStack(spacing: 16) {
                // 负责人
                Label {
                    Text(task.assignee)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                } icon: {
                    Image(systemName: "person")
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                }
                
                // 截止日期
                Label {
                    Text(task.dueDate.formatted(date: .numeric, time: .omitted))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                }
                
                // 提醒时间
                if task.reminder != nil {
                    Label {
                        Text("\(task.reminderHour):00")
                            .foregroundColor(task.isCompleted ? .secondary : .blue)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(task.isCompleted ? .secondary : .blue)
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
        .sheet(isPresented: $showingEditTask) {
            // TODO: 实现编辑任务视图
            Text("编辑任务")
        }
    }
} 