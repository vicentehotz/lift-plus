import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Hoje", systemImage: "flame") }

            PlansListView()
                .tabItem { Label("Fichas", systemImage: "list.bullet.rectangle") }

            ScheduleView()
                .tabItem { Label("Agenda", systemImage: "calendar") }

            HistoryView()
                .tabItem { Label("Histórico", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
