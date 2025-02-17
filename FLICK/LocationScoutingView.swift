import SwiftUI
import PhotosUI
import FLICK

struct LocationScoutingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    @State private var showingAddGroup = false
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
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
                    LazyVStack(spacing: 0) {
                        ForEach($project.locationPhotos) { $photo in
                            PhotoTimelineItem(photo: $photo, color: project.color)
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

// 场地行视图
struct LocationGroupRow: View {
    let group: LocationGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text(group.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !group.photos.isEmpty {
                Text("\(group.photos.count)张照片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// 添加场地表单
struct AddLocationGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    
    @State private var name = ""
    @State private var note = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("场地名称", text: $name)
                }
                
                Section {
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加场地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let newGroup = LocationGroup(
                            name: name,
                            note: note.isEmpty ? nil : note
                        )
                        DispatchQueue.main.async {
                            project.locationGroups.append(newGroup)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// 场地详情视图
struct LocationGroupDetailView: View {
    @Binding var group: LocationGroup
    let projectColor: Color
    
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 场地信息卡片
                VStack(alignment: .leading, spacing: 12) {
                    // 日期
                    Text(group.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // 备注
                    if let note = group.note {
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
                if group.photos.isEmpty {
                    ContentUnavailableView(
                        "暂无照片",
                        systemImage: "photo.fill",
                        description: Text("点击上方按钮添加照片")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach($group.photos) { $photo in
                            PhotoTimelineItem(photo: $photo, color: projectColor)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(group.name)
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let image = newImage,
                       let photo = LocationPhoto(image: image) {
                        withAnimation {
                            group.photos.insert(photo, at: 0)
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
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let photo = LocationPhoto(image: image) {
                        withAnimation {
                            group.photos.insert(photo, at: 0)
                        }
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
}

// 照片时间线项
struct PhotoTimelineItem: View {
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
