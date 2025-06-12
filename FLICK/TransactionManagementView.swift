import SwiftUI

// 排序选项
enum TransactionSortOption: String, CaseIterable {
    case dateDesc = "日期（新到旧）"
    case dateAsc = "日期（旧到新）"
    case amountDesc = "金额（高到低）"
    case amountAsc = "金额（低到高）"
}

// 筛选类别
enum FilterCategory: String, CaseIterable {
    case none = "全部"
    case expenseType = "费用类型"
    case group = "组别"
}

struct TransactionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddTransaction = false
    @State private var editingTransaction: Transaction? = nil
    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var showingFilterSheet = false
    @State private var sortOption: TransactionSortOption = .dateDesc
    @State private var refreshID = UUID()
    @State private var transactionToDelete: Transaction? = nil
    @State private var showingDeleteAlert = false
    @State private var selectedDateRange: DateInterval = DateInterval(
        start: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        end: Date()
    )
    @State private var showingBudgetEditor = false
    
    // 筛选相关状态
    @State private var selectedExpenseType: String? = nil
    @State private var selectedGroup: String? = nil
    
    // 添加筛选区域展开/折叠状态
    @State private var isFilterExpanded: Bool = false
    
    // 获取所有可用的费用类型
    var expenseTypes: [String] {
        return CustomTagManager.shared.getAllExpenseTypes()
    }
    
    // 获取所有可用的组别
    var groupTypes: [String] {
        return CustomTagManager.shared.getAllGroupTypes()
    }
    
    // 按费用类型统计
    private var expenseByType: [String: Double] {
        var result = [String: Double]()
        for transaction in project.transactions where transaction.transactionType == .expense {
            let type = transaction.expenseType
            result[type, default: 0] += transaction.amount
        }
        return result
    }
    
    // 按组别统计
    private var expenseByGroup: [String: Double] {
        var result = [String: Double]()
        for transaction in project.transactions where transaction.transactionType == .expense {
            let group = transaction.group
            result[group, default: 0] += transaction.amount
        }
        return result
    }
    
    // 交叉分析：获取特定组别在特定费用类型上的总支出
    private func expenseForGroupAndType(group: String, type: String) -> Double {
        project.transactions
            .filter { $0.transactionType == .expense && $0.group == group && $0.expenseType == type }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 过滤交易记录
    var filteredTransactions: [Transaction] {
        var result = project.transactions
        
        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.name.localizedCaseInsensitiveContains(searchText) ||
                transaction.transactionDescription.localizedCaseInsensitiveContains(searchText) ||
                transaction.expenseType.localizedCaseInsensitiveContains(searchText) ||
                transaction.group.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 类型过滤
        if let type = selectedType {
            result = result.filter { $0.transactionType == type }
        }
        
        // 日期过滤
        result = result.filter { 
            $0.date >= selectedDateRange.start && $0.date <= selectedDateRange.end 
        }
        
        // 费用类型筛选
        if let type = selectedExpenseType {
            result = result.filter { $0.expenseType == type }
        }
        
        // 组别筛选
        if let group = selectedGroup {
            result = result.filter { $0.group == group }
        }
        
        // 排序
        switch sortOption {
        case .dateDesc:
            result.sort { $0.date > $1.date }
        case .dateAsc:
            result.sort { $0.date < $1.date }
        case .amountDesc:
            result.sort { $0.amount > $1.amount }
        case .amountAsc:
            result.sort { $0.amount < $1.amount }
        }
        
        return result
    }
    
    // 计算统计数据
    var totalIncome: Double {
        filteredTransactions.filter { $0.transactionType == .income }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        filteredTransactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var balance: Double {
        totalIncome - totalExpense
    }
    
    // 格式化金额
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 预算信息
            if project.budget > 0 {
                BudgetInfoView(
                    budget: project.budget,
                    spent: project.remainingBudget,
                    usagePercentage: project.budgetUsagePercentage,
                    onEditBudget: { showingBudgetEditor = true }
                )
                .padding()
                
                Divider()
            }
            
            // 统计卡片区域
            HStack(spacing: 12) {
                TransactionStatCard(
                    title: "收入", 
                    value: formatAmount(totalIncome), 
                    color: .green, 
                    icon: "arrow.up.circle.fill"
                )
                
                TransactionStatCard(
                    title: "支出", 
                    value: formatAmount(totalExpense), 
                    color: .red, 
                    icon: "arrow.down.circle.fill"
                )
                
                TransactionStatCard(
                    title: "结余", 
                    value: formatAmount(balance), 
                    color: balance >= 0 ? .blue : .red, 
                    icon: "equal.circle.fill"
                )
            }
            .frame(height: 60)
            .padding()
            
            Divider()
            
            // 搜索和筛选
            VStack(spacing: 8) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索交易记录", text: $searchText)
                            .font(.system(size: 15))
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // 筛选按钮，添加当前筛选条件数量的指示
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            
                            // 显示筛选数量的小红点
                            let filterCount = [selectedType, selectedExpenseType, selectedGroup].compactMap { $0 }.count
                            if filterCount > 0 {
                                Text("\(filterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // 添加展开/折叠筛选区域的按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFilterExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                
                // 使用可折叠区域包装筛选内容
                if isFilterExpanded {
                    VStack(spacing: 8) {
                        // 费用类型行 - 直接显示
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("费用类型")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
            
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        selectedExpenseType = nil
                                    }) {
                                        Text("全部")
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedExpenseType == nil ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(selectedExpenseType == nil ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                    
                                    ForEach(expenseTypes, id: \.self) { type in
                                        FilterButton(
                                            text: type,
                                            amount: formatAmount(expenseByType[type, default: 0]),
                                            isSelected: selectedExpenseType == type,
                                            action: {
                                                if selectedExpenseType == type {
                                                    selectedExpenseType = nil
                                                } else {
                                                    selectedExpenseType = type
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 组别行 - 直接显示
                        VStack(alignment: .leading, spacing: 4) {
                            Text("组别")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        selectedGroup = nil
                                    }) {
                                        Text("全部")
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedGroup == nil ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(selectedGroup == nil ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                    
                                    ForEach(groupTypes, id: \.self) { group in
                                        FilterButton(
                                            text: group,
                                            amount: formatAmount(expenseByGroup[group, default: 0]),
                                            isSelected: selectedGroup == group,
                                            action: {
                                                if selectedGroup == group {
                                                    selectedGroup = nil
                                                } else {
                                                    selectedGroup = group
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 交叉分析结果区域
                        if let group = selectedGroup, let type = selectedExpenseType {
                            // 显示特定组别在特定费用类型上的支出
                            let amount = expenseForGroupAndType(group: group, type: type)
                            
                            HStack {
                                Text("\(group) - \(type) 支出:")
                                    .font(.system(size: 14))
                                
                                Spacer()
                                
                                Text(formatAmount(amount))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .padding(10)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)
                            .padding(.top, 4)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
                
                // 当前筛选状态提示，始终显示
                if selectedType != nil || selectedExpenseType != nil || selectedGroup != nil {
                    HStack(spacing: 6) {
                        Text("筛选:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let type = selectedType {
                            FilterTag(text: type.rawValue, color: type.color)
                        }
                        
                        if let type = selectedExpenseType {
                            FilterTag(text: type, color: .orange)
                        }
                        
                        if let group = selectedGroup {
                            FilterTag(text: group, color: .purple)
                        }
                        
                        if sortOption != .dateDesc {
                            FilterTag(
                                text: "排序: \(sortOption.rawValue)", 
                                color: .blue
                            )
                        }
                        
                        Spacer()
                        
                        // 添加清除所有筛选的按钮
                        Button(action: {
                            selectedType = nil
                            selectedExpenseType = nil
                            selectedGroup = nil
                            sortOption = .dateDesc
                        }) {
                            Text("清除")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // 交易记录列表
            if filteredTransactions.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("暂无交易记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingAddTransaction = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加交易记录")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredTransactions) { transaction in
                        TransactionCell(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTransaction = transaction
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("账目管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if project.budget == 0 {
                    Button(action: { showingBudgetEditor = true }) {
                        Label("设置预算", systemImage: "dollarsign.circle")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddTransaction = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            NavigationView {
                AddTransactionView(
                    project: $project,
                    isPresented: $showingAddTransaction
                )
                .environmentObject(projectStore)
            }
            .onDisappear {
                // 当添加交易记录sheet关闭时刷新视图
                refreshID = UUID()
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            NavigationView {
                EditTransactionView(
                    transaction: Binding(
                        get: { transaction },
                        set: { _ in }
                    ),
                    project: $project,
                    isPresented: Binding(
                        get: { editingTransaction != nil },
                        set: { if !$0 { editingTransaction = nil } }
                    )
                )
                .environmentObject(projectStore)
            }
            .onDisappear {
                // 当编辑交易记录sheet关闭时刷新视图
                refreshID = UUID()
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationView {
                FilterView(
                    selectedType: $selectedType,
                    sortOption: $sortOption,
                    dateRange: $selectedDateRange
                )
                .navigationTitle("筛选")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("重置") {
                            selectedType = nil
                            selectedExpenseType = nil
                            selectedGroup = nil
                            sortOption = .dateDesc
                            selectedDateRange = DateInterval(
                                start: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
                                end: Date()
                            )
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingFilterSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingBudgetEditor) {
            BudgetEditorView(project: $project, projectStore: projectStore)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                transactionToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let transaction = transactionToDelete {
                    projectStore.deleteTransaction(from: project, transactionId: transaction.id)
                    transactionToDelete = nil
                    refreshID = UUID()
                }
            }
        } message: {
            Text("确定要删除这条交易记录吗？此操作无法撤销。")
        }
        .id(refreshID)
        // 直接监听project.transactions变化，这是关键
        .onChange(of: project.transactions) { _ in
            refreshID = UUID()
        }
    }
}

// 预算信息视图
struct BudgetInfoView: View {
    let budget: Double
    let spent: Double // 这个参数现在应该是剩余预算 (budget + income - expense)
    let usagePercentage: Double // 使用百分比
    let onEditBudget: () -> Void
    
    // 我们不在这里计算 remainingBudget，而是直接使用传入的参数
    private var isOverBudget: Bool {
        spent < 0
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("项目预算")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onEditBudget) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                }
            }
            
            Divider()
            
            HStack {
                Text("总预算: \(formatAmount(budget))")
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(isOverBudget ? "超出预算: " : "剩余预算: ")
                Text(formatAmount(abs(spent)))
                    .foregroundColor(isOverBudget ? .red : (spent > budget * 0.2 ? .green : .orange))
                
                if isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .font(.subheadline)
            
            // 进度条
            HStack {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(height: 6)
                        .foregroundColor(Color(.systemGray5))
                        .cornerRadius(3)
                    
                    Rectangle()
                        .frame(width: min(max(CGFloat(usagePercentage) / 100.0 * UIScreen.main.bounds.width * 0.7, 0), UIScreen.main.bounds.width * 0.7), height: 6)
                        .foregroundColor(
                            usagePercentage < 70 ? .green :
                                usagePercentage < 90 ? .yellow : .red
                        )
                        .cornerRadius(3)
                }
                
                Text(String(format: "%.1f%%", usagePercentage))
                    .font(.caption)
                    .foregroundColor(
                        usagePercentage < 70 ? .green :
                            usagePercentage < 90 ? .yellow : .red
                    )
            }
            
            // 超出预算警告
            if isOverBudget {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("已超出预算 \(formatAmount(abs(spent)))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
                .padding(.top, 4)
            }
        }
    }
}

// 筛选按钮组件
struct FilterButton: View {
    let text: String
    let amount: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(amount)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// 筛选视图
struct FilterView: View {
    @Binding var selectedType: TransactionType?
    @Binding var sortOption: TransactionSortOption
    @Binding var dateRange: DateInterval
    
    var body: some View {
        Form {
            Section(header: Text("交易类型")) {
                Button(action: {
                    selectedType = nil
                }) {
                    HStack {
                        Text("全部")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedType == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                ForEach(TransactionType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                            Text(type.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("排序方式")) {
                Picker("", selection: $sortOption) {
                    ForEach(TransactionSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(InlinePickerStyle())
            }
            
            Section(header: Text("日期范围")) {
                DatePicker("开始日期", selection: $dateRange.start, displayedComponents: .date)
                DatePicker("结束日期", selection: $dateRange.end, displayedComponents: .date)
            }
        }
    }
}

// 统计卡片
struct TransactionStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.primary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 18)
        }
        .frame(maxWidth: .infinity, minHeight: 65, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// 交易记录单元格
struct TransactionCell: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: transaction.transactionType.icon)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(transaction.transactionType.color)
                .cornerRadius(18)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.headline)
                
                HStack {
                    Text(transaction.expenseType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    if transaction.group != "未分类" {
                        Text(transaction.group)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // 日期
                    Text(transaction.date.formatted(.dateTime.month().day()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 金额
            Text(transaction.formattedAmount)
                .font(.headline)
                .foregroundColor(transaction.transactionType.color)
        }
        .padding(.vertical, 8)
    }
}

// 筛选标签
struct FilterTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

#Preview {
    NavigationView {
        TransactionManagementView(
            project: .constant(Project(
                name: "示例项目",
                transactions: [
                    Transaction(name: "摄影器材租赁", amount: 5000, transactionType: .expense),
                    Transaction(name: "制作费收入", amount: 50000, transactionType: .income),
                    Transaction(name: "场地费", amount: 3000, transactionType: .expense)
                ]
            ))
        )
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
    }
} 