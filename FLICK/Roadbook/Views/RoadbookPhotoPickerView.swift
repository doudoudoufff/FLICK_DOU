import SwiftUI
import PhotosUI

struct RoadbookPhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var allowMultiple: Bool = true
    @State private var isLoading: Bool = false
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        print("创建照片选择器")
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = allowMultiple ? 0 : 1 // 0表示不限制选择数量
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: RoadbookPhotoPickerView
        
        init(_ parent: RoadbookPhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("照片选择完成，选择了 \(results.count) 张照片")
            
            guard !results.isEmpty else { 
                print("没有选择任何照片")
                picker.dismiss(animated: true)
                return 
            }
            
            // 显示加载状态
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            
            // 创建一个临时数组来存储加载的图片
            var loadedImages: [UIImage] = []
            let group = DispatchGroup()
            
            for (index, result) in results.enumerated() {
                group.enter()
                print("开始加载第 \(index+1) 张照片")
                
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (object, error) in
                    guard let self = self else { 
                        group.leave()
                        return 
                    }
                    
                    defer { 
                        group.leave() 
                        print("第 \(index+1) 张照片加载完成")
                    }
                    
                    if let error = error {
                        print("照片加载失败: \(error.localizedDescription)")
                        return
                    }
                    
                    if let image = object as? UIImage {
                        print("照片加载成功，尺寸: \(image.size)")
                        // 修正图片方向
                        let correctedImage = self.fixImageOrientation(image)
                        // 调整图片大小，降低内存占用
                        let resizedImage = self.resizeImage(correctedImage, targetSize: 1200)
                        
                        DispatchQueue.main.async {
                            loadedImages.append(resizedImage)
                        }
                    } else {
                        print("照片加载失败：无法转换为UIImage")
                    }
                }
            }
            
            // 当所有图片加载完成后
            group.notify(queue: .main) {
                print("所有照片加载完成，共 \(loadedImages.count) 张")
                self.parent.selectedImages = loadedImages
                self.parent.isLoading = false
                
                // 确保在主线程上关闭选择器
                picker.dismiss(animated: true)
            }
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