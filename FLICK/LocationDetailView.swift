import SwiftUI
import PhotosUI
import MapKit
import PDFKit
import CoreData
import AVFoundation

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
    @State private var isGeneratingPDF = false
    @Environment(\.dismiss) private var dismiss
    @State private var reportPDFData: Data?
    @State private var generatingProgress: Double = 0
    @State private var selectedPhotoForPreview: LocationPhoto?
    @State private var showingCopiedAlert = false
    @State private var copiedMessage = ""
    
    // 照片添加相关状态
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingCameraAlert = false
    @State private var cameraErrorMessage = ""
    @State private var isUploading = false
    @State private var uploadProgress: Float = 0.0
    @State private var processedItems = 0
    @State private var totalItems = 0
    
    // 获取当前场地的所有照片
    private var locationPhotos: [(Location, LocationPhoto)] {
        return location.photos.map { (location, $0) }
    }
    
    var body: some View {
        ZStack {
            // 主内容
            ScrollView {
                VStack(spacing: 20) {
                    // 主要信息卡片
                    mainInfoCard
                    
                    // 照片部分卡片
                    photoSectionCard
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditView = true
                        } label: {
                            Label("编辑场地", systemImage: "pencil")
                        }
                        
                        Button {
                            prepareAndShowPDFReport()
                        } label: {
                            Label("生成报告", systemImage: "doc.text")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("删除场地", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(projectColor)
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
                if let pdfData = reportPDFData {
                    PDFPreviewView(pdfData: pdfData, title: "\(project.name) - \(location.name) 场景报告")
                }
            }
            .sheet(isPresented: $showingMap) {
                if let coordinate = location.coordinate {
                    LocationMapView(location: location)
                }
            }
            .alert("已复制", isPresented: $showingCopiedAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(copiedMessage)
            }
            .alert("确认删除场地", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteLocation()
                }
            } message: {
                Text("确定要删除\"\(location.name)\"场地吗？此操作将删除所有相关照片，且无法撤销。")
            }
            .alert("相机错误", isPresented: $showingCameraAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(cameraErrorMessage)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(projectStore: projectStore, project: project, location: location)
            }
            .photosPicker(
                isPresented: $showingPhotosPicker,
                selection: $selectedPhotos,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, items in
                Task {
                    // 显示进度条
                    totalItems = items.count
                    processedItems = 0
                    isUploading = totalItems > 0
                    uploadProgress = 0.0
                    
                    // 批量处理照片
                    if totalItems > 0 {
                        // 创建一个临时数组存储处理好的照片，避免多次更新CoreData
                        var processedPhotos: [LocationPhoto] = []
                        
                        for (index, item) in items.enumerated() {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                // 修正图片方向
                                let correctedImage = fixImageOrientation(uiImage)
                                // 调整图片大小，降低内存占用
                                let resizedImage = resizeImage(correctedImage, targetSize: 1200)
                                let photo = LocationPhoto(image: resizedImage)
                                processedPhotos.append(photo)
                                
                                // 更新进度
                                processedItems = index + 1
                                uploadProgress = Float(processedItems) / Float(totalItems)
                                
                                // 每处理10张或者是最后一批时保存到CoreData
                                if processedPhotos.count >= 10 || index == items.count - 1 {
                                    // 批量添加到CoreData
                                    await projectStore.addPhotos(processedPhotos, to: location, in: project)
                                    processedPhotos.removeAll()
                                }
                            }
                        }
                        
                        // 完成上传
                        isUploading = false
                    }
                    
                    selectedPhotos.removeAll()
                }
            }
            
            // 悬浮拍照和相册按钮
            if !isUploading && !isGeneratingPDF {
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Spacer()
                        Button(action: { checkCameraPermissionAndShow() }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        Button(action: { showingPhotosPicker = true }) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(projectColor)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding([.trailing, .bottom], 24)
                }
            }
        }
        .overlay {
            if isGeneratingPDF {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("正在生成PDF报告...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button("取消") {
                            isGeneratingPDF = false
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                    .padding(25)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
            } else if isUploading {
                // 批量上传进度条
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("正在处理照片")
                                .font(.headline)
                            Spacer()
                            Text("\(processedItems)/\(totalItems)")
                                .font(.subheadline)
                        }
                        
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(projectColor)
                        
                        Text("处理大量照片可能需要一些时间，请耐心等待...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding()
                }
            }
        }
    }
    
    // MARK: - 主要信息卡片
    private var mainInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和状态
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(location.type.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LocationStatusBadge(status: location.status)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // 位置信息
            infoSection(title: "位置信息", icon: "location", color: .blue) {
                VStack(spacing: 12) {
                    // 可编辑的地址行
                    Button {
                        showingEditView = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("详细地址")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(location.address.isEmpty ? "点击设置地址" : location.address)
                                    .font(.subheadline)
                                    .foregroundColor(location.address.isEmpty ? .blue : .primary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                if !location.address.isEmpty {
                                    Button {
                                        copyToClipboard(location.address, label: "详细地址")
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .onTapGesture {
                                        // 阻止冒泡到外层按钮
                                    }
                                }
                                
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if location.hasCoordinates {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("坐标位置")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showingMap = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                    Text("查看地图")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        
                        // 导航按钮
                        Button {
                            openInMaps()
                        } label: {
                            HStack {
                                Image(systemName: "car.fill")
                                Text("导航前往")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            
            // 联系信息（如果有）
            if location.contactName != nil || location.contactPhone != nil {
                Divider()
                
                infoSection(title: "联系信息", icon: "person.circle", color: .green) {
                    VStack(spacing: 12) {
                        if let contactName = location.contactName {
                            infoRow(label: "联系人", value: contactName, icon: "person", isCopyable: true)
                        }
                        
                        if let contactPhone = location.contactPhone {
                            infoRow(label: "联系电话", value: contactPhone, icon: "phone", isCopyable: true, isPhoneNumber: true)
                        }
                    }
                }
            }
            
            // 备注信息（如果有）
            if let notes = location.notes, !notes.isEmpty {
                Divider()
                
                infoSection(title: "备注信息", icon: "note.text", color: .orange) {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6).opacity(0.5))
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 照片部分卡片
    private var photoSectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(projectColor)
                
                Text("场地照片")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("\(location.photos.count) 张")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    
                    Button {
                        prepareAndShowPDFReport()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("导出报告")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(projectColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            
            if location.photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("暂无照片")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("点击右下角按钮添加照片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LocationPhotoList(
                    project: project,
                    location: $location,
                    projectColor: projectColor
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 信息分组
    private func infoSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content()
        }
    }
    
    // MARK: - 信息行
    private func infoRow(
        label: String,
        value: String,
        icon: String,
        isCopyable: Bool = false,
        isPhoneNumber: Bool = false
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value.isEmpty ? "未设置" : value)
                    .font(.subheadline)
                    .foregroundColor(value.isEmpty ? .secondary.opacity(0.7) : .primary)
            }
            
            Spacer()
            
            if !value.isEmpty {
                HStack(spacing: 8) {
                    if isCopyable {
                        Button {
                            copyToClipboard(value, label: label)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if isPhoneNumber {
                        Button {
                            callPhoneNumber(value)
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    private func deleteLocation() {
        projectStore.deleteLocation(location, from: project)
        dismiss()
    }
    
    private func prepareAndShowPDFReport() {
        isGeneratingPDF = true
        generatingProgress = 0
        
        Task {
            do {
                var logoImage: UIImage? = nil
                if let logoData = project.logoData {
                    logoImage = UIImage(data: logoData)
                }
                
                let generator = PDFReportGenerator(project: project, location: location, logoImage: logoImage)
                let (pdfData, fileName) = generator.generatePDF()
                
                if let pdfData = pdfData {
                    reportPDFData = pdfData
                    isGeneratingPDF = false
                    showingPDFReport = true
                    print("PDF报告生成成功，文件名：\(fileName)")
                } else {
                    print("PDF生成失败")
                    isGeneratingPDF = false
                }
            } catch {
                print("生成PDF报告时发生错误：\(error)")
                isGeneratingPDF = false
            }
        }
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
        copiedMessage = "\(label)已复制到剪贴板"
        showingCopiedAlert = true
    }
    
    private func callPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "tel:\(phoneNumber)") else { return }
        UIApplication.shared.open(url)
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
    
    // MARK: - 照片添加相关方法
    
    // 检查相机权限并显示相机
    private func checkCameraPermissionAndShow() {
        // 首先检查相机硬件是否可用
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            cameraErrorMessage = "相机不可用或无法访问"
            showingCameraAlert = true
            return
        }
        
        // 检查相机权限状态
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 已授权，可以显示相机
            showingCamera = true
        case .notDetermined:
            // 尚未请求权限，请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.cameraErrorMessage = "需要相机权限才能拍摄照片"
                        self.showingCameraAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // 权限被拒绝或受限
            cameraErrorMessage = "需要相机权限才能拍摄照片，请在设置中允许访问相机"
            showingCameraAlert = true
        @unknown default:
            cameraErrorMessage = "无法访问相机"
            showingCameraAlert = true
        }
    }
    
    // 调整图片大小
    private func resizeImage(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        let size = image.size
        let widthRatio = targetSize / size.width
        let heightRatio = targetSize / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // 如果图片已经小于目标尺寸，直接返回
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // 添加图片方向修正方法
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
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
        let coordinate = location.coordinate ?? CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975)
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
