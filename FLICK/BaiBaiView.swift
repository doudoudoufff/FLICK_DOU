import SwiftUI

struct BaiBaiView: View {
    let projectColor: Color
    @StateObject private var weatherManager = WeatherManager.shared
    @State private var currentBlessing: String?
    @State private var showingBlessing = false
    @State private var rotation: Double = 0
    @State private var lunarInfo: LunarInfo?
    @State private var isLoading = false
    @State private var error: String?
    @State private var bowAngle: Double = 0  // 鞠躬角度
    @State private var isAnimating = false   // 动画状态
    @State private var showMultipeerSetup = false  // 是否显示多人拜拜设置
    
    // 祈福语录库
    private let blessings = [
        "今天拍摄一切顺利",
        "不超时，不加班，没有奇葩往里窜",
        "设备零故障，演员不NG",
        "天气给力，光线完美",
        "场地方配合度满分",
        "演员状态在线，一条过",
        "道具、服装、化妆都准时到位",
        "没有突发事件，按计划完成",
        "预算充足，不会超支",
        "剧组伙食特别好",
        "今天不会堵车",
        "设备师心情愉悦",
        "导演今天特别好说话",
        "制片今天特别大方",
        "摄影师今天手感超好",
        "录音师说今天特别安静",
        "化妆师说今天状态绝佳",
        "场记说今天特别顺利",
        "群演都特别配合",
        "今天不会下雨"
    ]
    
    // 首先添加一个结构体来处理黄历数据
    private struct LunarInfo: Decodable {
        let code: Int
        let msg: String
        let data: LunarData?
        let ip: String
        let url: String
        let weixin: String
        let update: String
        
        struct LunarData: Decodable {
            let Solar: String
            let Week: String
            let Constellation: String
            let Festivals: String
            let OtherFestivals: String
            let LunarYear: String
            let Lunar: String
            let LunarMonthDayCount: Int
            let IsLeapMonth: Bool
            let ThisYear: String
            let GanZhiYear: String
            let Lunar_Festivals: String
            let Lunar_OtherFestivals: String
            let JieQi1: String
            let ShuJiu: String
            let SanFu: String
            let YiDay: String
            let JiDay: String
            let WeiYu_s: String
            let WeiYu_l: String
            
            // 不需要 Unicode 解码，因为 JSON 已经是解码后的中文
            var decodedLunar: String { Lunar }
            var decodedSolar: String { Solar }
            var decodedWeek: String { Week }
            var decodedYi: String { YiDay }
            var decodedJi: String { JiDay }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 多人拜拜按钮
                NavigationLink(destination: MultipeerBaiBaiSetupView(projectColor: projectColor), isActive: $showMultipeerSetup) {
                    Button {
                        showMultipeerSetup = true
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title2)
                            Text("多人拜拜")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .foregroundColor(projectColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // 拜拜按钮
                Button {
                    // 添加震动反馈
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    // 执行鞠躬动画
                    withAnimation(.easeInOut(duration: 0.3)) {
                        bowAngle = 30  // 向前倾斜30度
                        showingBlessing = false
                    }
                    
                    // 回弹动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            bowAngle = 0  // 回到原位
                        }
                    }
                    
                    // 显示祈福语
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        currentBlessing = blessings.randomElement()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                            showingBlessing = true
                        }
                    }
                } label: {
                    ZStack {
                        // 光晕效果
                        Circle()
                            .fill(projectColor.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)
                        
                        // 主按钮
                        Circle()
                            .fill(projectColor.gradient)
                            .frame(width: 120, height: 120)
                            .shadow(color: projectColor.opacity(0.3), radius: 15, x: 0, y: 8)
                        
                        // 文字
                        Text("拜拜")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .rotation3DEffect(
                        .degrees(bowAngle),
                        axis: (x: 1, y: 0, z: 0),  // 沿X轴旋转，实现前倾效果
                        anchor: .center,
                        anchorZ: 0,
                        perspective: 1
                    )
                }
                
                // 祈福语显示区域
                if showingBlessing, let blessing = currentBlessing {
                    Text(blessing)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(projectColor)
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 提示文本
                Text("点击按钮获取今日祈福")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // 天气信息卡片
                if let weather = weatherManager.weatherInfo {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日天气")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 20) {
                            // 天气图标 - 使用系统 SF Symbols
                            Image(systemName: weather.symbolName.isEmpty ? "sun.max.fill" : weather.symbolName)
                                .symbolRenderingMode(.multicolor)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(weather.condition)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(String(format: "%.1f°C", weather.temperature))
                                    .font(.title3)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 天气详情
                        VStack(spacing: 8) {
                            HStack {
                                WeatherDetailItem(icon: "wind", label: "风向", value: "\(weather.windDirection) \(String(format: "%.1f", weather.windSpeed))m/s")
                                Spacer()
                                WeatherDetailItem(icon: "humidity", label: "湿度", value: "\(String(format: "%.0f", weather.humidity * 100))%")
                            }
                            
                            HStack {
                                WeatherDetailItem(icon: "eye", label: "能见度", value: "\(String(format: "%.1f", weather.visibility / 1000))km")
                                Spacer()
                                WeatherDetailItem(icon: "umbrella", label: "降水量", value: "\(String(format: "%.1f", weather.precipitationIntensity))mm")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                } else if weatherManager.isLoading {
                    // 天气加载中
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // 显示黄历信息
                if let info = lunarInfo?.data {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日黄历")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        // 日期信息
                        VStack(alignment: .leading, spacing: 8) {
                            Text(info.decodedLunar)
                                .font(.headline)
                            Text(info.decodedSolar)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(info.decodedWeek)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        
                        Divider()
                        
                        // 宜忌
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("宜", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(info.decodedYi)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("忌", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(info.decodedJi)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                }
            }
            .padding()
        }
        .navigationTitle("开机拜拜")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchLunarData()
            weatherManager.fetchWeatherData()
        }
        .overlay {
            if isLoading && lunarInfo == nil {
                ProgressView()
            }
        }
    }
    
    // 天气详情项组件
    private struct WeatherDetailItem: View {
        let icon: String
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.subheadline)
                }
            }
        }
    }
    
    private func fetchLunarData() {
        isLoading = true
        
        let urlString = "https://api.shwgij.com/api/lunars/lunar"
        guard let url = URL(string: urlString) else {
            error = "无效的 URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // 改为 POST 请求
        
        // 设置请求体
        let postData = "key=EXx6f9LLxgivqKCj4rwM8xUCUP"
        request.httpBody = postData.data(using: .utf8)
        
        // 设置请求头
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    self.error = "网络请求错误: \(error.localizedDescription)"
                    print("网络错误详情: \(error)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("响应状态码: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        if let data = data {
                            do {
                                let lunarInfo = try JSONDecoder().decode(LunarInfo.self, from: data)
                                self.lunarInfo = lunarInfo
                                print("成功解析黄历数据")
                            } catch {
                                self.error = "黄历数据解析错误: \(error.localizedDescription)"
                                print("解析错误详情: \(error)")
                            }
                        }
                    } else {
                        self.error = "黄历API请求失败 (状态码: \(httpResponse.statusCode))"
                    }
                }
            }
        }

        task.resume()
    }
}

#Preview {
    NavigationStack {
        BaiBaiView(projectColor: .blue)
    }
} 
