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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .sheet(isPresented: $isAddingTransaction) {
            NavigationView {
                TransactionFormView(
                    project: $project,
                    projectStore: projectStore,
                    transactionToEdit: nil,
                    isPresented: $isAddingTransaction
                )
            }
        }
        .sheet(isPresented: $showingManagement) {
            NavigationView {
                TransactionManagementView(project: $project)
                    .environmentObject(projectStore)
            }
        }
    }
    
    // 导航到交易记录详情
    private func navigateToTransactionDetail(transaction: Transaction) {
        // 实际应用中，可以跳转到详情页
    }
}

// 金融数据卡片
struct FinanceCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(10)
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