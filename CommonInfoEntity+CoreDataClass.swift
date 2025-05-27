//
//  CommonInfoEntity+CoreDataClass.swift
//  FLICK
//
//  Created by 豆子 on 2025/5/28.
//
//

import Foundation
import CoreData


public class CommonInfoEntity: NSManagedObject {
    // 获取源账户ID
    func getSourceAccountId() -> UUID? {
        guard let userData = self.userData else { return nil }
        
        do {
            if let userInfo = try JSONSerialization.jsonObject(with: userData, options: []) as? [String: String],
               let sourceIdString = userInfo["sourceId"],
               let sourceId = UUID(uuidString: sourceIdString) {
                return sourceId
            }
        } catch {
            print("解析userData失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // 设置源账户ID
    func setSourceAccountId(_ id: UUID) {
        let userInfo = ["sourceId": id.uuidString]
        
        do {
            let data = try JSONEncoder().encode(userInfo)
            self.userData = data
        } catch {
            print("编码userData失败: \(error.localizedDescription)")
        }
    }
    
    // 检查是否是从项目账户导入的
    var isImportedFromAccount: Bool {
        return getSourceAccountId() != nil
    }
}
