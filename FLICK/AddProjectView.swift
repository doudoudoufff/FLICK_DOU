import SwiftUI

struct AddProjectView: View {
    @Binding var isPresented: Bool
    @Binding var projects: [Project]
    
    @State private var projectName = ""
    @State private var director = ""
    @State private var producer = ""
    @State private var startDate = Date()
    @State private var projectColor: Color = .blue
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("项目名称", text: $projectName)
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
                    ColorPickerView(selectedColor: $projectColor)
                } header: {
                    Text("项目颜色")
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
                        let newProject = Project(
                            name: projectName,
                            director: director,
                            producer: producer,
                            startDate: startDate,
                            color: projectColor
                        )
                        projects.append(newProject)
                        isPresented = false
                    }
                    .disabled(projectName.isEmpty)
                }
            }
        }
        .onAppear {
            nameFieldFocused = true
        }
    }
    
    @FocusState private var nameFieldFocused: Bool
} 