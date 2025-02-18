import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    
    @State private var name = ""
    @State private var type = LocationType.exterior
    @State private var address = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
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
                    Button("添加") {
                        let location = Location(
                            name: name,
                            type: type,
                            address: address,
                            contactName: contactName.isEmpty ? nil : contactName,
                            contactPhone: contactPhone.isEmpty ? nil : contactPhone,
                            notes: notes.isEmpty ? nil : notes
                        )
                        project.locations.append(location)
                        dismiss()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
} 