import SwiftUI
import CloudKit

struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var showingSyncAlert = false
    @State private var syncError: Error?
    @State private var isSyncing = false
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    @AppStorage("lastSyncTime") private var lastSyncTime: Double = 0
    
    var body: some View {
        NavigationStack {
            List {
                // iCloud 同步状态
                Section {
                    HStack {
                        Label {
                            Text("iCloud 同步")
                        } icon: {
                            Image(systemName: "cloud.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        // 同步状态指示器
                        switch projectStore.syncStatus {
                        case .unknown:
                            Text("等待同步")
                                .foregroundStyle(.secondary)
                        case .syncing:
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("同步中...")
                                    .foregroundStyle(.secondary)
                            }
                        case .synced:
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("已同步")
                                    .foregroundStyle(.secondary)
                            }
                        case .error(let error):
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("同步失败")
                                    .foregroundStyle(.red)
                            }
                            .onTapGesture {
                                syncError = error
                                showingSyncAlert = true
                            }
                        }
                    }
                    
                    // 添加上次同步时间
                    if lastSyncTime > 0 {
                        HStack {
                            Label {
                                Text("上次同步")
                            } icon: {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(Date(timeIntervalSince1970: lastSyncTime), style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 添加数据库信息
                    if let dbSize = PersistenceController.shared.getDatabaseSize() {
                        HStack {
                            Label {
                                Text("数据库大小")
                            } icon: {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(formatFileSize(dbSize))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 手动同步按钮
                    Button(action: {
                        // 显示同步中状态
                        isSyncing = true
                        
                        // 触发同步
                        projectStore.sync()
                        
                        // 延迟后重置状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isSyncing = false
                        }
                    }) {
                        HStack {
                            Label("手动同步", systemImage: "arrow.clockwise")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    .disabled(projectStore.syncStatus == .syncing)
                    
                    // 添加查看 iCloud 状态按钮
                    Button {
                        checkCloudKitStatus()
                    } label: {
                        Label("检查 iCloud 状态", systemImage: "magnifyingglass")
                    }
                    
                    // iCloud 同步开关
                    Toggle(isOn: $enableCloudSync) {
                        Label {
                            Text("启用 iCloud 同步")
                        } icon: {
                            Image(systemName: "cloud.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .onChange(of: enableCloudSync) { newValue in
                        // 显示加载中状态
                        isSyncing = true
                        
                        // 切换 iCloud 同步状态
                        PersistenceController.shared.toggleCloudSync(enabled: newValue) { success, error in
                            // 更新 UI
                            isSyncing = false
                            
                            if let error = error {
                                // 显示通知
                                syncError = error
                                showingSyncAlert = true
                            }
                        }
                    }
                } header: {
                    Text("数据同步")
                } footer: {
                    Text("启用 iCloud 同步后，数据将在所有设备间自动同步")
                }
                
                // 通知设置
                Section {
                    Toggle(isOn: $enableNotifications) {
                        Label {
                            Text("任务提醒")
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("通知设置")
                }
                
                // 法律条款
                Section {
                    NavigationLink {
                        UserAgreementView()
                    } label: {
                        Label {
                            Text("用户协议")
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("隐私政策")
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("法律条款")
                }
                
                // 关于
                Section {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label {
                            Text("特别鸣谢")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    HStack {
                        Label {
                            Text("版本")
                        } icon: {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.purple)
                        }
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
                
                // 其他设置
                Section {
                    Button(role: .destructive) {
                        hasSeenOnboarding = false
                    } label: {
                        Label {
                            Text("重置引导页")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .alert("同步错误", isPresented: $showingSyncAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                if let error = syncError {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // 添加格式化文件大小的函数
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    // 添加检查 CloudKit 状态的方法
    private func checkCloudKitStatus() {
        CKContainer(identifier: "iCloud.FLICKiCLoud").accountStatus { status, error in
            DispatchQueue.main.async {
                var message = ""
                
                switch status {
                case .available:
                    message = "iCloud 账户可用，同步功能正常"
                case .noAccount:
                    message = "未登录 iCloud 账户，请在设置中登录"
                case .restricted:
                    message = "iCloud 账户受限，无法使用同步功能"
                case .couldNotDetermine:
                    message = "无法确定 iCloud 账户状态，请检查网络连接"
                @unknown default:
                    message = "未知状态"
                }
                
                if let error = error {
                    message += "\n错误: \(error.localizedDescription)"
                }
                
                // 显示状态
                syncError = NSError(domain: "CloudKit", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
                showingSyncAlert = true
            }
        }
    }
}

// 用户协议视图
struct UserAgreementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title)
                    .bold()
                
                Group {
                    Text("1. Acceptance of Terms")
                        .font(.headline)
                    Text("By accessing or using FLICK (the \"App\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree to these Terms, do not use the App.")
                    
                    Text("2. Description of Service")
                        .font(.headline)
                    Text("FLICK is a project management application designed for film and television industry professionals. The App provides tools for managing projects, tasks, and financial records.")
                    
                    Text("3. User Account")
                        .font(.headline)
                    Text("You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.")
                    
                    Text("4. User Content")
                        .font(.headline)
                    Text("You retain all rights to any content you submit, post or display on or through the App. By submitting content, you grant FLICK a worldwide, non-exclusive, royalty-free license to use, copy, and display such content.")
                    
                    Text("5. Intellectual Property Rights")
                        .font(.headline)
                    Text("The App and its original content, features, and functionality are owned by FLICK and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.")
                    
                    Text("6. Termination")
                        .font(.headline)
                    Text("We may terminate or suspend your access to the App immediately, without prior notice, for any reason whatsoever.")
                    
                    Text("7. Changes to Terms")
                        .font(.headline)
                    Text("We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days' notice prior to any new terms taking effect.")
                    
                    Text("8. Contact Us")
                        .font(.headline)
                    Text("If you have any questions about these Terms, please contact us at support@flickapp.com")
                }
                .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .bold()
                
                Group {
                    Text("1. Information We Collect")
                        .font(.headline)
                    Text("We collect information that you provide directly to us when using the App, including:\n• Project details and management information\n• Task and schedule information\n• Financial records and invoices\n• Device information and usage data")
                    
                    Text("2. How We Use Your Information")
                        .font(.headline)
                    Text("We use the information we collect to:\n• Provide, maintain, and improve our services\n• Develop new features and functionality\n• Understand how users interact with our App\n• Send you technical notices and support messages\n• Detect and prevent fraud and abuse")
                    
                    Text("3. Data Storage and Security")
                        .font(.headline)
                    Text("All data is stored locally on your device. We implement appropriate technical and organizational measures to protect your information against unauthorized access, alteration, disclosure, or destruction.")
                    
                    Text("4. Your Rights")
                        .font(.headline)
                    Text("You have the right to:\n• Access your personal information\n• Correct inaccurate data\n• Request deletion of your data\n• Export your data\n• Opt-out of data collection")
                    
                    Text("5. Children's Privacy")
                        .font(.headline)
                    Text("The App is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.")
                    
                    Text("6. Changes to This Policy")
                        .font(.headline)
                    Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last Updated\" date.")
                    
                    Text("7. Contact Us")
                        .font(.headline)
                    Text("If you have any questions about this Privacy Policy, please contact us at privacy@flickapp.com")
                    
                    Text("Last Updated: March 15, 2024")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 特别鸣谢视图
struct CreditsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(.orange)
                    Text("感谢以下人员对项目的贡献")
                }
                .font(.headline)
            }
            
            Section("核心团队") {
                ContributorRow(name: "孙尚前", role: "产品", country: "🇨🇳")
            }
            
            Section("测试团队") {
                ContributorRow(name: "王小跳", role: "测试", country: "🇨🇳")
                ContributorRow(name: "杨欣蕾", role: "测试", country: "🇨🇳")
                ContributorRow(name: "吴韩臻", role: "测试", country: "🇨🇳")
                ContributorRow(name: "朱科恩", role: "测试", country: "🇨🇳")
            }
        }
        .navigationTitle("致谢")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 贡献者行视图
struct ContributorRow: View {
    let name: String
    let role: String
    let country: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                HStack {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(country)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
} 