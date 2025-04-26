import SwiftUI

struct ImageCropView: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    
    var isSquare: Bool {
        return image.size.width == image.size.height
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.black)
                            .padding(8)
                    }
                    Spacer()
                    Button(action: {
                        if isSquare {
                            compressImage()
                        } else {
                            showAlert = true
                        }
                    }) {
                        Text("确定")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(8)
                    }
                }
                .padding()
                .background(Color.white)
                
                Spacer()
                
                // 图片预览
                ZStack {
                    Color(uiColor: .systemGray6)
                    
                    // 预览图片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width, geometry.size.height * 0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 正方形裁切框
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(
                            width: min(
                                min(geometry.size.width, geometry.size.height * 0.7),
                                min(image.size.width, image.size.height)
                            ),
                            height: min(
                                min(geometry.size.width, geometry.size.height * 0.7),
                                min(image.size.width, image.size.height)
                            )
                        )
                        .allowsHitTesting(false)
                }
                .frame(height: geometry.size.height * 0.7)
                
                Spacer()
                
                // 底部提示文本
                VStack(spacing: 8) {
                    if isSquare {
                        Text("图片将被压缩为200x200")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("请上传正方形图片")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("当前图片尺寸：\(Int(image.size.width))x\(Int(image.size.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            }
            .background(Color.white)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请上传正方形图片")
            }
        }
    }
    
    private func compressImage() {
        // 创建200x200的位图上下文
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 200, height: 200), true, 1.0)
        
        if let context = UIGraphicsGetCurrentContext() {
            // 填充白色背景
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
            
            // 直接绘制图片（不旋转）
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))
            
            // 获取压缩后的图片
            if let compressedImage = UIGraphicsGetImageFromCurrentImageContext() {
                self.croppedImage = compressedImage
                dismiss()
            }
        }
        
        UIGraphicsEndImageContext()
    }
}

#Preview {
    ImageCropView(
        image: UIImage(systemName: "photo")!,
        croppedImage: .constant(nil)
    )
} 