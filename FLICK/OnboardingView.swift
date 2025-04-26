import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @EnvironmentObject private var projectStore: ProjectStore
    
    let pages = [
        OnboardingPage(
            title: "欢迎使用 FLICK",
            description: "专业的影视项目管理工具，让您的拍摄与协作更高效。",
            color: .accentColor
        ),
        OnboardingPage(
            title: "项目与场景管理",
            description: "轻松创建、编辑项目，支持多场景、多任务，信息一目了然。",
            color: .orange
        ),
        OnboardingPage(
            title: "堪景与照片管理",
            description: "现场拍照、批量上传，自动生成规范PDF报告，LOGO与时间信息一应俱全，支持一键分享。",
            color: .blue
        ),
        OnboardingPage(
            title: "账户管理",
            description: "便捷的发票信息和账户管理，告别埋藏在聊天记录里的各类账户。",
            color: .green
        ),
        OnboardingPage(
            title: "数据同步",
            description: "选择是否启用 iCloud 同步，让您的项目数据在所有设备间保持一致。",
            color: .blue,
            systemImage: "cloud.fill",
            content: AnyView(CloudSyncView())
        )
    ]
    
    var appIcon: some View {
        Image("FLICKLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
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
                    
                    // 如果有自定义内容，则显示自定义内容，否则显示默认内容
                    if let content = pages[index].content {
                        content
                    } else {
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
                    }
                    
                    Spacer()
                    
                    // 最后一页显示开始按钮
                    if index == pages.count - 1 {
                        Button(action: {
                            // 创建演示数据
                            createDemoData()
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
    
    private func createDemoData() {
        // 直接设置已看过引导页，不创建示例项目
        withAnimation {
            hasSeenOnboarding = true
        }
    }
}

// 引导页数据模型
struct OnboardingPage {
    let title: String
    let description: String
    let color: Color
    let systemImage: String?
    let content: AnyView?
    
    // 添加一个便利初始化方法，兼容旧的初始化方式
    init(title: String, description: String, color: Color, systemImage: String? = nil, content: AnyView? = nil) {
        self.title = title
        self.description = description
        self.color = color
        self.systemImage = systemImage
        self.content = content
    }
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

struct CloudSyncView: View {
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("启用 iCloud 同步")
                .font(.title)
                .bold()
            
            Text("启用 iCloud 同步后，您的项目数据将在所有设备间自动同步。您随时可以在设置中更改此选项。")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Toggle("启用 iCloud 同步", isOn: $enableCloudSync)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isProcessing)
            
            if isProcessing {
                ProgressView("正在配置...")
            }
        }
        .padding()
        .onChange(of: enableCloudSync) { newValue in
            if newValue {
                isProcessing = true
                
                // 配置 iCloud 同步
                PersistenceController.shared.toggleCloudSync(enabled: true) { success, error in
                    isProcessing = false
                    
                    if !success, let error = error {
                        // 如果配置失败，恢复设置
                        enableCloudSync = false
                        print("❌ iCloud 同步配置失败: \(error)")
                    } else {
                        print("✓ iCloud 同步配置成功")
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
} 