import SwiftUI

struct RoadbookView: View {
    @StateObject private var roadbookManager = RoadbookManager.shared
    @State private var showingAddRoadbook = false
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var newRoadbookName = ""
    @State private var selectedProjectId: UUID? = nil
    @State private var navigateToPhotoEdit = false
    @State private var createdRoadbook: Roadbook?
    @State private var createdPhoto: RoadbookPhoto?
    @State private var photoEditId = UUID() // 用于强制刷新编辑视图
    @EnvironmentObject private var projectStore: ProjectStore
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部标题栏和操作按钮
                HStack(spacing: 16) {
                    Text("路书")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // 添加按钮 - 使用胶囊样式
                    Button {
                        showingAddRoadbook = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("新建路书")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                if roadbookManager.isLoading {
                    // 加载中状态
                    ProgressView("加载中...")
                        .padding()
                } else if let errorMessage = roadbookManager.errorMessage {
                    // 错误状态
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("加载失败")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("重试") {
                            roadbookManager.loadRoadbooks()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if roadbookManager.roadbooks.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "map")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text("还没有创建路书")
                            .font(.headline)
                        
                        Text("路书可以帮助剧组在陌生场地快速找到拍摄位置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingAddRoadbook = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("创建第一个路书")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 路书列表 - 改进设计
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(roadbookManager.roadbooks) { roadbook in
                                NavigationLink(destination: RoadbookDetailView(roadbook: roadbook)) {
                                    RoadbookCard(roadbook: roadbook)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteRoadbook(roadbook)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            
            // 导航链接到照片编辑页面
            NavigationLink(
                destination: Group {
                    if let roadbook = createdRoadbook, let photo = createdPhoto {
                        RoadbookPhotoEditView(
                            photo: photo,
                            roadbookId: roadbook.id,
                            photoIndex: roadbook.photos.count - 1, // 使用最新的索引
                            onContinueTakingPhoto: {
                                // 继续拍照
                                continueCapturing()
                            }
                        )
                        .id(photoEditId) // 添加 ID 以强制视图刷新
                    }
                },
                isActive: $navigateToPhotoEdit
            ) {
                EmptyView()
            }
        }
        .navigationTitle("路书")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddRoadbook) {
            // 添加路书表单
            NavigationView {
                Form {
                    Section(header: Text("路书信息")) {
                        TextField("路书名称", text: $newRoadbookName)
                        
                        // 项目选择
                        Picker("关联项目", selection: $selectedProjectId) {
                            Text("不关联项目").tag(nil as UUID?)
                            ForEach(projectStore.projects) { project in
                                Text(project.name).tag(project.id as UUID?)
                            }
                        }
                    }
                    
                    Section {
                        Button("开始拍照") {
                            // 关闭当前表单，打开相机
                            showingAddRoadbook = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingCamera = true
                            }
                        }
                        .disabled(newRoadbookName.isEmpty)
                    }
                }
                .navigationTitle("新建路书")
                .navigationBarItems(
                    trailing: Button("取消") {
                        showingAddRoadbook = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingCamera) {
            RoadbookCameraView(capturedImage: $capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if let image = capturedImage {
                        if createdRoadbook == nil {
                            // 第一次拍照，创建新路书并添加照片
                            createNewRoadbookWithPhoto(image: image)
                        } else {
                            // 继续拍照，添加照片到现有路书
                            addPhotoToRoadbook(image: image)
                        }
                    }
                }
        }
        .onAppear {
            // 加载路书数据
            roadbookManager.loadRoadbooks()
        }
    }
    
    // 创建新路书并添加照片
    private func createNewRoadbookWithPhoto(image: UIImage) {
        guard !newRoadbookName.isEmpty else { return }
        
        roadbookManager.createRoadbookWithPhoto(name: newRoadbookName, image: image, projectId: selectedProjectId) { result in
            switch result {
            case .success(let (roadbook, photo)):
                // 创建成功，保存路书和照片
                createdRoadbook = roadbook
                createdPhoto = photo
                
                // 重置表单
                newRoadbookName = ""
                selectedProjectId = nil
                
                // 生成新的 ID 以强制刷新编辑视图
                photoEditId = UUID()
                
                // 导航到照片编辑页面
                navigateToPhotoEdit = true
                
            case .failure(let error):
                // 处理错误
                print("创建路书失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 继续拍照
    private func continueCapturing() {
        // 关闭当前编辑页面，打开相机
        navigateToPhotoEdit = false
        capturedImage = nil
        
        // 延迟一小段时间再打开相机，确保之前的视图和UI完全消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showingCamera = true
        }
    }
    
    // 添加照片到现有路书
    private func addPhotoToRoadbook(image: UIImage) {
        guard let roadbook = createdRoadbook else { return }
        
        // 创建新照片
        let newPhoto = RoadbookPhoto(
            image: image,
            note: "",
            orderIndex: roadbook.photos.count
        )
        
        // 添加照片到路书
        roadbookManager.addPhoto(newPhoto, to: roadbook.id) { result in
            switch result {
            case .success(let updatedRoadbook):
                // 更新路书
                createdRoadbook = updatedRoadbook
                
                // 获取新添加的照片
                if let addedPhoto = updatedRoadbook.photos.last {
                    createdPhoto = addedPhoto
                    
                    // 生成新的 ID 以强制刷新编辑视图
                    photoEditId = UUID()
                    
                    // 导航到照片编辑页面
                    navigateToPhotoEdit = true
                }
                
            case .failure(let error):
                print("添加照片失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 删除路书
    private func deleteRoadbook(_ roadbook: Roadbook) {
        roadbookManager.deleteRoadbook(with: roadbook.id) { result in
            switch result {
            case .success():
                // 删除成功，不需要额外操作，roadbookManager会更新roadbooks数组
                break
            case .failure(let error):
                // 处理错误
                print("删除路书失败: \(error.localizedDescription)")
            }
        }
    }
}

// 路书卡片视图 - 替换原来的RoadbookRow
struct RoadbookCard: View {
    let roadbook: Roadbook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roadbook.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("创建于 \(roadbook.formattedCreationDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 照片数量指示器
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.blue)
                    Text("\(roadbook.photoCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 如果有照片，显示照片预览
            if roadbook.photos.isEmpty {
                // 没有照片时的占位符
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无照片")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                // 照片预览
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(roadbook.photos.sorted(by: { $0.orderIndex < $1.orderIndex }).prefix(5).enumerated()), 
                               id: \.element.id) { index, photo in
                            if let thumbnail = photo.thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 90)
                                    .cornerRadius(8)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(4)
                                            .background(Color.black.opacity(0.6))
                                            .foregroundColor(.white)
                                            .cornerRadius(4),
                                        alignment: .topLeading
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 90)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        
                        // 如果照片数量超过5张，显示"更多"指示器
                        if roadbook.photos.count > 5 {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 80, height: 90)
                                    .cornerRadius(8)
                                
                                VStack(spacing: 4) {
                                    Image(systemName: "ellipsis")
                                        .font(.title3)
                                    Text("更多\(roadbook.photos.count - 5)张")
                                        .font(.caption)
                                }
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct RoadbookView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RoadbookView()
                .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 