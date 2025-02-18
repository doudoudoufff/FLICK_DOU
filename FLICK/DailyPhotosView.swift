import SwiftUI

struct DailyPhotosView: View {
    @Binding var project: Project
    
    // 获取所有场地的照片并按日期分组
    private var photosByDate: [(Date, [(Location, LocationPhoto)])] {
        // 收集所有场地的照片，并记录对应的场地信息
        let allPhotos = project.locations.flatMap { location in
            location.photos.map { (location, $0) }
        }
        
        // 按日期分组
        let grouped = Dictionary(grouping: allPhotos) { pair in
            Calendar.current.startOfDay(for: pair.1.date)
        }
        
        // 按日期降序排序
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(photosByDate, id: \.0) { date, photos in
                    DaySection(date: date, photos: photos, projectColor: project.color)
                }
            }
        }
        .navigationTitle("每日照片")
    }
}

private struct DaySection: View {
    let date: Date
    let photos: [(Location, LocationPhoto)]
    let projectColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日期标题
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 12)
            
            // 当天的照片时间线
            ForEach(photos.sorted { $0.1.date > $1.1.date }, id: \.1.id) { location, photo in
                PhotoTimelineItem(
                    location: location,
                    photo: photo,
                    color: projectColor
                )
            }
        }
        .padding(.top, 8)
    }
}

private struct PhotoTimelineItem: View {
    let location: Location
    let photo: LocationPhoto
    let color: Color
    @State private var showingDetail = false
    
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
                // 时间和场地信息
                HStack {
                    Text(photo.date.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    Text(location.name)
                        .fontWeight(.medium)
                    Text("·")
                    Text(location.type.rawValue)
                }
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
                
                // 备注
                if let note = photo.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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