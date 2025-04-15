import SwiftUI
import CoreData
import CoreLocation

// 堪景场地类型
enum LocationType: String, Codable, CaseIterable {
    case exterior = "外景"
    case interior = "内景"
    case studio = "摄影棚"
    case other = "其他"
}

// 场地状态
enum LocationStatus: String, Codable, CaseIterable {
    case pending = "待确认"
    case confirmed = "已确认"
    case rejected = "已否决"
}

// 堪景场地
struct Location: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var type: LocationType
    var status: LocationStatus
    var address: String
    private var _latitude: Double?
    private var _longitude: Double?
    var contactName: String?
    var contactPhone: String?
    var photos: [LocationPhoto]
    var notes: String?
    var date: Date
    
    var latitude: Double? {
        get { return _latitude }
        set { _latitude = newValue }
    }
    
    var longitude: Double? {
        get { return _longitude }
        set { _longitude = newValue }
    }
    
    var hasCoordinates: Bool {
        return _latitude != nil && _longitude != nil
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = _latitude, let longitude = _longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(id: UUID = UUID(), 
         name: String, 
         type: LocationType = .exterior,
         status: LocationStatus = .pending,
         address: String,
         latitude: Double? = nil,
         longitude: Double? = nil,
         contactName: String? = nil,
         contactPhone: String? = nil,
         photos: [LocationPhoto] = [],
         notes: String? = nil,
         date: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.address = address
        self._latitude = latitude
        self._longitude = longitude
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.photos = photos
        self.notes = notes
        self.date = date
    }
    
    func toEntity(context: NSManagedObjectContext) -> LocationEntity {
        let entity = LocationEntity(context: context)
        entity.id = id
        entity.name = name
        entity.type = type.rawValue
        entity.status = status.rawValue
        entity.address = address
        entity.latitude = _latitude ?? 0
        entity.longitude = _longitude ?? 0
        entity.hasCoordinates = hasCoordinates
        entity.contactName = contactName
        entity.contactPhone = contactPhone
        entity.notes = notes
        entity.date = date
        
        // 转换照片
        entity.photos = NSSet(array: photos.map { $0.toEntity(context: context) })
        
        return entity
    }
    
    static func fromEntity(_ entity: LocationEntity) -> Location? {
        guard let id = entity.id,
              let name = entity.name,
              let type = LocationType(rawValue: entity.type ?? ""),
              let status = LocationStatus(rawValue: entity.status ?? ""),
              let address = entity.address,
              let date = entity.date else {
            return nil
        }
        
        let photos = (entity.photos?.allObjects as? [LocationPhotoEntity])?.compactMap(LocationPhoto.fromEntity) ?? []
        
        return Location(
            id: id,
            name: name,
            type: type,
            status: status,
            address: address,
            latitude: entity.hasCoordinates ? entity.latitude : nil,
            longitude: entity.hasCoordinates ? entity.longitude : nil,
            contactName: entity.contactName,
            contactPhone: entity.contactPhone,
            photos: photos,
            notes: entity.notes,
            date: date
        )
    }
    
    // 添加 Equatable 的实现
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.status == rhs.status &&
        lhs.address == rhs.address &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.contactName == rhs.contactName &&
        lhs.contactPhone == rhs.contactPhone &&
        lhs.photos == rhs.photos &&
        lhs.notes == rhs.notes &&
        lhs.date == rhs.date
    }
    
    // 添加 Hashable 的实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func fetchEntity(in context: NSManagedObjectContext) -> LocationEntity? {
        let request: NSFetchRequest<LocationEntity> = LocationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("获取场地实体失败: \(error)")
            return nil
        }
    }
}

// 照片模型
struct LocationPhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let imageData: Data
    let date: Date
    let weather: String?
    let note: String?
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    init(id: UUID = UUID(), image: UIImage, date: Date = Date(), weather: String? = nil, note: String? = nil) {
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.date = date
        self.weather = weather
        self.note = note
    }
    
    func toEntity(context: NSManagedObjectContext) -> LocationPhotoEntity {
        let entity = LocationPhotoEntity(context: context)
        entity.id = id
        entity.imageData = imageData
        entity.date = date
        entity.weather = weather
        entity.note = note
        return entity
    }
    
    static func fromEntity(_ entity: LocationPhotoEntity) -> LocationPhoto? {
        guard let id = entity.id,
              let imageData = entity.imageData,
              let date = entity.date,
              let image = UIImage(data: imageData)
        else {
            return nil
        }
        
        return LocationPhoto(
            id: id,
            image: image,
            date: date,
            weather: entity.weather,
            note: entity.note
        )
    }
} 