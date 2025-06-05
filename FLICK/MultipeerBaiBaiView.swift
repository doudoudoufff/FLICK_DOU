import SwiftUI

/// 多人拜拜界面
struct MultipeerBaiBaiView: View {
    // MARK: - 属性
    
    // 项目主色调
    let projectColor: Color
    
    // 管理近场连接
    @StateObject private var connectionManager = NearbyConnectionManager()
    
    // 拜拜状态
    @State private var showingConnectionSheet = false
    @State private var bowAngle: Double = 0
    @State private var bowCount: Int = 0
    @State private var isShowingBlessingInput = false
    @State private var blessingInput: String = ""
    @State private var currentBlessing: String?
    @State private var showingBlessing = false
    @State private var prayerComplete = false
    @State private var showNFCNotSupportedAlert = false
    
    // 粒子效果
    @State private var particles: [Particle] = []
    
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
    
    // MARK: - 主视图
    
    var body: some View {
        ZStack {
            // 背景色
            Color(.systemBackground).ignoresSafeArea()
            
            // 粒子效果
            ForEach(particles) { particle in
                Image(systemName: ["star.fill", "sparkle", "moon.stars.fill", "sun.max.fill"].randomElement()!)
                    .foregroundColor(particle.color)
                    .scaleEffect(particle.scale)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.opacity)
                    .position(particle.position)
            }
            
            // 主界面内容
            VStack(spacing: 30) {
                // 标题
                Text("多人拜拜")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(projectColor)
                    .padding(.top, 20)
                
                Spacer()
                
                // 拜拜按钮
                if !prayerComplete {
                    Button {
                        performBow()
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
                            VStack(spacing: 5) {
                                Text("拜拜")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                
                                if connectionManager.connectionState == .connected {
                                    Text("一起拜")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                        .rotation3DEffect(
                            .degrees(bowAngle),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 1
                        )
                    }
                    .disabled(connectionManager.connectionState == .notConnected)
                }
                
                // 祝福语显示区域
                if showingBlessing, let blessing = currentBlessing {
                    Text(blessing)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(projectColor)
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 祝福语输入区域
                if isShowingBlessingInput {
                    VStack(spacing: 15) {
                        TextField("输入你的祝福语", text: $blessingInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        Button("发送祝福") {
                            sendBlessing()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(projectColor)
                        .cornerRadius(12)
                        .disabled(blessingInput.isEmpty)
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // 连接状态和控制按钮
                connectionStatusView
                
                // 已连接设备列表
                if !connectionManager.connectedPeers.isEmpty {
                    connectedPeersView
                }
                
                // 收到的祝福列表
                if !connectionManager.receivedBlessings.isEmpty {
                    receivedBlessingsView
                }
                
                Spacer()
                
                // 碰一碰按钮
                Button {
                    // 检查NFC支持
                    if #available(iOS 13.0, *), NFCNDEFReaderSession.readingAvailable {
                        connectionManager.startNFCBump()
                    } else {
                        showNFCNotSupportedAlert = true
                    }
                } label: {
                    Label("碰一碰", systemImage: "iphone.gen2.radiowaves.left.and.right")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 30)
                        .background(
                            Capsule()
                                .fill(projectColor.gradient)
                                .shadow(color: projectColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .disabled(connectionManager.connectionState == .notConnected)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationTitle("多人拜拜")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if connectionManager.connectionState == .notConnected {
                        connectionManager.startDiscovery()
                    } else {
                        connectionManager.stopDiscovery()
                    }
                } label: {
                    Image(systemName: connectionManager.connectionState == .notConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                }
            }
        }
        .onAppear {
            // 设置回调
            setupCallbacks()
        }
        .onDisappear {
            connectionManager.stopDiscovery()
        }
        .alert(isPresented: $showNFCNotSupportedAlert) {
            Alert(
                title: Text("不支持NFC"),
                message: Text("您的设备不支持NFC碰一碰功能，但仍可使用蓝牙/Wi-Fi连接"),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
    
    // MARK: - 子视图
    
    // 连接状态视图
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 10, height: 10)
            
            Text(connectionStatusText)
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if connectionManager.connectionState != .notConnected {
                Button {
                    connectionManager.stopDiscovery()
                } label: {
                    Text("断开")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // 已连接设备列表
    private var connectedPeersView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("已连接设备:")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(connectionManager.connectedPeers, id: \.self) { peer in
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(projectColor)
                            Text(peer.displayName.components(separatedBy: "-").first ?? peer.displayName)
                                .font(.footnote)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // 收到的祝福列表
    private var receivedBlessingsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("收到的祝福:")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(connectionManager.receivedBlessings, id: \.message) { blessing in
                        HStack(alignment: .top) {
                            Text(blessing.sender + ":")
                                .font(.footnote.bold())
                                .foregroundColor(projectColor)
                            
                            Text(blessing.message)
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(.horizontal)
    }
    
    // MARK: - 计算属性
    
    // 连接状态颜色
    private var connectionStatusColor: Color {
        switch connectionManager.connectionState {
        case .notConnected:
            return .gray
        case .searching:
            return .orange
        case .connecting:
            return .yellow
        case .connected:
            return .green
        }
    }
    
    // 连接状态文本
    private var connectionStatusText: String {
        switch connectionManager.connectionState {
        case .notConnected:
            return "未连接"
        case .searching:
            return "正在搜索附近设备..."
        case .connecting:
            return "正在连接..."
        case .connected:
            return "已连接 \(connectionManager.connectedPeers.count) 台设备"
        }
    }
    
    // MARK: - 方法
    
    // 设置回调
    private func setupCallbacks() {
        // 当其他设备拜拜时
        connectionManager.onPeerBowed = { peerName in
            // 播放动画和震动
            animateBowing()
            
            // 显示谁在拜拜
            let displayName = peerName.components(separatedBy: "-").first ?? peerName
            currentBlessing = "\(displayName) 正在拜拜"
            
            withAnimation {
                showingBlessing = true
            }
            
            // 3秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showingBlessing = false
                }
            }
        }
        
        // 当其他设备完成拜拜时
        connectionManager.onPeerCompletedBowing = {
            // 生成粒子效果
            generateParticles(count: 20)
            
            // 强烈震动反馈
            generateStrongHapticFeedback()
        }
        
        // 当收到祝福语时
        connectionManager.onPeerSentBlessing = { sender, text in
            // 已在管理器中处理
        }
    }
    
    // 执行鞠躬动作
    private func performBow() {
        // 添加震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // 向其他设备发送拜拜动作
        connectionManager.sendBowAction()
        
        // 执行鞠躬动画
        animateBowing()
        
        // 计数
        bowCount += 1
        
        // 三次拜拜后完成
        if bowCount >= 3 {
            completeBowing()
        }
    }
    
    // 动画鞠躬效果
    private func animateBowing() {
        // 执行鞠躬动画
        withAnimation(.easeInOut(duration: 0.3)) {
            bowAngle = 30  // 向前倾斜30度
            showingBlessing = false
        }
        
        // 添加粒子效果
        generateParticles(count: 5)
        
        // 回弹动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bowAngle = 0  // 回到原位
            }
        }
    }
    
    // 完成拜拜
    private func completeBowing() {
        // 标记为完成
        prayerComplete = true
        
        // 通知其他设备
        connectionManager.sendBowingCompleted()
        
        // 生成粒子效果
        generateParticles(count: 30)
        
        // 强烈震动反馈
        generateStrongHapticFeedback()
        
        // 延迟显示祝福语输入
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isShowingBlessingInput = true
            }
        }
    }
    
    // 发送祝福语
    private func sendBlessing() {
        guard !blessingInput.isEmpty else { return }
        
        // 发送到其他设备
        connectionManager.sendBlessing(blessingInput)
        
        // 隐藏输入区域
        withAnimation {
            isShowingBlessingInput = false
        }
        
        // 重置
        blessingInput = ""
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
            
            if particles.isEmpty {
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
}

// MARK: - 预览
#Preview {
    NavigationStack {
        MultipeerBaiBaiView(projectColor: .blue)
    }
} 