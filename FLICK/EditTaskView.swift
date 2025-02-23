import SwiftUI

struct EditTaskView: View {
    @Binding var task: ProjectTask
    let project: Project
    @Binding var isPresented: Bool
    @EnvironmentObject var projectStore: ProjectStore
    
    @State private var title: String
    @State private var assignee: String
    @State private var dueDate: Date
    @State private var reminder: ProjectTask.TaskReminder?
    @State private var reminderHour: Double
    
    init(task: Binding<ProjectTask>, project: Project, isPresented: Binding<Bool>) {
        self._task = task
        self.project = project
        self._isPresented = isPresented
        
        // 初始化状态变量
        _title = State(initialValue: task.wrappedValue.title)
        _assignee = State(initialValue: task.wrappedValue.assignee)
        _dueDate = State(initialValue: task.wrappedValue.dueDate)
        _reminder = State(initialValue: task.wrappedValue.reminder)
        _reminderHour = State(initialValue: Double(task.wrappedValue.reminderHour))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    TextField("任务内容", text: $title)
                }, header: {
                    Text("必填信息")
                })
                
                Section(content: {
                    TextField("负责人员", text: $assignee)
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }, header: {
                    Text("任务详情")
                })
                
                Section {
                    Picker("提醒频率", selection: $reminder) {
                        Text("不提醒").tag(ProjectTask.TaskReminder?.none)
                        ForEach(ProjectTask.TaskReminder.allCases, id: \.self) { reminder in
                            Text(reminder.rawValue).tag(ProjectTask.TaskReminder?.some(reminder))
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
                            Slider(value: $reminderHour, in: 0.0...23.0, step: 1.0)
                        }
                    }
                } header: {
                    Text("提醒设置")
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 创建更新后的任务对象
                        var updatedTask = task
                        updatedTask.title = title
                        updatedTask.assignee = assignee
                        updatedTask.dueDate = dueDate
                        updatedTask.reminder = reminder
                        updatedTask.reminderHour = Int(reminderHour)
                        
                        // 使用 ProjectStore 更新任务
                        projectStore.updateTask(updatedTask, in: project)
                        
                        // 更新绑定的任务
                        task = updatedTask
                        
                        isPresented = false
                    }
                    .disabled(title.isEmpty || assignee.isEmpty)
                }
            }
        }
    }
} 