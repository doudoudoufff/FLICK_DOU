import Foundation
import CoreData
import SwiftUI

class CommonInfoManager: ObservableObject {
    private let persistenceController = PersistenceController.shared
    private var viewContext: NSManagedObjectContext {
        return persistenceController.container.viewContext
    }
    
    @Published var projectInfos: [CommonInfoEntity] = []
    @Published var companyInfos: [CommonInfoEntity] = []
    @Published var personalInfos: [CommonInfoEntity] = []
    
    init() {
        fetchAllInfos()
    }
    
    // MARK: - 获取数据
    
    func fetchAllInfos() {
        fetchInfos(for: "项目账户", result: &projectInfos)
        fetchInfos(for: "公司账户", result: &companyInfos)
        fetchInfos(for: "个人账户", result: &personalInfos)
    }
    
    private func fetchInfos(for type: String, result: inout [CommonInfoEntity]) {
        let request = CommonInfoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CommonInfoEntity.dateAdded, ascending: false)]
        
        do {
            result = try viewContext.fetch(request)
        } catch {
            print("获取常用信息失败: \(error.localizedDescription)")
            result = []
        }
    }
    
    // MARK: - 添加信息
    
    func addInfo(title: String, type: String, tag: String, content: String, isFavorite: Bool = false) -> CommonInfoEntity? {
        let newInfo = CommonInfoEntity(context: viewContext)
        newInfo.id = UUID()
        newInfo.title = title
        newInfo.type = type
        newInfo.tag = tag
        newInfo.content = content
        newInfo.isFavorite = isFavorite
        newInfo.dateAdded = Date()
        
        do {
            try viewContext.save()
            fetchAllInfos()
            return newInfo
        } catch {
            print("添加常用信息失败: \(error.localizedDescription)")
            viewContext.rollback()
            return nil
        }
    }
    
    // MARK: - 更新信息
    
    func updateInfo(info: CommonInfoEntity, title: String, tag: String, content: String) -> Bool {
        info.title = title
        info.tag = tag
        info.content = content
        
        do {
            try viewContext.save()
            fetchAllInfos()
            return true
        } catch {
            print("更新常用信息失败: \(error.localizedDescription)")
            viewContext.rollback()
            return false
        }
    }
    
    // MARK: - 删除信息
    
    func deleteInfo(_ info: CommonInfoEntity) -> Bool {
        viewContext.delete(info)
        
        do {
            try viewContext.save()
            fetchAllInfos()
            return true
        } catch {
            print("删除常用信息失败: \(error.localizedDescription)")
            viewContext.rollback()
            return false
        }
    }
    
    // MARK: - 切换收藏状态
    
    func toggleFavorite(_ info: CommonInfoEntity) -> Bool {
        info.isFavorite.toggle()
        
        do {
            try viewContext.save()
            fetchAllInfos()
            return true
        } catch {
            print("切换收藏状态失败: \(error.localizedDescription)")
            viewContext.rollback()
            return false
        }
    }
    
    // MARK: - 辅助方法
    
    func getInfoEntity(by id: UUID) -> CommonInfoEntity? {
        let request = CommonInfoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("获取特定常用信息失败: \(error.localizedDescription)")
            return nil
        }
    }
} 