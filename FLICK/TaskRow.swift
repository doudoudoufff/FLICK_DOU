import SwiftUI

struct TaskRow: View {
    @Binding var task: ProjectTask
    let project: Project
    @State private var showingEditTask = false
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 完成状态滑块按钮
                Toggle("", isOn: $task.isCompleted)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()
                    .frame(width: 45)
                
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
                    Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
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
            .padding(.leading, 45)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                showingEditTask = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingEditTask) {
            EditTaskView(task: $task, project: project)
        }
    }
} 