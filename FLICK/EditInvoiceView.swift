import SwiftUI

struct EditInvoiceView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var invoice: Invoice
    let project: Project
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var phone: String
    @State private var idNumber: String
    @State private var bankAccount: String
    @State private var bankName: String
    @State private var date: Date
    @State private var amount: String
    @State private var category: Invoice.Category
    @State private var status: Invoice.Status
    @State private var dueDate: Date?
    @State private var notes: String
    // 增值税发票特有字段
    @State private var invoiceCode: String
    @State private var invoiceNumber: String
    @State private var sellerName: String
    @State private var sellerTaxNumber: String
    @State private var sellerAddress: String
    @State private var sellerBankInfo: String
    @State private var buyerAddress: String
    @State private var buyerBankInfo: String
    @State private var goodsText: String
    @State private var totalAmount: String
    
    init(invoice: Binding<Invoice>, project: Project, isPresented: Binding<Bool>) {
        self._invoice = invoice
        self.project = project
        self._isPresented = isPresented
        let value = invoice.wrappedValue
        _name = State(initialValue: value.name)
        _phone = State(initialValue: value.phone)
        _idNumber = State(initialValue: value.idNumber)
        _bankAccount = State(initialValue: value.bankAccount)
        _bankName = State(initialValue: value.bankName)
        _date = State(initialValue: value.date)
        _amount = State(initialValue: String(format: "%.2f", value.amount))
        _category = State(initialValue: value.category)
        _status = State(initialValue: value.status)
        _dueDate = State(initialValue: value.dueDate)
        _notes = State(initialValue: value.notes ?? "")
        _invoiceCode = State(initialValue: value.invoiceCode ?? "")
        _invoiceNumber = State(initialValue: value.invoiceNumber ?? "")
        _sellerName = State(initialValue: value.sellerName ?? "")
        _sellerTaxNumber = State(initialValue: value.sellerTaxNumber ?? "")
        _sellerAddress = State(initialValue: value.sellerAddress ?? "")
        _sellerBankInfo = State(initialValue: value.sellerBankInfo ?? "")
        _buyerAddress = State(initialValue: value.buyerAddress ?? "")
        _buyerBankInfo = State(initialValue: value.buyerBankInfo ?? "")
        _goodsText = State(initialValue: value.goodsList?.joined(separator: ", ") ?? "")
        _totalAmount = State(initialValue: value.totalAmount != nil ? String(format: "%.2f", value.totalAmount!) : "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("姓名")
                            .foregroundColor(.primary)
                        Text("*")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    TextField("请输入姓名", text: $name)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.numberPad)
                    TextField("身份证号码", text: $idNumber)
                        .textInputAutocapitalization(.characters)
                }
                Section("银行信息") {
                    TextField("银行卡账号", text: $bankAccount)
                        .keyboardType(.numberPad)
                    TextField("开户行", text: $bankName)
                }
                Section("增值税发票信息") {
                    TextField("发票代码", text: $invoiceCode)
                    TextField("发票号码", text: $invoiceNumber)
                    TextField("销售方名称", text: $sellerName)
                    TextField("销售方纳税人识别号", text: $sellerTaxNumber)
                    TextField("销售方地址电话", text: $sellerAddress)
                    TextField("销售方开户行及账号", text: $sellerBankInfo)
                    TextField("购买方地址电话", text: $buyerAddress)
                    TextField("购买方开户行及账号", text: $buyerBankInfo)
                    TextField("商品名称列表(用逗号分隔)", text: $goodsText)
                    TextField("价税合计", text: $totalAmount)
                        .keyboardType(.decimalPad)
                }
                Section("开票信息") {
                    TextField("开票金额", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("开票类别", selection: $category) {
                        ForEach(Invoice.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    Picker("开票状态", selection: $status) {
                        ForEach(Invoice.Status.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                    DatePicker("开票截止日期", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: .date)
                }
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("编辑开票信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveInvoice() }
                    .disabled(isFormInvalid)
                }
            }
        }
    }
    private var isFormInvalid: Bool {
        name.isEmpty
    }
    private func saveInvoice() {
        // 转换金额数据类型
        var amountValue: Double = 0
        if !amount.isEmpty {
            let cleanAmount = amount.filter { "0123456789.".contains($0) }
            amountValue = Double(cleanAmount) ?? 0
        }
        var totalAmountValue: Double? = nil
        if !totalAmount.isEmpty {
            let cleanTotal = totalAmount.filter { "0123456789.".contains($0) }
            totalAmountValue = Double(cleanTotal)
        }
        var goodsArray: [String]? = nil
        if !goodsText.isEmpty {
            goodsArray = goodsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        let updatedInvoice = Invoice(
            id: invoice.id,
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date,
            amount: amountValue,
            category: category,
            status: status,
            dueDate: dueDate,
            notes: notes.isEmpty ? nil : notes,
            attachments: invoice.attachments,
            invoiceCode: invoiceCode.isEmpty ? nil : invoiceCode,
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            sellerName: sellerName.isEmpty ? nil : sellerName,
            sellerTaxNumber: sellerTaxNumber.isEmpty ? nil : sellerTaxNumber,
            sellerAddress: sellerAddress.isEmpty ? nil : sellerAddress,
            sellerBankInfo: sellerBankInfo.isEmpty ? nil : sellerBankInfo,
            buyerAddress: buyerAddress.isEmpty ? nil : buyerAddress,
            buyerBankInfo: buyerBankInfo.isEmpty ? nil : buyerBankInfo,
            goodsList: goodsArray,
            totalAmount: totalAmountValue
        )
        invoice = updatedInvoice
        projectStore.updateInvoice(updatedInvoice, in: project)
        isPresented = false
    }
} 