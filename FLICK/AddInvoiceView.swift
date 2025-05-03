import SwiftUI

struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    
    @State private var name = ""
    @State private var phone = ""
    @State private var idNumber = ""
    @State private var bankAccount = ""
    @State private var bankName = ""
    @State private var date = Date()
    @State private var amount = ""
    @State private var category = Invoice.Category.other
    @State private var status = Invoice.Status.pending
    @State private var dueDate: Date? = nil
    @State private var notes = ""
    
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
            .navigationTitle("添加开票信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveInvoice()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && 
        !phone.isEmpty && 
        !idNumber.isEmpty && 
        !bankAccount.isEmpty && 
        !bankName.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil
    }
    
    private func saveInvoice() {
        let invoice = Invoice(
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
        
        projectStore.addInvoice(invoice, to: project)
        dismiss()
    }
} 