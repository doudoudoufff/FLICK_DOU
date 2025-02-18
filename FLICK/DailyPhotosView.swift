import SwiftUI
import UniformTypeIdentifiers

struct DailyPhotosView: View {
    @Binding var project: Project
    @State private var selectedDate: Date?
    @State private var showingExportOptions = false
    @State private var showingDatePicker = false
    @State private var filterDate: Date?
    
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
        
        // 如果有日期筛选，只返回该日期的照片
        let filteredGroups: [Date: [(Location, LocationPhoto)]] = {
            if let filterDate = filterDate {
                let startOfDay = Calendar.current.startOfDay(for: filterDate)
                return grouped.filter { $0.key == startOfDay }
            }
            return grouped
        }()
        
        // 按日期降序排序
        return filteredGroups.sorted { $0.key > $1.key }
    }
    
    // 获取所有有照片的日期
    private var availableDates: Set<Date> {
        Set(project.locations.flatMap { location in
            location.photos.map { photo in
                Calendar.current.startOfDay(for: photo.date)
            }
        })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 日期筛选器
                DateFilterView(
                    filterDate: $filterDate,
                    availableDates: availableDates,
                    projectColor: project.color
                )
                .padding(.horizontal)
                
                if photosByDate.isEmpty {
                    ContentUnavailableView(
                        filterDate == nil ? "暂无照片" : "该日期暂无照片",
                        systemImage: "photo.fill",
                        description: Text(filterDate == nil ? "在场地详情页添加照片" : "选择其他日期查看")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(photosByDate, id: \.0) { date, photos in
                            DaySection(
                                date: date,
                                photos: photos,
                                projectColor: project.color,
                                isSelected: selectedDate == date
                            ) {
                                if selectedDate == date {
                                    selectedDate = nil
                                } else {
                                    selectedDate = date
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("每日照片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedDate != nil {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
        .confirmationDialog("导出选项", isPresented: $showingExportOptions) {
            if let date = selectedDate {
                Button("导出堪景报告") {
                    exportReport(for: date)
                }
                
                Button("导出照片") {
                    exportPhotos(for: date)
                }
            }
            
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $filterDate,
                availableDates: availableDates,
                projectColor: project.color
            )
        }
    }
    
    private func exportReport(for date: Date) {
        // TODO: 生成并导出堪景报告
        // 1. 收集当天的所有照片和场地信息
        // 2. 生成 PDF 报告
        // 3. 分享报告
    }
    
    private func exportPhotos(for date: Date) {
        // TODO: 导出照片
        // 1. 收集当天的所有照片
        // 2. 分享照片
    }
}

private struct DaySection: View {
    let date: Date
    let photos: [(Location, LocationPhoto)]
    let projectColor: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日期标题（可点击选择）
            Button {
                onTap()
            } label: {
                HStack {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(projectColor)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isSelected ? projectColor.opacity(0.1) : Color.clear)
            
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

// 日期筛选视图
private struct DateFilterView: View {
    @Binding var filterDate: Date?
    let availableDates: Set<Date>
    let projectColor: Color
    
    var body: some View {
        if let date = filterDate {
            Button {
                filterDate = nil
            } label: {
                HStack {
                    Text(date.formatted(date: .complete, time: .omitted))
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(projectColor)
                .clipShape(Capsule())
            }
        }
    }
}

// 日期选择器面板
private struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    let availableDates: Set<Date>
    let projectColor: Color
    @State private var tempDate: Date?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(getCalendarDays(), id: \.self) { date in
                        let hasPhotos = availableDates.contains(date)
                        Button {
                            if hasPhotos {
                                tempDate = date
                            }
                        } label: {
                            Text(date.formatted(.dateTime.day()))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if hasPhotos {
                                            projectColor.opacity(tempDate == date ? 1 : 0.1)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                                .foregroundStyle(
                                    hasPhotos ?
                                    (tempDate == date ? .white : projectColor) :
                                    .secondary
                                )
                        }
                        .disabled(!hasPhotos)
                    }
                }
                .padding()
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .disabled(tempDate == nil)
                }
            }
        }
        .onAppear {
            tempDate = selectedDate
        }
    }
    
    private func getCalendarDays() -> [Date] {
        // 获取当前月份的所有日期
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month)) else {
            return []
        }
        
        let monthLength = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        
        return (1...monthLength).compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }
} 