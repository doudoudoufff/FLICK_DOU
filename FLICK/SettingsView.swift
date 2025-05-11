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

// 添加关于应用视图
struct AboutAppView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("FLICKLogo") // 使用 FLICKLogo 作为关于页面图标
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .padding(.top, 30)
                
                Text("FLICK")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("版本 1.2.1")
                    .foregroundStyle(.secondary)
                
                Divider()
                    .padding(.horizontal)
                
                Text("FLICK 是一款专为影视行业设计的项目与场景管理应用，帮助您高效管理拍摄、照片、PDF报告与团队协作。")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("功能特点")
                        .font(.headline)
                        .padding(.top)
                    
                    FeatureRow(icon: "list.bullet.clipboard", title: "项目与场景管理", description: "轻松创建和管理影视项目与多场景")
                    FeatureRow(icon: "camera.fill", title: "堪景与照片管理", description: "现场拍照、批量上传，自动生成PDF报告")
                    FeatureRow(icon: "doc.text.fill", title: "PDF 报告", description: "一键生成专业场地勘察报告，LOGO与时间信息规范显示")
                    FeatureRow(icon: "bell.fill", title: "任务提醒", description: "设置任务提醒，不错过重要日期")
                    FeatureRow(icon: "icloud.fill", title: "iCloud 同步", description: "跨设备同步所有数据")
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                Button(action: {
                    if let url = URL(string: "mailto:danziyi9@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("联系我们", systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                
                Text("© 2024 FLICK Studio. 保留所有权利。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 30)
            }
            .padding()
        }
        .navigationTitle("关于应用")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 功能特点行视图
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

// 协议章节标题样式
fileprivate struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 2)
            Text(title)
                .font(.title3).bold()
                .foregroundColor(.accentColor)
                .padding(.bottom, 2)
        }
    }
}

// 协议内容块样式
fileprivate struct AgreementBlock: View {
    let items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.body)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// 用户协议视图
struct UserAgreementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("FLICK User license Agreement")
                    .font(.largeTitle).bold()
                    .foregroundColor(.accentColor)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Last Updated: April 26, 2025")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Group {
                    SectionHeader("· General provisions of user agreement")
                    AgreementBlock([
                        "1. Both parties to this agreement are registered users (hereinafter referred to as 'users') of danziyi (hereinafter referred to as 'operators') and FLICK (including services provided by Mobile APP and other products, hereinafter referred to as 'products and services').",
                        "2. Before registering, please read the terms of this agreement carefully and complete all registration procedures according to the prompts on the page.",
                        "3. When the user clicks the 'Agree' button during the registration process, it means that the user has fully understood and fully accepted all the terms under this agreement, and then reached this agreement with the operator.",
                        "4. The operator has the right to modify or supplement the relevant rules under this agreement from time to time and publish them on the website. If the user continues to use, it will be deemed that you accept the revised terms of this agreement."
                    ])
                    SectionHeader("· User service instructions")
                    AgreementBlock([
                        "1. When registering, users should fill in accurate e-mail address and other relevant personal data according to the registration prompt, which meets the requirements of completeness, accuracy and authenticity.",
                        "2. Once the user is registered successfully, it will become the operator's legal registered user . The user shall take full responsibility for the security of his/her account, and bear corresponding legal responsibility for all acts and events under his/her user name.",
                        "3. The user agrees to accept that the operator sends relevant business information to the user through or other means.",
                        "4. The operator is not responsible for the deletion or storage failure of the information released by the user.",
                        "5. The operator has the right to determine whether the user's behavior meets the requirements of the service terms of the website. If the user violates the provisions of the service terms, the website has the right to interrupt or stop using the network services provided by its users.",
                        "6. The operator provides account deletion service. If users need to delete accounts, they can contact us through the contact information in this agreement."
                    ])
                    SectionHeader("· Changes and amendments to the contents of the agreement")
                    AgreementBlock([
                        "1. The operator has the right to modify the service terms when necessary, and the modified agreement can be viewed on the operator.",
                        "2. If the user does not agree with the content changed by the operator, he/she can stop using the network service of the station.",
                        "3. If the user continues to enjoy the network service of this website, it is deemed that he/she agrees to accept the change of the service terms of this website.",
                        "4. The operator can interrupt or terminate one or more network services at any time according to the actual situation without taking any responsibility for any user or third party. If the user has any objection to the interruption or termination of one or more network services, he can exercise the following rights:",
                        "  (1) Stop using the network service of the operator.",
                        "  (2) Notify the operator to stop the service to the user. After the end of the user service, the user's right to use the network service will terminate immediately. From the time of termination, the user has no right to process any unfinished information or services, and the operator has no obligation to transmit any unfinished information or unfinished services to the user or any third party."
                    ])
                    SectionHeader("· User privacy protection")
                    AgreementBlock([
                        "The operator will strictly perform the user's privacy confidentiality obligation and promise not to disclose, edit or disclose the user's personal information, except for the following special circumstances:",
                        "1. With the prior permission and authorization of the registered user;",
                        "2. Comply with national laws and regulations or cooperate with the requirements of relevant government departments;",
                        "3. Comply with the legal service procedures of the operator;",
                        "4. It is necessary to safeguard the public interests and the legitimate rights and interests of the operator."
                    ])
                    SectionHeader("· Rights and obligations of registered users")
                    AgreementBlock([
                        "1. When using the operator's products and services, registered users must comply with the relevant laws and regulations of the People's Republic of China. Users should agree that they will not use this service for any illegal or improper activities, otherwise users will bear all legal liabilities arising therefrom.",
                        "2. Users shall not upload, display, post, disseminate or otherwise transmit information containing one of the following contents during the use of their account:",
                        "  (1) Endangering national security, disclosing state secrets, subverting state power, and undermining national unity;",
                        "  (2) Damage to national honor and interests;",
                        "  (3) Inciting ethnic hatred, ethnic discrimination and undermining ethnic unity;",
                        "  (4) Those who undermine the state's religious policies and promote heresy and feudal superstition;",
                        "  (5) Spreading rumors, disturbing social order and undermining social stability;",
                        "  (6) Spreading obscenity, pornography, gambling, violence, murder, terror or abetting crimes;",
                        "  (7) Insult or slander others and infringe upon their legal rights;",
                        "  (8) It contains false, harmful, threatening, infringing on the privacy of others, harassing, infringing, slandering, vulgar, obscene, or other morally offensive content.",
                        "3. The network service system shall not be used for any illegal purpose.",
                        "4. It is not allowed to use the products and services of the operator to intentionally make and spread destructive programs such as computer viruses, or engage in any other acts that endanger the security of computer information network.",
                        "5. If the user's behavior violates the above agreement, the operator has the right to make an independent judgment and immediately cancel the user's service account. The user shall bear all legal responsibilities for his online behavior. The operator's system records may be submitted to the relevant competent department as evidence of the user's violation of the law.",
                        "6. The user shall agree to protect and maintain the interests of all members of the operator and other users. If the operator or any third party suffers losses due to violation of this agreement or relevant laws and regulations, the user shall bear the legal liabilities arising therefrom."
                    ])
                    SectionHeader("· Ownership of network service content of the operator")
                    AgreementBlock([
                        "1. The network service content defined by the operator includes but is not limited to: 软件 etc. These contents are protected by the Copyright Law, the Trademark Law, the Patent Law, the Computer Software Protection Regulations and other relevant laws and regulations."
                    ])
                    SectionHeader("· Disclaimers")
                    AgreementBlock([
                        "1. The user agrees to bear all risks arising from the use of the operator`s products and services and all consequences arising from the use of network services, and the operator does not assume any responsibility for the user.",
                        "2. The operator does not guarantee that the service will meet the user`s requirements, that the service will not be interrupted, and that the timeliness, security and possible technical errors of the service will not be guaranteed.",
                        "3. The operator shall not be liable for any risk or loss that may be caused by the user's personal data leakage, loss, embezzlement, tampering or temporary or termination of the service due to hacker attack, computer virus invasion or attack, government control, hardware failure, force majeure and other non-intentional or gross negligence of the operator."
                    ])
                    SectionHeader("· Other agreements")
                    AgreementBlock([
                        "1. The user agrees that any dispute arising from the service of the platform shall be governed by the laws of the People's Republic of China, and any party to the relevant dispute may file a lawsuit to the people's court where the operator is domiciled.",
                        "2. The headings in this Agreement are for convenience only and do not affect the interpretation of the terms themselves. Any provision in this Agreement shall be invalid or unenforceable in whole or in part for any reason, and the remaining provisions shall remain binding."
                    ])
                    SectionHeader("· Contact us")
                    AgreementBlock([
                        "If you have any questions, opinions or suggestions about this agreement or this service, you can contact us through the following ways:",
                        "  (1) Call the customer service hotline 13109923825",
                        "  (2) Email to:danziyi9@gmail.com",
                        "  (3) Contact address: 上海市静安区场中路2950号, contact: danziyi"
                    ])
                }
                Text("(End)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("User license Agreement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("FLICK Privacy Policy")
                    .font(.largeTitle).bold()
                    .foregroundColor(.accentColor)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Last Updated: March 15, 2024")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                Group {
                    SectionHeader("· Introduction")
                    AgreementBlock([
                        "Welcome to visit our products.  FLICK （Including services provided by Mobile APP and other products, hereinafter referred to as 'products and services'）It is developed and operated by danziyi (hereinafter referred to as 'we'). Ensuring the data security and privacy protection of users is our primary task. This privacy policy specifies the data you collect when accessing and using our products and services and the processing methods.",
                        "Please carefully read and confirm that you fully understand all the rules and key points of this privacy policy before continuing to use our products. Once you choose to use it, it is deemed that you agree with all the contents of this privacy policy and agree that we collect and use your relevant information according to it. If you have any questions about this policy during reading, you can contact our customer service for consultation. Please contact us through or the feedback method in the product. If you do not agree to the relevant agreement or any of its terms, you should stop using our products and services."
                    ])
                    SectionHeader("· What this policy helps you understand")
                    AgreementBlock([
                        "This privacy policy helps you understand the following:",
                        "· Definition",
                        "· How do we collect and use your personal information",
                        "· How do we store and protect your personal information",
                        "· How do we share, transfer and publicly disclose your personal information",
                        "· How to update this policy",
                        "· How to contact us"
                    ])
                    SectionHeader("· Definition")
                    AgreementBlock([
                        "we: Refer to danziyi.",
                        "personal information: It refers to all kinds of information related to identified or identifiable natural persons recorded by electronic or other means, excluding information after anonymization.",
                        "personal sensitive information: Refers to personal information that may cause discrimination or serious harm to personal and property once disclosed or illegally used, including race, nationality, religious belief, personal biological characteristics, medical health, financial account, personal whereabouts and other information (we will prominently mark specific personal sensitive information in bold in this privacy policy).",
                        "juveniles: Refers to natural persons under the age of 18.",
                        "children: Refers to natural persons under the age of 14."
                    ])
                    SectionHeader("· How do we collect and use your personal information")
                    AgreementBlock([
                        "Personal information refers to all kinds of information recorded in electronic or other ways that can identify the identity of a specific natural person or reflect the activities of a specific natural person alone or in combination with other information. We collect and use your personal information, including but not limited to etc in accordance with the requirements of the Network Security Law of the People's Republic of China, the Information Security Technology Personal Information Security Specification (GB/T 35273-2017) and other relevant laws and regulations, and in strict accordance with the principles of legitimacy, legality and necessity, for the purpose of your use of the services and/or products we provide.",
                        "In order to accept our comprehensive product services, you should first register a user account through which we will record relevant data. The account name, password and your contact information you are going to use may be verified by SMS or email."
                    ])
                    SectionHeader("· How do we store and protect your personal information")
                    AgreementBlock([
                        "As a general rule, we only retain your personal information for the time required to achieve the purpose of information collection. We will keep your personal information for as long as it is strictly necessary to manage the relationship with you (for example, when you open an account and obtain services from our products). For the purpose of complying with legal obligations or to prove that a certain right or contract meets the applicable limitation of action requirements, we may need to retain your archived personal information after the expiration of the above period and cannot delete it according to your requirements."
                    ])
                    SectionHeader("· How do we share, transfer and publicly disclose your personal information")
                    AgreementBlock([
                        "When managing our daily business activities, we will use your personal information in compliance and appropriately in order to pursue legal interests and better serve customers. For comprehensive consideration of business and various aspects, .",
                        "We may share your personal information according to laws and regulations or the mandatory requirements of the competent government departments. On the premise of complying with laws and regulations, when we receive the above request for disclosure of information, we will require that corresponding legal documents, such as subpoenas or investigation letters, be issued. We firmly believe that the information we are required to provide should be as transparent as possible within the scope permitted by law.",
                        "Under the following circumstances, sharing, transferring and public disclosure of your personal information does not require your authorization and consent in advance:",
                        "1. Directly related to national security and national defense security",
                        "2. Directly related to criminal investigation, prosecution, trial and execution of judgments",
                        "3. For the purpose of safeguarding your or other personal life, property and other important legitimate rights and interests, but it is difficult to obtain my consent",
                        "4. Personal information that you disclose to the public",
                        "5. Collect personal information from legally disclosed information, such as legal news reports, government information disclosure and other channels",
                        "6. It is necessary to sign and perform the contract according to the requirements of the personal information subject",
                        "7. It is necessary to maintain the safe and stable operation of the products or services provided, for example, to find and handle the faults of the products or services",
                        "8. Other circumstances stipulated by laws and regulations"
                    ])
                    SectionHeader("· How to update this policy")
                    AgreementBlock([
                        "Our privacy policy may change.",
                        "Without your explicit consent, we will not reduce your rights under this policy. We will publish any changes to this policy on this page.",
                        "For major changes, we will also provide more significant notifications (such as official announcements, push notifications, SMS or email), and obtain your explicit consent again when you log in for the first time after the update of this policy. If you click 'agree' or 'next' after updating this policy and receiving our notice, it means that you have fully read, understood and accepted the revised policy.",
                        "The major changes referred to in this policy include but are not limited to:",
                        "1. Significant changes have taken place in our service model, such as the type, purpose and method of processing personal information",
                        "2. Significant changes have taken place in our ownership structure and organizational structure, such as changes in owners caused by business adjustment, mergers and acquisitions, bankruptcy, etc",
                        "3. The main objects of personal information sharing, transfer or public disclosure have changed",
                        "4. Your right to participate in personal information processing and the way you exercise it have changed significantly",
                        "5. When the department responsible for handling personal information security, contact information and complaint channel change",
                        "6. When the personal information security impact assessment report indicates that there are high risks",
                        "We will also archive the old version of this policy for your reference."
                    ])
                    SectionHeader("· How to contact us")
                    AgreementBlock([
                        "1. If you have any questions, opinions or suggestions about this policy, you can contact us through the following ways:",
                        "（1）Call the customer service hotline 13109923825",
                        "（2）Send an email to: danziyi9@gmail.com",
                        "（3）Contact address: 上海市静安区场中路2950号, contact: danziyi",
                        "Our customer service department will reply with the personal information protection department within 30 days and help solve your problem.",
                        "2. If you are not satisfied with our reply, especially if our personal information processing behavior has damaged your legitimate rights and interests, you can also seek solutions through the following external channels: file a lawsuit to the people's court where  is located, or file a complaint or report to the regulatory authorities such as Netcom, industry and commerce, and public security."
                    ])
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
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
                    Text("感谢以下人员对FLICK的贡献")
                }
                .font(.headline)
            }
            
            Section("测试团队") {
                ContributorRow(name: "Zhang Jingrou", role: "测试")
                ContributorRow(name: "17", role: "测试")
                ContributorRow(name: "Wang Xiaotiao", role: "测试")
                ContributorRow(name: "Yang Xinlei", role: "测试")
                ContributorRow(name: "Sun Shangqian", role: "产品")
                ContributorRow(name: "Wu Hanzhen", role: "测试")
                ContributorRow(name: "Zhu Keen", role: "测试")
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