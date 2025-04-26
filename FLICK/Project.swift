import Foundation
import SwiftUI
import CoreData

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var director: String
    var producer: String
    var startDate: Date
    var status: Status
    var color: Color
    var tasks: [ProjectTask]
    var invoices: [Invoice]
    var locations: [Location]  // 确保 locations 在 accounts 之前
    var accounts: [Account]
    var isLocationScoutingEnabled: Bool
    var logoData: Data? // 项目LOGO数据
    
    public enum Status: String, Codable, CaseIterable {
        case preProduction = "前期"
        case production = "拍摄"
        case postProduction = "后期"
        case completed = "完成"
        case cancelled = "取消"
        
        public static var all: Self { .preProduction }  // 用于过滤器
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        director: String = "",
        producer: String = "",
        startDate: Date = Date(),
        status: Status = .preProduction,
        color: Color = .blue,
        tasks: [ProjectTask] = [],
        invoices: [Invoice] = [],
        locations: [Location] = [],  // 确保 locations 在 accounts 之前
        accounts: [Account] = [],
        isLocationScoutingEnabled: Bool = false,
        logoData: Data? = nil
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
        self.isLocationScoutingEnabled = isLocationScoutingEnabled
        self.logoData = logoData
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, director, producer, startDate, status
        case color, tasks, invoices, locations, accounts
        case isLocationScoutingEnabled, logoData
    }
    
    init(from decoder: Decoder) throws {
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
        isLocationScoutingEnabled = try container.decode(Bool.self, forKey: .isLocationScoutingEnabled)
        logoData = try container.decodeIfPresent(Data.self, forKey: .logoData)
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
        try container.encode(isLocationScoutingEnabled, forKey: .isLocationScoutingEnabled)
        try container.encodeIfPresent(logoData, forKey: .logoData)
    }
    
    func toEntity(context: NSManagedObjectContext) -> ProjectEntity {
        let entity = ProjectEntity(context: context)
        entity.id = id
        entity.name = name
        entity.director = director
        entity.producer = producer
        entity.startDate = startDate
        entity.status = status.rawValue
        entity.color = color.toData()
        entity.isLocationScoutingEnabled = isLocationScoutingEnabled
        entity.logoData = logoData
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
        
        let tasks: [ProjectTask] = (entity.tasks?.allObjects as? [TaskEntity])?.compactMap { taskEntity in
            guard let task = taskEntity as? TaskEntity else { return nil }
            return ProjectTask.fromEntity(task)
        } ?? []
        
        let invoices = (entity.invoices?.allObjects as? [InvoiceEntity])?.map(Invoice.fromEntity) ?? []
        
        return Project(
            id: id,
            name: name,
            director: entity.director ?? "",
            producer: entity.producer ?? "",
            startDate: startDate,
            status: Status(rawValue: status) ?? .preProduction,
            color: entity.color.flatMap(Color.init(data:)) ?? .blue,
            tasks: tasks,
            invoices: invoices,
            locations: [],
            accounts: [],
            isLocationScoutingEnabled: entity.isLocationScoutingEnabled,
            logoData: entity.logoData
        )
    }
    
    // 在 CoreData 中查找对应的实体
    func fetchEntity(in context: NSManagedObjectContext) -> ProjectEntity? {
        let request = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

// 添加 Color 扩展来支持十六进制转换
extension Color {
    func toHex() -> UInt? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = UInt(components[0] * 255.0)
        let g = UInt(components[1] * 255.0)
        let b = UInt(components[2] * 255.0)
        
        return (r << 16) + (g << 8) + b
    }
    
    init?(hex: UInt) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
} 