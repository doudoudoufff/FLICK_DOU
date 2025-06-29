import SwiftUI

struct ProjectCardView: View {
    @Binding var project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 项目名称和状态
            HStack {
                Circle()
                    .fill(project.color)
                    .frame(width: 12, height: 12)
                Text(project.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: project.status)
            }
            
            // 项目信息
            HStack {
                // 导演信息
                if !project.director.isEmpty {
                    Label(project.director, systemImage: "megaphone")
                }
                
                // 制片信息
                if !project.producer.isEmpty {
                    if !project.director.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary)
                    }
                    Label(project.producer, systemImage: "person")
                }
                
                Spacer()
                
                // 时间始终靠右显示
                Text(project.startDate.chineseStyleShortString())
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 状态标签组件
struct StatusBadge: View {
    let status: Project.Status  // 使用完整的类型名称
    
    var statusInfo: (text: String, color: Color) {
        switch status {
        case .inProgress:
            return ("进行中", .blue)
        case .completed:
            return ("已完成", .green)
        case .cancelled:
            return ("已取消", .red)
        }
    }
    
    var body: some View {
        Text(statusInfo.text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusInfo.color.opacity(0.1))
            .clipShape(Capsule())
    }
}


