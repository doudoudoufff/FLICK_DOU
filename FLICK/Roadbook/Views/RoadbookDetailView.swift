import SwiftUI
import PhotosUI

struct RoadbookDetailView: View {
    @ObservedObject private var roadbookManager = RoadbookManager.shared
    @State private var roadbook: Roadbook
    @State private var showingAddPhoto = false
    @State private var showingPhotoDetail = false
    @State private var selectedPhoto: RoadbookPhoto?
    @State private var selectedPhotoIndex = 0
    @State private var showingPreview = false
    @State private var generatedImage: UIImage?
    @State private var isGeneratingImage = false
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 新增状态变量
    @State private var selectedImages: [UIImage] = []
    @State private var isAddingPhotos = false
    @State private var processedPhotos = 0
    @State private var totalPhotos = 0
    @State private var showingDeleteConfirmation = false
    @State private var photoToDeleteId: UUID? = nil
    @State private var showingPhotoSort = false
    @State private var showingPhotoEdit = false
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    
    // 生成长图进度
    @State private var generatingProgress: Float = 0
    
    // 自定义文本输入
    @State private var showingCustomTextInput = false
    @State private var customHeaderText = ""
    
    init(roadbook: Roadbook) {
        _roadbook = State(initialValue: roadbook)
    }
    
    var body: some View {
        ZStack {
            RoadbookDetailContent(
                roadbook: $roadbook,
                roadbookManager: roadbookManager,
                selectedPhoto: $selectedPhoto,
                selectedPhotoIndex: $selectedPhotoIndex,
                selectedImages: $selectedImages,
                generatedImage: $generatedImage,
                isGeneratingImage: $isGeneratingImage,
                isAddingPhotos: $isAddingPhotos,
                processedPhotos: $processedPhotos,
                totalPhotos: $totalPhotos,
                showingAddPhoto: $showingAddPhoto,
                showingPhotoDetail: $showingPhotoDetail,
                showingPhotoEdit: $showingPhotoEdit,
                showingPhotoSort: $showingPhotoSort,
                showingPreview: $showingPreview,
                showingShareSheet: $showingShareSheet,
                showingAlert: $showingAlert,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                photoToDeleteId: $photoToDeleteId,
                alertMessage: $alertMessage,
                generatingProgress: $generatingProgress,
                showingCustomTextInput: $showingCustomTextInput,
                customHeaderText: $customHeaderText,
                addSelectedPhotosToRoadbook: addSelectedPhotosToRoadbook,
                deletePhotoFromRoadbook: deletePhotoFromRoadbook,
                generateRoadbookImage: generateRoadbookImage
            )
            
            // 浮动按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // 胶囊形状的按钮组
                    HStack(spacing: 0) {
                        // 拍照按钮
                        Button {
                            showingCamera = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                Text("拍照")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                        }
                        
                        // 分隔线
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1, height: 24)
                        
                        // 相册按钮
                        Button {
                            showingAddPhoto = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                Text("相册")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                        }
                    }
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingCamera) {
            RoadbookCameraView(capturedImage: $capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if let image = capturedImage {
                        // 处理拍摄的照片，添加到路书
                        selectedImages = [image]
                        addSelectedPhotosToRoadbook()
                        capturedImage = nil
                    }
                }
        }
        .sheet(isPresented: $showingAddPhoto) {
            RoadbookPhotoPickerView(selectedImages: $selectedImages, allowMultiple: true)
                .onDisappear {
                    if !selectedImages.isEmpty {
                        addSelectedPhotosToRoadbook()
                    }
                }
        }
    }
    
    // MARK: - 辅助方法
    
    // 添加选中照片到路书
    private func addSelectedPhotosToRoadbook() {
        guard !selectedImages.isEmpty else { 
            print("没有选择任何照片，不执行添加操作")
            return 
        }
        
        print("开始添加 \(selectedImages.count) 张照片到路书")
        isAddingPhotos = true
        totalPhotos = selectedImages.count
        processedPhotos = 0
        
        // 使用DispatchGroup来跟踪所有照片的处理
        let group = DispatchGroup()
        
        // 创建一个临时数组存储成功添加的照片ID
        var addedPhotoIds: [UUID] = []
        
        for (index, image) in selectedImages.enumerated() {
            group.enter()
            
            // 创建RoadbookPhoto对象
            let photo = RoadbookPhoto(
                image: image,
                note: "",
                orderIndex: roadbook.photos.count + index
            )
            
            addedPhotoIds.append(photo.id)
            print("准备添加照片 \(index+1)/\(selectedImages.count)，照片ID: \(photo.id)，图片尺寸: \(image.size)")
            
            // 添加到路书
            roadbookManager.addPhoto(photo, to: roadbook.id) { result in
                defer { group.leave() }
                
                DispatchQueue.main.async {
                    self.processedPhotos += 1
                    
                    switch result {
                    case .success(let updatedRoadbook):
                        // 每次添加照片后立即更新路书状态
                        print("照片添加成功，当前路书照片数量：\(updatedRoadbook.photos.count)")
                        self.roadbook = updatedRoadbook
                    case .failure(let error):
                        print("添加照片失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 所有照片处理完成后
        group.notify(queue: .main) {
            print("所有照片处理完成，清理状态")
            self.selectedImages = []
            self.isAddingPhotos = false
            
            // 强制重新加载路书数据
            print("重新加载路书数据")
            self.roadbookManager.loadRoadbooks()
            
            // 延迟一小段时间后再次更新当前路书
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let updatedRoadbook = self.roadbookManager.roadbooks.first(where: { $0.id == self.roadbook.id }) {
                    print("最终更新路书，照片数量：\(updatedRoadbook.photos.count)")
                    print("添加的照片ID: \(addedPhotoIds)")
                    print("路书中的照片ID: \(updatedRoadbook.photos.map { $0.id })")
                    self.roadbook = updatedRoadbook
                } else {
                    print("无法找到更新后的路书")
                }
            }
        }
    }
    
    // 从路书中删除照片
    private func deletePhotoFromRoadbook(photoId: UUID) {
        roadbookManager.deletePhoto(withId: photoId, from: roadbook.id) { result in
            switch result {
            case .success(let updatedRoadbook):
                DispatchQueue.main.async {
                    self.roadbook = updatedRoadbook
                }
            case .failure(let error):
                print("删除照片失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 生成路书长图
    private func generateRoadbookImage(andShare: Bool = false) {
        guard !roadbook.photos.isEmpty else {
            alertMessage = "路书中没有照片，无法生成长图"
            showingAlert = true
            return
        }
        
        // 显示自定义文本输入对话框
        showingCustomTextInput = true
    }
}

// 将主要内容提取到单独的结构体中，避免类型推断过于复杂
struct RoadbookDetailContent: View {
    @Binding var roadbook: Roadbook
    var roadbookManager: RoadbookManager
    @Binding var selectedPhoto: RoadbookPhoto?
    @Binding var selectedPhotoIndex: Int
    @Binding var selectedImages: [UIImage]
    @Binding var generatedImage: UIImage?
    @Binding var isGeneratingImage: Bool
    @Binding var isAddingPhotos: Bool
    @Binding var processedPhotos: Int
    @Binding var totalPhotos: Int
    @Binding var showingAddPhoto: Bool
    @Binding var showingPhotoDetail: Bool
    @Binding var showingPhotoEdit: Bool
    @Binding var showingPhotoSort: Bool
    @Binding var showingPreview: Bool
    @Binding var showingShareSheet: Bool
    @Binding var showingAlert: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var photoToDeleteId: UUID?
    @Binding var alertMessage: String
    
    // 生成长图进度
    @Binding var generatingProgress: Float
    
    // 自定义文本输入
    @Binding var showingCustomTextInput: Bool
    @Binding var customHeaderText: String
    
    var addSelectedPhotosToRoadbook: () -> Void
    var deletePhotoFromRoadbook: (UUID) -> Void
    var generateRoadbookImage: (Bool) -> Void
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 路书信息
                roadbookInfoSection
                
                // 操作按钮
                actionButtonsSection
                
                // 照片列表
                if roadbook.photos.isEmpty {
                    emptyStateView
                } else {
                    photosGridSection
                }
                
                // 加载指示器
                if isGeneratingImage {
                    loadingView(message: "生成长图中...")
                }
                
                // 照片添加进度指示器
                if isAddingPhotos {
                    photoAddingProgressView
                }
            }
        }
        .navigationTitle("路书详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("路书详情视图出现，刷新路书数据")
            roadbookManager.getRoadbook(id: roadbook.id) { result in
                if case .success(let updatedRoadbook) = result {
                    print("成功刷新路书数据，照片数量：\(updatedRoadbook.photos.count)")
                    self.roadbook = updatedRoadbook
                }
            }
        }
        .sheet(isPresented: $showingPhotoDetail) {
            photoDetailSheet
        }
        .sheet(isPresented: $showingPreview) {
            previewSheet
        }
        .sheet(isPresented: $showingShareSheet) {
            // 分享表单
            if let image = generatedImage {
                RoadbookShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showingPhotoSort, onDismiss: {
            print("照片排序视图已关闭，重新加载路书数据")
            // 重新加载路书数据
            roadbookManager.loadRoadbooks()
            
            // 查找并更新当前路书
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let updatedRoadbook = roadbookManager.roadbooks.first(where: { $0.id == roadbook.id }) {
                    print("照片排序后更新路书，照片数量：\(updatedRoadbook.photos.count)")
                    print("照片排序：\(updatedRoadbook.photos.map { $0.orderIndex })")
                    self.roadbook = updatedRoadbook
                } else {
                    print("照片排序后无法找到更新的路书")
                }
            }
        }) {
            // 照片排序视图
            RoadbookPhotoSortView(roadbook: roadbook)
        }
        .sheet(isPresented: $showingPhotoEdit) {
            photoEditSheet
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("提示"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let photoId = photoToDeleteId {
                    deletePhotoFromRoadbook(photoId)
                }
            }
        } message: {
            Text("确定要删除这张照片吗？此操作无法撤销。")
        }
        // 自定义文本输入对话框
        .sheet(isPresented: $showingCustomTextInput) {
            customTextInputSheet
        }
    }
    
    // MARK: - 子视图
    
    // 路书信息区域
    private var roadbookInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 路书图标
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(roadbook.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(roadbook.formattedCreationDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let projectId = roadbook.projectId,
                           let project = roadbookManager.getProject(id: projectId) {
                            Divider()
                                .frame(height: 12)
                            
                            Image(systemName: "folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(project.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 编辑按钮
                Button {
                    // 编辑路书功能（后续实现）
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.blue)
                }
            }
            
            if !roadbook.notes.isEmpty {
                Text(roadbook.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // 操作按钮区域
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // 排序按钮
            Button {
                showingPhotoSort = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("调整顺序")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(roadbook.photos.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(roadbook.photos.isEmpty ? .gray : .white)
                .cornerRadius(20)
            }
            .disabled(roadbook.photos.isEmpty)
            
            Spacer()
            
            // 生成长图按钮
            Button {
                generateRoadbookImage(false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("生成长图")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(roadbook.photos.isEmpty ? Color.gray.opacity(0.3) : Color.green)
                .foregroundColor(roadbook.photos.isEmpty ? .gray : .white)
                .cornerRadius(20)
            }
            .disabled(roadbook.photos.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("没有照片")
                .font(.headline)
            
            Text("使用右下角的按钮添加照片")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 照片网格区域
    private var photosGridSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(Array(roadbook.photos.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated()), id: \.element.id) { index, photo in
                    PhotoGridItemView(
                        photo: photo,
                        index: index,
                        onSelect: {
                            selectedPhoto = photo
                            selectedPhotoIndex = index
                            showingPhotoDetail = true
                        },
                        onDelete: {
                            photoToDeleteId = photo.id
                            showingDeleteConfirmation = true
                        },
                        onEdit: {
                            selectedPhoto = photo
                            selectedPhotoIndex = index
                            showingPhotoEdit = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }
    
    // 加载视图
    private func loadingView(message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView(message)
            
            // 显示进度条
            ProgressView(value: generatingProgress, total: 1.0)
                .frame(width: 200)
                .padding(.top, 4)
            
            // 显示百分比
            Text("\(Int(generatingProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    // 照片添加进度视图
    private var photoAddingProgressView: some View {
        VStack {
            ProgressView("正在添加照片...")
                .padding(.bottom, 8)
            
            Text("\(processedPhotos)/\(totalPhotos)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    // 自定义文本输入Sheet
    private var customTextInputSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("路书信息")) {
                    HStack {
                        Text("路书名称")
                        Spacer()
                        Text(roadbook.name)
                            .foregroundColor(.secondary)
                    }
                    
                    if let projectId = roadbook.projectId, 
                       let project = roadbookManager.getProject(id: projectId) {
                        HStack {
                            Text("关联项目")
                            Spacer()
                            Text(project.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("添加自定义文本")) {
                    TextField("输入自定义文本（可选）", text: $customHeaderText)
                    Text("此文本将显示在长图顶部")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("长图信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showingCustomTextInput = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("生成") {
                        showingCustomTextInput = false
                        startGeneratingImage()
                    }
                }
            }
        }
    }
    
    // 开始生成长图
    private func startGeneratingImage() {
        isGeneratingImage = true
        generatingProgress = 0
        
        // 获取项目信息
        var projectName = ""
        if let projectId = roadbook.projectId, 
           let project = roadbookManager.getProject(id: projectId) {
            projectName = project.name
        }
        
        // 创建头部信息
        let headerInfo = RoadbookHeaderInfo(
            title: roadbook.name,
            projectName: projectName,
            customText: customHeaderText,
            date: Date()
        )
        
        roadbookManager.generateRoadbookImage(for: roadbook.id, headerInfo: headerInfo, progressHandler: { progress in
            self.generatingProgress = progress
        }) { result in
            isGeneratingImage = false
            
            switch result {
            case .success(let image):
                generatedImage = image
                showingPreview = true
            case .failure(let error):
                alertMessage = "生成长图失败: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    // 照片详情Sheet
    private var photoDetailSheet: some View {
        Group {
            if let photo = selectedPhoto {
                NavigationStack {
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        
                        // 照片查看器
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                
                                // 显示照片
                                if let displayImage = photo.displayImage {
                                    Image(uiImage: displayImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: geometry.size.width)
                                }
                                
                                Spacer()
                                
                                // 照片信息
                                if !photo.note.isEmpty {
                                    Text(photo.note)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground).opacity(0.8))
                                }
                            }
                        }
                    }
                    .navigationTitle("照片详情")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button {
                                    // 显示编辑视图
                                    showingPhotoDetail = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showingPhotoEdit = true
                                    }
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    photoToDeleteId = photo.id
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                    .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation) {
                        Button("删除照片", role: .destructive) {
                            if let photoId = photoToDeleteId {
                                deletePhotoFromRoadbook(photoId)
                                showingPhotoDetail = false
                            }
                        }
                    } message: {
                        Text("确定要删除这张照片吗？此操作无法撤销。")
                    }
                }
            }
        }
    }
    
    // 预览Sheet
    private var previewSheet: some View {
        Group {
            if let image = generatedImage {
                NavigationView {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        
                        ScrollView {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    }
                    .navigationTitle("路书预览")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 照片编辑Sheet
    private var photoEditSheet: some View {
        Group {
            if let photo = selectedPhoto {
                RoadbookPhotoEditView(
                    photo: photo,
                    roadbookId: roadbook.id,
                    photoIndex: selectedPhotoIndex
                )
                .onDisappear {
                    // 编辑完成后刷新路书数据
                    print("照片编辑视图已关闭，强制刷新路书数据")
                    
                    // 先重新加载所有路书
                    roadbookManager.loadRoadbooks()
                    
                    // 然后特别获取当前路书的最新数据
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        roadbookManager.getRoadbook(id: roadbook.id) { result in
                            if case .success(let updatedRoadbook) = result {
                                print("成功获取更新后的路书，照片数量：\(updatedRoadbook.photos.count)")
                                
                                // 检查缩略图
                                for photo in updatedRoadbook.photos {
                                    if let thumbnail = photo.thumbnail {
                                        print("照片 \(photo.id) 有缩略图，尺寸: \(thumbnail.size)")
                                    } else {
                                        print("警告：照片 \(photo.id) 没有缩略图")
                                    }
                                }
                                
                                self.roadbook = updatedRoadbook
                            } else {
                                print("获取更新后的路书失败")
                            }
                        }
                    }
                }
            }
        }
    }
}

// 照片网格项视图
struct PhotoGridItemView: View {
    let photo: RoadbookPhoto
    let index: Int
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    // 照片
                    ZStack(alignment: .bottomLeading) {
                        if let thumbnail = photo.thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // 序号标签
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(8)
                    }
                    
                    // 备注（如果有）
                    if !photo.note.isEmpty {
                        Text(photo.note)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            }
            
            // 操作按钮
            Menu {
                Button(action: onEdit) {
                    Label("编辑", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(8)
            }
        }
    }
}

// 路书分享表单
struct RoadbookShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 
 