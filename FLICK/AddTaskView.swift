import SwiftUI

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var taskTitle = ""
    @State private var assignee = ""
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("任务内容", text: $taskTitle)
                        .focused($titleFieldFocused)
                } header: {
                    Text("必填信息")
                }
                
                Section {
                    TextField("负责人员", text: $assignee)
                    DatePicker("截止时间", selection: $dueDate, displayedComponents: .date)
                } header: {
                    Text("任务详情")
                }
            }
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let newTask = ProjectTask(
                            title: taskTitle,
                            assignee: assignee,
                            dueDate: dueDate
                        )
                        project.tasks.append(newTask)
                        isPresented = false
                    }
                    .disabled(taskTitle.isEmpty)
                }
            }
        }
        .onAppear {
            titleFieldFocused = true
        }
    }
    
    @FocusState private var titleFieldFocused: Bool
} 