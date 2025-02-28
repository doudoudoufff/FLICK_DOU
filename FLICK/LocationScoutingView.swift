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
                    project: $project
                )
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLocationView(project: project)
        }
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
    @Binding var project: Project
    
    var body: some View {
        HStack {
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
