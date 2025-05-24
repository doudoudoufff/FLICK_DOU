import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectStore: ProjectStore
    @Binding var isPresented: Bool
    
    // 添加预设日期参数
    var presetStartDate: Date?
    var presetEndDate: Date?
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var startDate = Date()
    @State private var dueDate = Date()
    @State private var isMultiDayTask = false
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
                    
                    // 跨天任务开关
                    Toggle("跨天任务", isOn: $isMultiDayTask)
                        .onChange(of: isMultiDayTask) { newValue in
                            if !newValue {
                                // 如果关闭跨天任务，将开始日期设置为截止日期
                                startDate = dueDate
                            }
                        }
                    
                    if isMultiDayTask {
                        // 如果是跨天任务，显示开始日期和截止日期选择器
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .onChange(of: startDate) { newValue in
                                // 确保截止日期不早于开始日期
                                if dueDate < newValue {
                                    dueDate = newValue
                                }
                            }
                        
                        DatePicker("截止日期", selection: $dueDate, in: startDate..., displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    } else {
                        // 如果不是跨天任务，只显示截止日期选择器
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                            .onChange(of: dueDate) { newValue in
                                // 保持开始日期与截止日期同步
                                startDate = newValue
                            }
                    }
                }
                
                Section(header: Text("提醒设置")) {
                    Picker("提醒类型", selection: $reminder) {
                        Text("不提醒").tag(nil as ProjectTask.TaskReminder?)
                        ForEach(ProjectTask.TaskReminder.allCases) { reminderType in
                            Text(reminderType.rawValue).tag(reminderType as ProjectTask.TaskReminder?)
                        }
                    }
                    
                    if reminder != nil {
                    HStack {
                                Text("提醒时间")
                        Spacer()
                                Text("\(Int(reminderHour)):00")
                                    .foregroundColor(.secondary)
                    }
                        
                        Slider(value: $reminderHour, in: 0...23, step: 1)
                        }
                    }
                
                Section(header: HStack {
                    Text("所属项目")
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }) {
                    if projectStore.projects.isEmpty {
                        Button("创建项目") {
                            showingCreateProjectSheet = true
                        }
                    } else {
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
        .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                            dismiss()
                        }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        addTask()
                }
                    .disabled(title.isEmpty || selectedProject == nil)
            }
        }
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreateProjectSheet) {
                AddProjectView(isPresented: $showingCreateProjectSheet)
                    .environmentObject(projectStore)
            }
            .alert("需要选择项目", isPresented: $showingProjectRequiredAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请先选择一个项目或创建新项目")
            }
            .alert("任务已添加", isPresented: $showingTaskAddedAlert) {
                Button("确定", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("任务已添加到项目\"\(addedTaskProjectName)\"")
            }
        }
        .onAppear {
            // 如果有预设日期，使用预设日期
            if let presetStart = presetStartDate {
                startDate = presetStart
                if let presetEnd = presetEndDate {
                    dueDate = presetEnd
                    // 如果开始日期和结束日期不同，设置为跨天任务
                    isMultiDayTask = !Calendar.current.isDate(presetStart, inSameDayAs: presetEnd)
                } else {
                    dueDate = presetStart
                    isMultiDayTask = false
                }
            }
        }
    }
    
    private func addTask() {
        guard let project = selectedProject else {
            showingProjectRequiredAlert = true
            return
        }
        
        let task = ProjectTask(
            title: title,
            assignee: assignee.isEmpty ? "未分配" : assignee,
            startDate: startDate,
            dueDate: dueDate,
            isCompleted: false,
            reminder: reminder,
            reminderHour: Int(reminderHour)
        )
        
        projectStore.addTask(task, to: project)
        addedTaskProjectName = project.name
        showingTaskAddedAlert = true
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

// 项目选择按钮组件
struct ProjectSelectionButton: View {
    let project: Project
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // 项目图标
                Circle()
                    .fill(project.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? project.color : Color.clear, lineWidth: 2)
                            .padding(-4)
                    )
                
                // 项目名称
                Text(project.name)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? project.color : .primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 70)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? project.color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        AddTaskView(
            isPresented: .constant(true),
            presetStartDate: nil,
            presetEndDate: nil
        )
    }
    .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 
