import Foundation
import SwiftUI
import PencilKit

/// 绘图管理器，处理图片编辑和绘制功能
class DrawingManager: ObservableObject {
    /// 当前选择的绘制工具类型
    @Published var selectedTool: DrawingToolType = .pen
    
    /// 当前选择的颜色
    @Published var selectedColor: Color = .red
    
    /// 当前线条宽度
    @Published var lineWidth: CGFloat = 3.0
    
    /// 当前绘制的元素
    @Published var currentElement: DrawingElement?
    
    /// 已完成的绘制元素
    @Published var completedElements: [DrawingElement] = []
    
    /// 是否处于绘制状态
    @Published var isDrawing = false
    
    /// 是否可以撤销
    var canUndo: Bool {
        return !completedElements.isEmpty
    }
    
    /// 是否可以重做
    var canRedo: Bool {
        // TODO: 实现重做功能
        return false
    }
    
    /// 绘制工具类型
    enum DrawingToolType {
        case pen        // 自由绘制
        case line       // 直线
        case arrow      // 箭头
        case rectangle  // 矩形
        case ellipse    // 椭圆
        case text       // 文字
        case eraser     // 橡皮擦
    }
    
    /// 开始绘制
    /// - Parameter point: 起始点
    func startDrawing(at point: CGPoint) {
        isDrawing = true
        
        // 创建新的绘制元素
        let type: DrawingElementType
        switch selectedTool {
        case .pen:
            type = .line
        case .line:
            type = .line
        case .arrow:
            type = .arrow
        case .rectangle:
            type = .rectangle
        case .ellipse:
            type = .ellipse
        case .text:
            type = .text
        case .eraser:
            // 橡皮擦特殊处理
            handleEraser(at: point)
            return
        }
        
        // 将Color转换为十六进制字符串
        let colorHex = selectedColor.toHex() ?? "#FF0000"
        
        // 创建新元素
        currentElement = DrawingElement(
            type: type,
            color: colorHex,
            lineWidth: lineWidth,
            points: [point]
        )
    }
    
    /// 继续绘制
    /// - Parameter point: 当前点
    func continueDrawing(at point: CGPoint) {
        guard isDrawing, var element = currentElement else { return }
        
        // 添加点到当前绘制元素
        element.points.append(point)
        currentElement = element
    }
    
    /// 结束绘制
    /// - Parameter point: 结束点
    func endDrawing(at point: CGPoint) {
        guard isDrawing, var element = currentElement else { return }
        
        // 添加最后一个点
        if point != element.points.last {
            element.points.append(point)
        }
        
        // 将完成的元素添加到列表
        completedElements.append(element)
        
        // 重置当前元素和绘制状态
        currentElement = nil
        isDrawing = false
    }
    
    /// 处理橡皮擦
    /// - Parameter point: 擦除点
    private func handleEraser(at point: CGPoint) {
        // 查找与点相交的元素
        let eraseRadius: CGFloat = lineWidth * 2
        
        // 从后向前查找，以便先擦除最上层的元素
        for i in (0..<completedElements.count).reversed() {
            let element = completedElements[i]
            
            // 检查点是否在元素路径上
            if isPoint(point, nearElement: element, tolerance: eraseRadius) {
                // 移除元素
                completedElements.remove(at: i)
                // 只擦除一个元素后退出
                break
            }
        }
    }
    
    /// 检查点是否在元素附近
    /// - Parameters:
    ///   - point: 检查点
    ///   - element: 绘制元素
    ///   - tolerance: 容差
    /// - Returns: 是否在元素附近
    private func isPoint(_ point: CGPoint, nearElement element: DrawingElement, tolerance: CGFloat) -> Bool {
        // 根据元素类型进行不同的检查
        switch element.type {
        case .line, .arrow:
            // 检查点是否在线段附近
            for i in 0..<(element.points.count - 1) {
                let start = element.points[i]
                let end = element.points[i + 1]
                
                if distanceFromPoint(point, toLineSegment: (start, end)) <= tolerance {
                    return true
                }
            }
            
        case .rectangle:
            // 检查点是否在矩形边界附近
            if element.points.count >= 2 {
                let start = element.points.first!
                let end = element.points.last!
                
                let minX = min(start.x, end.x)
                let maxX = max(start.x, end.x)
                let minY = min(start.y, end.y)
                let maxY = max(start.y, end.y)
                
                // 检查是否在矩形的四条边附近
                if (abs(point.x - minX) <= tolerance && point.y >= minY - tolerance && point.y <= maxY + tolerance) ||
                   (abs(point.x - maxX) <= tolerance && point.y >= minY - tolerance && point.y <= maxY + tolerance) ||
                   (abs(point.y - minY) <= tolerance && point.x >= minX - tolerance && point.x <= maxX + tolerance) ||
                   (abs(point.y - maxY) <= tolerance && point.x >= minX - tolerance && point.x <= maxX + tolerance) {
                    return true
                }
            }
            
        case .ellipse:
            // 检查点是否在椭圆边界附近
            if element.points.count >= 2 {
                let start = element.points.first!
                let end = element.points.last!
                
                let centerX = (start.x + end.x) / 2
                let centerY = (start.y + end.y) / 2
                let radiusX = abs(end.x - start.x) / 2
                let radiusY = abs(end.y - start.y) / 2
                
                if radiusX > 0 && radiusY > 0 {
                    // 计算点到椭圆的距离（近似）
                    let dx = point.x - centerX
                    let dy = point.y - centerY
                    
                    // 归一化坐标
                    let normalizedX = dx / radiusX
                    let normalizedY = dy / radiusY
                    
                    // 计算到椭圆的距离
                    let distance = abs(normalizedX * normalizedX + normalizedY * normalizedY - 1)
                    
                    return distance <= tolerance / min(radiusX, radiusY)
                }
            }
            
        case .text:
            // 检查点是否在文本框内
            if element.points.count >= 2 {
                let start = element.points.first!
                let end = element.points.last!
                
                let minX = min(start.x, end.x)
                let maxX = max(start.x, end.x)
                let minY = min(start.y, end.y)
                let maxY = max(start.y, end.y)
                
                return point.x >= minX - tolerance && point.x <= maxX + tolerance &&
                       point.y >= minY - tolerance && point.y <= maxY + tolerance
            }
        }
        
        return false
    }
    
    /// 计算点到线段的距离
    /// - Parameters:
    ///   - point: 点
    ///   - lineSegment: 线段的起点和终点
    /// - Returns: 距离
    private func distanceFromPoint(_ point: CGPoint, toLineSegment lineSegment: (CGPoint, CGPoint)) -> CGFloat {
        let (start, end) = lineSegment
        
        // 如果线段实际上是一个点
        if start == end {
            return hypot(point.x - start.x, point.y - start.y)
        }
        
        // 计算点到线段的距离
        let a = point.x - start.x
        let b = point.y - start.y
        let c = end.x - start.x
        let d = end.y - start.y
        
        let dot = a * c + b * d
        let lenSq = c * c + d * d
        var param = dot / lenSq
        
        // 如果投影点在线段外，取最近端点
        if param < 0 {
            param = 0
        } else if param > 1 {
            param = 1
        }
        
        let projX = start.x + param * c
        let projY = start.y + param * d
        
        return hypot(point.x - projX, point.y - projY)
    }
    
    /// 撤销最后一个绘制操作
    func undo() {
        guard !completedElements.isEmpty else { return }
        completedElements.removeLast()
    }
    
    /// 清除所有绘制
    func clearAll() {
        completedElements.removeAll()
        currentElement = nil
        isDrawing = false
    }
    
    /// 将绘制元素渲染到图片上
    /// - Parameters:
    ///   - image: 原始图片
    ///   - elements: 绘制元素数组
    /// - Returns: 渲染后的图片
    func renderDrawing(on image: UIImage, elements: [DrawingElement]) -> UIImage {
        let imageSize = image.size
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制原始图片
        image.draw(at: .zero)
        
        // 获取上下文
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // 绘制所有元素
        for element in elements {
            drawElement(element, in: context, imageSize: imageSize)
        }
        
        // 获取结果图片
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// 在上下文中绘制元素
    /// - Parameters:
    ///   - element: 绘制元素
    ///   - context: 绘图上下文
    ///   - imageSize: 图片尺寸
    private func drawElement(_ element: DrawingElement, in context: CGContext, imageSize: CGSize) {
        // 设置绘制属性
        context.setLineWidth(element.lineWidth)
        context.setStrokeColor(UIColor(hex: element.color)?.cgColor ?? UIColor.red.cgColor)
        
        // 根据元素类型进行绘制
        switch element.type {
        case .line:
            drawLine(element, in: context)
            
        case .arrow:
            drawArrow(element, in: context)
            
        case .rectangle:
            drawRectangle(element, in: context)
            
        case .ellipse:
            drawEllipse(element, in: context)
            
        case .text:
            drawText(element, in: context, imageSize: imageSize)
        }
    }
    
    /// 绘制线条
    private func drawLine(_ element: DrawingElement, in context: CGContext) {
        guard !element.points.isEmpty else { return }
        
        context.beginPath()
        context.move(to: element.points[0])
        
        for i in 1..<element.points.count {
            context.addLine(to: element.points[i])
        }
        
        context.strokePath()
    }
    
    /// 绘制箭头
    private func drawArrow(_ element: DrawingElement, in context: CGContext) {
        guard element.points.count >= 2 else { return }
        
        // 绘制主线
        let start = element.points.first!
        let end = element.points.last!
        
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        
        // 绘制箭头
        let arrowLength = element.lineWidth * 5
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle1 = angle + .pi * 3/4
        let arrowAngle2 = angle - .pi * 3/4
        
        let arrowPoint1 = CGPoint(
            x: end.x + arrowLength * cos(arrowAngle1),
            y: end.y + arrowLength * sin(arrowAngle1)
        )
        
        let arrowPoint2 = CGPoint(
            x: end.x + arrowLength * cos(arrowAngle2),
            y: end.y + arrowLength * sin(arrowAngle2)
        )
        
        context.beginPath()
        context.move(to: end)
        context.addLine(to: arrowPoint1)
        context.move(to: end)
        context.addLine(to: arrowPoint2)
        context.strokePath()
    }
    
    /// 绘制矩形
    private func drawRectangle(_ element: DrawingElement, in context: CGContext) {
        guard element.points.count >= 2 else { return }
        
        let start = element.points.first!
        let end = element.points.last!
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        context.stroke(rect)
    }
    
    /// 绘制椭圆
    private func drawEllipse(_ element: DrawingElement, in context: CGContext) {
        guard element.points.count >= 2 else { return }
        
        let start = element.points.first!
        let end = element.points.last!
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        context.strokeEllipse(in: rect)
    }
    
    /// 绘制文本
    private func drawText(_ element: DrawingElement, in context: CGContext, imageSize: CGSize) {
        guard element.points.count >= 2, let text = element.text, !text.isEmpty else { return }
        
        let start = element.points.first!
        let end = element.points.last!
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        // 设置文本属性
        let font = UIFont.systemFont(ofSize: element.lineWidth * 6)
        let color = UIColor(hex: element.color) ?? .red
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        // 绘制文本
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(in: rect)
    }
}

// MARK: - UIColor扩展，用于从十六进制字符串创建颜色
extension UIColor {
    /// 从十六进制字符串创建UIColor
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        let hexColor = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        
        guard scanner.scanHexInt64(&hexNumber) else {
            return nil
        }
        
        r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
        b = CGFloat(hexNumber & 0x0000ff) / 255
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
} 