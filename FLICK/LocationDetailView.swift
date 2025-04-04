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
    @State private var showingExportOptions = false
    @State private var showingPDFReport = false
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    // 获取当前场地的所有照片
    private var locationPhotos: [(Location, LocationPhoto)] {
        return location.photos.map { (location, $0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 基本信息
                Section {
                    LocationInfoCard(location: location)
                        .equatable()
                }
                
                // 照片区域
                Section {
                    LocationPhotoList(
                        project: project,
                        location: $location,
                        projectColor: projectColor
                    )
                }
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if !location.photos.isEmpty {
                            Button {
                                showingExportOptions = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        
                        Menu {
                            Button {
                                showingEditView = true
                            } label: {
                                Label("编辑场地", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除场地", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                NavigationStack {
                    EditLocationView(
                        location: location,
                        projectStore: projectStore,
                        project: project
                    )
                }
            }
            .sheet(isPresented: $showingPDFReport) {
                PDFReportView(
                    project: project,
                    date: Date(),
                    photos: locationPhotos
                )
            }
            .confirmationDialog("导出选项", isPresented: $showingExportOptions) {
                Button("导出场地PDF报告") {
                    showingPDFReport = true
                }
                
                Button("取消", role: .cancel) {}
            }
            .alert("确认删除场地", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteLocation()
                }
            } message: {
                Text("确定要删除\"\(location.name)\"场地吗？此操作将删除所有相关照片，且无法撤销。")
            }
        }
    }
    
    private func deleteLocation() {
        // 删除场地
        projectStore.deleteLocation(location, from: project)
        // 返回上一级
        dismiss()
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
