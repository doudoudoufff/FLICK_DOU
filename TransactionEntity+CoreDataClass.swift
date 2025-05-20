//
//  TransactionEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/20.
//
//

import Foundation
import CoreData


public class TransactionEntity: NSManagedObject {
    func toModel() -> Transaction? {
        guard let id = self.id,
              let name = self.name,
              let date = self.date,
              let type = self.type
        else { return nil }
        
        var transaction = Transaction(
            id: id,
            name: name,
            amount: self.amount,
            date: date,
            transactionDescription: self.transactionDescription ?? "",
            expenseType: self.expenseType ?? "未分类",
            group: self.group ?? "未分类",
            paymentMethod: self.paymentMethod ?? "现金",
            transactionType: TransactionType(rawValue: type) ?? .expense,
            isVerified: self.isVerified
        )
        
        // 加载附件
        if let attachmentEntities = self.attachments?.allObjects as? [AttachmentEntity],
           let firstAttachment = attachmentEntities.first,
           let attachmentData = firstAttachment.data {
            transaction.attachmentData = attachmentData
        }
        
        return transaction
    }
}
