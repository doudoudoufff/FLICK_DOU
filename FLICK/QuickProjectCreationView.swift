import SwiftUI

/// 快速项目创建视图 - 用于新用户引导后快速创建第一个项目
struct QuickProjectCreationView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var isPresented: Bool
    @State private var projectName = ""
    @State private var isCreating = false
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 顶部图标
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.top, 20)
            
            // 标题
            Text("创建您的第一个项目")
                .font(.title2)
                .fontWeight(.bold)
            
            // 说明
            Text("为了帮助您快速开始使用FLICK，请创建一个项目。\n您可以稍后在项目详情中添加更多信息。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 项目名称输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("项目名称")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("输入项目名称", text: $projectName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: projectName.isEmpty ? 0 : 2)
                    )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 创建按钮
            Button(action: createProject) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("创建项目")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(projectName.isEmpty ? Color.gray : Color.accentColor)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(projectName.isEmpty || isCreating)
            
            // 跳过按钮
            Button("稍后再说") {
                isPresented = false
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .padding()
        .frame(maxWidth: 500)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            Group {
                if showSuccess {
                    SuccessOverlay {
                        isPresented = false
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        )
        .animation(.spring(response: 0.3), value: showSuccess)
    }
    
    private func createProject() {
        guard !projectName.isEmpty else { return }
        
        // 设置创建中状态
        isCreating = true
        
        // 创建项目（使用默认值简化流程）
        let project = Project(
            name: projectName,
            director: "",
            producer: "",
            startDate: Date(),
            status: .inProgress,
            color: .blue
        )
        
        // 模拟网络延迟，增强用户体验
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 添加到项目存储
            projectStore.addProject(project)
            
            // 显示成功动画
            withAnimation {
                isCreating = false
                showSuccess = true
            }
        }
    }
}

/// 成功创建项目后的覆盖层
struct SuccessOverlay: View {
    let onComplete: () -> Void
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.95)
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)
                        .opacity(showCheckmark ? 1.0 : 0.0)
                }
                
                Text("项目创建成功！")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("您可以在项目标签页中查看和管理您的项目")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: onComplete) {
                    Text("开始使用")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding()
        }
        .onAppear {
            // 动画显示对勾
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
            
            // 2.5秒后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onComplete()
            }
        }
    }
}

#Preview {
    QuickProjectCreationView(isPresented: .constant(true))
        .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
} 
