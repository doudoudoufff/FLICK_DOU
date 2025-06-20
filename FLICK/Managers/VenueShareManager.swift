import Foundation
import MultipeerConnectivity
import UIKit

// MARK: - 场地分享数据结构

struct VenueSharePackage: Codable {
    let id: String
    let venue: VenueShareData
    let attachments: [AttachmentShareData]
    let sender: SenderInfo
    let timestamp: Date
    
    init(venue: VenueShareData, attachments: [AttachmentShareData], sender: SenderInfo) {
        self.id = UUID().uuidString
        self.venue = venue
        self.attachments = attachments
        self.sender = sender
        self.timestamp = Date()
    }
}

struct VenueShareData: Codable {
    let name: String
    let address: String
    let contactName: String
    let contactPhone: String
    let type: String
    let notes: String
    let dateAdded: Date
}

struct AttachmentShareData: Codable {
    let id: String
    let fileName: String
    let fileType: String
    let data: Data
    let dateAdded: Date
}

struct SenderInfo: Codable {
    let deviceName: String
    let appVersion: String
    let timestamp: Date
    
    init() {
        self.deviceName = UIDevice.current.name
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.timestamp = Date()
    }
}

// MARK: - 消息类型

enum VenueShareMessageType: String, Codable {
    case shareRequest    // 分享请求
    case shareData      // 分享数据
    case shareResponse  // 分享响应
    case shareCancel    // 取消分享
}

struct VenueShareMessage: Codable {
    let type: VenueShareMessageType
    let messageId: String
    let sender: String
    let timestamp: Date
    let data: Data?
    
    init(type: VenueShareMessageType, sender: String, data: Data? = nil) {
        self.type = type
        self.messageId = UUID().uuidString
        self.sender = sender
        self.timestamp = Date()
        self.data = data
    }
}

// MARK: - 连接状态

enum VenueShareConnectionState: Equatable {
    case idle           // 空闲状态
    case searching      // 搜索设备中
    case connecting     // 连接中
    case connected      // 已连接
    case sharing        // 分享中
    case receiving      // 接收中
    case completed      // 完成
    case failed(Error)  // 失败
    
    // 实现 Equatable 协议所需的 == 操作符
    static func == (lhs: VenueShareConnectionState, rhs: VenueShareConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.searching, .searching),
             (.connecting, .connecting),
             (.connected, .connected),
             (.sharing, .sharing),
             (.receiving, .receiving),
             (.completed, .completed):
            return true
        case (.failed, .failed):
            // 对于包含关联值的 case，我们只比较 case 本身，不比较关联值
            return true
        default:
            return false
        }
    }
}

// MARK: - 场地分享管理器

class VenueShareManager: NSObject, ObservableObject {
    static let shared = VenueShareManager()
    
    // 服务类型标识符 - 必须是1-15个字符，只能包含ASCII字母、数字和连字符，必须以字母开头
    private let serviceType = "flickvenue"
    
    // MultipeerConnectivity 组件
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    // 状态管理
    @Published var connectionState: VenueShareConnectionState = .idle
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isSearching: Bool = false
    @Published var lastError: String?
    
    // 当前分享/接收的数据
    private var currentSharePackage: VenueSharePackage?
    private var pendingInvitations: [MCPeerID: (Bool) -> Void] = [:]
    
    // 回调函数
    var onVenueShareReceived: ((VenueSharePackage, MCPeerID, @escaping (Bool) -> Void) -> Void)?
    var onShareCompleted: ((Bool, String?) -> Void)?
    var onConnectionStateChanged: ((VenueShareConnectionState) -> Void)?
    
    private override init() {
        super.init()
        setupSession()
        
        // 添加应用生命周期通知观察
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        // 移除所有通知观察
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppDidBecomeActive() {
        // 应用变为活跃状态时，自动开始搜索附近设备
        if !isSearching {
            startSearching()
        }
    }
    
    // MARK: - 会话设置
    
    private func setupSession() {
        // 使用.optional加密选项以提高兼容性，同时保持一定的安全性
        // .none在某些iOS版本上可能会导致连接问题
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
        session?.delegate = self
        print("VenueShareManager: 初始化会话，设备ID: \(myPeerID.displayName)")
    }
    
    // MARK: - 公共方法
    
    /// 开始搜索附近的设备
    func startSearching() {
        guard !isSearching else { return }
        
        print("VenueShareManager: 开始搜索附近设备")
        
        // 重置状态
        discoveredPeers.removeAll()
        lastError = nil
        updateConnectionState(.searching)
        
        // 设置为正在搜索状态
        isSearching = true
        
        // 检查权限并确保蓝牙已启用
        checkPermissionsAndStart()
    }
    
    private func checkPermissionsAndStart() {
        // 在真机上，需要确保有必要的权限
        // 由于MultipeerConnectivity会自动请求权限，这里只需要开始服务
        
        // 开始广播和浏览
        startAdvertising()
        startBrowsing()
        
        // 打印调试信息
        print("VenueShareManager: 已启动广播和浏览服务")
        
        // 30秒后如果没有发现设备，尝试重启服务
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isSearching else { return }
            
            if self.discoveredPeers.isEmpty {
                print("VenueShareManager: 30秒内未发现设备，尝试重启服务")
                self.restartAdvertising()
                self.restartBrowsing()
            }
        }
    }
    
    /// 停止搜索
    func stopSearching() {
        guard isSearching else { return }
        
        print("VenueShareManager: 停止搜索")
        
        stopAdvertising()
        stopBrowsing()
        
        isSearching = false
        updateConnectionState(.idle)
    }
    
    /// 分享场地给指定设备（两步流程：先连接，再发送数据）
    func shareVenue(_ venue: VenueEntity, to peer: MCPeerID) {
        guard let session = session else {
            handleError("会话未初始化")
            return
        }
        
        // 存储当前要分享的场地信息，以便在连接成功后发送
        do {
            // 创建分享包
            let sharePackage = try prepareVenueSharePackage(from: venue)
            currentSharePackage = sharePackage
            print("VenueShareManager: 已准备场地 '\(venue.wrappedName)' 的分享包")
        } catch {
            handleError("准备分享数据失败: \(error.localizedDescription)")
            return
        }
        
        // 检查是否已连接到目标设备
        if connectedPeers.contains(peer) {
            // 已连接，直接发送数据
            sendVenueData(to: peer)
        } else {
            // 未连接，先建立连接
            print("VenueShareManager: 未连接到设备 \(peer.displayName)，先建立连接")
            connectToPeer(peer)
            // 连接成功后会通过 onConnectionStateChanged 回调触发发送数据
        }
    }
    
    /// 发送场地数据（在连接成功后调用）
    private func sendVenueData(to peer: MCPeerID) {
        guard let session = session, let sharePackage = currentSharePackage else {
            handleError("无法发送数据：会话未初始化或没有准备好的分享包")
            return
        }
        
        print("VenueShareManager: 开始发送场地数据给 \(peer.displayName)")
        updateConnectionState(.sharing)
        
        do {
            // 创建初始消息（仅包含基本信息，不包含附件）
            let initialMessage = VenueShareMessage(
                type: .shareRequest,
                sender: myPeerID.displayName,
                data: try JSONEncoder().encode(sharePackage)
            )
            
            // 编码消息
            let messageData = try JSONEncoder().encode(initialMessage)
            
            // 发送消息
            print("VenueShareManager: 正在发送数据，大小: \(ByteCountFormatter.string(fromByteCount: Int64(messageData.count), countStyle: .file))")
            try session.send(messageData, toPeers: [peer], with: .reliable)
            
            print("VenueShareManager: 分享请求已发送")
            
        } catch let error as NSError {
            if error.domain == "MCSession" {
                handleError("发送数据失败: 连接问题 - \(error.localizedDescription)")
            } else {
                handleError("发送数据失败: \(error.localizedDescription)")
            }
        } catch {
            handleError("发送数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 连接到指定设备
    func connectToPeer(_ peer: MCPeerID) {
        guard let session = session else {
            handleError("会话未初始化")
            return
        }
        
        // 如果已经连接，直接报告成功
        if connectedPeers.contains(peer) {
            print("VenueShareManager: 已经连接到设备: \(peer.displayName)")
            updateConnectionState(.connected)
            return
        }
        
        print("VenueShareManager: 连接到设备: \(peer.displayName)")
        updateConnectionState(.connecting)
        
        // 设置连接超时
        let timeoutSeconds = 15.0
        
        // 邀请对方连接
        serviceBrowser?.invitePeer(peer, to: session, withContext: nil, timeout: timeoutSeconds)
        
        // 设置连接超时处理
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // 检查是否已连接
            if !self.connectedPeers.contains(peer) && self.connectionState == .connecting {
                print("VenueShareManager: 连接超时: \(peer.displayName)")
                let error = NSError(
                    domain: "VenueShare",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "连接超时，请确保两台设备都已打开FLICK应用"]
                )
                self.updateConnectionState(.failed(error))
            }
        }
    }
    
    /// 断开所有连接
    func disconnect() {
        print("VenueShareManager: 断开所有连接")
        
        session?.disconnect()
        stopSearching()
        
        // 重置状态
        discoveredPeers.removeAll()
        connectedPeers.removeAll()
        currentSharePackage = nil
        pendingInvitations.removeAll()
        
        updateConnectionState(.idle)
    }
    
    // MARK: - 私有方法
    
    private func startAdvertising() {
        // 确保在应用启动时就开始广播，增加被发现的机会
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["version": "1.0", "app": "FLICK"],
            serviceType: serviceType
        )
        serviceAdvertiser?.delegate = self
        
        // 添加延迟和错误处理，确保广播正确启动
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 在某些设备上，如果太快启动广播可能会失败
                try? self.serviceAdvertiser?.startAdvertisingPeer()
                print("VenueShareManager: 开始广播服务")
                
                // 30秒后重新启动广播，以防初始广播失败
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                    guard let self = self, self.isSearching else { return }
                    self.restartAdvertising()
                }
            }
        }
        
        // 添加通知中心观察，以便在应用进入前台时重新开始广播
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartAdvertising),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // 添加额外的通知观察，以便在蓝牙状态变化时重新开始广播
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartAdvertising),
            name: NSNotification.Name(rawValue: "CBCentralManagerDidUpdateStateNotification"),
            object: nil
        )
    }
    
    @objc private func restartAdvertising() {
        // 应用回到前台或其他需要重启广播的情况
        if isSearching {
            stopAdvertising()
            
            // 短暂延迟后重新开始广播，给系统一些时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isSearching else { return }
                self.startAdvertising()
                print("VenueShareManager: 重新开始广播")
            }
        }
    }
    
    private func stopAdvertising() {
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceAdvertiser = nil
        print("VenueShareManager: 停止广播服务")
    }
    
    private func startBrowsing() {
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser?.delegate = self
        
        // 添加延迟和错误处理，确保浏览正确启动
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 在某些设备上，如果太快启动浏览可能会失败
            self.serviceBrowser?.startBrowsingForPeers()
            print("VenueShareManager: 开始浏览服务")
            
            // 30秒后重新启动浏览，以防初始浏览失败
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                guard let self = self, self.isSearching else { return }
                self.restartBrowsing()
            }
            
            // 每60秒周期性重启浏览，增加发现设备的机会
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.setupPeriodicBrowsingRestart()
            }
        }
        
        // 添加通知中心观察，以便在应用进入前台时重新开始浏览
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartBrowsing),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // 添加额外的通知观察，以便在蓝牙状态变化时重新开始浏览
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartBrowsing),
            name: NSNotification.Name(rawValue: "CBCentralManagerDidUpdateStateNotification"),
            object: nil
        )
    }
    
    private func setupPeriodicBrowsingRestart() {
        // 如果不再搜索，则不设置定时器
        guard isSearching else { return }
        
        // 每60秒重启一次浏览服务，增加发现设备的机会
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self = self, self.isSearching else { return }
            
            print("VenueShareManager: 周期性重启浏览服务")
            self.restartBrowsing()
            
            // 递归设置下一次重启
            self.setupPeriodicBrowsingRestart()
        }
    }
    
    @objc private func restartBrowsing() {
        // 应用回到前台或其他需要重启浏览的情况
        if isSearching {
            stopBrowsing()
            
            // 短暂延迟后重新开始浏览，给系统一些时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isSearching else { return }
                self.startBrowsing()
                print("VenueShareManager: 重新开始浏览")
                
                // 清除并重新发现设备列表
                self.discoveredPeers.removeAll()
            }
        }
    }
    
    private func stopBrowsing() {
        serviceBrowser?.stopBrowsingForPeers()
        serviceBrowser = nil
        print("VenueShareManager: 停止浏览服务")
    }
    
    private func prepareVenueSharePackage(from venue: VenueEntity) throws -> VenueSharePackage {
        // 准备场地数据
        let venueData = VenueShareData(
            name: venue.wrappedName,
            address: venue.wrappedAddress,
            contactName: venue.wrappedContactName,
            contactPhone: venue.wrappedContactPhone,
            type: venue.wrappedType,
            notes: venue.wrappedNotes,
            dateAdded: venue.wrappedDateAdded
        )
        
        // 准备附件数据
        var attachments: [AttachmentShareData] = []
        for attachment in venue.attachmentsArray {
            if let data = attachment.data {
                let attachmentData = AttachmentShareData(
                    id: attachment.id?.uuidString ?? UUID().uuidString,
                    fileName: attachment.wrappedFileName,
                    fileType: attachment.wrappedFileType,
                    data: data,
                    dateAdded: attachment.wrappedDateAdded
                )
                attachments.append(attachmentData)
            }
        }
        
        // 创建分享包
        let sharePackage = VenueSharePackage(
            venue: venueData,
            attachments: attachments,
            sender: SenderInfo()
        )
        
        print("VenueShareManager: 准备分享包完成，包含 \(attachments.count) 个附件")
        return sharePackage
    }
    
    private func handleReceivedMessage(_ message: VenueShareMessage, from peer: MCPeerID) {
        DispatchQueue.main.async {
            switch message.type {
            case .shareRequest:
                self.handleShareRequest(message, from: peer)
            case .shareResponse:
                self.handleShareResponse(message, from: peer)
            case .shareCancel:
                self.handleShareCancel(message, from: peer)
            case .shareData:
                break // 这种类型的消息在 shareRequest 中已处理
            }
        }
    }
    
    private func handleShareRequest(_ message: VenueShareMessage, from peer: MCPeerID) {
        guard let data = message.data else {
            print("VenueShareManager: 收到无效的分享请求")
            return
        }
        
        do {
            let sharePackage = try JSONDecoder().decode(VenueSharePackage.self, from: data)
            print("VenueShareManager: 收到来自 \(peer.displayName) 的场地分享请求: \(sharePackage.venue.name)")
            
            // 更新状态为接收中
            updateConnectionState(.receiving)
            
            // 打印接收到的场地信息，便于调试
            print("VenueShareManager: 接收到场地 '\(sharePackage.venue.name)' 信息:")
            print("  - 地址: \(sharePackage.venue.address)")
            print("  - 类型: \(sharePackage.venue.type)")
            print("  - 联系人: \(sharePackage.venue.contactName)")
            print("  - 附件数量: \(sharePackage.attachments.count)")
            
            // 调用回调让UI处理用户确认
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.onVenueShareReceived?(sharePackage, peer) { accepted in
                    self.sendShareResponse(to: peer, accepted: accepted, package: sharePackage)
                }
            }
            
        } catch {
            print("VenueShareManager: 解析分享请求失败: \(error)")
            
            // 报告错误
            let errorMessage = "解析分享数据失败: \(error.localizedDescription)"
            handleError(errorMessage)
        }
    }
    
    private func handleShareResponse(_ message: VenueShareMessage, from peer: MCPeerID) {
        // 处理对方的分享响应
        print("VenueShareManager: 收到来自 \(peer.displayName) 的分享响应")
        
        if let data = message.data,
           let responseString = String(data: data, encoding: .utf8) {
            let accepted = responseString == "accepted"
            
            if accepted {
                updateConnectionState(.completed)
                onShareCompleted?(true, "场地分享成功")
            } else {
                updateConnectionState(.failed(NSError(domain: "VenueShare", code: 1, userInfo: [NSLocalizedDescriptionKey: "对方拒绝了分享请求"])))
                onShareCompleted?(false, "对方拒绝了分享请求")
            }
        }
    }
    
    private func handleShareCancel(_ message: VenueShareMessage, from peer: MCPeerID) {
        print("VenueShareManager: 对方取消了分享")
        updateConnectionState(.failed(NSError(domain: "VenueShare", code: 2, userInfo: [NSLocalizedDescriptionKey: "对方取消了分享"])))
        onShareCompleted?(false, "对方取消了分享")
    }
    
    private func sendShareResponse(to peer: MCPeerID, accepted: Bool, package: VenueSharePackage) {
        guard let session = session else { return }
        
        do {
            let responseData = (accepted ? "accepted" : "rejected").data(using: .utf8)
            let message = VenueShareMessage(
                type: .shareResponse,
                sender: myPeerID.displayName,
                data: responseData
            )
            
            let messageData = try JSONEncoder().encode(message)
            try session.send(messageData, toPeers: [peer], with: .reliable)
            
            if accepted {
                // 如果接受，触发场地导入
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportSharedVenue"),
                    object: nil,
                    userInfo: ["package": package, "sender": peer.displayName]
                )
                
                updateConnectionState(.completed)
                onShareCompleted?(true, "场地接收成功")
            }
            
            print("VenueShareManager: 分享响应已发送: \(accepted ? "接受" : "拒绝")")
            
        } catch {
            print("VenueShareManager: 发送分享响应失败: \(error)")
        }
    }
    
    private func updateConnectionState(_ newState: VenueShareConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = newState
            self.onConnectionStateChanged?(newState)
        }
    }
    
    private func handleError(_ message: String) {
        print("VenueShareManager Error: \(message)")
        DispatchQueue.main.async {
            self.lastError = message
            self.updateConnectionState(.failed(NSError(domain: "VenueShare", code: 0, userInfo: [NSLocalizedDescriptionKey: message])))
            self.onShareCompleted?(false, message)
        }
    }
}

// MARK: - MCSessionDelegate

extension VenueShareManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("VenueShareManager: 已连接到 \(peerID.displayName)")
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                
                // 更新连接状态为已连接
                self.updateConnectionState(.connected)
                
                // 打印当前连接的所有设备
                print("VenueShareManager: 当前连接的设备: \(self.connectedPeers.map { $0.displayName }.joined(separator: ", "))")
                
                // 如果有准备好的分享包，自动发送数据
                if self.currentSharePackage != nil {
                    print("VenueShareManager: 检测到准备好的分享包，自动发送数据")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendVenueData(to: peerID)
                    }
                }
                
            case .connecting:
                print("VenueShareManager: 正在连接到 \(peerID.displayName)")
                self.updateConnectionState(.connecting)
                
            case .notConnected:
                print("VenueShareManager: 与 \(peerID.displayName) 断开连接")
                self.connectedPeers.removeAll { $0 == peerID }
                
                // 如果是在分享过程中断开连接，则报告错误
                if self.connectionState == .sharing || self.connectionState == .connecting {
                    let error = NSError(
                        domain: "VenueShare",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "与设备 \(peerID.displayName) 的连接已断开"]
                    )
                    self.updateConnectionState(.failed(error))
                } else if self.connectedPeers.isEmpty {
                    self.updateConnectionState(.idle)
                }
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(VenueShareMessage.self, from: data)
            print("VenueShareManager: 收到消息类型 \(message.type) 来自 \(peerID.displayName)")
            handleReceivedMessage(message, from: peerID)
        } catch {
            print("VenueShareManager: 解析消息失败: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // 暂不支持流传输
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // 暂不支持资源传输
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // 暂不支持资源传输
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension VenueShareManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("VenueShareManager: 收到来自 \(peerID.displayName) 的连接邀请")
        
        DispatchQueue.main.async {
            // 更新连接状态
            self.updateConnectionState(.connecting)
            
            // 自动接受邀请，增强连接的可能性
            print("VenueShareManager: 自动接受来自 \(peerID.displayName) 的连接邀请")
            invitationHandler(true, self.session)
            
            // 确保对方也被添加到发现的设备列表中
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
            
            // 发送通知，更新UI
            NotificationCenter.default.post(
                name: NSNotification.Name("VenueSharePeerDiscovered"),
                object: nil,
                userInfo: ["peerID": peerID, "displayName": peerID.displayName]
            )
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension VenueShareManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("VenueShareManager: 发现设备 \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                
                // 发出设备发现通知，可以用于调试和UI更新
                NotificationCenter.default.post(
                    name: NSNotification.Name("VenueSharePeerDiscovered"),
                    object: nil,
                    userInfo: ["peerID": peerID, "displayName": peerID.displayName]
                )
                
                // 打印当前发现的所有设备
                print("VenueShareManager: 当前发现的设备列表:")
                for (index, peer) in self.discoveredPeers.enumerated() {
                    print("  \(index+1). \(peer.displayName)")
                }
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("VenueShareManager: 丢失设备 \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
} 