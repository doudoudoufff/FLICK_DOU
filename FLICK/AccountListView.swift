import SwiftUI

struct AccountListView: View {
    @Binding var project: Project
    @State private var showingAddAccount = false
    @State private var selectedAccount: Account?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("账户管理")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddAccount = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if !project.accounts.isEmpty {
                ForEach(project.accounts) { account in
                    AccountRow(account: account)
                        .onTapGesture {
                            selectedAccount = account
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
        }
        .sheet(item: $selectedAccount) { account in
            AccountDetailView(account: account, project: $project)
        }
    }
}

struct AccountRow: View {
    let account: Account
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：名称和类型
                HStack(spacing: 8) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(account.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 第二行：联系人信息
                Text("\(account.contactName) \(account.contactPhone)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .imageScale(.small)
        }
        .padding(.vertical, 8)
    }
} 