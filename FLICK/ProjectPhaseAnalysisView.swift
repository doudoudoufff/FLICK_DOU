import SwiftUI

struct ProjectPhaseAnalysisView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    // 计算各阶段的支出
    private var phaseExpenses: [ProjectPhase: Double] {
        var result = [ProjectPhase: Double]()
        for phase in ProjectPhase.allCases {
            let expense = project.transactions
                .filter { $0.transactionType == .expense && $0.projectPhase == phase }
                .reduce(0) { $0 + abs($1.amount) }
            result[phase] = expense
        }
        return result
    }
    
    // 总支出
    private var totalExpense: Double {
        phaseExpenses.values.reduce(0, +)
    }
    
    // 格式化金额
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }
    
    // 计算百分比
    private func percentage(for amount: Double) -> Double {
        guard totalExpense > 0 else { return 0 }
        return (amount / totalExpense) * 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 项目信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("阶段支出分析")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 总览卡片
                    VStack(spacing: 12) {
                        HStack {
                            Text("总支出")
                                .font(.headline)
                            Spacer()
                            Text(formatAmount(totalExpense))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        if project.budget > 0 {
                            HStack {
                                Text("预算使用率")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(project.budgetUsagePercentage))%")
                                    .font(.headline)
                                    .foregroundColor(
                                        project.budgetUsagePercentage < 70 ? .green :
                                        project.budgetUsagePercentage < 90 ? .orange : .red
                                    )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // 阶段详细分析
                    VStack(alignment: .leading, spacing: 16) {
                        Text("各阶段支出详情")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(ProjectPhase.allCases, id: \.self) { phase in
                            let expense = phaseExpenses[phase] ?? 0
                            let percent = percentage(for: expense)
                            
                            VStack(spacing: 12) {
                                // 阶段标题和金额
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: phase.icon)
                                            .foregroundColor(phase.color)
                                            .font(.title3)
                                        
                                        Text(phase.rawValue)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatAmount(expense))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        
                                        if totalExpense > 0 {
                                            Text("\(String(format: "%.1f", percent))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // 进度条
                                if totalExpense > 0 {
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
                                
                                // 交易数量
                                let transactionCount = project.transactions
                                    .filter { $0.transactionType == .expense && $0.projectPhase == phase }
                                    .count
                                
                                if transactionCount > 0 {
                                    HStack {
                                        Text("交易笔数: \(transactionCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        if transactionCount > 0 {
                                            Text("平均: \(formatAmount(expense / Double(transactionCount)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
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
                    
                    // 建议和洞察
                    if totalExpense > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("分析洞察")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                // 找出支出最多的阶段
                                if let maxPhase = phaseExpenses.max(by: { $0.value < $1.value }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chart.bar.fill")
                                            .foregroundColor(.blue)
                                        Text("支出最多的阶段是\(maxPhase.key.rawValue)，占总支出的\(String(format: "%.1f", percentage(for: maxPhase.value)))%")
                                            .font(.subheadline)
                                    }
                                }
                                
                                // 预算警告
                                if project.budget > 0 && project.budgetUsagePercentage > 80 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("预算使用率已超过80%，建议控制后续支出")
                                            .font(.subheadline)
                                    }
                                }
                                
                                // 阶段建议
                                let activePhases = phaseExpenses.filter { $0.value > 0 }.count
                                if activePhases > 0 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text("当前项目涉及\(activePhases)个阶段，建议定期回顾各阶段预算执行情况")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("阶段分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleProject = Project(
        id: UUID(),
        name: "示例项目",
        director: "导演",
        producer: "制片人",
        startDate: Date(),
        status: .production,
        color: .blue,
        tasks: [],
        invoices: [],
        locations: [],
        accounts: [],
        transactions: [],
        isLocationScoutingEnabled: true,
        logoData: nil,
        budget: 100000
    )
    
    ProjectPhaseAnalysisView(project: sampleProject)
} 