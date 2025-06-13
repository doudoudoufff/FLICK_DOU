import SwiftUI

// MARK: - TimeRange 枚举
enum TimeRange: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case quarter = "本季度"
    case all = "全部"
    
    func dateRange() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (startOfWeek, endOfWeek)
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
            
        case .quarter:
            let startOfQuarter = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            let endOfQuarter = calendar.dateInterval(of: .quarter, for: now)?.end ?? now
            return (startOfQuarter, endOfQuarter)
            
        case .all:
            return nil // 返回nil表示不过滤
        }
    }
}

struct GlobalFinanceAnalysisView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedAnalysisType: AnalysisType = .overview
    
    enum AnalysisType: String, CaseIterable {
        case overview = "总览"
        case projects = "项目对比"
        case phases = "阶段分析"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 时间范围选择器
                    VStack(alignment: .leading, spacing: 12) {
                        Text("时间范围")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Button(action: { selectedTimeRange = range }) {
                                        Text(range.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedTimeRange == range ? Color.blue : Color(.systemGray6))
                                            )
                                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 分析类型选择器
                    VStack(alignment: .leading, spacing: 12) {
                        Text("分析类型")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AnalysisType.allCases, id: \.self) { type in
                                    Button(action: { selectedAnalysisType = type }) {
                                        Text(type.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedAnalysisType == type ? Color.green : Color(.systemGray6))
                                            )
                                            .foregroundColor(selectedAnalysisType == type ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 财务总览卡片
                    FinancialOverviewCard(
                        projects: projectStore.projects,
                        timeRange: selectedTimeRange
                    )
                    
                    // 根据选择的分析类型显示内容
                    switch selectedAnalysisType {
                    case .overview:
                        ProjectStatusOverview(projects: projectStore.projects)
                        
                    case .projects:
                        ProjectComparisonView(
                            projects: projectStore.projects,
                            timeRange: selectedTimeRange
                        )
                        
                    case .phases:
                        GlobalPhaseAnalysisView(
                            projects: projectStore.projects,
                            timeRange: selectedTimeRange
                        )
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("财务分析")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 财务总览卡片
struct FinancialOverviewCard: View {
    let projects: [Project]
    let timeRange: TimeRange
    
    private var totalBudget: Double {
        projects.reduce(0) { $0 + $1.budget }
    }
    
    private var totalExpense: Double {
        projects.reduce(0) { total, project in
            let filteredTransactions = filterTransactions(project.transactions)
            return total + filteredTransactions
                .filter { $0.transactionType == .expense }
                .reduce(0) { $0 + abs($1.amount) }
        }
    }
    
    private var totalIncome: Double {
        projects.reduce(0) { total, project in
            let filteredTransactions = filterTransactions(project.transactions)
            return total + filteredTransactions
                .filter { $0.transactionType == .income }
                .reduce(0) { $0 + $1.amount }
        }
    }
    
    private func filterTransactions(_ transactions: [Transaction]) -> [Transaction] {
        guard let dateRange = timeRange.dateRange() else {
            return transactions
        }
        return transactions.filter { transaction in
            transaction.date >= dateRange.start && transaction.date <= dateRange.end
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("财务总览")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                FinanceMetricCard(
                    title: "总预算",
                    value: formatAmount(totalBudget),
                    color: .blue,
                    icon: "dollarsign.circle"
                )
                
                FinanceMetricCard(
                    title: "总收入",
                    value: formatAmount(totalIncome),
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                FinanceMetricCard(
                    title: "总支出",
                    value: formatAmount(totalExpense),
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
                
                FinanceMetricCard(
                    title: "净结余",
                    value: formatAmount(totalIncome - totalExpense),
                    color: (totalIncome - totalExpense) >= 0 ? .green : .red,
                    icon: (totalIncome - totalExpense) >= 0 ? "plus.circle.fill" : "minus.circle.fill"
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 项目状态总览
struct ProjectStatusOverview: View {
    let projects: [Project]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("项目状态分布")
                .font(.headline)
                .padding(.horizontal)
            
            let statusCounts = Dictionary(grouping: projects, by: { $0.status })
            
            VStack(spacing: 8) {
                ForEach(Array(Project.Status.allCases), id: \.self) { status in
                    let count = statusCounts[status]?.count ?? 0
                    if count > 0 {
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 12, height: 12)
                            
                            Text(status.rawValue)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(count) 个项目")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
}

// MARK: - 项目对比视图
struct ProjectComparisonView: View {
    let projects: [Project]
    let timeRange: TimeRange
    
    private func filterTransactions(_ transactions: [Transaction]) -> [Transaction] {
        guard let dateRange = timeRange.dateRange() else {
            return transactions
        }
        return transactions.filter { transaction in
            transaction.date >= dateRange.start && transaction.date <= dateRange.end
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("项目对比")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(projects) { project in
                let filteredTransactions = filterTransactions(project.transactions)
                let expense = filteredTransactions
                    .filter { $0.transactionType == .expense }
                    .reduce(0) { $0 + abs($1.amount) }
                
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(project.color)
                            .frame(width: 16, height: 16)
                        
                        Text(project.name)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatAmount(expense))
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(project.status.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if project.budget > 0 {
                        VStack(spacing: 4) {
                            HStack {
                                Text("预算使用率")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(project.budgetUsagePercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            ProgressView(value: project.budgetUsagePercentage, total: 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: project.budgetUsagePercentage > 80 ? .red : project.color))
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 全局阶段分析视图
struct GlobalPhaseAnalysisView: View {
    let projects: [Project]
    let timeRange: TimeRange
    
    private var phaseData: [ProjectPhase: Double] {
        var result = [ProjectPhase: Double]()
        
        for project in projects {
            let filteredTransactions = filterTransactions(project.transactions)
            for transaction in filteredTransactions where transaction.transactionType == .expense {
                result[transaction.projectPhase, default: 0] += abs(transaction.amount)
            }
        }
        
        return result
    }
    
    private var totalExpense: Double {
        phaseData.values.reduce(0, +)
    }
    
    private func filterTransactions(_ transactions: [Transaction]) -> [Transaction] {
        guard let dateRange = timeRange.dateRange() else {
            return transactions
        }
        return transactions.filter { transaction in
            transaction.date >= dateRange.start && transaction.date <= dateRange.end
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    private func percentage(for amount: Double) -> Double {
        guard totalExpense > 0 else { return 0 }
        return (amount / totalExpense) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("全局阶段分析")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(ProjectPhase.allCases), id: \.self) { phase in
                let amount = phaseData[phase] ?? 0
                let percent = percentage(for: amount)
                
                if amount > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: phase.icon)
                                    .foregroundColor(phase.color)
                                    .font(.title3)
                                
                                Text(phase.rawValue)
                                    .font(.headline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatAmount(amount))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text("\(String(format: "%.1f", percent))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(height: 8)
                                    .foregroundColor(Color(.systemGray5))
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .frame(width: geometry.size.width * CGFloat(percent / 100), height: 8)
                                    .foregroundColor(phase.color)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(phase.color.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(phase.color.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 财务指标卡片
struct FinanceMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    GlobalFinanceAnalysisView()
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 