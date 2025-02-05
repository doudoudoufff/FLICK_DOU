import LeanCloud
import SwiftUI

class LCManager: ObservableObject {
    static let shared = LCManager()
    
    // 用户状态
    @Published var isLoggedIn = false
    @Published var currentUserInfo: UserInfo?
    
    struct UserInfo {
        let id: String
        let username: String
        let nickname: String?
    }
    
    private init() {
        // 初始化 LeanCloud SDK
        do {
            try LCApplication.default.set(
                id: "uUImyopEtEIc2swq7A2S4Zij-gzGzoHsz",
                key: "775aKsl0DyGLJ9B45KB5scJn",
                serverURL: "https://uuimyope.lc-cn-n1-shared.com"
            )
            // 检查是否已登录
            checkLoginStatus()
        } catch {
            print("LeanCloud 初始化失败: \(error)")
        }
    }
    
    // 检查登录状态
    private func checkLoginStatus() {
        if let user = LCApplication.default.currentUser {
            isLoggedIn = true
            currentUserInfo = UserInfo(
                id: user.objectId?.stringValue ?? "",
                username: user.username?.stringValue ?? "",
                nickname: user.get("nickname") as? String
            )
        }
    }
    
    // 发送验证码
    func sendVerificationCode(to phoneNumber: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            LCSMSClient.requestShortMessage(
                mobilePhoneNumber: phoneNumber,
                templateName: "login"  // 在 LeanCloud 后台配置的短信模板名称
            ) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 手机号验证码登录
    func loginWithPhone(phoneNumber: String, verificationCode: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            LCUser.signUpOrLogIn(
                mobilePhoneNumber: phoneNumber,
                verificationCode: verificationCode
            ) { result in
                switch result {
                case .success(let user):
                    self.isLoggedIn = true
                    self.currentUserInfo = UserInfo(
                        id: user.objectId?.stringValue ?? "",
                        username: user.username?.stringValue ?? "",
                        nickname: user.get("nickname") as? String
                    )
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 保存项目到云端
    func saveProject(_ project: Project) async throws {
        let lcProject = LCObject(className: "Project")
        try lcProject.set("name", value: project.name)
        try lcProject.set("director", value: project.director)
        try lcProject.set("producer", value: project.producer)
        try lcProject.set("startDate", value: project.startDate)
        
        // 使用 withCheckedThrowingContinuation 包装异步操作
        return try await withCheckedThrowingContinuation { continuation in
            lcProject.save { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 从云端获取项目列表
    func fetchProjects() async throws -> [Project] {
        let query = LCQuery(className: "Project")
        
        // 使用 withCheckedThrowingContinuation 包装异步操作
        let results = try await withCheckedThrowingContinuation { continuation in
            query.find { result in
                switch result {
                case .success(let objects):
                    continuation.resume(returning: objects)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        return results.map { object -> Project? in
            guard let name = object.get("name") as? String,
                  let director = object.get("director") as? String,
                  let producer = object.get("producer") as? String,
                  let startDate = object.get("startDate") as? Date else {
                return nil
            }
            
            let idString = object.objectId?.stringValue ?? UUID().uuidString
            let id = UUID(uuidString: idString) ?? UUID()
            
            return Project(
                id: id,
                name: name,
                director: director,
                producer: producer,
                startDate: startDate,
                color: .blue,  // 暂时使用默认颜色
                tasks: [],
                invoices: []
            )
        }.compactMap { $0 }
    }
} 