import SwiftUI

struct AccountManagementView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddAccount = false
    @State private var editingAccount: Account? = nil
    @State private var searchText = ""
    @State private var selectedType: AccountType? = nil
    @State private var showingFilterSheet = false

    var filteredAccounts: [Account] {
        var result = project.accounts
        if !searchText.isEmpty {
            result = result.filter { account in
                account.name.localizedCaseInsensitiveContains(searchText) ||
                account.contactName.localizedCaseInsensitiveContains(searchText) ||
                account.contactPhone.contains(searchText)
            }
        }
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 统计卡片区
            HStack(spacing: 16) {
                StatCard(
                    title: "账户总数",
                    value: "\(filteredAccounts.count)",
                    color: .blue,
                    icon: "person.3.fill"
                )
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Divider().padding(.bottom, 8)
            // 搜索与筛选区
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索账户信息", text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                Button(action: { showingFilterSheet = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            // 列表区
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredAccounts) { account in
                        AccountRow(account: account, project: $project, editingAccount: $editingAccount)
                            .environmentObject(projectStore)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 80)
            }
            // 底部悬浮按钮
            HStack {
                Spacer()
                Button(action: { showingAddAccount = true }) {
                    Text("添加新账户")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("账户管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddAccount = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount, project: $project)
                .environmentObject(projectStore)
        }
        .sheet(item: $editingAccount) { account in
            EditAccountView(isPresented: .constant(true), project: $project, account: account)
                .environmentObject(projectStore)
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationView {
                Form {
                    Section("账户类型") {
                        Picker("选择类型", selection: $selectedType) {
                            Text("全部").tag(Optional<AccountType>.none)
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(Optional(type))
                            }
                        }
                    }
                }
                .navigationTitle("筛选")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingFilterSheet = false
                        }
                    }
                }
            }
        }
    }
} 

// 账户行组件 - 用于账户管理列表
struct AccountRow: View {
    let account: Account
    @Binding var project: Project
    @Binding var editingAccount: Account?
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationLink(destination: AccountDetailView(account: account, project: $project)) {
            AccountRowContent(account: account)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                editingAccount = account
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                withAnimation {
                    projectStore.deleteAccount(account, from: project)
                    // 确保视图更新
                    if let updatedProject = projectStore.projects.first(where: { $0.id == project.id }) {
                        project = updatedProject
                    }
                }
            }
        } message: {
            Text("确定要删除这个账户吗？此操作不可撤销。")
        }
    }
} 