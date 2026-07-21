import Foundation
import SwiftData

/// Container em memória com dados de exemplo para SwiftUI Previews.
/// Isolado ao main actor porque acessa `mainContext` (main-actor no iOS 17+).
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        SeedService.seedIfNeeded(context: context)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func find(_ slug: String) -> Exercise? { exercises.first { $0.seedSlug == slug } }

        let plan = WorkoutPlan(name: "Treino A — Peito e Tríceps", orderIndex: 0)
        context.insert(plan)

        let block = WorkoutBlock(kind: .single, orderIndex: 0)
        block.plan = plan
        plan.blocks = [block]
        context.insert(block)
        if let supino = find("supino-reto-barra") {
            let planned = PlannedExercise(exercise: supino, orderIndex: 0)
            planned.block = block
            block.exercises = [planned]
            context.insert(planned)
            for i in 0..<3 {
                let set = PlannedSet(orderIndex: i, targetReps: 10, targetWeight: 60)
                set.plannedExercise = planned
                planned.sets = (planned.sets ?? []) + [set]
                context.insert(set)
            }
        }

        context.insert(ScheduleEntry(weekday: Calendar.current.component(.weekday, from: .now), plan: plan))
        try? context.save()
        return container
    }()

    static var sampleExercise: Exercise {
        let context = container.mainContext
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return exercises.first { $0.seedSlug == "agachamento-livre" }
            ?? Exercise(name: "Agachamento", primaryMuscle: .quadriceps)
    }
}
