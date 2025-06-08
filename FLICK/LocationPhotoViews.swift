import SwiftUI
import PhotosUI
import AVFoundation
import os.log

// MARK: - 性能监测工具
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = Logger(subsystem: "com.flick.app", category: "Performance")
    
    private var imageLoadTimes: [String: CFTimeInterval] = [:]
    private var memorySamples: [Date: Double] = [:]
    private var samplingTimer: Timer?
    
    private init() { }
    
    // 开始记录图片加载时间
    func startImageLoad(id: String) {
        imageLoadTimes[id] = CACurrentMediaTime()
    }
    
    // 结束记录图片加载时间并输出
    func endImageLoad(id: String, type: String) {
        guard let startTime = imageLoadTimes[id] else { return }
        let duration = CACurrentMediaTime() - startTime
        logger.debug("图片加载 [\(type)] \(id): \(String(format: "%.3f", duration))秒")
        imageLoadTimes.removeValue(forKey: id)
    }
    
    // 获取当前内存使用情况
    func currentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // MB
        } else {
            return 0
        }
    }
    
    // 开始定期记录内存使用情况
    func startMemorySampling() {
        stopMemorySampling()
        memorySamples.removeAll()
        
        samplingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let usage = self.currentMemoryUsage()
            self.memorySamples[Date()] = usage
            self.logger.debug("内存使用: \(String(format: "%.1f", usage)) MB")
        }
    }
    
    // 停止内存使用记录
    func stopMemorySampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        
        if !memorySamples.isEmpty {
            let values = memorySamples.values
            let avg = values.reduce(0, +) / Double(values.count)
            let max = values.max() ?? 0
            let min = values.min() ?? 0
            
            logger.debug("内存使用统计: 平均 \(String(format: "%.1f", avg)) MB, 最大 \(String(format: "%.1f", max)) MB, 最小 \(String(format: "%.1f", min)) MB")
        }
    }
    
    // 记录一个性能标记点
    func logPerformanceMark(_ description: String) {
        logger.debug("性能标记: \(description), 内存: \(String(format: "%.1f", self.currentMemoryUsage())) MB")
    }
}

// MARK: - 图片缓存管理器
class ImageCacheManager {
    static let shared = ImageCacheManager()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        // 设置缓存大小限制
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 100 // 100MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算图片内存占用
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - 照片列表视图
struct LocationPhotoList: View {
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    @Binding var location: Location
    let projectColor: Color
    
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingCameraAlert = false
    @State private var cameraErrorMessage = ""
    
    // 批量上传进度
    @State private var isUploading = false
    @State private var uploadProgress: Float = 0.0
    @State private var processedItems = 0
    @State private var totalItems = 0
    
    @State private var isMonitoringPerformance = false
    
    // 按日期分组的照片
    private var photosByDate: [(Date, [LocationPhoto])] {
        let grouped = Dictionary(grouping: location.photos) { photo in
            Calendar.current.startOfDay(for: photo.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // 检查相机是否可用
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    // 检查相机权限并显示相机
    private func checkCameraPermissionAndShow() {
        // 首先检查相机硬件是否可用
        if !isCameraAvailable {
            cameraErrorMessage = "相机不可用或无法访问"
            showingCameraAlert = true
            return
        }
        
        // 检查相机权限状态
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 已授权，可以显示相机
            showingCamera = true
        case .notDetermined:
            // 尚未请求权限，请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.cameraErrorMessage = "需要相机权限才能拍摄照片"
                        self.showingCameraAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // 权限被拒绝或受限
            cameraErrorMessage = "需要相机权限才能拍摄照片，请在设置中允许访问相机"
            showingCameraAlert = true
        @unknown default:
            cameraErrorMessage = "无法访问相机"
            showingCameraAlert = true
        }
    }
    
    var body: some View {
        ZStack {
            // 主内容区域
            if location.photos.isEmpty {
                // 空状态
                ContentUnavailableView {
                    Label("暂无照片", systemImage: "photo.stack")
                } description: {
                    Text("点击下方按钮开始拍摄或选择照片")
                } actions: {
                    HStack(spacing: 20) {
                        Button(action: { checkCameraPermissionAndShow() }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        Button(action: { showingPhotosPicker = true }) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                }
            } else {
                VStack {
                    // 性能监测开关
                    HStack {
                        Spacer()
                        Button {
                            isMonitoringPerformance.toggle()
                            if isMonitoringPerformance {
                                PerformanceMonitor.shared.startMemorySampling()
                                PerformanceMonitor.shared.logPerformanceMark("开始加载照片列表")
                            } else {
                                PerformanceMonitor.shared.stopMemorySampling()
                            }
                        } label: {
                            Label(isMonitoringPerformance ? "停止监测" : "开始监测", 
                                  systemImage: isMonitoringPerformance ? "gauge.with.dots.needle.bottom.50percent" : "gauge")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isMonitoringPerformance ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(photosByDate, id: \.0) { date, photos in
                            Section {
                                VStack(spacing: 16) {
                                    ForEach(photos) { photo in
                                        LazyPhotoView(
                                            photo: photo,
                                            color: projectColor,
                                            project: project,
                                            location: location
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            } header: {
                                DateHeader(date: date, color: projectColor)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                    }
                }
            }
            
            // 批量上传进度条
            if isUploading {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("正在处理照片")
                                .font(.headline)
                            Spacer()
                            Text("\(processedItems)/\(totalItems)")
                                .font(.subheadline)
                        }
                        
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(projectColor)
                        
                        Text("处理大量照片可能需要一些时间，请耐心等待...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding()
                }
            }
            
            // 悬浮添加按钮
            if !location.photos.isEmpty && !isUploading {
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Spacer()
                        Button(action: { checkCameraPermissionAndShow() }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                        }
                        Button(action: { showingPhotosPicker = true }) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                        }
                    }
                    .padding([.trailing, .bottom], 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(projectStore: projectStore, project: project, location: location)
        }
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotos,
            matching: .images
        )
        .alert("相机错误", isPresented: $showingCameraAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(cameraErrorMessage)
        }
        .onChange(of: selectedPhotos) { _, items in
            Task {
                // 显示进度条
                totalItems = items.count
                processedItems = 0
                isUploading = totalItems > 0
                uploadProgress = 0.0
                
                // 批量处理照片
                if totalItems > 0 {
                    // 创建一个临时数组存储处理好的照片，避免多次更新CoreData
                    var processedPhotos: [LocationPhoto] = []
                    
                    for (index, item) in items.enumerated() {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            // 修正图片方向
                            let correctedImage = fixImageOrientation(uiImage)
                            // 调整图片大小，降低内存占用
                            let resizedImage = resizeImage(correctedImage, targetSize: 1200)
                            let photo = LocationPhoto(image: resizedImage)
                            processedPhotos.append(photo)
                            
                            // 更新进度
                            processedItems = index + 1
                            uploadProgress = Float(processedItems) / Float(totalItems)
                            
                            // 每处理10张或者是最后一批时保存到CoreData
                            if processedPhotos.count >= 10 || index == items.count - 1 {
                                // 批量添加到CoreData
                                await projectStore.addPhotos(processedPhotos, to: location, in: project)
                                processedPhotos.removeAll()
                            }
                        }
                    }
                    
                    // 完成上传
                    isUploading = false
                }
                
                selectedPhotos.removeAll()
            }
        }
        .onDisappear {
            // 清理图片缓存
            ImageCacheManager.shared.clear()
            
            // 停止性能监测
            if isMonitoringPerformance {
                PerformanceMonitor.shared.logPerformanceMark("视图消失")
                PerformanceMonitor.shared.stopMemorySampling()
                isMonitoringPerformance = false
            }
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
    
    // 添加图片方向修正方法
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

// MARK: - 懒加载照片视图
struct LazyPhotoView: View {
    let photo: LocationPhoto
    let color: Color
    let project: Project
    let location: Location
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var showingFullImage = false
    
    var body: some View {
        PhotoTimelineCell(
            image: loadedImage ?? UIImage(),
            photo: photo,
            color: color,
            project: project,
            location: location
        )
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // 视图消失时可以释放大图，只保留缓存
            loadedImage = nil
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }
        }

    }
    
    private func loadThumbnail() {
        let photoId = photo.id.uuidString
        let cacheKey = "thumb_\(photoId)"
        
        // 检查缓存
        if let cachedImage = ImageCacheManager.shared.get(forKey: cacheKey) {
            loadedImage = cachedImage
            return
        }
        
        // 图片未缓存，加载中
        isLoading = true
        
        // 记录性能
        PerformanceMonitor.shared.startImageLoad(id: photoId)
        
        // 在后台线程加载缩略图
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnail = photo.thumbnail
            
            // 返回主线程更新UI
            DispatchQueue.main.async {
                loadedImage = thumbnail
                isLoading = false
                
                // 记录加载完成
                PerformanceMonitor.shared.endImageLoad(id: photoId, type: "缩略图")
                
                // 缓存缩略图
                if let thumbnail = thumbnail {
                    ImageCacheManager.shared.set(thumbnail, forKey: cacheKey)
                }
            }
        }
    }
}

// MARK: - 日期头部视图
private struct DateHeader: View {
    let date: Date
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // 保持左侧时间线的空间一致
            Rectangle()
                .fill(.clear)
                .frame(width: 45)
            
            Text(formatDate(date))
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .background(.background)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month().day().weekday())
        } else {
            return date.formatted(.dateTime.year().month().day().weekday())
        }
    }
}

// MARK: - 时间线照片单元格
private struct PhotoTimelineCell: View {
    let image: UIImage
    let photo: LocationPhoto
    let color: Color
    let project: Project
    let location: Location
    @EnvironmentObject var projectStore: ProjectStore
    @State private var note: String
    @State private var showDeleteConfirmation = false
    @State private var showingFullImage = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var isSaving = false
    
    init(image: UIImage, photo: LocationPhoto, color: Color, project: Project, location: Location) {
        self.image = image
        self.photo = photo
        self.color = color
        self.project = project
        self.location = location
        self._note = State(initialValue: photo.note ?? "")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间线
            VStack(spacing: 0) {
                Text(formatTime(photo.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 45)
                
                VStack(spacing: 0) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(height: 260)
            
            // 右侧内容
            VStack(alignment: .leading, spacing: 12) {
                // 照片
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 2)
                        .contentShape(Rectangle()) // 确保整个区域可点击
                        .onTapGesture {
                            showingFullImage = true
                        }
                    
                    // 删除按钮
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .background(Color.white.clipShape(Circle()))
                    }
                    .padding(8)
                }
                
                // 备注输入区域
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    
                    TextField("添加备注...", text: $note)
                        .font(.subheadline)
                        .submitLabel(.done)
                        .onSubmit {
                            // 点击完成时立即保存并取消防抖任务
                            debounceTask?.cancel()
                            Task {
                                isSaving = true
                                await updatePhotoNote(note)
                                isSaving = false
                            }
                        }
                        .onChange(of: note) { _, newValue in
                            // 使用防抖机制，用户停止输入1.5秒后自动保存
                            debounceTask?.cancel()
                            debounceTask = Task {
                                do {
                                    try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒防抖
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            isSaving = true
                                        }
                                        await updatePhotoNote(newValue)
                                        await MainActor.run {
                                            isSaving = false
                                        }
                                    }
                                } catch {
                                    // Task被取消时会抛出异常，这是正常的
                                }
                            }
                        }
                    
                    // 保存状态指示器
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    await deletePhoto()
                }
            }
        } message: {
            Text("确定要删除这张照片吗？此操作无法撤销。")
        }
        .fullScreenCover(isPresented: $showingFullImage) {
            FullScreenImageView(photo: photo, color: color)
        }
        .onDisappear {
            // 视图消失时取消防抖任务并保存最新内容
            debounceTask?.cancel()
            if note != (photo.note ?? "") {
                Task {
                    await updatePhotoNote(note)
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
    
    private func updatePhotoNote(_ newNote: String) async {
        // 避免不必要的保存
        guard newNote != (photo.note ?? "") else { return }
        
        // 创建新的照片对象
        let updatedPhoto = LocationPhoto(
            id: photo.id,
            image: image,
            date: photo.date,
            weather: photo.weather,
            note: newNote.isEmpty ? nil : newNote
        )
        
        // 更新 CoreData
        await projectStore.updatePhoto(updatedPhoto, in: location, project: project)
    }
    
    private func deletePhoto() async {
        // 调用 ProjectStore 的删除照片方法
        await projectStore.deletePhoto(photo, from: location, in: project)
    }
}

// MARK: - 相机视图
struct CameraView: View {
    let projectStore: ProjectStore
    let project: Project
    let location: Location
    @Environment(\.dismiss) private var dismiss
    
    // 添加图片方向修正方法
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
    
    var body: some View {
        ZStack {
            CameraImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        // 修正图片方向
                        let correctedImage = fixImageOrientation(image)
                        // 调整图片大小，降低内存占用
                        let resizedImage = resizeImage(correctedImage, targetSize: 1200)
                        let photo = LocationPhoto(image: resizedImage)
                        Task {
                            await projectStore.addPhotos([photo], to: location, in: project)
                        }
                    }
                    dismiss()
                }
            ))
            .ignoresSafeArea()
            
            // 关闭按钮
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - 相机选择器
private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // 检查相机是否可用
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.delegate = context.coordinator
        } else {
            // 如果相机不可用，在下一个周期自动关闭
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 全屏图片查看
struct FullScreenImageView: View {
    let photo: LocationPhoto
    let color: Color
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var fullImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
            
            if let image = fullImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
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
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                    )
            } else {
                // 显示缩略图（直到原图加载完成）
                if let thumbnail = photo.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .opacity(isLoading ? 0.5 : 1.0)
                }
            }
            
            // 顶部工具栏
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    // 照片日期显示
                    Text(photo.date.formatted(.dateTime.year().month().day().hour().minute()))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                }
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            loadFullImage()
        }
        .statusBar(hidden: true)
        .ignoresSafeArea()
    }
    
    private func loadFullImage() {
        isLoading = true
        
        // 在后台线程加载原图
        DispatchQueue.global(qos: .userInitiated).async {
            // 记录性能
            let photoId = photo.id.uuidString
            PerformanceMonitor.shared.startImageLoad(id: photoId)
            
            let fullImage = photo.image
            
            // 返回主线程更新UI
            DispatchQueue.main.async {
                self.fullImage = fullImage
                isLoading = false
                
                // 记录加载完成
                PerformanceMonitor.shared.endImageLoad(id: photoId, type: "原图")
            }
        }
    }
} 
