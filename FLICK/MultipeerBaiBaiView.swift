import SwiftUI

struct MultipeerBaiBaiView: View {
    let projectColor: Color
    @StateObject private var multipeerManager = MultipeerManager.shared
    @StateObject private var motionManager = MotionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 界面状态
    @State private var showFullscreenBai = false
    @State private var isBowing = false
    @State private var showBaiAnimation = false
    @State private var particles: [BaiParticle] = []
    @State private var particleTimer: Timer? = nil
    @State private var currentBlessing: String? = nil
    @State private var showingBlessing = false
    
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
        "剧组伙食特别好"
    ]
    
    // 粒子效果的定义
    struct BaiParticle: Identifiable {
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
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
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
                // 顶部状态栏
                ConnectionStatusView(
                    deviceRole: multipeerManager.deviceRole,
                    isConnected: multipeerManager.isConnected,
                    connectedCount: multipeerManager.connectedPeers.count
                )
                .padding()
                
                Spacer()
                
                // 中央拜拜区域
                VStack(spacing: 20) {
                    // 拜拜按钮 - 只有主设备可以发起
                    if multipeerManager.deviceRole == .main {
                        Button {
                            // 主设备发起全屏拜拜
                            showFullscreenBai = true
                            // 同时发送信号给其他设备
                            multipeerManager.sendBaiSignal()
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
                                VStack {
                                    Image(systemName: "hands.sparkles.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white)
                                    
                                    Text("拜拜")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .rotation3DEffect(
                                .degrees(isBowing ? 30 : 0),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .center,
                                anchorZ: 0,
                                perspective: 1
                            )
                        }
                    } else {
                        // 非主设备显示等待状态
                        ZStack {
                            // 光晕效果
                            Circle()
                                .fill(projectColor.opacity(0.2))
                                .frame(width: 160, height: 160)
                                .blur(radius: 20)
                            
                            // 主按钮
                            Circle()
                                .fill(projectColor.opacity(0.5).gradient)
                                .frame(width: 120, height: 120)
                                .shadow(color: projectColor.opacity(0.3), radius: 15, x: 0, y: 8)
                            
                            // 文字
                            VStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                                    .symbolEffect(.variableColor.iterative, options: .repeating, value: true)
                                
                                Text("等待主持人")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .rotation3DEffect(
                            .degrees(isBowing ? 30 : 0),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 1
                        )
                    }
                    
                    // 提示文本
                    if multipeerManager.deviceRole == .main {
                        Text("点击按钮发起多人拜拜")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("等待主持人发起拜拜仪式")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 祈福语显示区域
                    if showingBlessing, let blessing = currentBlessing {
                        Text(blessing)
                            .font(.title2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(projectColor)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                // 底部角色说明
                RoleExplanationView(deviceRole: multipeerManager.deviceRole)
                    .padding()
            }
        }
        .navigationTitle("多人拜拜")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("结束") {
                    // 断开连接并返回
                    multipeerManager.disconnect()
                    dismiss()
                }
            }
        }
        .onAppear {
            // 设置回调函数
            multipeerManager.onBaiSignalReceived = {
                // 非主设备接收到信号时，显示全屏拜拜
                if multipeerManager.deviceRole != .main {
                    showFullscreenBai = true
                }
            }
        }
        .onDisappear {
            // 清理
            particleTimer?.invalidate()
            particleTimer = nil
            multipeerManager.onBaiSignalReceived = nil
        }
        .fullScreenCover(isPresented: $showFullscreenBai) {
            BaiBaiFullscreenView(projectColor: projectColor)
        }
    }
    
    // 执行拜拜动画
    private func performBaiAnimation() {
        // 添加震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // 执行鞠躬动画
        withAnimation(.easeInOut(duration: 0.3)) {
            isBowing = true
            showingBlessing = false
        }
        
        // 添加粒子效果
        generateParticles(count: 10)
        
        // 回弹动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isBowing = false
            }
        }
        
        // 显示祈福语
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            currentBlessing = blessings.randomElement()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showingBlessing = true
            }
        }
    }
    
    // 生成粒子效果
    private func generateParticles(count: Int) {
        for _ in 0..<count {
            let particle = BaiParticle(
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
        if particleTimer == nil {
            particleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                updateParticles()
                
                if particles.isEmpty {
                    timer.invalidate()
                    particleTimer = nil
                }
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
}

// 连接状态视图
struct ConnectionStatusView: View {
    let deviceRole: DeviceRole
    let isConnected: Bool
    let connectedCount: Int
    
    var body: some View {
        HStack(spacing: 15) {
            // 角色图标
            Image(systemName: roleIcon)
                .font(.title3)
                .foregroundColor(roleColor)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(roleColor.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                // 角色名称
                Text(roleName)
                    .font(.headline)
                
                // 连接状态
                Text(isConnected ? "已连接 \(connectedCount) 台设备" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态指示灯
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // 角色图标
    var roleIcon: String {
        switch deviceRole {
        case .main:
            return "crown.fill"
        case .secondary:
            return "antenna.radiowaves.left.and.right"
        case .leaf:
            return "leaf.fill"
        }
    }
    
    // 角色名称
    var roleName: String {
        switch deviceRole {
        case .main:
            return "主持人"
        case .secondary:
            return "二级节点"
        case .leaf:
            return "参与者"
        }
    }
    
    // 角色颜色
    var roleColor: Color {
        switch deviceRole {
        case .main:
            return .yellow
        case .secondary:
            return .blue
        case .leaf:
            return .green
        }
    }
}

// 角色说明视图
struct RoleExplanationView: View {
    let deviceRole: DeviceRole
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的角色: \(roleName)")
                .font(.headline)
            
            Text(roleDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // 角色名称
    var roleName: String {
        switch deviceRole {
        case .main:
            return "主持人"
        case .secondary:
            return "二级节点"
        case .leaf:
            return "参与者"
        }
    }
    
    // 角色描述
    var roleDescription: String {
        switch deviceRole {
        case .main:
            return "您是主持人，负责发起拜拜仪式，并广播信号给所有参与者。"
        case .secondary:
            return "您是二级节点，负责接收主持人的信号，并转发给其他参与者。"
        case .leaf:
            return "您是参与者，会接收到主持人或二级节点发送的信号，参与拜拜仪式。"
        }
    }
}

#Preview {
    NavigationStack {
        MultipeerBaiBaiView(projectColor: .blue)
    }
} 