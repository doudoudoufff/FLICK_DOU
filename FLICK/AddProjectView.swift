import SwiftUI

struct AddProjectView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var director = ""
    @State private var producer = ""
    @State private var startDate = Date()
    @State private var status: Project.Status = .inProgress
    @State private var selectedColor: Color = .blue
    
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
                    ColorPickerView(selectedColor: $selectedColor)
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
                        let project = Project(
                            name: name,
                            director: director,
                            producer: producer,
                            startDate: startDate,
                            status: status,
                            color: selectedColor
                        )
                        projectStore.addProject(project)
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddProjectView(isPresented: .constant(true))
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 