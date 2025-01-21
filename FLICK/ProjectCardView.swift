import SwiftUI

struct ProjectCardView: View {
    @Binding var project: Project
    
    var body: some View {
        NavigationLink(destination: ProjectDetailView(project: $project)) {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部状态条
                Rectangle()
                    .fill(project.color)
                    .frame(height: 4)
                
                // 主要内容
                VStack(alignment: .leading, spacing: 12) {
                    // 项目名称和日期
                    HStack {
                        Text(project.name)
                            .font(.system(size: 18, weight: .medium))
                        
                        Spacer()
                        
                        Text(project.startDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 分割线
                    Divider()
                    
                    // 导演和制片信息
                    HStack {
                        // 导演信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("导演")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(project.director)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 制片信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("制片")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(project.producer)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch project.status {
        case .planning:
            return .blue
        case .shooting:
            return .orange
        case .postProduction:
            return .purple
        case .completed:
            return .green
        }
    }
} 