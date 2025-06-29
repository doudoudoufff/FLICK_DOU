import Foundation
import SwiftUI
import CoreData

class Project: ObservableObject, Identifiable, Codable, Hashable {
    let id: UUID
    @Published var name: String
    @Published var director: String
    @Published var producer: String
    @Published var startDate: Date
    @Published var status: Status
    @Published var color: Color {
        didSet {
            // 当颜色发生变化时，确保通知观察者
            objectWillChange.send()
        }
    }
    @Published var tasks: [ProjectTask]
    @Published var invoices: [Invoice]
    @Published var locations: [Location]  // 确保 locations 在 accounts 之前
    @Published var accounts: [Account]
    @Published var transactions: [Transaction] // 添加交易记录
    @Published var isLocationScoutingEnabled: Bool
    @Published var logoData: Data? // 项目LOGO数据
    @Published var budget: Double // 项目预算
    
    // 计算预算使用百分比
    var budgetUsagePercentage: Double {
        guard budget > 0 else { return 0 }
        let totalExpense = transactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + abs($1.amount) }  // 支出amount为负值，取绝对值
        
        // 预算使用百分比只考虑支出占预算的比例，不考虑收入
        return min((totalExpense / budget) * 100, 100)  // 限制最大值为100%
    }
    
    // 计算总收入
    var totalIncome: Double {
        transactions
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    // 计算剩余预算
    var remainingBudget: Double {
        let totalExpense = transactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + abs($1.amount) }  // 支出amount为负值，取绝对值
        return budget - totalExpense  // 剩余预算只考虑支出，不考虑收入
    }
    
    public enum Status: String, Codable, CaseIterable {
        case inProgress = "进行中"
        case completed = "完成"
        case cancelled = "取消"
        
        public static var all: Self { .inProgress }  // 用于过滤器
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        director: String = "",
        producer: String = "",
        startDate: Date = Date(),
        status: Status = .inProgress,
        color: Color = .blue,
        tasks: [ProjectTask] = [],
        invoices: [Invoice] = [],
        locations: [Location] = [],  // 确保 locations 在 accounts 之前
        accounts: [Account] = [],
        transactions: [Transaction] = [], // 添加交易记录
        isLocationScoutingEnabled: Bool = false,
        logoData: Data? = nil,
        budget: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.director = director
        self.producer = producer
        self.startDate = startDate
        self.status = status
        self.color = color
        self.tasks = tasks
        self.invoices = invoices
        self.locations = locations  // 确保顺序一致
        self.accounts = accounts
        self.transactions = transactions // 添加交易记录
        self.isLocationScoutingEnabled = isLocationScoutingEnabled
        self.logoData = logoData
        self.budget = budget
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, director, producer, startDate, status
        case color, tasks, invoices, locations, accounts, transactions
        case isLocationScoutingEnabled, logoData, budget
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        director = try container.decode(String.self, forKey: .director)
        producer = try container.decode(String.self, forKey: .producer)
        startDate = try container.decode(Date.self, forKey: .startDate)
        status = try container.decode(Status.self, forKey: .status)
        color = try container.decode(Color.self, forKey: .color)
        tasks = try container.decode([ProjectTask].self, forKey: .tasks)
        invoices = try container.decode([Invoice].self, forKey: .invoices)
        locations = try container.decode([Location].self, forKey: .locations)
        accounts = try container.decode([Account].self, forKey: .accounts)
        transactions = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        isLocationScoutingEnabled = try container.decode(Bool.self, forKey: .isLocationScoutingEnabled)
        logoData = try container.decodeIfPresent(Data.self, forKey: .logoData)
        budget = try container.decodeIfPresent(Double.self, forKey: .budget) ?? 0.0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(director, forKey: .director)
        try container.encode(producer, forKey: .producer)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(status, forKey: .status)
        try container.encode(color, forKey: .color)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(invoices, forKey: .invoices)
        try container.encode(locations, forKey: .locations)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(isLocationScoutingEnabled, forKey: .isLocationScoutingEnabled)
        try container.encodeIfPresent(logoData, forKey: .logoData)
        try container.encode(budget, forKey: .budget)
    }
    
    func toEntity(context: NSManagedObjectContext) -> ProjectEntity {
        let entity = ProjectEntity(context: context)
        entity.id = id
        entity.name = name
        entity.director = director
        entity.producer = producer
        entity.startDate = startDate
        entity.status = status.rawValue
        entity.color = color.toHex()
        entity.isLocationScoutingEnabled = isLocationScoutingEnabled
        entity.logoData = logoData
        
        // 设置预算值并添加明确调试日志
        print("Project.toEntity - 项目 \(name) 设置预算值: \(budget)")
        entity.budget = budget
        print("Project.toEntity - 设置后实体预算值: \(entity.budget)")
        
        return entity
    }
    
    // 从 CoreData 实体转换为模型
    static func fromEntity(_ entity: ProjectEntity) -> Project? {
        // 确保必需的属性都存在
        guard let id = entity.id,
              let name = entity.name,
              let status = entity.status,
              let startDate = entity.startDate
        else {
            return nil
        }
        
        // 打印预算值（调试）
        print("Project.fromEntity - 加载预算值: \(entity.budget)")
        
        // 颜色读取日志 - 使用Hex字符串
        let color: Color = {
            if let colorHex = entity.color {
                print("Project.fromEntity - CoreData读取到colorHex: \(colorHex)")
                let color = Color(hex: colorHex) ?? .blue
                print("Project.fromEntity - 还原出来的颜色Hex: \(color.toHex())")
                return color
            } else {
                print("Project.fromEntity - CoreData中没有color字段，使用默认蓝色")
                return .blue
            }
        }()
        
        let tasks: [ProjectTask] = (entity.tasks?.allObjects as? [TaskEntity])?.compactMap { taskEntity in
            guard let task = taskEntity as? TaskEntity else { return nil }
            return ProjectTask.fromEntity(task)
        } ?? []
        
        let invoices = (entity.invoices?.allObjects as? [InvoiceEntity])?.map(Invoice.fromEntity) ?? []
        
        // 注意：实际项目中需要从 CoreData 中加载 transactions 和自定义类型
        
        let project = Project(
            id: id,
            name: name,
            director: entity.director ?? "",
            producer: entity.producer ?? "",
            startDate: startDate,
            status: Status(rawValue: status) ?? .inProgress,
            color: color,
            tasks: tasks,
            invoices: invoices,
            locations: [],
            accounts: [],
            transactions: [], // 添加空的交易记录数组
            isLocationScoutingEnabled: entity.isLocationScoutingEnabled,
            logoData: entity.logoData,
            budget: entity.budget // 确保预算值被传递到Project对象
        )
        
        // 添加预算值调试日志
        print("Project实例化后的预算值: \(project.budget)")
        
        // 确保打印出状态，以便调试
        
        return project
    }
    
    // 在 CoreData 中查找对应的实体
    func fetchEntity(in context: NSManagedObjectContext) -> ProjectEntity? {
        let request = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    // 创建一个占位项目，用于处理已删除项目的情况
    static func placeholder() -> Project {
        return Project(
            id: UUID(),
            name: "项目已删除",
            director: "",
            producer: "",
            startDate: Date(),
            status: .cancelled,
            color: .gray,
            tasks: [],
            invoices: [],
            locations: [],
            accounts: [],
            transactions: [],
            isLocationScoutingEnabled: false,
            logoData: nil,
            budget: 0.0
        )
    }
    
    // 从 CoreData 实体初始化
    convenience init(entity: ProjectEntity) {
        guard let id = entity.id,
              let name = entity.name,
              let status = entity.status,
              let startDate = entity.startDate
        else {
            self.init(name: "无效项目")
            return
        }
        
        self.init(
            id: id,
            name: name,
            director: entity.director ?? "",
            producer: entity.producer ?? "",
            startDate: startDate,
            status: Status(rawValue: status) ?? .inProgress,
            color: Color(hex: entity.color ?? "#1976D2") ?? .blue,
            tasks: [],
            invoices: [],
            locations: [],
            accounts: [],
            transactions: [],
            isLocationScoutingEnabled: entity.isLocationScoutingEnabled,
            logoData: entity.logoData,
            budget: entity.budget
        )
    }
} 