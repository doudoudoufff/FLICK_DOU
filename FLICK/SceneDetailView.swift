import SwiftUI
import PhotosUI

struct SceneDetailView: View {
    @Binding var scene: LocationScene
    let projectColor: Color
    
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 场景信息卡片
                SceneInfoCard(scene: scene)
                
                // 拍照和相册按钮
                PhotoActionButtons(
                    projectColor: projectColor,
                    showingCamera: $showingCamera,
                    showingPhotosPicker: $showingPhotosPicker
                )
                
                // 照片列表
                PhotoList(scene: $scene, projectColor: projectColor)
            }
            .padding(.vertical)
        }
        .navigationTitle(scene.name)
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage,
                       let photo = LocationPhoto(image: image) {
                        withAnimation {
                            scene.photos.insert(photo, at: 0)
                        }
                    }
                }
            ), sourceType: .camera)
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotosPicker,
                     selection: $selectedPhotos,
                     matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                var newPhotos: [LocationPhoto] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let photo = LocationPhoto(image: image) {
                        newPhotos.append(photo)
                    }
                }
                if !newPhotos.isEmpty {
                    withAnimation {
                        scene.photos.insert(contentsOf: newPhotos, at: 0)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
}

// 场景信息卡片
private struct SceneInfoCard: View {
    let scene: LocationScene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scene.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let note = scene.note {
                Text(note)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// 拍照和相册按钮
private struct PhotoActionButtons: View {
    let projectColor: Color
    @Binding var showingCamera: Bool
    @Binding var showingPhotosPicker: Bool
    
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
        .padding(.horizontal)
    }
}

// 照片列表
private struct PhotoList: View {
    @Binding var scene: LocationScene
    let projectColor: Color
    
    var body: some View {
        if scene.photos.isEmpty {
            ContentUnavailableView(
                "暂无照片",
                systemImage: "photo.fill",
                description: Text("点击上方按钮添加照片")
            )
            .padding(.top, 40)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(scene.photos.indices, id: \.self) { index in
                    PhotoCard(
                        photo: Binding(
                            get: { scene.photos[index] },
                            set: { scene.photos[index] = $0 }
                        ),
                        color: projectColor
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// 照片卡片
private struct PhotoCard: View {
    @Binding var photo: LocationPhoto
    let color: Color
    @State private var showingDetail = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间
            Text(photo.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // 照片
            if let image = photo.image {
                Button {
                    showingDetail = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // 备注
            TextField("添加备注...", text: Binding(
                get: { photo.note ?? "" },
                set: { newValue in
                    if !isFocused { return }
                    photo.note = newValue.isEmpty ? nil : newValue
                }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                PhotoDetailView(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showingDetail = false }
                        }
                    }
            }
        }
    }
}

// 照片详情视图
private struct PhotoDetailView: View {
    let photo: LocationPhoto
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Text(photo.date.formatted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let note = photo.note {
                    Text(note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
} 