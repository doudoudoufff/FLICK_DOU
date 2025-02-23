import SwiftUI

struct AddProjectView: View {
    @Binding var isPresented: Bool
    @ObservedObject var projectStore: ProjectStore
    
    @State private var name = ""
    @State private var director = ""
    @State private var producer = ""
    @State private var startDate = Date()
    @State private var color = Color.blue
    @State private var status = Project.ProjectStatus.preProduction
    
    private func addProject() {
        let project = Project(
            name: name,
            director: director,
            producer: producer,
            startDate: startDate,
            status: status,
            color: color,
            tasks: [],
            invoices: []
        )
        projectStore.addProject(project)
        isPresented = false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("项目名称", text: $name)
                        .focused($nameFieldFocused)
                } header: {
                    Text("必填信息")
                }
                
                Section {
                    TextField("导演", text: $director)
                    TextField("制片", text: $producer)
                    DatePicker("开始时间", selection: $startDate, displayedComponents: .date)
                } header: {
                    Text("选填信息")
                }
                
                Section {
                    ColorPickerView(selectedColor: $color)
                } header: {
                    Text("项目颜色")
                }
                
                Section {
                    Picker("项目状态", selection: $status) {
                        Text("筹备").tag(Project.ProjectStatus.preProduction)
                        Text("拍摄").tag(Project.ProjectStatus.production)
                        Text("后期").tag(Project.ProjectStatus.postProduction)
                    }
                } header: {
                    Text("项目状态")
                }
            }
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        addProject()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            nameFieldFocused = true
        }
    }
    
    @FocusState private var nameFieldFocused: Bool
}

#Preview {
    NavigationStack {
        AddProjectView(
            isPresented: .constant(true),
            projectStore: ProjectStore(context: PersistenceController.preview.container.viewContext)
        )
    }
} 