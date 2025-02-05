import SwiftUI

class ProjectStore: ObservableObject {
    static var shared: ProjectStore!
    @Published var projects: [Project] = []
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    
    init(projects: [Project] = []) {
        self.projects = projects
        ProjectStore.shared = self
    }
    
    // 从云端加载项目
    func loadProjects() async {
        do {
            let cloudProjects = try await LCManager.shared.fetchProjects()
            DispatchQueue.main.async {
                self.projects = cloudProjects
            }
        } catch {
            print("加载项目失败：\(error)")
        }
    }
    
    // 添加项目
    func addProject(_ project: Project) {
        projects.append(project)
        
        // 保存到云端
        Task {
            do {
                try await LCManager.shared.saveProject(project)
            } catch {
                print("保存项目失败：\(error)")
            }
        }
    }
    
    // 删除项目
    func deleteProject(at index: Int) {
        projects.remove(at: index)
    }
    
    // 更新项目
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }
    
    private func handleTaskChange(task: ProjectTask, in project: Project) {
        if enableNotifications {
            if task.isCompleted {
                // 如果任务完成，移除提醒
                NotificationManager.shared.removeTaskReminders(for: task)
            } else if task.reminder != nil {
                // 如果设置了提醒，更新提醒
                NotificationManager.shared.scheduleTaskReminder(for: task, in: project)
            }
        }
    }
    
    func updateTask(_ task: ProjectTask, in project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
           let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == task.id }) {
            projects[projectIndex].tasks[taskIndex] = task
            handleTaskChange(task: task, in: project)
        }
    }
    
    func addTask(_ task: ProjectTask, to project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].tasks.append(task)
            handleTaskChange(task: task, in: project)
        }
    }
    
    func deleteTask(_ task: ProjectTask, from project: Project) {
        if let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            projects[projectIndex].tasks.removeAll(where: { $0.id == task.id })
            NotificationManager.shared.removeTaskReminders(for: task)
        }
    }
}

// 用于获取项目 Binding 的扩展
extension ProjectStore {
    func binding(for projectId: UUID) -> Binding<Project>? {  // 返回可选的 Binding
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return nil
        }
        
        return Binding(
            get: { self.projects[index] },
            set: { self.projects[index] = $0 }
        )
    }
} 
