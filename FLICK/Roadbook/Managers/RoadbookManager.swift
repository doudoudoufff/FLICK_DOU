import Foundation
import SwiftUI
import CoreData
import Combine

// 路书头部信息结构体
struct RoadbookHeaderInfo {
    let title: String
    let projectName: String
    let customText: String
    let date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

/// 路书管理器，负责路书数据的CRUD操作
class RoadbookManager: ObservableObject {
    /// 单例实例
    static let shared = RoadbookManager()
    
    /// 发布者：路书列表更新
    @Published var roadbooks: [Roadbook] = []
    
    /// 当前选中的路书
    @Published var selectedRoadbook: Roadbook?
    
    /// 是否正在加载数据
    @Published var isLoading = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 持久化控制器
    private let persistenceController = PersistenceController.shared
    
    /// 私有初始化方法，防止外部创建实例
    private init() {
        loadRoadbooks()
    }
    
    /// 加载所有路书
    func loadRoadbooks() {
        isLoading = true
        errorMessage = nil
        
        // 使用后台线程加载数据
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 从本地存储加载路书数据
                let loadedRoadbooks = try self.fetchRoadbooksFromStorage()
                
                // 在主线程更新UI
                DispatchQueue.main.async {
                    self.roadbooks = loadedRoadbooks
                    self.isLoading = false
                }
            } catch {
                // 处理错误
                DispatchQueue.main.async {
                    self.errorMessage = "加载路书失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 从存储中获取所有路书
    /// - Returns: 路书数组
    private func fetchRoadbooksFromStorage() throws -> [Roadbook] {
        let context = persistenceController.container.viewContext
        
        // 创建获取请求
        let fetchRequest = RoadbookEntity.fetchRequest()
        
        // 按修改日期降序排序
        let sortDescriptor = NSSortDescriptor(key: "modificationDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // 执行请求
        let roadbookEntities = try context.fetch(fetchRequest)
        
        // 将实体转换为模型
        return roadbookEntities.compactMap { entity in
            return convertEntityToModel(entity)
        }
    }
    
    /// 创建新路书
    /// - Parameters:
    ///   - name: 路书名称
    ///   - projectId: 关联项目ID（可选）
    ///   - completion: 完成回调，返回创建的路书或错误
    func createRoadbook(name: String, projectId: UUID? = nil, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        // 创建新路书实例
        let newRoadbook = Roadbook(name: name, projectId: projectId)
        
        // 保存到存储
        saveRoadbook(newRoadbook) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let savedRoadbook):
                // 更新内存中的路书列表
                DispatchQueue.main.async {
                    self.roadbooks.append(savedRoadbook)
                    self.selectedRoadbook = savedRoadbook
                    completion(.success(savedRoadbook))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 保存路书到存储
    /// - Parameters:
    ///   - roadbook: 要保存的路书
    ///   - completion: 完成回调，返回保存的路书或错误
    func saveRoadbook(_ roadbook: Roadbook, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        print("开始保存路书，ID: \(roadbook.id), 名称: \(roadbook.name), 照片数量: \(roadbook.photos.count)")
        
        do {
            // 检查是新建还是更新
            let fetchRequest = RoadbookEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", roadbook.id as CVarArg)
            
            let existingEntities = try context.fetch(fetchRequest)
            let roadbookEntity: RoadbookEntity
            
            if let existingEntity = existingEntities.first {
                // 更新现有实体
                roadbookEntity = existingEntity
                print("更新现有路书实体")
            } else {
                // 创建新实体
                roadbookEntity = RoadbookEntity(context: context)
                roadbookEntity.id = roadbook.id
                roadbookEntity.creationDate = roadbook.creationDate
                print("创建新路书实体")
            }
            
            // 更新实体属性
            roadbookEntity.name = roadbook.name
            roadbookEntity.modificationDate = Date()
            roadbookEntity.notes = roadbook.notes
            
            // 如果有项目ID，查找并关联项目
            if let projectId = roadbook.projectId {
                let projectFetchRequest = ProjectEntity.fetchRequest()
                projectFetchRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
                
                if let projectEntity = try context.fetch(projectFetchRequest).first {
                    roadbookEntity.project = projectEntity
                }
            }
            
            // 更新照片顺序（如果有照片）
            if !roadbook.photos.isEmpty {
                print("更新照片顺序，照片数量: \(roadbook.photos.count)")
                
                // 获取所有照片实体
                let photoFetchRequest = RoadbookPhotoEntity.fetchRequest()
                photoFetchRequest.predicate = NSPredicate(format: "roadbook.id == %@", roadbook.id as CVarArg)
                let photoEntities = try context.fetch(photoFetchRequest)
                
                // 更新每个照片的orderIndex
                for photo in roadbook.photos {
                    if let photoEntity = photoEntities.first(where: { $0.id == photo.id }) {
                        if photoEntity.orderIndex != Int32(photo.orderIndex) {
                            print("更新照片 \(photoEntity.id?.uuidString ?? "nil") 的顺序: \(photoEntity.orderIndex) -> \(photo.orderIndex)")
                            photoEntity.orderIndex = Int32(photo.orderIndex)
                        }
                    }
                }
                
                print("照片顺序更新完成")
            }
            
            // 保存上下文
            try context.save()
            print("CoreData 保存成功")
            
            // 将保存后的实体转换回模型
            let savedRoadbook = convertEntityToModel(roadbookEntity)
            print("路书转换完成，照片数量: \(savedRoadbook.photos.count)")
            
            completion(.success(savedRoadbook))
        } catch {
            print("保存路书失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// 更新路书
    /// - Parameters:
    ///   - roadbook: 要更新的路书
    ///   - completion: 完成回调，返回更新后的路书或错误
    func updateRoadbook(_ roadbook: Roadbook, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        // 查找并更新内存中的路书
        if let index = roadbooks.firstIndex(where: { $0.id == roadbook.id }) {
            // 更新内存中的路书
            roadbooks[index] = roadbook
            
            // 保存到存储
            saveRoadbook(roadbook) { result in
                completion(result)
            }
        } else {
            // 未找到要更新的路书
            completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到要更新的路书"])))
        }
    }
    
    /// 删除路书
    /// - Parameters:
    ///   - roadbookId: 要删除的路书ID
    ///   - completion: 完成回调，返回成功或错误
    func deleteRoadbook(with roadbookId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        do {
            // 查找要删除的实体
            let fetchRequest = RoadbookEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", roadbookId as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            if let entityToDelete = entities.first {
                // 从上下文中删除
                context.delete(entityToDelete)
                
                // 保存上下文
                try context.save()
                
                // 从内存中移除路书
                if let index = roadbooks.firstIndex(where: { $0.id == roadbookId }) {
                    DispatchQueue.main.async {
                        self.roadbooks.remove(at: index)
                        
                        // 如果删除的是当前选中的路书，则取消选中
                        if self.selectedRoadbook?.id == roadbookId {
                            self.selectedRoadbook = nil
                        }
                    }
                }
                
                completion(.success(()))
            } else {
                // 未找到要删除的路书
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到要删除的路书"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 添加照片到路书
    /// - Parameters:
    ///   - photo: 要添加的照片
    ///   - roadbookId: 路书ID
    ///   - completion: 完成回调，返回更新后的路书或错误
    func addPhoto(_ photo: RoadbookPhoto, to roadbookId: UUID, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        print("开始添加照片到路书，照片ID: \(photo.id), 路书ID: \(roadbookId)")
        
        if let imageData = photo.originalImageData {
            print("照片数据大小: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
            
            if let image = photo.originalImage {
                print("照片尺寸: \(image.size)")
            } else {
                print("❌ 无法从数据创建图片")
            }
        } else {
            print("❌ 照片没有原始数据")
        }
        
        do {
            // 查找路书实体
            let fetchRequest = RoadbookEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", roadbookId as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            guard let roadbookEntity = entities.first else {
                print("❌ 未找到路书实体")
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到路书"])))
                return
            }
            
            print("✅ 找到路书实体: \(roadbookEntity.name ?? "未命名")")
            
            // 创建照片实体
            let photoEntity = RoadbookPhotoEntity(context: context)
            photoEntity.id = photo.id
            photoEntity.captureDate = photo.captureDate
            photoEntity.originalImageData = photo.originalImageData
            photoEntity.editedImageData = photo.editedImageData
            photoEntity.note = photo.note
            photoEntity.orderIndex = Int32(photo.orderIndex)
            photoEntity.thumbnailData = photo.thumbnailData
            
            if let imageData = photo.originalImageData {
                print("✅ 创建照片实体，ID: \(photoEntity.id?.uuidString ?? "nil"), 原始数据大小: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
            } else {
                print("❌ 创建照片实体，但没有原始数据")
            }
            
            // 设置位置信息
            if let location = photo.location {
                photoEntity.latitude = location.latitude
                photoEntity.longitude = location.longitude
            }
            
            // 添加绘制元素
            for drawingElement in photo.drawingData {
                let elementEntity = createDrawingElementEntity(from: drawingElement, in: context)
                photoEntity.addToDrawingElements(elementEntity)
            }
            
            // 关联到路书 - 使用正确的方法添加照片
            roadbookEntity.addToPhotos(photoEntity)
            print("✅ 已将照片关联到路书")
            
            // 更新路书修改时间
            roadbookEntity.modificationDate = Date()
            
            // 保存上下文
            try context.save()
            print("✅ CoreData 保存成功")
            
            // 验证照片是否成功添加到路书
            if let photoSet = roadbookEntity.photos {
                let photoCount = photoSet.count
                print("✅ 路书现在有 \(photoCount) 张照片")
                
                // 打印所有照片ID
                let photoEntities = Array(photoSet) as? [RoadbookPhotoEntity] ?? []
                let photoIds = photoEntities.compactMap { $0.id?.uuidString }
                print("路书中的照片ID: \(photoIds)")
            }
            
            // 更新内存中的路书
            let updatedRoadbook = convertEntityToModel(roadbookEntity)
            print("✅ 路书模型转换完成，照片数量: \(updatedRoadbook.photos.count)")
            
            completion(.success(updatedRoadbook))
        } catch {
            print("❌ 添加照片失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// 更新照片
    /// - Parameters:
    ///   - photo: 更新后的照片
    ///   - photoIndex: 照片在路书中的索引
    ///   - roadbookId: 路书ID
    ///   - completion: 完成回调，返回更新后的路书或错误
    func updatePhoto(_ photo: RoadbookPhoto, at photoIndex: Int, in roadbookId: UUID, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        do {
            // 查找路书实体
            let fetchRequest = RoadbookEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", roadbookId as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            guard let roadbookEntity = entities.first else {
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到路书"])))
                return
            }
            
            // 查找要更新的照片 - 使用ID查找而不是索引
            let photoFetchRequest = RoadbookPhotoEntity.fetchRequest()
            photoFetchRequest.predicate = NSPredicate(format: "roadbook.id == %@", roadbookId as CVarArg)
            
            let photoEntities = try context.fetch(photoFetchRequest)
            
            // 按orderIndex排序
            let sortedPhotoEntities = photoEntities.sorted { $0.orderIndex < $1.orderIndex }
            
            guard photoIndex < sortedPhotoEntities.count else {
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到照片"])))
                return
            }
            
            let photoEntity = sortedPhotoEntities[photoIndex]
            
            print("更新照片，ID: \(photoEntity.id?.uuidString ?? "nil"), 索引: \(photoIndex)")
            
            // 更新照片属性
            photoEntity.note = photo.note
            photoEntity.editedImageData = photo.editedImageData
            photoEntity.orderIndex = Int32(photo.orderIndex)
            
            // 更新缩略图数据
            if let thumbnailData = photo.thumbnailData {
                photoEntity.thumbnailData = thumbnailData
                print("已更新缩略图数据，大小: \(thumbnailData.count) 字节")
                
                // 验证缩略图数据是否有效
                if let thumbnailImage = UIImage(data: thumbnailData) {
                    print("缩略图有效，尺寸: \(thumbnailImage.size)")
                } else {
                    print("警告：缩略图数据无法转换为图片")
                }
            } else {
                print("警告：照片没有缩略图数据")
            }
            
            // 更新位置信息
            if let location = photo.location {
                photoEntity.latitude = location.latitude
                photoEntity.longitude = location.longitude
            }
            
            // 更新绘制元素（如果有）
            if !photo.drawingData.isEmpty {
                print("更新绘制元素，数量: \(photo.drawingData.count)")
                
                // 删除现有的绘制元素
                if let existingElements = photoEntity.drawingElements {
                    let elementsToDelete = Array(existingElements) as? [DrawingElementEntity] ?? []
                    for elementEntity in elementsToDelete {
                        context.delete(elementEntity)
                    }
                }
                
                // 添加新的绘制元素
                for drawingElement in photo.drawingData {
                    let elementEntity = createDrawingElementEntity(from: drawingElement, in: context)
                    photoEntity.addToDrawingElements(elementEntity)
                }
            }
            
            // 更新路书修改时间
            roadbookEntity.modificationDate = Date()
            
            // 保存上下文
            try context.save()
            print("照片更新成功")
            
            // 更新内存中的路书
            let updatedRoadbook = convertEntityToModel(roadbookEntity)
            completion(.success(updatedRoadbook))
        } catch {
            print("更新照片失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// 生成路书长图
    /// - Parameters:
    ///   - roadbookId: 路书ID
    ///   - headerInfo: 头部信息
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    func generateRoadbookImage(for roadbookId: UUID, headerInfo: RoadbookHeaderInfo? = nil, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // 获取路书数据
        getRoadbook(id: roadbookId) { result in
            switch result {
            case .success(let roadbook):
                // 检查照片数量
                guard !roadbook.photos.isEmpty else {
                    completion(.failure(NSError(domain: "RoadbookManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "路书中没有照片"])))
                    return
                }
                
                // 按照顺序排序照片
                let sortedPhotos = roadbook.photos.sorted(by: { $0.orderIndex < $1.orderIndex })
                
                // 创建长图
                DispatchQueue.global(qos: .userInitiated).async {
                    // 初始化进度
                    DispatchQueue.main.async {
                        progressHandler(0.0)
                    }
                    
                    // 计算总高度和最大宽度
                    var totalHeight: CGFloat = 0
                    var maxWidth: CGFloat = 0
                    
                    // 计算照片尺寸和找出最大宽度
                    var photoSizes: [(photo: RoadbookPhoto, size: CGSize)] = []
                    
                    for photo in sortedPhotos {
                        if let image = photo.displayImage {
                            let size = image.size
                            photoSizes.append((photo, size))
                            totalHeight += size.height
                            maxWidth = max(maxWidth, size.width)
                        }
                    }
                    
                    // 确保最小宽度
                    maxWidth = max(maxWidth, 1000)
                    
                    // 添加头部信息的高度
                    let headerHeight: CGFloat = headerInfo != nil ? 200 : 0
                    totalHeight += headerHeight
                    
                    // 创建画布
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), true, 0)
                    let context = UIGraphicsGetCurrentContext()
                    
                    // 填充白色背景
                    context?.setFillColor(UIColor.white.cgColor)
                    context?.fill(CGRect(x: 0, y: 0, width: maxWidth, height: totalHeight))
                    
                    var currentY: CGFloat = 0
                    
                    // 绘制头部信息
                    if let headerInfo = headerInfo {
                        // 设置头部背景色
                        context?.setFillColor(UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0).cgColor)
                        context?.fill(CGRect(x: 0, y: 0, width: maxWidth, height: headerHeight))
                        
                        // 绘制标题
                        let titleAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(ofSize: 28),
                            .foregroundColor: UIColor.black
                        ]
                        let titleString = NSAttributedString(string: headerInfo.title, attributes: titleAttributes)
                        let titleRect = CGRect(x: 20, y: 20, width: maxWidth - 40, height: 40)
                        titleString.draw(in: titleRect)
                        
                        // 绘制项目名称
                        if !headerInfo.projectName.isEmpty {
                            let projectAttributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 18),
                                .foregroundColor: UIColor.darkGray
                            ]
                            let projectString = NSAttributedString(string: "项目: \(headerInfo.projectName)", attributes: projectAttributes)
                            let projectRect = CGRect(x: 20, y: 70, width: maxWidth - 40, height: 30)
                            projectString.draw(in: projectRect)
                        }
                        
                        // 绘制自定义文本
                        if !headerInfo.customText.isEmpty {
                            let customAttributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 16),
                                .foregroundColor: UIColor.darkGray
                            ]
                            let customString = NSAttributedString(string: headerInfo.customText, attributes: customAttributes)
                            let customRect = CGRect(x: 20, y: 110, width: maxWidth - 40, height: 50)
                            customString.draw(in: customRect)
                        }
                        
                        // 绘制日期
                        let dateAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 14),
                            .foregroundColor: UIColor.gray
                        ]
                        let dateString = NSAttributedString(string: "生成时间: \(headerInfo.formattedDate)", attributes: dateAttributes)
                        let dateRect = CGRect(x: 20, y: 160, width: maxWidth - 40, height: 20)
                        dateString.draw(in: dateRect)
                        
                        // 更新当前Y坐标
                        currentY += headerHeight
                    }
                    
                    // 绘制照片
                    for (index, photoData) in photoSizes.enumerated() {
                        autoreleasepool {
                            let photo = photoData.photo
                            let size = photoData.size
                            
                            if let image = photo.displayImage {
                                // 计算照片位置，居中显示
                                let x = (maxWidth - size.width) / 2
                                
                                // 绘制照片
                                image.draw(in: CGRect(x: x, y: currentY, width: size.width, height: size.height))
                                
                                // 如果有备注，绘制备注
                                if !photo.note.isEmpty {
                                    // 设置备注背景
                                    context?.setFillColor(UIColor(white: 0, alpha: 0.6).cgColor)
                                    let noteBackgroundHeight: CGFloat = 40
                                    context?.fill(CGRect(x: x, y: currentY + size.height - noteBackgroundHeight, width: size.width, height: noteBackgroundHeight))
                                    
                                    // 绘制备注文本
                                    let noteAttributes: [NSAttributedString.Key: Any] = [
                                        .font: UIFont.systemFont(ofSize: 16),
                                        .foregroundColor: UIColor.white
                                    ]
                                    let noteString = NSAttributedString(string: photo.note, attributes: noteAttributes)
                                    let noteRect = CGRect(x: x + 10, y: currentY + size.height - noteBackgroundHeight + 10, width: size.width - 20, height: noteBackgroundHeight - 20)
                                    noteString.draw(in: noteRect)
                                }
                                
                                // 更新当前Y坐标
                                currentY += size.height
                                
                                // 更新进度
                                let progress = Float(index + 1) / Float(photoSizes.count)
                                DispatchQueue.main.async {
                                    progressHandler(progress)
                                }
                            }
                        }
                    }
                    
                    // 获取生成的图片
                    if let generatedImage = UIGraphicsGetImageFromCurrentImageContext() {
                        UIGraphicsEndImageContext()
                        
                        // 返回结果
                        DispatchQueue.main.async {
                            completion(.success(generatedImage))
                        }
                    } else {
                        UIGraphicsEndImageContext()
                        
                        // 返回错误
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "RoadbookManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "生成图片失败"])))
                        }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 将多张图片垂直拼接成一张长图
    /// - Parameters:
    ///   - images: 要拼接的图片数组
    ///   - progressHandler: 进度回调，返回0-1之间的值表示进度
    /// - Returns: 拼接后的图片
    private func combineImages(_ images: [UIImage], progressHandler: ((Float) -> Void)? = nil) -> UIImage {
        // 计算总高度和最大宽度
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for image in images {
            totalHeight += image.size.height
            maxWidth = max(maxWidth, image.size.width)
        }
        
        // 创建绘图上下文
        let size = CGSize(width: maxWidth, height: totalHeight)
        UIGraphicsBeginImageContext(size)
        
        // 逐个绘制图片
        var y: CGFloat = 0
        for (index, image) in images.enumerated() {
            image.draw(in: CGRect(x: 0, y: y, width: image.size.width, height: image.size.height))
            y += image.size.height
            
            // 报告进度
            let progress = Float(index + 1) / Float(images.count)
            progressHandler?(progress)
        }
        
        // 获取结果图片
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return combinedImage
    }
    
    /// 从路书中删除照片
    /// - Parameters:
    ///   - photoId: 要删除的照片ID
    ///   - roadbookId: 路书ID
    ///   - completion: 完成回调，返回更新后的路书或错误
    func deletePhoto(withId photoId: UUID, from roadbookId: UUID, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        do {
            // 查找路书实体
            let roadbookFetchRequest = RoadbookEntity.fetchRequest()
            roadbookFetchRequest.predicate = NSPredicate(format: "id == %@", roadbookId as CVarArg)
            
            guard let roadbookEntity = try context.fetch(roadbookFetchRequest).first else {
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到路书"])))
                return
            }
            
            // 查找照片实体
            let photoFetchRequest = RoadbookPhotoEntity.fetchRequest()
            photoFetchRequest.predicate = NSPredicate(format: "id == %@ AND roadbook.id == %@", photoId as CVarArg, roadbookId as CVarArg)
            
            guard let photoEntity = try context.fetch(photoFetchRequest).first else {
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到照片"])))
                return
            }
            
            // 获取要删除的照片的orderIndex
            let deletedPhotoOrderIndex = photoEntity.orderIndex
            
            // 删除照片实体
            context.delete(photoEntity)
            
            // 更新其他照片的orderIndex
            let remainingPhotosFetchRequest = RoadbookPhotoEntity.fetchRequest()
            remainingPhotosFetchRequest.predicate = NSPredicate(format: "roadbook.id == %@ AND orderIndex > %d", roadbookId as CVarArg, deletedPhotoOrderIndex)
            
            let remainingPhotos = try context.fetch(remainingPhotosFetchRequest)
            
            // 调整剩余照片的顺序
            for photo in remainingPhotos {
                photo.orderIndex -= 1
            }
            
            // 更新路书修改时间
            roadbookEntity.modificationDate = Date()
            
            // 保存上下文
            try context.save()
            
            // 更新内存中的路书
            let updatedRoadbook = convertEntityToModel(roadbookEntity)
            
            if let index = roadbooks.firstIndex(where: { $0.id == roadbookId }) {
                DispatchQueue.main.async {
                    self.roadbooks[index] = updatedRoadbook
                    
                    // 如果是当前选中的路书，更新选中的路书
                    if self.selectedRoadbook?.id == roadbookId {
                        self.selectedRoadbook = updatedRoadbook
                    }
                }
            }
            
            completion(.success(updatedRoadbook))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 获取特定ID的路书
    /// - Parameters:
    ///   - id: 路书ID
    ///   - completion: 完成回调，返回路书或错误
    func getRoadbook(id: UUID, completion: @escaping (Result<Roadbook, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        // 重置缓存，确保从数据库获取最新数据
        context.refreshAllObjects()
        
        do {
            // 查找路书实体
            let fetchRequest = RoadbookEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            guard let roadbookEntity = entities.first else {
                completion(.failure(NSError(domain: "RoadbookManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到路书"])))
                return
            }
            
            print("从数据库获取路书，ID: \(roadbookEntity.id?.uuidString ?? "nil")，照片数量: \(roadbookEntity.photos?.count ?? 0)")
            
            // 转换为模型
            let roadbook = convertEntityToModel(roadbookEntity)
            
            // 如果是当前内存中的路书，更新内存中的数据
            if let index = roadbooks.firstIndex(where: { $0.id == id }) {
                DispatchQueue.main.async {
                    self.roadbooks[index] = roadbook
                    
                    // 如果是当前选中的路书，更新选中的路书
                    if self.selectedRoadbook?.id == id {
                        self.selectedRoadbook = roadbook
                    }
                }
            }
            
            completion(.success(roadbook))
        } catch {
            print("获取路书失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// 获取项目
    /// - Parameter id: 项目ID
    /// - Returns: 项目对象，如果不存在则返回nil
    func getProject(id: UUID) -> Project? {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let result = try persistenceController.container.viewContext.fetch(request)
            if let projectEntity = result.first {
                return Project(entity: projectEntity)
            }
            return nil
        } catch {
            print("获取项目失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 辅助方法
    
    /// 将RoadbookEntity转换为Roadbook模型
    /// - Parameter entity: 路书实体
    /// - Returns: 路书模型
    private func convertEntityToModel(_ entity: RoadbookEntity) -> Roadbook {
        // 获取基本属性
        let id = entity.id ?? UUID()
        let name = entity.name ?? "未命名路书"
        var photos: [RoadbookPhoto] = []
        
        // 安全处理照片关系
        if let photoSet = entity.photos {
            print("照片关系类型: \(type(of: photoSet))，数量: \(photoSet.count)")
            
            // 创建一个安全的临时数组
            var photoArray: [RoadbookPhotoEntity] = []
            
            // 最安全的方式：将集合转换为数组后再处理
            let photoObjects = photoSet.compactMap { $0 }
            
            for object in photoObjects {
                if let photoEntity = object as? RoadbookPhotoEntity {
                    photoArray.append(photoEntity)
                }
            }
            
            // 按orderIndex排序
            let sortedPhotoEntities = photoArray.sorted { $0.orderIndex < $1.orderIndex }
            
            print("照片排序前: \(photoArray.map { $0.orderIndex })")
            print("照片排序后: \(sortedPhotoEntities.map { $0.orderIndex })")
            
            // 安全转换每个照片实体
            for photoEntity in sortedPhotoEntities {
                // 添加额外的安全检查
                guard photoEntity.originalImageData != nil, photoEntity.id != nil else {
                    print("⚠️ 跳过无效的照片实体")
                    continue
                }
                
                if let photo = convertPhotoEntityToModel(photoEntity) {
                    photos.append(photo)
                }
            }
            
            print("从实体转换了 \(photos.count) 张照片，顺序: \(photos.map { $0.orderIndex })")
        }
        
        // 创建路书模型
        var roadbook = Roadbook(
            id: id,
            name: name,
            projectId: entity.project?.id,
            photos: photos,
            notes: entity.notes ?? ""
        )
        
        // 设置创建日期和修改日期
        if let creationDate = entity.creationDate {
            roadbook.creationDate = creationDate
        }
        
        if let modificationDate = entity.modificationDate {
            roadbook.modificationDate = modificationDate
        }
        
        return roadbook
    }
    
    /// 将RoadbookPhotoEntity转换为RoadbookPhoto模型
    /// - Parameter entity: 照片实体
    /// - Returns: 照片模型
    private func convertPhotoEntityToModel(_ entity: RoadbookPhotoEntity) -> RoadbookPhoto? {
        // 确保必要的数据存在
        guard let id = entity.id,
              let originalImageData = entity.originalImageData,
              let originalImage = UIImage(data: originalImageData) else {
            print("⚠️ 无法创建照片模型：缺少必要数据")
            return nil
        }
        
        // 转换绘制元素
        var drawingElements: [DrawingElement] = []
        
        // 安全处理绘制元素
        if let elementSet = entity.drawingElements {
            print("绘制元素关系类型: \(type(of: elementSet))")
            
            // 使用更安全的方式获取所有元素
            var elementArray: [DrawingElementEntity] = []
            
            // 最安全的方式：将集合转换为数组后再处理
            let elementObjects = elementSet.compactMap { $0 }
            
            for object in elementObjects {
                if let elementEntity = object as? DrawingElementEntity {
                    elementArray.append(elementEntity)
                }
            }
            
            print("获取到 \(elementArray.count) 个绘制元素")
            
            // 转换每个元素
            for elementEntity in elementArray {
                // 确保元素有有效的ID和类型
                guard elementEntity.id != nil, elementEntity.type != nil else {
                    print("⚠️ 跳过无效的绘制元素")
                    continue
                }
                
                let element = convertDrawingElementEntityToModel(elementEntity)
                drawingElements.append(element)
            }
        }
        
        // 创建位置信息
        var location: PhotoLocation? = nil
        if entity.latitude != 0 || entity.longitude != 0 {
            location = PhotoLocation(
                latitude: entity.latitude,
                longitude: entity.longitude
            )
        }
        
        // 创建照片模型
        var photo = RoadbookPhoto(
            id: id,
            image: originalImage,
            note: entity.note ?? "",
            orderIndex: Int(entity.orderIndex),
            location: location
        )
        
        // 设置编辑后的图片数据
        photo.editedImageData = entity.editedImageData
        
        // 设置缩略图数据
        photo.thumbnailData = entity.thumbnailData
        
        // 调试缩略图数据
        if let thumbnailData = entity.thumbnailData {
            print("从数据库加载缩略图数据，大小: \(thumbnailData.count) 字节")
            if let thumbnailImage = UIImage(data: thumbnailData) {
                print("从数据库加载的缩略图有效，尺寸: \(thumbnailImage.size)")
            } else {
                print("警告：从数据库加载的缩略图数据无法转换为图片")
            }
        } else {
            print("警告：数据库中没有缩略图数据")
        }
        
        // 设置绘制数据
        photo.drawingData = drawingElements
        
        // 设置拍摄日期
        if let captureDate = entity.captureDate {
            photo.captureDate = captureDate
        }
        
        return photo
    }
    
    /// 将DrawingElementEntity转换为DrawingElement模型
    /// - Parameter entity: 绘制元素实体
    /// - Returns: 绘制元素模型
    private func convertDrawingElementEntityToModel(_ entity: DrawingElementEntity) -> DrawingElement {
        // 解析点数据
        var points: [CGPoint] = []
        
        if let pointsData = entity.pointsData {
            do {
                let pointsArray = try JSONDecoder().decode([[CGFloat]].self, from: pointsData)
                points = pointsArray.map { array in
                    // 确保数组至少有两个元素
                    guard array.count >= 2 else { return .zero }
                    return CGPoint(x: array[0], y: array[1])
                }
            } catch {
                print("解析绘制元素点数据失败: \(error)")
            }
        }
        
        // 确定元素类型，使用安全的方式获取类型
        let typeString = entity.type ?? ""
        let type = DrawingElementType(rawValue: typeString) ?? .line
        
        // 创建绘制元素，确保所有属性都有默认值
        return DrawingElement(
            id: entity.id ?? UUID(),
            type: type,
            color: entity.color ?? "#FF0000",
            lineWidth: CGFloat(entity.lineWidth),
            points: points,
            text: entity.text
        )
    }
    
    /// 从DrawingElement模型创建DrawingElementEntity实体
    /// - Parameters:
    ///   - element: 绘制元素模型
    ///   - context: 托管对象上下文
    /// - Returns: 绘制元素实体
    private func createDrawingElementEntity(from element: DrawingElement, in context: NSManagedObjectContext) -> DrawingElementEntity {
        let entity = DrawingElementEntity(context: context)
        
        // 设置基本属性
        entity.id = element.id
        entity.type = element.type.rawValue
        entity.color = element.color
        entity.lineWidth = Double(element.lineWidth)
        entity.text = element.text
        
        // 序列化点数据
        do {
            // 将CGPoint数组转换为可序列化的格式
            let pointsArray = element.points.map { [$0.x, $0.y] }
            let pointsData = try JSONEncoder().encode(pointsArray)
            entity.pointsData = pointsData
        } catch {
            print("序列化绘制元素点数据失败: \(error)")
        }
        
        return entity
    }
    
    // 创建路书并立即添加照片
    func createRoadbookWithPhoto(name: String, image: UIImage, projectId: UUID? = nil, completion: @escaping (Result<(Roadbook, RoadbookPhoto), Error>) -> Void) {
        // 创建新路书
        createRoadbook(name: name, projectId: projectId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let roadbook):
                // 创建照片对象
                let photo = RoadbookPhoto(image: image, note: "", orderIndex: 0)
                
                // 添加照片到路书
                self.addPhoto(photo, to: roadbook.id) { photoResult in
                    switch photoResult {
                    case .success(let updatedRoadbook):
                        // 返回创建的路书和添加的照片
                        if let addedPhoto = updatedRoadbook.photos.first {
                            completion(.success((updatedRoadbook, addedPhoto)))
                        } else {
                            completion(.failure(NSError(domain: "RoadbookManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "照片添加成功但无法获取"])))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
} 