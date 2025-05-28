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
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : LinearGradient(
                            colors: [Color(.systemGray6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
                .shadow(
                    color: isSelected ? color.opacity(0.3) : Color.clear,
                    radius: isSelected ? 4 : 0,
                    x: 0,
                    y: isSelected ? 2 : 0
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
        VStack(alignment: .leading, spacing: 12) {
            // 场地名称和状态
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // 地址
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                LocationStatusBadge(status: location.status)
            }
            
            // 照片预览
            if !location.photos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(location.photos.count) 张照片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(location.photos.prefix(5)) { photo in
                                if let image = photo.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray5), lineWidth: 0.5)
                                        )
                                }
                            }
                            
                            // 如果照片超过5张，显示更多指示器
                            if location.photos.count > 5 {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        VStack(spacing: 2) {
                                            Image(systemName: "plus")
                                                .font(.caption)
                                            Text("\(location.photos.count - 5)")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.secondary)
                                    )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            
            // 联系人信息
            if let contactName = location.contactName {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(contactName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let phone = location.contactPhone {
                        Image(systemName: "phone.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text(phone)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
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
        HStack(spacing: 4) {
            Circle()
                .fill(statusInfo.color)
                .frame(width: 6, height: 6)
            
            Text(statusInfo.text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(statusInfo.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusInfo.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(statusInfo.color.opacity(0.3), lineWidth: 1)
        )
    }
} 