import Foundation
import CoreData

// 将 AccountType 移到外部，并添加 public 访问级别
public enum AccountType: String, Codable, CaseIterable {
    case bankAccount = "银行账户"
    case invoice = "发票"
    case address = "地址"
    case supplier = "常用供应商"
    case other = "其他"
}

struct Account: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String            // 收款方名称
    var type: AccountType       // 账户类型
    
    // 银行信息
    var bankName: String        // 开户行
    var bankBranch: String      // 支行
    var bankAccount: String     // 账号
    var idNumber: String?       // 身份证号（可选，公司可能不需要）
    
    // 联系方式
    var contactName: String     // 联系人
    var contactPhone: String    // 联系电话
    
    var notes: String?          // 备注
    
    init(id: UUID = UUID(),
         name: String,
         type: AccountType,
         bankName: String,
         bankBranch: String,
         bankAccount: String,
         idNumber: String? = nil,
         contactName: String,
         contactPhone: String,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.bankName = bankName
        self.bankBranch = bankBranch
        self.bankAccount = bankAccount
        self.idNumber = idNumber
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.notes = notes
    }
}

extension Account {
    func toEntity(context: NSManagedObjectContext) -> AccountEntity {
        let entity = AccountEntity(context: context)
        entity.id = id
        entity.name = name
        entity.type = type.rawValue
        entity.bankName = bankName
        entity.bankBranch = bankBranch
        entity.bankAccount = bankAccount
        entity.contactName = contactName
        entity.contactPhone = contactPhone
        entity.notes = notes
        return entity
    }
    
    static func fromEntity(_ entity: AccountEntity) -> Account? {
        guard let id = entity.id,
              let name = entity.name,
              let typeString = entity.type,
              let type = AccountType(rawValue: typeString),
              let bankName = entity.bankName,
              let bankBranch = entity.bankBranch,
              let bankAccount = entity.bankAccount,
              let contactName = entity.contactName,
              let contactPhone = entity.contactPhone else {
            return nil
        }
        
        return Account(
            id: id,
            name: name,
            type: type,
            bankName: bankName,
            bankBranch: bankBranch,
            bankAccount: bankAccount,
            contactName: contactName,
            contactPhone: contactPhone,
            notes: entity.notes
        )
    }
} 