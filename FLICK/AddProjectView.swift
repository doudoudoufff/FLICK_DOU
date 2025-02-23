import SwiftUI

struct AddProjectView: View {
    @Binding var isPresented: Bool
    @ObservedObject var projectStore: ProjectStore
    
    @State private var name = ""
    @State private var director = ""
    @State private var producer = ""
    @State private var startDate = Date()
    @State private var status: ProjectStatus = .preProduction
    @State private var selectedColor: Color = .blue
    @State private var showingColorPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("项目名称", text: $name)
                    TextField("导演", text: $director)
                    TextField("制片", text: $producer)
                }
                
                Section("项目状态") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Picker("项目状态", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section("外观") {
                    ColorPicker("项目颜色", selection: $selectedColor)
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
    NavigationStack {
        AddProjectView(
            isPresented: .constant(true),
            projectStore: ProjectStore(context: PersistenceController.preview.container.viewContext)
        )
    }
} 