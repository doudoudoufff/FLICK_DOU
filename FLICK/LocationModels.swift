import SwiftUI

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
struct Location: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: LocationType
    var status: LocationStatus
    var address: String
    var contactName: String?
    var contactPhone: String?
    var photos: [LocationPhoto]
    var notes: String?
    var date: Date
    
    init(id: UUID = UUID(), 
         name: String, 
         type: LocationType = .exterior,
         status: LocationStatus = .pending,
         address: String,
         contactName: String? = nil,
         contactPhone: String? = nil,
         photos: [LocationPhoto] = [],
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.address = address
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.photos = photos
        self.notes = notes
        self.date = Date()
    }
}

// 照片模型
struct LocationPhoto: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let date: Date
    var tags: Set<String>
    var weather: String?
    var note: String?
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    init?(image: UIImage, tags: Set<String> = [], weather: String? = nil, note: String? = nil) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        self.id = UUID()
        self.imageData = imageData
        self.date = Date()
        self.tags = tags
        self.weather = weather
        self.note = note
    }
    
    static let placeholder = UIImage(systemName: "photo.fill")!
} 