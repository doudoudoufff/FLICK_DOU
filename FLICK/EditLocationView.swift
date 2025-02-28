import SwiftUI

struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    let location: Location
    let projectStore: ProjectStore
    let project: Project
    
    @State private var editedLocation: Location
    
    init(location: Location, projectStore: ProjectStore, project: Project) {
        self.location = location
        self.projectStore = projectStore
        self.project = project
        self._editedLocation = State(initialValue: location)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("场地名称", text: Binding(
                        get: { editedLocation.name },
                        set: { editedLocation.name = $0 }
                    ))
                    Picker("场地类型", selection: Binding(
                        get: { editedLocation.type },
                        set: { editedLocation.type = $0 }
                    )) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("详细地址", text: Binding(
                        get: { editedLocation.address },
                        set: { editedLocation.address = $0 }
                    ))
                }
                
                Section("状态") {
                    Picker("场地状态", selection: $editedLocation.status) {
                        ForEach(LocationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                Section("联系方式") {
                    TextField("联系人", text: Binding(
                        get: { editedLocation.contactName ?? "" },
                        set: { editedLocation.contactName = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("联系电话", text: Binding(
                        get: { editedLocation.contactPhone ?? "" },
                        set: { editedLocation.contactPhone = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.phonePad)
                }
                
                Section("备注") {
                    TextEditor(text: Binding(
                        get: { editedLocation.notes ?? "" },
                        set: { editedLocation.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(height: 100)
                }
            }
            .navigationTitle("编辑场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await projectStore.updateLocation(editedLocation, in: project)
                            dismiss()
                        }
                    }
                    .disabled(editedLocation.name.isEmpty || editedLocation.address.isEmpty)
                }
            }
        }
    }
} 