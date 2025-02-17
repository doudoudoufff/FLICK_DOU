import SwiftUI
import PhotosUI

struct LocationSceneView: View {
    @Binding var scene: LocationScene
    let projectColor: Color
    
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 场景信息卡片
                VStack(alignment: .leading, spacing: 12) {
                    // 日期
                    Text(scene.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // 备注
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
                
                // 拍照和相册按钮
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
                
                // 照片时间线
                if scene.photos.isEmpty {
                    ContentUnavailableView(
                        "暂无照片",
                        systemImage: "photo.fill",
                        description: Text("点击上方按钮添加照片")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(scene.photos.indices, id: \.self) { index in
                            PhotoTimelineItem(
                                photo: Binding(
                                    get: { scene.photos[index] },
                                    set: { newValue in
                                        scene.photos[index] = newValue
                                    }
                                ),
                                color: projectColor
                            )
                        }
                    }
                }
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
                        scene.photos.insert(photo, at: 0)
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
                    DispatchQueue.main.async {
                        scene.photos.insert(contentsOf: newPhotos, at: 0)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
} 