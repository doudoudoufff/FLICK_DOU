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
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
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
                        .disabled(pdfURL == nil)
                    }
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

// 注意：PDFKitViewWithNavigation 和 ShareSheet 结构体在 PDFReportView.swift 文件中定义 