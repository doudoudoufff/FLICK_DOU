import SwiftUI
import PhotosUI
import FLICK

struct LocationScoutingView: View {
    @Binding var project: Project
    @State private var showingAddLocation = false
    @State private var selectedFilter: LocationType?
    @State private var searchText = ""
    @State private var showingDailyPhotos = false
    
    // 按类型分组的场地
    var locationsByType: [LocationType: [Location]] {
        Dictionary(grouping: filteredLocations) { $0.type }
    }
    
    // 过滤后的场地列表
    var filteredLocations: [Location] {
        project.locations.filter { location in
            let matchesSearch = searchText.isEmpty || 
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.address.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter = selectedFilter == nil || location.type == selectedFilter
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 类型筛选器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "全部",
                            isSelected: selectedFilter == nil,
                            color: project.color
                        ) {
                            selectedFilter = nil
                        }
                        
                        ForEach(LocationType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                isSelected: selectedFilter == type,
                                color: project.color
                            ) {
                                selectedFilter = type
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 场地列表
                if project.locations.isEmpty {
                    ContentUnavailableView(
                        "暂无场地",
                        systemImage: "building.2.fill",
                        description: Text("点击右上角添加场地")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(LocationType.allCases, id: \.self) { type in
                            if let locations = locationsByType[type], !locations.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    // 分组标题
                                    Text(type.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                    
                                    // 场地列表
                                    ForEach($project.locations.filter { $0.type.wrappedValue == type }) { $location in
                                        NavigationLink {
                                            LocationDetailView(location: $location, projectColor: project.color)
                                        } label: {
                                            LocationRow(location: location)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("堪景")
        .searchable(text: $searchText, prompt: "搜索场地")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    NavigationLink {
                        DailyPhotosView(project: $project)
                    } label: {
                        Image(systemName: "clock.fill")
                    }
                    
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView(project: $project)
        }
    }
}

#Preview {
    NavigationStack {
        LocationScoutingView(project: .constant(Project(name: "测试项目")))
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
