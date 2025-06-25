import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    @Environment(\.managedObjectContext) private var context
    @State private var showingEditProject = false
    @State private var showingAddTask = false
    @State private var showingLocationScoutingView = false
    @State private var showingBaiBai = false
    @State private var editingTask: ProjectTask? = nil
    @State private var refreshID = UUID()
    // 暂时保留但不使用发票相关的代码
    @State private var invoiceToDelete: (invoice: Invoice, project: Project)? = nil
    
    var body: some View {
        ScrollView {
            ProjectDetailMainContent(
                project: $project,
                projectStore: projectStore,
                showingEditProject: $showingEditProject,
                showingAddTask: $showingAddTask,
                showingLocationScoutingView: $showingLocationScoutingView,
                showingBaiBai: $showingBaiBai,
                editingTask: $editingTask,
                refreshID: $refreshID,
                invoiceToDelete: $invoiceToDelete
            )
        }
        .id(refreshID)
        .onChange(of: project.invoices) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                refreshID = UUID()
            }
        }
        .onChange(of: project.transactions) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                refreshID = UUID()
            }
        }
        /* 暂时隐藏发票功能
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
        */
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: $project, isPresented: $showingEditProject)
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationView {
                AddTaskView(
                    isPresented: $showingAddTask
                )
                .environmentObject(projectStore)
            }
            .presentationDetents([.height(500)])
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(
                isPresented: Binding(
                    get: { editingTask != nil },
                    set: { if !$0 { editingTask = nil } }
                ),
                task: Binding(
                    get: { task },
                    set: { newTask in
                        projectStore.updateTask(newTask, in: project)
                        editingTask = nil
                    }
                )
            )
        }
        .navigationDestination(isPresented: $showingBaiBai) {
            BaiBaiView(projectColor: project.color)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(project.name)
                .font(.headline)
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button("编辑") {
                showingEditProject = true
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Menu {
                NavigationLink {
                    BaiBaiView(projectColor: project.color)
                } label: {
                    Label("开机拜拜", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
            }
        }
    }
}

// 功能模块枚举
enum ProjectModule: String, CaseIterable {
    case tasks = "提醒我做"
    case finance = "账目管理"
    case scouting = "堪景"
    // case invoices = "开票信息"  // 暂时隐藏发票功能
    case accounts = "账户信息"
    
    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .finance: return "chart.line.uptrend.xyaxis"
        case .scouting: return "camera.viewfinder"
        // case .invoices: return "doc.text"  // 暂时隐藏发票功能
        case .accounts: return "creditcard"
        }
    }
}

struct ProjectDetailMainContent: View {
    @Binding var project: Project
    var projectStore: ProjectStore
    @Binding var showingEditProject: Bool
    @Binding var showingAddTask: Bool
    @Binding var showingLocationScoutingView: Bool
    @Binding var showingBaiBai: Bool
    @Binding var editingTask: ProjectTask?
    @Binding var refreshID: UUID
    // 暂时保留但不使用发票相关的参数
    @Binding var invoiceToDelete: (invoice: Invoice, project: Project)?
    
    @State private var selectedModule: ProjectModule = .tasks

    var body: some View {
        VStack(spacing: 16) {
            // 项目信息卡片（始终显示）
            ProjectInfoCard(project: $project)
            
            // 功能模块选择器
            moduleSelector
            
            // 根据选择的模块显示对应内容
            selectedModuleContent
        }
        .padding(.horizontal)
        .padding(.vertical)
    }
    
    // MARK: - 模块选择器
    private var moduleSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ProjectModule.allCases, id: \.self) { module in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedModule = module
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: module.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedModule == module ? .white : project.color)
                            
                            Text(module.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selectedModule == module ? .white : project.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedModule == module ? project.color : project.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - 选中模块的内容
    @ViewBuilder
    private var selectedModuleContent: some View {
        switch selectedModule {
        case .tasks:
            TaskListCard(
                project: $project,
                showingAddTask: $showingAddTask,
                editingTask: $editingTask
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            
        case .finance:
            TransactionSummaryCard(project: $project, projectStore: projectStore)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            
        case .scouting:
            LocationScoutingCard(project: $project)
                .environmentObject(projectStore)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            
        /* 暂时隐藏发票功能
        case .invoices:
            InvoiceListView(project: $project)
                .environmentObject(projectStore)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        */
            
        case .accounts:
            AccountListView(project: $project, showManagement: true)
                .environmentObject(projectStore)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
}

// 项目信息卡片
struct ProjectInfoCard: View {
    @Binding var project: Project
    @State private var showingStatusPicker = false
    
    // 根据项目状态获取颜色
    private var statusColor: Color {
        switch project.status {
        case .preProduction: return .blue
        case .production: return .orange
        case .postProduction: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
    
    // 根据项目状态获取图标
    private var statusIcon: String {
        switch project.status {
        case .preProduction: return "gear"
        case .production: return "film"
        case .postProduction: return "slider.horizontal.3"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 顶部标题和状态指示器
            HStack {
                Text("项目信息")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 可点击的状态指示器 - 点击后弹出选择器
                Button {
                    showingStatusPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 14))
                        
                        Text(project.status.rawValue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [statusColor, statusColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: statusColor.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .popover(isPresented: $showingStatusPicker) {
                    StatusPickerView(project: $project, isPresented: $showingStatusPicker)
                }
            }
            
            Divider()
                .background(Color(.systemGray4))
            
            // 项目详细信息
            VStack(alignment: .leading, spacing: 14) {
                // 项目开始时间
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开始时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(project.startDate.chineseStyleString())
                            .font(.subheadline)
                    }
                }
                
                // 导演信息
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导演")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(project.director.isEmpty ? "未设置" : project.director)
                            .font(.subheadline)
                            .foregroundColor(project.director.isEmpty ? .secondary : .primary)
                    }
                }
                
                // 制片信息
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("制片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(project.producer.isEmpty ? "未设置" : project.producer)
                            .font(.subheadline)
                            .foregroundColor(project.producer.isEmpty ? .secondary : .primary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// 开机拜拜按钮
struct BaiBaiButton: View {
    @Binding var project: Project
    @Binding var showingBaiBai: Bool
    
    var body: some View {
        Button {
            showingBaiBai = true
        } label: {
            Label("开机拜拜", systemImage: "sparkles.rectangle.stack.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(project.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}

// 任务列表卡片
struct TaskListCard: View {
    @Binding var project: Project
    @Binding var showingAddTask: Bool
    @Binding var editingTask: ProjectTask?
    @EnvironmentObject var projectStore: ProjectStore
    @State private var refreshID = UUID()
    @State private var showingTaskManagement = false
    
    private var taskProgress: Double {
        let totalTasks = project.tasks.count
        guard totalTasks > 0 else { return 0.0 }
        return Double(project.tasks.filter { $0.isCompleted }.count) / Double(totalTasks)
    }
    
    // 获取排序后的任务列表
    private var sortedTasks: [ProjectTask] {
        // 排序逻辑：
        // 1. 首先按完成状态分组：未完成任务在前，已完成任务在后
        // 2. 然后在各自组内按照截止日期排序
        return project.tasks.sorted { task1, task2 in
            // 首先按完成状态排序：未完成的排在前面
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            
            // 然后在各自分组内（已完成或未完成）按照截止日期排序
            return task1.dueDate < task2.dueDate
        }
    }
    
    // 判断是否为iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("提醒我做")
                    .font(.headline)
                
                Spacer()
                
                // 胶囊形UI按钮设计
                HStack(spacing: 8) {
                    // 添加任务按钮
                    Button(action: {
                        showingAddTask = true
                    }) {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    // 管理按钮
                    if isIPad {
                        Button(action: { showingTaskManagement = true }) {
                            Label("管理", systemImage: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundColor(.accentColor)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    } else {
                        NavigationLink(destination: TaskManagementView(project: $project).environmentObject(projectStore)) {
                            Label("管理", systemImage: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundColor(.accentColor)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 添加任务进度显示
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(taskProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(project.tasks.filter { $0.isCompleted }.count)/\(project.tasks.count)个任务")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: taskProgress)
                    .tint(project.color)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            if project.tasks.isEmpty {
                Text("暂无任务")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // 使用List显示前5个任务，支持滑动查看
                List {
                    // 使用排序后的任务列表，只显示前5个
                    ForEach(Array(sortedTasks.prefix(5)), id: \.id) { task in
                        TaskRow(task: task, project: project)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        projectStore.deleteTask(task, from: project)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: task.isCompleted)
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: sortedTasks)
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(min(project.tasks.count, 5)) * 100, 350)) // 限制高度
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                
                // 如果有超过5个任务，显示"查看更多"按钮
                if project.tasks.count > 5 {
                    NavigationLink(destination: TaskManagementView(project: $project).environmentObject(projectStore)) {
                        Text("查看全部\(project.tasks.count)个任务")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .id(refreshID)
        .onChange(of: project.tasks) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                refreshID = UUID()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingTaskManagement) {
            NavigationView {
                TaskManagementView(project: $project)
                    .environmentObject(projectStore)
            }
        }
    }
}

// 堪景模块卡片
struct LocationScoutingCard: View {
    @Binding var project: Project
    @EnvironmentObject var projectStore: ProjectStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("堪景")
                .font(.headline)
            
            Divider()
            
            // 直接显示进入堪景的按钮，不需要切换开关
                    NavigationLink {
                        LocationScoutingView(project: $project)
                            .environmentObject(projectStore)
                    } label: {
                Label("查看堪景图", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(project.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: .constant(Project(name: "测试项目")))
            .environmentObject(ProjectStore(context: PersistenceController.preview.container.viewContext))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// 状态选择器视图
struct StatusPickerView: View {
    @Binding var project: Project
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("更改项目状态")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Project.Status.allCases, id: \.self) { status in
                        Button {
                            project.status = status
                            isPresented = false
                        } label: {
                            HStack {
                                // 状态图标
                                ZStack {
                                    Circle()
                                        .fill(statusColor(for: status).opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: statusIcon(for: status))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(statusColor(for: status))
                                }
                                
                                // 状态名称
                                Text(status.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.leading, 10)
                                
                                Spacer()
                                
                                // 当前选中的状态
                                if project.status == status {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if status != Project.Status.allCases.last {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // 获取状态对应的颜色
    private func statusColor(for status: Project.Status) -> Color {
        switch status {
        case .preProduction: return .blue
        case .production: return .orange
        case .postProduction: return .purple
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
    
    // 获取状态对应的图标
    private func statusIcon(for status: Project.Status) -> String {
        switch status {
        case .preProduction: return "gear"
        case .production: return "film"
        case .postProduction: return "slider.horizontal.3"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
}

