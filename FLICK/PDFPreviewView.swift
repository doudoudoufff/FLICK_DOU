import SwiftUI
import PDFKit
import QuickLook

struct PDFPreviewView: View {
    let pdfData: Data
    let title: String
    
    @State private var pdfDocument: PDFDocument?
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("正在准备PDF预览...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pdfDocument {
                    PDFKitView(document: pdfDocument)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("无法加载PDF文档")
                            .font(.headline)
                        
                        Text("请尝试重新生成报告")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(pdfURL == nil)
                }
            }
            .onAppear {
                processPDFData()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func processPDFData() {
        isLoading = true
        
        // 在后台线程处理PDF数据
        DispatchQueue.global(qos: .userInitiated).async {
            // 创建PDF文档
            guard let document = PDFDocument(data: pdfData) else {
                print("无法从数据创建PDF文档")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            // 确保文件名有.pdf后缀
            let fileName = title.hasSuffix(".pdf") ? title : "\(title).pdf"
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: tmpURL)
                
                // 在主线程更新UI
                DispatchQueue.main.async {
                    self.pdfDocument = document
                    self.pdfURL = tmpURL
                    self.isLoading = false
                }
            } catch {
                print("保存PDF文件失败: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }
    }
}

// 注意：PDFKitView 和 ShareSheet 结构体已经在 PDFReportView.swift 文件中定义 