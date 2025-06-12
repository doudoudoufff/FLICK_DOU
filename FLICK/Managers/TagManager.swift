import Foundation
import SwiftUI
import CoreData
import Combine

// 标签类型枚举
enum TagCategoryType: String, CaseIterable {
    case expenseType = "expense"   // 费用类型标签
    case groupType = "group"       // 组别标签
    case infoType = "info"         // 常用信息标签
    
    var displayName: String {
        switch self {
        case .expenseType: return "费用类型"
        case .groupType: return "组别"
        case .infoType: return "常用信息"
        }
    }
    
    var defaultTags: [String] {
        switch self {
        case .expenseType:
            return ["交通", "餐饮", "杂支", "差旅", "住宿", "器材", "场地", "演员费用", "后期制作", "其他"]
        case .groupType:
            return ["制片组", "摄影组", "灯光组", "场务组", "道具组", "演员组", "美术组", "后期组", "导演组", "其他"]
        case .infoType:
            return ["银行账户", "发票", "地址", "常用供应商", "其他"]
        }
    }
}

// 统一的标签管理器 - 使用CoreData存储
class CustomTagManager: ObservableObject {
    // 单例模式
    static let shared = CustomTagManager()
    
    // 持久化上下文
    private var context: NSManagedObjectContext {
        return PersistenceController.shared.container.viewContext
    }
    
    // 私有初始化方法
    private init() {
        // 初始化时确保所有类型的默认标签存在
        ensureDefaultTags()
    }
    
    // 确保默认标签存在
    private func ensureDefaultTags() {
        for tagType in TagCategoryType.allCases {
            // 检查该类型是否已有标签
            let tagCount = countTags(ofType: tagType)
            
            // 如果没有标签，添加默认标签
            if tagCount == 0 {
                addDefaultTags(for: tagType)
            }
        }
    }
    
    // 为指定类型添加默认标签
    private func addDefaultTags(for tagType: TagCategoryType) {
        for (index, name) in tagType.defaultTags.enumerated() {
            let tag = TagEntity(context: context)
            tag.id = UUID()
            tag.name = name
            tag.tagType = tagType.rawValue
            tag.dateAdded = Date()
            tag.order = Int32(index)
            tag.isDefault = true
            
            // 设置默认颜色
            tag.colorHex = defaultColorHex(for: name)
        }
        
        // 保存上下文
        saveContext()
    }
    
    // 获取标签默认颜色的十六进制字符串
    private func defaultColorHex(for tagName: String) -> String {
        switch tagName {
        case "银行账户": return "#007AFF" // 蓝色
        case "发票": return "#34C759"     // 绿色
        case "地址": return "#AF52DE"     // 紫色
        case "常用供应商": return "#FF9500" // 橙色
        case "交通": return "#FF3B30"     // 红色
        case "餐饮": return "#5856D6"     // 深蓝色
        case "住宿": return "#5AC8FA"     // 浅蓝色
        case "器材": return "#FF2D55"     // 粉色
        case "制片组": return "#007AFF"    // 蓝色
        case "摄影组": return "#34C759"    // 绿色
        case "灯光组": return "#FFCC00"    // 黄色
        default: return "#8E8E93"        // 灰色
        }
    }
    
    // 获取颜色从十六进制字符串
    func color(from hex: String?) -> Color {
        guard let hex = hex else { return .gray }
        
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    // 保存上下文
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                // 触发UI更新
                objectWillChange.send()
                // 同步到iCloud
                PersistenceController.shared.save()
            } catch {
                print("❌ 保存标签失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 标签查询方法
    
    // 获取指定类型的所有标签
    func getAllTags(ofType type: TagCategoryType) -> [TagEntity] {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tagType == %@", type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TagEntity.order, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ 获取标签失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取指定类型的所有标签名称
    func getAllTagNames(ofType type: TagCategoryType) -> [String] {
        return getAllTags(ofType: type).compactMap { $0.name }
    }
    
    // 计算指定类型的标签数量
    func countTags(ofType type: TagCategoryType) -> Int {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tagType == %@", type.rawValue)
        
        do {
            return try context.count(for: request)
        } catch {
            print("❌ 计数标签失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - 标签修改方法
    
    // 添加新标签
    func addTag(name: String, type: TagCategoryType, colorHex: String? = nil) -> TagEntity? {
        // 检查是否已存在同名标签
        if tagExists(name: name, type: type) {
            return nil
        }
        
        // 获取当前最大的order值
        let maxOrder = getMaxOrder(for: type)
        
        // 创建新标签
        let newTag = TagEntity(context: context)
        newTag.id = UUID()
        newTag.name = name
        newTag.tagType = type.rawValue
        newTag.dateAdded = Date()
        newTag.order = maxOrder + 1
        newTag.isDefault = false
        newTag.colorHex = colorHex ?? defaultColorHex(for: name)
        
        // 保存上下文
        saveContext()
        return newTag
    }
    
    // 获取当前最大的order值
    private func getMaxOrder(for type: TagCategoryType) -> Int32 {
        let tags = getAllTags(ofType: type)
        return tags.map { $0.order }.max() ?? 0
    }
    
    // 检查标签是否已存在
    func tagExists(name: String, type: TagCategoryType) -> Bool {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND tagType == %@", name, type.rawValue)
        
        do {
            return try context.count(for: request) > 0
        } catch {
            print("❌ 检查标签是否存在失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 删除标签
    func removeTag(name: String, type: TagCategoryType) -> Bool {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND tagType == %@", name, type.rawValue)
        
        do {
            let results = try context.fetch(request)
            if let tag = results.first {
                // 检查是否是默认标签
                if tag.isDefault {
                    print("⚠️ 不能删除默认标签")
                    return false
                }
                
                context.delete(tag)
                saveContext()
                return true
            }
            return false
        } catch {
            print("❌ 删除标签失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 重置标签为默认值
    func resetTags(forType type: TagCategoryType) {
        // 删除所有指定类型的标签
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tagType == %@", type.rawValue)
        
        do {
            let results = try context.fetch(request)
            for tag in results {
                context.delete(tag)
            }
            
            // 添加默认标签
            addDefaultTags(for: type)
            
            // 保存上下文
            saveContext()
        } catch {
            print("❌ 重置标签失败: \(error.localizedDescription)")
        }
    }
    
    // 根据标签名称获取颜色
    func tagColor(for name: String, type: TagCategoryType) -> Color {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND tagType == %@", name, type.rawValue)
        
        do {
            let results = try context.fetch(request)
            if let tag = results.first {
                return color(from: tag.colorHex)
            }
        } catch {
            print("❌ 获取标签颜色失败: \(error.localizedDescription)")
        }
        
        // 如果找不到标签，返回默认颜色
        return .gray
    }
    
    // 更新标签颜色
    func updateTagColor(name: String, type: TagCategoryType, color: Color) {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND tagType == %@", name, type.rawValue)
        
        do {
            let results = try context.fetch(request)
            if let tag = results.first {
                // 将Color转换为十六进制字符串
                let uiColor = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let hexString = String(
                    format: "#%02X%02X%02X",
                    Int(r * 255),
                    Int(g * 255),
                    Int(b * 255)
                )
                
                tag.colorHex = hexString
                saveContext()
            }
        } catch {
            print("❌ 更新标签颜色失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 兼容性扩展方法
    
    // 费用类型相关方法
    func getAllExpenseTypes() -> [String] {
        return getAllTagNames(ofType: .expenseType)
    }
    
    func addExpenseType(_ type: String) {
        _ = addTag(name: type, type: .expenseType)
    }
    
    func removeExpenseType(_ type: String) {
        _ = removeTag(name: type, type: .expenseType)
    }
    
    func resetExpenseTypes() {
        resetTags(forType: .expenseType)
    }
    
    // 组别相关方法
    func getAllGroupTypes() -> [String] {
        return getAllTagNames(ofType: .groupType)
    }
    
    func addGroupType(_ group: String) {
        _ = addTag(name: group, type: .groupType)
    }
    
    func removeGroupType(_ group: String) {
        _ = removeTag(name: group, type: .groupType)
    }
    
    func resetGroupTypes() {
        resetTags(forType: .groupType)
    }
    
    // 常用信息标签相关方法
    func getAllInfoTags() -> [String] {
        return getAllTagNames(ofType: .infoType)
    }
    
    func addInfoTag(_ tag: String) {
        _ = addTag(name: tag, type: .infoType)
    }
    
    func removeInfoTag(_ tag: String) {
        _ = removeTag(name: tag, type: .infoType)
    }
    
    func resetInfoTags() {
        resetTags(forType: .infoType)
    }
    
    // 根据标签名称获取颜色 - 常用信息标签版本
    func tagColor(for tag: String) -> Color {
        return tagColor(for: tag, type: .infoType)
    }
}

// 为兼容性提供别名
typealias TagManager = CustomTagManager 