import Foundation
import SwiftUI

// 交易记录模型
struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String              // 姓名（必填）
    var amount: Double            // 金额（必填）
    var date: Date                // 交易日期（必填）
    var transactionDescription: String  // 描述（选填）
    var expenseType: String       // 费用类型（选填）
    var group: String             // 组别（选填）
    var paymentMethod: String     // 支付方式（选填）
    var transactionType: TransactionType  // 交易类型
    var attachmentData: Data?     // 附件数据（选填）
    var isVerified: Bool          // 是否已核实
    
    init(id: UUID = UUID(), 
         name: String,
         amount: Double, 
         date: Date = Date(),
         transactionDescription: String = "",
         expenseType: String = "未分类",
         group: String = "未分类",
         paymentMethod: String = "现金",
         transactionType: TransactionType = .expense,
         attachmentData: Data? = nil,
         isVerified: Bool = false) {
        self.id = id
        self.name = name
        self.amount = amount
        self.date = date
        self.transactionDescription = transactionDescription
        self.expenseType = expenseType
        self.group = group
        self.paymentMethod = paymentMethod
        self.transactionType = transactionType
        self.attachmentData = attachmentData
        self.isVerified = isVerified
    }
    
    // 获取金额的格式化字符串
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        
        // 根据交易类型处理金额显示（确保收入显示为正数，支出显示为负数）
        let displayAmount = transactionType == .income ? abs(amount) : -abs(amount)
        return formatter.string(from: NSNumber(value: displayAmount)) ?? "¥\(displayAmount)"
    }
    
    // 交易展示颜色
    var color: Color {
        return transactionType.color
    }
}

// 交易类型枚举
enum TransactionType: String, Codable, CaseIterable {
    case expense = "支出"
    case income = "收入"
    
    var color: Color {
        switch self {
        case .expense: return .red
        case .income: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        }
    }
}

// 常用交易分类
struct TransactionCategory {
    static let expense = [
        "交通", "餐饮", "杂支", "差旅", "住宿", "器材", "场地", "演员费用", "后期制作", "其他"
    ]
    
    static let income = [
        "制作费", "赞助", "投资", "销售", "其他"
    ]
    
    static func categories(for type: TransactionType) -> [String] {
        switch type {
        case .expense: return expense
        case .income: return income
        }
    }
}

// 注意：原TagManager类已被CustomTagManager替代，现在使用CoreData存储标签数据

// 为了兼容性保留原有结构体，但内部使用CustomTagManager
struct ExpenseType {
    static var defaults: [String] {
        return CustomTagManager.shared.getAllExpenseTypes()
    }
}

// 为了兼容性保留原有结构体，但内部使用CustomTagManager
struct GroupType {
    static var defaults: [String] {
        return CustomTagManager.shared.getAllGroupTypes()
    }
}

// 支付方式
struct PaymentMethod {
    static let methods = [
        "现金", "银行转账", "支付宝", "微信", "公司账户", "信用卡", "其他"
    ]
}

// 为方便访问费用类型和组别的静态扩展
extension Transaction {
    // 获取所有费用类型
    static func getAllExpenseTypes() -> [String] {
        return CustomTagManager.shared.getAllExpenseTypes()
    }
    
    // 获取所有组别
    static func getAllGroupTypes() -> [String] {
        return CustomTagManager.shared.getAllGroupTypes()
    }
} 