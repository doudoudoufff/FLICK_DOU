import Foundation
import SwiftXLSX
import UIKit
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers
import ZIPFoundation

class TransactionExcelExporter {
    // 添加进度回调类型定义
    typealias ProgressHandler = (String) -> Void
    
    static func exportTransactions(_ transactions: [Transaction], fileName: String, progressHandler: ProgressHandler? = nil, completion: @escaping (URL?) -> Void) {
        // 在主线程更新进度
        let updateProgress: ProgressHandler = { message in
            DispatchQueue.main.async {
                progressHandler?(message)
            }
        }
        
        // 在后台线程执行耗时操作
        DispatchQueue.global(qos: .userInitiated).async {
            // 更新进度
            updateProgress("初始化Excel导出...")
            
            let workbook = XWorkBook()
            let sheet = workbook.NewSheet("交易记录")
            
            // 设置表头
            updateProgress("创建表格结构...")
            let headers = ["日期", "名称", "描述", "金额", "类型", "费用类型", "支付方式", "组别", "验证状态", "项目", "附件文件名"]
            for (index, header) in headers.enumerated() {
                let cell = sheet.AddCell(XCoords(row: 1, col: index + 1))
                cell.value = .text(header)
                cell.Font = XFont(.TrebuchetMS, 12, true)
                // 设置表头样式
                cell.Cols(txt: .white, bg: .systemBlue)
            }
            
            // 填充数据
            updateProgress("准备填充交易数据...")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // 创建临时文件夹用于存储图片
            let tempDirURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ExcelExport", isDirectory: true)
            
            // 确保临时文件夹存在
            try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
            
            // 存储所有需要添加到ZIP的图片路径
            var imagePaths: [URL] = []
            
            let totalCount = transactions.count
            for (rowIndex, transaction) in transactions.enumerated() {
                // 更新进度
                if rowIndex % 5 == 0 || rowIndex == totalCount - 1 {
                    updateProgress("处理交易数据 \(rowIndex + 1)/\(totalCount)...")
                }
                
                let row = rowIndex + 2
                let isOddRow = rowIndex % 2 == 0
                
                let cells = [
                    dateFormatter.string(from: transaction.date),
                    transaction.name,
                    transaction.transactionDescription,
                    String(format: "%.2f", transaction.amount),
                    transaction.transactionType == .income ? "收入" : "支出",
                    transaction.expenseType,
                    transaction.paymentMethod,
                    transaction.group,
                    transaction.isVerified ? "已验证" : "未验证",
                    "" // 项目名称在这里不可用，因为Transaction没有直接引用项目
                ]
                
                for (colIndex, value) in cells.enumerated() {
                    let cell = sheet.AddCell(XCoords(row: row, col: colIndex + 1))
                    cell.value = .text(value)
                    
                    // 设置单元格样式
                    if isOddRow {
                        // 奇数行背景色
                        cell.Cols(txt: .black, bg: .systemGray6)
                    }
                    
                    // 为金额列设置特殊格式
                    if colIndex == 3 {
                        cell.alignmentHorizontal = .right
                        if transaction.transactionType == .expense {
                            cell.Font = XFont(.TrebuchetMS, 11, false)
                            cell.Cols(txt: .red, bg: isOddRow ? .systemGray6 : .white)
                        } else {
                            cell.Font = XFont(.TrebuchetMS, 11, false)
                            cell.Cols(txt: .systemGreen, bg: isOddRow ? .systemGray6 : .white)
                        }
                    }
                    
                    // 为类型列设置颜色
                    if colIndex == 4 {
                        if transaction.transactionType == .expense {
                            cell.Cols(txt: .red, bg: isOddRow ? .systemGray6 : .white)
                        } else {
                            cell.Cols(txt: .systemGreen, bg: isOddRow ? .systemGray6 : .white)
                        }
                    }
                }
                
                // 处理附件列
                let attachmentCell = sheet.AddCell(XCoords(row: row, col: 11))
                if isOddRow {
                    attachmentCell.Cols(txt: .black, bg: .systemGray6)
                }
                
                // 如果有附件，保存图片到临时文件夹并在Excel中添加引用
                if let attachmentData = transaction.attachmentData, let image = UIImage(data: attachmentData) {
                    updateProgress("处理第 \(rowIndex + 1) 条交易的附件图片...")
                    
                    // 为图片创建一个唯一的文件名
                    let imageFileName = "交易_\(dateFormatter.string(from: transaction.date))_\(transaction.name)_\(rowIndex + 1).jpg"
                    let safeFileName = imageFileName.replacingOccurrences(of: "/", with: "-")
                                                 .replacingOccurrences(of: ":", with: "-")
                                                 .replacingOccurrences(of: " ", with: "_")
                    
                    // 图片保存路径
                    let imageFileURL = tempDirURL.appendingPathComponent(safeFileName)
                    
                    // 保存图片到临时文件夹
                    if let jpegData = image.jpegData(compressionQuality: 0.8) {
                        try? jpegData.write(to: imageFileURL)
                        
                        // 添加到需要打包的图片列表
                        imagePaths.append(imageFileURL)
                        
                        // 在Excel中添加图片文件名引用
                        attachmentCell.value = .text(safeFileName)
                        attachmentCell.Font = XFont(.TrebuchetMS, 11, false)
                        attachmentCell.Cols(txt: .blue, bg: isOddRow ? .systemGray6 : .white)
                    }
                } else {
                    attachmentCell.value = .text("无")
                }
            }
            
            // 设置列宽
            let columnWidths = [15, 20, 30, 15, 10, 15, 15, 15, 10, 20, 25]
            for (index, width) in columnWidths.enumerated() {
                sheet.ForColumnSetWidth(index + 1, width * 6) // 乘以6使宽度更合适
            }
            
            // 添加合计行
            updateProgress("计算合计数据...")
            let totalRow = transactions.count + 2
            let totalCell = sheet.AddCell(XCoords(row: totalRow, col: 1))
            totalCell.value = .text("合计")
            totalCell.Font = XFont(.TrebuchetMS, 12, true)
            totalCell.Cols(txt: .white, bg: .systemBlue)
            
            // 计算收入和支出
            let totalIncome = transactions.filter { $0.transactionType == .income }.reduce(0) { $0 + abs($1.amount) }  // 使用绝对值确保收入为正
            let totalExpense = transactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + abs($1.amount) }
            
            // 添加收入合计
            let incomeCell = sheet.AddCell(XCoords(row: totalRow, col: 3))
            incomeCell.value = .text("收入合计:")
            incomeCell.Font = XFont(.TrebuchetMS, 12, true)
            incomeCell.Cols(txt: .white, bg: .systemBlue)
            
            let incomeTotalCell = sheet.AddCell(XCoords(row: totalRow, col: 4))
            incomeTotalCell.value = .text(String(format: "%.2f", totalIncome))
            incomeTotalCell.Font = XFont(.TrebuchetMS, 12, true)
            incomeTotalCell.Cols(txt: .white, bg: .systemBlue)
            incomeTotalCell.alignmentHorizontal = .right
            
            // 添加支出合计
            let expenseCell = sheet.AddCell(XCoords(row: totalRow + 1, col: 3))
            expenseCell.value = .text("支出合计:")
            expenseCell.Font = XFont(.TrebuchetMS, 12, true)
            expenseCell.Cols(txt: .white, bg: .systemBlue)
            
            let expenseTotalCell = sheet.AddCell(XCoords(row: totalRow + 1, col: 4))
            expenseTotalCell.value = .text(String(format: "%.2f", totalExpense))
            expenseTotalCell.Font = XFont(.TrebuchetMS, 12, true)
            expenseTotalCell.Cols(txt: .white, bg: .systemBlue)
            expenseTotalCell.alignmentHorizontal = .right
            
            // 添加余额
            let balanceCell = sheet.AddCell(XCoords(row: totalRow + 2, col: 3))
            balanceCell.value = .text("余额:")
            balanceCell.Font = XFont(.TrebuchetMS, 12, true, false)
            balanceCell.Cols(txt: .white, bg: .systemBlue)
            
            let balanceTotalCell = sheet.AddCell(XCoords(row: totalRow + 2, col: 4))
            balanceTotalCell.value = .text(String(format: "%.2f", totalIncome - totalExpense))
            balanceTotalCell.Font = XFont(.TrebuchetMS, 12, true, false)
            balanceTotalCell.Cols(txt: .white, bg: .systemBlue)
            balanceTotalCell.alignmentHorizontal = .right
            
            // 添加图片说明
            if !imagePaths.isEmpty {
                let noteRow = totalRow + 4
                let noteCell = sheet.AddCell(XCoords(row: noteRow, col: 1))
                noteCell.value = .text("附件图片说明")
                noteCell.Font = XFont(.TrebuchetMS, 12, true)
                
                let instructionCell = sheet.AddCell(XCoords(row: noteRow + 1, col: 1))
                instructionCell.value = .text("所有附件图片已保存在ZIP文件中，文件名与表格中的附件文件名列对应")
                instructionCell.Font = XFont(.TrebuchetMS, 11, false)
                instructionCell.Cols(txt: .blue, bg: .white)
            }
            
            // 创建最终文件名（不带扩展名）
            let baseFileName = createUniqueFileName(baseName: fileName)
            let excelFileName = baseFileName + ".xlsx"
            
            // 获取文档目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let excelFileURL = documentsDirectory.appendingPathComponent(excelFileName)
            
            // 保存文件
            updateProgress("准备保存Excel文件...")
            do {
                // 如果文件已存在，先删除
                if FileManager.default.fileExists(atPath: excelFileURL.path) {
                    try FileManager.default.removeItem(at: excelFileURL)
                }
                
                // 保存Excel文件到临时位置
                updateProgress("保存Excel文件中...")
                let tempFileName = "temp_\(excelFileName)"
                let savedPath = workbook.save(tempFileName)
                if savedPath.isEmpty {
                    print("Excel文件保存失败")
                    updateProgress("Excel文件保存失败")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                // 获取保存的文件路径
                let tempFileURL = URL(fileURLWithPath: savedPath)
                print("Excel文件已保存到临时位置: \(tempFileURL.path)")
                
                // 将文件复制到文档目录
                try FileManager.default.copyItem(at: tempFileURL, to: excelFileURL)
                print("Excel文件已复制到文档目录: \(excelFileURL.path)")
                
                // 删除临时文件
                try? FileManager.default.removeItem(at: tempFileURL)
                
                // 验证文件是否存在于文档目录
                let fileExists = FileManager.default.fileExists(atPath: excelFileURL.path)
                print("Excel文件是否存在于文档目录: \(fileExists)")
                assert(fileExists, "Excel文件未成功复制到文档目录")
                
                // 创建ZIP文件名
                let zipFileName = baseFileName + ".zip"
                let zipFileURL = documentsDirectory.appendingPathComponent(zipFileName)
                
                // 如果ZIP文件已存在，先删除
                if FileManager.default.fileExists(atPath: zipFileURL.path) {
                    try FileManager.default.removeItem(at: zipFileURL)
                }
                
                // 创建ZIP归档
                updateProgress("创建ZIP归档...")
                
                // 使用抛出异常的初始化方法
                let archive = try Archive(url: zipFileURL, accessMode: .create)
                
                // 读取Excel文件数据
                let excelData = try Data(contentsOf: excelFileURL)
                
                // 将Excel文件添加到ZIP归档中
                let excelProvider: (Int64, Int) throws -> Data = { position, size in
                    let rangeStart = Int(position)
                    let rangeEnd = min(Int(position) + size, excelData.count)
                    return excelData.subdata(in: rangeStart..<rangeEnd)
                }
                
                try archive.addEntry(
                    with: excelFileName,
                    type: .file,
                    uncompressedSize: Int64(excelData.count),
                    provider: excelProvider
                )
                
                // 添加所有图片到ZIP归档
                if !imagePaths.isEmpty {
                    updateProgress("添加图片到ZIP归档...")
                    
                    // 创建图片文件夹
                    let imagesFolderName = "附件图片"
                    
                    // 创建文件夹条目
                    let folderPath = imagesFolderName + "/"
                    let emptyProvider: (Int64, Int) throws -> Data = { _, _ in Data() }
                    
                    try archive.addEntry(
                        with: folderPath,
                        type: .directory,
                        uncompressedSize: 0,
                        provider: emptyProvider
                    )
                    
                    // 添加每张图片
                    for (index, imageURL) in imagePaths.enumerated() {
                        if index % 5 == 0 || index == imagePaths.count - 1 {
                            updateProgress("添加图片 \(index + 1)/\(imagePaths.count)...")
                        }
                        
                        let imageFileName = imageURL.lastPathComponent
                        let imageData = try Data(contentsOf: imageURL)
                        
                        // 将图片添加到ZIP的图片文件夹中
                        let entryPath = imagesFolderName + "/" + imageFileName
                        
                        let imageProvider: (Int64, Int) throws -> Data = { position, size in
                            let rangeStart = Int(position)
                            let rangeEnd = min(Int(position) + size, imageData.count)
                            return imageData.subdata(in: rangeStart..<rangeEnd)
                        }
                        
                        try archive.addEntry(
                            with: entryPath,
                            type: .file,
                            uncompressedSize: Int64(imageData.count),
                            provider: imageProvider
                        )
                    }
                }
                
                print("ZIP文件已创建: \(zipFileURL.path)")
                
                // 验证ZIP文件是否存在
                let zipExists = FileManager.default.fileExists(atPath: zipFileURL.path)
                print("ZIP文件是否存在: \(zipExists)")
                assert(zipExists, "ZIP文件未成功创建")
                
                updateProgress("导出完成!")
                
                // 在主线程返回结果
                DispatchQueue.main.async {
                    completion(zipFileURL)
                }
            } catch {
                print("处理文件时出错: \(error.localizedDescription)")
                updateProgress("导出失败: \(error.localizedDescription)")
                
                // 在主线程返回错误
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // 创建唯一的文件名（不带扩展名）
    private static func createUniqueFileName(baseName: String) -> String {
        // 移除文件扩展名
        var fileName = baseName
        if fileName.lowercased().hasSuffix(".xlsx") {
            fileName = String(fileName.dropLast(5))
        }
        
        // 添加数字格式的日期时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        // 返回格式化的文件名（不带扩展名）
        return "\(fileName)_\(dateString)"
    }
    
    // 分享Excel文件（现在是ZIP文件）
    static func shareExcelFile(from viewController: UIViewController, fileURL: URL) {
        // 验证文件路径和存在性
        print("准备分享的文件URL是: \(fileURL)")
        print("文件URL scheme: \(fileURL.scheme ?? "nil")")
        print("文件路径: \(fileURL.path)")
        print("文件扩展名: \(fileURL.pathExtension)")
        
        // 确保是文件URL
        guard fileURL.isFileURL else {
            print("错误：不是有效的文件URL")
            
            let alert = UIAlertController(
                title: "文件错误",
                message: "无效的文件URL格式",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("文件是否存在: \(fileExists)")
        
        // 检查文件是否存在
        if !fileExists {
            print("文件不存在: \(fileURL.path)")
            
            let alert = UIAlertController(
                title: "文件错误",
                message: "无法找到要分享的文件",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        // 尝试读取文件内容（验证文件是否可访问）
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? UInt64 ?? 0
            print("文件大小: \(fileSize) 字节")
            
            if fileSize == 0 {
                print("警告：文件大小为0")
            }
            
            // 直接分享文件URL
            DispatchQueue.main.async {
                // 使用活动视图控制器分享文件
                let activityVC = UIActivityViewController(
                    activityItems: [fileURL],
                    applicationActivities: nil
                )
                
                // 在iPad上需要设置弹出位置
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = viewController.view
                    popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                // 添加完成回调
                activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
                    if let error = error {
                        print("分享时出错: \(error.localizedDescription)")
                    } else if completed {
                        print("分享成功完成，活动类型: \(activityType?.rawValue ?? "未知")")
                    } else {
                        print("分享被取消或未完成")
                    }
                }
                
                viewController.present(activityVC, animated: true) {
                    print("分享界面已显示")
                }
            }
        } catch {
            print("无法访问文件: \(error.localizedDescription)")
            
            let alert = UIAlertController(
                title: "文件错误",
                message: "无法访问文件: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
        }
    }
} 