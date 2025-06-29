import SwiftUI
import PencilKit
import UIKit

// 文字标注模型
struct TextAnnotation: Identifiable {
    var id = UUID()
    var text: String
    var position: CGPoint
    var fontSize: CGFloat
    var color: Color
    var rotation: Double = 0
}

struct RoadbookPhotoEditView: View {
    // 环境对象
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var roadbookManager = RoadbookManager.shared
    
    // 状态变量
    @State private var photo: RoadbookPhoto
    @State private var roadbookId: UUID
    @State private var photoIndex: Int
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    // 移除笔记相关状态
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingConfirmation = false
    @State private var showingCamera = false
    
    // 文字标注相关状态
    @State private var textAnnotations: [TextAnnotation] = []
    @State private var isAddingText = false
    @State private var newText = ""
    @State private var textColor: Color = .red
    @State private var textSize: CGFloat = 20
    @State private var draggedAnnotationId: UUID? = nil
    @State private var selectedAnnotationId: UUID? = nil
    @State private var showingTextOptions = false
    
    // 编辑工具选择
    @State private var selectedTool: EditingTool = .draw
    
    // 回调函数，用于通知父视图需要继续拍照
    var onContinueTakingPhoto: (() -> Void)?
    
    enum EditingTool {
        case draw
        case text
    }
    
    // 初始化
    init(photo: RoadbookPhoto, roadbookId: UUID, photoIndex: Int, onContinueTakingPhoto: (() -> Void)? = nil) {
        _photo = State(initialValue: photo)
        _roadbookId = State(initialValue: roadbookId)
        _photoIndex = State(initialValue: photoIndex)
        self.onContinueTakingPhoto = onContinueTakingPhoto
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景颜色
                Color.white
                    .ignoresSafeArea()
                
                // 主内容
                VStack(spacing: 0) {
                    // 工具选择栏 - 移到顶部，避免被pencil UI遮挡
                    HStack {
                        Spacer()
                        
                        // 工具选择分段控件
                        Picker("编辑模式", selection: $selectedTool) {
                            Image(systemName: "pencil")
                                .tag(EditingTool.draw)
                            
                            Image(systemName: "text.cursor")
                                .tag(EditingTool.text)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 150)
                        .onChange(of: selectedTool) { newTool in
                            selectTool(newTool)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    
                    // 图片和画布
                    GeometryReader { geometry in
                        ZStack(alignment: .center) {
                            // 图片
                            if let displayImage = photo.displayImage {
                                Image(uiImage: displayImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            
                            // PencilKit画布 - 仅在绘图模式下显示
                            if selectedTool == .draw {
                                PencilKitCanvasView(canvasView: $canvasView, toolPicker: $toolPicker, image: photo.editedImage)
                                    .aspectRatio(photo.originalImage?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .opacity(selectedTool == .text ? 0.5 : 1.0) // 在文本模式下半透明
                            }
                            
                            // 文字标注层
                            ZStack {
                                // 现有的文字标注
                                ForEach(textAnnotations) { annotation in
                                    Text(annotation.text)
                                        .font(.system(size: annotation.fontSize))
                                        .foregroundColor(annotation.color)
                                        .position(annotation.position)
                                        .rotationEffect(.degrees(annotation.rotation))
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    if selectedTool == .text {
                                                        moveAnnotation(id: annotation.id, to: value.location)
                                                    }
                                                }
                                        )
                                        .onTapGesture {
                                            if selectedTool == .text {
                                                selectAnnotation(annotation.id)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(selectedAnnotationId == annotation.id ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                }
                                
                                // 新文字输入区域
                                if isAddingText {
                                    VStack {
                                        TextField("输入文字", text: $newText)
                                            .font(.system(size: textSize))
                                            .foregroundColor(textColor)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray, lineWidth: 1)
                                            )
                                        
                                        HStack {
                                            Button("取消") {
                                                isAddingText = false
                                                newText = ""
                                            }
                                            .foregroundColor(.black)
                                            .padding(8)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            
                                            Spacer()
                                            
                                            Button("添加") {
                                                addTextAnnotation()
                                            }
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(newText.isEmpty ? Color.gray : Color.blue)
                                            .cornerRadius(8)
                                            .disabled(newText.isEmpty)
                                        }
                                        .padding(.top, 8)
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                                    .frame(width: geometry.size.width * 0.8)
                                    .position(x: geometry.size.width / 2, y: geometry.size.height / 3)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .allowsHitTesting(selectedTool == .text)
                        }
                    }
                    
                    // 工具栏
                    VStack(spacing: 10) {
                        
                        // 文字工具选项 - 仅在文字模式下显示
                        if selectedTool == .text {
                            HStack(spacing: 15) {
                                // 添加新文字按钮
                                Button {
                                    isAddingText = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("添加文字")
                                    }
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                // 文字选项按钮
                                if selectedAnnotationId != nil {
                                    Button {
                                        showingTextOptions = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "textformat.size")
                                            Text("文字选项")
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .foregroundColor(.black)
                                        .cornerRadius(8)
                                    }
                                    
                                    Button {
                                        deleteSelectedAnnotation()
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("删除")
                                        }
                                        .padding(8)
                                        .background(Color.red.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        
                        Divider()
                            .background(Color.gray)
                        
                        // 底部工具栏
                        HStack {
                            Spacer()
                            
                            // 清除按钮
                            Button {
                                showingConfirmation = true
                            } label: {
                                VStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 20))
                                    Text("清除")
                                        .font(.caption)
                                }
                                .foregroundColor(.black)
                                .frame(width: 60)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .background(Color.gray.opacity(0.2))
                }
            }
            .navigationTitle("编辑照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        // 保存并继续按钮 - 仅当有继续拍照回调时显示
                        if onContinueTakingPhoto != nil {
                            Button {
                                // 先保存当前照片
                                saveChanges(andContinue: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("保存并继续")
                                    Image(systemName: "camera")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .disabled(isLoading)
                        }
                        
                        // 保存并结束按钮
                        Button {
                            saveChanges(andContinue: false)
                        } label: {
                            HStack(spacing: 4) {
                                Text("保存并结束")
                                Image(systemName: "checkmark")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(isLoading)
                    }
                }
            }
            // 移除笔记sheet
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .confirmationDialog("确认清除", isPresented: $showingConfirmation) {
                Button("清除所有内容", role: .destructive) {
                    clearAllContent()
                }
                Button("仅清除绘图", role: .destructive) {
                    canvasView.drawing = PKDrawing()
                }
                Button("仅清除文字", role: .destructive) {
                    textAnnotations.removeAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("选择要清除的内容")
            }
            .sheet(isPresented: $showingTextOptions) {
                textOptionsView()
                    .presentationDetents([.height(250)])
            }
            .sheet(isPresented: $showingCamera) {
                RoadbookCameraView(capturedImage: .constant(nil))
                    .ignoresSafeArea()
            }
            .onAppear {
                setupCanvasView()
                loadTextAnnotations()
            }
            .onDisappear {
                // 确保视图消失时隐藏工具选择器
                hidePencilToolPicker()
            }
        }
    }
    
    // 文字选项视图
    func textOptionsView() -> some View {
        // 将复杂的视图拆分为更小的组件
        let colorPickerView = createColorPickerView()
        let fontSizeView = createFontSizeView()
        let rotationView = createRotationView()
        
        return NavigationStack {
            VStack {
                colorPickerView
                fontSizeView
                rotationView
            }
            .navigationTitle("文字选项")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 创建颜色选择器视图
    private func createColorPickerView() -> some View {
        VStack(alignment: .leading) {
            Text("文字颜色")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .white, .black]
                    
                    ForEach(0..<colors.count, id: \.self) { index in
                        let color = colors[index]
                        ColorCircleView(
                            color: color,
                            isSelected: getSelectedAnnotation()?.color == color,
                            action: {
                                updateSelectedAnnotation { annotation in
                                    annotation.color = color
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    // 创建字体大小视图
    private func createFontSizeView() -> some View {
        VStack(alignment: .leading) {
            let fontSize = getSelectedAnnotation()?.fontSize ?? 20
            
            Text("字体大小: \(Int(fontSize))")
                .font(.headline)
            
            Slider(
                value: Binding(
                    get: { fontSize },
                    set: { newSize in
                        updateSelectedAnnotation { annotation in
                            annotation.fontSize = newSize
                        }
                    }
                ),
                in: 12...48,
                step: 1
            )
        }
        .padding()
    }
    
    // 创建旋转调整视图
    private func createRotationView() -> some View {
        VStack(alignment: .leading) {
            let rotation = getSelectedAnnotation()?.rotation ?? 0
            
            Text("旋转: \(Int(rotation))°")
                .font(.headline)
            
            Slider(
                value: Binding(
                    get: { rotation },
                    set: { newRotation in
                        updateSelectedAnnotation { annotation in
                            annotation.rotation = newRotation
                        }
                    }
                ),
                in: 0...360,
                step: 1
            )
        }
        .padding()
    }
    
    // 颜色圆圈视图
    private struct ColorCircleView: View {
        let color: Color
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .onTapGesture(perform: action)
        }
    }
    
    // 设置画布视图
    private func setupCanvasView() {
        // 设置画布背景为透明
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        
        // 如果有原始图片，调整画布大小以匹配图片的宽高比
        if let originalImage = photo.originalImage {
            let imageAspectRatio = originalImage.size.width / originalImage.size.height
            
            // 在下一个布局周期调整画布大小
            DispatchQueue.main.async {
                let canvasWidth = self.canvasView.bounds.width
                let canvasHeight = canvasWidth / imageAspectRatio
                
                // 更新画布大小约束
                self.canvasView.frame = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
            }
        }
        
        // 显示工具选择器
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }
    
    // 选择编辑工具
    private func selectTool(_ tool: EditingTool) {
        selectedTool = tool
        
        // 根据工具类型设置PencilKit工具
        switch tool {
        case .draw:
            canvasView.tool = PKInkingTool(.pen, color: .red, width: 1)
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
            selectedAnnotationId = nil
        case .text:
            // 在文本模式下隐藏工具选择器
            toolPicker.setVisible(false, forFirstResponder: canvasView)
            canvasView.resignFirstResponder()
        }
    }
    
    // 添加文字标注
    private func addTextAnnotation() {
        guard !newText.isEmpty else { return }
        
        // 获取画布中心点，但稍微上移，避免被工具栏遮挡
        let centerX = UIScreen.main.bounds.width / 2
        let centerY = UIScreen.main.bounds.height / 2.5
        
        let annotation = TextAnnotation(
            text: newText,
            position: CGPoint(x: centerX, y: centerY),
            fontSize: textSize,
            color: textColor
        )
        
        textAnnotations.append(annotation)
        selectedAnnotationId = annotation.id
        isAddingText = false
        newText = ""
    }
    
    // 移动文字标注
    private func moveAnnotation(id: UUID, to position: CGPoint) {
        if let index = textAnnotations.firstIndex(where: { $0.id == id }) {
            textAnnotations[index].position = position
            selectedAnnotationId = id
        }
    }
    
    // 选择文字标注
    private func selectAnnotation(_ id: UUID) {
        selectedAnnotationId = id
    }
    
    // 删除选中的文字标注
    private func deleteSelectedAnnotation() {
        if let id = selectedAnnotationId {
            textAnnotations.removeAll(where: { $0.id == id })
            selectedAnnotationId = nil
        }
    }
    
    // 获取选中的文字标注
    private func getSelectedAnnotation() -> TextAnnotation? {
        guard let id = selectedAnnotationId else { return nil }
        return textAnnotations.first(where: { $0.id == id })
    }
    
    // 更新选中的文字标注
    private func updateSelectedAnnotation(_ update: (inout TextAnnotation) -> Void) {
        guard let id = selectedAnnotationId,
              let index = textAnnotations.firstIndex(where: { $0.id == id }) else { return }
        
        var annotation = textAnnotations[index]
        update(&annotation)
        textAnnotations[index] = annotation
    }
    
    // 从照片数据加载文字标注
    private func loadTextAnnotations() {
        // 这里可以从photo中加载之前保存的文字标注数据
        // 目前简单实现，后续可以扩展
    }
    
    // 清除所有内容
    private func clearAllContent() {
        canvasView.drawing = PKDrawing()
        textAnnotations.removeAll()
    }
    
    // 保存更改
    private func saveChanges(andContinue: Bool = false) {
        isLoading = true
        
        // 如果要继续拍照，先隐藏 PencilKit 工具选择器
        if andContinue {
            hidePencilToolPicker()
        }
        
        // 获取画布上的绘制内容
        let drawing = canvasView.drawing
        
        // 更新照片
        var updatedPhoto = photo
        
        // 如果有绘制内容或文字标注，保存为编辑后的图片
        if !drawing.bounds.isEmpty || !textAnnotations.isEmpty {
            // 确保有原始图片
            guard let originalImage = photo.originalImage else {
                alertMessage = "无法获取原始图片"
                showingAlert = true
                isLoading = false
                return
            }
            
            // 获取原始图片尺寸
            let imageSize = originalImage.size
            
            // 创建一个与原始图片尺寸相同的上下文
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // 使用1.0的比例避免缩放问题
            format.opaque = false
            
            // 安全地获取画布尺寸
            let canvasSize = canvasView.bounds.size
            
            // 确保画布尺寸有效
            guard canvasSize.width > 0, canvasSize.height > 0 else {
                alertMessage = "画布尺寸无效"
                showingAlert = true
                isLoading = false
                return
            }
            
            // 计算绘图内容的缩放比例
            let scaleX = imageSize.width / canvasSize.width
            let scaleY = imageSize.height / canvasSize.height
            
            // 使用autoreleasepool来管理临时对象的内存
            autoreleasepool {
                let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
                let drawnImage = renderer.image { context in
                    // 先绘制原始图片
                    originalImage.draw(in: CGRect(origin: .zero, size: imageSize))
                    
                    // 缩放绘图内容以匹配原始图片尺寸
                    context.cgContext.scaleBy(x: scaleX, y: scaleY)
                    
                    // 绘制PencilKit内容 - 确保绘制区域有效
                    if !drawing.bounds.isEmpty {
                        let drawingImage = drawing.image(from: canvasView.bounds, scale: 1.0)
                        drawingImage.draw(in: canvasView.bounds)
                    }
                    
                    // 绘制文字标注
                    if !textAnnotations.isEmpty {
                        // 重置上下文缩放
                        context.cgContext.resetClip()
                        context.cgContext.scaleBy(x: scaleX, y: scaleY)
                        
                        for annotation in textAnnotations {
                            // 使用autoreleasepool管理每个文字标注的临时对象
                            autoreleasepool {
                                let attributedString = NSAttributedString(
                                    string: annotation.text,
                                    attributes: [
                                        .font: UIFont.systemFont(ofSize: annotation.fontSize),
                                        .foregroundColor: UIColor(annotation.color)
                                    ]
                                )
                                
                                // 计算文字大小
                                let textSize = attributedString.size()
                                
                                // 创建文字绘制区域
                                let textRect = CGRect(
                                    x: annotation.position.x - textSize.width / 2,
                                    y: annotation.position.y - textSize.height / 2,
                                    width: textSize.width,
                                    height: textSize.height
                                )
                                
                                // 应用旋转
                                context.cgContext.saveGState()
                                context.cgContext.translateBy(x: annotation.position.x, y: annotation.position.y)
                                context.cgContext.rotate(by: CGFloat(annotation.rotation) * .pi / 180)
                                context.cgContext.translateBy(x: -annotation.position.x, y: -annotation.position.y)
                                
                                // 绘制文字
                                attributedString.draw(in: textRect)
                                
                                context.cgContext.restoreGState()
                            }
                        }
                    }
                }
                
                // 安全地生成图片数据
                if let jpegData = drawnImage.jpegData(compressionQuality: 0.9) {
                    updatedPhoto.editedImageData = jpegData
                    
                    // 同时更新缩略图数据
                    updatedPhoto.thumbnailData = RoadbookPhoto.generateThumbnail(from: drawnImage)
                    
                    // 调试信息
                    if let thumbnailData = updatedPhoto.thumbnailData {
                        print("已生成缩略图，大小: \(thumbnailData.count) 字节")
                        if let thumbnailImage = UIImage(data: thumbnailData) {
                            print("缩略图尺寸: \(thumbnailImage.size)")
                        }
                    } else {
                        print("警告：生成缩略图失败")
                    }
                    
                    print("保存编辑后的图片，原始尺寸: \(imageSize), 画布尺寸: \(canvasSize), 结果尺寸: \(drawnImage.size)")
                } else {
                    print("警告：无法生成JPEG数据")
                }
            }
        }
        
        // 保存更新后的照片
        roadbookManager.updatePhoto(updatedPhoto, at: photoIndex, in: roadbookId) { result in
            self.isLoading = false
            
            switch result {
            case .success:
                if andContinue && self.onContinueTakingPhoto != nil {
                    // 如果需要继续拍照，调用回调函数
                    self.onContinueTakingPhoto?()
                } else {
                    // 否则关闭当前页面
                    self.dismiss()
                }
            case .failure(let error):
                self.alertMessage = "保存失败: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
    
    // 隐藏 PencilKit 工具选择器
    private func hidePencilToolPicker() {
        // 确保工具选择器被隐藏
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        
        // 放弃第一响应者状态，这样工具选择器就会完全消失
        canvasView.resignFirstResponder()
    }
}

// PencilKit画布视图
struct PencilKitCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var image: UIImage?
    
    func makeUIView(context: Context) -> PKCanvasView {
        // 配置画布
        canvasView.tool = PKInkingTool(.pen, color: .red, width: 1)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        // 如果有之前的绘制内容，尝试恢复
        if let editedImage = image, let pngData = editedImage.pngData() {
            do {
                // 尝试从图片数据中提取绘图内容
                let drawing = try PKDrawing(data: pngData)
                canvasView.drawing = drawing
            } catch {
                print("无法从图片数据恢复绘图内容: \(error)")
            }
        }
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 确保工具选择器可见并与画布关联
        toolPicker.setVisible(true, forFirstResponder: uiView)
        toolPicker.addObserver(uiView)
        
        // 使画布成为第一响应者
        DispatchQueue.main.async {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
} 