import SwiftUI

// 日历拖拽状态管理
class ChineseCalendarState: ObservableObject {
    @Published var isDraggingTask = false
    @Published var dragStartDate: Date?
    @Published var dragCurrentDate: Date?
    @Published var taskDraftStartDate: Date?
    @Published var taskDraftEndDate: Date?
    @Published var isMultiDayDragMode = false // 添加跨天拖拽模式标志
    @Published var isScrollLocked = false // 日历内部滑动锁定状态
    @Published var isExternalScrollLocked = false // 外部页面滑动锁定状态
    @Published var multiTouchDetected = false // 多点触控检测
}

// 农历计算扩展
extension Calendar {
    func chineseLunarDay(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .chinese)
        formatter.dateFormat = "d"
        let day = Int(formatter.string(from: date)) ?? 1
        
        let dayNames = ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                       "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                       "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        
        return day < dayNames.count ? dayNames[day] : "\(day)"
    }
    
    func chineseLunarMonthAndDay(for date: Date) -> String {
        let chineseCalendar = Calendar(identifier: .chinese)
        let components = chineseCalendar.dateComponents([.month, .day], from: date)
        
        let monthNames = ["", "正月", "二月", "三月", "四月", "五月", "六月", 
                         "七月", "八月", "九月", "十月", "冬月", "腊月"]
        let dayNames = ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                       "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                       "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        
        let month = components.month ?? 1
        let day = components.day ?? 1
        
        // 如果是初一，显示月份
        if day == 1 && month < monthNames.count {
            return monthNames[month]
        } else if day < dayNames.count {
            return dayNames[day]
        } else {
            return "\(day)"
        }
    }
}

// 农历计算扩展

// 月份可见性监听
struct MonthVisibilityData: Equatable {
    let monthOffset: Int
    let month: Date
    let frame: CGRect
    
    static func == (lhs: MonthVisibilityData, rhs: MonthVisibilityData) -> Bool {
        return lhs.monthOffset == rhs.monthOffset &&
               lhs.month == rhs.month &&
               lhs.frame == rhs.frame
    }
}

struct MonthVisibilityPreference: PreferenceKey {
    static var defaultValue: MonthVisibilityData? = nil
    
    static func reduce(value: inout MonthVisibilityData?, nextValue: () -> MonthVisibilityData?) {
        if let next = nextValue() {
            value = next
        }
    }
}

struct ChineseCalendarView: View {
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let getTasksForCalendar: () -> [ProjectTask]
    let onExternalScrollLockChanged: ((Bool) -> Void)? // 添加外部滑动锁定状态回调
    @State private var currentMonth: Date
    @State private var scrollViewHeight: CGFloat = 420 // 可滚动区域的默认高度
    @State private var showDatePicker = false // 日期选择器显示状态
    @State private var visibleMonth: Date // 添加新的状态变量跟踪当前可见的月份
    @State private var datePickerDate = Date() // 日期选择器的独立状态
    @State private var stableReferenceDate = Date() // 稳定的参考日期，用于月份计算
    @State private var showingAddTask = false // 控制创建任务界面显示
    @State private var longPressedDate: Date? // 记录长按的日期
    @State private var taskStartDate: Date? // 保存任务开始日期
    @State private var taskEndDate: Date? // 保存任务结束日期
    @EnvironmentObject private var projectStore: ProjectStore // 添加项目存储环境对象
    
    // 使用 StateObject 管理拖拽状态
    @StateObject private var calendarState = ChineseCalendarState()
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    // 显示多个月以支持滚动
    private let monthsToShow = 12
    
    init(selectedDate: Binding<Date>, hasTasksOnDate: @escaping (Date) -> Bool, getTasksForCalendar: @escaping () -> [ProjectTask], onExternalScrollLockChanged: ((Bool) -> Void)? = nil) {
        self._selectedDate = selectedDate
        let now = Date()
        self._currentMonth = State(initialValue: now)
        self._visibleMonth = State(initialValue: now) // 初始化为当前真实日期
        self._stableReferenceDate = State(initialValue: now) // 设置稳定的参考日期
        self.hasTasksOnDate = hasTasksOnDate
        self.getTasksForCalendar = getTasksForCalendar
        self.onExternalScrollLockChanged = onExternalScrollLockChanged
    }
    
    var body: some View {
        VStack(spacing: 0) {
            scrollableCalendarView
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 0) // 去掉内边距，让日历更宽
        .onDisappear {
            // 视图消失时重置状态 - 移除所有调试信息
        }
        .onAppear {
            // 在视图出现时滚动到当前月份
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let today = Date()
                // 发送通知到ScrollViewReader
                NotificationCenter.default.post(name: Notification.Name("ScrollToCurrentMonth"), object: nil)
            }
        }
        .onChange(of: calendarState.isExternalScrollLocked) { newValue in
            // 通知父组件外部滑动锁定状态变化
            onExternalScrollLockChanged?(newValue)
            print("🔥 外部滑动锁定状态变化：\(newValue)")
        }
        .sheet(isPresented: $showingAddTask, onDismiss: {
            // 任务创建界面关闭时的处理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 延迟重置，给任务保存时间
                print("🔥 清理预览状态")
                calendarState.taskDraftStartDate = nil
                calendarState.taskDraftEndDate = nil
                calendarState.isMultiDayDragMode = false
                calendarState.isScrollLocked = false // 解锁内部滑动
                calendarState.isExternalScrollLocked = false // 解锁外部滑动
                calendarState.multiTouchDetected = false // 重置多点触控状态
                
                // 重置保存的日期
                taskStartDate = nil
                taskEndDate = nil
            }
        }) {
            NavigationView {
                AddTaskView(
                    isPresented: $showingAddTask,
                    presetStartDate: taskStartDate ?? longPressedDate,
                    presetEndDate: taskEndDate ?? longPressedDate
                )
                .environmentObject(projectStore)
            }
            .presentationDetents([.height(500)])
        }
        // 在最外层添加多点触控检测，用于解锁滑动
        .simultaneousGesture(
            MagnificationGesture(minimumScaleDelta: 0.01)
                .onChanged { _ in
                    if calendarState.isScrollLocked && !calendarState.multiTouchDetected {
                        print("🔥 检测到缩放手势（多点触控），解锁内部滑动")
                        calendarState.multiTouchDetected = true
                        calendarState.isScrollLocked = false // 只解锁内部滑动
                        // 保持 isExternalScrollLocked = true，外部页面仍然锁定
                    }
                }
        )
    }
    
    private var scrollableCalendarView: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                // 直接在这里构建headerView，而不是作为函数调用
            HStack {
                    // 日期选择器按钮 - 移到左侧
                    Button(action: {
                        showDatePicker.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Text(currentMonthYearString)
                                .font(.title3)
                                .fontWeight(.medium)
                        .foregroundColor(.primary)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showDatePicker) {
                        DatePickerView(
                            selectedDate: $datePickerDate, 
                            isPresented: $showDatePicker,
                            onConfirm: { selectedDate in
                                // 计算选中日期对应的monthOffset
                                let monthDiff = calendar.dateComponents([.month], from: stableReferenceDate, to: selectedDate).month ?? 0
                                
                                // 滚动到对应的月份
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    scrollProxy.scrollTo("month_\(monthDiff)", anchor: UnitPoint.center)
                                }
                                
                                // 更新当前月份和选中日期
                                withAnimation {
                                    currentMonth = selectedDate
                                    self.selectedDate = selectedDate
                                }
                            }
                        )
                }
                
                Spacer()
                
                    // 回到今天按钮 - 移到右侧，改为"回到今天"
                    Button(action: {
                        let today = Date()
                        
                        // 计算今天对应的monthOffset
                        let monthDiff = calendar.dateComponents([.month], from: stableReferenceDate, to: today).month ?? 0
                        
                        // 滚动到对应的月份
                        withAnimation(.easeInOut(duration: 0.8)) {
                            scrollProxy.scrollTo("month_\(monthDiff)", anchor: UnitPoint.center)
                        }
                        
                        // 同时更新选中的日期为今天
                        withAnimation {
                            selectedDate = today
                            currentMonth = today
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text("回到今天")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .zIndex(1) // 确保月份选择器始终在顶部
                
                weekdayHeaderView
                GeometryReader { scrollGeometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            // 使用稳定的参考日期计算月份，完全避免因状态变化导致重新渲染
                            ForEach(-monthsToShow/2..<monthsToShow/2+1, id: \.self) { monthOffset in
                                let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: stableReferenceDate)!
                                MonthView(
                                    month: targetMonth,
                                    selectedDate: $selectedDate,
                                    hasTasksOnDate: hasTasksOnDate,
                                    getTasksForCalendar: getTasksForCalendar,
                                    calendar: calendar,
                                    onLongPress: { longPressedDate in
                                        // 记录长按的日期
                                        print("🔥🔥🔥 收到长按回调：\(longPressedDate)")
                                        self.longPressedDate = longPressedDate
                                        
                                        // 单天任务：起止日期相同
                                        taskStartDate = longPressedDate
                                        taskEndDate = longPressedDate
                                        
                                        // 触发弹出创建任务界面
                                        print("🔥🔥🔥 准备弹出创建任务界面")
                                        withAnimation {
                                            showingAddTask = true
                                        }
                                        print("🔥 showingAddTask = \(showingAddTask)")
                                    },
                                    onDragStart: { startDate in
                                        print("🔥🔥🔥 开始拖拽任务：\(startDate)")
                                        calendarState.isDraggingTask = true
                                        calendarState.dragStartDate = startDate
                                        calendarState.dragCurrentDate = startDate
                                        calendarState.taskDraftStartDate = startDate
                                        calendarState.taskDraftEndDate = startDate
                                        calendarState.isMultiDayDragMode = false // 初始不是跨天模式
                                    },
                                    onDragChanged: { originalDate, translation in
                                        if calendarState.isDraggingTask {
                                            // 根据拖拽位置计算目标日期
                                            let targetDate = calculateDateFromDragPosition(originalDate: originalDate, translation: translation, month: targetMonth)
                                            if let target = targetDate, target != calendarState.dragCurrentDate {
                                                calendarState.dragCurrentDate = target
                                                
                                                // 更新任务草稿的开始和结束日期
                                                if let start = calendarState.dragStartDate {
                                                    let calendar = Calendar.current
                                                    let startDay = calendar.startOfDay(for: start)
                                                    let targetDay = calendar.startOfDay(for: target)
                                                    
                                                    if targetDay >= startDay {
                                                        calendarState.taskDraftStartDate = start
                                                        calendarState.taskDraftEndDate = target
                                                    } else {
                                                        calendarState.taskDraftStartDate = target
                                                        calendarState.taskDraftEndDate = start
                                                    }
                                                    
                                                    // 检查是否进入跨天模式
                                                    let isMultiDay = startDay != targetDay
                                                    if isMultiDay != calendarState.isMultiDayDragMode {
                                                        calendarState.isMultiDayDragMode = isMultiDay
                                                        
                                                        if isMultiDay {
                                                            print("🔥 拖拽进入跨天模式：\(calendarState.taskDraftStartDate!) -> \(calendarState.taskDraftEndDate!)")
                                                            // 锁定内部和外部滑动
                                                            calendarState.isScrollLocked = true
                                                            calendarState.isExternalScrollLocked = true
                                                        } else {
                                                            print("🔥 拖拽回到单天模式")
                                                            // 解锁内部和外部滑动
                                                            calendarState.isScrollLocked = false
                                                            calendarState.isExternalScrollLocked = false
                                                        }
                                                    }
                                                    
                                                    if isMultiDay {
                                                        print("🔥 跨天拖拽更新：\(calendarState.taskDraftStartDate!) -> \(calendarState.taskDraftEndDate!)")
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    onDragEnd: { endDate in
                                        print("🔥🔥🔥 拖拽结束：\(endDate)")
                                        
                                        if calendarState.isDraggingTask && calendarState.isMultiDayDragMode {
                                            // 只有在跨天模式下才创建跨天任务
                                            if let startDate = calendarState.taskDraftStartDate, let endDate = calendarState.taskDraftEndDate {
                                                // 保存起止日期到独立变量中
                                                taskStartDate = startDate
                                                taskEndDate = endDate
                                                longPressedDate = startDate
                                                
                                                print("🔥🔥🔥 将创建跨天任务：\(startDate) -> \(endDate)")
                                                
                                                // 创建任务时使用正确的开始和结束日期
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    withAnimation {
                                                        showingAddTask = true
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // 注意：暂时不重置拖拽状态，保持预览条显示
                                        calendarState.isDraggingTask = false
                                        calendarState.dragStartDate = nil
                                        calendarState.dragCurrentDate = nil
                                        // 保留 taskDraftStartDate 和 taskDraftEndDate 用于预览
                                        // calendarState.taskDraftStartDate = nil
                                        // calendarState.taskDraftEndDate = nil
                                        // calendarState.isMultiDayDragMode = false
                                        calendarState.isScrollLocked = false // 解锁内部滑动
                                        calendarState.isExternalScrollLocked = false // 解锁外部滑动
                                        calendarState.multiTouchDetected = false // 重置多点触控
                                    }
                                )
                                .id("month_\(monthOffset)") // 简化ID，便于滚动控制
                                .background(
                                    // 添加几何读取器来监听可见区域
                                    GeometryReader { monthGeometry in
                                        Color.clear.preference(
                                            key: MonthVisibilityPreference.self,
                                            value: MonthVisibilityData(
                                                monthOffset: monthOffset,
                                                month: targetMonth,
                                                frame: monthGeometry.frame(in: .named("scroll"))
                                            )
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 20)
                    }
                    .scrollDisabled(calendarState.isScrollLocked)
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(MonthVisibilityPreference.self) { monthData in
                        updateVisibleMonth(from: monthData, scrollGeometry: scrollGeometry)
                    }
                }
                .frame(maxWidth: .infinity)
                .id("scrollView") // 给ScrollView一个ID便于控制
                .environmentObject(calendarState) // 传递拖拽状态给子视图
                taskLegendView
            }
            .onAppear {
                // 设置通知监听，当收到滚动到当前月份的通知时执行
                let nc = NotificationCenter.default
                let observer = nc.addObserver(forName: Notification.Name("ScrollToCurrentMonth"), object: nil, queue: .main) { _ in
                    let today = Date()
                    let monthDiff = calendar.dateComponents([.month], from: stableReferenceDate, to: today).month ?? 0
                    
                    // 滚动到当前月份，使用延迟确保视图已完全加载
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollProxy.scrollTo("month_\(monthDiff)", anchor: .center)
                            
                            // 更新当前月份和选中日期
                            currentMonth = today
                        }
                    }
                }
                
                // 立即触发滚动到当前月份
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let today = Date()
                    let monthDiff = calendar.dateComponents([.month], from: stableReferenceDate, to: today).month ?? 0
                    
                    withAnimation(.easeInOut(duration: 0.5)) {
                        scrollProxy.scrollTo("month_\(monthDiff)", anchor: .center)
                    }
                }
            }
        }
    }
    
    private var weekdayHeaderView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                        .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            
            Rectangle()
                .frame(height: 0.3)
                .foregroundColor(Color(.systemGray3).opacity(0.4))
                .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .zIndex(0.9)
    }
    
    private var taskLegendView: some View {
        Group {
            if hasTasksInCurrentMonth() {
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(height: 0.3)
                        .foregroundColor(Color(.systemGray3).opacity(0.3))
                        .padding(.horizontal, 4)
                    
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 4)
                            .cornerRadius(2)
                        
                        Text("当日任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer().frame(width: 16)
                        
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 24, height: 8)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        
                        Text("跨天任务")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                }
            }
        }
    }
    
    // 月视图组件
    struct MonthView: View {
        let month: Date
        @Binding var selectedDate: Date
        let hasTasksOnDate: (Date) -> Bool
        let getTasksForCalendar: () -> [ProjectTask]
        let calendar: Calendar
        let onLongPress: (Date) -> Void // 添加长按回调参数
        let onDragStart: (Date) -> Void // 拖拽开始回调
        let onDragChanged: (Date, CGSize) -> Void // 拖拽变化回调，使用 CGSize
        let onDragEnd: (Date) -> Void // 拖拽结束回调
        
        var body: some View {
            VStack(spacing: 6) {
                // 月份标题
                Text(monthString)
                    .font(.headline)
                    .foregroundColor(Color(.darkGray))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                
                // 细线分隔
                Rectangle()
                    .frame(height: 0.3)
                    .foregroundColor(Color(.systemGray3).opacity(0.3))
                
                // 按周显示该月日历
                ForEach(0..<weeksInMonth.count, id: \.self) { weekIndex in
                    WeekView(
                        week: weeksInMonth[weekIndex],
                        selectedDate: $selectedDate,
                        hasTasksOnDate: hasTasksOnDate,
                        calendar: calendar,
                        tasks: getTasksForCalendar().filter { task in
                            isTaskInWeek(task, week: weeksInMonth[weekIndex])
                        },
                        onLongPress: onLongPress,
                        onDragStart: onDragStart,
                        onDragChanged: onDragChanged,
                        onDragEnd: onDragEnd
                    )
                }
            }
            .padding(.horizontal, 2) // 减少水平边距，让月视图更宽
            .padding(.bottom, 10)
            .background(Color.white)
        }
        
        private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: month)
        }
        
        // 按周分组的日期
        private var weeksInMonth: [[Date?]] {
            var weeks: [[Date?]] = []
            let daysArray = daysInMonth
            
            var currentWeek: [Date?] = []
            for (index, date) in daysArray.enumerated() {
                currentWeek.append(date)
                
                if (index + 1) % 7 == 0 {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
            }
            
            // 如果最后有不足7天的一周
            if !currentWeek.isEmpty {
                while currentWeek.count < 7 {
                    currentWeek.append(nil)
                }
                weeks.append(currentWeek)
            }
            
            return weeks
        }
        
        // 该月的所有日期
    private var daysInMonth: [Date?] {
            let range = calendar.range(of: .day, in: .month, for: month)!
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
        // 检查任务是否在本周内
        private func isTaskInWeek(_ task: ProjectTask, week: [Date?]) -> Bool {
            let weekDates = week.compactMap { $0 }
            guard let weekStart = weekDates.first,
                  let weekEnd = weekDates.last else {
                return false
            }
            
            let taskStartDay = calendar.startOfDay(for: task.startDate)
            let taskEndDay = calendar.startOfDay(for: task.dueDate)
            
            // 任务的开始日期或结束日期在本周内，或者任务跨越本周
            return (taskStartDay <= weekEnd && taskEndDay >= weekStart)
        }
    }
    
    // 检查当前月是否有任务
    private func hasTasksInCurrentMonth() -> Bool {
        let tasks = getTasksForCalendar()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return tasks.contains { task in
            let taskEndDay = calendar.startOfDay(for: task.dueDate)
            let taskStartDay = calendar.startOfDay(for: task.startDate)
            
            return (taskStartDay <= endOfMonth && taskEndDay >= startOfMonth)
        }
    }
    
    private var currentMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentMonth)
    }
    
    // 更新可见月份
    private func updateVisibleMonth(from monthData: MonthVisibilityData?, scrollGeometry: GeometryProxy) {
        guard let data = monthData else { return }
        
        let scrollViewHeight = scrollGeometry.size.height
        let scrollViewCenter = scrollViewHeight / 2
        
        // 检查月份是否在视口中心附近
        let monthTop = data.frame.minY
        let monthBottom = data.frame.maxY
        let monthCenter = (monthTop + monthBottom) / 2
        
        // 如果月份中心在滚动视图中心附近，就更新当前月份
        if abs(monthCenter - scrollViewCenter) < scrollViewHeight / 4 {
            DispatchQueue.main.async {
                if !Calendar.current.isDate(self.currentMonth, equalTo: data.month, toGranularity: .month) {
                    self.currentMonth = data.month
                }
            }
        }
    }
    
    // 根据拖拽位置计算目标日期
    private func calculateDateFromDragPosition(originalDate: Date, translation: CGSize, month: Date) -> Date? {
        // 简化版本：根据水平拖拽距离计算日期偏移
        let dayWidth: CGFloat = 50 // 大约的日期单元格宽度
        let dayOffset = Int(translation.width / dayWidth)
        
        // 根据垂直拖拽计算周偏移
        let weekHeight: CGFloat = 80 // 大约的周高度
        let weekOffset = Int(translation.height / weekHeight)
        
        let totalDayOffset = dayOffset + (weekOffset * 7)
        
        if let targetDate = calendar.date(byAdding: .day, value: totalDayOffset, to: originalDate) {
            return targetDate
        }
        
        return nil
    }
}

// 按周显示的视图组件
struct WeekView: View {
    let week: [Date?]
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let calendar: Calendar
    let tasks: [ProjectTask]
    let onLongPress: (Date) -> Void // 添加长按回调参数
    let onDragStart: (Date) -> Void // 拖拽开始回调
    let onDragChanged: (Date, CGSize) -> Void // 拖拽变化回调，使用 CGSize
    let onDragEnd: (Date) -> Void // 拖拽结束回调
    
    // 从父组件传递拖拽状态
    @EnvironmentObject private var calendarState: ChineseCalendarState
    
    var body: some View {
        VStack(spacing: 0) {
            // 日期行
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(0..<7), id: \.self) { index in
                        if let date = week[index] {
                            DayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                hasTasks: hasTasksOnDate(date),
                                selectedDate: $selectedDate,
                                onLongPress: onLongPress,
                                onDragStart: onDragStart,
                                onDragChanged: onDragChanged,
                                onDragEnd: onDragEnd
                            )
                            .frame(maxWidth: .infinity) // 确保与星期标题宽度一致
                        } else {
                            Color.clear
                                .frame(height: 54) // 与DayCell高度保持一致
                                .frame(maxWidth: .infinity) // 确保空白区域也占用相同宽度
                        }
                    }
                }
            }
            .frame(height: 54) // 固定GeometryReader的高度
            .coordinateSpace(name: "weekView")
            
            // 任务时间线区域 - 显示所有任务 + 临时创建的任务条
            ZStack(alignment: .top) {
                // 原有任务
                if !tasks.isEmpty {
                    // 计算所有任务的高度需求
                    let allTasksCount = min(4, tasks.count) // 最多显示4个任务
                    let dynamicHeight = CGFloat(16 + allTasksCount * 20)
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: dynamicHeight)
                    
                    WeekTasksView(
                        week: week,
                        tasks: tasks,
                        calendar: calendar
                    )
                    .padding(.top, 6)
                }
                
                // 拖拽中的临时任务条
                if shouldShowDragTask() {
                    DragTaskPreview(
                        week: week,
                        startDate: calendarState.taskDraftStartDate!,
                        endDate: calendarState.taskDraftEndDate!,
                        calendar: calendar
                    )
                    .padding(.top, 6)
                }
            }
            
            // 添加淡色分隔线
            Rectangle()
                .fill(Color(.systemGray5).opacity(0.5))
                .frame(height: 0.5)
                .padding(.horizontal, 8)
                .padding(.top, 4)
        }
        .padding(.horizontal, 2) // 减少水平边距，让内容更宽
        .padding(.vertical, 3) // 统一上下间距
    }
    
    // 检查是否应该在这一周显示拖拽任务条
    private func shouldShowDragTask() -> Bool {
        guard calendarState.isMultiDayDragMode, // 只有在跨天模式下才显示
              let startDate = calendarState.taskDraftStartDate,
              let endDate = calendarState.taskDraftEndDate else {
            return false
        }
        
        // 只有真正的跨天任务才显示拖拽预览
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        
        // 如果开始和结束是同一天，不显示拖拽预览
        if startDay == endDay {
            return false
        }
        
        let weekDates = week.compactMap { $0 }
        guard let weekStart = weekDates.first,
              let weekEnd = weekDates.last else {
            return false
        }
        
        let weekStartDay = calendar.startOfDay(for: weekStart)
        let weekEndDay = calendar.startOfDay(for: weekEnd)
        
        // 检查任务是否与本周有交集
        return !(endDay < weekStartDay || startDay > weekEndDay)
    }
}

// 周任务时间线视图
struct WeekTasksView: View {
    let week: [Date?]
    let tasks: [ProjectTask]
    let calendar: Calendar
    
    // 不同颜色系的淡色版本 - 稍微浓一些
    private let taskColors: [Color] = [
        Color(hex: "b8e0f5") ?? .blue,     // 稍浓的蓝色
        Color(hex: "c0ebc0") ?? .green,     // 稍浓的绿色
        Color(hex: "ffb8b8") ?? .red,       // 稍浓的红色
        Color(hex: "ffe599") ?? .yellow,    // 稍浓的黄色
        Color(hex: "d6b8ff") ?? .purple,    // 稍浓的紫色
        Color(hex: "ffcc99") ?? .orange     // 稍浓的橙色
    ]
    
    // 对应的深色字体颜色
    private let textColors: [Color] = [
        Color(hex: "265474") ?? .blue,     // 深蓝色
        Color(hex: "2d5a3d") ?? .green,     // 深绿色
        Color(hex: "8b3a3a") ?? .red,     // 深红色
        Color(hex: "8b7355") ?? .brown,     // 深黄色/棕色
        Color(hex: "5a3d8b") ?? .purple,     // 深紫色
        Color(hex: "8b5a3d") ?? .brown      // 深橙色/棕色
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(tasksToDisplay(in: geometry)) { taskData in
                TaskTimelineView(
                    task: taskData.task,
                    startPosition: taskData.startPosition,
                    length: taskData.length,
                    color: taskData.color,
                    textColor: taskData.textColor,
                    offsetIndex: taskData.offsetIndex
                )
            }
        }
    }
    
    // 任务显示数据结构
    private struct TaskDisplayData: Identifiable {
        let id: UUID
        let task: ProjectTask
        let startPosition: CGPoint
        let length: Int
        let color: Color
        let textColor: Color
        let offsetIndex: Int
    }
    
    // 计算要显示的任务
    private func tasksToDisplay(in geometry: GeometryProxy) -> [TaskDisplayData] {
        var result: [TaskDisplayData] = []
        let weekDates = week.compactMap { $0 }
        
        if weekDates.isEmpty { return [] }
        
        // 记录每行已被占用的位置
        var usedOffsets: Set<Int> = []
        
        let cellWidth = geometry.size.width / 7
        
        // 处理所有任务，包括单天任务
        let allTasks = tasks.sorted(by: { $0.durationDays > $1.durationDays })
        
        for (index, task) in allTasks.enumerated() {
            // 计算任务在本周的开始和结束日期
            let taskStartDay = calendar.startOfDay(for: task.startDate)
            let taskEndDay = calendar.startOfDay(for: task.dueDate)
            
            // 获取本周的开始和结束日期
            guard let weekStart = weekDates.first,
                  let weekEnd = weekDates.last else {
                continue
            }
            
            // 如果任务不在本周范围内，跳过
            if taskEndDay < calendar.startOfDay(for: weekStart) || 
               taskStartDay > calendar.startOfDay(for: weekEnd) {
                continue
            }
            
            // 计算任务在本周内的开始位置
            let effectiveStartDate = max(taskStartDay, calendar.startOfDay(for: weekStart))
            let effectiveEndDate = min(taskEndDay, calendar.startOfDay(for: weekEnd))
            
            // 找出开始和结束日期在周内的索引
            var startIndex = -1
            var endIndex = -1
            
            for (i, weekDate) in weekDates.enumerated() {
                if calendar.isDate(calendar.startOfDay(for: weekDate), inSameDayAs: effectiveStartDate) {
                    startIndex = i
                }
                if calendar.isDate(calendar.startOfDay(for: weekDate), inSameDayAs: effectiveEndDate) {
                    endIndex = i
                }
            }
            
            // 如果找不到对应索引，跳过
            if startIndex == -1 || endIndex == -1 {
                continue
            }
            
            // 计算长度
            let length = endIndex - startIndex + 1
            
            // 找一个未占用的垂直偏移
            var offsetIndex = 0
            while usedOffsets.contains(offsetIndex) {
                offsetIndex += 1
            }
            usedOffsets.insert(offsetIndex)
            
            let taskData = TaskDisplayData(
                id: task.id,
                task: task,
                startPosition: CGPoint(x: CGFloat(startIndex) * cellWidth, y: CGFloat(12 + offsetIndex * 20)),
                length: length,
                color: taskColors[index % taskColors.count],
                textColor: textColors[index % textColors.count],
                offsetIndex: offsetIndex
            )
            
            result.append(taskData)
        }
        
        return result
    }
}

// 任务时间线视图
struct TaskTimelineView: View {
    let task: ProjectTask
    let startPosition: CGPoint
    let length: Int
    let color: Color
    let textColor: Color
    let offsetIndex: Int
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 7
            let isCompleted = task.isCompleted
            
            ZStack(alignment: .leading) {
                // 时间线背景
                Rectangle()
                    .fill(isCompleted ? Color.gray.opacity(0.3) : color)
                    .frame(
                        width: max(CGFloat(length) * cellWidth - 1, cellWidth * 1.15), // 增加到115%确保显示3个字
                        height: 18
                    )
                    .cornerRadius(9) // 增加圆角
                
                // 任务内容 - 恢复图标
                HStack(spacing: 2) {
                    // 恢复小图标
                    Image(systemName: "calendar")
                        .font(.system(size: 8, weight: .light))
                        .foregroundColor(isCompleted ? Color.gray : textColor)
                    
                    Text(task.title)
                        .font(.system(size: length == 1 ? 9 : 10, weight: .bold)) // 为了适应更多文字，稍微缩小字体
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(isCompleted ? Color.gray : textColor)
                        .strikethrough(isCompleted, color: isCompleted ? Color.gray : Color.clear)
                    
                    Spacer()
                }
                .padding(.leading, 2)
                .padding(.trailing, 2)
                .frame(maxWidth: max(CGFloat(length) * cellWidth - 4, cellWidth * 1.15))
            }
            .position(
                x: startPosition.x + (max(CGFloat(length) * cellWidth - 1, cellWidth * 1.15)) / 2,
                y: startPosition.y
            )
        }
    }
}

// 日期单元格视图
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasTasks: Bool
    @Binding var selectedDate: Date
    let onLongPress: (Date) -> Void // 添加长按回调
    let onDragStart: (Date) -> Void // 拖拽开始回调
    let onDragChanged: (Date, CGSize) -> Void // 拖拽变化回调，使用 CGSize
    let onDragEnd: (Date) -> Void // 拖拽结束回调
    @State private var isLongPressing = false // 添加长按状态
    @State private var isDragging = false // 添加拖拽状态
    @State private var isMultiDayDrag = false // 添加跨天拖拽状态
    @State private var dragStartTime = Date() // 记录拖拽开始时间
    @State private var pressStartTime = Date() // 记录按下开始时间
    @State private var longPressTimer: Timer? // 长按计时器
    @State private var isPressActive = false // 是否正在按下
    
    @EnvironmentObject private var calendarState: ChineseCalendarState // 添加拖拽状态环境对象
    
    private let calendar = Calendar.current
    private let dragThreshold: CGFloat = 60 // 增加拖拽阈值：超过60像素才认为是跨天任务
    private let longPressMinDuration: TimeInterval = 1.0 // 增加最小长按时间到1秒
    private let dragStartThreshold: CGFloat = 20 // 开始拖拽的最小距离
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // 背景圆圈
                Group {
                    if isMultiDayDrag {
                        // 跨天拖拽状态：简洁的蓝色背景 + 加粗边框
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                                    .frame(width: 38, height: 38)
                            )
                            .scaleEffect(1.1)
                    } else if isDragging {
                        // 普通拖拽状态：绿色背景
                        Circle()
                            .fill(Color.green)
                            .frame(width: 38, height: 38)
                            .scaleEffect(1.2)
                    } else if isLongPressing {
                        // 长按状态：橙色背景（准备创建单天任务）
                    Circle()
                            .fill(Color.orange)
                        .frame(width: 36, height: 36)
                            .scaleEffect(1.1)
                    } else if isSelected {
                        // 选中样式：简洁的圆形背景
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                } else if isToday {
                        // 今天的样式：细边框圆形
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 32, height: 32)
                            .background(
                    Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 32, height: 32)
                            )
                    }
                }
                
                // 日期数字 - 居中显示
                    Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, design: .rounded))
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundColor(isDragging || isLongPressing || isMultiDayDrag ? .white : (isSelected ? .white : (isToday ? Color.blue : .primary)))
            }
            
            // 农历显示
            Text(calendar.chineseLunarMonthAndDay(for: date))
                .font(.system(size: 9, weight: .light))
                .foregroundColor(isSelected ? .blue : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 54) // 增加高度以适应农历
        .frame(maxWidth: .infinity) // 占满可用宽度
        .contentShape(Rectangle()) // 确保整个区域可以接收手势
        .scaleEffect(isMultiDayDrag ? 1.2 : (isDragging ? 1.1 : (isLongPressing ? 1.05 : 1.0)))
        .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
        .animation(.easeInOut(duration: 0.1), value: isMultiDayDrag)
        .onTapGesture {
            // 这个手势现在作为备用，主要逻辑在DragGesture中处理
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0) // 设置最小距离为0，这样可以捕获所有触摸事件
                .onChanged { value in
                    if !isPressActive {
                        // 按下开始
                        isPressActive = true
                        pressStartTime = Date()
                        print("🔥 按下开始：\(date)")
                        
                        // 立即给予轻微震动反馈，表示开始检测长按
                        let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                        lightFeedback.prepare()
                        lightFeedback.impactOccurred()
                        
                        // 启动长按计时器
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressMinDuration, repeats: false) { _ in
                            if isPressActive && !isDragging {
                                // 达到长按时间且没有拖拽
                                print("🔥 长按触发：\(date)")
                                isLongPressing = true
                                
                                // 更强的震动反馈表示长按成功
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                                
                                print("🔥🔥🔥 长按震动反馈完成")
                            }
                        }
                    }
                    
                    // 检查用户是否在快速滑动（普通滑动日历的意图）
                    let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    let pressDuration = Date().timeIntervalSince(pressStartTime)
                    
                    // 如果用户快速移动，优先让ScrollView处理滑动
                    if pressDuration < 0.2 && dragDistance > 20 && !isLongPressing {
                        print("🔥 检测到快速滑动，让ScrollView处理")
                        // 取消计时器，但不重置状态，让手势继续但不拦截
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        return
                    }
                    
                    // 检查是否开始拖拽 - 只有在长按触发后才允许拖拽创建任务
                    if isPressActive && isLongPressing && !isDragging {
                        if dragDistance > dragStartThreshold {
                            print("🔥 开始拖拽：\(date)")
                            isDragging = true
                            onDragStart(date)
                        }
                    }
                    
                    // 处理拖拽 - 只有在拖拽状态下才处理
                    if isDragging {
                        // 检查是否超过跨天拖拽阈值
                        if !isMultiDayDrag && dragDistance > dragThreshold {
                            print("🔥 进入跨天拖拽模式：\(date)")
                            isMultiDayDrag = true
                            
                            // 强烈震动表示进入跨天模式
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                        }
                        
                        print("🔥 拖拽中，距离：\(dragDistance)，位置：\(value.translation)")
                        onDragChanged(date, value.translation)
                    }
                }
                .onEnded { value in
                    print("🔥 按下结束：\(date)")
                    
                    // 取消长按计时器
                    longPressTimer?.invalidate()
                    longPressTimer = nil
                    
                    let pressDuration = Date().timeIntervalSince(pressStartTime)
                    let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                    
                    if isDragging {
                        // 处理拖拽结束
                        print("🔥🔥🔥 拖拽结束：\(date)，最终距离：\(dragDistance)")
                        
                        // 轻微震动表示拖拽结束
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        // 只有跨天拖拽才调用 onDragEnd
                        if isMultiDayDrag {
                            print("🔥🔥🔥 创建跨天任务")
                            onDragEnd(date)
                        } else {
                            print("🔥🔥🔥 拖拽距离不足，创建单天任务")
                            onLongPress(date)
                        }
                        
                        // 重置所有拖拽状态
                        isDragging = false
                        isMultiDayDrag = false
                    } else if isLongPressing {
                        // 处理长按结束（没有拖拽）
                        print("🔥🔥🔥 长按结束：\(date)")
                        print("🔥🔥🔥 创建单天任务：\(date)")
                        
                        // 轻微震动表示创建单天任务
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        onLongPress(date)
                    } else if isPressActive {
                        // 处理单击 - 只有在没有长按且拖拽距离很小的情况下才是单击
                        if pressDuration < longPressMinDuration && dragDistance < 10 {
                            print("🔥 短按日期：\(date)")
                            withAnimation {
                                selectedDate = date
                            }
                        } else {
                            print("🔥 普通滑动，不执行任何操作")
                        }
                    }
                    
                    // 重置所有状态
                    isPressActive = false
                    isLongPressing = false
                    isDragging = false
                    isMultiDayDrag = false
                }
        )
        .onDisappear {
            // 清理计时器
            longPressTimer?.invalidate()
            longPressTimer = nil
        }
    }
}

// 日期选择器视图
struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @State private var tempDate: Date
    let onConfirm: (Date) -> Void
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>, onConfirm: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
        self.onConfirm = onConfirm
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("选择日期", selection: $tempDate, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Button(action: {
                    selectedDate = tempDate
                    isPresented = false
                    onConfirm(tempDate)
                }) {
                    Text("确定")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitle("选择日期", displayMode: .inline)
            .navigationBarItems(trailing: Button("取消") {
                isPresented = false
            })
        }
    }
}

// 拖拽任务预览组件
struct DragTaskPreview: View {
    let week: [Date?]
    let startDate: Date
    let endDate: Date
    let calendar: Calendar
    
    var body: some View {
        GeometryReader { geometry in
            if let taskData = calculateDragTaskDisplay(in: geometry) {
                ZStack(alignment: .leading) {
                    // 拖拽任务条背景 - 使用淡蓝色背景和虚线边框
                    Rectangle()
                        .fill(Color.blue.opacity(0.15)) // 淡蓝色背景
                        .frame(
                            width: taskData.width,
                            height: 18
                        )
                        .cornerRadius(9)
                        .overlay(
                            // 虚线边框
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        )
                    
                    // 任务内容
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8, weight: .light))
                            .foregroundColor(.blue)
                        
                        Text(taskData.dayCount > 1 ? "跨天任务" : "单天任务")
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        // 显示天数
                        if taskData.dayCount > 1 {
                            Text("\(taskData.dayCount)天")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                    .padding(.leading, 2)
                    .padding(.trailing, 2)
                    .frame(maxWidth: taskData.width)
                }
                .position(
                    x: taskData.startX + taskData.width / 2,
                    y: 12 // 放在顶部位置
                )
                .animation(.easeInOut(duration: 0.1), value: taskData.width)
                .animation(.easeInOut(duration: 0.1), value: taskData.startX)
            }
        }
    }
    
    // 任务显示数据
    private struct DragTaskDisplayData {
        let startX: CGFloat
        let width: CGFloat
        let dayCount: Int
    }
    
    // 计算拖拽任务的显示位置和大小
    private func calculateDragTaskDisplay(in geometry: GeometryProxy) -> DragTaskDisplayData? {
        let weekDates = week.compactMap { $0 }
        guard !weekDates.isEmpty else { return nil }
        
        let cellWidth = geometry.size.width / 7
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        
        // 找出开始和结束日期在本周的索引
        var startIndex = -1
        var endIndex = -1
        
        for (i, weekDate) in weekDates.enumerated() {
            let weekDay = calendar.startOfDay(for: weekDate)
            if weekDay == startDay || (startIndex == -1 && weekDay > startDay) {
                startIndex = max(0, startDay <= weekDay ? i : i - 1)
            }
            if weekDay == endDay {
                endIndex = i
            } else if endIndex == -1 && weekDay > endDay {
                endIndex = i - 1
            }
        }
        
        // 如果任务在本周之前开始，从第一天开始
        if startIndex == -1 && startDay < calendar.startOfDay(for: weekDates.first!) {
            startIndex = 0
        }
        
        // 如果任务在本周之后结束，到最后一天结束
        if endIndex == -1 && endDay > calendar.startOfDay(for: weekDates.last!) {
            endIndex = 6
        }
        
        guard startIndex >= 0 && endIndex >= 0 && startIndex <= endIndex else {
            return nil
        }
        
        let width = CGFloat(endIndex - startIndex + 1) * cellWidth - 2
        let startX = CGFloat(startIndex) * cellWidth + 1
        
        // 计算总天数（不仅仅是本周的天数）
        let totalDays = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        let dayCount = totalDays + 1
        
        return DragTaskDisplayData(
            startX: startX,
            width: max(width, cellWidth * 0.8),
            dayCount: dayCount
        )
    }
}


