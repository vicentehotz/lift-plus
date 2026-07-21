import XCTest
import SwiftData
@testable import LiftPlus

/// Verifica o round-trip de backup (export → import) e a idempotência do import
/// (reimportar não duplica) — base do backup manual da v2 (G13).
@MainActor
final class ExportServiceTests: XCTestCase {

    private func makeContext() -> ModelContext {
        PersistenceController.makeContainer(inMemory: true).mainContext
    }

    /// Cria uma ficha simples com uma sessão concluída no contexto dado.
    @discardableResult
    private func seedData(_ context: ModelContext) -> (plan: WorkoutPlan, session: WorkoutSession) {
        let exercise = Exercise(name: "Supino", primaryMuscle: .chest, seedSlug: "supino")
        context.insert(exercise)

        let plan = WorkoutPlan(name: "Treino A")
        context.insert(plan)
        let block = WorkoutBlock(kind: .single)
        block.plan = plan
        plan.blocks = [block]
        context.insert(block)
        let planned = PlannedExercise(exercise: exercise)
        planned.block = block
        block.exercises = [planned]
        context.insert(planned)
        let pset = PlannedSet(orderIndex: 0, targetReps: 10, targetWeight: 60)
        pset.plannedExercise = planned
        planned.sets = [pset]
        context.insert(pset)

        context.insert(ScheduleEntry(weekday: 2, plan: plan))

        let session = WorkoutSession(planId: plan.id, planNameSnapshot: "Treino A")
        session.status = .completed
        session.endedAt = session.startedAt.addingTimeInterval(1800)
        context.insert(session)
        let item = SessionItem(orderIndex: 0, blockIndex: 0, blockKind: .single,
                               exerciseId: exercise.id, exerciseName: "Supino", muscleGroups: [.chest])
        item.session = session
        session.items = [item]
        context.insert(item)
        let done = PerformedSet(orderIndex: 0, reps: 10, weight: 60, targetReps: 10, targetWeight: 60, restPlanned: 60)
        done.item = item
        item.sets = [done]
        context.insert(done)

        try? context.save()
        return (plan, session)
    }

    func testRoundTrip_importsAllEntitiesIntoEmptyStore() throws {
        let source = makeContext()
        seedData(source)
        let data = try ExportService.exportJSON(context: source)

        let dest = makeContext()
        let summary = try ExportService.importBackup(data, into: dest)

        XCTAssertEqual(summary.plans, 1)
        XCTAssertEqual(summary.schedule, 1)
        XCTAssertEqual(summary.sessions, 1)

        let plans = try dest.fetch(FetchDescriptor<WorkoutPlan>())
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.sortedBlocks.first?.sortedExercises.first?.exercise?.name, "Supino")

        let sessions = try dest.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.sortedItems.first?.sortedSets.first?.weight, 60)
    }

    func testImportIsIdempotent_reimportDoesNotDuplicate() throws {
        let source = makeContext()
        seedData(source)
        let data = try ExportService.exportJSON(context: source)

        let dest = makeContext()
        _ = try ExportService.importBackup(data, into: dest)
        let second = try ExportService.importBackup(data, into: dest)

        XCTAssertEqual(second.plans, 0)
        XCTAssertEqual(second.sessions, 0)
        XCTAssertEqual(try dest.fetch(FetchDescriptor<WorkoutPlan>()).count, 1)
        XCTAssertEqual(try dest.fetch(FetchDescriptor<WorkoutSession>()).count, 1)
        XCTAssertEqual(try dest.fetch(FetchDescriptor<PerformedSet>()).count, 1)
    }

    func testRebuildDerivedData_recomputesVolume() throws {
        let context = makeContext()
        let (_, session) = seedData(context)
        session.totalVolume = 0 // simula valor perdido/importado sem volume
        try context.save()

        ExportService.rebuildDerivedData(context: context)
        XCTAssertEqual(session.totalVolume, 600) // 10 reps × 60 kg
    }

    func testCSVExport_hasHeaderAndOneRowPerSet() {
        let context = makeContext()
        seedData(context)
        let csv = String(decoding: ExportService.exportSessionsCSV(context: context), as: UTF8.self)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2) // cabeçalho + 1 série
        XCTAssertTrue(lines[0].contains("exercicio"))
        XCTAssertTrue(lines[1].contains("Supino"))
    }
}
