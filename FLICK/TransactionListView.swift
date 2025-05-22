import SwiftUI

struct TransactionListView: View {
    @Binding var project: Project
    @ObservedObject var projectStore: ProjectStore
    @State private var isAddingTransaction = false
    @State private var searchText = ""
    @State private var selectedTransactionType: TransactionType?
    @State private var showTypeFilter = false
    @State private var showDatePicker = false
    @State private var startDate: Date = Date().addingTimeInterval(-30*86400) // 默认显示最近30天
    @State private var endDate: Date = Date()
    @State private var showingManagement = false
    @State private var showingBudgetEditor = false
    
    // 判断是否为 iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 过滤后的交易记录
    private var filteredTransactions: [Transaction] {
        var result = project.transactions
        
        // 搜索文本过滤
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.name.contains(searchText) ||
                transaction.transactionDescription.contains(searchText) ||
                transaction.expenseType.contains(searchText) ||
                transaction.group.contains(searchText)
            }
        }
        
        // 交易类型过滤
        if let type = selectedTransactionType {
            result = result.filter { $0.transactionType == type }
        }
        
        // 日期范围过滤
        result = result.filter { $0.date >= startDate && $0.date <= endDate }
        
        // 按日期排序（最新的在前）
        return result.sorted { $0.date > $1.date }
    }
    
    // 计算总收入
    private var totalIncome: Double {
        project.transactions
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 计算总支出
    private var totalExpense: Double {
        project.transactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 获取最近5条交易记录
    private var recentTransactions: [Transaction] {
        return project.transactions
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    // 格式化金额
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和操作按钮
            HStack {
                Text("账目记录")
                    .font(.headline)
                
                Spacer()
                
                if isIPad {
                    Button(action: { showingManagement = true }) {
                        Label("管理", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.accentColor)
                    }
                } else {
                    NavigationLink(destination: TransactionManagementView(project: $project).environmentObject(projectStore)) {
                        Label("管理", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { isAddingTransaction = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            // 预算卡片
            BudgetCard(
                budget: project.budget,
                spent: totalExpense,
                usagePercentage: project.budgetUsagePercentage,
                onEditBudget: { showingBudgetEditor = true }
            )
            
            // 统计卡片
            HStack(spacing: 12) {
                FinanceCard(
                    title: "收入",
                    value: formatAmount(totalIncome),
                    color: .green
                )
                
                FinanceCard(
                    title: "支出",
                    value: formatAmount(totalExpense),
                    color: .red
                )
                
                FinanceCard(
                    title: "结余",
                    value: formatAmount(totalIncome - totalExpense),
                    color: totalIncome - totalExpense >= 0 ? .blue : .red
                )
            }
            
            // 如果没有交易记录，显示提示信息
            if project.transactions.isEmpty {
                EmptyTransactionView(action: {
                    isAddingTransaction = true
                })
            } else {
                // 交易记录列表
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentTransactions) { transaction in
                        TransactionItemRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                navigateToTransactionDetail(transaction: transaction)
                            }
                    }
                    
                    if project.transactions.count > 5 {
                        NavigationLink(destination: TransactionManagementView(project: $project).environmentObject(projectStore)) {
                            Text("查看全部\(project.transactions.count)条记录")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            
            // 管理账目按钮
            NavigationLink(destination: TransactionManagementView(project: $project).environmentObject(projectStore)) {
                Text("管理所有账目")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .sheet(isPresented: $isAddingTransaction) {
            NavigationView {
                AddTransactionView(
                    project: $project,
                    isPresented: $isAddingTransaction
                )
                .environmentObject(projectStore)
            }
        }
        .sheet(isPresented: $showingManagement) {
            NavigationView {
                TransactionManagementView(project: $project)
                    .environmentObject(projectStore)
            }
        }
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(project: $project, projectStore: projectStore)
        }
    }
    
    // 导航到交易记录详情
    private func navigateToTransactionDetail(transaction: Transaction) {
        // 实际应用中，可以跳转到详情页
    }
}

// 项目账目摘要卡片 - 用于项目详情页面展示
struct TransactionSummaryCard: View {
    @Binding var project: Project
    @ObservedObject var projectStore: ProjectStore
    @State private var showingBudgetEditor = false
    @State private var isAddingTransaction = false
    
    // 计算总收入
    private var totalIncome: Double {
        project.transactions
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 计算总支出
    private var totalExpense: Double {
        project.transactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 格式化金额
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和操作按钮
            HStack {
                Text("账目管理")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: TransactionManagementView(project: $project).environmentObject(projectStore)) {
                    Label("管理", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Button(action: { isAddingTransaction = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            Divider()
            
            // 预算信息
            VStack(spacing: 12) {
                if project.budget > 0 {
                    HStack {
                        Text("预算总额")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatAmount(project.budget))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Button(action: { showingBudgetEditor = true }) {
                            Image(systemName: "pencil")
                                .font(.footnote)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                    
                    // 预算进度条
                    VStack(spacing: 4) {
                        HStack {
                            Text("预算使用")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(project.budgetUsagePercentage))%")
                                .foregroundColor(
                                    project.budgetUsagePercentage < 70 ? .green :
                                        project.budgetUsagePercentage < 90 ? .orange : .red
                                )
                        }
                        .font(.subheadline)
                        
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(height: 6)
                                .foregroundColor(Color(.systemGray5))
                                .cornerRadius(3)
                            
                            Rectangle()
                                .frame(width: min(max(CGFloat(project.budgetUsagePercentage) / 100.0 * UIScreen.main.bounds.width * 0.8, 0), UIScreen.main.bounds.width * 0.8), height: 6)
                                .foregroundColor(
                                    project.budgetUsagePercentage < 70 ? .green :
                                        project.budgetUsagePercentage < 90 ? .yellow : .red
                                )
                                .cornerRadius(3)
                        }
                    }
                } else {
                    HStack {
                        Text("尚未设置预算")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: { showingBudgetEditor = true }) {
                            Text("设置")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            
            // 财务摘要
            HStack(spacing: 12) {
                FinanceCard(
                    title: "收入",
                    value: formatAmount(totalIncome),
                    color: .green
                )
                
                FinanceCard(
                    title: "支出",
                    value: formatAmount(totalExpense),
                    color: .red
                )
                
                FinanceCard(
                    title: "结余",
                    value: formatAmount(totalIncome - totalExpense),
                    color: totalIncome - totalExpense >= 0 ? .blue : .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isAddingTransaction) {
            NavigationView {
                AddTransactionView(
                    project: $project,
                    isPresented: $isAddingTransaction
                )
                .environmentObject(projectStore)
            }
        }
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(project: $project, projectStore: projectStore)
        }
    }
}

// 预算卡片
struct BudgetCard: View {
    let budget: Double
    let spent: Double
    let usagePercentage: Double
    let onEditBudget: () -> Void
    
    private var remainingBudget: Double {
        max(budget - spent, 0)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("项目预算")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onEditBudget) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                }
            }
            
            if budget > 0 {
                HStack {
                    Text("总预算: \(formatAmount(budget))")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("已使用: \(formatAmount(spent))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("剩余: \(formatAmount(remainingBudget))")
                        .font(.subheadline)
                        .foregroundColor(remainingBudget > budget * 0.2 ? .green : .red)
                    
                    Spacer()
                    
                    Text("\(Int(usagePercentage))%")
                        .font(.subheadline)
                        .foregroundColor(usagePercentage < 80 ? .secondary : .red)
                }
                
                // 进度条
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(height: 8)
                        .foregroundColor(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Rectangle()
                        .frame(width: min(max(CGFloat(usagePercentage) / 100.0 * UIScreen.main.bounds.width * 0.8, 0), UIScreen.main.bounds.width * 0.8), height: 8)
                        .foregroundColor(
                            usagePercentage < 70 ? .green :
                                usagePercentage < 90 ? .yellow : .red
                        )
                        .cornerRadius(4)
                }
            } else {
                Text("未设置预算")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: onEditBudget) {
                    Text("设置预算")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// 预算编辑视图
struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    @ObservedObject var projectStore: ProjectStore
    @State private var budgetText: String = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("设置项目预算")) {
                    TextField("预算金额", text: $budgetText)
                        .keyboardType(.decimalPad)
                        .onAppear {
                            budgetText = project.budget > 0 ? String(format: "%.2f", project.budget) : ""
                        }
                }
                
                Section {
                    Button("保存") {
                        saveBudget()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("项目预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("输入错误"),
                    message: Text("请输入有效的预算金额"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func saveBudget() {
        guard let budget = Double(budgetText.replacingOccurrences(of: ",", with: ".")),
              budget >= 0 else {
            showError = true
            return
        }
        
        print("设置项目预算，原始值: \(project.budget)")
        project.budget = budget
        print("新的预算值: \(budget)")
        
        // 保存到CoreData
        projectStore.updateProject(project)
        print("已调用updateProject保存预算")
        
        dismiss()
    }
}

// 金融数据卡片
struct FinanceCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 交易记录行
struct TransactionItemRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // 交易类型图标
            Image(systemName: transaction.transactionType.icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(transaction.transactionType.color)
                .cornerRadius(14)
            
            // 交易信息
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(transaction.expenseType + (transaction.group != "未分类" ? " · " + transaction.group : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 右侧信息
            VStack(alignment: .trailing, spacing: 3) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .foregroundColor(transaction.transactionType.color)
                
                Text(transaction.date.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// 空状态视图
struct EmptyTransactionView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 4)
            
            Text("暂无账目记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: action) {
                Label("添加记录", systemImage: "plus")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// 提供预览
struct TransactionListView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTransactions = [
            Transaction(name: "张三", amount: 1200, date: Date(), transactionDescription: "摄影棚租金", expenseType: "场地", group: "摄影组"),
            Transaction(name: "李四", amount: 800, date: Date(), transactionDescription: "灯光设备租赁", expenseType: "器材", group: "灯光组"),
            Transaction(name: "王五", amount: 600, date: Date(), transactionDescription: "剧组盒饭", expenseType: "餐饮")
        ]
        
        let project = Project(name: "测试项目", transactions: sampleTransactions)
        
        return TransactionListView(project: .constant(project), projectStore: ProjectStore(context: PersistenceController.preview.container.viewContext))
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 