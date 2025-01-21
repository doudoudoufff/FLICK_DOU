import SwiftUI

struct EditProjectView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var editedName: String
    @State private var editedDirector: String
    @State private var editedProducer: String
    @State private var editedStartDate: Date
    @State private var editedColor: Color
    
    init(isPresented: Binding<Bool>, project: Binding<Project>) {
        _isPresented = isPresented
        _project = project
        _editedName = State(initialValue: project.wrappedValue.name)
        _editedDirector = State(initialValue: project.wrappedValue.director)
        _editedProducer = State(initialValue: project.wrappedValue.producer)
        _editedStartDate = State(initialValue: project.wrappedValue.startDate)
        _editedColor = State(initialValue: project.wrappedValue.color)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("项目名称", text: $editedName)
                }
                
                Section {
                    TextField("导演", text: $editedDirector)
                    TextField("制片", text: $editedProducer)
                    DatePicker("开始时间", selection: $editedStartDate, displayedComponents: .date)
                }
                
                Section {
                    ColorPickerView(selectedColor: $editedColor)
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
                        project.name = editedName
                        project.director = editedDirector
                        project.producer = editedProducer
                        project.startDate = editedStartDate
                        project.color = editedColor
                        isPresented = false
                    }
                    .disabled(editedName.isEmpty)
                }
            }
        }
    }
} 