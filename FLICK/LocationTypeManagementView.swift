import SwiftUI

struct LocationTypeManagementView: View {
    @State private var customTypeName = ""
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: String?
    @State private var customTypes: [String] = []
    
    // 加载自定义类型
    private func loadCustomTypes() {
        customTypes = UserDefaults.standard.stringArray(forKey: "FLICK_CustomLocationTypes") ?? []
    }
    
    var body: some View {
        List {
            Section("预设类型") {
                ForEach(LocationType.presetCases, id: \.rawValue) { type in
                    HStack {
                        Text(type.rawValue)
                        Spacer()
                        if type != .other {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("自定义类型") {
                if customTypes.isEmpty {
                    Text("尚未添加自定义类型")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .italic()
                } else {
                    ForEach(customTypes, id: \.self) { typeName in
                        HStack {
                            Text(typeName)
                            Spacer()
                            Button(action: {
                                typeToDelete = typeName
                                showingDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            
            Section("添加新类型") {
                HStack {
                    TextField("输入新类型名称", text: $customTypeName)
                    Button("添加") {
                        guard !customTypeName.isEmpty else { return }
                        LocationType.registerCustomType(customTypeName)
                        customTypeName = ""
                        loadCustomTypes()
                    }
                    .disabled(customTypeName.isEmpty)
                }
            }
        }
        .navigationTitle("场景类型管理")
        .onAppear {
            loadCustomTypes()
        }
        .alert(
            "确认删除",
            isPresented: $showingDeleteAlert,
            actions: {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let typeName = typeToDelete {
                        LocationType.removeCustomType(typeName)
                        loadCustomTypes()
                    }
                }
            },
            message: {
                if let typeName = typeToDelete {
                    Text("确认删除: \(typeName) 类型?\n所有使用此类型的场景将保持不变。")
                } else {
                    Text("确认删除选定的类型?")
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        LocationTypeManagementView()
    }
} 
 