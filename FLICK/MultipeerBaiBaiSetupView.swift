import SwiftUI

struct MultipeerBaiBaiSetupView: View {
    let projectColor: Color
    @StateObject private var multipeerManager = MultipeerManager.shared
    @State private var inputCode: String = ""
    @State private var isJoining: Bool = false
    @State private var showRoomInfo: Bool = false
    @State private var navigateToMainView: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            // 顶部图标和标题
            VStack(spacing: 15) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundColor(projectColor)
                    .symbolEffect(.variableColor.iterative, options: .repeating, value: multipeerManager.isSearching)
                
                Text("多人拜拜")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("连接周围的设备，共同参与拜拜仪式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)
            
            // 显示当前状态或错误
            Group {
                if let error = multipeerManager.connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                } else if multipeerManager.isSearching {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("正在搜索设备...")
                            .font(.footnote)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                } else if multipeerManager.isConnected && !multipeerManager.isHost {
                    Text("已连接到房间，等待仪式开始")
                        .font(.footnote)
                        .foregroundColor(.green)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                        )
                }
            }
            
            // 创建房间区域
            Button {
                multipeerManager.createRoom()
                showRoomInfo = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("创建新房间")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(projectColor.gradient)
                )
                .foregroundColor(.white)
            }
            .disabled(multipeerManager.isConnected || multipeerManager.isSearching)
            
            // 分隔线
            Text("或")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 加入房间区域
            VStack(spacing: 15) {
                TextField("输入4位房间码", text: $inputCode)
                    .keyboardType(.numberPad)
                    .focused($isInputFocused)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: inputCode) { value in
                        // 限制输入长度为4位
                        if value.count > 4 {
                            inputCode = String(value.prefix(4))
                        }
                        
                        // 如果输入满4位，收起键盘
                        if value.count == 4 {
                            isInputFocused = false
                        }
                    }
                
                Button {
                    joinRoom()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("加入房间")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .foregroundColor(inputCode.count == 4 ? projectColor : Color.gray)
                }
                .disabled(inputCode.count != 4 || multipeerManager.isConnected || multipeerManager.isSearching)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 显示房间信息卡片
            if showRoomInfo && multipeerManager.isHost {
                RoomInfoView(roomCode: multipeerManager.roomCode, connectedCount: multipeerManager.connectedPeers.count)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 连接成功后显示的开始仪式按钮
            if multipeerManager.isConnected && multipeerManager.isHost {
                Button {
                    navigateToMainView = true
                } label: {
                    Text("开始仪式")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(projectColor.gradient)
                        )
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding()
        .navigationTitle("多人拜拜")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToMainView) {
            MultipeerBaiBaiView(projectColor: projectColor)
        }
        // 如果当前设备不是主设备，连接成功后自动导航到主视图
        .onChange(of: multipeerManager.isConnected) { isConnected in
            if isConnected && !multipeerManager.isHost {
                // 给一点延迟，确保角色分配已完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigateToMainView = true
                }
            }
        }
        // 页面消失时断开连接
        .onDisappear {
            if !navigateToMainView {
                multipeerManager.disconnect()
            }
        }
    }
    
    // 加入房间方法
    private func joinRoom() {
        guard inputCode.count == 4 else { return }
        
        // 隐藏键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 尝试加入房间
        multipeerManager.joinRoom(withCode: inputCode)
    }
}

// 房间信息卡片视图
struct RoomInfoView: View {
    let roomCode: String
    let connectedCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Text("房间码")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(roomCode)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .tracking(8)
                .padding(.vertical, 5)
            
            Text("已连接: \(connectedCount) 台设备")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            Text("请让其他设备输入此码加入")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        MultipeerBaiBaiSetupView(projectColor: .blue)
    }
} 