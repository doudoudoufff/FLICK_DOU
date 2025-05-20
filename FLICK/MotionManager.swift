import Foundation
import CoreMotion
import UIKit

// 设备运动管理器，用于检测鞠躬动作
class MotionManager: ObservableObject {
    static let shared = MotionManager()
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    // 鞠躬动作的状态
    @Published var isBowing = false
    @Published var bowCount = 0
    @Published var bowProgress: Double = 0
    
    // 鞠躬检测阈值
    private let pitchThreshold: Double = -0.5  // 大约30度
    private var lastBowTime: Date?
    private var isInBowingPosition = false
    private var hasBowedRecently = false
    
    // 鞠躬完成的回调
    var onBowingComplete: (() -> Void)?
    
    private init() {
        queue.name = "com.flick.motionQueue"
    }
    
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("设备运动数据不可用")
            return
        }
        
        bowCount = 0
        bowProgress = 0
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("获取设备运动数据失败: \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.detectBowing(motion)
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        bowCount = 0
        bowProgress = 0
        isInBowingPosition = false
        hasBowedRecently = false
    }
    
    private func detectBowing(_ motion: CMDeviceMotion) {
        // pitch值表示设备前后倾斜角度，负值表示设备顶部向下倾斜
        let pitch = motion.attitude.pitch
        
        // 更新鞠躬进度，用于动画
        let normalizedPitch = min(1.0, max(0.0, -pitch / 1.0))
        bowProgress = normalizedPitch
        
        // 检测鞠躬动作（手机顶部向下倾斜超过阈值）
        if pitch < pitchThreshold && !isInBowingPosition {
            isInBowingPosition = true
            isBowing = true
            
            // 检查是否是新的一次鞠躬（防止连续触发）
            let now = Date()
            if let lastBow = lastBowTime, now.timeIntervalSince(lastBow) < 1.0 {
                // 如果与上次鞠躬间隔太短，忽略这次
                return
            }
            
            lastBowTime = now
            
            // 震动反馈
            generateHapticFeedback()
            
            // 增加鞠躬计数
            bowCount += 1
            print("检测到鞠躬 #\(bowCount)")
            
            // 连续鞠躬三次后触发回调
            if bowCount >= 3 && !hasBowedRecently {
                hasBowedRecently = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onBowingComplete?()
                    
                    // 重置状态，防止短时间内重复触发
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.hasBowedRecently = false
                    }
                }
            }
        } else if pitch >= pitchThreshold && isInBowingPosition {
            // 恢复到正常位置
            isInBowingPosition = false
            isBowing = false
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
} 