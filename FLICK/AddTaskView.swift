import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectStore: ProjectStore
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    @State private var reminder: ProjectTask.TaskReminder? = nil
    @State private var reminderHour: Double = 9
    @State private var selectedProject: Project?
    @State private var showingCreateProjectSheet = false
    @State private var showingTaskAddedAlert = false
    @State private var addedTaskProjectName = ""
    @State private var showingProjectRequiredAlert = false
    
    var body: some View {
        NavigationStack {
        Form {
                Section(header: Text("任务信息")) {
                    HStack {
                        Text("任务内容")
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                        TextField("", text: $title)
                    }
                    TextField("负责人员", text: $assignee)
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                Section(header: Text("提醒设置")) {
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
                }
                Section(header: HStack {
                    Text("所属项目")
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("选择项目")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { showingCreateProjectSheet = true }) {
                                Text("＋ 新建项目")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(projectStore.projects) { project in
                                    Button(action: {
                                        selectedProject = project
                                    }) {
                                        Text(project.name)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedProject?.id == project.id ? project.color : Color(.systemGray5))
                                            .foregroundColor(selectedProject?.id == project.id ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("添加任务")
        .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(400)])
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                        guard let project = selectedProject, !title.isEmpty else { return }
                    let task = ProjectTask(
                        title: title,
                            assignee: assignee,
                        dueDate: dueDate,
                        isCompleted: false,
                        reminder: reminder,
                            reminderHour: Int(reminderHour)
                    )
                    projectStore.addTask(task, to: project)
                        addedTaskProjectName = project.name
                        showingTaskAddedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            showingTaskAddedAlert = false
                            dismiss()
                        }
                }
                    .disabled(title.isEmpty || selectedProject == nil)
            }
        }
            .sheet(isPresented: $showingCreateProjectSheet) {
                AddProjectView(isPresented: $showingCreateProjectSheet)
                    .environmentObject(projectStore)
            }
            .onAppear {
                if selectedProject == nil {
                    selectedProject = projectStore.projects.first
                }
            }
                        .overlay(
                Group {
                    if showingTaskAddedAlert {
                        VStack {
                            Text("任务已添加至 \(addedTaskProjectName) 项目")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut, value: showingTaskAddedAlert)
                    }
                }
            )
            .alert("请选择项目", isPresented: $showingProjectRequiredAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请选择一个项目来保存任务。")
            }
            .alert("请选择项目", isPresented: $showingProjectRequiredAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请选择一个项目来添加此任务")
            }
                }
            }


struct EmptyProjectSection: View {
    @Binding var showingCreateProjectAlert: Bool
    var body: some View {
        Section {
            VStack(spacing: 16) {
                Text("您还没有项目")
                    .font(.headline)
                Text("请先创建一个项目，再添加任务")
                    .foregroundColor(.secondary)
                Button("创建项目") {
                    showingCreateProjectAlert = true
        }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }
}

struct TaskInfoSection: View {
    @Binding var taskTitle: String
    @Binding var taskDescription: String
    @Binding var dueDate: Date
    @Binding var assignee: String
    var body: some View {
        Section("任务信息") {
            TextField("任务标题", text: $taskTitle)
            TextField("任务描述", text: $taskDescription)
            DatePicker("截止日期", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            TextField("负责人", text: $assignee)
                    }
                }
            }

struct ProjectPickerSection: View {
    @Binding var selectedProject: Project?
    let projects: [Project]
    var body: some View {
        Section("所属项目") {
            Picker("选择项目", selection: $selectedProject) {
                ForEach(projects) { project in
                    Text(project.name)
                        .tag(Optional(project))
                }
            }
        }
    }
}

struct AddTaskButtonSection: View {
    @Binding var taskTitle: String
    @Binding var selectedProject: Project?
    @Binding var dueDate: Date
    @Binding var assignee: String
    var projectStore: ProjectStore
    @Binding var showingTaskAddedAlert: Bool
    var dismiss: DismissAction

    var body: some View {
        Section {
            Button(action: {
                guard let project = selectedProject else { return }
                let task = ProjectTask(
                    title: taskTitle,
                    assignee: assignee,
                    dueDate: dueDate
                )
                projectStore.addTask(task, to: project)
                showingTaskAddedAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }) {
                Text("添加任务")
            }
            .disabled(taskTitle.isEmpty || selectedProject == nil)
        }
    }
}

#Preview {
    NavigationView {
        AddTaskView(
            isPresented: .constant(true)
        )
    }
    .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 
