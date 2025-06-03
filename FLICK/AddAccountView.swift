import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Binding var project: Project
    
    @State private var name = ""
    @State private var type = AccountType.bankAccount
    @State private var bankName = ""
    @State private var bankBranch = ""
    @State private var bankAccount = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var notes = ""
    @State private var idNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("收款方名称", text: $name)
                    Picker("账户类型", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { type in
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
                        .textInputAutocapitalization(.never)
                }
                
                Section("联系方式") {
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("所属项目")
                            .font(.headline)
                        Text(project.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.systemGroupedBackground))
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { 
                        isPresented = false
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAccount()
                        isPresented = false
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        !bankName.isEmpty &&
        !bankBranch.isEmpty &&
        !bankAccount.isEmpty &&
        !contactName.isEmpty &&
        !contactPhone.isEmpty
    }
    
    private func saveAccount() {
        let newAccount = Account(
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
        
        projectStore.addAccount(to: project, account: newAccount)
    }
} 