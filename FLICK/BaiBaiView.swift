import SwiftUI

struct BaiBaiView: View {
    let projectColor: Color
    @State private var currentBlessing: String?
    @State private var showingBlessing = false
    @State private var rotation: Double = 0
    
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
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 祈福语显示区域
                if showingBlessing, let blessing = currentBlessing {
                    Text(blessing)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(projectColor)
                        .padding(.horizontal, 40)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 拜拜按钮
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        rotation += 360
                        showingBlessing = false
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        currentBlessing = blessings.randomElement()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                            showingBlessing = true
                        }
                    }
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
                        Text("拜拜")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .rotationEffect(.degrees(rotation))
                }
                
                // 提示文本
                Text("点击按钮获取今日祈福")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("开机拜拜")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BaiBaiView(projectColor: .blue)
    }
} 