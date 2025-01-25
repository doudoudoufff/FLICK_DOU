import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultReminderHour") private var defaultReminderHour: Int = 9
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @Environment(\.openURL) private var openURL
    @State private var showingProfileEdit = false
    
    // 模拟用户数据，之后需要替换为真实的用户管理系统
    @AppStorage("userNickname") private var nickname: String = "未设置"
    @AppStorage("userRole") private var role: String = "制片主任"
    @AppStorage("userAvatar") private var avatarData: Data = Data()
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationView {
            List {
                // 个人账户
                Section {
                    NavigationLink {
                        ProfileEditView(
                            nickname: $nickname,
                            role: $role,
                            avatarData: $avatarData
                        )
                    } label: {
                        HStack(spacing: 12) {
                            // 头像
                            if let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                            
                            // 用户信息
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nickname)
                                    .font(.headline)
                                Text(role)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 通用设置
                Section("通用") {
                    Toggle("启用通知", isOn: $enableNotifications)
                        .listRowBackground(Color(.systemBackground))
                        .tint(.blue)
                    
                    if enableNotifications {
                        Picker("默认提醒时间", selection: $defaultReminderHour) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                    }
                }
                
                // 其他
                Section("其他") {
                    // 社交媒体
                    Link(destination: URL(string: "https://www.xiaohongshu.com/user/profile/5c15ccc6000000000600df32")!) {
                        HStack {
                            Label {
                                Text("在小红书关注我")
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 分享
                    Button {
                        shareApp()
                    } label: {
                        Label {
                            Text("分享给朋友")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // App Store 评分
                    Link(destination: URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review")!) {
                        HStack {
                            Label {
                                Text("给个五星好评")
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 报告问题
                    Link(destination: URL(string: "mailto:support@example.com?subject=FLICK%20Bug%20Report")!) {
                        HStack {
                            Label {
                                Text("报告 Bug")
                            } icon: {
                                Image(systemName: "ant.fill")
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 关于
                Section {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label {
                            Text("特别鸣谢")
                        } icon: {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(.pink)
                        }
                    }
                    
                    NavigationLink {
                        UserAgreementView()
                    } label: {
                        Label {
                            Text("用户协议")
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("隐私政策")
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.teal)
                        }
                    }
                }
                
                // 版本信息
                Section {
                    HStack {
                        Label {
                            Text("版本")
                        } icon: {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label {
                            Text("备案号")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                        Spacer()
                        Text("京ICP备XXXXXXXX号")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
    
    private func shareApp() {
        let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX")!
        let activityVC = UIActivityViewController(
            activityItems: ["FLICK - 影视项目管理工具", url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// 特别鸣谢视图
struct CreditsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "medal.fill")
                        .foregroundColor(.orange)
                    Text("感谢以下人员对项目的贡献")
                }
                .font(.headline)
                .padding(.vertical, 8)
            }
            
            Section("贡献者") {
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
                        .foregroundColor(.secondary)
                    Text(country)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// 用户协议视图
struct UserAgreementView: View {
    var body: some View {
        ScrollView {
            Text("用户协议内容...")
                .padding()
        }
        .navigationTitle("用户协议")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("隐私政策内容...")
                .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 个人资料编辑视图
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var nickname: String
    @Binding var role: String
    @Binding var avatarData: Data
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        List {
            Section {
                // 头像
                HStack {
                    Text("头像")
                    Spacer()
                    if let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .onTapGesture {
                                showingImagePicker = true
                            }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                showingImagePicker = true
                            }
                    }
                }
                
                // 昵称
                TextField("昵称", text: $nickname)
                
                // 职位
                Picker("职位", selection: $role) {
                    Text("制片主任").tag("制片主任")
                    Text("执行制片").tag("执行制片")
                    Text("制片助理").tag("制片助理")
                    Text("场务主任").tag("场务主任")
                }
            }
            
            Section {
                Button("退出登录", role: .destructive) {
                    // 实现退出登录逻辑
                }
            }
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
                .onChange(of: selectedImage) { newImage in
                    if let newImage = newImage,
                       let imageData = newImage.jpegData(compressionQuality: 0.8) {
                        avatarData = imageData
                    }
                }
        }
    }
}

// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    SettingsView()
} 