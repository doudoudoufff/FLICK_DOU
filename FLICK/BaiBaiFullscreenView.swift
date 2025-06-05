import SwiftUI

struct BaiBaiFullscreenView: View {
    let projectColor: Color
    var isAutoMode: Bool = false  // 是否是自动模式（从机模式）
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var motionManager = MotionManager.shared
    @StateObject private var multipeerManager = MultipeerManager.shared  // 添加MultipeerManager
    @State private var currentBlessing: String?
    @State private var showingBlessing = false
    @State private var animationPhase = 0
    @State private var prayerComplete = false
    @State private var particles: [Particle] = []
    @State private var backgroundOpacity = 0.0
    @State private var circleScale = 0.0
    @State private var bowAngle: Double = 0
    @State private var bowInProgress = false
    @State private var bowCount = 0
    @State private var showInstructions = true
    
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
    
    // 粒子效果的定义
    struct Particle: Identifiable {
        var id = UUID()
        var position: CGPoint
        var scale: CGFloat
        var rotation: Double
        var opacity: Double
        var color: Color
        var speed: CGPoint
        var creationTime: Date
        
        var lifetime: TimeInterval {
            return 2.0 + Double.random(in: 0...1.0)
        }
        
        var isAlive: Bool {
            return Date().timeIntervalSince(creationTime) < lifetime
        }
    }
    
    var body: some View {
        ZStack {
            // 背景渐变
            RadialGradient(
                gradient: Gradient(colors: [
                    projectColor.opacity(0.2),
                    Color.black.opacity(0.8)
                ]),
                center: .center,
                startRadius: 1,
                endRadius: 600
            )
            .ignoresSafeArea()
            .opacity(backgroundOpacity)
            
            // 粒子效果
            ForEach(particles) { particle in
                Image(systemName: ["star.fill", "sparkle", "moon.stars.fill", "sun.max.fill"].randomElement()!)
                    .foregroundColor(particle.color)
                    .scaleEffect(particle.scale)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.opacity)
                    .position(particle.position)
            }
            
            VStack(spacing: 30) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.5)) {
                            backgroundOpacity = 0.0
                            circleScale = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                }
                
                Spacer()
                
                // 中央拜拜区域
                VStack(spacing: 20) {
                    if !prayerComplete {
                        if showInstructions && !isAutoMode {
                            // 拜拜引导说明 - 只在手动模式下显示
                            VStack(spacing: 10) {
                                Text("诚心三拜")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("手持设备，自然鞠躬三次")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.3))
                                    .blur(radius: 3)
                            )
                            .opacity(showInstructions ? 1 : 0)
                        } else if isAutoMode {
                            // 自动模式下显示提示
                            VStack(spacing: 10) {
                                Text("同步拜拜")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("正在跟随主持人的动作...")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.3))
                                    .blur(radius: 3)
                            )
                        }
                        
                        // 拜拜指示器
                        ZStack {
                            // 光环效果
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 200 + CGFloat(index * 20), height: 200 + CGFloat(index * 20))
                                    .scaleEffect(circleScale)
                            }
                            
                            // 主圆圈
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            projectColor,
                                            projectColor.opacity(0.7)
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 180, height: 180)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                                .shadow(color: projectColor.opacity(0.6), radius: 20, x: 0, y: 0)
                                .scaleEffect(circleScale)
                            
                            // 拜拜图标和文字
                            VStack(spacing: 15) {
                                Image(systemName: "hands.sparkles.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(bowInProgress ? 30 : 0))
                                    .scaleEffect(bowInProgress ? 1.2 : 1.0)
                                
                                Text("拜拜")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                if !isAutoMode && motionManager.bowCount > 0 {
                                    Text("\(motionManager.bowCount)/3")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                } else if isAutoMode && bowCount > 0 {
                                    Text("\(bowCount)/3")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(circleScale)
                            .rotation3DEffect(
                                .degrees(bowAngle),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .center
                            )
                        }
                    } else {
                        // 祈福完成后显示祝福语
                        if let blessing = currentBlessing {
                            VStack(spacing: 30) {
                                // 顶部装饰
                                HStack(spacing: 20) {
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                    Image(systemName: "moon.stars.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                }
                                
                                // 祝福语
                                Text(blessing)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(projectColor.opacity(0.3))
                                            .blur(radius: 0.5)
                                            .shadow(color: projectColor.opacity(0.5), radius: 10, x: 0, y: 0)
                                    )
                                
                                // 底部装饰
                                HStack(spacing: 20) {
                                    Image(systemName: "moon.stars.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                    Image(systemName: "moon.stars.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                            .scaleEffect(showingBlessing ? 1 : 0.5)
                            .opacity(showingBlessing ? 1 : 0)
                        }
                    }
                }
                
                Spacer()
                
                // 底部返回按钮
                if prayerComplete {
                    Button {
                        withAnimation(.easeOut(duration: 0.5)) {
                            backgroundOpacity = 0.0
                            circleScale = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    } label: {
                        Text("完成")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(projectColor.opacity(0.6))
                                    .shadow(color: projectColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startEntranceAnimation()
            
            // 根据模式决定不同的行为
            if isAutoMode {
                // 自动模式（从机）：设置接收鞠躬动作的回调
                multipeerManager.onBowActionReceived = { isBowing in
                    // 收到鞠躬动作信号时，执行对应动作
                    handleBowActionSignal(isBowing: isBowing)
                }
            } else {
                // 手动模式（主机）：设置陀螺仪检测
                startMotionDetection()
            }
        }
        .onDisappear {
            motionManager.stopMonitoring()
            multipeerManager.onBowActionReceived = nil
        }
        .onChange(of: motionManager.isBowing) { isBowing in
            if !isAutoMode && (isBowing != bowInProgress) {
                // 主机模式：检测到陀螺仪变化时
                bowInProgress = isBowing
                
                // 执行鞠躬动画
                animateBowing(isBowing: isBowing)
                
                // 发送鞠躬动作信号给从机
                multipeerManager.sendBowAction(isBowing: isBowing)
                
                // 如果开始鞠躬，增加计数
                if isBowing {
                    // 记录鞠躬次数，当达到3次时触发完成回调
                    if motionManager.bowCount == 3 && !prayerComplete {
                        // 三次拜拜完成
                        onBowingComplete()
                    }
                }
            }
        }
    }
    
    // 入场动画
    private func startEntranceAnimation() {
        // 延迟动画启动，让过渡更自然
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 1.2)) {
                backgroundOpacity = 1.0
                circleScale = 1.0
            }
        }
    }
    
    // 启动陀螺仪检测
    private func startMotionDetection() {
        // 设置鞠躬完成回调
        motionManager.onBowingComplete = {
            onBowingComplete()
        }
        
        // 开始监测设备运动
        motionManager.startMonitoring()
        
        // 3秒后隐藏说明
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showInstructions = false
            }
        }
    }
    
    // 自动拜拜模式
    private func startAutoBowing() {
        // 等待一段时间后开始自动拜拜
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 执行第一次拜拜
            performAutoBow()
            
            // 1.5秒后执行第二次拜拜
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                performAutoBow()
                
                // 1.5秒后执行第三次拜拜
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    performAutoBow()
                    
                    // 最后一次拜拜后完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onBowingComplete()
                    }
                }
            }
        }
    }
    
    // 执行单次自动拜拜
    private func performAutoBow() {
        // 震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 增加拜拜计数
        bowCount += 1
        
        // 向前倾斜动画
        withAnimation(.easeInOut(duration: 0.3)) {
            bowAngle = 30
            bowInProgress = true
        }
        
        // 添加粒子效果
        generateParticles(count: 5)
        
        // 回弹动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                bowAngle = 0
                bowInProgress = false
            }
        }
    }
    
    // 动画鞠躬效果
    private func animateBowing(isBowing: Bool) {
        if isBowing {
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 向前倾斜动画
            withAnimation(.easeInOut(duration: 0.3)) {
                bowAngle = 30
            }
            
            // 添加粒子效果
            generateParticles(count: 5)
        } else {
            // 回弹动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                bowAngle = 0
            }
        }
    }
    
    // 鞠躬完成
    private func onBowingComplete() {
        // 强烈震动反馈
        generateStrongHapticFeedback()
        
        // 大量粒子效果
        generateParticles(count: 30)
        
        // 标记祈祷完成
        prayerComplete = true
        
        // 显示随机祝福语
        currentBlessing = blessings.randomElement()
        
        // 延迟显示祝福语，让粒子效果先展示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                showingBlessing = true
            }
        }
    }
    
    // 生成粒子效果
    private func generateParticles(count: Int) {
        for _ in 0..<count {
            let particle = Particle(
                position: CGPoint(
                    x: UIScreen.main.bounds.width / 2 + CGFloat.random(in: -50...50),
                    y: UIScreen.main.bounds.height / 2 + CGFloat.random(in: -50...50)
                ),
                scale: CGFloat.random(in: 0.5...1.5),
                rotation: Double.random(in: 0...360),
                opacity: Double.random(in: 0.5...1.0),
                color: [projectColor, .yellow, .orange, .white].randomElement()!,
                speed: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -5...(-2))
                ),
                creationTime: Date()
            )
            particles.append(particle)
        }
        
        // 开始粒子动画
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            updateParticles()
            
            if particles.isEmpty && prayerComplete {
                timer.invalidate()
            }
        }
    }
    
    // 更新粒子位置
    private func updateParticles() {
        withAnimation(.linear(duration: 0.1)) {
            particles = particles.compactMap { particle in
                guard particle.isAlive else { return nil }
                
                var updatedParticle = particle
                updatedParticle.position.x += particle.speed.x
                updatedParticle.position.y += particle.speed.y
                updatedParticle.opacity -= 0.01
                updatedParticle.rotation += 1
                
                return updatedParticle
            }
        }
    }
    
    // 生成强烈的震动反馈
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
            
            // 第三次震动：再次使用通知反馈
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                notificationGenerator.notificationOccurred(.success)
            }
        }
    }
    
    // 处理从主机接收到的鞠躬动作信号
    private func handleBowActionSignal(isBowing: Bool) {
        // 更新UI状态
        bowInProgress = isBowing
        
        // 执行鞠躬动画
        animateBowing(isBowing: isBowing)
        
        // 如果开始鞠躬，增加鞠躬计数
        if isBowing {
            bowCount += 1
            
            // 判断是否完成三次鞠躬
            if bowCount == 3 && !prayerComplete {
                // 三次拜拜完成
                onBowingComplete()
            }
        }
    }
}

#Preview {
    BaiBaiFullscreenView(projectColor: .blue)
} 