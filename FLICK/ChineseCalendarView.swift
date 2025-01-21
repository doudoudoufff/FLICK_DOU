import SwiftUI

struct ChineseCalendarView: View {
    @Binding var selectedDate: Date
    @State private var isExpanded = false
    let hasTasksOnDate: (Date) -> Bool
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // 当前选中日期显示
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.medium)
                    
                    Text(weekdayString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
            .padding()
            
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                CalendarGridView(
                    selectedDate: $selectedDate,
                    isExpanded: $isExpanded,
                    hasTasksOnDate: hasTasksOnDate
                )
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var weekdayString: String {
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: selectedDate)
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    @Binding var isExpanded: Bool
    let hasTasksOnDate: (Date) -> Bool
    @State private var currentMonth: Date
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    
    init(selectedDate: Binding<Date>, isExpanded: Binding<Bool>, hasTasksOnDate: @escaping (Date) -> Bool) {
        self._selectedDate = selectedDate
        self._isExpanded = isExpanded
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
        self.hasTasksOnDate = hasTasksOnDate
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 月份选择器
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .mask(Circle()) // 使用 mask 来裁剪阴影为圆形
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .mask(Circle()) // 使用 mask 来裁剪阴影为圆形
                }
            }
            
            VStack(spacing: 12) {
                // 星期标题
                HStack {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // 日期网格
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(daysInMonth, id: \.self) { date in
                        if let date = date {
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
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                }
            }
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
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
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                
                // 任务标记点
                if hasTasks {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                    } else if isToday {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 1)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
