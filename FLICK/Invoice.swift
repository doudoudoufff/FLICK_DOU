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
    var amount: Double      // 开票金额
    var category: Category  // 开票类别
    var status: Status      // 开票状态
    var dueDate: Date?      // 开票截止日期
    var notes: String?      // 备注信息
    var attachments: [Data]? // 附件数据（如发票照片）
    
    enum Category: String, Codable, CaseIterable {
        case location = "场地费"
        case labor = "劳务费"
        case equipment = "设备费"
        case material = "材料费"
        case other = "其他"
    }
    
    enum Status: String, Codable, CaseIterable {
        case pending = "待开票"
        case completed = "已开票"
        case cancelled = "已取消"
    }
    
    init(id: UUID = UUID(),
         name: String,
         phone: String,
         idNumber: String,
         bankAccount: String,
         bankName: String,
         date: Date = Date(),
         amount: Double = 0,
         category: Category = .other,
         status: Status = .pending,
         dueDate: Date? = nil,
         notes: String? = nil,
         attachments: [Data]? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.idNumber = idNumber
        self.bankAccount = bankAccount
        self.bankName = bankName
        self.date = date
        self.amount = amount
        self.category = category
        self.status = status
        self.dueDate = dueDate
        self.notes = notes
        self.attachments = attachments
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
            date: entity.date ?? Date(),
            amount: entity.amount,
            category: Category(rawValue: entity.category ?? "") ?? .other,
            status: Status(rawValue: entity.status ?? "") ?? .pending,
            dueDate: entity.dueDate,
            notes: entity.notes,
            attachments: entity.attachments?.allObjects as? [Data]
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
        entity.amount = amount
        entity.category = category.rawValue
        entity.status = status.rawValue
        entity.dueDate = dueDate
        entity.notes = notes
        if let attachments = attachments {
            entity.attachments = NSSet(array: attachments)
        }
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