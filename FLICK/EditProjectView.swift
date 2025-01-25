import SwiftUI

struct EditProjectView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var name: String
    @State private var director: String
    @State private var producer: String
    @State private var startDate: Date
    @State private var color: Color
    
    init(isPresented: Binding<Bool>, project: Binding<Project>) {
        self._isPresented = isPresented
        self._project = project
        
        _name = State(initialValue: project.wrappedValue.name)
        _director = State(initialValue: project.wrappedValue.director)
        _producer = State(initialValue: project.wrappedValue.producer)
        _startDate = State(initialValue: project.wrappedValue.startDate)
        _color = State(initialValue: project.wrappedValue.color)
    }
    
    private func updateProject() {
        project.name = name
        project.director = director
        project.producer = producer
        project.startDate = startDate
        project.color = color
        // 保持原有的任务和发票数组不变
        isPresented = false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("项目名称", text: $name)
                }
                
                Section {
                    TextField("导演", text: $director)
                    TextField("制片", text: $producer)
                    DatePicker("开始时间", selection: $startDate, displayedComponents: .date)
                }
                
                Section {
                    ColorPickerView(selectedColor: $color)
                } header: {
                    Text("项目颜色")
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
                        updateProject()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
} 