import SwiftUI

struct EditInvoiceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    let invoice: Invoice
    
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
    
    init(project: Project, invoice: Invoice) {
        self.project = project
        self.invoice = invoice
        
        // 初始化状态
        _name = State(initialValue: invoice.name)
        _phone = State(initialValue: invoice.phone)
        _idNumber = State(initialValue: invoice.idNumber)
        _bankAccount = State(initialValue: invoice.bankAccount)
        _bankName = State(initialValue: invoice.bankName)
        _date = State(initialValue: invoice.date)
        _amount = State(initialValue: String(format: "%.2f", invoice.amount))
        _category = State(initialValue: invoice.category)
        _status = State(initialValue: invoice.status)
        _dueDate = State(initialValue: invoice.dueDate)
        _notes = State(initialValue: invoice.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)
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
                    
                    DatePicker("开票截止日期", selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ), displayedComponents: .date)
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
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveInvoice()
                    }
                    .disabled(isFormInvalid)
                }
            }
        }
    }
    
    private var isFormInvalid: Bool {
        name.isEmpty || 
        phone.isEmpty || 
        idNumber.isEmpty || 
        bankAccount.isEmpty || 
        bankName.isEmpty ||
        amount.isEmpty ||
        Double(amount) == nil
    }
    
    private func saveInvoice() {
        let updatedInvoice = Invoice(
            id: invoice.id,
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date,
            amount: Double(amount) ?? 0,
            category: category,
            status: status,
            dueDate: dueDate,
            notes: notes.isEmpty ? nil : notes
        )
        projectStore.updateInvoice(updatedInvoice, in: project)
        dismiss()
    }
} 