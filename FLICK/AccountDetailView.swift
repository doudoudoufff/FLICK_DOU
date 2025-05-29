import SwiftUI

struct AccountDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingEditSheet = false
    @State private var copiedMessage = ""
    @State private var showingCopiedAlert = false
    let account: Account
    @Binding var project: Project
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 主要信息卡片
                mainInfoCard
                
                // 操作按钮
                actionButtons
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("账户详情")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        showingEditSheet = true
                }
            }
        }
        .alert("已复制", isPresented: $showingCopiedAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(copiedMessage)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(
                isPresented: $showingEditSheet,
                project: $project,
                account: account
            )
            .environmentObject(projectStore)
            .onDisappear {
                // 如果账户被删除，关闭详情视图
                if !project.accounts.contains(where: { $0.id == account.id }) {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - 主要信息卡片
    private var mainInfoCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题区域
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(account.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("所属项目: \(project.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 类型标签
                    Text(account.type.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(tagColor(for: account.type.rawValue).opacity(0.15))
                        )
                        .foregroundColor(tagColor(for: account.type.rawValue))
                        .overlay(
                            Capsule()
                                .stroke(tagColor(for: account.type.rawValue).opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            Divider()
            
            // 所有信息统一排列
            VStack(alignment: .leading, spacing: 16) {
                // 银行信息
                if !account.bankName.isEmpty || !account.bankBranch.isEmpty || !account.bankAccount.isEmpty || !(account.idNumber?.isEmpty ?? true) {
                    infoSection(title: "银行信息", icon: "building.columns", color: .blue) {
                        VStack(spacing: 12) {
                            if !account.bankName.isEmpty {
                                infoRow(label: "开户行", value: account.bankName, icon: "building.2")
                            }
                            if !account.bankBranch.isEmpty {
                                infoRow(label: "支行", value: account.bankBranch, icon: "mappin.and.ellipse")
                            }
                            if !account.bankAccount.isEmpty {
                                infoRow(label: "账号", value: account.bankAccount, icon: "creditcard", isCopyable: true)
                            }
                            if let idNumber = account.idNumber, !idNumber.isEmpty {
                                infoRow(label: "身份证号", value: idNumber, icon: "person.text.rectangle", isCopyable: true)
                            }
                        }
                    }
                    
                    Divider()
                }
                
                // 联系信息
                if !account.contactName.isEmpty || !account.contactPhone.isEmpty {
                    infoSection(title: "联系信息", icon: "person.circle", color: .green) {
                        VStack(spacing: 12) {
                            if !account.contactName.isEmpty {
                                infoRow(label: "联系人", value: account.contactName, icon: "person")
                            }
                            if !account.contactPhone.isEmpty {
                                infoRow(label: "联系电话", value: account.contactPhone, icon: "phone", isCopyable: true, isPhoneNumber: true)
                            }
                        }
                    }
                }
                
                // 备注信息（如果有）
                if let notes = account.notes, !notes.isEmpty {
                    if !account.contactName.isEmpty || !account.contactPhone.isEmpty {
                        Divider()
                    }
                    
                    infoSection(title: "备注信息", icon: "note.text", color: .orange) {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6).opacity(0.5))
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 信息分组
    private func infoSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content()
        }
    }
    
    // MARK: - 信息行
    private func infoRow(
        label: String,
        value: String,
        icon: String,
        isCopyable: Bool = false,
        isPhoneNumber: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if value.isEmpty {
                    Text("未设置")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.7))
                        .italic()
                } else {
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                if isCopyable && !value.isEmpty {
                    Button(action: { copyText(value) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if isPhoneNumber && !value.isEmpty {
                    Button(action: { callPhoneNumber(value) }) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 复制所有信息
            Button(action: copyAllInfo) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .medium))
                    Text("复制信息")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            
            // 拨打电话（如果有电话号码）
            if !account.contactPhone.isEmpty {
                Button(action: { callPhoneNumber(account.contactPhone) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone")
                            .font(.system(size: 16, weight: .medium))
                        Text("拨打电话")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    private func copyAllInfo() {
        let content = """
        账户名称: \(account.name)
        账户类型: \(account.type.rawValue)
        所属项目: \(project.name)
        
        银行信息:
        开户行: \(account.bankName)
        支行: \(account.bankBranch)
        账号: \(account.bankAccount)
        身份证号: \(account.idNumber ?? "")
        
        联系信息:
        联系人: \(account.contactName)
        联系电话: \(account.contactPhone)
        
        备注: \(account.notes ?? "")
        """
        
        UIPasteboard.general.string = content
        copiedMessage = "账户信息已复制到剪贴板"
        showingCopiedAlert = true
    }
    
    private func copyText(_ text: String) {
        UIPasteboard.general.string = text
        copiedMessage = "已复制: \(text)"
        showingCopiedAlert = true
    }
    
    private func callPhoneNumber(_ phoneNumber: String) {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let url = URL(string: "tel://\(cleanedNumber)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
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

// 保留原有的 AccountDetailRow 以防其他地方使用
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