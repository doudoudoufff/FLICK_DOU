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
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "场地", "道具", "服装", "化妆", "其他"]
    
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
            
            // 内容区域
            if selectedTab == .project {
                // 项目账户列表
                ProjectAccountListView(manager: manager, searchText: $searchText, selectedTag: $selectedTag)
            } else {
                // 其他常用信息列表
                CommonInfoListView(manager: manager, selectedTab: selectedTab, searchText: $searchText, selectedTag: $selectedTag)
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
                // 根据当前选中的选项卡传递不同的类型
                UnifiedAddInfoView(infoType: selectedTab, manager: manager)
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
    
    // 根据选项卡获取标题文本
    private func tabTitle(for tab: CommonInfoType) -> String {
        switch tab {
        case .project: return "项目账户"
        case .company: return "公司账户"
        case .personal: return "个人账户"
        }
    }
}

// MARK: - 项目账户列表视图
struct ProjectAccountListView: View {
    @ObservedObject var manager: CommonInfoManager
    @Binding var searchText: String
    @Binding var selectedTag: String?
    
    var body: some View {
        ZStack {
            if filteredAccounts.isEmpty {
                // 空状态视图
                emptyStateView
            } else {
                // 账户列表
                accountListView
            }
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 24) {
            Spacer().frame(height: 40)
            
            // 空状态图标
            let iconName = searchText.isEmpty && selectedTag == nil ? 
                "person.crop.circle.badge.exclamationmark" : "magnifyingglass"
            
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.6))
            
            // 提示文本
            VStack(alignment: .center, spacing: 8) {
                if searchText.isEmpty && selectedTag == nil {
                    Text("暂无项目账户信息")
                        .font(.headline)
                    
                    Text("请先在项目中添加账户信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("未找到匹配的项目账户")
                        .font(.headline)
                    
                    let noResultsText = selectedTag != nil ? 
                        "没有类型为\"\(selectedTag!)\"的账户" : "尝试其他搜索关键词"
                    
                    Text(noResultsText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(minHeight: 300)
        .padding()
    }
    
    // 账户列表视图
    private var accountListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 按项目分组显示账户
                ForEach(groupedAccounts.keys.sorted(), id: \.self) { projectName in
                    if let accounts = groupedAccounts[projectName] {
                        ProjectAccountSection(
                            projectName: projectName,
                            accounts: accounts,
                            manager: manager,
                            deleteAction: deleteAccount
                        )
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // 过滤账户
    var filteredAccounts: [AccountEntity] {
        var accounts = manager.projectAccounts
        
        // 应用标签筛选
        if let tag = selectedTag {
            accounts = accounts.filter { $0.type == tag }
        }
        
        // 应用搜索筛选
        if !searchText.isEmpty {
            accounts = accounts.filter {
                $0.name?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.bankName?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.bankAccount?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.contactName?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.project?.name?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return accounts
    }
    
    // 按项目分组账户
    var groupedAccounts: [String: [AccountEntity]] {
        var groups: [String: [AccountEntity]] = [:]
        
        for account in filteredAccounts {
            let projectName = account.project?.name ?? "未分类"
            if groups[projectName] == nil {
                groups[projectName] = []
            }
            groups[projectName]?.append(account)
        }
        
        return groups
    }
    
    // 删除账户
    func deleteAccount(_ account: AccountEntity) {
        let context = PersistenceController.shared.container.viewContext
        
        // 1. 删除关联的收藏信息
        manager.removeProjectAccountFromFavorites(account)
        
        // 2. 从Core Data中删除账户
        context.delete(account)
        
        // 3. 保存上下文
        do {
            try context.save()
            print("✓ 账户删除成功")
            
            // 4. 刷新数据
            manager.fetchAllInfos()
        } catch {
            print("❌ 删除账户失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 项目账户分组视图
struct ProjectAccountSection: View {
    let projectName: String
    let accounts: [AccountEntity]
    let manager: CommonInfoManager
    let deleteAction: (AccountEntity) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 项目名称标题
            Text(projectName)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // 该项目下的账户列表
            ForEach(accounts, id: \.id) { account in
                NavigationLink(destination: ProjectAccountDetailView(manager: manager, account: account)) {
                    ProjectAccountRow(manager: manager, account: account)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        deleteAction(account)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    
                    Button {
                        manager.toggleFavoriteProjectAccount(account)
                    } label: {
                        Label(manager.isProjectAccountFavorited(account) ? "取消收藏" : "收藏", 
                              systemImage: manager.isProjectAccountFavorited(account) ? "star.slash" : "star")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteAction(account)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        manager.toggleFavoriteProjectAccount(account)
                    } label: {
                        Label(manager.isProjectAccountFavorited(account) ? "取消收藏" : "收藏", 
                              systemImage: manager.isProjectAccountFavorited(account) ? "star.slash" : "star")
                    }
                    .tint(manager.isProjectAccountFavorited(account) ? .gray : .yellow)
                }
            }
        }
    }
}

// MARK: - 常用信息列表视图
struct CommonInfoListView: View {
    @ObservedObject var manager: CommonInfoManager
    let selectedTab: CommonInfoType
    @Binding var searchText: String
    @Binding var selectedTag: String?
    
    var body: some View {
        ZStack {
            if filteredInfos.isEmpty {
                // 空状态视图
                emptyStateView
            } else {
                // 信息列表
                infoListView
            }
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(alignment: .center, spacing: 24) {
            Spacer().frame(height: 40)
            
            // 空状态图标
            let iconName = searchText.isEmpty && selectedTag == nil ? 
                "doc.text.magnifyingglass" : "magnifyingglass"
            
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.6))
            
            // 提示文本
            VStack(alignment: .center, spacing: 8) {
                if searchText.isEmpty && selectedTag == nil {
                    Text("暂无\(tabTitle(for: selectedTab))信息")
                        .font(.headline)
                    
                    Text("点击右上角的添加按钮创建新的信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("未找到匹配的信息")
                        .font(.headline)
                    
                    let noResultsText = selectedTag != nil ? 
                        "没有标签为\"\(selectedTag!)\"的信息" : "尝试其他搜索关键词"
                    
                    Text(noResultsText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(minHeight: 300)
        .padding()
    }
    
    // 信息列表视图
    private var infoListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 使用ForEach并绑定到filteredInfos以支持滑动删除
                ForEach(filteredInfos) { info in
                    InfoItemRow(info: info, manager: manager)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // 根据选项卡和搜索文本过滤信息
    var filteredInfos: [CommonInfoEntity] {
        let infos: [CommonInfoEntity]
        
        switch selectedTab {
        case .project:
            // 项目账户已不再使用这里的过滤
            infos = []
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

// MARK: - 信息项行视图
struct InfoItemRow: View {
    let info: CommonInfoEntity
    let manager: CommonInfoManager
    
    var body: some View {
        NavigationLink(destination: CommonInfoDetailView(manager: manager, info: info)) {
            CommonInfoRow(info: info)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                manager.deleteInfo(info)
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                manager.toggleFavorite(info)
            } label: {
                Label(info.isFavorite ? "取消收藏" : "收藏", 
                      systemImage: info.isFavorite ? "star.slash" : "star")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                manager.deleteInfo(info)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                manager.toggleFavorite(info)
            } label: {
                Label(info.isFavorite ? "取消收藏" : "收藏", 
                      systemImage: info.isFavorite ? "star.slash" : "star")
            }
            .tint(info.isFavorite ? .gray : .yellow)
        }
    }
}

// MARK: - 项目账户行视图
struct ProjectAccountRow: View {
    @ObservedObject var manager: CommonInfoManager
    let account: AccountEntity
    @State private var isFavorite: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：标题、标签和收藏状态
            HStack {
                Text(account.name ?? "未命名账户")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // 收藏图标
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                        .imageScale(.small)
                }
                
                // 标签胶囊
                Text(account.type ?? "其他")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagColor(for: account.type ?? "其他").opacity(0.15))
                    .foregroundColor(tagColor(for: account.type ?? "其他"))
                    .cornerRadius(12)
            }
            
            // 内容预览
            VStack(alignment: .leading, spacing: 3) {
                if let bankName = account.bankName {
                    Text("开户行: \(bankName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let bankAccount = account.bankAccount {
                    Text("账号: \(bankAccount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let contactName = account.contactName {
                    Text("联系人: \(contactName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
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
        .onAppear {
            isFavorite = manager.isProjectAccountFavorited(account)
        }
    }
    
    private func toggleFavorite() {
        if manager.toggleFavoriteProjectAccount(account) {
            isFavorite.toggle()
        }
    }
    
    // 根据标签返回不同颜色
    func tagColor(for tag: String) -> Color {
        switch tag {
        case "场地":
            return .orange
        case "道具":
            return .blue
        case "服装":
            return .green
        case "化妆":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - 项目账户详情视图
struct ProjectAccountDetailView: View {
    @ObservedObject var manager: CommonInfoManager
    let account: AccountEntity
    @State private var isFavorite: Bool = false
    @State private var showingCopiedAlert = false
    @State private var copiedMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题和标签
                HStack {
                    Text(account.name ?? "未命名账户")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(account.type ?? "其他")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tagColor(for: account.type ?? "其他").opacity(0.15))
                        .foregroundColor(tagColor(for: account.type ?? "其他"))
                        .cornerRadius(12)
                }
                
                if let projectName = account.project?.name {
                    Text("所属项目: \(projectName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 内容
                VStack(alignment: .leading, spacing: 12) {
                    AccountInfoRow(title: "开户行", value: account.bankName ?? "")
                    AccountInfoRow(title: "支行", value: account.bankBranch ?? "")
                    AccountInfoRow(title: "账号", value: account.bankAccount ?? "")
                    AccountInfoRow(title: "联系人", value: account.contactName ?? "")
                    AccountInfoRow(title: "联系电话", value: account.contactPhone ?? "")
                    
                    if let idNumber = account.idNumber, !idNumber.isEmpty {
                        AccountInfoRow(title: "身份证号", value: idNumber)
                    }
                    
                    if let notes = account.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备注")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
                
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
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("账户详情")
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
        .onAppear {
            isFavorite = manager.isProjectAccountFavorited(account)
        }
    }
    
    private func copyAllInfo() {
        let content = """
        账户名称: \(account.name ?? "")
        开户行: \(account.bankName ?? "")
        支行: \(account.bankBranch ?? "")
        账号: \(account.bankAccount ?? "")
        联系人: \(account.contactName ?? "")
        联系电话: \(account.contactPhone ?? "")
        身份证号: \(account.idNumber ?? "")
        备注: \(account.notes ?? "")
        """
        
        UIPasteboard.general.string = content
        copiedMessage = "账户信息已复制到剪贴板"
        showingCopiedAlert = true
    }
    
    private func toggleFavorite() {
        if manager.toggleFavoriteProjectAccount(account) {
            isFavorite.toggle()
        }
    }
    
    // 根据标签返回不同颜色
    func tagColor(for tag: String) -> Color {
        switch tag {
        case "场地":
            return .orange
        case "道具":
            return .blue
        case "服装":
            return .green
        case "化妆":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - 账户信息行视图
struct AccountInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(value.isEmpty ? "未设置" : value)
                .font(.body)
                .foregroundColor(value.isEmpty ? .secondary.opacity(0.7) : .secondary)
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
        case "场地":
            return .orange
        case "道具":
            return .blue
        case "服装":
            return .green
        case "化妆":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - 信息详情视图
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
        // 使用下划线前缀明确指定是State属性包装器
        _isFavorite = State<Bool>(initialValue: info.isFavorite)
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
        case "场地":
            return .orange
        case "道具":
            return .blue
        case "服装":
            return .green
        case "化妆":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - 统一的添加信息视图
struct UnifiedAddInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CommonInfoType
    @ObservedObject var manager: CommonInfoManager
    @EnvironmentObject var projectStore: ProjectStore
    
    // 常用信息相关状态
    @State private var title = ""
    @State private var tag = "银行账户"
    @State private var content = ""
    
    // 项目账户相关状态
    @State private var selectedProject: ProjectEntity?
    @State private var showingCreateProjectSheet = false
    @State private var projects: [ProjectEntity] = []
    
    // 项目账户详细信息
    @State private var accountName = ""
    @State private var accountType = "场地"
    @State private var bankName = ""
    @State private var bankBranch = ""
    @State private var bankAccount = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var idNumber = ""
    @State private var notes = ""
    
    // 账户类型选项
    let accountTypeOptions = ["场地", "道具", "服装", "化妆", "其他"]
    
    // 标签选项
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "其他"]
    
    init(infoType: CommonInfoType, manager: CommonInfoManager) {
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
                .onChange(of: selectedType) { _ in
                    // 切换类型时重置表单
                    if selectedType != .project {
                        selectedProject = nil
                    }
                }
            }
            
            if selectedType == .project {
                // 项目账户相关表单
                Section(header: HStack {
                    Text("所属项目")
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }) {
                    if projects.isEmpty {
                        Button("暂无项目，请先创建项目") {
                            // 这里可以添加创建项目的逻辑
                        }
                        .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("选择项目")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(projects, id: \.id) { project in
                                        Button(action: {
                                            selectedProject = project
                                        }) {
                                            Text(project.name ?? "未命名项目")
                                                .font(.system(size: 14))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedProject?.id == project.id ? Color.accentColor : Color(.systemGray5))
                                                .foregroundColor(selectedProject?.id == project.id ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                if selectedProject != nil {
                    // 账户基本信息
                    Section(header: Text("基本信息")) {
                        TextField("收款方名称", text: $accountName)
                        
                        Picker("账户类型", selection: $accountType) {
                            ForEach(accountTypeOptions, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                    }
                    
                    // 银行信息
                    Section(header: Text("银行信息")) {
                        TextField("开户行", text: $bankName)
                        TextField("支行", text: $bankBranch)
                        TextField("账号", text: $bankAccount)
                            .keyboardType(.numberPad)
                        TextField("身份证号（选填）", text: $idNumber)
                            .textInputAutocapitalization(.never)
                    }
                    
                    // 联系方式
                    Section(header: Text("联系方式")) {
                        TextField("联系人", text: $contactName)
                        TextField("联系电话", text: $contactPhone)
                            .keyboardType(.phonePad)
                    }
                    
                    // 备注
                    Section(header: Text("备注")) {
                        TextEditor(text: $notes)
                            .frame(height: 100)
                    }
                }
            } else {
                // 公司账户或个人账户表单
                Section(header: Text("基本信息")) {
                    TextField("标题", text: $title)
                    
                    Picker("标签", selection: $tag) {
                        ForEach(tagOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
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
        .navigationTitle("添加信息")
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
                .disabled(!isValid)
            }
        }
        .onAppear {
            fetchProjects()
        }
    }
    
    // 表单验证
    private var isValid: Bool {
        if selectedType == .project {
            return selectedProject != nil && 
                   !accountName.isEmpty &&
                   !bankName.isEmpty &&
                   !bankBranch.isEmpty &&
                   !bankAccount.isEmpty &&
                   !contactName.isEmpty &&
                   !contactPhone.isEmpty
        } else {
            return !title.isEmpty && !content.isEmpty
        }
    }
    
    // 保存信息
    private func saveInfo() {
        if selectedType == .project {
            if let project = selectedProject {
                addAccountToProject(project)
            }
        } else {
            // 保存常用信息
            manager.addInfo(
                title: title, 
                type: selectedType.rawValue, 
                tag: tag, 
                content: content
            )
        }
    }
    
    // 添加账户到项目
    private func addAccountToProject(_ project: ProjectEntity) {
        // 创建账户实体
        let context = PersistenceController.shared.container.viewContext
        let accountEntity = AccountEntity(context: context)
        
        // 设置账户属性
        accountEntity.id = UUID()
        accountEntity.name = accountName
        accountEntity.type = accountType
        accountEntity.bankName = bankName
        accountEntity.bankBranch = bankBranch
        accountEntity.bankAccount = bankAccount
        accountEntity.idNumber = idNumber.isEmpty ? nil : idNumber
        accountEntity.contactName = contactName
        accountEntity.contactPhone = contactPhone
        accountEntity.notes = notes.isEmpty ? nil : notes
        
        // 关联到项目
        accountEntity.project = project
        
        // 保存上下文
        do {
            try context.save()
            print("✓ 成功添加账户")
            
            // 刷新数据
            manager.fetchAllInfos()
        } catch {
            print("❌ 添加账户失败: \(error.localizedDescription)")
        }
    }
    
    // 获取所有项目
    private func fetchProjects() {
        let request = ProjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.name, ascending: true)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            projects = try context.fetch(request)
        } catch {
            print("获取项目失败: \(error.localizedDescription)")
            projects = []
        }
    }
}

// MARK: - 项目选择器视图
struct ProjectPickerView: View {
    @Binding var selectedProject: ProjectEntity?
    @State private var searchText = ""
    @State private var projects: [ProjectEntity] = []
    
    var body: some View {
        VStack {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                TextField("搜索项目", text: $searchText)
                    .font(.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top)
            
            if filteredProjects.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("没有找到项目")
                        .font(.headline)
                    
                    Text("请先创建一个项目")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                List(filteredProjects, id: \.id) { project in
                    Button(action: {
                        selectedProject = project
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name ?? "未命名项目")
                                    .font(.headline)
                                
                                if let status = project.status {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            fetchProjects()
        }
    }
    
    // 获取所有项目
    private func fetchProjects() {
        let request = ProjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.name, ascending: true)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            projects = try context.fetch(request)
        } catch {
            print("获取项目失败: \(error.localizedDescription)")
            projects = []
        }
    }
    
    // 过滤项目
    var filteredProjects: [ProjectEntity] {
        if searchText.isEmpty {
            return projects
        } else {
            return projects.filter {
                $0.name?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

// MARK: - 添加信息编辑视图
struct CommonInfoEditView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: CommonInfoManager
    let info: CommonInfoEntity
    
    @State private var title: String
    @State private var tag: String
    @State private var content: String
    @State private var selectedType: CommonInfoType
    
    // 标签选项
    let tagOptions = ["银行账户", "发票", "地址", "常用供应商", "其他"]
    
    init(manager: CommonInfoManager, info: CommonInfoEntity) {
        self.manager = manager
        self.info = info
        // 使用明确的类型和下划线前缀
        _title = State<String>(initialValue: info.title ?? "")
        _tag = State<String>(initialValue: info.tag ?? "")
        _content = State<String>(initialValue: info.content ?? "")
        
        let infoType = CommonInfoType(rawValue: info.type ?? "") ?? .personal
        _selectedType = State<CommonInfoType>(initialValue: infoType)
    }
    
    var body: some View {
        Form {
            Section(header: Text("信息类型")) {
                Picker("类型", selection: $selectedType) {
                    // 这里只允许在公司账户和个人账户之间切换
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
            
            // 公司账户和个人账户使用自由文本
            Section(header: Text("内容")) {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
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
                .disabled(title.isEmpty || content.isEmpty)
            }
        }
    }
    
    // 保存编辑
    private func saveChanges() {
        manager.updateInfo(
            info: info,
            title: title, 
            tag: tag, 
            content: content
        )
    }
}

struct CommonInfoManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CommonInfoManagementView()
    }
}

// MARK: - CommonInfoManager 扩展
extension CommonInfoManager {
    // 从收藏中移除项目账户（在删除账户时调用）
    func removeProjectAccountFromFavorites(_ account: AccountEntity) {
        // 获取所有与此账户相关的收藏信息
        let context = PersistenceController.shared.container.viewContext
        let request = CommonInfoEntity.fetchRequest()
        
        if let accountId = account.id?.uuidString {
            request.predicate = NSPredicate(format: "userData CONTAINS %@", accountId)
            
            do {
                let favoritedItems = try context.fetch(request)
                for item in favoritedItems {
                    if let userData = item.userData {
                        // 尝试不同的类型处理方式
                        var shouldRemove = false
                        
                        // 1. 如果userData是字符串
                        if let dataString = userData as? String {
                            shouldRemove = dataString.contains(accountId)
                        }
                        // 2. 如果userData是Data
                        else if let userData = userData as? Data {
                            if let dataString = String(data: userData, encoding: .utf8) {
                                shouldRemove = dataString.contains(accountId)
                            }
                        }
                        
                        if shouldRemove {
                            item.userData = nil
                            print("从收藏中移除账户: \(account.name ?? "")")
                        }
                    }
                }
                
                // 保存上下文
                try context.save()
            } catch {
                print("移除账户收藏失败: \(error.localizedDescription)")
            }
        }
    }
} 
