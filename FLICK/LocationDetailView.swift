import SwiftUI
import PhotosUI

// MARK: - 视图模式
enum ViewMode {
    case grid
    case timeline
}

struct LocationDetailView: View {
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    @Binding var location: Location
    let projectColor: Color
    @State private var showingEditView = false
    
    var body: some View {
        NavigationStack {
            List {
                // 基本信息
                Section {
                    LocationInfoCard(location: location)
                        .equatable()
                }
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button {
                    showingEditView = true
                } label: {
                    Image(systemName: "pencil")
                }
            )
            .sheet(isPresented: $showingEditView) {
                NavigationStack {
                    EditLocationView(
                        location: location,
                        projectStore: projectStore,
                        project: project
                    )
                }
            }
        }
    }
}

// MARK: - 基本信息卡片
private struct LocationInfoCard: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 类型和状态
            HStack {
                Text(location.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                LocationStatusBadge(status: location.status)
            }
            
            // 地址
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(location.address)
            }
            .font(.subheadline)
            
            // 联系人信息
            if let contactName = location.contactName {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text(contactName)
                    if let phone = location.contactPhone {
                        Button {
                            guard let url = URL(string: "tel:\(phone)") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Text(phone)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .font(.subheadline)
            }
            
            // 备注
            if let notes = location.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Equatable 实现
extension LocationInfoCard: Equatable {
    static func == (lhs: LocationInfoCard, rhs: LocationInfoCard) -> Bool {
        lhs.location.id == rhs.location.id &&
        lhs.location.name == rhs.location.name &&
        lhs.location.photos.count == rhs.location.photos.count
    }
}
