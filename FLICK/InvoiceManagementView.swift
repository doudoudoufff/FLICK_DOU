import SwiftUI

struct InvoiceManagementView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @Binding var project: Project
    @State private var showingAddInvoice = false
    @State private var editingInvoice: Invoice? = nil
    @State private var searchText = ""
    @State private var selectedCategory: Invoice.Category? = nil
    @State private var selectedStatus: Invoice.Status? = nil
    @State private var showingFilterSheet = false
    @State private var sortOption: SortOption = .dateDesc
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "日期（新到旧）"
        case dateAsc = "日期（旧到新）"
        case amountDesc = "金额（高到低）"
        case amountAsc = "金额（低到高）"
    }
    
    var filteredInvoices: [Invoice] {
        var result = project.invoices
        
        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { invoice in
                invoice.name.localizedCaseInsensitiveContains(searchText) ||
                invoice.phone.contains(searchText) ||
                invoice.idNumber.contains(searchText)
            }
        }
        
        // 分类过滤
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // 状态过滤
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        
        // 排序
        switch sortOption {
        case .dateDesc:
            result.sort { $0.date > $1.date }
        case .dateAsc:
            result.sort { $0.date < $1.date }
        case .amountDesc:
            result.sort { $0.amount > $1.amount }
        case .amountAsc:
            result.sort { $0.amount < $1.amount }
        }
        
        return result
    }
    
    var totalAmount: Double {
        filteredInvoices.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. 统计卡片区
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        StatCard(
                            title: "总金额",
                            value: String(format: "¥%.2f", totalAmount),
                            icon: "banknote.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "待开票",
                            value: "\(filteredInvoices.filter { $0.status == .pending }.count)",
                            icon: "clock.fill",
                            color: .orange
                        )
                        StatCard(
                            title: "已开票",
                            value: "\(filteredInvoices.filter { $0.status == .completed }.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                Divider().padding(.bottom, 8)
                // 2. 搜索与筛选区
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索开票信息", text: $searchText)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                // 3. 列表区
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredInvoices) { invoice in
                            InvoiceRow(invoice: invoice, project: project, editingInvoice: $editingInvoice)
                                .background(Color(.systemBackground))
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 80) // 给底部按钮留空间
                }
            }
            // 4. 底部悬浮按钮
            HStack {
                Spacer()
                Button(action: { showingAddInvoice = true }) {
                    Text("添加新开票")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("开票管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddInvoice = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddInvoice) {
            AddInvoiceView(project: project)
                .environmentObject(projectStore)
        }
        .sheet(item: $editingInvoice) { invoice in
            EditInvoiceView(project: project, invoice: invoice)
                .environmentObject(projectStore)
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationView {
                Form {
                    Section("分类") {
                        Picker("选择分类", selection: $selectedCategory) {
                            Text("全部").tag(Optional<Invoice.Category>.none)
                            ForEach(Invoice.Category.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(Optional(category))
                            }
                        }
                    }
                    Section("状态") {
                        Picker("选择状态", selection: $selectedStatus) {
                            Text("全部").tag(Optional<Invoice.Status>.none)
                            ForEach(Invoice.Status.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(Optional(status))
                            }
                        }
                    }
                    Section("排序") {
                        Picker("排序方式", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    }
                }
                .navigationTitle("筛选")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingFilterSheet = false
                        }
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 