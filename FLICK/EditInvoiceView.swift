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
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("个人信息") {
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
                
                Section("记录信息") {
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
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
                        let updatedInvoice = Invoice(
                            id: invoice.id,
                            name: name,
                            phone: phone,
                            idNumber: idNumber,
                            bankAccount: bankAccount,
                            bankName: bankName,
                            date: date
                        )
                        projectStore.updateInvoice(updatedInvoice, in: project)
                        dismiss()
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
        bankName.isEmpty
    }
} 