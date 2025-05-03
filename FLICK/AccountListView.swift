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
                if showManagement {
                    NavigationLink(destination: AccountManagementView(project: $project).environmentObject(projectStore)) {
                        Label("管理", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.accentColor)
                    }
                }
                Button(action: { showingAddAccount = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            if !project.accounts.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(project.accounts.prefix(3)) { account in
                            AccountRow(account: account, project: $project, editingAccount: $editingAccount)
                        }
                    }
                }
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

struct AccountRow: View {
    let account: Account
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var editingAccount: Account?
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack {
            // 背景按钮
            HStack(spacing: 0) {
                Spacer()
                
                // 编辑按钮
                Button {
                    withAnimation {
                        offset = 0
                        isSwiped = false
                    }
                    editingAccount = account
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 90, height: 90)
                }
                .background(Color.orange)
                
                // 删除按钮
                Button {
                    withAnimation {
                        offset = 0
                        isSwiped = false
                    }
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 90, height: 90)
                }
                .background(Color.red)
            }
            
            // 账户卡片内容
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(account.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(account.type.rawValue)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Label {
                    Text(account.contactName)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                }
                
                Label {
                    Text(account.contactPhone)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                }
                
                Label {
                    Text("\(account.bankName) \(formatBankAccount(account.bankAccount))")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "banknote.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            if isSwiped {
                                offset = value.translation.width - 180
                            } else {
                                offset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < 0 {
                                if -value.translation.width > 50 {
                                    offset = -180
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
        .padding(.vertical, 4)
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                withAnimation {
                    print("触发删除账户: \(account.name)")
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
    
    private func formatBankAccount(_ account: String) -> String {
        let lastFour = account.suffix(4)
        return "****\(lastFour)"
    }
} 