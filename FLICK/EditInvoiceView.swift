import SwiftUI

struct EditInvoiceView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    let invoice: Invoice
    
    @State private var name: String
    @State private var phone: String
    @State private var idNumber: String
    @State private var bankAccount: String
    @State private var bankName: String
    @State private var date: Date
    
    init(isPresented: Binding<Bool>, project: Binding<Project>, invoice: Invoice) {
        self._isPresented = isPresented
        self._project = project
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
                
                Section {
                    Button(role: .destructive) {
                        deleteInvoice()
                    } label: {
                        Text("删除开票信息")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("编辑开票信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { updateInvoice() }
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
    
    private func updateInvoice() {
        let updatedInvoice = Invoice(
            id: invoice.id,
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date
        )
        
        if let index = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
            project.invoices[index] = updatedInvoice
        }
        
        isPresented = false
    }
    
    private func deleteInvoice() {
        if let index = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
            project.invoices.remove(at: index)
        }
        isPresented = false
    }
} 