import Foundation
import SwiftUI

// 将 Project 重命名为 ProjectModel
struct ProjectModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var director: String
    var producer: String
    var startDate: Date
    var endDate: Date?
    var status: ProjectStatus
    var color: Color
    var tasks: [Task]
    var invoices: [Invoice]
    var accounts: [Account]
    var isLocationScoutingEnabled: Bool
    var locations: [Location] = []
    
    enum ProjectStatus: Int, Codable {
        case all = -1 // 用于筛选
        case preProduction = 0
        case production = 1
        case postProduction = 2
        
        var description: String {
            switch self {
            case .all: return "全部"
            case .preProduction: return "筹备"
            case .production: return "拍摄"
            case .postProduction: return "后期"
            }
        }
    }
    
    init(id: UUID = UUID(),
         name: String = "",
         director: String = "",
         producer: String = "",
         startDate: Date = Date(),
         endDate: Date? = nil,
         status: ProjectStatus = .preProduction,
         color: Color = .blue,
         tasks: [Task] = [],
         invoices: [Invoice] = [],
         accounts: [Account] = [],
         isLocationScoutingEnabled: Bool = false,
         locations: [Location] = []) {
        self.id = id
        self.name = name
        self.director = director
        self.producer = producer
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.color = color
        self.tasks = tasks
        self.invoices = invoices
        self.accounts = accounts
        self.isLocationScoutingEnabled = isLocationScoutingEnabled
        self.locations = locations
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ProjectModel, rhs: ProjectModel) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, director, producer, startDate, endDate, status, 
             colorHex, tasks, invoices, accounts, isLocationScoutingEnabled, 
             locations
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        director = try container.decode(String.self, forKey: .director)
        producer = try container.decode(String.self, forKey: .producer)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        status = try container.decode(ProjectStatus.self, forKey: .status)
        tasks = try container.decode([Task].self, forKey: .tasks)
        invoices = try container.decode([Invoice].self, forKey: .invoices)
        accounts = try container.decode([Account].self, forKey: .accounts)
        isLocationScoutingEnabled = try container.decode(Bool.self, forKey: .isLocationScoutingEnabled)
        locations = try container.decode([Location].self, forKey: .locations)
        
        // 解码颜色
        let colorHex = try container.decode(UInt.self, forKey: .colorHex)
        color = Color(hex: colorHex) ?? .blue
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(director, forKey: .director)
        try container.encode(producer, forKey: .producer)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(status, forKey: .status)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(invoices, forKey: .invoices)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(isLocationScoutingEnabled, forKey: .isLocationScoutingEnabled)
        try container.encode(locations, forKey: .locations)
        
        // 编码颜色
        let colorHex = color.toHex() ?? 0x0000FF // 默认蓝色
        try container.encode(colorHex, forKey: .colorHex)
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