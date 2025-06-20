import SwiftUI
import MultipeerConnectivity

struct VenueShareView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shareManager = VenueShareManager.shared
    
    let venue: VenueEntity
    
    @State private var selectedPeer: MCPeerID?
    @State private var showingConfirmation = false
    @State private var isSharing = false
    @State private var shareResult: (success: Bool, message: String)?
    @State private var showingResult = false
    @State private var refreshTrigger = false // 用于强制刷新视图
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 顶部场地预览卡片
                VenuePreviewCard(venue: venue)
                    .padding(.horizontal)
                
                // 搜索状态或设备列表
                if shareManager.discoveredPeers.isEmpty {
                    if shareManager.isSearching {
                        SearchingView()
                    } else {
                        EmptyDeviceView {
                            startSearching()
                        }
                    }
                } else {
                    // 已发现设备，显示设备列表
                    VStack(spacing: 12) {
                        if shareManager.isSearching {
                            // 显示正在搜索的指示器，但同时也显示已发现的设备
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在搜索更多设备...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        DeviceListView(
                            devices: shareManager.discoveredPeers,
                            selectedDevice: $selectedPeer,
                            onDeviceSelected: { peer in
                                selectedPeer = peer
                                showingConfirmation = true
                            }
                        )
                        // 使用 id 参数确保在 refreshTrigger 改变时强制刷新视图
                        .id(refreshTrigger)
                    }
                }
                
                Spacer()
                
                // 底部按钮
                VStack(spacing: 12) {
                    if !shareManager.isSearching {
                        Button("重新搜索") {
                            startSearching()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("分享场地")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startSearching()
                setupCallbacks()
                
                // 定期刷新UI，确保设备列表更新
                startPeriodicRefresh()
            }
            .onDisappear {
                shareManager.stopSearching()
                
                // 移除通知观察者
                NotificationCenter.default.removeObserver(self)
            }
            .confirmationDialog(
                "确认分享",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("分享给 \(selectedPeer?.displayName ?? "未知设备")") {
                    shareVenue()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("将分享场地「\(venue.wrappedName)」的完整信息，包括所有图片和文档附件。")
            }
            .alert("分享结果", isPresented: $showingResult) {
                Button("确定") {
                    if shareResult?.success == true {
                        dismiss()
                    }
                }
            } message: {
                Text(shareResult?.message ?? "")
            }
            .overlay(
                // 分享进度遮罩
                Group {
                    if isSharing {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("正在分享...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                }
            )
        }
    }
    
    private func startSearching() {
        shareManager.startSearching()
        print("VenueShareView: 开始搜索设备")
    }
    
    private func startPeriodicRefresh() {
        // 每2秒刷新一次UI，确保设备列表更新
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            if !shareManager.discoveredPeers.isEmpty {
                print("VenueShareView: 刷新UI，当前发现 \(shareManager.discoveredPeers.count) 个设备")
                refreshTrigger.toggle()
            }
        }
    }
    
    private func shareVenue() {
        guard let peer = selectedPeer else { return }
        
        isSharing = true
        
        // 设置连接状态变化监听
        shareManager.onConnectionStateChanged = { state in
            switch state {
            case .connected:
                // 连接成功后，如果是我们主动发起的分享，则继续发送数据
                // 注意：我们不再需要在这里调用shareVenue，因为在VenueShareManager中会自动处理
                print("VenueShareView: 连接成功")
                
            case .sharing:
                // 正在分享数据
                print("VenueShareView: 正在发送场地数据")
                
            case .completed:
                // 分享完成
                print("VenueShareView: 分享完成")
                
            case .failed(let error):
                // 连接或分享失败处理
                print("VenueShareView: 操作失败 - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSharing = false
                    self.shareResult = (success: false, message: "操作失败: \(error.localizedDescription)")
                    self.showingResult = true
                }
                
            default:
                break
            }
        }
        
        // 直接调用shareVenue方法，它会处理连接和发送
        print("VenueShareView: 开始向设备 \(peer.displayName) 分享场地")
        shareManager.shareVenue(self.venue, to: peer)
    }
    
    private func setupCallbacks() {
        // 设置分享完成回调
        shareManager.onShareCompleted = { success, message in
            DispatchQueue.main.async {
                isSharing = false
                shareResult = (success: success, message: message ?? "未知错误")
                showingResult = true
            }
        }
        
        // 添加设备发现通知观察
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VenueSharePeerDiscovered"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // 强制刷新视图
            refreshTrigger.toggle()
        }
    }
}

// MARK: - 子视图组件

struct VenuePreviewCard: View {
    let venue: VenueEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.wrappedName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(venue.wrappedType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 附件数量指示
                if !venue.attachmentsArray.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.caption)
                        Text("\(venue.attachmentsArray.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Text(venue.wrappedAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
    }
}

struct SearchingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在搜索附近的设备...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请确保对方也打开了FLICK应用")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

struct EmptyDeviceView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未发现附近设备")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("请确保：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 对方也打开了FLICK应用")
                    Text("• 两台设备距离较近")
                    Text("• 已开启蓝牙和WiFi")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Button("重新搜索") {
                onRefresh()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
}

struct DeviceListView: View {
    let devices: [MCPeerID]
    @Binding var selectedDevice: MCPeerID?
    let onDeviceSelected: (MCPeerID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择要分享给的设备")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(devices, id: \.displayName) { peer in
                    DeviceRow(peer: peer) {
                        onDeviceSelected(peer)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DeviceRow: View {
    let peer: MCPeerID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 设备图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "iphone")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(peer.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("FLICK用户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let venue = VenueEntity(context: context)
    venue.name = "示例摄影棚"
    venue.address = "北京市朝阳区示例地址123号"
    venue.type = "摄影棚"
    venue.contactName = "张先生"
    venue.contactPhone = "13800138000"
    
    return VenueShareView(venue: venue)
} 