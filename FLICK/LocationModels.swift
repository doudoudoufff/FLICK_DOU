import SwiftUI

// 堪景场地模型
struct LocationGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var photos: [LocationPhoto]
    var note: String?
    
    init(id: UUID = UUID(), name: String, note: String? = nil) {
        self.id = id
        self.name = name
        self.date = Date()
        self.photos = []
        self.note = note
    }
}

// 照片模型
struct LocationPhoto: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let date: Date
    var note: String?
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    init?(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        self.id = UUID()
        self.imageData = imageData
        self.date = Date()
        self.note = nil
    }
    
    static let placeholder = UIImage(systemName: "photo.fill")!
} 