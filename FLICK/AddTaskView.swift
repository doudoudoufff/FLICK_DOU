import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    @State private var reminder: ProjectTask.TaskReminder? = nil
    @State private var reminderHour: Int = 9
    @State private var showDatePicker = false
    @State private var showProjectPicker = false
    @State private var showReminderPicker = false
    @State private var showHourPicker = false
    
    // 提醒小时数选项
    private let hourOptions = Array(6...22)
    
    var body: some View {
        Form {
            Section("必填信息") {
                TextField("任务内容", text: $title)
            }
            
            Section("任务详情") {
                // 项目选择
                Button(action: { showProjectPicker = true }) {
                    HStack {
                        Text("所属项目")
                        Spacer()
                        Text(project.name)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                }
                
                TextField("负责人员", text: $assignee)
                
                Button(action: { showDatePicker = true }) {
                    HStack {
                        Text("截止时间")
                        Spacer()
                        Text(dueDate.formatted(date: .numeric, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("提醒设置") {
                // 提醒频率选择
                Button(action: { showReminderPicker = true }) {
                    HStack {
                        Text("提醒频率")
                        Spacer()
                        Text(reminder?.rawValue ?? "不提醒")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                }
                
                // 只有设置了提醒才显示提醒时间选项
                if reminder != nil {
                    Button(action: { showHourPicker = true }) {
                        HStack {
                            Text("提醒时间")
                            Spacer()
                            Text("\(reminderHour):00")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .imageScale(.small)
                        }
                    }
                }
            }
        }
        .navigationTitle("添加任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    let task = ProjectTask(
                        title: title,
                        assignee: assignee.isEmpty ? "" : assignee,
                        dueDate: dueDate,
                        isCompleted: false,
                        reminder: reminder,
                        reminderHour: reminderHour
                    )
                    projectStore.addTask(task, to: project)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            }
        }
        .sheet(isPresented: $showProjectPicker) {
            NavigationView {
                List(projectStore.projects) { proj in
                    Button(action: {
                        project = proj
                        showProjectPicker = false
                    }) {
                        HStack {
                            Text(proj.name)
                            Spacer()
                            if proj.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .navigationTitle("选择项目")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showProjectPicker = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker("选择日期", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .navigationTitle("截止日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") { showDatePicker = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReminderPicker) {
            NavigationView {
                List {
                    Button(action: {
                        reminder = nil
                        showReminderPicker = false
                    }) {
                        HStack {
                            Text("不提醒")
                            Spacer()
                            if reminder == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    ForEach(ProjectTask.TaskReminder.allCases) { option in
                        Button(action: {
                            reminder = option
                            showReminderPicker = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                Spacer()
                                if reminder == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("提醒频率")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showReminderPicker = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showHourPicker) {
            NavigationView {
                List {
                    ForEach(hourOptions, id: \.self) { hour in
                        Button(action: {
                            reminderHour = hour
                            showHourPicker = false
                        }) {
                            HStack {
                                Text("\(hour):00")
                                Spacer()
                                if reminderHour == hour {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("提醒时间")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showHourPicker = false }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AddTaskView(
            isPresented: .constant(true),
            project: .constant(Project(name: "测试项目"))
        )
    }
    .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 