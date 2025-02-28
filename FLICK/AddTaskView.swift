import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var title = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    @State private var showDatePicker = false
    @State private var showProjectPicker = false
    
    var body: some View {
        Form {
            Section("必填信息") {
                TextField("任务内容", text: $title)
            }
            
            Section("任务详情") {
                // 项目选择
                Button(action: { showProjectPicker = true }) {
                    HStack {
                        Text("所属项目")
                        Spacer()
                        Text(project.name)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                }
                
                TextField("负责人员", text: $assignee)
                
                Button(action: { showDatePicker = true }) {
                    HStack {
                        Text("截止时间")
                        Spacer()
                        Text(dueDate.formatted(date: .numeric, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("添加任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    let task = ProjectTask(
                        title: title,
                        assignee: assignee.isEmpty ? "" : assignee,
                        dueDate: dueDate
                    )
                    projectStore.addTask(task, to: project)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            }
        }
        .sheet(isPresented: $showProjectPicker) {
            NavigationView {
                List(projectStore.projects) { proj in
                    Button(action: {
                        project = proj
                        showProjectPicker = false
                    }) {
                        HStack {
                            Text(proj.name)
                            Spacer()
                            if proj.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .navigationTitle("选择项目")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showProjectPicker = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker("选择日期", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .navigationTitle("截止日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") { showDatePicker = false }
                        }
                    }
            }
        }
    }
}

#Preview {
    NavigationView {
        AddTaskView(
            isPresented: .constant(true),
            project: .constant(Project(name: "测试项目"))
        )
    }
    .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 