import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddInvoice = false
    @State private var editingInvoice: Invoice? = nil
    
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

struct InvoiceRow: View {
    let invoice: Invoice
    let project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var editingInvoice: Invoice?
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    @State private var showingEditSheet = false
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
                    Text(invoice.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(invoice.date.chineseStyleString())
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
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
        .sheet(isPresented: $showingEditSheet) {
            EditInvoiceView(project: project, invoice: invoice)
                .environmentObject(projectStore)
        }
    }
    
    private func formatBankAccount(_ account: String) -> String {
        let lastFour = account.suffix(4)
        return "****\(lastFour)"
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