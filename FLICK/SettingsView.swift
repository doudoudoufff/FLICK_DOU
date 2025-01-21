import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("设置页面")
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
} 