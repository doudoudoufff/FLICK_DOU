import SwiftUI
import CoreData

// 堪景快速拍照功能组件
struct ScoutingCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var currentSheetType: SheetType? = nil
    @State private var scoutingImage: UIImage? = nil
    @State private var newProjectName: String = ""
    @State private var showNewProjectField = false

    // 用于区分当前显示的Sheet类型
    enum SheetType: Identifiable {
        case camera
        case scoutingArchive(UIImage)
        
        var id: Int {
            switch self {
            case .camera: return 1
            case .scoutingArchive: return 2
            }
        }
    }
    
    var body: some View {
        FeatureCardButton(icon: "camera.fill", title: "堪景") {
            print("打开相机")
            currentSheetType = .camera
        }
        .sheet(item: $currentSheetType) { sheetType in
            switch sheetType {
            case .camera:
                // 相机界面
                ImagePicker(image: $scoutingImage, sourceType: .camera)
                    .onDisappear {
                        if let image = scoutingImage {
                            print("照片获取成功，尺寸: \(image.size.width)x\(image.size.height)")
                            currentSheetType = .scoutingArchive(image)
                        } else {
                            currentSheetType = nil
                        }
                    }
                    .ignoresSafeArea()  // 确保相机可以全屏显示
            case .scoutingArchive(let image):
                // 照片归档界面
                NavigationStack {
                    ScoutingArchiveSheet(image: image, onComplete: {
                        print("归档完成")
                        scoutingImage = nil
                        currentSheetType = nil
                    })
                    .environmentObject(projectStore)
                }
                .onAppear {
                    print("ScoutingArchiveSheet 出现，项目数量: \(projectStore.projects.count)")
                }
            }
        }
    }
}

// 拍照后归档弹窗
struct ScoutingArchiveSheet: View {
    let image: UIImage
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var selectedProject: Project?
    @State private var selectedLocation: Location?
    @State private var newLocationName: String = ""
    @State private var newProjectName: String = ""
    @State private var showNewProjectField = false
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var animateImage = false
    @State private var showForm = false
    
    var accentColor: Color {
        selectedProject?.color ?? .blue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 照片预览
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(alignment: .bottomTrailing) {
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(12)
                    }
                    .scaleEffect(animateImage ? 1 : 0.95)
                    .opacity(animateImage ? 1 : 0)
                
                // 项目和场景选择
                VStack(spacing: 16) {
                    // 项目选择
                    VStack(alignment: .leading, spacing: 8) {
                        Label("项目", systemImage: "folder.fill")
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        if projectStore.projects.isEmpty {
                            // 没有项目时显示创建提示
                            VStack(alignment: .leading, spacing: 12) {
                                Text("暂无项目，请创建")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                                
                                // 快速创建项目
                                HStack {
                                    TextField("创建新项目", text: $newProjectName)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    
                                    Button {
                                        if !newProjectName.isEmpty {
                                            let newProject = Project(name: newProjectName)
                                            projectStore.addProject(newProject)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                selectedProject = newProject
                                                newProjectName = ""
                                                projectStore.loadProjects()
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(newProjectName.isEmpty ? .gray : .blue)
                                            .font(.system(size: 22))
                                    }
                                    .disabled(newProjectName.isEmpty)
                                }
                            }
                        } else {
                            // 有项目时显示项目列表
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(projectStore.projects) { project in
                                        Button(action: {
                                            selectedProject = project
                                            selectedLocation = nil
                                        }) {
                                            Text(project.name)
                                                .font(.system(size: 14))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedProject?.id == project.id ? project.color : Color(.systemGray5))
                                                .foregroundColor(selectedProject?.id == project.id ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                    // 新建按钮
                                    Button(action: {
                                        showNewProjectField = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("新建")
                                                .font(.system(size: 14))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(16)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            // 新建输入框
                            if showNewProjectField {
                                HStack {
                                    TextField("创建新项目", text: $newProjectName)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    Button {
                                        if !newProjectName.isEmpty {
                                            let newProject = Project(name: newProjectName)
                                            projectStore.addProject(newProject)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                selectedProject = newProject
                                                newProjectName = ""
                                                showNewProjectField = false
                                                projectStore.loadProjects()
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(newProjectName.isEmpty ? .gray : .blue)
                                            .font(.system(size: 22))
                                    }
                                    .disabled(newProjectName.isEmpty)
                                    // 取消按钮
                                    Button {
                                        newProjectName = ""
                                        showNewProjectField = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.gray)
                                            .font(.system(size: 22))
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 场景选择
                    if let project = selectedProject {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("场景", systemImage: "mappin.circle.fill")
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            if project.locations.isEmpty {
                                Text("暂无场景，请创建")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(project.locations) { location in
                                            Button(action: {
                                                selectedLocation = location
                                            }) {
                                                Text(location.name)
                                                    .font(.system(size: 14))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(selectedLocation?.id == location.id ? accentColor : Color(.systemGray5))
                                                    .foregroundColor(selectedLocation?.id == location.id ? .white : .primary)
                                                    .cornerRadius(16)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            // 创建新场景
                            HStack {
                                TextField("创建新场景", text: $newLocationName)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                Button {
                                    if !newLocationName.isEmpty {
                                        // 创建带有默认地址的新场景
                                        let newLoc = Location(
                                            name: newLocationName,
                                            address: "待添加地址" // 提供一个默认地址
                                        )
                                        
                                        // 使用ProjectStore的addLocation方法添加场景
                                        projectStore.addLocation(newLoc, to: project)
                                        
                                        // 等待UI更新
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            // 设置为当前选中的场景
                                            selectedLocation = newLoc
                                            // 清空输入框
                                            newLocationName = ""
                                            
                                            // 重载项目数据
                                            projectStore.loadProjects()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(
                                            newLocationName.isEmpty ? .gray : accentColor
                                        )
                                        .font(.system(size: 22))
                                }
                                .disabled(newLocationName.isEmpty)
                            }
                        }
                        
                        Divider()
                    }
                    
                    FormRowView(label: "备注", icon: "text.bubble.fill") {
                        TextField("", text: $note, prompt: Text("可选").foregroundColor(.secondary))
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .opacity(showForm ? 1 : 0)
                .offset(y: showForm ? 0 : 20)
                
                // 保存按钮
                Button(action: saveScoutingPhoto) {
                    ZStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("保存到相册")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .buttonBorderShape(.capsule)
                .padding(.top, 8)
                .disabled(selectedProject == nil || selectedLocation == nil || isSaving)
                .opacity(showForm ? 1 : 0)
                .offset(y: showForm ? 0 : 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("堪景归档")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss(); onComplete() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .preferredColorScheme(.light) // 强制使用浅色模式
        .onAppear {
            // 设置最近使用的项目和场景
            selectMostRecentProject()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateImage = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showForm = true
                }
            }
        }
    }
    
    private func selectMostRecentProject() {
        // 如果有项目，默认选择第一个（最近添加的）
        if !projectStore.projects.isEmpty {
            selectedProject = projectStore.projects.first
            
            // 如果选中的项目有场景，默认选择第一个
            if let project = selectedProject, !project.locations.isEmpty {
                selectedLocation = project.locations.first
            }
        }
    }
    
    func saveScoutingPhoto() {
        guard let project = selectedProject, let location = selectedLocation else { return }
        
        print("===== 开始保存照片 =====")
        print("项目: \(project.name) (ID: \(project.id))")
        print("场景: \(location.name) (ID: \(location.id))")
        print("照片大小: \(image.size.width)x\(image.size.height)")
        print("备注内容: \(note.isEmpty ? "无" : note)")
        
        withAnimation {
            isSaving = true
        }
        
        // 创建照片对象
        let photo = LocationPhoto(id: UUID(), image: image, note: note)
        print("已创建照片对象 (ID: \(photo.id), 数据大小: \(photo.imageData.count) 字节)")
        
        Task {
            do {
                // 保存到CoreData - 不要在这里手动更新内存数据，防止重复添加
                // 让addPhotoToLocationAsync完成所有工作，避免双重添加
                try await addPhotoToLocationAsync(photo, location: location, in: project)
                
                // 通知UI已完成操作
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        isSaving = false
                    }
                    
                    // 强制重新加载项目数据，确保UI更新
                    self.projectStore.loadProjects()
                    
                    // 关闭窗口
                    dismiss()
                    onComplete()
                }
            } catch {
                print("❌ 添加照片过程中出错: \(error)")
                
                DispatchQueue.main.async {
                    withAnimation {
                        isSaving = false
                    }
                    dismiss()
                    onComplete()
                }
            }
        }
    }
    
    // 异步添加照片到场景的方法
    func addPhotoToLocationAsync(_ photo: LocationPhoto, location: Location, in project: Project) async throws {
        print("开始异步保存照片到场景...")
        
        // 获取CoreData上下文
        let context = PersistenceController.shared.container.viewContext
        
        // 1. 查找场景实体
        let request = NSFetchRequest<LocationEntity>(entityName: "LocationEntity")
        request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", 
            location.id as CVarArg, project.id as CVarArg)
        
        // 检查是否找到场景实体
        guard let locationEntity = try? context.fetch(request).first else {
            print("❌ 找不到场景实体，ID: \(location.id)")
            throw NSError(domain: "ProjectStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到场景实体"])
        }
        
        print("✓ 找到场景实体，名称: \(locationEntity.name ?? "未命名")")
        
        // 2. 创建照片实体
        return try await Task {
            let photoEntity = LocationPhotoEntity(context: context)
            photoEntity.id = photo.id
            photoEntity.imageData = photo.imageData
            photoEntity.date = photo.date
            photoEntity.weather = photo.weather
            photoEntity.note = photo.note
            photoEntity.location = locationEntity
            
            print("✓ 已创建照片实体 ID: \(photo.id)")
            
            // 3. 保存上下文
            try context.save()
            print("✓ 照片保存到CoreData成功")
            
            // 4. 触发CloudKit同步
            PersistenceController.shared.save()
            print("✓ 已触发CloudKit同步")
            
            return ()
        }.value
    }
}

// 表单行视图
struct FormRowView<Content: View>: View {
    let label: String
    let icon: String
    let content: Content
    
    init(label: String, icon: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            content
                .foregroundStyle(.primary)
        }
    }
} 