import SwiftUI
import PhotosUI
import FLICK

struct LocationScoutingView: View {
    @Binding var project: Project
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    // 按日期分组的照片
    var photosByDate: [Date: [LocationPhoto]] {
        let calendar = Calendar.current
        return Dictionary(grouping: project.locationPhotos) { photo in
            calendar.startOfDay(for: photo.date)
        }
    }
    
    // 排序后的日期
    var sortedDates: [Date] {
        photosByDate.keys.sorted(by: >)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                            .background(project.color)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        showingPhotosPicker = true
                    } label: {
                        Label("相册", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundColor(project.color)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(project.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
                
                // 照片时间线
                if project.locationPhotos.isEmpty {
                    ContentUnavailableView(
                        "暂无照片",
                        systemImage: "photo.fill",
                        description: Text("点击上方按钮添加照片")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(sortedDates, id: \.self) { date in
                        if let photos = photosByDate[date] {
                            VStack(alignment: .leading, spacing: 16) {
                                // 日期标题
                                Text(date.formatted(date: .complete, time: .omitted))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                // 当天的照片
                                ForEach(photos) { photo in
                                    if let index = project.locationPhotos.firstIndex(where: { $0.id == photo.id }) {
                                        PhotoCard(
                                            photo: Binding(
                                                get: { project.locationPhotos[index] },
                                                set: { project.locationPhotos[index] = $0 }
                                            ),
                                            color: project.color
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("堪景")
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage,
                       let photo = LocationPhoto(image: image) {
                        withAnimation {
                            project.locationPhotos.insert(photo, at: 0)
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
                        project.locationPhotos.insert(contentsOf: newPhotos, at: 0)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
}

// 照片卡片
struct PhotoCard: View {
    @Binding var photo: LocationPhoto
    let color: Color
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间
            Text(photo.date.formatted(date: .none, time: .shortened))
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // 备注
            if let note = photo.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                PhotoDetailView(photo: $photo)
            }
        }
    }
}

// 照片详情视图
struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photo: LocationPhoto
    @State private var note: String
    @FocusState private var isFocused: Bool
    
    init(photo: Binding<LocationPhoto>) {
        self._photo = photo
        self._note = State(initialValue: photo.wrappedValue.note ?? "")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(photo.date.formatted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("添加备注...", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }
                .padding()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    photo.note = note.isEmpty ? nil : note
                    dismiss()
                }
            }
        }
    }
} 
