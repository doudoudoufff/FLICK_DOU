import SwiftUI

struct AccountListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    var showManagement: Bool = false
    @State private var showingAddAccount = false
    @State private var editingAccount: Account? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("账户信息")
                    .font(.headline)
                
                Spacer()
                
                // 胶囊形UI按钮设计
                HStack(spacing: 8) {
                    // 添加账户按钮
                    Button(action: { showingAddAccount = true }) {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    // 管理按钮
                    if showManagement {
                        NavigationLink(destination: AccountManagementView(project: $project).environmentObject(projectStore)) {
                            Label("管理", systemImage: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundColor(.accentColor)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            if !project.accounts.isEmpty {
                List {
                    ForEach(project.accounts.prefix(3)) { account in
                        NavigationLink(destination: AccountDetailView(account: account, project: $project)) {
                            AccountRowContent(account: account)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                withAnimation {
                                    projectStore.deleteAccount(account, from: project)
                                    // 确保视图更新
                                    if let updatedProject = projectStore.projects.first(where: { $0.id == project.id }) {
                                        project = updatedProject
                                    }
                                }
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
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(project.accounts.prefix(3).count) * 90, 270)) // 调整为与发票相同的行高
                .background(Color.clear)
                .scrollContentBackground(.hidden)
            } else {
                Text("暂无账户信息")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView(isPresented: $showingAddAccount, project: $project)
                .environmentObject(projectStore)
        }
        .sheet(item: $editingAccount) { account in
            EditAccountView(isPresented: .constant(true), project: $project, account: account)
                .environmentObject(projectStore)
        }
    }
}

// 账户行内容组件 - 用于列表显示
struct AccountRowContent: View {
    let account: Account
    
    var body: some View {
        HStack {
            // 左侧信息
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                Text(account.contactName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatBankAccount(account.bankAccount))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 右侧信息
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                Text(account.bankName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(account.contactPhone)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private func formatBankAccount(_ account: String) -> String {
        let lastFour = account.suffix(4)
        return "****\(lastFour)"
    }
}

