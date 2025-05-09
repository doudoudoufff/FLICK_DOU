import Foundation
import CoreData

class Invoice: ObservableObject, Identifiable, Codable, Hashable {
    @Published var id: UUID
    @Published var name: String         // 开票人姓名
    @Published var phone: String        // 联系电话
    @Published var idNumber: String     // 身份证号码
    @Published var bankAccount: String  // 银行卡账号
    @Published var bankName: String     // 开户行
    @Published var date: Date          // 记录日期
    @Published var amount: Double      // 开票金额
    @Published var category: Category  // 开票类别
    @Published var status: Status      // 开票状态
    @Published var dueDate: Date?      // 开票截止日期
    @Published var notes: String?      // 备注信息
    @Published var attachments: [Data]? // 附件数据（如发票照片）
    
    // 增值税发票特有字段
    @Published var invoiceCode: String?        // 发票代码
    @Published var invoiceNumber: String?      // 发票号码
    @Published var sellerName: String?         // 销售方名称
    @Published var sellerTaxNumber: String?    // 销售方纳税人识别号
    @Published var sellerAddress: String?      // 销售方地址电话
    @Published var sellerBankInfo: String?     // 销售方开户行及账号
    @Published var buyerAddress: String?       // 购买方地址电话
    @Published var buyerBankInfo: String?      // 购买方开户行及账号
    @Published var goodsList: [String]?        // 商品名称列表
    @Published var totalAmount: Double?        // 价税合计
    
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, phone, idNumber, bankAccount, bankName, date, amount, category, status, dueDate, notes, attachments, invoiceCode, invoiceNumber, sellerName, sellerTaxNumber, sellerAddress, sellerBankInfo, buyerAddress, buyerBankInfo, goodsList, totalAmount
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        idNumber = try container.decode(String.self, forKey: .idNumber)
        bankAccount = try container.decode(String.self, forKey: .bankAccount)
        bankName = try container.decode(String.self, forKey: .bankName)
        date = try container.decode(Date.self, forKey: .date)
        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decode(Category.self, forKey: .category)
        status = try container.decode(Status.self, forKey: .status)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        attachments = try container.decodeIfPresent([Data].self, forKey: .attachments)
        invoiceCode = try container.decodeIfPresent(String.self, forKey: .invoiceCode)
        invoiceNumber = try container.decodeIfPresent(String.self, forKey: .invoiceNumber)
        sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName)
        sellerTaxNumber = try container.decodeIfPresent(String.self, forKey: .sellerTaxNumber)
        sellerAddress = try container.decodeIfPresent(String.self, forKey: .sellerAddress)
        sellerBankInfo = try container.decodeIfPresent(String.self, forKey: .sellerBankInfo)
        buyerAddress = try container.decodeIfPresent(String.self, forKey: .buyerAddress)
        buyerBankInfo = try container.decodeIfPresent(String.self, forKey: .buyerBankInfo)
        goodsList = try container.decodeIfPresent([String].self, forKey: .goodsList)
        totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(idNumber, forKey: .idNumber)
        try container.encode(bankAccount, forKey: .bankAccount)
        try container.encode(bankName, forKey: .bankName)
        try container.encode(date, forKey: .date)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encodeIfPresent(invoiceCode, forKey: .invoiceCode)
        try container.encodeIfPresent(invoiceNumber, forKey: .invoiceNumber)
        try container.encodeIfPresent(sellerName, forKey: .sellerName)
        try container.encodeIfPresent(sellerTaxNumber, forKey: .sellerTaxNumber)
        try container.encodeIfPresent(sellerAddress, forKey: .sellerAddress)
        try container.encodeIfPresent(sellerBankInfo, forKey: .sellerBankInfo)
        try container.encodeIfPresent(buyerAddress, forKey: .buyerAddress)
        try container.encodeIfPresent(buyerBankInfo, forKey: .buyerBankInfo)
        try container.encodeIfPresent(goodsList, forKey: .goodsList)
        try container.encodeIfPresent(totalAmount, forKey: .totalAmount)
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
         attachments: [Data]? = nil,
         invoiceCode: String? = nil,
         invoiceNumber: String? = nil,
         sellerName: String? = nil,
         sellerTaxNumber: String? = nil,
         sellerAddress: String? = nil,
         sellerBankInfo: String? = nil,
         buyerAddress: String? = nil,
         buyerBankInfo: String? = nil,
         goodsList: [String]? = nil,
         totalAmount: Double? = nil) {
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
        self.invoiceCode = invoiceCode
        self.invoiceNumber = invoiceNumber
        self.sellerName = sellerName
        self.sellerTaxNumber = sellerTaxNumber
        self.sellerAddress = sellerAddress
        self.sellerBankInfo = sellerBankInfo
        self.buyerAddress = buyerAddress
        self.buyerBankInfo = buyerBankInfo
        self.goodsList = goodsList
        self.totalAmount = totalAmount
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
            attachments: entity.attachments?.allObjects as? [Data],
            invoiceCode: entity.invoiceCode,
            invoiceNumber: entity.invoiceNumber,
            sellerName: entity.sellerName,
            sellerTaxNumber: entity.sellerTaxNumber,
            sellerAddress: entity.sellerAddress,
            sellerBankInfo: entity.sellerBankInfo,
            buyerAddress: entity.buyerAddress,
            buyerBankInfo: entity.buyerBankInfo,
            goodsList: entity.goodsList?.components(separatedBy: ","),
            totalAmount: entity.totalAmount > 0 ? entity.totalAmount : nil
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
        entity.invoiceCode = invoiceCode
        entity.invoiceNumber = invoiceNumber
        entity.sellerName = sellerName
        entity.sellerTaxNumber = sellerTaxNumber
        entity.sellerAddress = sellerAddress
        entity.sellerBankInfo = sellerBankInfo
        entity.buyerAddress = buyerAddress
        entity.buyerBankInfo = buyerBankInfo
        entity.goodsList = goodsList?.joined(separator: ",")
        entity.totalAmount = totalAmount ?? 0.0
        
        if let attachments = attachments {
            entity.attachments = NSSet(array: attachments)
        }
        return entity
    }
    
    // 工具方法：对发票数组按日期倒序排序
    static func sortedByDate(_ invoices: [Invoice]) -> [Invoice] {
        invoices.sorted { $0.date > $1.date }
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