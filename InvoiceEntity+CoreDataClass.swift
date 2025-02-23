//
//  InvoiceEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData


public class InvoiceEntity: NSManagedObject {
    func toModel() -> Invoice? {
        guard let id = self.id,
              let name = self.name,
              let phone = self.phone,
              let idNumber = self.idNumber,
              let bankAccount = self.bankAccount,
              let bankName = self.bankName,
              let date = self.date
        else { return nil }
        
        return Invoice(
            id: id,
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date
        )
    }
}
