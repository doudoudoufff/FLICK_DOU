import Foundation
import MultipeerConnectivity
import CoreNFC
import Combine

/// 用于管理多人拜拜功能的近场连接
class NearbyConnectionManager: NSObject, ObservableObject {
    // MARK: - 公开属性
    
    /// 连接状态
    enum ConnectionState {
        case notConnected
        case searching
        case connecting
        case connected
    }
    
    /// 当前连接状态
    @Published var connectionState: ConnectionState = .notConnected
    
    /// 已连接的设备
    @Published var connectedPeers: [MCPeerID] = []
    
    /// 收到的祝福消息
    @Published var receivedBlessings: [(sender: String, message: String)] = []
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 拜拜计数同步
    @Published var sharedBowCount: Int = 0
    
    // MARK: - 私有属性
    
    /// 用于设备发现和连接的服务标识
    private let serviceType = "flick-baibai"
    
    /// 本设备ID
    private var myPeerId: MCPeerID
    
    /// P2P会话
    private var session: MCSession
    
    /// 服务广播器
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    
    /// 服务浏览器
    private var serviceBrowser: MCNearbyServiceBrowser?
    
    /// NFC会话
    private var nfcSession: NFCNDEFReaderSession?
    
    /// 连接回调
    var onPeerBowed: ((String) -> Void)?
    var onPeerCompletedBowing: (() -> Void)?
    var onPeerSentBlessing: ((String, String) -> Void)?
    
    // MARK: - 初始化
    
    override init() {
        // 创建设备ID (设备名+随机数，确保唯一性)
        let deviceName = UIDevice.current.name
        let randomSuffix = String(Int.random(in: 1000...9999))
        myPeerId = MCPeerID(displayName: "\(deviceName)-\(randomSuffix)")
        
        // 创建对等会话
        session = MCSession(
            peer: myPeerId,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        
        super.init()
        
        // 设置会话代理
        session.delegate = self
    }
    
    // MARK: - 公开方法
    
    /// 开始搜索附近的设备
    func startDiscovery() {
        // 停止之前的搜索
        stopDiscovery()
        
        // 更新状态
        connectionState = .searching
        
        // 创建并启动服务广播器
        serviceAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerId,
            discoveryInfo: ["app": "FLICK", "feature": "baibai"],
            serviceType: serviceType
        )
        serviceAdvertiser?.delegate = self
        serviceAdvertiser?.startAdvertisingPeer()
        
        // 创建并启动服务浏览器
        serviceBrowser = MCNearbyServiceBrowser(
            peer: myPeerId,
            serviceType: serviceType
        )
        serviceBrowser?.delegate = self
        serviceBrowser?.startBrowsingForPeers()
        
        // 记录日志
        print("开始搜索附近设备...")
    }
    
    /// 停止搜索并断开连接
    func stopDiscovery() {
        // 停止NFC会话
        nfcSession?.invalidate()
        
        // 停止广播和浏览服务
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceBrowser?.stopBrowsingForPeers()
        
        // 断开会话连接
        if !connectedPeers.isEmpty {
            session.disconnect()
        }
        
        // 更新状态
        connectionState = .notConnected
        connectedPeers = []
        
        // 记录日志
        print("已停止搜索并断开连接")
    }
    
    /// 启动NFC碰一碰
    @available(iOS 13.0, *)
    func startNFCBump() {
        // 确认设备支持NFC读取
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "此设备不支持NFC读取"
            print("设备不支持NFC读取")
            return
        }
        
        // 创建NFC会话
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "将手机靠近另一台设备碰一碰"
        nfcSession?.begin()
    }
    
    /// 发送拜拜动作
    func sendBowAction() {
        guard !connectedPeers.isEmpty else { return }
        
        // 创建消息
        let message: [String: Any] = [
            "type": "bow",
            "sender": myPeerId.displayName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 发送到所有连接的设备
        sendToPeers(message: message)
        
        // 记录日志
        print("已发送拜拜动作")
    }
    
    /// 发送拜拜完成事件
    func sendBowingCompleted() {
        guard !connectedPeers.isEmpty else { return }
        
        // 创建消息
        let message: [String: Any] = [
            "type": "bowCompleted",
            "sender": myPeerId.displayName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 发送到所有连接的设备
        sendToPeers(message: message)
        
        // 记录日志
        print("已发送拜拜完成事件")
    }
    
    /// 发送祝福消息
    func sendBlessing(_ blessing: String) {
        guard !connectedPeers.isEmpty else { return }
        
        // 创建消息
        let message: [String: Any] = [
            "type": "blessing",
            "sender": myPeerId.displayName,
            "text": blessing,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 发送到所有连接的设备
        sendToPeers(message: message)
        
        // 将自己的祝福也添加到列表
        DispatchQueue.main.async {
            self.receivedBlessings.append((sender: "我", message: blessing))
        }
        
        // 记录日志
        print("已发送祝福消息: \(blessing)")
    }
    
    // MARK: - 私有辅助方法
    
    /// 发送消息到所有连接的设备
    private func sendToPeers(message: [String: Any]) {
        do {
            // 将消息转换为JSON数据
            let data = try JSONSerialization.data(withJSONObject: message)
            
            // 发送到所有连接的设备
            try session.send(data, toPeers: connectedPeers, with: .reliable)
        } catch {
            // 记录发送错误
            print("发送消息失败: \(error.localizedDescription)")
            errorMessage = "发送消息失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCSessionDelegate
extension NearbyConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                // 添加到已连接设备列表
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                
                // 更新连接状态
                if !self.connectedPeers.isEmpty {
                    self.connectionState = .connected
                }
                
                // 记录日志
                print("设备已连接: \(peerID.displayName)")
                
            case .connecting:
                // 更新连接状态
                self.connectionState = .connecting
                
                // 记录日志
                print("正在连接到设备: \(peerID.displayName)")
                
            case .notConnected:
                // 从已连接列表中移除
                self.connectedPeers.removeAll { $0 == peerID }
                
                // 更新连接状态
                if self.connectedPeers.isEmpty {
                    self.connectionState = .searching
                }
                
                // 记录日志
                print("设备已断开连接: \(peerID.displayName)")
                
            @unknown default:
                print("未知连接状态: \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // 尝试解析收到的JSON数据
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = message["type"] as? String,
              let sender = message["sender"] as? String else {
            print("收到无效消息格式")
            return
        }
        
        // 在主线程处理UI更新
        DispatchQueue.main.async {
            switch type {
            case "bow":
                // 收到拜拜动作
                self.onPeerBowed?(sender)
                print("收到拜拜动作: \(sender)")
                
            case "bowCompleted":
                // 收到拜拜完成事件
                self.onPeerCompletedBowing?()
                print("收到拜拜完成事件: \(sender)")
                
            case "blessing":
                // 收到祝福消息
                if let text = message["text"] as? String {
                    self.onPeerSentBlessing?(sender, text)
                    self.receivedBlessings.append((sender: sender, message: text))
                    print("收到祝福消息: \(sender) - \(text)")
                }
                
            default:
                print("收到未知类型消息: \(type)")
            }
        }
    }
    
    // 以下方法必须实现，但在本应用中不需要使用
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("收到流: \(streamName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("开始接收资源: \(resourceName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("完成接收资源: \(resourceName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension NearbyConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受连接邀请
        invitationHandler(true, session)
        
        // 记录日志
        print("自动接受来自 \(peerID.displayName) 的连接邀请")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        // 更新错误信息
        DispatchQueue.main.async {
            self.errorMessage = "无法启动服务广播: \(error.localizedDescription)"
        }
        
        // 记录日志
        print("无法启动服务广播: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension NearbyConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // 自动发送连接邀请
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        
        // 记录日志
        print("发现并邀请设备: \(peerID.displayName)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // 记录日志
        print("设备已离开: \(peerID.displayName)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        // 更新错误信息
        DispatchQueue.main.async {
            self.errorMessage = "无法启动设备浏览: \(error.localizedDescription)"
        }
        
        // 记录日志
        print("无法启动设备浏览: \(error.localizedDescription)")
    }
}

// MARK: - NFCNDEFReaderSessionDelegate
@available(iOS 13.0, *)
extension NearbyConnectionManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // 检查是否是用户取消
        if let readerError = error as? NFCReaderError, readerError.code == .readerSessionInvalidationErrorUserCanceled {
            // 用户取消，不显示错误
            print("用户取消了NFC会话")
            return
        }
        
        // 更新错误信息
        DispatchQueue.main.async {
            self.errorMessage = "NFC会话错误: \(error.localizedDescription)"
        }
        
        // 记录日志
        print("NFC会话错误: \(error.localizedDescription)")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // NFC检测到标签
        print("NFC检测到标签")
        
        // 当检测到NFC标签时触发一次碰一碰效果
        // 在真实应用中，这里可以验证NFC标签内容，或直接作为一个触发点
        DispatchQueue.main.async {
            // 振动反馈
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
            // 尝试连接最近的设备
            if self.connectionState == .searching {
                self.connectionState = .connecting
            }
        }
    }
} 