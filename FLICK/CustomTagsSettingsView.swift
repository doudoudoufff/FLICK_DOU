import SwiftUI

struct CustomTagsSettingsView: View {
    enum TagType {
        case expenseType, groupType
        
        var title: String {
            switch self {
            case .expenseType: return "费用类型"
            case .groupType: return "组别"
            }
        }
        
        var description: String {
            switch self {
            case .expenseType: return "设置交易记录中可选择的费用类型"
            case .groupType: return "设置交易记录中可选择的组别"
            }
        }
        
        var iconName: String {
            switch self {
            case .expenseType: return "dollarsign.circle.fill"
            case .groupType: return "person.2.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .expenseType: return .blue
            case .groupType: return .green
            }
        }
    }
    
    @State private var selectedTagType: TagType = .expenseType
    @State private var expenseTypes: [String] = TagManager.shared.getAllExpenseTypes()
    @State private var groupTypes: [String] = TagManager.shared.getAllGroupTypes()
    @State private var newTagName: String = ""
    @State private var isEditingTag: Bool = false
    @State private var showingAddTagAlert: Bool = false
    @State private var showingResetAlert: Bool = false
    @State private var editingTagIndex: Int? = nil
    @State private var showingDeleteAlert: Bool = false
    @State private var tagToDelete: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 分段控制器 - 选择管理费用类型或组别
            Picker("标签类型", selection: $selectedTagType) {
                Text("费用类型").tag(TagType.expenseType)
                Text("组别").tag(TagType.groupType)
            }
            .pickerStyle(.segmented)
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
                    if selectedTagType == .expenseType {
                        ForEach(expenseTypes, id: \.self) { type in
                            tagRow(for: type)
                        }
                        .onDelete { indexSet in
                            deleteExpenseTypes(at: indexSet)
                        }
                    } else {
                        ForEach(groupTypes, id: \.self) { group in
                            tagRow(for: group)
                        }
                        .onDelete { indexSet in
                            deleteGroupTypes(at: indexSet)
                        }
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
        .navigationTitle("自定义标签管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .alert("添加新\(selectedTagType.title)", isPresented: $showingAddTagAlert) {
            TextField("输入\(selectedTagType.title)名称", text: $newTagName)
            Button("取消", role: .cancel) {}
            Button("添加") {
                addNewTag()
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
                if selectedTagType == .expenseType {
                    TagManager.shared.removeExpenseType(tagToDelete)
                    expenseTypes = TagManager.shared.getAllExpenseTypes()
                } else {
                    TagManager.shared.removeGroupType(tagToDelete)
                    groupTypes = TagManager.shared.getAllGroupTypes()
                }
            }
        } message: {
            Text("确定要删除\"\(tagToDelete)\"吗？这可能会影响已使用该标签的交易记录。")
        }
        .onChange(of: selectedTagType) { _ in
            // 切换标签类型时刷新数据
            refreshData()
        }
    }
    
    // 标签行视图
    private func tagRow(for tag: String) -> some View {
        HStack {
            Image(systemName: selectedTagType.iconName)
                .foregroundColor(selectedTagType.iconColor)
                .font(.subheadline)
            
            Text(tag)
            
            Spacer()
            
            Button(action: {
                tagToDelete = tag
                showingDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    // 添加新标签
    private func addNewTag() {
        guard !newTagName.isEmpty else { return }
        
        if selectedTagType == .expenseType {
            TagManager.shared.addExpenseType(newTagName)
            expenseTypes = TagManager.shared.getAllExpenseTypes()
        } else {
            TagManager.shared.addGroupType(newTagName)
            groupTypes = TagManager.shared.getAllGroupTypes()
        }
        
        newTagName = ""
    }
    
    // 删除费用类型
    private func deleteExpenseTypes(at offsets: IndexSet) {
        offsets.forEach { index in
            if index < expenseTypes.count {
                let type = expenseTypes[index]
                TagManager.shared.removeExpenseType(type)
            }
        }
        expenseTypes = TagManager.shared.getAllExpenseTypes()
    }
    
    // 删除组别类型
    private func deleteGroupTypes(at offsets: IndexSet) {
        offsets.forEach { index in
            if index < groupTypes.count {
                let group = groupTypes[index]
                TagManager.shared.removeGroupType(group)
            }
        }
        groupTypes = TagManager.shared.getAllGroupTypes()
    }
    
    // 重置标签
    private func resetTags() {
        if selectedTagType == .expenseType {
            TagManager.shared.resetExpenseTypes()
            expenseTypes = TagManager.shared.getAllExpenseTypes()
        } else {
            TagManager.shared.resetGroupTypes()
            groupTypes = TagManager.shared.getAllGroupTypes()
        }
    }
    
    // 刷新数据
    private func refreshData() {
        expenseTypes = TagManager.shared.getAllExpenseTypes()
        groupTypes = TagManager.shared.getAllGroupTypes()
    }
}

#Preview {
    NavigationStack {
        CustomTagsSettingsView()
    }
} 
