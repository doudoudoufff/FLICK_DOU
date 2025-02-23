import SwiftUI

struct EditProjectView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var director: String
    @State private var producer: String
    @State private var startDate: Date
    @State private var status: Project.Status
    @State private var selectedColor: Color
    
    init(project: Binding<Project>, isPresented: Binding<Bool>) {
        self._project = project
        self._isPresented = isPresented
        
        _name = State(initialValue: project.wrappedValue.name)
        _director = State(initialValue: project.wrappedValue.director)
        _producer = State(initialValue: project.wrappedValue.producer)
        _startDate = State(initialValue: project.wrappedValue.startDate)
        _status = State(initialValue: project.wrappedValue.status)
        _selectedColor = State(initialValue: project.wrappedValue.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("项目名称", text: $name)
                    TextField("导演", text: $director)
                    TextField("制片", text: $producer)
                }
                
                Section(header: Text("项目状态")) {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Picker("状态", selection: $status) {
                        ForEach(Project.Status.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section(header: Text("项目颜色")) {
                    ColorPicker("选择颜色", selection: $selectedColor)
                }
            }
            .navigationTitle("编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updatedProject = Project(
                            id: project.id,  // 保持原有 ID
                            name: name,
                            director: director,
                            producer: producer,
                            startDate: startDate,
                            status: status,
                            color: selectedColor,
                            tasks: project.tasks,  // 保持原有任务
                            invoices: project.invoices,  // 保持原有发票
                            locations: project.locations,  // 保持原有位置
                            accounts: project.accounts,  // 保持原有账户
                            isLocationScoutingEnabled: project.isLocationScoutingEnabled
                        )
                        
                        // 更新项目
                        projectStore.updateProject(updatedProject)
                        
                        // 更新绑定
                        project = updatedProject
                        
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    EditProjectView(
        project: .constant(Project(
            name: "测试项目",
            director: "张导演",
            producer: "李制片"
        )),
        isPresented: .constant(true)
    )
} 