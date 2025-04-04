import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import Foundation
import ZIPFoundation

struct DailyPhotosView: View {
    @Binding var project: Project
    @State private var selectedDate: Date?
    @State private var showingExportOptions = false
    @State private var showingDatePicker = false
    @State private var filterDate: Date?
    @State private var showingExportProgress = false
    @State private var exportProgress: Float = 0
    @State private var exportStatus = "准备导出..."
    @State private var showingPDFReport = false
    @State private var reportDate: Date?
    @State private var reportPhotos: [(Location, LocationPhoto)] = []
    
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
                        description: Text(filterDate == nil ? 
                            "在场地详情页添加照片" : 
                            "这一天还没有拍摄任何照片\n选择其他日期或清除筛选查看所有照片"
                        )
                    )
                    .padding(.top, 40)
                    .multilineTextAlignment(.center)
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
                Button("导出堪景PDF报告") {
                    prepareAndShowPDFReport(for: date)
                }
                
                Button("导出照片压缩包") {
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
        .sheet(isPresented: $showingExportProgress) {
            ExportProgressView(progress: exportProgress, status: exportStatus)
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
        .overlay {
            if showingExportProgress {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ExportProgressView(
                    progress: exportProgress,
                    status: exportStatus
                )
            }
        }
    }
    
    private func prepareAndShowPDFReport(for date: Date) {
        // 获取当天的照片和场地信息
        reportDate = date
        reportPhotos = photosByDate.first { Calendar.current.isDate($0.0, inSameDayAs: date) }?.1 ?? []
        
        // 显示PDF报告视图
        showingPDFReport = true
    }
    
    private func exportPhotos(for date: Date) {
        // 获取当天的照片和场地信息
        let dayPhotos = photosByDate.first { Calendar.current.isDate($0.0, inSameDayAs: date) }?.1 ?? []
        
        // 创建临时文件夹
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("堪景照片_\(date.formatted(date: .abbreviated, time: .omitted))")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 显示进度视图
        exportProgress = 0
        exportStatus = "准备导出..."
        showingExportProgress = true
        
        // 在后台线程处理
        DispatchQueue.global(qos: .userInitiated).async {
            var currentProgress: Float = 0
            let totalPhotos = Float(dayPhotos.count)
            
            // 保存每张照片
            for (index, (location, photo)) in dayPhotos.enumerated() {
                // 更新进度
                currentProgress = Float(index) / totalPhotos
                DispatchQueue.main.async {
                    exportProgress = currentProgress
                    exportStatus = "正在处理第 \(index + 1) 张照片..."
                }
                
                // 创建场地文件夹
                let locationDir = tempDir.appendingPathComponent(location.name)
                try? FileManager.default.createDirectory(at: locationDir, withIntermediateDirectories: true)
                
                // 生成文件名
                let hourMinute = Calendar.current.component(.hour, from: photo.date) * 100 + 
                                Calendar.current.component(.minute, from: photo.date)
                let fileName = String(format: "%04d", hourMinute) + "_" + 
                              (photo.note?.prefix(10).replacingOccurrences(of: " ", with: "_") ?? "无备注")
                
                // 保存照片
                let photoPath = locationDir.appendingPathComponent("\(fileName).jpg")
                if let imageData = photo.image?.jpegData(compressionQuality: 0.8) {
                    try? imageData.write(to: photoPath)
                }
                
                // 如果有备注，创建文本文件
                if let note = photo.note, !note.isEmpty {
                    let notePath = locationDir.appendingPathComponent("\(fileName).txt")
                    try? note.write(to: notePath, atomically: true, encoding: .utf8)
                }
            }
            
            // 完成导出
            DispatchQueue.main.async {
                exportProgress = 1.0
                exportStatus = "正在压缩文件..."
            }
            
            // 创建压缩文件
            let zipPath = tempDir.deletingLastPathComponent()
                .appendingPathComponent("堪景照片_\(date.formatted(date: .abbreviated, time: .omitted)).zip")
            
            if createZipFile(at: zipPath, containing: tempDir) {
                DispatchQueue.main.async {
                    exportStatus = "导出完成!"
                    showingExportProgress = false
                    
                    // 分享压缩文件
                    shareReport(at: zipPath)
                }
            } else {
                DispatchQueue.main.async {
                    exportStatus = "导出失败"
                    showingExportProgress = false
                }
            }
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempDir)
        }
    }
    
    private func createZipFile(at path: URL, containing directory: URL) -> Bool {
        do {
            let archive = try Archive(url: path, accessMode: .create)
            
            // 获取源目录中的所有文件
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            // 添加每个文件到压缩包
            for fileURL in contents {
                let fileName = fileURL.lastPathComponent
                
                if fileName == "photos" {
                    // 处理照片文件夹
                    let photos = try fileManager.contentsOfDirectory(
                        at: fileURL,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    
                    // 创建照片文件夹
                    for photoURL in photos {
                        let photoPath = "photos/" + photoURL.lastPathComponent
                        try archive.addEntry(with: photoPath, fileURL: photoURL)
                    }
                } else {
                    // 处理其他文件
                    try archive.addEntry(with: fileName, fileURL: fileURL)
                }
            }
            
            return true
        } catch {
            print("Zip creation failed: \(error)")
            return false
        }
    }
    
    private func shareReport(at path: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [path],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
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
    @State private var displayMonth: Date = Date()  // 当前显示的月份
    
    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月份选择器
                HStack {
                    Button {
                        displayMonth = calendar.date(
                            byAdding: .month,
                            value: -1,
                            to: displayMonth
                        ) ?? displayMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(projectColor)
                    }
                    
                    Spacer()
                    
                    Text(displayMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        displayMonth = calendar.date(
                            byAdding: .month,
                            value: 1,
                            to: displayMonth
                        ) ?? displayMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(projectColor)
                    }
                }
                .padding()
                
                Divider()
                
                // 星期标题
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                
                // 日历网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(getCalendarDays(), id: \.self) { date in
                        let hasPhotos = availableDates.contains(date)
                        Button {
                            tempDate = date
                        } label: {
                            VStack(spacing: 4) {
                                Text(date.formatted(.dateTime.day()))
                                    .font(.subheadline)
                                
                                // 照片指示器
                                if hasPhotos {
                                    Circle()
                                        .fill(projectColor)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Group {
                                    if tempDate == date {
                                        projectColor
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            )
                            .foregroundStyle(
                                tempDate == date ? .white :
                                calendar.isDate(date, equalTo: Date(), toGranularity: .month) ? .primary :
                                .secondary
                            )
                        }
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
                }
            }
        }
        .onAppear {
            tempDate = selectedDate
            if let date = selectedDate {
                displayMonth = date
            }
        }
    }
    
    private func getCalendarDays() -> [Date] {
        let calendar = Calendar.current
        
        // 获取当月第一天
        let monthInterval = calendar.dateInterval(of: .month, for: displayMonth)!
        let firstDate = monthInterval.start
        
        // 获取当月天数
        let monthLength = calendar.range(of: .day, in: .month, for: firstDate)!.count
        
        // 获取第一天是星期几
        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let offsetDays = (firstWeekday + 5) % 7  // 调整为周一开始
        
        // 生成上个月的尾部日期
        let previousMonthDates = (0..<offsetDays).map { offset in
            calendar.date(byAdding: .day, value: -offset - 1, to: firstDate)!
        }.reversed()
        
        // 生成当月日期
        let currentMonthDates = (0..<monthLength).map { day in
            calendar.date(byAdding: .day, value: day, to: firstDate)!
        }
        
        // 计算需要补充的下个月日期数
        let remainingDays = (42 - offsetDays - monthLength)  // 保持6行
        let nextMonthDates = (0..<remainingDays).map { day in
            calendar.date(byAdding: .day, value: day, to: monthInterval.end)!
        }
        
        return Array(previousMonthDates) + currentMonthDates + nextMonthDates
    }
}

// 添加进度指示器视图
private struct ExportProgressView: View {
    let progress: Float
    let status: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress) {
                Text(status)
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            .tint(.accentColor)
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 300)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
    }
} 