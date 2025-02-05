import SwiftUI
import Combine

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Logo
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.accentColor, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                // 登录表单
                VStack(spacing: 20) {
                    // 手机号输入框
                    HStack {
                        TextField("手机号", text: $viewModel.phoneNumber)
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                        
                        if viewModel.countdown > 0 {
                            Text("\(viewModel.countdown)s")
                                .foregroundColor(.secondary)
                                .frame(width: 60)
                        } else {
                            Button(action: viewModel.sendVerificationCode) {
                                Text(viewModel.isSendingCode ? "发送中..." : "获取验证码")
                            }
                            .disabled(!viewModel.isValidPhone || viewModel.isSendingCode)
                            .frame(width: 100)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    
                    // 验证码输入框
                    TextField("验证码", text: $viewModel.verificationCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    
                    // 登录按钮
                    Button(action: viewModel.login) {
                        if viewModel.isLoggingIn {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("登录")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!viewModel.isValid || viewModel.isLoggingIn)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("登录")
            .alert("提示", isPresented: $viewModel.showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

// MARK: - ViewModel
class LoginViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var countdown = 0
    @Published var isSendingCode = false
    @Published var isLoggingIn = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private var timer: AnyCancellable?
    
    var isValidPhone: Bool {
        phoneNumber.count == 11 && phoneNumber.first == "1"
    }
    
    var isValid: Bool {
        isValidPhone && verificationCode.count == 6
    }
    
    func sendVerificationCode() {
        guard isValidPhone else { return }
        
        isSendingCode = true
        Task {
            do {
                try await LCManager.shared.sendVerificationCode(to: phoneNumber)
                await MainActor.run {
                    startCountdown()
                    isSendingCode = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "发送失败：\(error.localizedDescription)"
                    showingAlert = true
                    isSendingCode = false
                }
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                }
            }
    }
    
    func login() {
        guard isValid else { return }
        
        isLoggingIn = true
        Task {
            do {
                try await LCManager.shared.loginWithPhone(
                    phoneNumber: phoneNumber,
                    verificationCode: verificationCode
                )
                await MainActor.run {
                    LCManager.shared.isLoggedIn = true
                    isLoggingIn = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "登录失败：\(error.localizedDescription)"
                    showingAlert = true
                    isLoggingIn = false
                }
            }
        }
    }
    
    deinit {
        timer?.cancel()
    }
} 