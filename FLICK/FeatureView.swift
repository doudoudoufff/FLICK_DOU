import SwiftUI
import CloudKit
import CoreData

struct FeatureView: View {
    @State private var showSettingsDetail = false
    @State private var showingAddTask = false
    @EnvironmentObject private var projectStore: ProjectStore
    
    // 引导相关状态
    @AppStorage("hasSeenFeatureTutorial") private var hasSeenFeatureTutorial = false
    @State private var showTutorial = false
    @State private var tutorialRefreshTrigger = UUID() // 引导刷新触发器
    
    // 功能元素的框架位置
    @State private var baiBaiCardFrame: CGRect = .zero
    @State private var remindMeFrame: CGRect = .zero
    @State private var recordExpenseFrame: CGRect = .zero
    @State private var commonInfoFrame: CGRect = .zero
    @State private var favoriteVenueFrame: CGRect = .zero
    @State private var scoutingFrame: CGRect = .zero
    
    // 直接从PersistenceController获取上下文
    private var persistenceContext: NSManagedObjectContext {
        return PersistenceController.shared.container.viewContext
    }
    
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
                            .getFrame($baiBaiCardFrame)
                        
                        VStack(spacing: 20) {
                            // 第一排：提醒我做、记一笔账
                            HStack(spacing: 20) {
                                FeatureCardButton(icon: "checklist", title: "提醒我做") {
                                    showingAddTask = true
                                }
                                .getFrame($remindMeFrame)
                                
                                FeatureCardButton(icon: "creditcard.fill", title: "记一笔账") {
                                    // 直接打开记账表单
                                    let formVC = UIHostingController(rootView: 
                                        GlobalTransactionFormView()
                                            .environmentObject(projectStore)
                                    )
                                    UIApplication.shared.windows.first?.rootViewController?
                                        .present(formVC, animated: true)
                                }
                                .getFrame($recordExpenseFrame)
                            }
                            
                            // 第二排：常用信息+收藏地址（左侧），堪景（右侧）
                            HStack(spacing: 20) {
                                // 左侧：常用信息和收藏地址的水平布局
                                HStack(spacing: 12) {
                                    // 常用信息（小按钮）
                                    NavigationLink(destination: CommonInfoManagementView()) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(Color.blue.opacity(0.85))
                                            Text("常用信息")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(.systemBackground).opacity(0.95))
                                        .cornerRadius(16)
                                        .shadow(color: Color.blue.opacity(0.10), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .getFrame($commonInfoFrame)
                                    
                                    // 收藏场地管理（小按钮）
                                    NavigationLink(destination: {
                                        let context = PersistenceController.shared.container.viewContext
                                        return VenueListView(context: context)
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "building.2.fill")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(Color.blue.opacity(0.85))
                                            Text("收藏场地")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(.systemBackground).opacity(0.95))
                                        .cornerRadius(16)
                                        .shadow(color: Color.blue.opacity(0.10), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .getFrame($favoriteVenueFrame)
                                }
                                
                                // 右侧：堪景（大按钮）
                                ScoutingCameraView()
                                    .getFrame($scoutingFrame)
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
            .onAppear {
                checkAndShowTutorial()
            }
            // 监听任意框架位置变化
            .onChange(of: baiBaiCardFrame) { _ in updateTutorialIfShowing() }
            .onChange(of: remindMeFrame) { _ in updateTutorialIfShowing() }
            .onChange(of: recordExpenseFrame) { _ in updateTutorialIfShowing() }
            .onChange(of: commonInfoFrame) { _ in updateTutorialIfShowing() }
            .onChange(of: favoriteVenueFrame) { _ in updateTutorialIfShowing() }
            .onChange(of: scoutingFrame) { _ in updateTutorialIfShowing() }
            .overlay(
                ZStack {
                    if showTutorial {
                        TutorialOverlayView(
                            isPresented: $showTutorial,
                            tutorialSteps: featureTutorialSteps,
                            onComplete: {
                                hasSeenFeatureTutorial = true
                            }
                        )
                        .id(tutorialRefreshTrigger) // 使用ID触发刷新
                    }
                }
            )
        }
    }
    
    // 检查并显示教程
    private func checkAndShowTutorial() {
        // 延迟确保视图已完全加载并正确获取位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !hasSeenFeatureTutorial {
                withAnimation {
                    showTutorial = true
                }
            }
        }
    }
    
    // 功能页的教程步骤
    private var featureTutorialSteps: [TutorialStep] {
        var steps: [TutorialStep] = []
        
        // 欢迎步骤
        steps.append(
            TutorialStep(
                title: "欢迎使用 FLICK",
                description: "这是功能页，您可以在这里快速访问App的核心功能。点击屏幕继续浏览。",
                frame: nil
            )
        )
        
        // 只有当框架位置有效时添加对应步骤
        if baiBaiCardFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "拜拜祈福",
                    description: "拍摄前点击此处进行祈福，为拍摄顺利祈求好运。支持传统点击和陀螺仪感应两种模式。",
                    frame: baiBaiCardFrame
                )
            )
        }
        
        if remindMeFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "提醒我做",
                    description: "快速添加待办事项和提醒，帮助您管理拍摄中的各项任务。",
                    frame: remindMeFrame
                )
            )
        }
        
        if recordExpenseFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "记一笔账",
                    description: "随时记录项目支出，管理资金流向，支持多种分类和标签。",
                    frame: recordExpenseFrame
                )
            )
        }
        
        if commonInfoFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "常用信息",
                    description: "存储和管理常用联系人、账号等信息，随时查阅。",
                    frame: commonInfoFrame
                )
            )
        }
        
        if favoriteVenueFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "收藏场地",
                    description: "保存和管理您收藏的拍摄场地信息，包括地址、联系方式等。",
                    frame: favoriteVenueFrame
                )
            )
        }
        
        if scoutingFrame != .zero {
            steps.append(
                TutorialStep(
                    title: "堪景",
                    description: "拍摄场地时使用此功能，可以记录照片、视频、笔记和位置信息。",
                    frame: scoutingFrame
                )
            )
        }
        
        // 结束步骤
        steps.append(
            TutorialStep(
                title: "探索更多",
                description: "现在您已了解功能页的基本功能，开始使用FLICK管理您的项目吧！",
                frame: nil
            )
        )
        
        return steps
    }
    
    // 当框架位置变化时更新引导视图
    private func updateTutorialIfShowing() {
        if showTutorial {
            // 通过改变触发器ID来强制刷新引导视图
            tutorialRefreshTrigger = UUID()
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
    @State private var sparkleAnimation = false
    @State private var pulseAnimation = false
    @State private var rotateAnimation = false
    @State private var showFullscreenMode = false // 是否显示全屏模式
    
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
                    // 点击按钮触发拜拜动画
                        performTraditionalBowing()
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
                    .rotation3DEffect(
                        .degrees(bowAngle),
                        axis: (x: 1, y: 0, z: 0)
                    )
                }
            }
            .frame(height: 220) // 固定高度，给动画元素足够空间
            .contextMenu {
                Button {
                    showFullscreenMode = true
                } label: {
                    Label("开启全屏拜拜模式", systemImage: "sparkles")
                }
            }
            .onLongPressGesture {
                // 长按手势打开全屏模式
                withAnimation {
                    showFullscreenMode = true
                }
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
                VStack(spacing: 4) {
                Text("长按开启全屏拜拜模式")
                        .font(.caption)
                    Text("或点击获取祈福")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.8))
                .cornerRadius(8)
            
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
                NavigationLink(destination: BaiBaiView(projectColor: projectColor)) {
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
                        
                        // 添加一个小的箭头图标，表示可以点击
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.6)
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
                .buttonStyle(PlainButtonStyle())
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
        .fullScreenCover(isPresented: $showFullscreenMode) {
            BaiBaiFullscreenView(projectColor: projectColor)
        }
    }
    
    // 执行传统点击拜拜动画
    private func performTraditionalBowing() {
        // 添加轻微的震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
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
