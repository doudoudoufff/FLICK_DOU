import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Binding var task: ProjectTask
    
    @State private var title: String
    @State private var assignee: String
    @State private var startDate: Date
    @State private var dueDate: Date
    @State private var isMultiDayTask: Bool
    @State private var reminder: ProjectTask.TaskReminder?
    @State private var reminderHour: Double
    @State private var selectedProject: Project?
    @State private var showingCreateProjectSheet = false
    @State private var showingTaskUpdatedAlert = false
    @State private var updatedTaskProjectName = ""
    @State private var showingProjectRequiredAlert = false
    
    init(isPresented: Binding<Bool>, task: Binding<ProjectTask>) {
        self._isPresented = isPresented
        self._task = task
        self._title = State(initialValue: task.wrappedValue.title)
        self._assignee = State(initialValue: task.wrappedValue.assignee)
        self._startDate = State(initialValue: task.wrappedValue.startDate)
        self._dueDate = State(initialValue: task.wrappedValue.dueDate)
        self._isMultiDayTask = State(initialValue: !Calendar.current.isDate(task.wrappedValue.startDate, inSameDayAs: task.wrappedValue.dueDate))
        self._reminder = State(initialValue: task.wrappedValue.reminder)
        self._reminderHour = State(initialValue: Double(task.wrappedValue.reminderHour))
    }
    
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
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(500)])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if title.isEmpty {
                            return
                        }
                        
                        if selectedProject == nil {
                            showingProjectRequiredAlert = true
                            return
                        }
                        
                        guard let project = selectedProject else { return }
                        
                        // 创建一个更新后的任务对象
                        var updatedTask = task
                        updatedTask.title = title
                        updatedTask.assignee = assignee
                        updatedTask.startDate = startDate
                        updatedTask.dueDate = dueDate
                        updatedTask.reminder = reminder
                        updatedTask.reminderHour = Int(reminderHour)
                        
                        // 更新原始任务对象
                        task = updatedTask
                        
                        // 保存到ProjectStore
                        projectStore.updateTask(updatedTask, in: project)
                        updatedTaskProjectName = project.name
                        showingTaskUpdatedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            showingTaskUpdatedAlert = false
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingCreateProjectSheet) {
                AddProjectView(isPresented: $showingCreateProjectSheet)
                    .environmentObject(projectStore)
            }
            .onAppear {
                if selectedProject == nil {
                    // 尝试找到任务所属的项目
                    for project in projectStore.projects {
                        if project.tasks.contains(where: { $0.id == task.id }) {
                            selectedProject = project
                            break
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if showingTaskUpdatedAlert {
                        VStack {
                            Text("任务已更新至 \(updatedTaskProjectName) 项目")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut, value: showingTaskUpdatedAlert)
                    }
                }
            )
            .alert("请选择项目", isPresented: $showingProjectRequiredAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请选择一个项目来保存任务。")
            }
        }
    }
} 