import SwiftUI

struct EditAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Binding var project: Project
    let account: Account
    
    @State private var name: String
    @State private var type: AccountType
    @State private var bankName: String
    @State private var bankBranch: String
    @State private var bankAccount: String
    @State private var idNumber: String
    @State private var contactName: String
    @State private var contactPhone: String
    @State private var notes: String
    @State private var showingDeleteAlert = false
    
    init(isPresented: Binding<Bool>, project: Binding<Project>, account: Account) {
        self._isPresented = isPresented
        self._project = project
        self.account = account
        
        // 初始化状态
        _name = State(initialValue: account.name)
        _type = State(initialValue: account.type)
        _bankName = State(initialValue: account.bankName)
        _bankBranch = State(initialValue: account.bankBranch)
        _bankAccount = State(initialValue: account.bankAccount)
        _idNumber = State(initialValue: account.idNumber ?? "")
        _contactName = State(initialValue: account.contactName)
        _contactPhone = State(initialValue: account.contactPhone)
        _notes = State(initialValue: account.notes ?? "")
    }
    
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
                        .textInputAutocapitalization(.characters)
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
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Text("删除账户")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updatedAccount = Account(
                            id: account.id,
                            name: name,
                            type: type,
                            bankName: bankName,
                            bankBranch: bankBranch,
                            bankAccount: bankAccount,
                            contactName: contactName,
                            contactPhone: contactPhone,
                            notes: notes.isEmpty ? nil : notes
                        )
                        projectStore.updateAccount(updatedAccount, in: project)
                        isPresented = false
                    }
                    .disabled(isFormInvalid)
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    projectStore.deleteAccount(account, from: project)
                    isPresented = false
                }
            } message: {
                Text("确定要删除这个账户吗？此操作不可撤销。")
            }
        }
    }
    
    private var isFormInvalid: Bool {
        name.isEmpty ||
        bankName.isEmpty ||
        bankBranch.isEmpty ||
        bankAccount.isEmpty ||
        contactName.isEmpty ||
        contactPhone.isEmpty
    }
} 