import SwiftUI

struct CustomTagsSettingsView: View {
    @StateObject private var tagManager = CustomTagManager.shared
    
    enum TagUIType {
        case expenseType, groupType, infoType, venueType
        
        var title: String {
            switch self {
            case .expenseType: return "费用类型"
            case .groupType: return "组别"
            case .infoType: return "常用信息标签"
            case .venueType: return "场地类型"
            }
        }
        
        var description: String {
            switch self {
            case .expenseType: return "设置交易记录中可选择的费用类型"
            case .groupType: return "设置交易记录中可选择的组别"
            case .infoType: return "设置常用信息中可选择的标签类型"
            case .venueType: return "设置场地管理中可选择的场地类型"
            }
        }
        
        var iconName: String {
            switch self {
            case .expenseType: return "dollarsign.circle.fill"
            case .groupType: return "person.2.fill"
            case .infoType: return "tag.fill"
            case .venueType: return "building.2.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .expenseType: return .blue
            case .groupType: return .green
            case .infoType: return .blue
            case .venueType: return .orange
            }
        }
        
        var tagType: TagCategoryType {
            switch self {
            case .expenseType: return .expenseType
            case .groupType: return .groupType
            case .infoType: return .infoType
            case .venueType: return .venueType
            }
        }
    }
    
    @State private var selectedTagType: TagUIType
    @State private var tags: [TagEntity] = []
    @State private var newTagName: String = ""
    @State private var showingResetAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var tagToDelete: String = ""
    @State private var showingColorPicker: Bool = false
    @State private var selectedTag: TagEntity? = nil
    @State private var selectedColor: Color = .blue
    
    // 添加初始化函数，支持指定初始标签类型
    init(initialTagType: TagUIType = .expenseType) {
        _selectedTagType = State(initialValue: initialTagType)
    }
    
    // 获取导航标题
    private var navigationTitle: String {
        "自定义\(selectedTagType.title)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签类型选择器
            HStack {
                Text("标签类型：")
                    .font(.headline)
                
                Picker("选择标签类型", selection: $selectedTagType) {
                    Text("费用类型").tag(TagUIType.expenseType)
                    Text("组别").tag(TagUIType.groupType)
                    Text("常用信息标签").tag(TagUIType.infoType)
                    Text("场地类型").tag(TagUIType.venueType)
                }
                .pickerStyle(.menu)
                .tint(selectedTagType.iconColor)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // 标签说明
            HStack {
                Image(systemName: selectedTagType.iconName)
                    .foregroundColor(selectedTagType.iconColor)
                Text(selectedTagType.description)
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
                        TextField("添加新\(selectedTagType.title)", text: $newTagName)
                        
                        Button(action: {
                            addNewTag()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newTagName.isEmpty)
                    }
                } header: {
                    Text("新增\(selectedTagType.title)")
                }
                
                Section {
                    ForEach(tags, id: \.id) { tag in
                        tagRow(for: tag)
                    }
                    .onDelete { indexSet in
                        deleteTags(at: indexSet)
                    }
                } header: {
                    HStack {
                        Text("已有\(selectedTagType.title)")
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
        .navigationTitle(navigationTitle)
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
            Text("确定要将\(selectedTagType.title)重置为默认值吗？这将删除所有自定义标签。")
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if !tagToDelete.isEmpty {
                    tagManager.removeTag(name: tagToDelete, type: selectedTagType.tagType)
                    refreshData()
                }
            }
        } message: {
            Text("确定要删除\"\(tagToDelete)\"吗？这可能会影响已使用该标签的交易记录。")
        }
        .onChange(of: selectedTagType) { _ in
            // 切换标签类型时刷新数据
            refreshData()
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
                        tagManager.updateTagColor(name: name, type: selectedTagType.tagType, color: selectedColor)
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
        
        _ = tagManager.addTag(name: newTagName, type: selectedTagType.tagType)
        refreshData()
        newTagName = ""
    }
    
    // 删除标签
    private func deleteTags(at offsets: IndexSet) {
        offsets.forEach { index in
            if index < tags.count {
                let tag = tags[index]
                if let name = tag.name, !tag.isDefault {
                    tagManager.removeTag(name: name, type: selectedTagType.tagType)
                }
            }
        }
        refreshData()
    }
    
    // 重置标签
    private func resetTags() {
        tagManager.resetTags(forType: selectedTagType.tagType)
        refreshData()
    }
    
    // 刷新数据
    private func refreshData() {
        tags = tagManager.getAllTags(ofType: selectedTagType.tagType)
    }
}

#Preview {
    NavigationStack {
        CustomTagsSettingsView()
    }
} 
