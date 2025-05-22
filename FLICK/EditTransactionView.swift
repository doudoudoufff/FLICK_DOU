import SwiftUI
import PhotosUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var transaction: Transaction
    @Binding var project: Project
    @Binding var isPresented: Bool
    
    // 交易类型
    enum TransactionType {
        case expense, income
        
        var title: String {
            switch self {
            case .expense: return "支出"
            case .income: return "收入"
            }
        }
        
        var color: Color {
            switch self {
            case .expense: return .red
            case .income: return .green
            }
        }
    }
    
    @State private var transactionType: TransactionType = .expense
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var description: String = ""
    @State private var expenseType: String = "未分类"
    @State private var group: String = "未分类"
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var attachmentData: Data? = nil
    @State private var showingImagePreview: Bool = false
    @State private var showingAddExpenseType: Bool = false
    @State private var showingAddGroup: Bool = false
    @State private var newExpenseType: String = ""
    @State private var newGroup: String = ""
    @State private var isSaving: Bool = false
    
    // 错误处理
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // 获取可用的费用类型列表
    private var availableExpenseTypes: [String] {
        return TagManager.shared.getAllExpenseTypes()
    }
    
    // 获取可用的组别列表
    private var availableGroups: [String] {
        return TagManager.shared.getAllGroupTypes()
    }
    
    var body: some View {
        Form {
            // 交易类型选择
            Section {
                HStack(spacing: 0) {
                    Button(action: {
                        print("切换到支出，当前类型: \(transactionType)")
                        transactionType = .expense
                        print("切换后类型: \(transactionType)")
                        // 自动调整金额的正负值
                        if let value = Double(amount) {
                            let absValue = abs(value)
                            amount = String(format: "%.2f", absValue)
                        }
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
                    
                    Spacer()
                        .frame(width: 10)
                    
                    Button(action: {
                        print("切换到收入，当前类型: \(transactionType)")
                        transactionType = .income
                        print("切换后类型: \(transactionType)")
                        // 自动调整金额的正负值
                        if let value = Double(amount) {
                            let absValue = abs(value)
                            amount = String(format: "%.2f", absValue)
                        }
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
                }
                .padding(.vertical, 6)
            }
            
            // 当前项目信息
            Section {
                HStack {
                    Text("所属项目")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(project.name)
                        .foregroundColor(.secondary)
                }
            }
            
            // 姓名和金额（必填）
            Section("基本信息") {
                // 姓名输入
                HStack {
                    Text("姓名")
                        .foregroundColor(.primary)
                        .font(.body)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.body)
                    
                    Spacer()
                    
                    TextField("姓名", text: $name)
                        .multilineTextAlignment(.trailing)
                }
                
                // 金额输入
                HStack {
                    Text("金额")
                        .foregroundColor(.primary)
                        .font(.body)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.body)
                    
                    Spacer()
                    
                    TextField("金额", text: $amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .foregroundColor(transactionType.color)
                        .fontWeight(.semibold)
                }
                
                // 日期选择
                DatePicker(
                    selection: $date,
                    displayedComponents: [.date]
                ) {
                    HStack(spacing: 0) {
                        Text("日期")
                            .foregroundColor(.primary)
                            .font(.body)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            
            // 费用类型选择（横向滑动）
            Section(header: HStack {
                Text("费用类型")
                Spacer()
                Button("添加") {
                    showingAddExpenseType = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["未分类"] + availableExpenseTypes, id: \.self) { type in
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
            .alert("添加新费用类型", isPresented: $showingAddExpenseType) {
                TextField("费用类型名称", text: $newExpenseType)
                
                Button("取消", role: .cancel) {
                    newExpenseType = ""
                }
                
                Button("添加") {
                    if !newExpenseType.isEmpty && !availableExpenseTypes.contains(newExpenseType) {
                        TagManager.shared.addExpenseType(newExpenseType)
                        expenseType = newExpenseType
                    }
                    newExpenseType = ""
                }
            }
            
            // 组别选择（横向滑动）
            Section(header: HStack {
                Text("组别")
                Spacer()
                Button("添加") {
                    showingAddGroup = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["未分类"] + availableGroups, id: \.self) { group in
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
            .alert("添加新组别", isPresented: $showingAddGroup) {
                TextField("组别名称", text: $newGroup)
                
                Button("取消", role: .cancel) {
                    newGroup = ""
                }
                
                Button("添加") {
                    if !newGroup.isEmpty && !availableGroups.contains(newGroup) {
                        TagManager.shared.addGroupType(newGroup)
                        group = newGroup
                    }
                    newGroup = ""
                }
            }
            
            // 描述和附件
            Section("其他信息（选填）") {
                // 描述
                VStack(alignment: .leading) {
                    Text("描述")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    TextField("描述", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                
                // 附件
                VStack {
                    if let data = attachmentData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                            .onTapGesture {
                                showingImagePreview = true
                            }
                            
                        Button("移除附件") {
                            attachmentData = nil
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "plus.square.on.square")
                                Text("添加票据或收据照片")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .onChange(of: selectedPhoto) { _ in
                    loadImage()
                }
            }
        }
        .navigationTitle("编辑交易记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    isPresented = false
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveTransaction()
                }
                .disabled(isSaving || name.isEmpty || amount.isEmpty)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("保存中...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .alert("出错了", isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingImagePreview) {
            if let data = attachmentData, let image = UIImage(data: data) {
                ImageViewer(image: image) {
                    showingImagePreview = false
                }
            }
        }
        .onAppear {
            // 加载现有交易记录的数据
            loadTransactionData()
        }
    }
    
    private func loadTransactionData() {
        name = transaction.name
        
        // 根据金额的正负值确定交易类型
        let absAmount = abs(transaction.amount)
        transactionType = transaction.amount < 0 ? .expense : .income
        amount = String(format: "%.2f", absAmount)
        
        date = transaction.date
        description = transaction.transactionDescription
        expenseType = transaction.expenseType
        group = transaction.group
        attachmentData = transaction.attachmentData
    }
    
    private func loadImage() {
        guard let selectedPhoto = selectedPhoto else { return }
        
        Task {
            do {
                if let data = try await selectedPhoto.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.attachmentData = data
                    }
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
    
    private func saveTransaction() {
        // 验证输入
        guard !name.isEmpty else {
            alertMessage = "请输入姓名"
            showingAlert = true
            return
        }
        
        guard let amountValue = Double(amount) else {
            alertMessage = "请输入有效的金额"
            showingAlert = true
            return
        }
        
        // 显示保存中状态
        isSaving = true
        
        // 更新交易记录
        transaction.name = name
        // 根据交易类型设置金额的正负
        transaction.amount = transactionType == .expense ? -abs(amountValue) : abs(amountValue)
        transaction.date = date
        transaction.transactionDescription = description
        transaction.expenseType = expenseType
        transaction.group = group
        transaction.attachmentData = attachmentData
        
        // 保存到持久化存储
        projectStore.saveProjects()
        
        // 延迟一小段时间以显示保存中状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            isPresented = false
        }
    }
}

struct EditTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        let transaction = Transaction(
            name: "张三",
            amount: 1200,
            date: Date(),
            transactionDescription: "摄影棚租金",
            expenseType: "场地",
            group: "摄影组"
        )
        
        let project = Project(name: "测试项目")
        
        return NavigationStack {
            EditTransactionView(
                transaction: .constant(transaction),
                project: .constant(project),
                isPresented: .constant(true)
            )
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
        }
    }
} 
