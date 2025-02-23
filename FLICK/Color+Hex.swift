import SwiftUI
import UIKit

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case hex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hex = try container.decode(String.self, forKey: .hex)
        self = Color(hex: hex) ?? .blue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.toHex(), forKey: .hex)
    }
}

extension UIColor {
    convenience init?(data: Data) {
        guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        self.init(cgColor: color.cgColor)
    }
    
    func encode() -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
}

extension Color {
    init(uiColor: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
    
    func toData() -> Data? {
        UIColor(self).encode()
    }
    
    init?(data: Data) {
        guard let uiColor = UIColor(data: data) else { return nil }
        self.init(uiColor: uiColor)
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        return String(format: "#%06X", rgb)
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
} 