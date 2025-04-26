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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if let pdfDocument = pdfDocument {
                    PDFKitView(document: pdfDocument)
                } else {
                    ProgressView("生成报告中...")
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
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(pdfURL == nil || isGenerating)
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

// PDF查看组件
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
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
