import SwiftUI
import UIKit
import QuickLook
import UniformTypeIdentifiers

struct VenueDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var venue: VenueEntity
    @ObservedObject var venueManager: VenueManager
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedUIImage: UIImage?
    @State private var previewURL: URL?
    @State private var isShowingPreview = false
    @State private var previewAttachment: VenueAttachmentEntity?
    
    // 添加初始化诊断
    init(venue: VenueEntity, venueManager: VenueManager) {
        print("初始化VenueDetailView，场地: \(venue.wrappedName), ID: \(venue.id?.uuidString ?? "未知")")
        self.venue = venue
        self.venueManager = venueManager
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 场地信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    // 标题栏
                    HStack {
                        Text(venue.wrappedName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(venue.wrappedType)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Divider()
                    
                    // 联系信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("联系信息")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VenueInfoRow(icon: "person.fill", label: "联系人", value: venue.wrappedContactName)
                        
                        VenueInfoRow(icon: "phone.fill", label: "联系电话", value: venue.wrappedContactPhone, isPhone: true)
                    }
                    
                    Divider()
                    
                    // 地址信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("地址")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(venue.wrappedAddress)
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    openMaps()
                                }) {
                                    Label("在地图中查看", systemImage: "arrow.triangle.turn.up.right.circle")
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    // 备注信息
                    if !venue.wrappedNotes.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("备注")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(venue.wrappedNotes)
                                .foregroundColor(.primary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // 图片区域
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("图片")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Label("添加", systemImage: "plus")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    let imageAttachments = venue.attachmentsArray.filter { $0.isImage }
                    if imageAttachments.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("暂无图片")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(.vertical, 30)
                            Spacer()
                        }
                    } else {
                        // 显示图片
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(imageAttachments) { attachment in
                                if let data = attachment.data, let uiImage = UIImage(data: data) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                previewAttachment(attachment)
                                            }
                                            
                                        // 删除按钮
                                        Button(action: {
                                            // 删除图片
                                            venueManager.deleteAttachment(attachment)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .shadow(radius: 1)
                                        }
                                        .offset(x: -8, y: 8)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            venueManager.deleteAttachment(attachment)
                                        }) {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // PDF文档区域
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PDF文档")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingDocumentPicker = true
                        }) {
                            Label("添加", systemImage: "plus")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    let pdfAttachments = venue.attachmentsArray.filter { $0.isPDF }
                    if pdfAttachments.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("暂无PDF文档")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(.vertical, 30)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(pdfAttachments) { attachment in
                                VenueAttachmentRow(attachment: attachment, onDelete: {
                                    // 删除PDF附件
                                    venueManager.deleteAttachment(attachment)
                                })
                                .padding(.horizontal, 16)
                                .onTapGesture {
                                    previewAttachment(attachment)
                                }
                                .contextMenu {
                                    Button(role: .destructive, action: {
                                        venueManager.deleteAttachment(attachment)
                                    }) {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(venue.wrappedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        showingEditSheet = true
                    }) {
                        Text("编辑场地")
                    }
                    
                    Menu {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("删除场地", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditVenueView(venueManager: venueManager, venue: venue)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert, actions: {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                venueManager.deleteVenue(venue)
                presentationMode.wrappedValue.dismiss()
            }
        }, message: {
            Text("确定要删除 \"\(venue.wrappedName)\" 吗？此操作无法撤销。")
        })
        .sheet(isPresented: $showingImagePicker) {
            VenueDetailImagePicker(selectedImage: $selectedUIImage)
                .onDisappear {
                    if let image = selectedUIImage {
                        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                        _ = venueManager.addImageAttachment(to: venue, image: image, fileName: fileName)
                        selectedUIImage = nil
                    }
                }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            VenueDetailDocumentPicker { url in
                do {
                    let pdfData = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    print("已选择PDF文件: \(fileName), 大小: \(pdfData.count) 字节")
                    _ = venueManager.addPDFAttachment(to: venue, pdfData: pdfData, fileName: fileName)
                } catch {
                    print("读取PDF文件失败: \(error.localizedDescription)")
                }
            }
        }
        .sheet(isPresented: $isShowingPreview) {
            if let url = previewURL {
                QuickLookPreview(url: url)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            print("VenueDetailView出现，场地: \(venue.wrappedName), ID: \(venue.id?.uuidString ?? "未知")")
        }
        .onDisappear {
            // 视图消失时刷新场地列表
            venueManager.fetchVenues()
        }
    }
    
    private func openMaps() {
        let address = venue.wrappedAddress
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mapURL = URL(string: "https://maps.apple.com/?address=\(encodedAddress)")!
        
        if UIApplication.shared.canOpenURL(mapURL) {
            UIApplication.shared.open(mapURL)
        }
    }
    
    private func previewAttachment(_ attachment: VenueAttachmentEntity) {
        guard let data = attachment.data else { 
            print("无法预览附件：数据为空")
            return 
        }
        
        // 确保临时目录存在并可写
        let fileManager = FileManager.default
        let tempDirURL = fileManager.temporaryDirectory
        
        // 生成唯一文件名
        let uniqueID = UUID().uuidString
        var fileURL: URL
        var mimeType: String
        
        if attachment.isImage {
            fileURL = tempDirURL.appendingPathComponent("image_\(uniqueID).jpg")
            mimeType = "image/jpeg"
        } else if attachment.isPDF {
            fileURL = tempDirURL.appendingPathComponent("document_\(uniqueID).pdf")
            mimeType = "application/pdf"
        } else {
            print("无法预览附件：不支持的文件类型")
            return
        }
        
        do {
            // 删除已存在的同名文件
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            // 写入新文件
            try data.write(to: fileURL)
            
            print("预览文件已创建：\(fileURL.path)，类型：\(mimeType)，大小：\(data.count) 字节")
            previewURL = fileURL
            
            // 验证文件存在且可读
            if fileManager.fileExists(atPath: fileURL.path) {
                print("文件已成功写入磁盘并验证可访问")
                
                // 延迟一小段时间确保文件写入完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isShowingPreview = true
                }
            } else {
                print("错误：文件创建后无法访问")
            }
        } catch {
            print("无法创建临时文件: \(error.localizedDescription)")
        }
    }
}

// 信息行视图
struct VenueInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var isPhone: Bool = false
    
    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isPhone && !value.isEmpty && value != "未知" {
                Button(action: {
                    let tel = "tel://\(value.replacingOccurrences(of: " ", with: ""))"
                    if let url = URL(string: tel), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(value)
                        .foregroundColor(.blue)
                }
            } else {
                Text(value)
                    .foregroundColor(.primary)
            }
        }
    }
}

// 附件行视图
struct VenueAttachmentRow: View {
    let attachment: VenueAttachmentEntity
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                
                if attachment.isPDF {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                } else {
                    Image(systemName: attachment.attachmentType.icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.wrappedFileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if attachment.isPDF {
                        Text("PDF文档")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDate(attachment.wrappedDateAdded))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 添加删除按钮
            Button(action: {
                onDelete?()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
            }
            
            // 指示箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 图片选择器
struct VenueDetailImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VenueDetailImagePicker
        
        init(_ parent: VenueDetailImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// 文档选择器
struct VenueDetailDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // 修复UTType.pdf的使用问题
        let supportedTypes: [UTType]
        if #available(iOS 14.0, *) {
            supportedTypes = [UTType.pdf]
        } else {
            // 使用字符串标识符方式
            let pdfUTI = UTType(filenameExtension: "pdf")!
            supportedTypes = [pdfUTI]
        }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: VenueDetailDocumentPicker
        
        init(_ parent: VenueDetailDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 开始访问安全区域中的文件
            let securityScoped = url.startAccessingSecurityScopedResource()
            
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            parent.onPick(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("文档选择已取消")
        }
    }
}

// QuickLook预览
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // 确保预览控制器刷新
        uiViewController.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            print("准备预览文件: \(parent.url.path)")
            return parent.url as QLPreviewItem
        }
    }
} 