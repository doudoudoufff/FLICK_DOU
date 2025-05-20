import SwiftUI

// 费用类型按钮
struct ExpenseTypeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(isSelected ? .orange : .orange.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// 组别按钮
struct GroupButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(isSelected ? .blue : .blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// 图片预览组件
struct ImageViewer: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale *= delta
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    onDismiss()
                }
            }
        }
    }
} 