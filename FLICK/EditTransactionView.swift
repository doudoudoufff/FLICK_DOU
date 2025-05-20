import SwiftUI
import PhotosUI

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var transaction: Transaction
    @Binding var project: Project
    @Binding var isPresented: Bool
    
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
    
    // 获取可用的费用类型列表（包括默认和自定义）
    private var availableExpenseTypes: [String] {
        let defaultTypes = ExpenseType.defaults
        let customTypes = project.customExpenseTypes
        return defaultTypes + customTypes.filter { !defaultTypes.contains($0) }
    }
    
    // 获取可用的组别列表（包括默认和自定义）
    private var availableGroups: [String] {
        let defaultGroups = GroupType.defaults
        let customGroups = project.customGroupTypes
        return defaultGroups + customGroups.filter { !defaultGroups.contains($0) }
    }
    
    // 对类型分组以网格显示
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 10)
    ]
    
    var body: some View {
        Form {
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
                        .foregroundColor(.red)
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
            
            // 费用类型选择（网格布局）
            Section(header: HStack {
                Text("费用类型")
                Spacer()
                Button("添加") {
                    showingAddExpenseType = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(["未分类"] + availableExpenseTypes, id: \.self) { type in
                            ExpenseTypeButton(
                                title: type,
                                isSelected: expenseType == type,
                                action: { expenseType = type }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 150)
            }
            .alert("添加新费用类型", isPresented: $showingAddExpenseType) {
                TextField("费用类型名称", text: $newExpenseType)
                
                Button("取消", role: .cancel) {
                    newExpenseType = ""
                }
                
                Button("添加") {
                    if !newExpenseType.isEmpty && !availableExpenseTypes.contains(newExpenseType) {
                        project.customExpenseTypes.append(newExpenseType)
                        expenseType = newExpenseType
                        projectStore.saveProjects()
                    }
                    newExpenseType = ""
                }
            }
            
            // 组别选择（网格布局）
            Section(header: HStack {
                Text("组别")
                Spacer()
                Button("添加") {
                    showingAddGroup = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(["未分类"] + availableGroups, id: \.self) { group in
                            GroupButton(
                                title: group,
                                isSelected: self.group == group,
                                action: { self.group = group }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 150)
            }
            .alert("添加新组别", isPresented: $showingAddGroup) {
                TextField("组别名称", text: $newGroup)
                
                Button("取消", role: .cancel) {
                    newGroup = ""
                }
                
                Button("添加") {
                    if !newGroup.isEmpty && !availableGroups.contains(newGroup) {
                        project.customGroupTypes.append(newGroup)
                        group = newGroup
                        projectStore.saveProjects()
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
                    dismiss()
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
        amount = String(format: "%.2f", transaction.amount)
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
        transaction.amount = amountValue
        transaction.date = date
        transaction.transactionDescription = description
        transaction.expenseType = expenseType
        transaction.group = group
        
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
