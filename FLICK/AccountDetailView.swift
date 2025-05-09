import SwiftUI

struct AccountDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var copiedMessage = ""
    @State private var showingCopiedAlert = false
    let account: Account
    @Binding var project: Project
    
    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    AccountDetailRow(label: "收款方", text: account.name, onCopy: { copyToClipboard(account.name) })
                    AccountDetailRow(label: "账户类型", text: account.type.rawValue)
                }
                
                Section("银行信息") {
                    AccountDetailRow(label: "开户行", text: account.bankName, onCopy: { copyToClipboard(account.bankName) })
                    AccountDetailRow(label: "支行", text: account.bankBranch, onCopy: { copyToClipboard(account.bankBranch) })
                    AccountDetailRow(label: "账号", text: account.bankAccount, onCopy: { copyToClipboard(account.bankAccount) })
                    if let idNumber = account.idNumber {
                        AccountDetailRow(label: "身份证号", text: idNumber, onCopy: { copyToClipboard(idNumber) })
                    }
                }
                
                Section("联系方式") {
                    AccountDetailRow(label: "联系人", text: account.contactName, onCopy: { copyToClipboard(account.contactName) })
                    AccountDetailRow(label: "联系电话", text: account.contactPhone, onCopy: { copyToClipboard(account.contactPhone) })
                }
                
                if let notes = account.notes {
                    Section("备注") {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                Section {
                    Button(action: copyAllInfo) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制所有信息")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("账户详情")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(
                isPresented: $showingEditSheet,
                project: $project,
                account: account
            )
            .onDisappear {
                // 如果账户被删除，关闭详情视图
                if !project.accounts.contains(where: { $0.id == account.id }) {
                    dismiss()
                }
            }
        }
        .alert("已复制", isPresented: $showingCopiedAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(copiedMessage)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        copiedMessage = "已复制：\(text)"
        showingCopiedAlert = true
    }
    
    private func copyAllInfo() {
        let info = """
        【收款方】\(account.name)
        【账户类型】\(account.type.rawValue)
        【开户行】\(account.bankName)
        【支行】\(account.bankBranch)
        【账号】\(account.bankAccount)
        \(account.idNumber.map { "【身份证号】\($0)\n" } ?? "")【联系人】\(account.contactName)
        【联系电话】\(account.contactPhone)
        \(account.notes.map { "【备注】\($0)" } ?? "")
        """
        
        UIPasteboard.general.string = info
        copiedMessage = "已复制所有账户信息"
        showingCopiedAlert = true
    }
}

struct AccountDetailRow: View {
    let label: String
    let text: String
    var onCopy: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(text)
            if let copy = onCopy {
                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
            }
        }
    }
} 