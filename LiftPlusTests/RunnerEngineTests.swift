import XCTest
@testable import LiftPlus

final class RunnerEngineTests: XCTestCase {

    // Helper: cria um passo com descanso configurável.
    private func step(id: Int, itemKey: Int, name: String = "Ex",
                      round: Int = 0, roundCount: Int = 1,
                      rest: TimeInterval = 0, restKind: RestKind? = nil) -> RunnerStep {
        RunnerStep(id: id, itemKey: itemKey, exerciseId: nil, exerciseName: name,
                   muscleGroups: [.chest], blockIndex: 0, blockKind: .single,
                   roundIndex: round, roundCount: roundCount, setOrderIndex: round,
                   targetReps: 10, targetWeight: 50, isWarmup: false,
                   restAfter: rest, restKind: restKind)
    }

    func testSingleBlockThreeSets_restsBetweenSetsNotAfterLast() {
        let steps = [
            step(id: 0, itemKey: 0, round: 0, roundCount: 3, rest: 60, restKind: .betweenSets),
            step(id: 1, itemKey: 0, round: 1, roundCount: 3, rest: 60, restKind: .betweenSets),
            step(id: 2, itemKey: 0, round: 2, roundCount: 3, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)

        XCTAssertTrue(engine.handle(.start).isEmpty)
        XCTAssertEqual(engine.state, .performing(stepIndex: 0))

        // 1ª série → grava e entra em descanso.
        let e1 = engine.handle(.completeSet(reps: 10, weight: 50))
        XCTAssertEqual(e1, [
            .recordSet(stepIndex: 0, reps: 10, weight: 50, skipped: false),
            .startRest(duration: 60, kind: .betweenSets, nextExerciseName: "Ex"),
        ])
        XCTAssertTrue(engine.isResting)

        // Fim do descanso → cancela o timer e vai para a 2ª série.
        XCTAssertEqual(engine.handle(.restFinished), [.cancelRest])
        XCTAssertEqual(engine.state, .performing(stepIndex: 1))

        _ = engine.handle(.completeSet(reps: 10, weight: 50))
        _ = engine.handle(.restFinished)
        XCTAssertEqual(engine.state, .performing(stepIndex: 2))

        // Última série → sem descanso, sessão termina.
        let last = engine.handle(.completeSet(reps: 10, weight: 50))
        XCTAssertEqual(last, [
            .recordSet(stepIndex: 2, reps: 10, weight: 50, skipped: false),
            .sessionFinished,
        ])
        XCTAssertEqual(engine.state, .finished)
    }

    func testBiSet_noRestWithinRound_restBetweenRounds() {
        // Bloco composto: A e B na mesma rodada (sem descanso entre eles),
        // descanso entre rodadas, 2 rodadas.
        let steps = [
            step(id: 0, itemKey: 0, name: "A", round: 0, roundCount: 2, rest: 0, restKind: nil),
            step(id: 1, itemKey: 1, name: "B", round: 0, roundCount: 2, rest: 90, restKind: .betweenRounds),
            step(id: 2, itemKey: 0, name: "A", round: 1, roundCount: 2, rest: 0, restKind: nil),
            step(id: 3, itemKey: 1, name: "B", round: 1, roundCount: 2, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)
        _ = engine.handle(.start)

        // A → avança direto para B, sem descanso.
        let a = engine.handle(.completeSet(reps: 10, weight: 50))
        XCTAssertEqual(a, [.recordSet(stepIndex: 0, reps: 10, weight: 50, skipped: false)])
        XCTAssertEqual(engine.state, .performing(stepIndex: 1))

        // B (fim da rodada) → descanso entre rodadas.
        let b = engine.handle(.completeSet(reps: 10, weight: 50))
        XCTAssertEqual(b, [
            .recordSet(stepIndex: 1, reps: 10, weight: 50, skipped: false),
            .startRest(duration: 90, kind: .betweenRounds, nextExerciseName: "A"),
        ])
        _ = engine.handle(.restFinished)
        XCTAssertEqual(engine.state, .performing(stepIndex: 2))
    }

    func testSkipExercise_marksRemainingSetsSkipped_jumpsToNextItem() {
        // Item 0 com 2 séries, depois item 1.
        let steps = [
            step(id: 0, itemKey: 0, name: "A", round: 0, roundCount: 2, rest: 60, restKind: .betweenSets),
            step(id: 1, itemKey: 0, name: "A", round: 1, roundCount: 2, rest: 90, restKind: .afterBlock),
            step(id: 2, itemKey: 1, name: "B", round: 0, roundCount: 1, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)
        _ = engine.handle(.start)

        let effects = engine.handle(.skipExercise)
        // Ambas as séries de A viram puladas; salta para B sem descanso.
        XCTAssertEqual(effects, [
            .recordSet(stepIndex: 0, reps: 0, weight: 0, skipped: true),
            .recordSet(stepIndex: 1, reps: 0, weight: 0, skipped: true),
        ])
        XCTAssertEqual(engine.state, .performing(stepIndex: 2))
    }

    func testSkipSet_recordsSkippedAndAdvances() {
        let steps = [
            step(id: 0, itemKey: 0, round: 0, roundCount: 2, rest: 60, restKind: .betweenSets),
            step(id: 1, itemKey: 0, round: 1, roundCount: 2, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)
        _ = engine.handle(.start)

        let e = engine.handle(.skipSet)
        XCTAssertEqual(e.first, .recordSet(stepIndex: 0, reps: 0, weight: 0, skipped: true))
        XCTAssertTrue(engine.isResting)
    }

    func testFinishEarly_whileResting_cancelsRestAndFinishes() {
        let steps = [
            step(id: 0, itemKey: 0, round: 0, roundCount: 2, rest: 60, restKind: .betweenSets),
            step(id: 1, itemKey: 0, round: 1, roundCount: 2, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)
        _ = engine.handle(.start)
        _ = engine.handle(.completeSet(reps: 10, weight: 50))
        XCTAssertTrue(engine.isResting)

        let e = engine.handle(.finish)
        XCTAssertEqual(e, [.cancelRest, .sessionFinished])
        XCTAssertEqual(engine.state, .finished)
    }

    func testSkipRest_advancesImmediately() {
        let steps = [
            step(id: 0, itemKey: 0, round: 0, roundCount: 2, rest: 60, restKind: .betweenSets),
            step(id: 1, itemKey: 0, round: 1, roundCount: 2, rest: 0, restKind: nil),
        ]
        var engine = RunnerEngine(steps: steps)
        _ = engine.handle(.start)
        _ = engine.handle(.completeSet(reps: 10, weight: 50))

        let e = engine.handle(.skipRest)
        XCTAssertEqual(e, [.cancelRest])
        XCTAssertEqual(engine.state, .performing(stepIndex: 1))
    }

    func testEmptyPlan_finishesOnStart() {
        var engine = RunnerEngine(steps: [])
        let e = engine.handle(.start)
        XCTAssertEqual(e, [.sessionFinished])
        XCTAssertEqual(engine.state, .finished)
    }
}
