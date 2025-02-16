import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // 设置中文按钮文本
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        
        // 自定义导航栏按钮文本
        let cancelButton = UIBarButtonItem(title: "取消", style: .plain, target: nil, action: nil)
        picker.navigationItem.leftBarButtonItem = cancelButton
        
        if sourceType == .camera {
            // 自定义拍照界面的按钮文本
            if let cameraOverlayView = picker.cameraOverlayView {
                for subview in cameraOverlayView.subviews {
                    if let button = subview as? UIButton {
                        if button.title(for: .normal) == "Cancel" {
                            button.setTitle("取消", for: .normal)
                        } else if button.title(for: .normal) == "Use Photo" {
                            button.setTitle("使用照片", for: .normal)
                        } else if button.title(for: .normal) == "Retake" {
                            button.setTitle("重拍", for: .normal)
                        }
                    }
                }
            }
        }
        
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
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
} 