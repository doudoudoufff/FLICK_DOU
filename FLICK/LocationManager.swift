import Foundation
import CoreLocation

// 定位管理器
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10米变化才更新
        
        // 初始化时检查权限状态
        authorizationStatus = locationManager.authorizationStatus
        
        // 如果已经有权限，尝试获取位置
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
        } else if authorizationStatus == .notDetermined {
            requestLocationPermission()
        }
    }
    
    // 请求定位权限
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // 请求单次定位
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "定位权限未授权"
            return
        }
        
        isLocating = true
        locationError = nil
        locationManager.requestLocation()
    }
    
    // 开始持续定位
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "定位权限未授权"
            return
        }
        
        isLocating = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    // 停止持续定位
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isLocating = false
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 过滤掉过旧或不准确的位置数据
        let age = -location.timestamp.timeIntervalSinceNow
        if age > 5.0 { // 5秒前的数据认为过旧
            return
        }
        
        if location.horizontalAccuracy < 0 { // 无效数据
            return
        }
        
        if location.horizontalAccuracy > 100 { // 精度太低
            return
        }
        
        DispatchQueue.main.async {
            self.location = location
            self.isLocating = false
            self.locationError = nil
            print("✓ 定位成功: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude), 精度 \(location.horizontalAccuracy)m")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置信息"
                case .network:
                    self.locationError = "网络错误，无法定位"
                case .headingFailure:
                    self.locationError = "方向传感器错误"
                case .rangingUnavailable, .rangingFailure:
                    self.locationError = "测距功能不可用"
                case .promptDeclined:
                    self.locationError = "用户拒绝了定位请求"
                default:
                    self.locationError = "定位失败: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
            
            print("❌ 定位错误: \(self.locationError ?? "未知错误")")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .notDetermined:
                print("📍 定位权限: 未确定")
            case .restricted:
                print("📍 定位权限: 受限制")
                self.locationError = "定位功能受限制"
            case .denied:
                print("📍 定位权限: 被拒绝")
                self.locationError = "定位权限被拒绝，请在设置中开启"
            case .authorizedAlways:
                print("📍 定位权限: 始终允许")
                self.locationError = nil
                self.requestLocation()
            case .authorizedWhenInUse:
                print("📍 定位权限: 使用时允许")
                self.locationError = nil
                self.requestLocation()
            @unknown default:
                print("📍 定位权限: 未知状态")
            }
        }
    }
    
    // MARK: - 便利方法
    
    // 检查是否有定位权限
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // 获取当前位置的坐标
    var currentCoordinate: CLLocationCoordinate2D? {
        return location?.coordinate
    }
    
    // 获取位置精度描述
    var accuracyDescription: String {
        guard let location = location else { return "未知" }
        
        let accuracy = location.horizontalAccuracy
        if accuracy < 5 {
            return "非常精确"
        } else if accuracy < 10 {
            return "精确"
        } else if accuracy < 50 {
            return "较精确"
        } else if accuracy < 100 {
            return "一般"
        } else {
            return "不精确"
        }
    }
    
    // 重置错误状态
    func clearError() {
        locationError = nil
    }
} 