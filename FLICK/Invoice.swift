import Foundation
import CoreData

struct Invoice: Identifiable, Codable, Hashable {
    let id: UUID
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
    
    // 添加 Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Invoice, rhs: Invoice) -> Bool {
        lhs.id == rhs.id
    }
}

extension Invoice {
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