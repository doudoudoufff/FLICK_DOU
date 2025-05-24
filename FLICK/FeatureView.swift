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
    @State private var sparkleAnimation = false
    @State private var pulseAnimation = false
    @State private var rotateAnimation = false
    
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
                // 背景光环效果 - 调整大小和间距
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(projectColor.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 130 + CGFloat(index * 15), height: 130 + CGFloat(index * 15))
                        .scaleEffect(pulseAnimation ? 1.05 : 0.98)
                        .opacity(pulseAnimation ? 0.4 : 0.7)
                        .animation(
                            .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.5),
                            value: pulseAnimation
                        )
                }
                
                // 闪烁星星效果 - 调整位置和大小
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 8))
                        .foregroundColor(projectColor.opacity(0.6))
                        .offset(
                            x: cos(Double(index) * .pi / 3) * 100,
                            y: sin(Double(index) * .pi / 3) * 100
                        )
                        .rotationEffect(.degrees(rotateAnimation ? 360 : 0))
                        .scaleEffect(sparkleAnimation ? 1.0 : 0.3)
                        .opacity(sparkleAnimation ? 0.8 : 0.3)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: sparkleAnimation
                        )
                }
                
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
                    // 外层光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [projectColor.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 6)
                    
                    // 主按钮
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [projectColor, projectColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 100, height: 100)
                        )
                        .shadow(color: projectColor.opacity(0.3), radius: 15, x: 0, y: 8)
                        
                        if isMotionMode {
                            // 陀螺仪模式下显示指引
                            VStack(spacing: 6) {
                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 24, weight: .medium))
                                    .rotationEffect(.degrees(motionManager.bowProgress * 30))
                                Text("鞠躬 \(motionManager.bowCount)/3")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        } else {
                            // 普通模式下显示"拜拜"文字和装饰
                            VStack(spacing: 3) {
                                HStack(spacing: 3) {
                                    Image(systemName: "hands.sparkles")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("拜拜")
                                        .font(.system(size: 24, weight: .bold))
                                    Image(systemName: "hands.sparkles")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                Text("祈福")
                                    .font(.system(size: 10, weight: .medium))
                                    .opacity(0.9)
                            }
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                }
                .rotation3DEffect(
                        .degrees(isMotionMode ? (motionManager.bowProgress * 30) : bowAngle),
                    axis: (x: 1, y: 0, z: 0)
                )
            }
            }
            .frame(height: 220) // 固定高度，给动画元素足够空间
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
            .onAppear {
                // 启动环形动画
                pulseAnimation = true
                sparkleAnimation = true
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    rotateAnimation = true
                }
            }
            
            // 提示文本 - 移到按钮下方
            if !isMotionMode {
                VStack(spacing: 4) {
                    Text("长按开启陀螺仪模式")
                        .font(.caption)
                    Text("或点击获取祈福")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.8))
                .cornerRadius(8)
            } else {
                Text("手持设备，自然鞠躬三次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6).opacity(0.8))
                    .cornerRadius(8)
            }
            
            // 祝福语显示 - 增强样式
            if showingBlessing, let blessing = currentBlessing {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    .font(.system(size: 12))
                    
                    Text(blessing)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(projectColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(projectColor.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(projectColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    .font(.system(size: 12))
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // 天气信息
            if let weather = weatherManager.weatherInfo {
                HStack(spacing: 20) {
                    Image(systemName: weather.symbolName.isEmpty ? "sun.max.fill" : weather.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.condition == "Cloudy" ? "多云" : weather.condition)
                            .font(.headline)
                        Text(String(format: "%.1f°C", weather.temperature))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "wind")
                            Text("\(weather.windDirection) \(String(format: "%.1f", weather.windSpeed))m/s")
                        }.font(.caption)
                        HStack(spacing: 4) {
                            Image(systemName: "humidity")
                            Text("\(String(format: "%.0f", weather.humidity * 100))%")
                        }.font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(projectColor.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
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
