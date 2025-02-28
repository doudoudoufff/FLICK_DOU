import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @EnvironmentObject private var projectStore: ProjectStore
    
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
                            // 创建演示数据
                            createDemoData()
                            
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
    
    private func createDemoData() {
        // 短片项目
        let shortFilm = Project(
            id: UUID(),
            name: "春天的声音",
            director: "王导演",
            producer: "赵制片",
            startDate: Date().addingTimeInterval(86400 * 7),
            status: .preProduction,
            color: .blue,
            tasks: [
                ProjectTask(
                    title: "完成最终分镜",
                    assignee: "导演组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                ),
                ProjectTask(
                    title: "确定主要演员",
                    assignee: "选角导演",
                    dueDate: Date().addingTimeInterval(86400 * 4)
                ),
                ProjectTask(
                    title: "场地合同签订",
                    assignee: "制片组",
                    dueDate: Date().addingTimeInterval(86400 * 5)
                )
            ],
            invoices: [
                Invoice(
                    name: "星光场地公司",
                    phone: "13800138000",
                    idNumber: "110101199001011234",
                    bankAccount: "6222021234567890",
                    bankName: "中国建设银行",
                    date: Date()
                )
            ],
            locations: [
                Location(
                    name: "老街区",
                    address: "北京市东城区东四胡同",
                    photos: [],
                    notes: "需要注意早晚高峰时段的环境音"
                ),
                Location(
                    name: "音乐教室",
                    address: "北京市海淀区中关村音乐学院",
                    photos: [],
                    notes: "已获得场地使用许可"
                )
            ],
            accounts: [
                Account(
                    name: "星光场地公司",
                    type: .location,
                    bankName: "中国建设银行",
                    bankBranch: "北京东城支行",
                    bankAccount: "6222021234567890",
                    contactName: "李经理",
                    contactPhone: "13800138000"
                )
            ]
        )
        
        // 广告项目
        let commercial = Project(
            id: UUID(),
            name: "新春饮料广告",
            director: "张导演",
            producer: "李制片",
            startDate: Date().addingTimeInterval(86400 * 3),
            status: .preProduction,
            color: .orange,
            tasks: [
                ProjectTask(
                    title: "确认产品展示要求",
                    assignee: "制片组",
                    dueDate: Date().addingTimeInterval(86400)
                ),
                ProjectTask(
                    title: "道具采购清单",
                    assignee: "美术组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                ),
                ProjectTask(
                    title: "完成灯光设计",
                    assignee: "灯光组",
                    dueDate: Date().addingTimeInterval(86400 * 2)
                )
            ],
            invoices: [
                Invoice(
                    name: "城市影棚",
                    phone: "13900139000",
                    idNumber: "110101199001011235",
                    bankAccount: "6222021234567891",
                    bankName: "中国工商银行",
                    date: Date()
                )
            ],
            locations: [
                Location(
                    name: "影棚A",
                    address: "北京市朝阳区影视基地A区",
                    photos: [],
                    notes: "需要提前一天进场搭建"
                )
            ],
            accounts: [
                Account(
                    name: "城市影棚",
                    type: .location,
                    bankName: "中国工商银行",
                    bankBranch: "北京朝阳支行",
                    bankAccount: "6222021234567891",
                    contactName: "王经理",
                    contactPhone: "13900139000"
                )
            ]
        )
        
        // 添加项目
        projectStore.addProject(shortFilm)
        projectStore.addProject(commercial)
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