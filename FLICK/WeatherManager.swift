import Foundation
import SwiftUI
import CoreLocation
import WeatherKit

// 天气数据模型 - 直接使用 WeatherKit
struct WeatherInfo: Equatable {
    let temperature: Double
    let condition: String
    let symbolName: String
    let windSpeed: Double
    let windDirection: String
    let humidity: Double
    let visibility: Double
    let pressure: Double
    let precipitationIntensity: Double
    let date: Date
    
    // 判断是否相等的实现
    static func == (lhs: WeatherInfo, rhs: WeatherInfo) -> Bool {
        lhs.date == rhs.date &&
        lhs.temperature == rhs.temperature &&
        lhs.condition == rhs.condition
    }
    
    // 创建一个默认值，用于在 WeatherKit 服务不可用时
    static func defaultInfo() -> WeatherInfo {
        print("使用默认天气数据")
        return WeatherInfo(
            temperature: 25.0,
            condition: "晴朗",
            symbolName: "sun.max.fill",
            windSpeed: 2.5,
            windDirection: "东南",
            humidity: 0.6,
            visibility: 10000,
            pressure: 1013,
            precipitationIntensity: 0,
            date: Date()
        )
    }
}

// 天气管理器 - 单例模式实现，使用 WeatherKit
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    private let weatherService = WeatherService.shared
    
    @Published var weatherInfo: WeatherInfo?
    @Published var isLoading = false
    @Published var error: String?
    
    private var lastFetchTime: Date?
    private let cacheTime: TimeInterval = 30 * 60 // 30分钟缓存
    private let locationManager = CLLocationManager()
    private var shouldUseWeatherKit = true // 启用WeatherKit
    
    // 私有初始化器，确保只通过shared访问
    private override init() {
        super.init()
        print("初始化WeatherManager")
        // 默认先加载一个默认天气数据，避免界面空白
        self.weatherInfo = WeatherInfo.defaultInfo()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // CLLocationManagerDelegate 方法
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            error = "位置服务被禁用，将使用默认位置"
            print("位置服务被禁用，使用默认位置数据")
            // 如果位置服务被禁用，使用默认天气数据
            if self.weatherInfo == nil {
                self.weatherInfo = WeatherInfo.defaultInfo()
            }
        case .notDetermined:
            // 等待用户做出选择
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            locationManager.stopUpdatingLocation()
            if shouldUseWeatherKit {
                fetchWeatherForLocation(location)
            } else {
                print("已获取位置，但使用默认天气数据")
                self.weatherInfo = WeatherInfo.defaultInfo()
                self.lastFetchTime = Date()
                self.isLoading = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
        self.error = "位置获取失败，将使用默认位置"
        
        // 如果无法获取位置，使用默认天气数据
        if self.weatherInfo == nil {
            self.weatherInfo = WeatherInfo.defaultInfo()
        }
    }
    
    // 获取天气数据
    func fetchWeatherData(force: Bool = false) {
        // 如果已经有缓存的天气数据，并且缓存未过期，则直接返回
        if !force,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTime,
           weatherInfo != nil {
            return
        }
        
        isLoading = true
        error = nil
        
        // 如果不使用WeatherKit，直接使用默认天气数据
        if !shouldUseWeatherKit {
            print("跳过WeatherKit请求，使用默认天气数据")
            DispatchQueue.main.async {
                self.weatherInfo = WeatherInfo.defaultInfo()
                self.lastFetchTime = Date()
                self.isLoading = false
            }
            return
        }
        
        // 检查位置权限状态
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 请求位置更新
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // 如果位置服务被禁用，使用默认天气数据
            self.weatherInfo = WeatherInfo.defaultInfo()
            self.lastFetchTime = Date()
            self.isLoading = false
        case .notDetermined:
            // 请求位置权限
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            // 使用默认天气数据
            self.weatherInfo = WeatherInfo.defaultInfo()
            self.lastFetchTime = Date()
            self.isLoading = false
        }
    }
    
    // 获取指定位置的天气数据
    private func fetchWeatherForLocation(_ location: CLLocation) {
        Task {
            do {
                print("开始请求位置 \(location.coordinate.latitude), \(location.coordinate.longitude) 的天气数据")
                
                // 获取当前天气
                let currentWeather = try await weatherService.weather(for: location)
                
                // 确保获取到的符号名称是有效的 SF Symbol 名称
                let safeSymbolName = safeWeatherSymbolName(currentWeather.currentWeather.symbolName)
                
                // 构建我们的天气数据模型
                let weatherInfo = WeatherInfo(
                    temperature: currentWeather.currentWeather.temperature.value,
                    condition: currentWeather.currentWeather.condition.description,
                    symbolName: safeSymbolName,
                    windSpeed: currentWeather.currentWeather.wind.speed.value,
                    windDirection: formatWindDirection(currentWeather.currentWeather.wind.direction),
                    humidity: currentWeather.currentWeather.humidity,
                    visibility: currentWeather.currentWeather.visibility.value,
                    pressure: currentWeather.currentWeather.pressure.value,
                    precipitationIntensity: currentWeather.currentWeather.precipitationIntensity.value,
                    date: currentWeather.currentWeather.date
                )
                
                // 在主线程更新 UI
                await MainActor.run {
                    self.weatherInfo = weatherInfo
                    self.lastFetchTime = Date()
                    self.isLoading = false
                    print("成功获取天气数据: \(weatherInfo.condition), \(weatherInfo.temperature)°C, 图标: \(safeSymbolName)")
                }
            } catch {
                await MainActor.run {
                    print("天气数据获取错误: \(error)")
                    
                    // 出现错误时使用默认天气数据
                    if self.weatherInfo == nil {
                        self.weatherInfo = WeatherInfo.defaultInfo()
                    }
                    
                    self.error = "获取天气数据失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // 将 WeatherKit 符号名称转换为有效的 SF Symbol 名称
    private func safeWeatherSymbolName(_ symbolName: String) -> String {
        // 如果符号名称为空或不存在，返回默认图标
        guard !symbolName.isEmpty else {
            return "sun.max.fill"
        }
        
        // 检查符号名称是否包含有效的 SF Symbol 前缀
        let commonPrefixes = ["sun.", "cloud.", "moon.", "wind.", "snow.", "rain.", "thermometer.", "humidity."]
        if commonPrefixes.contains(where: symbolName.contains) {
            return symbolName
        }
        
        // 根据符号名称映射到常见的天气图标
        if symbolName.contains("clear") {
            return "sun.max.fill"
        } else if symbolName.contains("cloud") {
            return "cloud.fill"
        } else if symbolName.contains("rain") || symbolName.contains("drizzle") {
            return "cloud.rain.fill"
        } else if symbolName.contains("snow") || symbolName.contains("sleet") {
            return "cloud.snow.fill"
        } else if symbolName.contains("fog") || symbolName.contains("haze") {
            return "cloud.fog.fill"
        } else if symbolName.contains("thunderstorm") {
            return "cloud.bolt.rain.fill"
        } else {
            return "cloud.fill" // 默认图标
        }
    }
    
    // 格式化风向
    private func formatWindDirection(_ direction: Measurement<UnitAngle>) -> String {
        let degrees = direction.value
        let directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        let index = Int(round(degrees / 45.0).truncatingRemainder(dividingBy: 8))
        return directions[index]
    }
} 