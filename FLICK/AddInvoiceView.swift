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
        !bankName.isEmpty
    }
    
    private func saveInvoice() {
        let invoice = Invoice(
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date
        )
        
        // 使用 ProjectStore 添加发票
        projectStore.addInvoice(invoice, to: project)
        dismiss()
    }
} 