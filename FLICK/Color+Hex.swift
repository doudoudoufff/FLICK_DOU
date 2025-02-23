import SwiftUI
import UIKit

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
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
        self.init(red: Double(uiColor.cgColor.components?[0] ?? 0),
                 green: Double(uiColor.cgColor.components?[1] ?? 0),
                 blue: Double(uiColor.cgColor.components?[2] ?? 0),
                 opacity: Double(uiColor.cgColor.components?[3] ?? 1))
    }
} 