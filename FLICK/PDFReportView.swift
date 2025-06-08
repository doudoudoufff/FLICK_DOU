import SwiftUI
import PDFKit

struct PDFReportView: View {
    let project: Project
    let date: Date
    let photos: [(Location, LocationPhoto)]
    
    @State private var pdfDocument: PDFDocument?
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var isGenerating = true
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let pdfDocument = pdfDocument {
                    VStack(spacing: 0) {
                        // PDF预览区域
                        PDFKitViewWithNavigation(
                            document: pdfDocument,
                            currentPage: $currentPage,
                            totalPages: $totalPages
                        )
                        
                        // 底部页面导航栏
                        if totalPages > 1 {
                            HStack {
                                Button {
                                    if currentPage > 1 {
                                        currentPage -= 1
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(currentPage > 1 ? .blue : .gray)
                                }
                                .disabled(currentPage <= 1)
                                
                                Spacer()
                                
                                Text("第 \(currentPage) 页，共 \(totalPages) 页")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button {
                                    if currentPage < totalPages {
                                        currentPage += 1
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.title2)
                                        .foregroundColor(currentPage < totalPages ? .blue : .gray)
                                }
                                .disabled(currentPage >= totalPages)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .overlay(
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundColor(Color(.separator)),
                                alignment: .top
                            )
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView("生成报告中...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("正在处理 \(photos.count) 张照片...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("堪景报告预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if let pdfDocument = pdfDocument, totalPages > 0 {
                            Text("\(totalPages)页")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(pdfURL == nil || isGenerating)
                    }
                }
            }
            .onAppear {
                generatePDF()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func generatePDF() {
        isGenerating = true
        // 在后台线程生成PDF
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()
            
            var logoImage: UIImage? = nil
            if let logoData = project.logoData {
                logoImage = UIImage(data: logoData)
            }
            
            let generator = PDFReportGenerator(project: project, date: date, photos: photos, logoImage: logoImage)
            let (pdfData, fileName) = generator.generatePDF()
            
            guard let pdfData = pdfData else {
                print("PDF生成失败")
                DispatchQueue.main.async {
                    self.isGenerating = false
                }
                return
            }
            
            do {
                let tmpURL = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(fileName)
                
                print("PDF生成完成, 大小: \(pdfData.count / 1024) KB, 耗时: \(Date().timeIntervalSince(startTime)) 秒")
                try pdfData.write(to: tmpURL)
                
                // 在主线程更新UI
                DispatchQueue.main.async {
                    if let document = PDFDocument(url: tmpURL) {
                        self.pdfDocument = document
                        self.pdfURL = tmpURL
                    }
                    self.isGenerating = false
                }
            } catch {
                print("保存PDF文件时发生错误：\(error)")
                DispatchQueue.main.async {
                    self.isGenerating = false
                }
            }
        }
    }
    
    private var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
            .replacingOccurrences(of: " ", with: "_")
    }
}

// PDF查看组件 - 基础版本
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        
        // 修改显示模式以支持多页浏览
        pdfView.displayMode = .singlePageContinuous  // 连续单页模式，可以垂直滚动查看所有页面
        pdfView.displayDirection = .vertical
        
        // 启用页面导航
        pdfView.displaysPageBreaks = true
        
        // 启用缩放功能
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5.0
        
        // 设置页面显示选项
        pdfView.displaysAsBook = false
        pdfView.displaysRTL = false
        
        // 启用拖拽滚动
        pdfView.isUserInteractionEnabled = true
        
        // 设置背景色
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// PDF查看组件 - 带导航的版本
struct PDFKitViewWithNavigation: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        
        // 修改显示模式以支持多页浏览
        pdfView.displayMode = .singlePageContinuous  // 连续单页模式，可以垂直滚动查看所有页面
        pdfView.displayDirection = .vertical
        
        // 启用页面导航
        pdfView.displaysPageBreaks = true
        
        // 启用缩放功能
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5.0
        
        // 设置页面显示选项
        pdfView.displaysAsBook = false
        pdfView.displaysRTL = false
        
        // 启用拖拽滚动
        pdfView.isUserInteractionEnabled = true
        
        // 设置背景色
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        
        // 设置代理以获取页面变化通知
        context.coordinator.pdfView = pdfView
        
        // 监听页面变化通知
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        // 初始化页数
        DispatchQueue.main.async {
            totalPages = document.pageCount
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        
        // 如果当前页面发生变化，跳转到指定页面
        if currentPage > 0 && currentPage <= document.pageCount,
           let page = document.page(at: currentPage - 1),
           uiView.currentPage != page {
            uiView.go(to: page)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitViewWithNavigation
        weak var pdfView: PDFView?
        
        init(_ parent: PDFKitViewWithNavigation) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex + 1
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 
