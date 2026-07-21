import XCTest
import SwiftData
@testable import LiftPlus

/// Verifica o achatamento da ficha em passos, com foco nas regras de descanso
/// que distinguem bloco `single` de bloco composto (G2).
@MainActor
final class StepBuilderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeExercise(_ name: String) -> Exercise {
        let ex = Exercise(name: name, primaryMuscle: .chest)
        context.insert(ex)
        return ex
    }

    func testSingleBlock_roundsFollowSetCount() {
        let plan = WorkoutPlan(name: "P")
        context.insert(plan)
        let block = WorkoutBlock(kind: .single, rounds: 99) // rounds ignorado no single
        block.plan = plan
        plan.blocks = [block]
        context.insert(block)

        let planned = PlannedExercise(exercise: makeExercise("Supino"))
        planned.block = block
        block.exercises = [planned]
        context.insert(planned)
        for i in 0..<3 {
            let set = PlannedSet(orderIndex: i, targetReps: 8, targetWeight: Double(50 + i * 5))
            set.plannedExercise = planned
            planned.sets = (planned.sets ?? []) + [set]
            context.insert(set)
        }

        let steps = RunnerStepBuilder.steps(for: plan)
        XCTAssertEqual(steps.count, 3)
        XCTAssertEqual(steps.map(\.targetWeight), [50, 55, 60]) // pirâmide preservada
        // Descanso entre séries, exceto após a última de bloco único.
        XCTAssertEqual(steps[0].restKind, .betweenSets)
        XCTAssertEqual(steps[1].restKind, .betweenSets)
        XCTAssertNil(steps[2].restKind)
    }

    func testBiSetBlock_interleavesExercises_restOnlyAtRoundEnd() {
        let plan = WorkoutPlan(name: "P")
        context.insert(plan)
        let block = WorkoutBlock(kind: .biSet, rounds: 2)
        block.restBetweenRounds = 90
        block.plan = plan
        plan.blocks = [block]
        context.insert(block)

        for (i, name) in ["A", "B"].enumerated() {
            let planned = PlannedExercise(exercise: makeExercise(name), orderIndex: i)
            planned.block = block
            block.exercises = (block.exercises ?? []) + [planned]
            context.insert(planned)
            let set = PlannedSet(orderIndex: 0, targetReps: 12, targetWeight: 20)
            set.plannedExercise = planned
            planned.sets = [set]
            context.insert(set)
        }

        let steps = RunnerStepBuilder.steps(for: plan)
        // 2 exercícios × 2 rodadas = 4 passos, alternando A,B,A,B.
        XCTAssertEqual(steps.map(\.exerciseName), ["A", "B", "A", "B"])
        XCTAssertNil(steps[0].restKind)                 // A → B sem descanso
        XCTAssertEqual(steps[1].restKind, .betweenRounds) // fim da 1ª rodada
        XCTAssertNil(steps[2].restKind)                 // A → B sem descanso
        XCTAssertNil(steps[3].restKind)                 // fim do último bloco
        // Mesma instância de exercício compartilha itemKey entre rodadas.
        XCTAssertEqual(steps[0].itemKey, steps[2].itemKey)
        XCTAssertEqual(steps[1].itemKey, steps[3].itemKey)
        XCTAssertNotEqual(steps[0].itemKey, steps[1].itemKey)
    }

    func testTwoBlocks_restAfterFirstBlock() {
        let plan = WorkoutPlan(name: "P")
        context.insert(plan)
        for b in 0..<2 {
            let block = WorkoutBlock(kind: .single, orderIndex: b)
            block.restAfterBlock = 120
            block.plan = plan
            plan.blocks = (plan.blocks ?? []) + [block]
            context.insert(block)
            let planned = PlannedExercise(exercise: makeExercise("Ex\(b)"))
            planned.block = block
            block.exercises = [planned]
            context.insert(planned)
            let set = PlannedSet(orderIndex: 0, targetReps: 10, targetWeight: 40)
            set.plannedExercise = planned
            planned.sets = [set]
            context.insert(set)
        }

        let steps = RunnerStepBuilder.steps(for: plan)
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps[0].restKind, .afterBlock) // descanso após 1º bloco
        XCTAssertNil(steps[1].restKind)                // fim do treino
    }
}
