import SwiftUI
import CoreData

struct VenueListView: View {
    @ObservedObject private var venueManager: VenueManager
    @State private var showingAddVenue = false
    @State private var selectedVenueID: UUID? = nil
    @State private var showingVenueDetail = false
    @State private var searchText = ""
    @State private var selectedType: String? = nil
    @State private var editingVenue: VenueEntity? = nil
    @State private var showingEditSheet = false
    
    init(context: NSManagedObjectContext) {
        // 使用传入的上下文初始化VenueManager
        self.venueManager = VenueManager(context: context)
        print("VenueListView初始化，使用上下文: \(context)")
        
        // 自定义List的外观
        UITableView.appearance().contentInset.left = -16
        UITableView.appearance().contentInset.right = -16
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 场地类型筛选器和添加按钮
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        VenueFilterChip(
                            title: "全部",
                            isSelected: selectedType == nil,
                            color: .blue,
                            action: {
                                selectedType = nil
                                venueManager.selectedVenueType = nil
                                venueManager.fetchVenues()
                            }
                        )
                        
                        ForEach(venueManager.venueTypeOptions, id: \.self) { type in
                            VenueFilterChip(
                                title: type,
                                isSelected: selectedType == type,
                                color: .blue,
                                action: {
                                    selectedType = type
                                    venueManager.selectedVenueType = type
                                    venueManager.fetchVenues()
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            
            // 场地列表
            if venueManager.venues.isEmpty {
                EmptyVenueView()
            } else {
                List {
                    // 按场地类型分组
                    ForEach(groupedVenues.keys.sorted(), id: \.self) { type in
                        if let venues = groupedVenues[type], !venues.isEmpty {
                            Section(header: Text(type)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, -12)
                                .padding(.bottom, 4)
                            ) {
                                ForEach(venues) { venue in
                                    VenueCard(venue: venue)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .contentShape(Rectangle())
                                        .background(
                                            NavigationLink(
                                                destination: VenueDetailView(venue: venue, venueManager: venueManager),
                                                tag: venue.id ?? UUID(),
                                                selection: $selectedVenueID
                                            ) {
                                                EmptyView()
                                            }
                                            .opacity(0)
                                        )
                                        .onTapGesture {
                                            selectVenue(venue)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                // 删除场地
                                                venueManager.deleteVenue(venue)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .padding(.horizontal, -2) // 让列表更宽
            }
        }
        .navigationTitle("场地管理")
        .searchable(text: $searchText, prompt: "搜索场地名称或地址")
        .onChange(of: searchText) { newValue in
            venueManager.searchText = newValue
            venueManager.fetchVenues()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddVenue = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("添加场地")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
        }
        .sheet(isPresented: $showingAddVenue) {
            AddEditVenueView(venueManager: venueManager)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let venue = editingVenue {
                AddEditVenueView(venueManager: venueManager, venue: venue)
            }
        }
        .onAppear {
            print("VenueListView出现，刷新场地列表")
            venueManager.fetchVenues()
        }
    }
    
    // 选择场地显示详情
    private func selectVenue(_ venue: VenueEntity) {
        // 只存储场地ID，而不是整个对象引用
        guard let venueID = venue.id else {
            print("错误：场地没有ID")
            return
        }
        
        print("选择场地: \(venue.wrappedName), ID: \(venueID.uuidString)")
        selectedVenueID = venueID
    }
    
    // 按场地类型分组的场地
    private var groupedVenues: [String: [VenueEntity]] {
        Dictionary(grouping: venueManager.venues) { $0.wrappedType }
    }
}

// MARK: - 筛选器组件
struct VenueFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - 空状态视图
struct EmptyVenueView: View {
    var body: some View {
        ContentUnavailableView(
            "暂无场地",
            systemImage: "building.2.fill",
            description: Text("点击右上角添加场地")
        )
        .padding(.top, 40)
    }
}

// MARK: - 场地卡片
struct VenueCard: View {
    let venue: VenueEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // 场地名称
                Text(venue.wrappedName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 附件数量
                if !venue.attachmentsArray.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.caption)
                        Text("\(venue.attachmentsArray.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
            
            // 联系人信息
            HStack {
                Label(venue.wrappedContactName, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(venue.wrappedContactPhone, systemImage: "phone")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 地址信息
            HStack(alignment: .top) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, 2)
                
                Text(venue.wrappedAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
} 
