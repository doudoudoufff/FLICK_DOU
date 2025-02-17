import SwiftUI
import PhotosUI

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