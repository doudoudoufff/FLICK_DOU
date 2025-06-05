import Foundation
import MultipeerConnectivity

// 设备角色枚举
enum DeviceRole: String, Codable {
    case main       // 主设备（创建房间的设备）
    case secondary  // 二级节点（负责中继转发）
    case leaf       // 叶子节点（仅接收消息）
}

// 消息类型枚举
enum MessageType: String, Codable {
    case roleAssignment // 角色分配
    case baiSignal      // 拜拜信号
    case statusUpdate   // 状态更新
    case peerList       // 节点列表更新
    case bowAction      // 鞠躬动作
}

// 消息结构
struct BaiMessage: Codable {
    let type: MessageType
    let sender: String      // 发送者ID
    let messageId: String   // 消息唯一ID，用于去重
    let timestamp: Date     // 时间戳，用于同步
    let content: [String: String] // 消息内容
    
    // 添加一个初始化方法便于使用
    init(type: MessageType, sender: String, content: [String: String] = [:]) {
        self.type = type
        self.sender = sender
        self.messageId = UUID().uuidString
        self.timestamp = Date()
        self.content = content
    }
}

class MultipeerManager: NSObject, ObservableObject {
    static let shared = MultipeerManager()
    
    // 服务类型标识符 - 用于发现和浏览服务
    private let serviceType = "flick-baibai"
    
    // 当前设备的ID和角色
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    @Published var deviceRole: DeviceRole = .leaf
    
    // 会话和连接管理
    private var session: MCSession?
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    // 房间信息
    @Published var roomCode: String = ""
    @Published var isHost: Bool = false
    
    // 连接状态
    @Published var isConnected: Bool = false
    @Published var isSearching: Bool = false
    @Published var connectionError: String? = nil
    
    // 连接的设备列表
    @Published var connectedPeers: [MCPeerID] = []
    
    // 节点管理 - 保存父节点和子节点
    private var parentPeer: MCPeerID? = nil
    private var childPeers: [MCPeerID] = []
    
    // 已处理的消息ID集合，用于去重
    private var processedMessages: Set<String> = []
    
    // 回调函数
    var onBaiSignalReceived: (() -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onBowActionReceived: ((Bool) -> Void)?  // 接收到鞠躬动作信号的回调，参数表示是否开始鞠躬
    
    // 私有初始化方法
    private override init() {
        super.init()
    }
    
    // MARK: - 公共方法
    
    // 创建房间（作为主设备）
    func createRoom() {
        // 生成一个简单的PIN码
        roomCode = String(format: "%04d", Int.random(in: 1000...9999))
        isHost = true
        deviceRole = .main
        
        // 初始化会话
        setupSession()
        
        // 开始广播服务
        let discoveryInfo = ["roomCode": roomCode]
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: discoveryInfo, serviceType: serviceType)
        serviceAdvertiser?.delegate = self
        serviceAdvertiser?.startAdvertisingPeer()
        
        // 打印调试信息
        print("创建房间成功，房间码: \(roomCode)")
    }
    
    // 加入房间（作为二级节点或叶子节点）
    func joinRoom(withCode code: String) {
        roomCode = code
        isHost = false
        isSearching = true
        connectionError = nil
        
        // 初始化会话
        setupSession()
        
        // 开始浏览服务
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        serviceBrowser?.delegate = self
        serviceBrowser?.startBrowsingForPeers()
        
        // 打印调试信息
        print("开始寻找房间: \(code)")
    }
    
    // 发送拜拜信号
    func sendBaiSignal() {
        guard session != nil, !connectedPeers.isEmpty else {
            print("没有连接的设备，无法发送拜拜信号")
            return
        }
        
        // 创建拜拜信号消息
        let message = BaiMessage(
            type: .baiSignal,
            sender: myPeerId.displayName,
            content: ["action": "start"]
        )
        
        // 发送消息
        broadcastMessage(message)
        
        // 打印调试信息
        print("发送拜拜信号")
        
        // 如果是主设备，同时自己也执行拜拜动作
        if deviceRole == .main {
            onBaiSignalReceived?()
        }
    }
    
    // 发送鞠躬动作信号
    func sendBowAction(isBowing: Bool) {
        guard session != nil, !connectedPeers.isEmpty else {
            print("没有连接的设备，无法发送鞠躬动作信号")
            return
        }
        
        // 创建鞠躬动作消息
        let message = BaiMessage(
            type: .bowAction,
            sender: myPeerId.displayName,
            content: ["isBowing": isBowing ? "true" : "false"]
        )
        
        // 发送消息
        broadcastMessage(message)
        
        // 打印调试信息
        print("发送鞠躬动作信号: \(isBowing)")
    }
    
    // 断开连接
    func disconnect() {
        serviceBrowser?.stopBrowsingForPeers()
        serviceBrowser = nil
        
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceAdvertiser = nil
        
        session?.disconnect()
        session = nil
        
        connectedPeers = []
        childPeers = []
        parentPeer = nil
        processedMessages.removeAll()
        
        isConnected = false
        isSearching = false
        
        onConnectionStatusChanged?(false)
        
        // 打印调试信息
        print("断开所有连接")
    }
    
    // MARK: - 私有方法
    
    // 初始化会话
    private func setupSession() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
    }
    
    // 广播消息给所有子节点
    private func broadcastMessage(_ message: BaiMessage) {
        do {
            // 将消息编码为Data
            let data = try JSONEncoder().encode(message)
            
            // 记录已处理的消息ID
            processedMessages.insert(message.messageId)
            
            if deviceRole == .main {
                // 主设备：发送给所有直接连接的二级节点
                if !connectedPeers.isEmpty {
                    try session?.send(data, toPeers: connectedPeers, with: .reliable)
                }
            } else if deviceRole == .secondary {
                // 二级节点：转发给所有子节点，但不包括父节点
                let targets = childPeers.filter { $0 != parentPeer }
                if !targets.isEmpty {
                    try session?.send(data, toPeers: targets, with: .reliable)
                }
                
                // 如果消息不是从父节点来的，也发送给父节点
                if let parent = parentPeer, message.sender != parent.displayName {
                    try session?.send(data, toPeers: [parent], with: .reliable)
                }
            }
            
            // 打印调试信息
            print("广播消息: \(message.type.rawValue), ID: \(message.messageId)")
        } catch {
            print("发送消息失败: \(error.localizedDescription)")
        }
    }
    
    // 处理收到的消息
    private func handleReceivedMessage(_ message: BaiMessage, from peer: MCPeerID) {
        // 检查消息是否已经处理过
        guard !processedMessages.contains(message.messageId) else {
            print("忽略重复消息: \(message.messageId)")
            return
        }
        
        // 记录已处理的消息ID
        processedMessages.insert(message.messageId)
        
        // 根据消息类型处理
        switch message.type {
        case .roleAssignment:
            // 处理角色分配消息
            if let roleString = message.content["role"], let role = DeviceRole(rawValue: roleString) {
                DispatchQueue.main.async {
                    self.deviceRole = role
                    print("角色已分配: \(role.rawValue)")
                }
            }
            
        case .baiSignal:
            // 处理拜拜信号
            print("收到拜拜信号")
            
            // 转发给其他节点
            if deviceRole == .secondary {
                broadcastMessage(message)
            }
            
            // 触发拜拜动作
            DispatchQueue.main.async {
                self.onBaiSignalReceived?()
            }
            
        case .statusUpdate:
            // 处理状态更新消息
            print("收到状态更新")
            
        case .peerList:
            // 处理节点列表更新
            print("收到节点列表更新")
            
        case .bowAction:
            // 处理鞠躬动作信号
            if let isBowingStr = message.content["isBowing"], let isBowing = (isBowingStr == "true") ? true : false {
                print("收到鞠躬动作信号: \(isBowing)")
                
                // 转发给其他节点
                if deviceRole == .secondary {
                    broadcastMessage(message)
                }
                
                // 触发鞠躬动作回调
                DispatchQueue.main.async {
                    self.onBowActionReceived?(isBowing)
                }
            }
        }
    }
    
    // 分配角色给新加入的设备
    private func assignRole(to peer: MCPeerID) {
        guard deviceRole == .main else { return }
        
        let role: DeviceRole
        
        // 前7台连接的设备分配为二级节点，之后的为叶子节点
        if connectedPeers.count <= 7 {
            role = .secondary
            print("分配二级节点角色给: \(peer.displayName)")
        } else {
            role = .leaf
            print("分配叶子节点角色给: \(peer.displayName)")
        }
        
        // 创建角色分配消息
        let message = BaiMessage(
            type: .roleAssignment,
            sender: myPeerId.displayName,
            content: ["role": role.rawValue]
        )
        
        // 发送给特定设备
        do {
            let data = try JSONEncoder().encode(message)
            try session?.send(data, toPeers: [peer], with: .reliable)
        } catch {
            print("发送角色分配消息失败: \(error.localizedDescription)")
        }
    }
    
    // 更新拓扑结构
    private func updateTopology() {
        // 对于非主设备，在连接成功后，需要设置父节点
        if !isHost && parentPeer == nil {
            parentPeer = connectedPeers.first
            print("设置父节点: \(parentPeer?.displayName ?? "未知")")
        }
        
        // 更新子节点列表
        let newChildPeers = connectedPeers.filter { $0 != parentPeer }
        childPeers = newChildPeers
        
        if !childPeers.isEmpty {
            print("子节点: \(childPeers.map { $0.displayName }.joined(separator: ", "))")
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("设备已连接: \(peerID.displayName)")
                
                // 更新连接的设备列表
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                
                // 如果是主设备，为新加入的设备分配角色
                if self.deviceRole == .main {
                    self.assignRole(to: peerID)
                }
                
                // 更新拓扑结构
                self.updateTopology()
                
                // 更新连接状态
                self.isConnected = !self.connectedPeers.isEmpty
                self.onConnectionStatusChanged?(self.isConnected)
                
            case .connecting:
                print("设备正在连接: \(peerID.displayName)")
                
            case .notConnected:
                print("设备已断开连接: \(peerID.displayName)")
                
                // 从连接的设备列表中移除
                self.connectedPeers.removeAll { $0 == peerID }
                
                // 如果是父节点断开，需要重新寻找父节点
                if self.parentPeer == peerID {
                    self.parentPeer = nil
                    
                    // 如果还有其他连接的设备，选择一个作为新的父节点
                    if !self.connectedPeers.isEmpty {
                        self.parentPeer = self.connectedPeers.first
                        print("重新设置父节点: \(self.parentPeer?.displayName ?? "未知")")
                    }
                }
                
                // 从子节点列表中移除
                self.childPeers.removeAll { $0 == peerID }
                
                // 更新连接状态
                self.isConnected = !self.connectedPeers.isEmpty
                self.onConnectionStatusChanged?(self.isConnected)
                
            @unknown default:
                print("未知的连接状态: \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            // 解码接收到的消息
            let message = try JSONDecoder().decode(BaiMessage.self, from: data)
            
            // 处理消息
            handleReceivedMessage(message, from: peerID)
        } catch {
            print("消息解码失败: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // 不使用流传输
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // 不使用资源传输
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // 不使用资源传输
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 接受所有邀请
        invitationHandler(true, session)
        print("接受来自 \(peerID.displayName) 的连接请求")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.connectionError = "广播服务失败: \(error.localizedDescription)"
            print("广播服务失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // 检查房间码是否匹配
        guard let peerRoomCode = info?["roomCode"], peerRoomCode == roomCode else {
            print("发现设备 \(peerID.displayName)，但房间码不匹配")
            return
        }
        
        // 发送连接邀请
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 30)
        print("发送连接请求给: \(peerID.displayName)")
        
        // 停止搜索
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("设备离开: \(peerID.displayName)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.connectionError = "搜索设备失败: \(error.localizedDescription)"
            self.isSearching = false
            print("搜索设备失败: \(error.localizedDescription)")
        }
    }
} 