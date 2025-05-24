import SwiftUI
import CloudKit

struct FeatureView: View {
    @State private var showSettingsDetail = false
    @State private var showingAddTask = false
    @EnvironmentObject private var projectStore: ProjectStore
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题
                ZStack {
                    Text("功能")
                        .font(.title3)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Spacer()
                        NavigationLink(destination: SettingsDetailView()) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
                
            ScrollView {
                VStack(spacing: 32) {
                    BaiBaiCompactCard(projectColor: .blue)
                        .padding(.top, 8)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 28) {
                        FeatureCardButton(icon: "checklist", title: "提醒我做") {
                            showingAddTask = true
                                    }
                        FeatureCardButton(icon: "creditcard.circle.fill", title: "添加账户") {
                            // TODO: 跳转到账户页面
                        }
                        
                        // 使用独立的堪景相机视图
                        ScoutingCameraView()
                        
                        FeatureCardButton(icon: "creditcard.fill", title: "记一笔账") {
                            // 直接打开记账表单
                            let formVC = UIHostingController(rootView: 
                                GlobalTransactionFormView()
                                    .environmentObject(projectStore)
                            )
                            UIApplication.shared.windows.first?.rootViewController?
                                .present(formVC, animated: true)
                        }
                    }
                    .padding(.horizontal)
                            }
                        }
            }
            .sheet(isPresented: $showingAddTask) {
                NavigationView {
                    AddTaskView(isPresented: $showingAddTask)
                        .environmentObject(projectStore)
                        }
                .presentationDetents([.height(500)])
                    }
        }
    }
}

// 卡片式功能按钮（毛玻璃风格，统一主色）
struct FeatureCardButton: View {
    let icon: String
    let title: String
    let color: Color = Color.blue.opacity(0.85) // 统一主色
    let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
    }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(22)
            .shadow(color: color.opacity(0.10), radius: 8, x: 0, y: 4)
            .scaleEffect(pressed ? 0.96 : 1.0)
            }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// 精简版拜拜卡片，仅首页用
struct BaiBaiCompactCard: View {
    let projectColor: Color
    @State private var currentBlessing: String?
    @State private var showingBlessing = false
    @State private var bowAngle: Double = 0
    @StateObject private var weatherManager = WeatherManager.shared
    @StateObject private var motionManager = MotionManager.shared
    @State private var isLoading = false
    @State private var isMotionMode = false // 是否启用陀螺仪模式
    
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
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 拜拜按钮
            Button {
                    if isMotionMode {
                        // 陀螺仪模式下，按钮只用于切换回普通模式
                        stopMotionMode()
                    } else {
                        // 普通模式下，点击按钮触发拜拜动画
                        performTraditionalBowing()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(projectColor.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .blur(radius: 16)
                    Circle()
                        .fill(projectColor.gradient)
                        .frame(width: 110, height: 110)
                        .shadow(color: projectColor.opacity(0.25), radius: 18, x: 0, y: 8)
                        
                        if isMotionMode {
                            // 陀螺仪模式下显示指引
                            VStack {
                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 32))
                                    .rotationEffect(.degrees(motionManager.bowProgress * 30))
                                Text("鞠躬 \(motionManager.bowCount)/3")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white)
                        } else {
                            // 普通模式下显示"拜拜"文字
                    Text("拜拜")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        }
                }
                .rotation3DEffect(
                        .degrees(isMotionMode ? (motionManager.bowProgress * 30) : bowAngle),
                    axis: (x: 1, y: 0, z: 0)
                )
            }
                
                // 长按开启陀螺仪模式提示
                if !isMotionMode {
                    Text("长按开启陀螺仪模式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.7))
                        .cornerRadius(4)
                        .offset(y: 65)
                        .opacity(0.7)
                }
            }
            .contextMenu {
                Button {
                    toggleMotionMode()
                } label: {
                    Label(isMotionMode ? "切换为普通模式" : "开启陀螺仪模式", 
                          systemImage: isMotionMode ? "hand.tap" : "gyroscope")
                }
            }
            .onLongPressGesture {
                toggleMotionMode()
            }
            
            // 祝福语显示
            if showingBlessing, let blessing = currentBlessing {
                Text(blessing)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(projectColor)
                    .padding(.horizontal, 24)
            }
            
            // 提示文本
            Text(isMotionMode ? "手持设备，自然鞠躬三次" : "点击按钮获取今日祈福")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            // 天气信息
            if let weather = weatherManager.weatherInfo {
                HStack(spacing: 24) {
                    Image(systemName: weather.symbolName.isEmpty ? "sun.max.fill" : weather.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.condition == "Cloudy" ? "多云" : weather.condition)
                            .font(.headline)
                        Text(String(format: "%.1f°C", weather.temperature))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "wind")
                            Text("\(weather.windDirection) \(String(format: "%.1f", weather.windSpeed))m/s")
                        }.font(.caption)
                        HStack {
                            Image(systemName: "humidity")
                            Text("\(String(format: "%.0f", weather.humidity * 100))%")
                        }.font(.caption)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(16)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
        .padding(.horizontal)
        .onAppear {
            weatherManager.fetchWeatherData()
            
            // 设置陀螺仪回调
            motionManager.onBowingComplete = {
                performBlessingAfterBowing()
            }
        }
        .onDisappear {
            stopMotionMode()
        }
    }
    
    // 切换陀螺仪模式
    private func toggleMotionMode() {
        if isMotionMode {
            stopMotionMode()
        } else {
            startMotionMode()
        }
    }
    
    // 开启陀螺仪模式
    private func startMotionMode() {
        withAnimation {
            isMotionMode = true
            showingBlessing = false
        }
        
        // 开始监测设备运动
        motionManager.startMonitoring()
        
        // 震动反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // 停止陀螺仪模式
    private func stopMotionMode() {
        withAnimation {
            isMotionMode = false
        }
        
        // 停止监测设备运动
        motionManager.stopMonitoring()
    }
    
    // 执行传统点击拜拜动画
    private func performTraditionalBowing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            bowAngle = 30
            showingBlessing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bowAngle = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showRandomBlessing()
        }
    }
    
    // 鞠躬后显示祝福语
    private func performBlessingAfterBowing() {
        // 生成更强的震动反馈 - 连续震动效果
        generateStrongHapticFeedback()
        
        // 显示祝福
        showRandomBlessing()
        
        // 延迟后自动切回普通模式
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                isMotionMode = false
            }
            motionManager.stopMonitoring()
            }
    }
    
    // 生成强烈的震动反馈（多次连续震动）
    private func generateStrongHapticFeedback() {
        // 第一次震动：使用错误类型的通知反馈（更强烈）
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
        
        // 第二次震动：0.15秒后重型冲击反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.prepare()
            heavyGenerator.impactOccurred(intensity: 1.0)
            
            // 第三次震动：0.3秒后再次重型冲击
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                heavyGenerator.impactOccurred(intensity: 1.0)
                
                // 第四次震动：再次使用通知反馈
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    notificationGenerator.notificationOccurred(.success)
                }
            }
        }
    }
    
    // 显示随机祝福语
    private func showRandomBlessing() {
        currentBlessing = blessings.randomElement()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            showingBlessing = true
        }
    }
}

#Preview {
    FeatureView()
} 
