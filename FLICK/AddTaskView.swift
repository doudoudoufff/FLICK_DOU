import SwiftUI

struct AddTaskView: View {
    @Binding var isPresented: Bool
    let selectedDate: Date
    let projectStore: ProjectStore
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    @State private var selectedProject: Project?
    
    init(isPresented: Binding<Bool>, project: Project) {
        let today = Date()
        self._isPresented = isPresented
        self.selectedDate = today
        var store = ProjectStore()
        store.projects = [project]
        self.projectStore = store
        self._selectedProject = State(initialValue: project)
        self._dueDate = State(initialValue: today)
    }
    
    init(isPresented: Binding<Bool>, selectedDate: Date, projectStore: ProjectStore) {
        self._isPresented = isPresented
        self.selectedDate = selectedDate
        self.projectStore = projectStore
        self._dueDate = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 项目选择
                Picker("选择项目", selection: $selectedProject) {
                    ForEach(projectStore.projects) { project in
                        Text(project.name).tag(project as Project?)
                    }
                }
                
                Section {
                    TextField("任务内容", text: $title)
                        .focused($titleFieldFocused)
                } header: {
                    Text("必填信息")
                }
                
                Section {
                    TextField("负责人员", text: $assignee)
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                } header: {
                    Text("任务详情")
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
                    Button("添加") {
                        addTask()
                    }
                    .disabled(selectedProject == nil || title.isEmpty || assignee.isEmpty)
                }
            }
        }
        .onAppear {
            titleFieldFocused = true
        }
    }
    
    private func addTask() {
        guard let project = selectedProject,
              let projectIndex = projectStore.projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        let task = ProjectTask(
            title: title,
            assignee: assignee,
            dueDate: dueDate,
            isCompleted: false
        )
        
        var updatedProject = project
        updatedProject.tasks.append(task)
        projectStore.projects[projectIndex] = updatedProject
        
        isPresented = false
    }
    
    @FocusState private var titleFieldFocused: Bool
} 