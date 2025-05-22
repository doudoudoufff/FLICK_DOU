import SwiftUI

struct ChineseCalendarView: View {
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let getTasksForCalendar: () -> [ProjectTask]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // 固定大小的卡片，内部内容可滚动
            CalendarGridView(
                selectedDate: $selectedDate,
                hasTasksOnDate: hasTasksOnDate,
                getTasksForCalendar: getTasksForCalendar
            )
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity) // 确保日历能占据最大水平空间
        .frame(height: 480) // 固定日历卡片的高度
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let getTasksForCalendar: () -> [ProjectTask]
    @State private var currentMonth: Date
    @State private var scrollViewHeight: CGFloat = 420 // 可滚动区域的默认高度
    @State private var showDatePicker = false // 日期选择器显示状态
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    // 显示多个月以支持滚动
    private let monthsToShow = 12
    
    init(selectedDate: Binding<Date>, hasTasksOnDate: @escaping (Date) -> Bool, getTasksForCalendar: @escaping () -> [ProjectTask]) {
        self._selectedDate = selectedDate
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
        self.hasTasksOnDate = hasTasksOnDate
        self.getTasksForCalendar = getTasksForCalendar
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 月份选择器与日期快速跳转 - 固定在顶部
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                Spacer()
                
                // 日期选择器按钮
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    Text(monthYearString)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePickerView(selectedDate: $currentMonth, isPresented: $showDatePicker)
                }
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
            .zIndex(1) // 确保月份选择器始终在顶部
            
            // 星期标题行 - 固定在月份选择器下方
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
            
            // 可滚动的日历区域
            ScrollViewReader { scrollProxy in
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
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 20)
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
                    // 当通过日期选择器改变月份时，滚动到相应位置
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            scrollProxy.scrollTo(0, anchor: .top) // 滚动到当前选择的月
                        }
                    }
                }
            }
            
            // 任务图例
            if hasTasksInCurrentMonth() {
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
            .padding(.horizontal, 4)
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
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentMonth)
    }
    
    private func previousMonth() {
        withAnimation {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
        }
    }
    
    private func nextMonth() {
        withAnimation {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
        }
    }
}

// 按周显示的视图组件
struct WeekView: View {
    let week: [Date?]
    @Binding var selectedDate: Date
    let hasTasksOnDate: (Date) -> Bool
    let calendar: Calendar
    let tasks: [ProjectTask]
    
    private var hasVisibleTasks: Bool {
        return !tasks.filter({ $0.isCrossDays }).isEmpty
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
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            
            // 任务时间线区域 - 根据是否有任务动态调整高度
            if hasVisibleTasks {
                // 有跨天任务时，显示时间线
                let taskCount = min(3, tasks.filter({ $0.isCrossDays }).count) // 最多考虑3个任务的高度
                let dynamicHeight = CGFloat(20 + taskCount * 24) // 基础高度 + 每个任务的高度
                
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
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3) // 统一上下间距
    }
}

// 周任务时间线视图
struct WeekTasksView: View {
    let week: [Date?]
    let tasks: [ProjectTask]
    let calendar: Calendar
    
    private let taskColors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(tasksToDisplay(in: geometry)) { taskData in
                TaskTimelineView(
                    task: taskData.task,
                    startPosition: taskData.startPosition,
                    length: taskData.length,
                    color: taskData.color,
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
        
        // 过滤跨天任务并按持续时间排序
        let crossDaysTasks = tasks.filter { $0.isCrossDays }
        if crossDaysTasks.isEmpty { return [] } // 如果没有跨天任务，直接返回空数组
        
        let sortedTasks = crossDaysTasks.sorted(by: { $0.durationDays > $1.durationDays })
        
        for (index, task) in sortedTasks.enumerated() {
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
            
            // 设置颜色
            let color = taskColors[index % taskColors.count]
            
            let taskData = TaskDisplayData(
                id: task.id,
                task: task,
                startPosition: CGPoint(x: CGFloat(startIndex) * cellWidth, y: CGFloat(14 + offsetIndex * 24)),
                length: length,
                color: color,
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
    let offsetIndex: Int
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 7
            
            ZStack(alignment: .leading) {
                // 时间线背景
                Rectangle()
                    .fill(color.opacity(0.2))
                    .frame(
                        width: CGFloat(length) * cellWidth - 4, // 减去4像素留出边距
                        height: 22
                    )
                    .cornerRadius(11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(color, lineWidth: 1.5)
                    )
                
                // 任务开始指示器
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .padding(.leading, 4)
                
                // 任务标题
                if length > 1 {
                    HStack(spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.leading, 14)
                            .foregroundColor(color.opacity(0.9))
                            
                        // 显示任务持续天数
                        if length > 2 && task.durationDays > 1 {
                            Text("(\(task.durationDays)天)")
                                .font(.system(size: 11))
                                .foregroundColor(color.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: CGFloat(length) * cellWidth - 16)
                }
            }
            .position(
                x: startPosition.x + (CGFloat(length) * cellWidth) / 2,
                y: startPosition.y
            )
            .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
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
            VStack(spacing: 4) {
                // 日期数字
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 20, design: .rounded))
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
                
                // 任务标记点
                if hasTasks {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 2)
                } else {
                    Color.clear
                        .frame(width: 6, height: 8)
                }
            }
            .frame(height: 46) // 日期单元格高度
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    } else if isToday {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 1.5)
                            .frame(width: 40, height: 40)
                    } else {
                        Color.clear
                    }
                }
            )
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
