import SwiftUI

struct CommonInfoManagementView: View {
    // 信息类型选择（项目账户、公司账户、个人账户）
    @State private var selectedTab: CommonInfoType = .project
    @State private var searchText = ""
    @State private var showingAddInfo = false
    @State private var showFilterSheet = false
    @State private var selectedTag: String? = nil
    
    // 使用CoreData管理器
    @StateObject private var manager = CommonInfoManager()
    
    // 标签选项
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "其他"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部选项卡
            Picker("信息类型", selection: $selectedTab) {
                Text("项目账户").tag(CommonInfoType.project)
                Text("公司账户").tag(CommonInfoType.company)
                Text("个人账户").tag(CommonInfoType.personal)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 12) // 增加垂直内边距使选项卡更大
            .font(.headline) // 增大字体
            
            // 搜索和筛选栏
            HStack(spacing: 12) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                    
                    TextField("搜索信息", text: $searchText)
                        .font(.system(size: 15))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 6)
                        }
                    }
                }
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 筛选按钮
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(selectedTag != nil ? .accentColor : .secondary)
                        
                        if let tag = selectedTag {
                            Text(tag)
                                .font(.subheadline)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTag != nil ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedTag != nil ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.vertical, 8)
            
            // 信息列表
            ScrollView {
                if filteredInfos.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 40)
                        
                        // 空状态图标
                        Image(systemName: searchText.isEmpty && selectedTag == nil ? "doc.text.magnifyingglass" : "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        // 提示文本
                        VStack(spacing: 8) {
                            if searchText.isEmpty && selectedTag == nil {
                                Text("暂无\(tabTitle(for: selectedTab))信息")
                                    .font(.headline)
                                
                                Text("点击右上角的添加按钮创建新的信息")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button(action: { showingAddInfo = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                        Text("添加\(tabTitle(for: selectedTab))信息")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 12)
                            } else {
                                Text("未找到匹配的信息")
                                    .font(.headline)
                                
                                Text(selectedTag != nil ? "没有标签为\"\(selectedTag!)\"的信息" : "尝试其他搜索关键词")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(minHeight: 300)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        // 根据选中的选项卡和搜索文本过滤显示的信息
                        ForEach(filteredInfos) { info in
                            NavigationLink(destination: CommonInfoDetailView(manager: manager, info: info)) {
                                CommonInfoRow(info: info)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("常用信息")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddInfo = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("添加")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
            }
        }
        .sheet(isPresented: $showingAddInfo) {
            NavigationView {
                CommonInfoAddView(manager: manager, infoType: selectedTab)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationView {
                List {
                    Button("全部") {
                        selectedTag = nil
                        showFilterSheet = false
                    }
                    
                    ForEach(tagOptions, id: \.self) { tag in
                        Button(tag) {
                            selectedTag = tag
                            showFilterSheet = false
                        }
                    }
                }
                .navigationTitle("选择标签")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            showFilterSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            manager.fetchAllInfos()
        }
    }
    
    // 根据选项卡和搜索文本过滤信息
    var filteredInfos: [CommonInfoEntity] {
        let infos: [CommonInfoEntity]
        
        switch selectedTab {
        case .project:
            infos = manager.projectInfos
        case .company:
            infos = manager.companyInfos
        case .personal:
            infos = manager.personalInfos
        }
        
        var filtered = infos
        
        // 应用标签筛选
        if let tag = selectedTag {
            filtered = filtered.filter { $0.tag == tag }
        }
        
        // 应用搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.content?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    // 根据选项卡获取标题文本
    private func tabTitle(for tab: CommonInfoType) -> String {
        switch tab {
        case .project: return "项目账户"
        case .company: return "公司账户"
        case .personal: return "个人账户"
        }
    }
}

// 信息类型枚举
enum CommonInfoType: String, CaseIterable {
    case project = "项目账户"
    case company = "公司账户"
    case personal = "个人账户"
}

// 信息行视图
struct CommonInfoRow: View {
    let info: CommonInfoEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：标题、标签和收藏状态
            HStack {
                Text(info.title ?? "")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // 收藏图标
                if info.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .imageScale(.small)
                }
                
                // 标签胶囊
                Text(info.tag ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagColor(for: info.tag ?? "").opacity(0.15))
                    .foregroundColor(tagColor(for: info.tag ?? ""))
                    .cornerRadius(12)
            }
            
            // 内容预览
            if let content = info.content {
                Text(content.prefix(80) + (content.count > 80 ? "..." : ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // 底部：添加日期
            HStack {
                Spacer()
                Text(formattedDate(info.dateAdded ?? Date()))
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // 根据标签返回不同颜色
    func tagColor(for tag: String) -> Color {
        switch tag {
        case "银行账户":
            return .blue
        case "发票":
            return .green
        case "地址":
            return .purple
        case "常用供应商":
            return .orange
        default:
            return .gray
        }
    }
}

// 信息详情视图
struct CommonInfoDetailView: View {
    let manager: CommonInfoManager
    let info: CommonInfoEntity
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var copiedMessage = ""
    @State private var showingCopiedAlert = false
    @State private var isFavorite: Bool
    @Environment(\.presentationMode) var presentationMode
    
    init(manager: CommonInfoManager, info: CommonInfoEntity) {
        self.manager = manager
        self.info = info
        self._isFavorite = State(initialValue: info.isFavorite)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题和标签
                HStack {
                    Text(info.title ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(info.tag ?? "")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagColor(for: info.tag ?? "").opacity(0.15))
                        .foregroundColor(tagColor(for: info.tag ?? ""))
                        .cornerRadius(12)
                }
                
                Divider()
                
                // 内容
                Text(info.content ?? "")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: copyAllInfo) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制所有信息")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("编辑")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemRed).opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
            }
        }
        .alert("已复制", isPresented: $showingCopiedAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(copiedMessage)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteInfo()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("确定要删除这条信息吗？此操作不可撤销。")
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                CommonInfoEditView(manager: manager, info: info)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func copyAllInfo() {
        UIPasteboard.general.string = "\(info.title ?? "")\n\n\(info.content ?? "")"
        copiedMessage = "信息已复制到剪贴板"
        showingCopiedAlert = true
    }
    
    private func toggleFavorite() {
        isFavorite.toggle()
        if manager.toggleFavorite(info) {
            // 切换成功
        }
    }
    
    private func deleteInfo() {
        if manager.deleteInfo(info) {
            // 删除成功
        }
    }
    
    // 根据标签返回不同颜色
    func tagColor(for tag: String) -> Color {
        switch tag {
        case "银行账户":
            return .blue
        case "发票":
            return .green
        case "地址":
            return .purple
        case "常用供应商":
            return .orange
        default:
            return .gray
        }
    }
}

// 添加信息视图
struct CommonInfoAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CommonInfoType
    let manager: CommonInfoManager
    
    @State private var title = ""
    @State private var tag = "银行账户"
    @State private var content = ""
    
    // 项目账户专用字段
    @State private var bankName = ""
    @State private var accountNumber = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    
    // 标签选项
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "其他"]
    
    init(manager: CommonInfoManager, infoType: CommonInfoType) {
        self.manager = manager
        self._selectedType = State(initialValue: infoType)
    }
    
    var body: some View {
        Form {
            Section(header: Text("信息类型")) {
                Picker("类型", selection: $selectedType) {
                    Text("项目账户").tag(CommonInfoType.project)
                    Text("公司账户").tag(CommonInfoType.company)
                    Text("个人账户").tag(CommonInfoType.personal)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("基本信息")) {
                TextField("标题", text: $title)
                
                Picker("标签", selection: $tag) {
                    ForEach(tagOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }
            
            if selectedType == .project {
                // 项目账户使用结构化表单
                Section(header: Text("账户信息")) {
                    TextField("开户行", text: $bankName)
                    TextField("账号", text: $accountNumber)
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                }
                
                Section(header: Text("提示")) {
                    Text("项目账户建议包含：开户行、账号、联系人、电话等信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 公司账户和个人账户使用自由文本
                Section(header: Text("内容")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                if selectedType == .company {
                    Section(header: Text("提示")) {
                        Text("公司账户可以记录：公司银行账户、开票信息、地址等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(header: Text("提示")) {
                        Text("个人账户可以记录：个人账户、地址、联系方式等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("添加常用信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveInfo()
                    dismiss()
                }
                .disabled(title.isEmpty || (selectedType == .project ? (bankName.isEmpty || accountNumber.isEmpty) : content.isEmpty))
            }
        }
    }
    
    // 保存信息
    private func saveInfo() {
        let contentText = selectedType == .project ? 
                "开户行：\(bankName)\n账号：\(accountNumber)\n联系人：\(contactName)\n电话：\(contactPhone)" :
                content
        
        manager.addInfo(
            title: title, 
            type: selectedType.rawValue, 
            tag: tag, 
            content: contentText
        )
    }
}

// 编辑信息视图
struct CommonInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: CommonInfoManager
    let info: CommonInfoEntity
    
    @State private var title: String
    @State private var tag: String
    @State private var content: String
    @State private var selectedType: CommonInfoType
    
    // 项目账户专用字段
    @State private var bankName = ""
    @State private var accountNumber = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    
    // 标签选项
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "其他"]
    
    init(manager: CommonInfoManager, info: CommonInfoEntity) {
        self.manager = manager
        self.info = info
        _title = State(initialValue: info.title ?? "")
        _tag = State(initialValue: info.tag ?? "")
        _content = State(initialValue: info.content ?? "")
        _selectedType = State(initialValue: CommonInfoType(rawValue: info.type ?? "") ?? .personal)
        
        // 如果是项目账户，解析内容到结构化字段
        if info.type == CommonInfoType.project.rawValue {
            // 解析内容
            let lines = (info.content ?? "").components(separatedBy: "\n")
            for line in lines {
                if line.starts(with: "开户行：") {
                    _bankName = State(initialValue: String(line.dropFirst(4)))
                } else if line.starts(with: "账号：") {
                    _accountNumber = State(initialValue: String(line.dropFirst(3)))
                } else if line.starts(with: "联系人：") {
                    _contactName = State(initialValue: String(line.dropFirst(4)))
                } else if line.starts(with: "电话：") {
                    _contactPhone = State(initialValue: String(line.dropFirst(3)))
                }
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("信息类型")) {
                Picker("类型", selection: $selectedType) {
                    Text("项目账户").tag(CommonInfoType.project)
                    Text("公司账户").tag(CommonInfoType.company)
                    Text("个人账户").tag(CommonInfoType.personal)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("基本信息")) {
                TextField("标题", text: $title)
                
                Picker("标签", selection: $tag) {
                    ForEach(tagOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }
            
            if selectedType == .project {
                // 项目账户使用结构化表单
                Section(header: Text("账户信息")) {
                    TextField("开户行", text: $bankName)
                    TextField("账号", text: $accountNumber)
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                }
            } else {
                // 公司账户和个人账户使用自由文本
                Section(header: Text("内容")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
        }
        .navigationTitle("编辑信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveChanges()
                    dismiss()
                }
                .disabled(title.isEmpty || (selectedType == .project ? (bankName.isEmpty || accountNumber.isEmpty) : content.isEmpty))
            }
        }
    }
    
    // 保存编辑
    private func saveChanges() {
        let updatedContent = selectedType == .project ?
            "开户行：\(bankName)\n账号：\(accountNumber)\n联系人：\(contactName)\n电话：\(contactPhone)" :
            content
        
        manager.updateInfo(
            info: info,
            title: title,
            tag: tag,
            content: updatedContent
        )
    }
}

struct CommonInfoManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CommonInfoManagementView()
    }
} 
