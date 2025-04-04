import SwiftUI
import PhotosUI
import AVFoundation

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
                    Text("点击添加按钮开始拍摄或选择照片")
                } actions: {
                    Button(action: { showingActionSheet = true }) {
                        Text("添加照片")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(projectColor)
                            .clipShape(Capsule())
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(photosByDate, id: \.0) { date, photos in
                            Section {
                                VStack(spacing: 16) {
                                    ForEach(photos) { photo in
                                        if let image = photo.image {
                                            PhotoTimelineCell(
                                                image: image,
                                                photo: photo,
                                                color: projectColor,
                                                project: project,
                                                location: location
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } header: {
                                DateHeader(date: date, color: projectColor)
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            
            // 悬浮添加按钮
            if !location.photos.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingActionSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(projectColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding([.trailing, .bottom], 16)
                    }
                }
            }
        }
        .confirmationDialog("添加照片", isPresented: $showingActionSheet) {
            Button("拍摄照片") { 
                checkCameraPermissionAndShow()
            }
            Button("从相册选择") { showingPhotosPicker = true }
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
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let photo = LocationPhoto(image: image)
                        await projectStore.addPhotos([photo], to: location, in: project)
                    }
                }
                selectedPhotos.removeAll()
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
                            // 当用户点击键盘上的完成按钮时保存
                            Task {
                                await updatePhotoNote(note)
                            }
                        }
                        .onChange(of: note) { _, newValue in
                            // 当文本变化时延迟保存，避免频繁更新
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
                                await updatePhotoNote(newValue)
                            }
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
    }
    
    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
    
    private func updatePhotoNote(_ newNote: String) async {
        // 创建新的照片对象
        let updatedPhoto = LocationPhoto(
            id: photo.id,
            image: image,
            date: photo.date,
            weather: photo.weather,
            note: newNote
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
    
    var body: some View {
        ZStack {
            CameraImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage {
                        let photo = LocationPhoto(image: image)
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
