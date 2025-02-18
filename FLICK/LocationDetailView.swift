import SwiftUI
import PhotosUI

struct LocationDetailView: View {
    @Binding var location: Location
    let projectColor: Color
    
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingEditSheet = false
    @State private var viewMode: ViewMode = .grid
    
    enum ViewMode {
        case grid
        case timeline
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 场地信息卡片
                LocationInfoCard(location: location)
                    .padding(.horizontal)
                
                // 拍照和相册按钮
                PhotoActionButtons(
                    showingCamera: $showingCamera,
                    showingPhotosPicker: $showingPhotosPicker,
                    projectColor: projectColor
                )
                .padding(.horizontal)
                
                // 视图模式切换
                Picker("显示模式", selection: $viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(ViewMode.grid)
                    Image(systemName: "clock")
                        .tag(ViewMode.timeline)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 照片展示
                if location.photos.isEmpty {
                    EmptyPhotoView()
                } else {
                    switch viewMode {
                    case .grid:
                        PhotoGrid(photos: $location.photos)
                            .padding(.horizontal)
                    case .timeline:
                        PhotoTimeline(photos: $location.photos, color: projectColor)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(location: $location)
        }
        .photosPicker(isPresented: $showingPhotosPicker,
                     selection: $selectedPhotos,
                     matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                await handleSelectedPhotos(newItems)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditLocationView(location: $location)
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let photo = LocationPhoto(image: image) {
                location.photos.insert(photo, at: 0)
            }
        }
        selectedPhotos.removeAll()
    }
}

// MARK: - 子视图组件
private struct LocationInfoCard: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息
            HStack {
                Text(location.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                LocationStatusBadge(status: location.status)
            }
            
            // 地址
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(location.address)
            }
            .font(.subheadline)
            
            // 联系人信息
            if let contactName = location.contactName {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text(contactName)
                    if let phone = location.contactPhone {
                        Button {
                            guard let url = URL(string: "tel:\(phone)") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Text(phone)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .font(.subheadline)
            }
            
            // 备注
            if let notes = location.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PhotoActionButtons: View {
    @Binding var showingCamera: Bool
    @Binding var showingPhotosPicker: Bool
    let projectColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Button {
                showingCamera = true
            } label: {
                Label("拍摄", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(projectColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Button {
                showingPhotosPicker = true
            } label: {
                Label("相册", systemImage: "photo.fill")
                    .font(.headline)
                    .foregroundColor(projectColor)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(projectColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct EmptyPhotoView: View {
    var body: some View {
        ContentUnavailableView(
            "暂无照片",
            systemImage: "photo.fill",
            description: Text("点击上方按钮添加照片")
        )
        .padding(.top, 40)
    }
}

private struct PhotoGrid: View {
    @Binding var photos: [LocationPhoto]
    @State private var selectedPhoto: LocationPhoto?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(photos) { photo in
                if let image = photo.image {
                    Button {
                        selectedPhoto = photo
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                LocationPhotoDetailView(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                selectedPhoto = nil
                            }
                        }
                    }
            }
        }
    }
}

private struct CameraView: View {
    @Binding var location: Location
    
    var body: some View {
        ImagePicker(image: Binding(
            get: { nil },
            set: { newImage in
                if let image = newImage,
                   let photo = LocationPhoto(image: image) {
                    location.photos.insert(photo, at: 0)
                }
            }
        ), sourceType: .camera)
        .ignoresSafeArea()
    }
}

// 新增时间线视图组件
private struct PhotoTimeline: View {
    @Binding var photos: [LocationPhoto]
    let color: Color
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach($photos) { $photo in
                PhotoTimelineItem(photo: $photo, color: color)
            }
        }
    }
}

// 时间线项组件
private struct PhotoTimelineItem: View {
    @Binding var photo: LocationPhoto
    let color: Color
    @State private var showingDetail = false
    @State private var note: String
    @FocusState private var isFocused: Bool
    
    init(photo: Binding<LocationPhoto>, color: Color) {
        self._photo = photo
        self.color = color
        self._note = State(initialValue: photo.wrappedValue.note ?? "")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 时间线指示器
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(color.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                // 时间
                Text(photo.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // 照片
                Button {
                    showingDetail = true
                } label: {
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // 备注输入框
                TextField("添加备注...", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: note) { _, newValue in
                        photo.note = newValue.isEmpty ? nil : newValue
                    }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                LocationPhotoDetailView(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                showingDetail = false
                            }
                        }
                    }
            }
        }
    }
} 