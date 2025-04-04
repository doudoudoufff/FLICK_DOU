import SwiftUI
import PhotosUI
import FLICK

struct LocationScoutingView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddSheet = false
    @State private var selectedFilter: LocationType?
    @State private var searchText = ""
    @State private var showingDailyPhotos = false
    @State private var showingExportOptions = false
    @State private var showingPDFReport = false
    @State private var reportPhotos: [(Location, LocationPhoto)] = []
    @State private var reportDate: Date?
    
    // 获取所有堪景照片
    private var allLocationPhotos: [(Location, LocationPhoto)] {
        var photos: [(Location, LocationPhoto)] = []
        for location in project.locations {
            for photo in location.photos {
                photos.append((location, photo))
            }
        }
        return photos.sorted { $0.1.date < $1.1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FilterSection(
                    selectedFilter: $selectedFilter,
                    projectColor: project.color
                )
                
                if project.locations.isEmpty {
                    EmptyLocationView()
                } else {
                    LocationListContent(
                        project: $project,
                        selectedFilter: selectedFilter,
                        searchText: searchText
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("堪景")
        .searchable(text: $searchText, prompt: "搜索场地")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LocationToolbarContent(
                    showingAddSheet: $showingAddSheet,
                    showingExportOptions: $showingExportOptions,
                    project: $project
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLocationView(project: project)
        }
        .sheet(isPresented: $showingPDFReport) {
            if let date = reportDate {
                PDFReportView(
                    project: project,
                    date: date,
                    photos: reportPhotos
                )
            }
        }
        .confirmationDialog("导出选项", isPresented: $showingExportOptions) {
            Button("导出所有堪景PDF报告") {
                prepareAndShowAllPhotosPDFReport()
            }
            
            Button("查看每日照片时间线") {
                showingDailyPhotos = true
            }
            
            Button("取消", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showingDailyPhotos) {
            DailyPhotosView(project: $project)
        }
    }
    
    // 准备所有照片的PDF报告
    private func prepareAndShowAllPhotosPDFReport() {
        // 获取所有照片和场地信息
        reportDate = Date()
        reportPhotos = allLocationPhotos
        
        // 显示PDF报告视图
        showingPDFReport = true
    }
    
    private func addLocation(_ location: Location) {
        project.locations.append(location)
        projectStore.saveProjects()
    }
}

#Preview {
    NavigationStack {
        LocationScoutingView(project: .constant(Project(name: "测试项目")))
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
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

// MARK: - 筛选器部分
private struct FilterSection: View {
    @Binding var selectedFilter: LocationType?
    let projectColor: Color
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "全部",
                    isSelected: selectedFilter == nil,
                    color: projectColor
                ) {
                    selectedFilter = nil
                }
                
                ForEach(LocationType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue,
                        isSelected: selectedFilter == type,
                        color: projectColor
                    ) {
                        selectedFilter = type
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 空状态视图
private struct EmptyLocationView: View {
    var body: some View {
        ContentUnavailableView(
            "暂无场地",
            systemImage: "building.2.fill",
            description: Text("点击右上角添加场地")
        )
        .padding(.top, 40)
    }
}

// MARK: - 场地列表内容
private struct LocationListContent: View {
    @Binding var project: Project
    let selectedFilter: LocationType?
    let searchText: String
    
    private var filteredLocations: [Location] {
        project.locations.filter { location in
            let matchesSearch = searchText.isEmpty || 
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.address.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter = selectedFilter == nil || location.type == selectedFilter
            
            return matchesSearch && matchesFilter
        }
    }
    
    private var locationsByType: [LocationType: [Location]] {
        Dictionary(grouping: filteredLocations) { $0.type }
    }
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(LocationType.allCases, id: \.self) { type in
                if let locations = locationsByType[type], !locations.isEmpty {
                    LocationTypeSection(
                        type: type,
                        project: $project,
                        locations: locations
                    )
                }
            }
        }
    }
}

// MARK: - 场地类型分组
private struct LocationTypeSection: View {
    let type: LocationType
    @Binding var project: Project
    let locations: [Location]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(type.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ForEach(locations) { location in
                let locationBinding = Binding(
                    get: { location },
                    set: { newLocation in
                        if let index = project.locations.firstIndex(where: { $0.id == location.id }) {
                            project.locations[index] = newLocation
                        }
                    }
                )
                
                NavigationLink {
                    LocationDetailView(
                        project: project,  // 传递值而不是绑定
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

// MARK: - 工具栏内容
struct LocationToolbarContent: View {
    @Binding var showingAddSheet: Bool
    @Binding var showingExportOptions: Bool
    @Binding var project: Project
    
    var body: some View {
        HStack {
            Button {
                showingExportOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            
            NavigationLink {
                DailyPhotosView(project: $project)
            } label: {
                Image(systemName: "clock.fill")
            }
            
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }
} 
