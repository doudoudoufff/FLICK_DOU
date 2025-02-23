//
//  AccountEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData
import SwiftUI

public class AccountEntity: NSManagedObject {
    func toModel() -> Account? {
        guard let id = self.id,
              let name = self.name,
              let type = self.type,
              let bankName = self.bankName,
              let bankBranch = self.bankBranch,
              let bankAccount = self.bankAccount,
              let contactName = self.contactName,
              let contactPhone = self.contactPhone,
              let typeEnum = FLICK.AccountType(rawValue: type)
        else { return nil }
        
        return Account(
            id: id,
            name: name,
            type: typeEnum,
            bankName: bankName,
            bankBranch: bankBranch,
            bankAccount: bankAccount,
            idNumber: idNumber,
            contactName: contactName,
            contactPhone: contactPhone,
            notes: notes
        )
    }
}
