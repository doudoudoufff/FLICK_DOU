import SwiftUI

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    @State private var reminder: ProjectTask.TaskReminder?
    @State private var reminderHour: Double = 9
    
    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    TextField("任务内容", text: $title)
                        .focused($titleFieldFocused)
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
                    reminderSection
                } header: {
                    Text("提醒设置")
                }
            }
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let task = ProjectTask(
                            title: title,
                            assignee: assignee,
                            dueDate: dueDate,
                            reminder: reminder,
                            reminderHour: Int(reminderHour)
                        )
                        projectStore.addTask(task, to: project)
                        isPresented = false
                    }
                    .disabled(title.isEmpty || assignee.isEmpty)
                }
            }
        }
        .onAppear {
            titleFieldFocused = true
        }
    }
    
    @ViewBuilder
    private var reminderSection: some View {
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
                Slider(
                    value: $reminderHour,
                    in: 0.0...23.0,
                    step: 1.0
                )
            }
        }
    }
    
    @FocusState private var titleFieldFocused: Bool
}

#Preview {
    AddTaskView(
        isPresented: .constant(true),
        project: .constant(Project(name: "测试项目"))
    )
    .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 