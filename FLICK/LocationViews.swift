import SwiftUI

// 筛选器组件
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - 场地分组视图
private struct LocationSection: View {
    let type: LocationType
    @ObservedObject var project: Project
    let locations: [Location]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(type.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ForEach(locations) { location in
                let locationBinding = Binding<Location>(
                    get: { location },
                    set: { newLocation in
                        if let index = project.locations.firstIndex(where: { $0.id == location.id }) {
                            project.locations[index] = newLocation
                        }
                    }
                )
                
                NavigationLink {
                    LocationDetailView(
                        project: project,
                        location: locationBinding,
                        projectColor: project.color
                    )
                } label: {
                    LocationRow(location: location)
                }
                .padding(.horizontal)
            }
        }
    }
}

// 场地行组件
struct LocationRow: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 场地名称和状态
            HStack {
                Text(location.name)
                    .font(.headline)
                Spacer()
                LocationStatusBadge(status: location.status)
            }
            
            // 地址
            Text(location.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 照片预览
            if !location.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(location.photos.prefix(5)) { photo in
                            if let image = photo.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
            
            // 联系人信息
            if let contactName = location.contactName {
                HStack {
                    Image(systemName: "person.fill")
                        .imageScale(.small)
                    Text(contactName)
                    if let phone = location.contactPhone {
                        Text(" | \(phone)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 状态标签组件（重命名以避免冲突）
struct LocationStatusBadge: View {
    let status: LocationStatus
    
    var statusInfo: (text: String, color: Color) {
        switch status {
        case .pending:
            return ("待确认", .orange)
        case .confirmed:
            return ("已确认", .green)
        case .rejected:
            return ("已否决", .red)
        }
    }
    
    var body: some View {
        Text(statusInfo.text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusInfo.color.opacity(0.1))
            .clipShape(Capsule())
    }
} 