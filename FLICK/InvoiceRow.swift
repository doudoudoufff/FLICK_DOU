import SwiftUI

struct InvoiceRow: View {
    let invoice: Invoice
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var editingInvoice: Invoice?
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
                    editingInvoice = invoice
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
            
            // 发票卡片内容
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text(invoice.category.rawValue)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(invoice.category.color.opacity(0.2))
                                .foregroundColor(invoice.category.color)
                                .cornerRadius(4)
                            
                            Text(invoice.status.rawValue)
                                .font(.system(size: 13))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(invoice.status.color.opacity(0.2))
                                .foregroundColor(invoice.status.color)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "¥%.2f", invoice.amount))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(invoice.date.chineseStyleString())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Label {
                        Text(invoice.idNumber)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "person.text.rectangle.fill")
                            .foregroundColor(.blue)
                    }
                    
                    Label {
                        Text("\(invoice.bankName) \(formatBankAccount(invoice.bankAccount))")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if let notes = invoice.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
                    print("开始删除发票：\(invoice.name)")
                    projectStore.deleteInvoice(invoice, from: project)
                }
            }
        } message: {
            Text("确定要删除这条开票信息吗？此操作不可撤销。")
        }
    }
    
    private func formatBankAccount(_ account: String) -> String {
        let lastFour = account.suffix(4)
        return "****\(lastFour)"
    }
}

extension Invoice.Category {
    var color: Color {
        switch self {
        case .location: return .blue
        case .labor: return .orange
        case .equipment: return .purple
        case .material: return .green
        case .other: return .gray
        }
    }
}

extension Invoice.Status {
    var color: Color {
        switch self {
        case .pending: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
} 