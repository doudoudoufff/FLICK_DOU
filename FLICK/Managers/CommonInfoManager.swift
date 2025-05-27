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
    @Published var projectAccounts: [AccountEntity] = [] // 所有项目账户
    
    init() {
        fetchAllInfos()
        // 添加通知监听，当项目或账户变更时更新数据
        setupNotifications()
    }
    
    // 设置通知监听
    private func setupNotifications() {
        // 监听项目变更通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProjectDataChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchAllInfos()
        }
        
        // 监听CoreData变更通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchAllInfos()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 获取数据
    
    func fetchAllInfos() {
        fetchInfos(for: "公司账户", result: &companyInfos)
        fetchInfos(for: "个人账户", result: &personalInfos)
        fetchProjectAccounts()
        // 注意：不再需要单独获取项目账户CommonInfoEntity，因为我们直接使用AccountEntity
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
    
    // MARK: - 获取项目账户
    
    private func fetchProjectAccounts() {
        let request = AccountEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AccountEntity.project?.name, ascending: true),
            NSSortDescriptor(keyPath: \AccountEntity.name, ascending: true)
        ]
        
        do {
            projectAccounts = try viewContext.fetch(request)
        } catch {
            print("获取项目账户失败: \(error.localizedDescription)")
            projectAccounts = []
        }
    }
    
    // MARK: - 将项目账户转换为常用信息
    
    func convertAccountToCommonInfo(_ account: AccountEntity) -> CommonInfoEntity? {
        guard let accountName = account.name,
              let bankName = account.bankName,
              let bankAccount = account.bankAccount,
              let contactName = account.contactName,
              let contactPhone = account.contactPhone,
              let projectName = account.project?.name else {
            return nil
        }
        
        let content = """
        项目：\(projectName)
        开户行：\(bankName)
        支行：\(account.bankBranch ?? "")
        账号：\(bankAccount)
        联系人：\(contactName)
        电话：\(contactPhone)
        备注：\(account.notes ?? "")
        """
        
        var tag = "其他"
        if let typeStr = account.type {
            switch typeStr {
            case "场地": tag = "场地"
            case "道具": tag = "道具"
            case "服装": tag = "服装"
            case "化妆": tag = "化妆"
            default: tag = "其他"
            }
        }
        
        return addInfo(
            title: accountName,
            type: "项目账户", 
            tag: tag,
            content: content,
            sourceId: account.id?.uuidString
        )
    }
    
    // MARK: - 添加信息
    
    func addInfo(title: String, type: String, tag: String, content: String, isFavorite: Bool = false, sourceId: String? = nil) -> CommonInfoEntity? {
        let newInfo = CommonInfoEntity(context: viewContext)
        newInfo.id = UUID()
        newInfo.title = title
        newInfo.type = type
        newInfo.tag = tag
        newInfo.content = content
        newInfo.isFavorite = isFavorite
        newInfo.dateAdded = Date()
        
        // 存储源账户ID（如果有）
        if let sourceId = sourceId {
            // 我们需要添加一个字段来存储这个ID
            // 使用UserInfo字典来存储额外信息
            let userInfo = ["sourceId": sourceId]
            if let data = try? JSONEncoder().encode(userInfo) {
                newInfo.userData = data
            }
        }
        
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
    
    // MARK: - 收藏/取消收藏项目账户
    
    func toggleFavoriteProjectAccount(_ account: AccountEntity) -> Bool {
        // 查找对应的收藏记录
        let request = CommonInfoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND userData != nil", "项目账户收藏")
        
        do {
            let favorites = try viewContext.fetch(request)
            
            // 查找是否已收藏
            var found = false
            for favorite in favorites {
                if let sourceId = favorite.getSourceAccountId(), sourceId == account.id {
                    // 已收藏，则取消收藏
                    viewContext.delete(favorite)
                    found = true
                    break
                }
            }
            
            // 未收藏，则添加收藏
            if !found {
                let newFavorite = CommonInfoEntity(context: viewContext)
                newFavorite.id = UUID()
                newFavorite.title = account.name
                newFavorite.type = "项目账户收藏"
                newFavorite.tag = account.type ?? "其他"
                newFavorite.isFavorite = true
                newFavorite.dateAdded = Date()
                
                if let id = account.id {
                    newFavorite.setSourceAccountId(id)
                }
            }
            
            try viewContext.save()
            return true
        } catch {
            print("切换项目账户收藏状态失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 检查项目账户是否已收藏
    func isProjectAccountFavorited(_ account: AccountEntity) -> Bool {
        guard let accountId = account.id else { return false }
        
        let request = CommonInfoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@ AND userData != nil", "项目账户收藏")
        
        do {
            let favorites = try viewContext.fetch(request)
            
            for favorite in favorites {
                if let sourceId = favorite.getSourceAccountId(), sourceId == accountId {
                    return true
                }
            }
            
            return false
        } catch {
            print("检查项目账户收藏状态失败: \(error.localizedDescription)")
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