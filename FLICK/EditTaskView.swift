import SwiftUI

struct EditTaskView: View {
    @Binding var task: ProjectTask
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var assignee: String
    @State private var dueDate: Date
    @State private var reminder: ProjectTask.TaskReminder?
    @State private var reminderHour: Double
    
    init(task: Binding<ProjectTask>, project: Project) {
        self._task = task
        self.project = project
        _title = State(initialValue: task.wrappedValue.title)
        _assignee = State(initialValue: task.wrappedValue.assignee)
        _dueDate = State(initialValue: task.wrappedValue.dueDate)
        _reminder = State(initialValue: task.wrappedValue.reminder)
        _reminderHour = State(initialValue: Double(task.wrappedValue.reminderHour))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("任务信息") {
                    TextField("任务内容", text: $title)
                    TextField("负责人员", text: $assignee)
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                
                Section("提醒设置") {
                    Picker("提醒频率", selection: $reminder) {
                        Text("不提醒").tag(nil as ProjectTask.TaskReminder?)
                        ForEach(ProjectTask.TaskReminder.allCases, id: \.self) { reminder in
                            Text(reminder.rawValue).tag(reminder as ProjectTask.TaskReminder?)
                        }
                    }
                    
                    if reminder != nil {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("提醒时间")
                                Spacer()
                                Text("\(Int(reminderHour)):00")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $reminderHour, in: 0...23, step: 1)
                        }
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        updateTask()
                        dismiss()
                    }
                    .disabled(title.isEmpty || assignee.isEmpty)
                }
            }
        }
    }
    
    private func updateTask() {
        task.title = title
        task.assignee = assignee
        task.dueDate = dueDate
        task.reminder = reminder
        task.reminderHour = Int(reminderHour)
        
        if let projectStore = ProjectStore.shared {
            projectStore.updateTask(task, in: project)
        }
    }
} 