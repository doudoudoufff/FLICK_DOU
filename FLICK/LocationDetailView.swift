import SwiftUI
import PhotosUI
import MapKit

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
    @State private var showingMap = false
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
                    LocationInfoCard(location: location, showMap: $showingMap)
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
            .sheet(isPresented: $showingMap) {
                if let coordinate = location.coordinate {
                    LocationMapView(location: location)
                }
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

// MARK: - 地图视图
struct LocationMapView: View {
    let location: Location
    @State private var region: MKCoordinateRegion
    @State private var mapPosition: MapCameraPosition
    @Environment(\.dismiss) private var dismiss
    
    init(location: Location) {
        self.location = location
        let coordinate = location.coordinate ?? CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975) // 默认北京坐标
        self._region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        self._mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        NavigationStack {
            Map(position: $mapPosition) {
                if let coordinate = location.coordinate {
                    Marker(location.name, coordinate: coordinate)
                        .tint(.red)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openInMaps()
                    } label: {
                        Label("导航", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                }
            }
        }
    }
    
    private func openInMaps() {
        guard let coordinate = location.coordinate else { return }
        
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - 基本信息卡片
private struct LocationInfoCard: View {
    let location: Location
    @Binding var showMap: Bool
    
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
                
                if location.hasCoordinates {
                    Spacer()
                    Button {
                        showMap = true
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("查看地图")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            .font(.subheadline)
            
            // 导航按钮（仅当有坐标时显示）
            if location.hasCoordinates {
                Button {
                    openInMaps()
                } label: {
                    HStack {
                        Spacer()
                        Label("导航前往", systemImage: "car.fill")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            
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
    
    private func openInMaps() {
        guard let coordinate = location.coordinate else { return }
        
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
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
