import SwiftUI

struct AddProjectView: View {
    @Binding var isPresented: Bool
    @Binding var projects: [Project]
    
    @State private var name = ""
    @State private var director = ""
    @State private var producer = ""
    @State private var startDate = Date()
    @State private var color = Color.blue
    
    private func addProject() {
        let project = Project(
            name: name,
            director: director,
            producer: producer,
            startDate: startDate,
            color: color,
            tasks: [],
            invoices: []  // 添加空的发票数组
        )
        projects.append(project)
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