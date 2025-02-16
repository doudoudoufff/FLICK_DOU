import SwiftUI
import PhotosUI

struct LocationScoutingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部操作栏
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
                .padding()
                
                // 时间线视图
                if project.locationPhotos.isEmpty {
                    ContentUnavailableView(
                        "暂无堪景记录",
                        systemImage: "camera.viewfinder",
                        description: Text("点击上方按钮添加照片")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach($project.locationPhotos) { $photo in
                            LocationTimelineItem(photo: $photo, projectColor: project.color)
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .navigationTitle("堪景")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage,
                       let photo = LocationPhoto(image: image) {
                        project.locationPhotos.insert(photo, at: 0)
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
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let photo = LocationPhoto(image: image) {
                        project.locationPhotos.insert(photo, at: 0)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
}

// 时间线项目视图
struct LocationTimelineItem: View {
    @Binding var photo: LocationPhoto
    let projectColor: Color
    @State private var note: String
    @FocusState private var isFocused: Bool
    
    init(photo: Binding<LocationPhoto>, projectColor: Color) {
        self._photo = photo
        self.projectColor = projectColor
        self._note = State(initialValue: photo.wrappedValue.note ?? "")
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 时间线指示器
            VStack(spacing: 0) {
                Circle()
                    .fill(projectColor)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(projectColor.opacity(0.2))
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
                NavigationLink {
                    LocationPhotoDetailView(photo: photo)
                } label: {
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4/3, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                Image(systemName: "photo.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            }
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
    }
}

// 照片详情视图
struct LocationPhotoDetailView: View {
    let photo: LocationPhoto
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 照片
                Image(uiImage: photo.image ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 时间
                Text(photo.date.formatted(date: .long, time: .standard))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // 备注
                if let note = photo.note {
                    Text(note)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 堪景照片模型
struct LocationPhoto: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    var note: String?
    var date: Date
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    init?(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        self.id = UUID()
        self.imageData = imageData
        self.date = Date()
    }
    
    static let placeholder = UIImage(systemName: "photo.fill")!
} 
