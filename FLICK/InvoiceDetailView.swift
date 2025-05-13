import SwiftUI

struct InvoiceDetailView: View {
    @Binding var invoice: Invoice
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @State private var showCopyToast = false
    @State private var copyToastMessage = ""
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    private func copyToClipboard(_ text: String, message: String) {
        UIPasteboard.general.string = text
        copyToastMessage = message
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyToast = false
        }
    }
    
    @ViewBuilder
    private var basicSection: some View {
        Section(header: Text("基本信息")) {
            DetailRow(title: "姓名", content: invoice.name, copyable: true, onCopy: { copyToClipboard(invoice.name, message: "已复制：姓名") })
            DetailRow(title: "联系电话", content: invoice.phone, copyable: true, onCopy: { copyToClipboard(invoice.phone, message: "已复制：联系电话") })
            DetailRow(title: "身份证号码", content: invoice.idNumber, copyable: true, onCopy: { copyToClipboard(invoice.idNumber, message: "已复制：身份证号码") })
        }
    }
    
    @ViewBuilder
    private var bankSection: some View {
        Section(header: Text("银行信息")) {
            DetailRow(title: "银行卡账号", content: invoice.bankAccount, copyable: true, onCopy: { copyToClipboard(invoice.bankAccount, message: "已复制：银行卡账号") })
            DetailRow(title: "开户行", content: invoice.bankName, copyable: true, onCopy: { copyToClipboard(invoice.bankName, message: "已复制：开户行") })
        }
    }
    
    @ViewBuilder
    private var invoiceSection: some View {
        Section(header: Text("增值税发票信息")) {
            DetailRow(title: "发票代码", content: invoice.invoiceCode ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.invoiceCode ?? "--", message: "已复制：发票代码") })
            DetailRow(title: "发票号码", content: invoice.invoiceNumber ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.invoiceNumber ?? "--", message: "已复制：发票号码") })
            DetailRow(title: "销售方名称", content: invoice.sellerName ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.sellerName ?? "--", message: "已复制：销售方名称") })
            DetailRow(title: "销售方纳税人识别号", content: invoice.sellerTaxNumber ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.sellerTaxNumber ?? "--", message: "已复制：销售方纳税人识别号") })
            DetailRow(title: "销售方地址电话", content: invoice.sellerAddress ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.sellerAddress ?? "--", message: "已复制：销售方地址电话") })
            DetailRow(title: "销售方开户行及账号", content: invoice.sellerBankInfo ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.sellerBankInfo ?? "--", message: "已复制：销售方开户行及账号") })
            DetailRow(title: "购买方地址电话", content: invoice.buyerAddress ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.buyerAddress ?? "--", message: "已复制：购买方地址电话") })
            DetailRow(title: "购买方开户行及账号", content: invoice.buyerBankInfo ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.buyerBankInfo ?? "--", message: "已复制：购买方开户行及账号") })
            VStack(alignment: .leading, spacing: 4) {
                Text("商品名称").foregroundColor(.secondary)
                if let goodsList = invoice.goodsList, !goodsList.isEmpty {
                    ForEach(goodsList, id: \.self) { item in
                        Text(item).padding(.leading, 8)
                    }
                } else {
                    Text("--").padding(.leading, 8)
                }
            }
            .padding(.vertical, 4)
            DetailRow(title: "价税合计", content: invoice.totalAmount.map { String(format: "%.2f", $0) } ?? "--", copyable: true, onCopy: { copyToClipboard(invoice.totalAmount.map { String(format: "%.2f", $0) } ?? "--", message: "已复制：价税合计") })
        }
    }
    
    @ViewBuilder
    private var billingSection: some View {
        Section(header: Text("开票信息")) {
            DetailRow(title: "开票金额", content: String(format: "%.2f", invoice.amount), copyable: true, onCopy: { copyToClipboard(String(format: "%.2f", invoice.amount), message: "已复制：开票金额") })
            DetailRow(title: "开票类别", content: invoice.category.rawValue)
            DetailRow(title: "开票状态", content: invoice.status.rawValue)
            DetailRow(title: "记录日期", content: invoice.date.formatted(date: .abbreviated, time: .omitted))
            if let dueDate = invoice.dueDate {
                DetailRow(title: "开票截止日期", content: dueDate.formatted(date: .abbreviated, time: .omitted))
            }
            if let remarks = invoice.notes {
                DetailRow(title: "备注", content: remarks, copyable: true, onCopy: { copyToClipboard(remarks, message: "已复制：备注") })
            }
        }
    }
    
    @ViewBuilder
    private var copyAllSection: some View {
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
    
    var body: some View {
        NavigationStack {
            List {
                basicSection
                bankSection
                invoiceSection
                billingSection
                copyAllSection
            }
            .navigationTitle("发票详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") { showingEditSheet = true }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    projectStore.deleteInvoice(invoice, from: project)
                    dismiss()
                }
            } message: {
                Text("确定要删除这条开票信息吗？此操作不可撤销。")
            }
            .sheet(isPresented: $showingEditSheet) {
                EditInvoiceView(invoice: $invoice, project: project, isPresented: $showingEditSheet)
                    .environmentObject(projectStore)
            }
            .overlay(
                Group {
                    if showCopyToast {
                        VStack {
                            Spacer()
                            Text(copyToastMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showCopyToast)
                    }
                }
            )
        }
    }
    
    // 通用明细行组件
    private struct DetailRow: View {
        let title: String
        let content: String
        var copyable: Bool = false
        var onCopy: (() -> Void)? = nil
        var body: some View {
            HStack {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                Text(content)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                if copyable && !content.isEmpty, let onCopy = onCopy {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // 新增一键复制所有发票信息的函数
    private func copyAllInfo() {
        var info = """
        【姓名】\(invoice.name)
        【联系电话】\(invoice.phone)
        【身份证号码】\(invoice.idNumber)
        【银行卡账号】\(invoice.bankAccount)
        【开户行】\(invoice.bankName)
        【开票金额】\(String(format: "%.2f", invoice.amount))
        【开票类别】\(invoice.category.rawValue)
        【开票状态】\(invoice.status.rawValue)
        【记录日期】\(invoice.date.formatted(date: .abbreviated, time: .omitted))
        """
        
        if let dueDate = invoice.dueDate {
            info += "\n【开票截止日期】\(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        
        if let notes = invoice.notes {
            info += "\n【备注】\(notes)"
        }
        
        if let invoiceCode = invoice.invoiceCode {
            info += "\n【发票代码】\(invoiceCode)"
        }
        
        if let invoiceNumber = invoice.invoiceNumber {
            info += "\n【发票号码】\(invoiceNumber)"
        }
        
        if let totalAmount = invoice.totalAmount {
            info += "\n【价税合计】\(String(format: "%.2f", totalAmount))"
                }
        
                if let sellerName = invoice.sellerName {
            info += "\n【销售方名称】\(sellerName)"
                }
        
                if let sellerTaxNumber = invoice.sellerTaxNumber {
            info += "\n【销售方税号】\(sellerTaxNumber)"
                }
        
                if let sellerAddress = invoice.sellerAddress {
            info += "\n【销售方地址电话】\(sellerAddress)"
                }
        
                if let sellerBankInfo = invoice.sellerBankInfo {
            info += "\n【销售方银行信息】\(sellerBankInfo)"
                }
        
                if let buyerAddress = invoice.buyerAddress {
            info += "\n【购买方地址电话】\(buyerAddress)"
                }
        
                if let buyerBankInfo = invoice.buyerBankInfo {
            info += "\n【购买方银行信息】\(buyerBankInfo)"
                }
        
                if let goodsList = invoice.goodsList, !goodsList.isEmpty {
            info += "\n【商品名称】\(goodsList.joined(separator: "，"))"
        }
        
        UIPasteboard.general.string = info
        copyToClipboard(info, message: "已复制所有发票信息")
    }
}
