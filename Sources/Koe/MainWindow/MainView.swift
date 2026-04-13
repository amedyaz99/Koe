import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            RecordTab()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
            
            HistoryTab()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}
