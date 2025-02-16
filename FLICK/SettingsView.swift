import SwiftUI

struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    
    var body: some View {
        NavigationStack {
            List {
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