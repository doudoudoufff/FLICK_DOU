import SwiftUI

/// 用于应用功能引导的叠加层视图
struct TutorialOverlayView: View {
    // 控制叠加层显示状态
    @Binding var isPresented: Bool
    
    // 引导步骤数据
    let tutorialSteps: [TutorialStep]
    
    // 当前显示的步骤索引
    @State private var currentStepIndex = 0
    
    // 是否显示完成按钮
    var showCompletionButton = true
    
    // 完成引导后的回调
    var onComplete: (() -> Void)?
    
    // 获取当前步骤
    private var currentStep: TutorialStep {
        tutorialSteps[currentStepIndex]
    }
    
    // 是否是最后一个步骤
    private var isLastStep: Bool {
        currentStepIndex == tutorialSteps.count - 1
    }
    
    var body: some View {
        GeometryReader { rootGeometry in
            ZStack {
                // 透明背景，允许点击通过
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isLastStep {
                            if !showCompletionButton {
                                withAnimation {
                                    isPresented = false
                                    onComplete?()
                                }
                            }
                        } else {
                            withAnimation {
                                currentStepIndex += 1
                            }
                        }
                    }
                
                // 高亮框
                if let frame = currentStep.frame {
                    HighlightBorderView(frame: frame)
                        .transition(.opacity)
                        .animation(.easeInOut, value: currentStepIndex)
                }
                
                // 提示卡片 - 根据高亮框位置智能定位
                if let frame = currentStep.frame {
                    // 智能定位提示卡片，避免遮挡高亮框
                    let screenHeight = rootGeometry.size.height
                    let screenWidth = rootGeometry.size.width
                    let isFrameInUpperHalf = frame.midY < screenHeight / 2
                    
                    HintCardView(
                        title: currentStep.title,
                        description: currentStep.description,
                        currentStepIndex: currentStepIndex,
                        totalSteps: tutorialSteps.count,
                        isLastStep: isLastStep,
                        showCompletionButton: showCompletionButton,
                        onComplete: {
                            withAnimation {
                                isPresented = false
                                onComplete?()
                            }
                        }
                    )
                    .frame(width: screenWidth - 32)
                    .padding(.horizontal, 16)
                    .position(
                        x: screenWidth / 2,
                        y: isFrameInUpperHalf 
                            ? min(screenHeight - 100, frame.maxY + 120) // 如果框在上半部分，提示卡片在下方
                            : max(120, frame.minY - 120) // 如果框在下半部分，提示卡片在上方
                    )
                } else {
                    // 对于没有框架的步骤，居中显示
                    VStack {
                        Spacer()
                        
                        HintCardView(
                            title: currentStep.title,
                            description: currentStep.description,
                            currentStepIndex: currentStepIndex,
                            totalSteps: tutorialSteps.count,
                            isLastStep: isLastStep,
                            showCompletionButton: showCompletionButton,
                            onComplete: {
                                withAnimation {
                                    isPresented = false
                                    onComplete?()
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, rootGeometry.safeAreaInsets.bottom + 16)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

/// 高亮边框视图
struct HighlightBorderView: View {
    let frame: CGRect
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // 轮廓线
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: frame.width + 10, height: frame.height + 10)
                .position(x: frame.midX, y: frame.midY)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .opacity(isPulsing ? 0.8 : 1.0)
                .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 0)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                }
            
            // 四个角的装饰
            ForEach(0..<4) { index in
                CornerDecoration(index: index)
                    .position(
                        x: index < 2 ? frame.minX - 5 : frame.maxX + 5,
                        y: index % 2 == 0 ? frame.minY - 5 : frame.maxY + 5
                    )
            }
        }
    }
}

/// 角落装饰
struct CornerDecoration: View {
    let index: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
        }
    }
}

/// 提示卡片视图
struct HintCardView: View {
    let title: String
    let description: String
    let currentStepIndex: Int
    let totalSteps: Int
    let isLastStep: Bool
    let showCompletionButton: Bool
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题和描述
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // 步骤指示器
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStepIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // 显示完成按钮
            if isLastStep && showCompletionButton {
                Button(action: onComplete) {
                    Text("完成")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 40)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
    }
}

/// 引导步骤数据结构
struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let frame: CGRect? // 高亮区域的位置和大小
    
    init(title: String, description: String, frame: CGRect? = nil) {
        self.title = title
        self.description = description
        self.frame = frame
    }
}

/// 可以获取视图框架信息的修饰器
struct FrameGetter: ViewModifier {
    @Binding var frame: CGRect
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: FramePreferenceKey.self, value: geometry.frame(in: .global))
                        .onPreferenceChange(FramePreferenceKey.self) { newFrame in
                            DispatchQueue.main.async {
                                self.frame = newFrame
                            }
                        }
                }
            )
    }
}

/// 用于传递视图框架信息的偏好键
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension View {
    /// 获取视图在全局坐标系中的框架
    func getFrame(_ frame: Binding<CGRect>) -> some View {
        self.modifier(FrameGetter(frame: frame))
    }
}

#Preview {
    // 预览示例
    ZStack {
        Color(.systemBackground).edgesIgnoringSafeArea(.all)
        
        Text("示例内容")
            .frame(width: 200, height: 100)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .position(x: UIScreen.main.bounds.width / 2, y: 200)
        
        TutorialOverlayView(
            isPresented: .constant(true),
            tutorialSteps: [
                TutorialStep(
                    title: "欢迎使用引导", 
                    description: "这是一个功能引导示例，点击屏幕继续",
                    frame: CGRect(x: UIScreen.main.bounds.width / 2 - 100, y: 200 - 50, width: 200, height: 100)
                ),
                TutorialStep(
                    title: "第二步", 
                    description: "这里会介绍另一个功能，点击屏幕继续",
                    frame: CGRect(x: UIScreen.main.bounds.width / 2 - 100, y: 200 - 50, width: 200, height: 100)
                ),
                TutorialStep(
                    title: "最后一步", 
                    description: "引导结束，点击完成按钮退出",
                    frame: CGRect(x: UIScreen.main.bounds.width / 2 - 100, y: 200 - 50, width: 200, height: 100)
                )
            ]
        )
    }
} 