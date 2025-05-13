import SwiftUI

struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectStore: ProjectStore
    let project: Project
    
    @State private var name = ""
    @State private var phone = ""
    @State private var idNumber = ""
    @State private var bankAccount = ""
    @State private var bankName = ""
    @State private var date = Date()
    @State private var amount = ""
    @State private var category = Invoice.Category.other
    @State private var status = Invoice.Status.pending
    
    // 增值税发票特有字段
    @State private var invoiceCode = ""
    @State private var invoiceNumber = ""
    @State private var sellerName = ""
    @State private var sellerTaxNumber = ""
    @State private var sellerAddress = ""
    @State private var sellerBankInfo = ""
    @State private var buyerAddress = ""
    @State private var buyerBankInfo = ""
    @State private var goodsText = ""
    @State private var totalAmount = ""
    
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingCameraPicker = false
    @State private var showingPhotoPicker = false
    @State private var invoiceImage: UIImage? = nil
    @State private var isRecognizing = false
    @State private var recognitionError: String? = nil
    
    // 百度OCR API配置
    private let API_KEY = "YmfPoAgGkQb8lkC2ufUGtdns" // 替换为您的API Key
    private let SECRET_KEY = "NsxTZq6v7xqhX3KEN4oMSRxIpjNeEpAa" // 替换为您的Secret Key
    
    @State private var showCopyToast = false
    @State private var copyToastMessage = ""
    
    @State private var showingSaveError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("姓名")
                            .foregroundColor(.primary)
                        Text("*")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    TextField("请输入姓名", text: $name)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.numberPad)
                    TextField("身份证号码", text: $idNumber)
                        .textInputAutocapitalization(.characters)
                }
                
                Section("银行信息") {
                    TextField("银行卡账号", text: $bankAccount)
                        .keyboardType(.numberPad)
                    TextField("开户行", text: $bankName)
                }
                
                Section("增值税发票信息") {
                    TextField("发票号码", text: $invoiceNumber)
                    
                    TextField("销售方名称", text: $sellerName)
                    TextField("销售方纳税人识别号", text: $sellerTaxNumber)
                    TextField("销售方地址电话", text: $sellerAddress)
                    TextField("销售方开户行及账号", text: $sellerBankInfo)
                    
                    TextField("购买方地址电话", text: $buyerAddress)
                    TextField("购买方开户行及账号", text: $buyerBankInfo)
                    
                    TextField("商品名称列表(用逗号分隔)", text: $goodsText)
                }
                
                Section("开票信息") {
                    TextField("开票金额", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    Picker("开票类别", selection: $category) {
                        ForEach(Invoice.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    
                    Picker("开票状态", selection: $status) {
                        ForEach(Invoice.Status.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                }
                
                Section {
                    Button {
                        showingCameraPicker = true
                    } label: {
                        Label("拍照识别发票", systemImage: "camera")
                    }
                }
                Section {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("相册识别发票", systemImage: "photo")
                    }
                }
                if isRecognizing {
                    ProgressView("正在识别发票...")
                }
                if let error = recognitionError {
                    Text(error).foregroundColor(.red)
                }
            }
            .navigationTitle("添加开票信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveInvoice(project)
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingCameraPicker) {
                ImagePicker(image: $invoiceImage, sourceType: .camera)
                    .onDisappear {
                        if let img = invoiceImage {
                            recognizeInvoiceImage(img)
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                ImagePicker(image: $invoiceImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if let img = invoiceImage {
                            recognizeInvoiceImage(img)
                        }
                    }
            }
            .overlay(
                Group {
                    if showCopyToast {
                        VStack {
                            Spacer()
                            Text(copyToastMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showCopyToast)
                    }
                }
            )
            .alert("保存失败", isPresented: $showingSaveError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("发票保存失败，请检查输入数据或重试。")
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty  // 只验证姓名为必填
    }
    
    private func saveInvoice(_ project: Project) {
        // 转换金额数据类型
        var amountValue: Double = 0
        if !amount.isEmpty {
            // 清除非数字字符
            let cleanAmount = amount.filter { "0123456789.".contains($0) }
            amountValue = Double(cleanAmount) ?? 0
        }
        
        var totalAmountValue: Double? = nil
        if !totalAmount.isEmpty {
            // 清除非数字字符
            let cleanTotal = totalAmount.filter { "0123456789.".contains($0) }
            totalAmountValue = Double(cleanTotal)
        }
        
        // 把商品列表处理为数组
        var goodsArray: [String]? = nil
        if !goodsText.isEmpty {
            goodsArray = goodsText.components(separatedBy: ",")
                                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                  .filter { !$0.isEmpty }
        }
        
        let invoice = Invoice(
            name: name,
            phone: phone,
            idNumber: idNumber,
            bankAccount: bankAccount,
            bankName: bankName,
            date: date,
            amount: amountValue,
            category: category,
            status: status,
            invoiceCode: invoiceCode.isEmpty ? nil : invoiceCode,
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            sellerName: sellerName.isEmpty ? nil : sellerName,
            sellerTaxNumber: sellerTaxNumber.isEmpty ? nil : sellerTaxNumber,
            sellerAddress: sellerAddress.isEmpty ? nil : sellerAddress,
            sellerBankInfo: sellerBankInfo.isEmpty ? nil : sellerBankInfo,
            buyerAddress: buyerAddress.isEmpty ? nil : buyerAddress,
            buyerBankInfo: buyerBankInfo.isEmpty ? nil : buyerBankInfo,
            goodsList: goodsArray,
            totalAmount: totalAmountValue
        )
        
        projectStore.addInvoice(invoice, to: project)
        if projectStore.lastError != nil {
            DispatchQueue.main.async {
                self.showingSaveError = true
            }
        } else {
        dismiss()
        }
    }
    
    // 获取access_token
    private func getAccessToken() async throws -> String {
        let url = URL(string: "https://aip.baidubce.com/oauth/2.0/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "client_credentials",
            "client_id": API_KEY,
            "client_secret": SECRET_KEY
        ]
        
        let formData = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
        
        request.httpBody = formData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return response.access_token
    }
    
    // 发票图像识别方法（使用百度OCR API）
    private func recognizeInvoiceImage(_ image: UIImage) {
        print("[发票识别] 开始识别图片...")
        
        // 1. 获取access_token
        Task {
            do {
                let token = try await getAccessToken()
                print("[发票识别] 获取token成功")
                
                // 2. 准备图片数据
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("[发票识别] 图片转换失败")
                    return
                }
                print("[发票识别] imageData字节数: \(imageData.count)")
                let base64Image = imageData.base64EncodedString()
                print("[发票识别] base64前100字符: \(base64Image.prefix(100))")
                // 3. base64字符串进行严格urlencode
                let encodedImage = base64Image.baiduURLEncoded
                print("[发票识别] urlencoded base64前100字符: \(encodedImage.prefix(100))")
                // 4. 准备请求
                let url = URL(string: "https://aip.baidubce.com/rest/2.0/ocr/v1/vat_invoice?access_token=\(token)")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                // 5. 构造body
                let postData = "image=\(encodedImage)&seal_tag=false"
                request.httpBody = postData.data(using: .utf8)
                
                // 6. 发送请求
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 打印原始HTTP响应状态码
                if let httpResponse = response as? HTTPURLResponse {
                    print("[发票识别] HTTP状态码: \(httpResponse.statusCode)")
                }
                
                // 打印原始返回内容
                if let rawString = String(data: data, encoding: .utf8) {
                    print("[发票识别] 原始返回: \(rawString)")
                }
                
                // 7. 解析响应
                let decoder = JSONDecoder()
                let result = try decoder.decode(OCRResponse.self, from: data)
                
                // 8. 处理识别结果
                if let wordsResult = result.wordsResult {
                    DispatchQueue.main.async {
                        // 单值字段
                        self.invoiceNumber = wordsResult.InvoiceNum ?? ""
                        // 日期
                        if let dateString = wordsResult.InvoiceDate, dateString.count >= 8 {
                            // 支持"2024年07月02日"或"20240702"
                            let dateStr = dateString.replacingOccurrences(of: "年", with: "-")
                                                    .replacingOccurrences(of: "月", with: "-")
                                                    .replacingOccurrences(of: "日", with: "")
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            if let date = formatter.date(from: dateStr) {
                                self.date = date
                            }
                        }
                        self.sellerName = wordsResult.SellerName ?? ""
                        self.sellerTaxNumber = wordsResult.SellerRegisterNum ?? ""
                        self.sellerAddress = wordsResult.SellerAddress ?? ""
                        self.sellerBankInfo = wordsResult.SellerBank ?? ""
                        self.buyerAddress = wordsResult.PurchaserAddress ?? ""
                        self.buyerBankInfo = wordsResult.PurchaserBank ?? ""
                        // 金额
                        if let amount = wordsResult.AmountInFiguers {
                            self.amount = amount
                        }
                        // 商品信息（取第一个）
                        if let goodsArr = wordsResult.CommodityName, let first = goodsArr.first?.word {
                            self.goodsText = first
                        }
                    }
                    print("[发票识别] 识别成功")
                } else {
                    print("[发票识别] 未识别到内容，error_code: \(result.error_code ?? -1), error_msg: \(result.error_msg ?? "无")")
                }
                
            } catch {
                print("[发票识别] 错误: \(error.localizedDescription)")
            }
        }
    }
    
    private func copyToClipboard(_ text: String, message: String) {
        UIPasteboard.general.string = text
        copyToastMessage = message
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyToast = false
        }
    }
}

// MARK: - API Response Models
struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let error: String?
    let error_description: String?
}

struct OCRResponse: Codable {
    let error_code: Int?
    let error_msg: String?
    let wordsResult: WordsResult?

    enum CodingKeys: String, CodingKey {
        case error_code
        case error_msg
        case wordsResult = "words_result"
    }
}

struct WordsResult: Codable {
    let PurchaserAddress: String?
    let PurchaserBank: String?
    let SellerRegisterNum: String?
    let SellerBank: String?
    let InvoiceType: String?
    let AmountInWords: String?
    let TotalTax: String?
    let InvoiceCode: String?
    let SellerAddress: String?
    let InvoiceNum: String?
    let InvoiceDate: String?
    let PurchaserRegisterNum: String?
    let TotalAmount: String?
    let PurchaserName: String?
    let SellerName: String?
    let AmountInFiguers: String?
    let Remarks: String?
    // 数组字段
    let CommodityName: [WordRowResult]?
    let CommodityNum: [WordRowResult]?
    let CommodityAmount: [WordRowResult]?
    let CommodityUnit: [WordRowResult]?
    let CommodityPrice: [WordRowResult]?
    let CommodityTaxRate: [WordRowResult]?
    let CommodityTax: [WordRowResult]?
}

struct WordRowResult: Codable {
    let row: String?
    let word: String?
}

// MARK: - 百度URL编码扩展
extension String {
    var baiduURLEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+")
        let encoded = self.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return encoded.replacingOccurrences(of: "+", with: "%2B")
    }
} 