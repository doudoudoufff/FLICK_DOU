import SwiftUI
import CloudKit

struct SettingsDetailView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var showingSyncAlert = false
    @State private var syncError: Error?
    @State private var isSyncing = false
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    @AppStorage("lastSyncTime") private var lastSyncTime: Double = 0
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    var body: some View {
        NavigationStack {
            List {
                // 数据同步部分
                Section {
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
                    
                    // 同步状态信息
                    if enableCloudSync {
                        DisclosureGroup {
                            // 同步状态
                            HStack {
                                Label {
                                    Text("同步状态")
                                } icon: {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
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
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text("同步错误")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            // 上次同步时间
                            if lastSyncTime > 0 {
                                HStack {
                                    Label {
                                        Text("上次同步")
                                    } icon: {
                                        Image(systemName: "clock.fill")
                                            .foregroundStyle(.blue)
                                    }
                                    Spacer()
                                    Text(Date(timeIntervalSince1970: lastSyncTime).formatted())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // 数据库大小
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
                        } label: {
                            Label {
                                Text("同步详情")
                            } icon: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    Text("数据同步")
                } footer: {
                    Text("启用 iCloud 同步后，数据将在所有设备间自动同步")
                }
                
                // 外观设置
                Section {
                    Picker("主题", selection: $appTheme) {
                        Label {
                            Text("跟随系统")
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(.blue)
                        }
                        .tag("system")
                        
                        Label {
                            Text("浅色模式")
                        } icon: {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.yellow)
                        }
                        .tag("light")
                        
                        Label {
                            Text("深色模式")
                        } icon: {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(.indigo)
                        }
                        .tag("dark")
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("外观")
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
                    
                    NavigationLink {
                        AboutAppView()
                    } label: {
                        Label {
                            Text("关于应用")
                        } icon: {
                            Image(systemName: "app.badge.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                } header: {
                    Text("关于")
                }
                
                Section {
                    SettingsFooterView()
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                }
            }
            .navigationTitle("设置")
            .alert("iCloud 状态", isPresented: $showingSyncAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                if let error = syncError {
                    let isError = (error as NSError).userInfo["isError"] as? Bool ?? false
                    Text(error.localizedDescription)
                        .foregroundColor(isError ? .red : .primary)
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    // 主题设置
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // 跟随系统
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
                var isError = false
                
                switch status {
                case .available:
                    message = "iCloud 账户可用，同步功能正常"
                case .noAccount:
                    message = "未登录 iCloud 账户，请在设置中登录"
                    isError = true
                case .restricted:
                    message = "iCloud 账户受限，无法使用同步功能"
                    isError = true
                case .couldNotDetermine:
                    message = "无法确定 iCloud 账户状态，请检查网络连接"
                    isError = true
                @unknown default:
                    message = "未知状态"
                    isError = true
                }
                
                if let error = error {
                    message += "\n错误: \(error.localizedDescription)"
                    isError = true
                }
                
                // 显示状态消息
                syncError = NSError(
                    domain: "CloudKit",
                    code: isError ? 1 : 0,
                    userInfo: [
                        NSLocalizedDescriptionKey: message,
                        "isError": isError
                    ]
                )
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
                // 标题
                Text("User License Agreement")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 4)
                
                Text("Last Updated: April 26, 2025")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                
                // 通用条款
                SectionView(title: "General Provisions") {
                    NumberedTextView(number: "1", text: "Both parties to this agreement are users of FLICK (including services provided by Mobile APP and other products, hereinafter referred to as 'products and services') and danziyi (hereinafter referred to as 'operators').")
                    
                    NumberedTextView(number: "2", text: "Before using FLICK, please read the terms of this agreement carefully.")
                    
                    NumberedTextView(number: "3", text: "When the user uses FLICK, it means that the user has fully understood and fully accepted all the terms under this agreement, and then reached this agreement with the operator.")
                    
                    NumberedTextView(number: "4", text: "The operator has the right to modify or supplement the relevant rules under this agreement from time to time and publish them on the website. If the user continues to use, it will be deemed that you accept the revised terms of this agreement.")
                }
                
                // 用户服务说明
                SectionView(title: "User Service Instructions") {
                    NumberedTextView(number: "1", text: "FLICK does not require registration to use. Users can use FLICK directly without any registration process.")
                    
                    NumberedTextView(number: "2", text: "The user shall take full responsibility for the security of his/her device, and bear corresponding legal responsibility for all acts and events under his/her device.")
                    
                    NumberedTextView(number: "3", text: "The user agrees to accept that the operator sends relevant business information to the user through or other means.")
                    
                    NumberedTextView(number: "4", text: "The operator is not responsible for the deletion or storage failure of the information released by the user.")
                    
                    NumberedTextView(number: "5", text: "The operator has the right to determine whether the user's behavior meets the requirements of the service terms of the website. If the user violates the provisions of the service terms, the website has the right to interrupt or stop using the network services provided by its users.")
                }
                
                // 协议内容的变更和修改
                SectionView(title: "Changes and Amendments") {
                    NumberedTextView(number: "1", text: "The operator has the right to modify the service terms when necessary, and the modified agreement can be viewed on the operator.")
                    
                    NumberedTextView(number: "2", text: "If the user does not agree with the content changed by the operator, he/she can stop using the network service of the station.")
                    
                    NumberedTextView(number: "3", text: "If the user continues to enjoy the network service of this website, it is deemed that he/she agrees to accept the change of the service terms of this website.")
                    
                    NumberedTextView(number: "4", text: "The operator can interrupt or terminate one or more network services at any time according to the actual situation without taking any responsibility for any user or third party. If the user has any objection to the interruption or termination of one or more network services, he can exercise the following rights:")
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("a)")
                            .foregroundStyle(.secondary)
                        Text("Stop using the network service of the operator.")
                    }
                    .padding(.leading, 20)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("b)")
                            .foregroundStyle(.secondary)
                        Text("Notify the operator to stop the service to the user. After the end of the user service, the user's right to use the network service will terminate immediately. From the time of termination, the user has no right to process any unfinished information or services, and the operator has no obligation to transmit any unfinished information or unfinished services to the user or any third party.")
                    }
                    .padding(.leading, 20)
                }
                
                // 用户隐私保护
                SectionView(title: "User Privacy Protection") {
                    Text("The operator will strictly perform the user's privacy confidentiality obligation and promise not to disclose, edit or disclose the user's personal information, except for the following special circumstances:")
                        .padding(.bottom, 8)
                    
                    NumberedTextView(number: "1", text: "With the prior permission and authorization of the user;")
                    
                    NumberedTextView(number: "2", text: "Comply with national laws and regulations or cooperate with the requirements of relevant government departments;")
                    
                    NumberedTextView(number: "3", text: "Comply with the legal service procedures of the operator;")
                    
                    NumberedTextView(number: "4", text: "It is necessary to safeguard the public interests and the legitimate rights and interests of the operator.")
                }
                
                // 用户权利和义务
                SectionView(title: "Rights and Obligations of Users") {
                    NumberedTextView(number: "1", text: "When using the operator's products and services, users must comply with the relevant laws and regulations of the People's Republic of China. Users should agree that they will not use this service for any illegal or improper activities, otherwise users will bear all legal liabilities arising therefrom.")
                    
                    NumberedTextView(number: "2", text: "Users shall not upload, display, post, disseminate or otherwise transmit information containing one of the following contents during the use of their account:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("(1) Endangering national security, disclosing state secrets, subverting state power, and undermining national unity;")
                        Text("(2) Damage to national honor and interests;")
                        Text("(3) Inciting ethnic hatred, ethnic discrimination and undermining ethnic unity;")
                        Text("(4) Those who undermine the state's religious policies and promote heresy and feudal superstition;")
                        Text("(5) Spreading rumors, disturbing social order and undermining social stability;")
                        Text("(6) Spreading obscenity, pornography, gambling, violence, murder, terror or abetting crimes;")
                        Text("(7) Insult or slander others and infringe upon their legal rights;")
                        Text("(8) It contains false, harmful, threatening, infringing on the privacy of others, harassing, infringing, slandering, vulgar, obscene, or other morally offensive content.")
                    }
                    .font(.subheadline)
                    .padding(.leading, 20)
                    .padding(.bottom, 8)
                    
                    NumberedTextView(number: "3", text: "The network service system shall not be used for any illegal purpose.")
                    
                    NumberedTextView(number: "4", text: "It is not allowed to use the products and services of the operator to intentionally make and spread destructive programs such as computer viruses, or engage in any other acts that endanger the security of computer information network.")
                    
                    NumberedTextView(number: "5", text: "If the user's behavior violates the above agreement, the operator has the right to make an independent judgment and immediately cancel the user's service account. The user shall bear all legal responsibilities for his online behavior. The operator's system records may be submitted to the relevant competent department as evidence of the user's violation of the law.")
                    
                    NumberedTextView(number: "6", text: "The user shall agree to protect and maintain the interests of all members of the operator and other users. If the operator or any third party suffers losses due to violation of this agreement or relevant laws and regulations, the user shall bear the legal liabilities arising therefrom.")
                }
                
                // 网络服务内容的所有权
                SectionView(title: "Ownership of Network Service Content") {
                    NumberedTextView(number: "1", text: "The network service content defined by the operator includes but is not limited to: software etc. These contents are protected by the Copyright Law, the Trademark Law, the Patent Law, the Computer Software Protection Regulations and other relevant laws and regulations.")
                }
                
                // 免责声明
                SectionView(title: "Disclaimers") {
                    NumberedTextView(number: "1", text: "The user agrees to bear all risks arising from the use of the operator's products and services and all consequences arising from the use of network services, and the operator does not assume any responsibility for the user.")
                    
                    NumberedTextView(number: "2", text: "The operator does not guarantee that the service will meet the user's requirements, that the service will not be interrupted, and that the timeliness, security and possible technical errors of the service will not be guaranteed.")
                    
                    NumberedTextView(number: "3", text: "The operator shall not be liable for any risk or loss that may be caused by the user's personal data leakage, loss, embezzlement, tampering or temporary or termination of the service due to hacker attack, computer virus invasion or attack, government control, hardware failure, force majeure and other non-intentional or gross negligence of the operator.")
                }
                
                // 其他协议
                SectionView(title: "Other Agreements") {
                    NumberedTextView(number: "1", text: "The user agrees that any dispute arising from the service of the platform shall be governed by the laws of the People's Republic of China, and any party to the relevant dispute may file a lawsuit to the people's court where the operator is domiciled.")
                    
                    NumberedTextView(number: "2", text: "The headings in this Agreement are for convenience only and do not affect the interpretation of the terms themselves. Any provision in this Agreement shall be invalid or unenforceable in whole or in part for any reason, and the remaining provisions shall remain binding.")
                }
                
                // 联系我们
                SectionView(title: "Contact Us") {
                    Text("If you have any questions, opinions or suggestions about this agreement or this service, you can contact us through the following ways:")
                        .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("(1) Call the customer service hotline 13109923825")
                        Text("(2) Email to: danziyi9@gmail.com")
                        Text("(3) Contact address: 上海市静安区场中路2950号, contact: danziyi")
                    }
                    .font(.subheadline)
                    .padding(.leading, 20)
                }
            }
            .padding()
        }
        .navigationTitle("User Agreement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 4)
                
                Text("Last Updated: March 15, 2024")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                
                // 介绍
                SectionView(title: "Introduction") {
                    Text("Welcome to visit our products. FLICK (including services provided by Mobile APP and other products, hereinafter referred to as 'products and services') is developed and operated by danziyi (hereinafter referred to as 'we'). Ensuring the data security and privacy protection of users is our primary task. This privacy policy specifies the data you collect when accessing and using our products and services and the processing methods.")
                    
                    Text("Please carefully read and confirm that you fully understand all the rules and key points of this privacy policy before continuing to use our products. Once you choose to use it, it is deemed that you agree with all the contents of this privacy policy and agree that we collect and use your relevant information according to it. If you have any questions about this policy during reading, you can contact our customer service for consultation. Please contact us through or the feedback method in the product. If you do not agree to the relevant agreement or any of its terms, you should stop using our products and services.")
                        .padding(.top, 8)
                }
                
                // 政策帮助你了解什么
                SectionView(title: "What This Policy Helps You Understand") {
                    Text("This privacy policy helps you understand the following:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("· Definition")
                        Text("· How do we collect and use your personal information")
                        Text("· How do we store and protect your personal information")
                        Text("· How do we share, transfer and publicly disclose your personal information")
                        Text("· How to update this policy")
                        Text("· How to contact us")
                    }
                    .font(.subheadline)
                    .padding(.leading, 20)
                    .padding(.top, 8)
                }
                
                // 定义
                SectionView(title: "Definition") {
                    DefinitionItemView(term: "we", definition: "Refer to danziyi.")
                    
                    DefinitionItemView(term: "personal information", definition: "It refers to all kinds of information related to identified or identifiable natural persons recorded by electronic or other means, excluding information after anonymization.")
                    
                    DefinitionItemView(term: "personal sensitive information", definition: "Refers to personal information that may cause discrimination or serious harm to personal and property once disclosed or illegally used, including race, nationality, religious belief, personal biological characteristics, medical health, financial account, personal whereabouts and other information (we will prominently mark specific personal sensitive information in bold in this privacy policy).")
                    
                    DefinitionItemView(term: "juveniles", definition: "Refers to natural persons under the age of 18.")
                    
                    DefinitionItemView(term: "children", definition: "Refers to natural persons under the age of 14.")
                }
                
                // 我们如何收集和使用您的个人信息
                SectionView(title: "How Do We Collect and Use Your Personal Information") {
                    Text("FLICK does not collect any personal information from users. Users can use FLICK without any registration or providing any personal data.")
                }
                
                // 我们如何存储和保护您的个人信息
                SectionView(title: "How Do We Store and Protect Your Personal Information") {
                    Text("Since FLICK does not collect any personal information, there is no need to store or protect user data.")
                }
                
                // 我们如何共享、转让和公开披露您的个人信息
                SectionView(title: "How Do We Share, Transfer and Publicly Disclose Your Personal Information") {
                    Text("FLICK does not collect any personal information, so there is no sharing, transfer, or public disclosure of user data.")
                }
                
                // 如何更新本政策
                SectionView(title: "How to Update This Policy") {
                    Text("Our privacy policy may change.")
                    
                    Text("Without your explicit consent, we will not reduce your rights under this policy. We will publish any changes to this policy on this page.")
                        .padding(.top, 8)
                    
                    Text("For major changes, we will also provide more significant notifications (such as official announcements, push notifications, SMS or email), and obtain your explicit consent again when you log in for the first time after the update of this policy. If you click 'agree' or 'next' after updating this policy and receiving our notice, it means that you have fully read, understood and accepted the revised policy.")
                        .padding(.top, 8)
                    
                    Text("The major changes referred to in this policy include but are not limited to:")
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Significant changes have taken place in our service model, such as the type, purpose and method of processing personal information")
                        Text("2. Significant changes have taken place in our ownership structure and organizational structure, such as changes in owners caused by business adjustment, mergers and acquisitions, bankruptcy, etc")
                        Text("3. The main objects of personal information sharing, transfer or public disclosure have changed")
                        Text("4. Your right to participate in personal information processing and the way you exercise it have changed significantly")
                        Text("5. When the department responsible for handling personal information security, contact information and complaint channel change")
                        Text("6. When the personal information security impact assessment report indicates that there are high risks")
                    }
                    .font(.subheadline)
                    .padding(.leading, 20)
                    .padding(.top, 8)
                    
                    Text("We will also archive the old version of this policy for your reference.")
                        .padding(.top, 8)
                }
                
                // 如何联系我们
                SectionView(title: "How to Contact Us") {
                    NumberedTextView(number: "1", text: "If you have any questions, opinions or suggestions about this policy, you can contact us through the following ways:")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("(1) Call the customer service hotline 13109923825")
                        Text("(2) Send an email to: danziyi9@gmail.com")
                        Text("(3) Contact address: 上海市静安区场中路2950号, contact: danziyi")
                    }
                    .font(.subheadline)
                    .padding(.leading, 40)
                    .padding(.top, 8)
                    
                    Text("Our customer service department will reply with the personal information protection department within 30 days and help solve your problem.")
                        .padding(.leading, 20)
                        .padding(.top, 8)
                    
                    NumberedTextView(number: "2", text: "If you are not satisfied with our reply, especially if our personal information processing behavior has damaged your legitimate rights and interests, you can also seek solutions through the following external channels: file a lawsuit to the people's court where is located, or file a complaint or report to the regulatory authorities such as Netcom, industry and commerce, and public security.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 辅助组件：章节视图
struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.bottom, 4)
            
            content
                .font(.body)
            
            Divider()
                .padding(.vertical, 8)
        }
    }
}

// 辅助组件：带序号的文本视图
struct NumberedTextView: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number + ".")
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
            Text(text)
        }
    }
}

// 辅助组件：定义项目视图
struct DefinitionItemView: View {
    let term: String
    let definition: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.primary)
            
            Text(definition)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}

// 特别鸣谢视图
struct CreditsView: View {
    var body: some View {
        List {
            // 顶部标题区域
            Section {
                HStack {
                    Image(systemName: "medal.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text("感谢以下人员对FLICK的贡献")
                        .font(.headline)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(.systemGroupedBackground))
            }
            
            // 测试团队
            Section(header: Text("测试团队")) {
                ContributorRow(name: "Zhang Jingrou", role: "测试")
                
                ContributorRow(name: "17", role: "测试")

                ContributorRow(name: "Wei Wenjun", role: "测试")
                
                ContributorRow(name: "Wang Xiaotiao", role: "测试")
                
                ContributorRow(name: "Yang Xinlei", role: "测试")
                
                ContributorRow(name: "Sun Shangqian", role: "测试")
                
                ContributorRow(name: "Wu Hanzhen", role: "测试")
                
                ContributorRow(name: "Zhu Keen", role: "测试")
                
                ContributorRow(name: "Li XinYue", role: "测试")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("致谢")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 贡献者行组件
struct ContributorRow: View {
    let name: String
    let role: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            
            Text(role)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// 关于应用视图
struct AboutAppView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 应用图标
                Image("filmReel") // 确保在资源中有此图像，或使用系统图标替代
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .padding(.top, 20)
                
                // 应用名称
                Text("FLICK")
                    .font(.system(size: 40, weight: .bold))
                
                // 版本号
                Text("版本 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .padding(.horizontal, 30)
                
                // 应用介绍
                Text("FLICK 是一款专为影视行业设计的项目与场景管理应用，帮助您高效管理拍摄、照片、PDF报告与团队协作。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // 功能特点
                VStack(alignment: .leading, spacing: 16) {
                    Text("功能特点")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    // 项目与场景管理
                    FeatureItemRow(
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        title: "项目与场景管理",
                        description: "轻松创建和管理影视项目与多场景"
                    )
                    
                    // 堪景与照片管理
                    FeatureItemRow(
                        icon: "camera.fill",
                        iconColor: .blue,
                        title: "堪景与照片管理",
                        description: "现场拍照、批量上传，自动生成PDF报告"
                    )
                    
                    // PDF报告
                    FeatureItemRow(
                        icon: "doc.fill",
                        iconColor: .blue,
                        title: "PDF 报告",
                        description: "一键生成专业场地勘察报告，LOGO与时间信息规范显示"
                    )
                    
                    // 任务提醒
                    FeatureItemRow(
                        icon: "bell.fill",
                        iconColor: .blue,
                        title: "任务提醒",
                        description: "设置任务提醒，不错过重要日期"
                    )
                    
                    // iCloud同步
                    FeatureItemRow(
                        icon: "icloud.fill",
                        iconColor: .blue,
                        title: "iCloud 同步",
                        description: "跨设备同步所有数据"
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                
                // 联系我们按钮
                Button(action: {
                    // 这里可以添加发送邮件或打开网站的操作
                    if let url = URL(string: "mailto:danziyi9@gmail.com") {
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .imageScale(.medium)
                        Text("联系我们")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 版权信息
                Text("© 2024 FLICK Studio. 保留所有权利。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关于应用")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 功能项行组件（用于AboutAppView）
struct FeatureItemRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// 设置页脚视图
struct SettingsFooterView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和名称
            VStack(spacing: 4) {
                Image(systemName: "film.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("FLICK")
                    .font(.headline)
                Text("© 2023-2024")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            
            // 提示文字
            Text("感谢使用FLICK应用，如有问题或建议，请与我们联系")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
    }
} 