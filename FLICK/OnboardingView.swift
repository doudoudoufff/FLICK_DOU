import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "欢迎使用 FLICK",
            description: "专业的影视项目管理工具，让您的工作更轻松高效",
            color: .accentColor
        ),
        OnboardingPage(
            title: "项目管理",
            description: "从前期筹备到后期制作，全流程项目管理，让工作效率更高",
            color: .orange
        ),
        OnboardingPage(
            title: "任务追踪",
            description: "智能任务分配和进度追踪，项目进展一目了然",
            color: .blue
        ),
        OnboardingPage(
            title: "账户管理",
            description: "便捷的发票信息和账户管理，告别埋藏在聊天记录里的各类账户",
            color: .green
        )
    ]
    
    var appIcon: some View {
        Image(systemName: "film.stack.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .foregroundStyle(.linearGradient(
                colors: [.accentColor, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            }
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pages.count, id: \.self) { index in
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 60)
                    
                    // App 图标
                    appIcon
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 16) {
                        // 标题
                        Text(pages[index].title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(pages[index].color)
                        
                        // 描述
                        Text(pages[index].description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // 最后一页显示开始按钮
                    if index == pages.count - 1 {
                        Button(action: {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }) {
                            Text("开始使用")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(pages[index].color)
                                .cornerRadius(25)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 50)
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

// 引导页数据模型
struct OnboardingPage {
    let title: String
    let description: String
    let color: Color
}

// 添加 Bundle 扩展来获取应用图标
extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    OnboardingView()
} 