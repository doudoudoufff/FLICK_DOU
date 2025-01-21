import SwiftUI

struct OverviewView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("总览页面")
            }
            .navigationTitle("总览")
        }
    }
}

#Preview {
    OverviewView()
} 