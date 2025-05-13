import SwiftUI

struct InvoiceRow: View {
    @Binding var invoice: Invoice
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingDetail = false
    
    var body: some View {
        NavigationLink(destination: InvoiceDetailView(invoice: $invoice, project: project)) {
            InvoiceRowContent(invoice: invoice)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                // 发送删除通知
                NotificationCenter.default.post(
                    name: Notification.Name("DeleteInvoice"),
                    object: nil,
                    userInfo: ["invoice": invoice, "project": project]
                )
                } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                NotificationCenter.default.post(
                    name: Notification.Name("EditInvoice"),
                    object: nil,
                    userInfo: ["invoice": invoice]
                )
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
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

// 发票行内容组件 - 用于列表显示
struct InvoiceRowContent: View {
    let invoice: Invoice
    
    var body: some View {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.name)
                            .font(.headline)
                        Text(invoice.phone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatBankAccount(invoice.bankAccount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "¥%.2f", invoice.amount))
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text(invoice.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(invoice.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                    .background(invoice.status.color.opacity(0.2))
                    .foregroundColor(invoice.status.color)
                            .cornerRadius(4)
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