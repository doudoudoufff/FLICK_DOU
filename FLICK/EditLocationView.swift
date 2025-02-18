import SwiftUI

struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var location: Location
    
    @State private var name: String
    @State private var type: LocationType
    @State private var status: LocationStatus
    @State private var address: String
    @State private var contactName: String
    @State private var contactPhone: String
    @State private var notes: String
    
    init(location: Binding<Location>) {
        self._location = location
        
        // 初始化状态变量
        _name = State(initialValue: location.wrappedValue.name)
        _type = State(initialValue: location.wrappedValue.type)
        _status = State(initialValue: location.wrappedValue.status)
        _address = State(initialValue: location.wrappedValue.address)
        _contactName = State(initialValue: location.wrappedValue.contactName ?? "")
        _contactPhone = State(initialValue: location.wrappedValue.contactPhone ?? "")
        _notes = State(initialValue: location.wrappedValue.notes ?? "")
    }
    
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
                
                Section("状态") {
                    Picker("场地状态", selection: $status) {
                        ForEach(LocationStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
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
            .navigationTitle("编辑场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 更新场地信息
                        location.name = name
                        location.type = type
                        location.status = status
                        location.address = address
                        location.contactName = contactName.isEmpty ? nil : contactName
                        location.contactPhone = contactPhone.isEmpty ? nil : contactPhone
                        location.notes = notes.isEmpty ? nil : notes
                        
                        dismiss()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
} 