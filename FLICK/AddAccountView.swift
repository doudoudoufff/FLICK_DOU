import SwiftUI

struct AddAccountView: View {
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var name = ""
    @State private var type = Account.AccountType.artist
    @State private var bankName = ""
    @State private var bankBranch = ""
    @State private var bankAccount = ""
    @State private var idNumber = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("收款方名称", text: $name)
                    Picker("账户类型", selection: $type) {
                        ForEach(Account.AccountType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("银行信息") {
                    TextField("开户行", text: $bankName)
                    TextField("支行", text: $bankBranch)
                    TextField("账号", text: $bankAccount)
                        .keyboardType(.numberPad)
                    TextField("身份证号（选填）", text: $idNumber)
                        .textInputAutocapitalization(.characters)
                }
                
                Section("联系方式") {
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.numberPad)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let account = Account(
                            name: name,
                            type: type,
                            bankName: bankName,
                            bankBranch: bankBranch,
                            bankAccount: bankAccount,
                            idNumber: idNumber.isEmpty ? nil : idNumber,
                            contactName: contactName,
                            contactPhone: contactPhone,
                            notes: notes.isEmpty ? nil : notes
                        )
                        // 添加账户到项目
                        project.accounts.append(account)
                        isPresented = false
                    }
                    .disabled(name.isEmpty || bankName.isEmpty || bankAccount.isEmpty || contactName.isEmpty || contactPhone.isEmpty)
                }
            }
        }
    }
} 