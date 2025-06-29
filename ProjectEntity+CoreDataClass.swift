//
//  ProjectEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/2/23.
//
//

import Foundation
import CoreData
import SwiftUI
import UIKit

public class ProjectEntity: NSManagedObject {
    func toModel() -> Project? {
        guard let id = self.id,
              let name = self.name,
              let director = self.director,
              let producer = self.producer,
              let startDate = self.startDate,
              let status = self.status,
              let statusEnum = Project.Status(rawValue: status)
        else { return nil }
        
        // 转换 tasks
        let tasksArray = (tasks?.allObjects as? [TaskEntity])?
            .compactMap { $0.toModel() } ?? []
            
        // 转换 invoices
        let invoicesArray = (invoices?.allObjects as? [InvoiceEntity])?
            .compactMap { $0.toModel() } ?? []
            
        // 转换 locations
        let locationsArray = (locations?.allObjects as? [LocationEntity])?
            .compactMap { $0.toModel() } ?? []
            
        // 转换 accounts
        let accountsArray = (accounts?.allObjects as? [AccountEntity])?
            .compactMap { $0.toModel() } ?? []
            
        // 转换 transactions
        let transactionsArray = (transactions?.allObjects as? [TransactionEntity])?
            .compactMap { $0.toModel() } ?? []
        
        // 处理颜色转换
        let projectColor: Color = {
            if let colorHex = color {
                return Color(hex: colorHex) ?? .blue
            }
            return .blue
        }()
        
        // 打印预算值（用于调试）
        print("ProjectEntity.toModel - 加载预算值: \(budget)")
        
        return Project(
            id: id,
            name: name,
            director: director,
            producer: producer,
            startDate: startDate,
            status: statusEnum,
            color: projectColor,
            tasks: tasksArray,
            invoices: invoicesArray,
            locations: locationsArray,
            accounts: accountsArray,
            transactions: transactionsArray,
            isLocationScoutingEnabled: isLocationScoutingEnabled,
            logoData: logoData,
            budget: budget
        )
    }
}
