import SwiftUI
import AVFoundation
import UIKit

struct RoadbookCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        
        // 设置相机控制
        picker.showsCameraControls = true
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        
        // 不使用编辑模式，直接使用原图
        picker.allowsEditing = false
        
        // 设置相机UI优先级
        picker.modalPresentationStyle = .fullScreen
        picker.modalTransitionStyle = .coverVertical
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 确保相机控件在前台
        if let window = uiViewController.view.window {
            window.makeKeyAndVisible()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: RoadbookCameraView
        
        init(_ parent: RoadbookCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let originalImage = info[.originalImage] as? UIImage {
                // 处理图片方向
                let correctedImage = fixImageOrientation(originalImage)
                
                // 调整图片大小，降低内存占用
                let resizedImage = resizeImage(correctedImage, targetSize: 1200)
                
                parent.capturedImage = resizedImage
            }
            
            // 立即关闭相机视图，返回到上一个页面
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // 用户取消拍照，关闭相机视图
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        // 调整图片大小
        private func resizeImage(_ image: UIImage, targetSize: CGFloat) -> UIImage {
            let size = image.size
            let widthRatio = targetSize / size.width
            let heightRatio = targetSize / size.height
            let ratio = min(widthRatio, heightRatio)
            
            // 如果图片已经小于目标尺寸，直接返回
            if ratio >= 1.0 {
                return image
            }
            
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage ?? image
        }
        
        // 修正图片方向
        private func fixImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
} 