import SwiftUI

struct RoadbookPhotoSortView: View {
    @ObservedObject private var roadbookManager = RoadbookManager.shared
    @State var roadbook: Roadbook
    @State private var photos: [RoadbookPhoto]
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    
    init(roadbook: Roadbook) {
        self._roadbook = State(initialValue: roadbook)
        self._photos = State(initialValue: roadbook.photos.sorted(by: { $0.orderIndex < $1.orderIndex }))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if photos.isEmpty {
                    ContentUnavailableView {
                        Label("暂无照片", systemImage: "photo.stack")
                    } description: {
                        Text("请先添加照片到路书")
                    }
                } else {
                    List {
                        ForEach(photos) { photo in
                            HStack {
                                if let thumbnail = photo.thumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(6)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(6)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("照片 \(photo.orderIndex + 1)")
                                        .font(.headline)
                                    
                                    if !photo.note.isEmpty {
                                        Text(photo.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { from, to in
                            photos.move(fromOffsets: from, toOffset: to)
                            updatePhotoOrderIndices()
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("调整照片顺序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("保存中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
        }
    }
    
    private func updatePhotoOrderIndices() {
        // 更新照片的orderIndex
        for (index, photo) in photos.enumerated() {
            photos[index].orderIndex = index
        }
        print("已更新照片顺序索引，照片数量: \(photos.count)")
    }
    
    private func saveChanges() {
        isSaving = true
        
        // 确保照片顺序索引是正确的
        updatePhotoOrderIndices()
        
        // 打印排序前后的照片ID和顺序
        print("排序前的照片顺序:")
        for (index, photo) in roadbook.photos.enumerated() {
            print("索引: \(index), ID: \(photo.id), orderIndex: \(photo.orderIndex)")
        }
        
        print("排序后的照片顺序:")
        for (index, photo) in photos.enumerated() {
            print("索引: \(index), ID: \(photo.id), orderIndex: \(photo.orderIndex)")
        }
        
        // 更新路书中的照片顺序
        var updatedRoadbook = roadbook
        updatedRoadbook.photos = photos
        
        roadbookManager.updateRoadbook(updatedRoadbook) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success(let savedRoadbook):
                    print("照片排序保存成功，照片数量: \(savedRoadbook.photos.count)")
                    
                    // 打印保存后的照片顺序
                    print("保存后的照片顺序:")
                    for (index, photo) in savedRoadbook.photos.enumerated() {
                        print("索引: \(index), ID: \(photo.id), orderIndex: \(photo.orderIndex)")
                    }
                    
                    // 更新当前路书
                    self.roadbook = savedRoadbook
                    
                    // 关闭视图
                    self.dismiss()
                case .failure(let error):
                    print("保存照片顺序失败: \(error.localizedDescription)")
                }
            }
        }
    }
} 