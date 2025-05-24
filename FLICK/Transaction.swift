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
        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
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

// 自定义标签管理器
class TagManager {
    // 单例模式
    static let shared = TagManager()
    
    // UserDefaults中存储标签的键
    private let expenseTypesKey = "customExpenseTypes"
    private let groupTypesKey = "customGroupTypes"
    
    // 默认费用类型
    private let defaultExpenseTypes = [
        "交通", "餐饮", "杂支", "差旅", "住宿", "器材", "场地", "演员费用", "后期制作", "其他"
    ]

// 默认组别类型
    private let defaultGroupTypes = [
        "制片组", "摄影组", "灯光组", "场务组", "道具组", "演员组", "美术组", "后期组", "导演组", "其他"
    ]
    
    private init() {
        // 初始化时，如果UserDefaults中没有数据，则写入默认值
        if UserDefaults.standard.object(forKey: expenseTypesKey) == nil {
            UserDefaults.standard.set(defaultExpenseTypes, forKey: expenseTypesKey)
        }
        
        if UserDefaults.standard.object(forKey: groupTypesKey) == nil {
            UserDefaults.standard.set(defaultGroupTypes, forKey: groupTypesKey)
        }
    }
    
    // 获取所有费用类型（包括默认和自定义）
    func getAllExpenseTypes() -> [String] {
        return UserDefaults.standard.stringArray(forKey: expenseTypesKey) ?? defaultExpenseTypes
    }
    
    // 获取所有组别类型（包括默认和自定义）
    func getAllGroupTypes() -> [String] {
        return UserDefaults.standard.stringArray(forKey: groupTypesKey) ?? defaultGroupTypes
    }
    
    // 添加新的费用类型
    func addExpenseType(_ type: String) {
        var types = getAllExpenseTypes()
        if !types.contains(type) && !type.isEmpty {
            types.append(type)
            UserDefaults.standard.set(types, forKey: expenseTypesKey)
        }
    }
    
    // 添加新的组别类型
    func addGroupType(_ group: String) {
        var groups = getAllGroupTypes()
        if !groups.contains(group) && !group.isEmpty {
            groups.append(group)
            UserDefaults.standard.set(groups, forKey: groupTypesKey)
        }
    }
    
    // 删除费用类型
    func removeExpenseType(_ type: String) {
        var types = getAllExpenseTypes()
        if let index = types.firstIndex(of: type) {
            types.remove(at: index)
            UserDefaults.standard.set(types, forKey: expenseTypesKey)
        }
    }
    
    // 删除组别类型
    func removeGroupType(_ group: String) {
        var groups = getAllGroupTypes()
        if let index = groups.firstIndex(of: group) {
            groups.remove(at: index)
            UserDefaults.standard.set(groups, forKey: groupTypesKey)
        }
    }
    
    // 重置为默认费用类型
    func resetExpenseTypes() {
        UserDefaults.standard.set(defaultExpenseTypes, forKey: expenseTypesKey)
    }
    
    // 重置为默认组别类型
    func resetGroupTypes() {
        UserDefaults.standard.set(defaultGroupTypes, forKey: groupTypesKey)
    }
}

// 为了兼容性保留原有结构体，但内部使用TagManager
struct ExpenseType {
    static var defaults: [String] {
        return TagManager.shared.getAllExpenseTypes()
    }
}

// 为了兼容性保留原有结构体，但内部使用TagManager
struct GroupType {
    static var defaults: [String] {
        return TagManager.shared.getAllGroupTypes()
    }
}

// 支付方式
struct PaymentMethod {
    static let methods = [
        "现金", "银行转账", "支付宝", "微信", "公司账户", "信用卡", "其他"
    ]
} 