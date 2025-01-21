import SwiftUI

struct EditTaskView: View {
    @Binding var isPresented: Bool
    @Binding var task: ProjectTask
    
    @State private var editedTitle: String
    @State private var editedAssignee: String
    @State private var editedDueDate: Date
    
    init(isPresented: Binding<Bool>, task: Binding<ProjectTask>) {
        _isPresented = isPresented
        _task = task
        _editedTitle = State(initialValue: task.wrappedValue.title)
        _editedAssignee = State(initialValue: task.wrappedValue.assignee)
        _editedDueDate = State(initialValue: task.wrappedValue.dueDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("任务内容", text: $editedTitle)
                        .focused($titleFieldFocused)
                } header: {
                    Text("必填信息")
                }
                
                Section {
                    TextField("负责人员", text: $editedAssignee)
                    DatePicker("截止时间", selection: $editedDueDate, displayedComponents: .date)
                } header: {
                    Text("任务详情")
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        task.title = editedTitle
                        task.assignee = editedAssignee
                        task.dueDate = editedDueDate
                        isPresented = false
                    }
                    .disabled(editedTitle.isEmpty)
                }
            }
        }
        .onAppear {
            titleFieldFocused = true
        }
    }
    
    @FocusState private var titleFieldFocused: Bool
} 