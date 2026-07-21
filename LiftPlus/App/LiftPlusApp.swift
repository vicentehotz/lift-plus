import SwiftUI
import SwiftData

@main
struct LiftPlusApp: App {
    let container: ModelContainer

    init() {
        let container = PersistenceController.makeContainer()
        SeedService.seedIfNeeded(context: container.mainContext)
        self.container = container
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
