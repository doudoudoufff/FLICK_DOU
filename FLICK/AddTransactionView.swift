import SwiftUI
import PhotosUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @Binding var isPresented: Bool
    var onTransactionAdded: (() -> Void)? = nil
    
    // 使用视图本地变量来跟踪UI状态
    @State private var isExpense: Bool = true
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
    @State private var isSaving: Bool = false
    
    // 错误处理
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // 获取所有费用类型选项
    @State private var expenseTypeOptions: [String] = []
    
    // 获取所有组别选项
    @State private var groupOptions: [String] = []
    
    // 刷新标签选项
    private func refreshTagOptions() {
        print("刷新标签选项")
        expenseTypeOptions = CustomTagManager.shared.getAllExpenseTypes()
        groupOptions = CustomTagManager.shared.getAllGroupTypes()
        print("刷新后的费用类型: \(expenseTypeOptions)")
        print("刷新后的组别: \(groupOptions)")
    }
    
    var body: some View {
        Form {
            // 交易类型选择
            Section {
                HStack(spacing: 0) {
                    Button(action: {
                        print("切换到支出")
                        isExpense = true
                    }) {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 20))
                            Text("支出")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isExpense ? Color.red.opacity(0.9) : Color(.systemGray5))
                        .foregroundColor(isExpense ? .white : .primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                        .frame(width: 10)
                    
                    Button(action: {
                        print("切换到收入")
                        isExpense = false
                    }) {
                        VStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20))
                            Text("收入")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(!isExpense ? Color.green.opacity(0.9) : Color(.systemGray5))
                        .foregroundColor(!isExpense ? .white : .primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
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
                        .foregroundColor(isExpense ? .red : .green)
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
                Button("管理") {
                    showingAddExpenseType = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["未分类"] + expenseTypeOptions, id: \.self) { type in
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
            .sheet(isPresented: $showingAddExpenseType) {
                NavigationStack {
                    CustomTagsSettingsView(initialTagType: .expenseType)
                }
            }
            
            // 组别选择（横向滑动）
            Section(header: HStack {
                Text("组别")
                Spacer()
                Button("管理") {
                    showingAddGroup = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["未分类"] + groupOptions, id: \.self) { group in
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
            .sheet(isPresented: $showingAddGroup) {
                NavigationStack {
                    CustomTagsSettingsView(initialTagType: .groupType)
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
                                Text("添加附件照片")
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
        .navigationTitle("添加交易记录")
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
        .onAppear {
            refreshTagOptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TagsUpdated"))) { _ in
            refreshTagOptions()
        }
        .sheet(isPresented: $showingImagePreview) {
            if let data = attachmentData, let image = UIImage(data: data) {
                ImageViewer(image: image) {
                    showingImagePreview = false
                }
            }
        }
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
        
        // 创建新的交易记录
        let transaction = Transaction(
            name: name,
            amount: amountValue,  // 存储原始金额值，不再在这里处理正负
            date: date,
            transactionDescription: description,
            expenseType: expenseType,
            group: group,
            paymentMethod: "现金", // 默认使用现金
            transactionType: isExpense ? .expense : .income, // 根据UI状态设置交易类型
            attachmentData: attachmentData,
            isVerified: false
        )
        
        print("开始添加交易记录: \(transaction.name), 金额: \(transaction.amount)")
        print("交易记录日期: \(transaction.date)")
        print("添加前交易记录数量: \(project.transactions.count)")
        
        // 使用ProjectStore的addTransaction方法添加到项目
        projectStore.addTransaction(to: project, transaction: transaction)
        
        // 不要在这里重复添加，让ProjectStore负责添加记录
        // project.transactions.append(transaction)
        
        print("添加后交易记录数量: \(project.transactions.count)")
        
        // 立即发送通知，强制刷新所有相关视图
        NotificationCenter.default.post(
            name: NSNotification.Name("TransactionAdded"),
            object: nil,
            userInfo: ["projectId": project.id, "transactionId": transaction.id]
        )
        
        print("已发送TransactionAdded通知")
        
        // 立即调用回调函数进行刷新
        self.onTransactionAdded?()
        print("已调用onTransactionAdded回调")
        
        // 确保数据更新后视图能正确刷新
        DispatchQueue.main.async {
            // 通知ProjectStore发生变化
            projectStore.objectWillChange.send()
            print("已通知ProjectStore更新")
            
            // 通知Project对象发生变化
            project.objectWillChange.send()
            print("已通知Project对象更新")
            
            // 延迟一小段时间以显示保存中状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                isPresented = false
                print("表单已关闭")
            }
        }
    }
}

#Preview {
        NavigationStack {
        AddTransactionView(project: .constant(Project(name: "测试项目")), isPresented: .constant(true))
                .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
    }
} 
