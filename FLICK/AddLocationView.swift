import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    
    @State private var name = ""
    @State private var type = LocationType.exterior
    @State private var status = LocationStatus.pending
    @State private var address = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("场地名称", text: $name)
                    Picker("场地类型", selection: $type) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("详细地址", text: $address)
                }
                
                Section("联系方式") {
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("添加场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let location = Location(
                            name: name,
                            type: type,
                            status: status,
                            address: address,
                            contactName: contactName.isEmpty ? nil : contactName,
                            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                            notes: notes.isEmpty ? nil : notes
                        )
                        
                        projectStore.addLocation(location, to: project)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !address.isEmpty
    }
} 