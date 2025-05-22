import SwiftUI
import PhotosUI

struct TransactionFormView: View {
    @Binding var project: Project
    @ObservedObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    // 交易记录数据
    @State private var transactionId: UUID
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var expenseType: String = "未分类"
    @State private var group: String = "未分类"
    @State private var transactionType: TransactionType = .expense
    
    // 附件图片
    @State private var attachmentImage: UIImage? = nil
    @State private var imageSelection: PhotosPickerItem? = nil
    
    // 自定义分类
    @State private var showingExpenseTypeSheet = false
    @State private var showingGroupSheet = false
    @State private var newTypeName = ""
    
    // 表单验证
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 是否在编辑模式
    private var isEditMode: Bool
    
    // 字段列表
    private var expenseTypes: [String] {
        project.customExpenseTypes.isEmpty ? ExpenseType.defaults : project.customExpenseTypes
    }
    
    private var groupTypes: [String] {
        project.customGroupTypes.isEmpty ? GroupType.defaults : project.customGroupTypes
    }
    
    init(project: Binding<Project>, projectStore: ProjectStore, transactionToEdit: Transaction?, isPresented: Binding<Bool>) {
        self._project = project
        self.projectStore = projectStore
        self._isPresented = isPresented
        
        // 编辑模式初始化
        if let transaction = transactionToEdit {
            self.isEditMode = true
            self._transactionId = State(initialValue: transaction.id)
            self._name = State(initialValue: transaction.name)
            self._amount = State(initialValue: String(format: "%.2f", transaction.amount))
            self._date = State(initialValue: transaction.date)
            self._expenseType = State(initialValue: transaction.expenseType)
            self._group = State(initialValue: transaction.group)
            self._transactionType = State(initialValue: transaction.transactionType)
            
            // 加载附件图片
            if let attachmentData = transaction.attachmentData,
               let image = UIImage(data: attachmentData) {
                self._attachmentImage = State(initialValue: image)
            }
        } else {
            // 新建模式初始化
            self.isEditMode = false
            self._transactionId = State(initialValue: UUID())
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text(isEditMode ? "编辑交易记录" : "新建交易记录")
                    .font(.headline)
                
                Spacer()
                
                Button(isEditMode ? "保存" : "添加") {
                    saveTransaction()
                }
                .foregroundColor(.blue)
                .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // 表单内容
            Form {
                // 交易类型
                Section {
                    HStack(spacing: 10) {
                        // 支出按钮
                        Button(action: { transactionType = .expense }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                Text("支出")
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(transactionType == .expense ? Color.red : Color(.systemGray5))
                            .foregroundColor(transactionType == .expense ? .white : .gray)
                            .cornerRadius(8)
                        }
                        
                        // 收入按钮
                        Button(action: { transactionType = .income }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                Text("收入")
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(transactionType == .income ? Color.green : Color(.systemGray5))
                            .foregroundColor(transactionType == .income ? .white : .gray)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // 基本信息
                Section {
                    TextField("名称", text: $name)
                    
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(transactionType == .expense ? .red : .green)
                    }
                    
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                
                // 分类信息
                Section {
                    // 费用类型
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("费用类型")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("添加") {
                                showingExpenseTypeSheet = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TransactionCategory.categories(for: transactionType), id: \.self) { type in
                                    Button(action: {
                                        expenseType = type
                                    }) {
                                        Text(type)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(expenseType == type ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(expenseType == type ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // 组别
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("所属组别")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("添加") {
                                showingGroupSheet = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(groupTypes, id: \.self) { group in
                                    Button(action: {
                                        self.group = group
                                    }) {
                                        Text(group)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(self.group == group ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(self.group == group ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // 交易类型
                Section {
                    HStack(spacing: 10) {
                        // 支出按钮
                        Button(action: { transactionType = .expense }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                Text("支出")
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(transactionType == .expense ? Color.red : Color(.systemGray5))
                            .foregroundColor(transactionType == .expense ? .white : .gray)
                            .cornerRadius(8)
                        }
                        
                        // 收入按钮
                        Button(action: { transactionType = .income }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                Text("收入")
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(transactionType == .income ? Color.green : Color(.systemGray5))
                            .foregroundColor(transactionType == .income ? .white : .gray)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // 附件
                Section {
                    if let image = attachmentImage {
                        VStack(alignment: .leading) {
                            HStack {
                                Spacer()
                                Button("删除") {
                                    attachmentImage = nil
                                }
                                .foregroundColor(.red)
                            }
                            
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                    } else {
                        PhotosPicker(selection: $imageSelection, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text("添加图片附件")
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .onChange(of: imageSelection) { newItem in
            loadImage(from: newItem)
        }
        .onChange(of: transactionType) { _ in
            updateExpenseType()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
        .sheet(isPresented: $showingExpenseTypeSheet) {
            addCustomTypeSheet(title: "添加费用类型", isExpenseType: true)
        }
        .sheet(isPresented: $showingGroupSheet) {
            addCustomTypeSheet(title: "添加组别", isExpenseType: false)
        }
    }
    
    // 加载图片
    private func loadImage(from item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    attachmentImage = image
                }
            }
        }
    }
    
    // 更新费用类型
    private func updateExpenseType() {
        let availableTypes = TransactionCategory.categories(for: transactionType)
        if !availableTypes.contains(expenseType) {
            expenseType = "未分类"
        }
    }
    
    // 自定义类型添加表单
    private func addCustomTypeSheet(title: String, isExpenseType: Bool) -> some View {
        NavigationView {
            Form {
                Section {
                    TextField("请输入名称", text: $newTypeName)
                }
                
                Section {
                    Button("添加") {
                        addCustomType(isExpenseType: isExpenseType)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismissTypeSheet(isExpenseType: isExpenseType)
                    }
                }
            }
        }
    }
    
    // 添加自定义类型
    private func addCustomType(isExpenseType: Bool) {
        guard !newTypeName.isEmpty else { return }
        
        if isExpenseType {
            // 添加费用类型
            var updatedProject = project
            var customTypes = updatedProject.customExpenseTypes
            if !customTypes.contains(newTypeName) {
                customTypes.append(newTypeName)
                updatedProject.customExpenseTypes = customTypes
                projectStore.updateProject(updatedProject)
                expenseType = newTypeName
            }
            showingExpenseTypeSheet = false
        } else {
            // 添加组别
            var updatedProject = project
            var customTypes = updatedProject.customGroupTypes
            if !customTypes.contains(newTypeName) {
                customTypes.append(newTypeName)
                updatedProject.customGroupTypes = customTypes
                projectStore.updateProject(updatedProject)
                group = newTypeName
            }
            showingGroupSheet = false
        }
        
        newTypeName = ""
    }
    
    // 关闭添加类型表单
    private func dismissTypeSheet(isExpenseType: Bool) {
        newTypeName = ""
        if isExpenseType {
            showingExpenseTypeSheet = false
        } else {
            showingGroupSheet = false
        }
    }
    
    // 保存交易记录
    private func saveTransaction() {
        // 验证输入
        guard !name.isEmpty else {
            alertMessage = "请输入名称"
            showingAlert = true
            return
        }
        
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            alertMessage = "请输入有效的金额"
            showingAlert = true
            return
        }
        
        // 创建交易记录对象
        var transaction = Transaction(
            id: transactionId,
            name: name,
            amount: amountValue,
            date: date,
            expenseType: expenseType,
            group: group,
            transactionType: transactionType
        )
        
        // 处理附件
        if let image = attachmentImage, let imageData = image.jpegData(compressionQuality: 0.7) {
            transaction.attachmentData = imageData
        }
        
        // 保存到数据库
        if isEditMode {
            projectStore.updateTransaction(in: project, transaction: transaction)
            
            // 直接更新project的transactions数组，确保视图立即更新
            if let index = project.transactions.firstIndex(where: { $0.id == transaction.id }) {
                project.transactions[index] = transaction
            }
        } else {
            projectStore.addTransaction(to: project, transaction: transaction)
            
            // 直接添加到project的transactions数组，确保视图立即更新
            project.transactions.append(transaction)
        }
        
        // 关闭表单
        isPresented = false
    }
}

// 预览
struct TransactionFormView_Previews: PreviewProvider {
    static var previews: some View {
        let project = Project(name: "测试项目")
        let projectStore = ProjectStore(context: PersistenceController.preview.container.viewContext)
        
        return TransactionFormView(
            project: .constant(project),
            projectStore: projectStore,
            transactionToEdit: nil,
            isPresented: .constant(true)
        )
    }
} 
