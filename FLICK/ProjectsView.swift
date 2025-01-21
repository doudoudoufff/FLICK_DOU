import SwiftUI

struct ProjectsView: View {
    @State private var projects: [Project] = [
        Project(
            name: "荒野猎人",
            director: "亚利桑德罗·冈萨雷斯·伊纳里图",
            producer: "阿诺德·米尔钱",
            startDate: Date(),
            status: .shooting
        ),
        Project(
            name: "星际穿越",
            director: "克里斯托弗·诺兰",
            producer: "艾玛·托马斯",
            startDate: Date(),
            status: .planning
        ),
        Project(
            name: "盗梦空间",
            director: "克里斯托弗·诺兰",
            producer: "艾玛·托马斯",
            startDate: Date(),
            status: .postProduction
        )
    ]
    
    @State private var searchText = ""
    @State private var showingAddProject = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach($projects) { $project in
                        if searchText.isEmpty || 
                           project.name.localizedCaseInsensitiveContains(searchText) ||
                           project.director.localizedCaseInsensitiveContains(searchText) ||
                           project.producer.localizedCaseInsensitiveContains(searchText) {
                            ProjectCardView(project: $project)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "搜索项目")
            .navigationTitle("项目")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAddProject = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(isPresented: $showingAddProject, projects: $projects)
            }
        }
    }
}

#Preview {
    ProjectsView()
} 