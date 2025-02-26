import Foundation
import CoreData

struct Invoice: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String         // 开票人姓名
    var phone: String        // 联系电话
    var idNumber: String     // 身份证号码
    var bankAccount: String  // 银行卡账号
    var bankName: String     // 开户行
    var date: Date          // 记录日期
    
    init(id: UUID = UUID(),
         name: String,
         phone: String,
         idNumber: String,
         bankAccount: String,
         bankName: String,
         date: Date = Date()) {
        self.id = id
        self.name = name
        self.phone = phone
        self.idNumber = idNumber
        self.bankAccount = bankAccount
        self.bankName = bankName
        self.date = date
    }
}

// MARK: - CoreData 转换
extension Invoice {
    // 从 CoreData 实体转换为模型
    static func fromEntity(_ entity: InvoiceEntity) -> Invoice {
        Invoice(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            phone: entity.phone ?? "",
            idNumber: entity.idNumber ?? "",
            bankAccount: entity.bankAccount ?? "",
            bankName: entity.bankName ?? "",
            date: entity.date ?? Date()
        )
    }
    
    // 转换为 CoreData 实体
    func toEntity(context: NSManagedObjectContext) -> InvoiceEntity {
        let entity = InvoiceEntity(context: context)
        entity.id = id
        entity.name = name
        entity.phone = phone
        entity.idNumber = idNumber
        entity.bankAccount = bankAccount
        entity.bankName = bankName
        entity.date = date
        return entity
    }
}

// MARK: - Hashable
extension Invoice {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Invoice, rhs: Invoice) -> Bool {
        lhs.id == rhs.id
    }
} 