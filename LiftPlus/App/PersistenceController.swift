import Foundation
import SwiftData

/// Fábrica do ModelContainer. Na v1 o store é sempre local (fonte da verdade,
/// 100% offline). A troca para CloudKit (v3) acontece só aqui — Views e
/// ViewModels nunca tocam a configuração de persistência, então habilitar o
/// sync não exige mudar a UI.
enum PersistenceController {
    static let schema = Schema([
        Exercise.self,
        WorkoutPlan.self,
        WorkoutBlock.self,
        PlannedExercise.self,
        PlannedSet.self,
        ScheduleEntry.self,
        WorkoutSession.self,
        SessionItem.self,
        PerformedSet.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none // v3: .private(...)
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Falha ao criar o ModelContainer: \(error)")
        }
    }
}
