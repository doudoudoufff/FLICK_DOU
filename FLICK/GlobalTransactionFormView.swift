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
    @State private var selectedProjectIndex = 0
    
    // 自定义分类
    @State private var showingExpenseTypeSheet = false
    @State private var showingGroupSheet = false
    @State private var newTypeName = ""
    
    // 表单验证
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 计算属性：获取当前项目
    private var currentProject: Project {
        guard !projectStore.projects.isEmpty else {
            return Project(name: "默认项目")
        }
        return projectStore.projects[selectedProjectIndex]
    }
    
    // 当前项目的费用类型和组别
    private var expenseTypes: [String] {
        currentProject.customExpenseTypes.isEmpty ? ExpenseType.defaults : currentProject.customExpenseTypes
    }
    
    private var groupTypes: [String] {
        currentProject.customGroupTypes.isEmpty ? GroupType.defaults : currentProject.customGroupTypes
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
                // 选择项目
                Section(header: Text("选择项目")) {
                    if projectStore.projects.isEmpty {
                        Text("暂无项目")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("项目", selection: $selectedProjectIndex) {
                            ForEach(0..<projectStore.projects.count, id: \.self) { index in
                                Text(projectStore.projects[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProjectIndex) { _ in
                            // 切换项目时更新费用类型和组别，如果不在新项目的可选范围内
                            updateExpenseTypeAndGroup()
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
                Section(header: Text("交易类型")) {
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
                selectedProjectIndex = 0
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
        let availableTypes = currentProject.customExpenseTypes.isEmpty ? 
            ExpenseType.defaults : currentProject.customExpenseTypes
            
        let availableGroups = currentProject.customGroupTypes.isEmpty ?
            GroupType.defaults : currentProject.customGroupTypes
            
        // 确保选择的费用类型和组别在新项目的可选范围内
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
        guard !projectStore.projects.isEmpty else { return }
        
        // 获取当前选择的项目
        var updatedProject = currentProject
        
        if isExpenseType {
            // 添加费用类型
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
        
        // 验证有项目可选
        guard !projectStore.projects.isEmpty else {
            alertMessage = "没有可用的项目，请先创建项目"
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
        var project = currentProject
        projectStore.addTransaction(to: project, transaction: transaction)
        
        // 直接添加到project的transactions数组，确保视图立即更新
        project.transactions.append(transaction)
        
        // 关闭表单
        dismiss()
    }
}

#Preview {
    GlobalTransactionFormView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 