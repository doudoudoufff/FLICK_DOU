import SwiftUI
import CoreData
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct AddEditVenueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var venueManager: VenueManager
    
    // 编辑模式时传入
    var venue: VenueEntity?
    
    @State private var name: String = ""
    @State private var contactName: String = ""
    @State private var contactPhone: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var selectedType: String = "摄影棚" // 默认类型
    
    // 图片和PDF附件
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var isShowingImagePicker = false
    @State private var isShowingDocumentPicker = false
    @State private var selectedPDFData: Data? = nil
    @State private var selectedPDFName: String? = nil
    
    // 表单验证
    @State private var nameError: Bool = false
    @State private var addressError: Bool = false
    
    var isEditMode: Bool {
        venue != nil
    }
    
    var title: String {
        isEditMode ? "编辑场地" : "添加场地"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 场地类型选择（顶部）
                Section(header: Text("场地类型")) {
                    // 替换Picker为滑动选择UI
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(venueManager.venueTypeOptions, id: \.self) { type in
                                    Button(action: {
                                        selectedType = type
                                    }) {
                                        Text(type)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedType == type ? Color.accentColor : Color(.systemGray5))
                                            .foregroundColor(selectedType == type ? .white : .primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // 基本信息
                Section(header: HStack {
                    Text("场地信息")
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                }) {
                    HStack {
                        Text("场地名称")
                        Text("*")
                            .foregroundColor(.red)
                            .font(.caption)
                        TextField("", text: $name)
                            .onChange(of: name) { newValue in
                                nameError = newValue.isEmpty
                            }
                    }
                    
                    if nameError {
                        Text("场地名称不能为空")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("场地地址")
                        Text("*")
                            .foregroundColor(.red)
                            .font(.caption)
                        TextField("", text: $address)
                            .onChange(of: address) { newValue in
                                addressError = newValue.isEmpty
                            }
                    }
                    
                    if addressError {
                        Text("场地地址不能为空")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // 联系信息
                Section(header: Text("联系信息")) {
                    TextField("联系人", text: $contactName)
                    TextField("联系电话", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
                
                // 附件 - 图片
                Section(header: Text("图片")) {
                    Button(action: {
                        isShowingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                            Text("添加图片")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let image = selectedImage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("预览图片")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 附件 - PDF
                Section(header: Text("PDF文档")) {
                    Button(action: {
                        isShowingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.red)
                            Text("添加PDF文件")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if selectedPDFData != nil, let fileName = selectedPDFName {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fileName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text("PDF已选择，将在保存后添加")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                // 清除已选择的PDF
                                selectedPDFData = nil
                                selectedPDFName = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 备注
                Section(header: Text("备注")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "保存" : "添加") {
                        saveVenue()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerView { url in
                    do {
                        let pdfData = try Data(contentsOf: url)
                        let fileName = url.lastPathComponent
                        print("已选择PDF文件: \(fileName), 大小: \(pdfData.count) 字节")
                        
                        // 保存PDF数据以便后续创建新场地时使用
                        if isEditMode, let venueToEdit = venue {
                            _ = venueManager.addPDFAttachment(to: venueToEdit, pdfData: pdfData, fileName: fileName)
                        } else {
                            // 非编辑模式，临时保存PDF数据
                            selectedPDFData = pdfData
                            selectedPDFName = fileName
                            print("PDF数据已临时保存，创建场地后将添加: \(fileName)")
                        }
                    } catch {
                        print("读取PDF文件失败: \(error.localizedDescription)")
                    }
                }
            }
            .onAppear {
                loadVenueData()
            }
        }
    }
    
    // 加载场地数据
    private func loadVenueData() {
        if let venue = venue {
            // 如果有场地ID，尝试从数据库获取最新数据
            if let venueID = venue.id, let freshVenue = venueManager.getVenueByID(venueID) {
                print("编辑模式，从数据库加载最新场地数据: \(freshVenue.wrappedName)")
                name = freshVenue.wrappedName
                contactName = freshVenue.wrappedContactName
                contactPhone = freshVenue.wrappedContactPhone
                address = freshVenue.wrappedAddress
                notes = freshVenue.wrappedNotes
                selectedType = freshVenue.wrappedType
            } else {
                // 直接使用传入的场地对象
                print("编辑模式，使用传入的场地数据: \(venue.wrappedName)")
                name = venue.wrappedName
                contactName = venue.wrappedContactName
                contactPhone = venue.wrappedContactPhone
                address = venue.wrappedAddress
                notes = venue.wrappedNotes
                selectedType = venue.wrappedType
            }
        } else {
            print("添加模式，使用默认值")
        }
    }
    
    private func saveVenue() {
        // 验证必填字段
        nameError = name.isEmpty
        addressError = address.isEmpty
        
        if nameError || addressError {
            return
        }
        
        print("保存场地数据: \(name)")
        
        if isEditMode, let venue = venue {
            // 更新现有场地
            venueManager.updateVenue(
                venue,
                name: name,
                contactName: contactName,
                contactPhone: contactPhone,
                address: address,
                notes: notes,
                type: selectedType
            )
            
            // 如果有选择图片，添加图片附件
            if let image = selectedImage {
                let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                _ = venueManager.addImageAttachment(to: venue, image: image, fileName: fileName)
            }
        } else {
            // 添加新场地
            let newVenue = venueManager.addVenue(
                name: name,
                contactName: contactName,
                contactPhone: contactPhone,
                address: address,
                notes: notes,
                type: selectedType
            )
            
            // 如果有选择图片，添加图片附件
            if let image = selectedImage {
                let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                _ = venueManager.addImageAttachment(to: newVenue, image: image, fileName: fileName)
            }
            
            // 如果有选择PDF，添加PDF附件
            if let pdfData = selectedPDFData, let fileName = selectedPDFName {
                print("正在添加之前选择的PDF: \(fileName)")
                _ = venueManager.addPDFAttachment(to: newVenue, pdfData: pdfData, fileName: fileName)
            }
        }
        
        dismiss()
    }
}

// 文档选择器 - 使用与VenueDetailView一致的实现
struct DocumentPickerView: UIViewControllerRepresentable {
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
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
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