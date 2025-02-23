import SwiftUI

struct EditProjectView: View {
    @Binding var project: Project
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var director: String
    @State private var producer: String
    @State private var startDate: Date
    @State private var status: ProjectStatus
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
                        project.name = name
                        project.director = director
                        project.producer = producer
                        project.startDate = startDate
                        project.status = status
                        project.color = selectedColor
                        
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