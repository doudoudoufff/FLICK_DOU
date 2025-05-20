import SwiftUI

enum SortOption: String, CaseIterable {
    case dateDesc = "日期（新到旧）"
    case dateAsc = "日期（旧到新）"
    case amountDesc = "金额（高到低）"
    case amountAsc = "金额（低到高）"
}

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
    @State private var refreshID = UUID()
    @State private var invoiceToDelete: (invoice: Invoice, project: Project)? = nil
    
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
                StatCardsSection(totalAmount: totalAmount, filteredInvoices: filteredInvoices)
                SearchFilterSection(searchText: $searchText, showingFilterSheet: $showingFilterSheet)
                InvoiceListSection(filteredInvoices: filteredInvoices, project: $project)
            }
            BottomAddButton(showingAddInvoice: $showingAddInvoice)
        }
        .id(refreshID)
        .onChange(of: project.invoices) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                refreshID = UUID()
            }
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
            NavigationView {
                AddInvoiceView(project: project)
                    .environmentObject(projectStore)
                    .onDisappear {
                        refreshID = UUID()
                    }
            }
        }
        .sheet(item: $editingInvoice) { invoice in
            if let index = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
                EditInvoiceView(invoice: $project.invoices[index], project: project, isPresented: Binding(get: { editingInvoice != nil }, set: { if !$0 { editingInvoice = nil } }))
                    .environmentObject(projectStore)
                    .onDisappear {
                        refreshID = UUID()
                    }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetSection(selectedCategory: $selectedCategory, selectedStatus: $selectedStatus, sortOption: $sortOption, showingFilterSheet: $showingFilterSheet)
        }
        .alert("确认删除", isPresented: Binding(
            get: { invoiceToDelete != nil },
            set: { if !$0 { invoiceToDelete = nil } }
        )) {
            Button("取消", role: .cancel) {
                invoiceToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let (invoice, project) = invoiceToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        projectStore.deleteInvoice(invoice, from: project)
                    }
                }
                invoiceToDelete = nil
            }
        } message: {
            Text("确定要删除这条开票信息吗？此操作不可撤销。")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DeleteInvoice"))) { notification in
            if let invoice = notification.userInfo?["invoice"] as? Invoice,
               let project = notification.userInfo?["project"] as? Project {
                invoiceToDelete = (invoice, project)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditInvoice"))) { notification in
            if let invoice = notification.userInfo?["invoice"] as? Invoice {
                editingInvoice = invoice
            }
        }
    }
}

// 统计卡片区
private struct StatCardsSection: View {
    let totalAmount: Double
    let filteredInvoices: [Invoice]
    var body: some View {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        StatCard(
                            title: "总金额",
                            value: String(format: "¥%.2f", totalAmount),
                            color: .blue,
                            icon: "banknote.fill"
                        )
                        StatCard(
                            title: "待开票",
                            value: "\(filteredInvoices.filter { $0.status == .pending }.count)",
                            color: .orange,
                            icon: "clock.fill"
                        )
                        StatCard(
                            title: "已开票",
                            value: "\(filteredInvoices.filter { $0.status == .completed }.count)",
                            color: .green,
                            icon: "checkmark.circle.fill"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                Divider().padding(.bottom, 8)
    }
}

// 搜索与筛选区
private struct SearchFilterSection: View {
    @Binding var searchText: String
    @Binding var showingFilterSheet: Bool
    var body: some View {
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
    }
}

// 列表区
private struct InvoiceListSection: View {
    let filteredInvoices: [Invoice]
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                        ForEach(filteredInvoices) { invoice in
                    if let index = project.invoices.firstIndex(where: { $0.id == invoice.id }) {
                        InvoiceRow(invoice: $project.invoices[index], project: project)
                            .environmentObject(projectStore)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .id(invoice.id)  // 添加 id 用于动画
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 80)
            .onAppear {
                scrollProxy = proxy
                }
            }
    }
}

// 底部添加按钮
private struct BottomAddButton: View {
    @Binding var showingAddInvoice: Bool
    var body: some View {
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
}

// 筛选弹窗
private struct FilterSheetSection: View {
    @Binding var selectedCategory: Invoice.Category?
    @Binding var selectedStatus: Invoice.Status?
    @Binding var sortOption: SortOption
    @Binding var showingFilterSheet: Bool
    var body: some View {
            NavigationView {
                Form {
                    Section("分类") {
                        Picker("选择分类", selection: $selectedCategory) {
                            Text("全部").tag(Optional<Invoice.Category>.none)
                        ForEach(Invoice.Category.allCases, id: \ .self) { category in
                                Text(category.rawValue).tag(Optional(category))
                            }
                        }
                    }
                    Section("状态") {
                        Picker("选择状态", selection: $selectedStatus) {
                            Text("全部").tag(Optional<Invoice.Status>.none)
                        ForEach(Invoice.Status.allCases, id: \ .self) { status in
                                Text(status.rawValue).tag(Optional(status))
                            }
                        }
                    }
                    Section("排序") {
                        Picker("排序方式", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \ .self) { option in
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

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
} 