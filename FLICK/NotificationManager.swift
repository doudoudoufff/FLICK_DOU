import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationsAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = granted
            }
            
            if let error = error {
                print("通知授权错误：\(error.localizedDescription)")
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleTaskReminder(for task: ProjectTask, in project: Project) {
        guard let reminder = task.reminder else { return }
        
        // 先移除该任务的所有现有提醒
        removeTaskReminders(for: task)
        
        // 创建提醒的日期组件
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: task.dueDate)
        dateComponents.hour = task.reminderHour
        dateComponents.minute = 0
        
        // 根据提醒类型设置不同的提醒时间
        switch reminder {
        case .daily:
            // 从今天开始到截止日期每天提醒
            let today = Calendar.current.startOfDay(for: Date())
            let dueDate = Calendar.current.startOfDay(for: task.dueDate)
            let numberOfDays = Calendar.current.dateComponents([.day], from: today, to: dueDate).day ?? 0
            
            for dayOffset in 0...numberOfDays {
                scheduleNotification(
                    for: task,
                    in: project,
                    dateComponents: dateComponents,
                    dayOffset: dayOffset,
                    identifier: "\(task.id)-daily-\(dayOffset)"
                )
            }
            
        case .sevenDays, .threeDays, .oneDay:
            // 在指定天数前提醒
            let dayOffset = -reminder.days
            scheduleNotification(
                for: task,
                in: project,
                dateComponents: dateComponents,
                dayOffset: dayOffset,
                identifier: "\(task.id)-\(reminder.rawValue)"
            )
        }
    }
    
    private func scheduleNotification(
        for task: ProjectTask,
        in project: Project,
        dateComponents: DateComponents,
        dayOffset: Int,
        identifier: String
    ) {
        var components = dateComponents
        if let day = components.day {
            components.day = day + dayOffset
        }
        
        let content = UNMutableNotificationContent()
        content.title = "任务提醒：\(project.name)"
        content.body = "任务「\(task.title)」\(task.reminder == .daily ? "今日待办" : "即将到期")\n负责人：\(task.assignee)"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("添加通知失败：\(error.localizedDescription)")
            }
        }
    }
    
    func removeTaskReminders(for task: ProjectTask) {
        // 移除该任务的所有提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "\(task.id)-daily",
                "\(task.id)-sevenDays",
                "\(task.id)-threeDays",
                "\(task.id)-oneDay"
            ]
        )
    }
    
    func removeAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "测试通知"
        content.body = "如果你看到这条通知，说明通知功能正常工作！"
        content.sound = .default
        
        // 5秒后触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "testNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("测试通知添加失败：\(error.localizedDescription)")
            } else {
                print("测试通知已添加，将在5秒后显示")
            }
        }
    }
    
    // 查看所有待发送的通知
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n当前待发送的通知：")
            for request in requests {
                print("ID: \(request.identifier)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextDate = trigger.nextTriggerDate() {
                    print("预计发送时间: \(nextDate.chineseStyleString())")
                }
                print("标题: \(request.content.title)")
                print("内容: \(request.content.body)\n")
            }
        }
    }
} 