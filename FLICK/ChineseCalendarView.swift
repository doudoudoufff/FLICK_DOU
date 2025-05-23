import SwiftUI

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

// 月份位置preference key
struct MonthPositionPreference: PreferenceKey {
    static var defaultValue: [MonthPosition] = []
    
    static func reduce(value: inout [MonthPosition], nextValue: () -> [MonthPosition]) {
        value.append(contentsOf: nextValue())
    }
}

struct MonthPosition: Equatable {
    let month: Date
    let frame: CGRect
}

struct ChineseCalendarView: View {
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let getTasksForCalendar: () -> [ProjectTask]
    @State private var currentMonth: Date
    @State private var scrollViewHeight: CGFloat = 420 // 可滚动区域的默认高度
    @State private var showDatePicker = false // 日期选择器显示状态
    @State private var visibleMonth: Date // 添加新的状态变量跟踪当前可见的月份
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    // 显示多个月以支持滚动
    private let monthsToShow = 12
    
    init(selectedDate: Binding<Date>, hasTasksOnDate: @escaping (Date) -> Bool, getTasksForCalendar: @escaping () -> [ProjectTask]) {
        self._selectedDate = selectedDate
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
        self._visibleMonth = State(initialValue: selectedDate.wrappedValue) // 初始化可见月份
        self.hasTasksOnDate = hasTasksOnDate
        self.getTasksForCalendar = getTasksForCalendar
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            weekdayHeaderView
            scrollableCalendarView
            taskLegendView
        }
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 0) // 去掉内边距，让日历更宽
    }
    
    // 分解为更小的视图组件
    private var headerView: some View {
        HStack {
            Spacer()
            
            // 日期选择器按钮 - 简化设计
            Button(action: {
                showDatePicker.toggle()
            }) {
                HStack(spacing: 6) {
                    Text(visibleMonthYearString)
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
                DatePickerView(selectedDate: $currentMonth, isPresented: $showDatePicker)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .zIndex(1) // 确保月份选择器始终在顶部
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
    
    private var scrollableCalendarView: some View {
        ScrollViewReader { scrollProxy in
            GeometryReader { scrollGeometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        // 生成多个月的视图以支持滚动
                        ForEach(-monthsToShow/2..<monthsToShow/2+1, id: \.self) { monthOffset in
                            let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: currentMonth)!
                            MonthView(
                                month: targetMonth,
                                selectedDate: $selectedDate,
                                hasTasksOnDate: hasTasksOnDate,
                                getTasksForCalendar: getTasksForCalendar,
                                calendar: calendar
                            )
                            .id(monthOffset) // 使用月份偏移作为ID，确保月份变化时视图更新
                            .background(
                                GeometryReader { monthGeometry in
                                    Color.clear
                                        .preference(
                                            key: MonthPositionPreference.self,
                                            value: [MonthPosition(
                                                month: targetMonth,
                                                frame: monthGeometry.frame(in: .named("scroll"))
                                            )]
                                        )
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(MonthPositionPreference.self) { positions in
                    // 找到最接近屏幕中心的月份
                    let scrollCenter = scrollGeometry.size.height / 2
                    
                    if let closestMonth = positions.min(by: { position1, position2 in
                        let distance1 = abs(position1.frame.midY - scrollCenter)
                        let distance2 = abs(position2.frame.midY - scrollCenter)
                        return distance1 < distance2
                    }) {
                        if !calendar.isDate(visibleMonth, equalTo: closestMonth.month, toGranularity: .month) {
                            visibleMonth = closestMonth.month
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                // 应用启动时自动滚动到当前月
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollProxy.scrollTo(0, anchor: .top) // 滚动到当前月
                    }
                }
            }
            .onChange(of: currentMonth) { newValue in
                // 当通过日期选择器改变月份时，滚动到相应位置并更新可见月份
                visibleMonth = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollProxy.scrollTo(0, anchor: .top) // 滚动到当前选择的月
                    }
                }
            }
        }
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
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                        
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
                        }
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
    
    private var visibleMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: visibleMonth)
    }
}

// 按周显示的视图组件
struct WeekView: View {
    let week: [Date?]
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let calendar: Calendar
    let tasks: [ProjectTask]
    
    // 修改为检查是否有任何任务（包括单天任务）
    private var hasAnyTasks: Bool {
        return !tasks.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 日期行
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    if let date = week[index] {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasTasks: hasTasksOnDate(date)
                        ) {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                        .frame(maxWidth: .infinity) // 确保与星期标题宽度一致
                    } else {
                        Color.clear
                            .frame(height: 54) // 与DayCell高度保持一致
                            .frame(maxWidth: .infinity) // 确保空白区域也占用相同宽度
                    }
                }
            }
            
            // 任务时间线区域 - 显示所有任务
            if hasAnyTasks {
                // 计算所有任务的高度需求
                let allTasksCount = min(4, tasks.count) // 最多显示4个任务
                let dynamicHeight = CGFloat(16 + allTasksCount * 20)
                
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: dynamicHeight)
                    
                    WeekTasksView(
                        week: week,
                        tasks: tasks,
                        calendar: calendar
                    )
                }
                .padding(.top, 6)
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
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    // 背景圆圈
                    Group {
                        if isSelected {
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
                        .foregroundColor(isSelected ? .white : (isToday ? Color.blue : .primary))
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 日期选择器视图
struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @State private var tempDate: Date
    
    init(selectedDate: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedDate = selectedDate
        self._isPresented = isPresented
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
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


