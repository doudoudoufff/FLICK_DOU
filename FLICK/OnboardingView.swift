import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    @Environment(\.dismiss) private var dismiss
    @State private var isSyncing = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo
        Image("FLICKLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
                .padding(.top, 40)
                    
            // 引导内容
            VStack(spacing: 20) {
                Text("欢迎使用 FLICK")
                                .font(.title)
                                .fontWeight(.bold)
                
                Text("您的专业影视项目管理助手")
                    .font(.headline)
                                .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "film", title: "项目全流程管理", description: "从前期到后期，一站式管理您的影视项目")
                    FeatureRow(icon: "location.fill", title: "智能堪景系统", description: "轻松记录和管理拍摄场地信息")
                    FeatureRow(icon: "dollarsign.circle.fill", title: "发票管理", description: "高效管理项目支出和发票")
                    FeatureRow(icon: "cloud.fill", title: "iCloud 同步", description: "数据自动在设备间同步，确保安全")
                }
                .padding(.horizontal)
                        }
            
            // iCloud 同步选项
            VStack(spacing: 12) {
                Toggle(isOn: $enableCloudSync) {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundStyle(.blue)
                        Text("启用 iCloud 同步")
                            .font(.headline)
                    }
                }
                .padding(.horizontal)
                .onChange(of: enableCloudSync) { newValue in
                    isSyncing = true
                    PersistenceController.shared.toggleCloudSync(enabled: newValue) { success, error in
                        isSyncing = false
                    }
                }
                
                if isSyncing {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            
            // 开始使用按钮
                        Button(action: {
                hasSeenOnboarding = true
                dismiss()
                        }) {
                            Text("开始使用")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                        }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
                }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    let previewContext = PersistenceController.preview.container.viewContext
    let previewStore = ProjectStore(context: previewContext)
    
    return OnboardingView()
        .environmentObject(previewStore)
} 