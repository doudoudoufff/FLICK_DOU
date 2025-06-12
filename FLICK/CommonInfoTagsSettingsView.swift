import SwiftUI

struct CommonInfoTagsSettingsView: View {
    @StateObject private var tagManager = CustomTagManager.shared
    @State private var infoTags: [TagEntity] = []
    @State private var newTagName: String = ""
    @State private var showingResetAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var tagToDelete: String = ""
    @State private var showingColorPicker: Bool = false
    @State private var selectedTag: TagEntity? = nil
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签说明
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text("设置常用信息中可选择的标签类型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // 标签列表
            List {
                Section {
                    // 新增标签输入框
                    HStack {
                        TextField("添加新标签", text: $newTagName)
                        
                        Button(action: {
                            addNewTag()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newTagName.isEmpty)
                    }
                } header: {
                    Text("新增标签")
                }
                
                Section {
                    ForEach(infoTags, id: \.id) { tag in
                        tagRow(for: tag)
                    }
                    .onDelete { indexSet in
                        deleteInfoTags(at: indexSet)
                    }
                } header: {
                    HStack {
                        Text("已有标签")
                        Spacer()
                        Button("重置为默认") {
                            showingResetAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("自定义常用信息标签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            if let tag = selectedTag {
                colorPickerView(for: tag)
            }
        }
        .alert("确认重置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                resetTags()
            }
        } message: {
            Text("确定要将标签重置为默认值吗？这将删除所有自定义标签。")
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if !tagToDelete.isEmpty {
                    tagManager.removeInfoTag(tagToDelete)
                    refreshData()
                }
            }
        } message: {
            Text("确定要删除\"\(tagToDelete)\"吗？这可能会影响已使用该标签的常用信息。")
        }
        .onAppear {
            refreshData()
        }
    }
    
    // 标签行视图
    private func tagRow(for tag: TagEntity) -> some View {
        HStack {
            Circle()
                .fill(tagManager.color(from: tag.colorHex))
                .frame(width: 12, height: 12)
            
            Text(tag.name ?? "")
            
            Spacer()
            
            Button(action: {
                selectedTag = tag
                selectedColor = tagManager.color(from: tag.colorHex)
                showingColorPicker = true
            }) {
                Image(systemName: "paintpalette")
                    .foregroundColor(.blue)
            }
            
            if !tag.isDefault {
                Button(action: {
                    tagToDelete = tag.name ?? ""
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // 颜色选择器视图
    private func colorPickerView(for tag: TagEntity) -> some View {
        NavigationView {
            VStack {
                ColorPicker("选择颜色", selection: $selectedColor)
                    .padding()
                
                Button("保存") {
                    if let name = tag.name {
                        tagManager.updateTagColor(name: name, type: .infoType, color: selectedColor)
                        refreshData()
                        showingColorPicker = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Spacer()
            }
            .navigationTitle("标签颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingColorPicker = false
                    }
                }
            }
        }
    }
    
    // 添加新标签
    private func addNewTag() {
        guard !newTagName.isEmpty else { return }
        
        tagManager.addInfoTag(newTagName)
        refreshData()
        
        newTagName = ""
    }
    
    // 删除标签
    private func deleteInfoTags(at offsets: IndexSet) {
        offsets.forEach { index in
            if index < infoTags.count {
                let tag = infoTags[index]
                if let name = tag.name, !tag.isDefault {
                    tagManager.removeInfoTag(name)
                }
            }
        }
        refreshData()
    }
    
    // 重置标签
    private func resetTags() {
        tagManager.resetInfoTags()
        refreshData()
    }
    
    // 刷新数据
    private func refreshData() {
        infoTags = tagManager.getAllTags(ofType: .infoType)
    }
}

#Preview {
    NavigationStack {
        CommonInfoTagsSettingsView()
    }
} 