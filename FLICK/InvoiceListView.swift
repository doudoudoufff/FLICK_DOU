import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddInvoice = false
    @State private var editingInvoice: Invoice? = nil
    @State private var showManagement = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("开票信息")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: InvoiceManagementView(project: $project).environmentObject(projectStore)) {
                    Label("管理", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.accentColor)
                }
                
                Button(action: { showingAddInvoice = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if !project.invoices.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(project.invoices) { invoice in
                            InvoiceRow(invoice: invoice, project: project, editingInvoice: $editingInvoice)
                        }
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
            AddInvoiceView(project: project)
                .environmentObject(projectStore)
        }
        .sheet(item: $editingInvoice) { invoice in
            EditInvoiceView(
                project: project,
                invoice: invoice
            )
            .environmentObject(projectStore)
        }
    }
}

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showingEditSheet = false
    let invoice: Invoice
    let project: Project
    
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditInvoiceView(project: project, invoice: invoice)
                .environmentObject(projectStore)
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