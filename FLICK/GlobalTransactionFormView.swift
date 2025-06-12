import SwiftUI
import PhotosUI

struct GlobalTransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @State private var isPresented = true
    
    // 交易记录数据
    @State private var transactionId = UUID()
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var expenseType: String = "未分类"
    @State private var group: String = "未分类"
    @State private var transactionType: TransactionType = .expense
    
    // 附件图片
    @State private var attachmentImage: UIImage? = nil
    @State private var imageSelection: PhotosPickerItem? = nil
    
    // 项目选择
    @State private var selectedProjectId: UUID? = nil
    
    // 自定义分类
    @State private var showingExpenseTypeSheet = false
    @State private var showingGroupSheet = false
    @State private var newTypeName = ""
    @State private var showingCreateProjectSheet = false
    
    // 表单验证
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 计算属性：获取当前项目
    private var currentProject: Project {
        if let id = selectedProjectId, let project = projectStore.projects.first(where: { $0.id == id }) {
            return project
        } else if !projectStore.projects.isEmpty {
            // 如果没有选择项目但有可用项目，则选择第一个
            return projectStore.projects[0]
        } else {
            return Project(name: "默认项目")
        }
    }
    
    // 获取所有费用类型选项
    var expenseTypeOptions: [String] {
        return CustomTagManager.shared.getAllExpenseTypes()
    }
    
    // 获取所有组别选项
    var groupOptions: [String] {
        return CustomTagManager.shared.getAllGroupTypes()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Button("取消") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("记一笔账")
                    .font(.headline)
                
                Spacer()
                
                Button("添加") {
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
                // 交易类型选择
                Section {
                    HStack(spacing: 0) {
                        Button(action: {
                            print("切换到支出，当前类型: \(transactionType)")
                            transactionType = .expense
                            print("切换后类型: \(transactionType)")
                        }) {
                            VStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                Text("支出")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(transactionType == .expense ? Color.red.opacity(0.9) : Color(.systemGray5))
                            .foregroundColor(transactionType == .expense ? .white : .primary)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                            .frame(width: 10)
                        
                        Button(action: {
                            print("切换到收入，当前类型: \(transactionType)")
                            transactionType = .income
                            print("切换后类型: \(transactionType)")
                        }) {
                            VStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 20))
                                Text("收入")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(transactionType == .income ? Color.green.opacity(0.9) : Color(.systemGray5))
                            .foregroundColor(transactionType == .income ? .white : .primary)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
                
                // 选择项目
                Section(header: Text("选择项目")) {
                    if projectStore.projects.isEmpty {
                        HStack {
                        Text("暂无项目")
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("创建项目") {
                                showingCreateProjectSheet = true
                            }
                            .foregroundColor(.accentColor)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(projectStore.projects) { proj in
                                    Button(action: {
                                        selectedProjectId = proj.id
                                        // 切换项目时更新费用类型和组别
                            updateExpenseTypeAndGroup()
                                    }) {
                                        Text(proj.name)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedProjectId == proj.id ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(selectedProjectId == proj.id ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                                
                                Button(action: { showingCreateProjectSheet = true }) {
                                    Text("＋ 新建项目")
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // 基本信息
                Section(header: Text("基本信息")) {
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
                Section(header: Text("分类信息")) {
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
                            .padding(.vertical, 8)
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
                                ForEach(groupOptions, id: \.self) { group in
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
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // 附件
                Section(header: Text("附件")) {
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
        .onAppear {
            // 默认选择最近的项目（假设列表第一个是最近的）
            if !projectStore.projects.isEmpty {
                selectedProjectId = projectStore.projects[0].id
            }
        }
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
        .sheet(isPresented: $showingCreateProjectSheet) {
            AddProjectView(isPresented: $showingCreateProjectSheet)
                .environmentObject(projectStore)
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
    
    // 切换项目时更新费用类型和组别
    private func updateExpenseTypeAndGroup() {
        let availableTypes = CustomTagManager.shared.getAllExpenseTypes()
        let availableGroups = CustomTagManager.shared.getAllGroupTypes()
            
        // 确保选择的费用类型和组别在可选范围内
        if !availableTypes.contains(expenseType) {
            expenseType = "未分类"
        }
        
        if !availableGroups.contains(group) {
            group = "未分类"
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
            if !CustomTagManager.shared.getAllExpenseTypes().contains(newTypeName) {
                CustomTagManager.shared.addExpenseType(newTypeName)
                expenseType = newTypeName
            }
            showingExpenseTypeSheet = false
        } else {
            // 添加组别
            if !CustomTagManager.shared.getAllGroupTypes().contains(newTypeName) {
                CustomTagManager.shared.addGroupType(newTypeName)
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
        
        // 验证有项目可选
        guard !projectStore.projects.isEmpty else {
            alertMessage = "没有可用的项目，请先创建项目"
            showingAlert = true
            return
        }
        
        let finalAmount = transactionType == .expense ? -abs(amountValue) : abs(amountValue)
        
        // 创建交易记录对象
        var transaction = Transaction(
            id: transactionId,
            name: name,
            amount: finalAmount,
            date: date,
            expenseType: expenseType,
            group: group,
            transactionType: transactionType
        )
        
        // 处理附件
        if let image = attachmentImage, let imageData = image.jpegData(compressionQuality: 0.7) {
            transaction.attachmentData = imageData
        }
        
        // 保存到数据库 - 只调用一次，避免重复添加
        let project = currentProject
        projectStore.addTransaction(to: project, transaction: transaction)
        
        // 关闭表单
        dismiss()
    }
}

#Preview {
    GlobalTransactionFormView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 