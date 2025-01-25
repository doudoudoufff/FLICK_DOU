import SwiftUI

struct InvoiceListView: View {
    @Binding var project: Project
    @State private var showingAddInvoice = false
    @State private var selectedInvoice: Invoice?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("开票信息")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddInvoice = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if !project.invoices.isEmpty {
                ForEach(project.invoices) { invoice in
                    InvoiceRow(invoice: invoice)
                        .onTapGesture {
                            selectedInvoice = invoice
                        }
                }
            } else {
                Text("暂无开票信息")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingAddInvoice) {
            AddInvoiceView(isPresented: $showingAddInvoice, project: $project)
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailView(invoice: invoice, project: $project)
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.name)
                    .font(.headline)
                Spacer()
                Text(invoice.date.chineseStyleString())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 第一行：姓名和身份证
            HStack(spacing: 8) {
                Text(invoice.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(invoice.idNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 第二行：银行信息
            Text("\(invoice.bankName) \(formatBankAccount(invoice.bankAccount))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // 格式化银行卡号，只显示后四位
    private func formatBankAccount(_ account: String) -> String {
        let lastFour = account.suffix(4)
        return "****\(lastFour)"
    }
}

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    let invoice: Invoice
    @Binding var project: Project
    
    var body: some View {
        NavigationView {
            List {
                Section("个人信息") {
                    InvoiceDetailRow(label: "姓名", text: invoice.name)
                    InvoiceDetailRow(label: "联系电话", text: invoice.phone)
                    InvoiceDetailRow(label: "身份证号", text: invoice.idNumber)
                }
                
                Section("银行信息") {
                    InvoiceDetailRow(label: "开户行", text: invoice.bankName)
                    InvoiceDetailRow(label: "账号", text: invoice.bankAccount)
                }
                
                Section("记录信息") {
                    InvoiceDetailRow(label: "记录日期", text: invoice.date.chineseStyleString())
                }
            }
            .navigationTitle("开票信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditInvoiceView(
                isPresented: $showingEditSheet,
                project: $project,
                invoice: invoice
            )
            .onDisappear {
                // 如果发票被删除，关闭详情视图
                if !project.invoices.contains(where: { $0.id == invoice.id }) {
                    dismiss()
                }
            }
        }
    }
}

struct InvoiceDetailRow: View {
    let label: String
    let text: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(text)
        }
    }
} 