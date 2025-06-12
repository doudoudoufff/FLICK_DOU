import Foundation
import CoreData
import SwiftUI
import UIKit

class VenueManager: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published var venues: [VenueEntity] = []
    @Published var searchText: String = ""
    @Published var selectedVenueType: String? = nil
    
    // 缓存场地对象，避免频繁从数据库查询
    private var venueCache: [UUID: VenueEntity] = [:]
    
    init(context: NSManagedObjectContext) {
        print("初始化VenueManager，使用CoreData上下文: \(context)")
        self.context = context
        fetchVenues()
    }
    
    // MARK: - 数据获取
    
    func fetchVenues() {
        print("开始获取场地数据...")
        let request: NSFetchRequest<VenueEntity> = VenueEntity.fetchRequest()
        
        // 排序
        let sortDescriptor = NSSortDescriptor(keyPath: \VenueEntity.name, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        // 根据搜索文本和筛选条件过滤
        var predicates: [NSPredicate] = []
        
        if !searchText.isEmpty {
            let namePredicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
            let contactNamePredicate = NSPredicate(format: "contactName CONTAINS[cd] %@", searchText)
            let addressPredicate = NSPredicate(format: "address CONTAINS[cd] %@", searchText)
            
            let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                namePredicate, contactNamePredicate, addressPredicate
            ])
            
            predicates.append(searchPredicate)
        }
        
        if let venueType = selectedVenueType {
            let typePredicate = NSPredicate(format: "type == %@", venueType)
            predicates.append(typePredicate)
        }
        
        if !predicates.isEmpty {
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.predicate = compoundPredicate
        }
        
        do {
            venues = try context.fetch(request)
            print("成功获取场地数据，共\(venues.count)个场地")
            
            // 更新缓存
            updateVenueCache()
            
        } catch {
            print("获取场地数据失败: \(error.localizedDescription)")
            venues = []
        }
    }
    
    // 更新场地缓存
    private func updateVenueCache() {
        venueCache.removeAll()
        for venue in venues {
            if let id = venue.id {
                venueCache[id] = venue
                print("缓存场地: \(venue.wrappedName), ID: \(id.uuidString)")
            }
        }
        print("场地缓存更新完成，共\(venueCache.count)个场地")
    }
    
    // 通过ID获取场地对象
    func getVenueByID(_ id: UUID) -> VenueEntity? {
        print("通过ID获取场地: \(id.uuidString)")
        
        // 首先检查缓存
        if let cachedVenue = venueCache[id] {
            print("从缓存中获取场地: \(cachedVenue.wrappedName)")
            return cachedVenue
        }
        
        // 缓存未命中，从数据库查询
        let request: NSFetchRequest<VenueEntity> = VenueEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            if let venue = results.first {
                print("成功从数据库获取场地: \(venue.wrappedName)")
                
                // 更新缓存
                venueCache[id] = venue
                
                return venue
            } else {
                print("未找到ID为 \(id.uuidString) 的场地")
                return nil
            }
        } catch {
            print("通过ID获取场地失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 场地管理
    
    func addVenue(name: String, contactName: String, contactPhone: String, address: String, notes: String, type: String) -> VenueEntity {
        print("添加新场地: \(name)")
        let venue = VenueEntity(context: context)
        venue.id = UUID()
        venue.name = name
        venue.contactName = contactName
        venue.contactPhone = contactPhone
        venue.address = address
        venue.notes = notes
        venue.type = type
        venue.dateAdded = Date()
        
        saveContext()
        fetchVenues() // 这会更新缓存
        
        return venue
    }
    
    func updateVenue(_ venue: VenueEntity, name: String, contactName: String, contactPhone: String, address: String, notes: String, type: String) {
        print("更新场地: \(name)")
        venue.name = name
        venue.contactName = contactName
        venue.contactPhone = contactPhone
        venue.address = address
        venue.notes = notes
        venue.type = type
        
        saveContext()
        fetchVenues() // 这会更新缓存
    }
    
    func deleteVenue(_ venue: VenueEntity) {
        print("删除场地: \(venue.wrappedName)")
        
        // 从缓存中移除
        if let id = venue.id {
            venueCache.removeValue(forKey: id)
        }
        
        context.delete(venue)
        saveContext()
        fetchVenues()
    }
    
    // MARK: - 附件管理
    
    func addImageAttachment(to venue: VenueEntity, image: UIImage, fileName: String) -> VenueAttachmentEntity? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("无法转换图片为数据")
            return nil
        }
        
        print("添加图片附件到场地: \(venue.wrappedName)")
        let attachment = VenueAttachmentEntity(context: context)
        attachment.id = UUID()
        attachment.data = imageData
        attachment.fileName = fileName
        attachment.fileType = VenueAttachmentEntity.AttachmentType.image.rawValue
        attachment.dateAdded = Date()
        attachment.venue = venue
        
        venue.addToAttachments(attachment)
        
        saveContext()
        return attachment
    }
    
    func addPDFAttachment(to venue: VenueEntity, pdfData: Data, fileName: String) -> VenueAttachmentEntity {
        print("添加PDF附件到场地: \(venue.wrappedName)")
        let attachment = VenueAttachmentEntity(context: context)
        attachment.id = UUID()
        attachment.data = pdfData
        attachment.fileName = fileName
        attachment.fileType = VenueAttachmentEntity.AttachmentType.pdf.rawValue
        attachment.dateAdded = Date()
        attachment.venue = venue
        
        venue.addToAttachments(attachment)
        
        saveContext()
        return attachment
    }
    
    func deleteAttachment(_ attachment: VenueAttachmentEntity) {
        print("删除附件: \(attachment.wrappedFileName)")
        context.delete(attachment)
        saveContext()
    }
    
    // MARK: - 辅助方法
    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("保存场地数据成功")
            } catch {
                print("保存场地数据失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 返回所有场地类型选项
    var venueTypeOptions: [String] {
        return CustomTagManager.shared.getAllTagNames(ofType: .venueType)
    }
} 