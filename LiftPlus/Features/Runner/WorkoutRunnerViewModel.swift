import Foundation
import SwiftData
import SwiftUI

/// Orquestra a execução do treino: aciona a máquina de estados pura
/// (`RunnerEngine`), materializa os efeitos no store (grava séries realizadas),
/// controla o timer de descanso e persiste a sessão `inProgress` a cada
/// transição (retomável após kill do app).
@Observable
@MainActor
final class WorkoutRunnerViewModel {
    private(set) var engine: RunnerEngine
    let restTimer = RestTimerService()

    private let context: ModelContext
    private let session: WorkoutSession
    /// SessionItem por itemKey do engine (criado sob demanda ao gravar).
    private var itemsByKey: [Int: SessionItem] = [:]
    /// Duração planejada do descanso atualmente em curso (o `currentStep`
    /// durante o descanso já aponta para o próximo item, então guardamos o
    /// valor do descanso ao iniciá-lo).
    private var activeRestPlanned: TimeInterval = 0

    var isFinished = false

    init?(plan: WorkoutPlan?, existingSession: WorkoutSession?, context: ModelContext) {
        self.context = context

        if let existingSession {
            // Retomada: reconstrói a partir da própria ficha (planId) ou aborta
            // graciosamente se a ficha não existir mais.
            self.session = existingSession
            let sourcePlan = plan ?? Self.fetchPlan(id: existingSession.planId, context: context)
            guard let sourcePlan else { return nil }
            self.engine = RunnerEngine(steps: RunnerStepBuilder.steps(for: sourcePlan))
            rebuildItemIndex()
            resumeEngine()
        } else if let plan {
            let steps = RunnerStepBuilder.steps(for: plan)
            guard !steps.isEmpty else { return nil }
            let session = WorkoutSession(planId: plan.id, planNameSnapshot: plan.name)
            context.insert(session)
            self.session = session
            self.engine = RunnerEngine(steps: steps)
            try? context.save()
        } else {
            return nil
        }
    }

    var currentStep: RunnerStep? { engine.currentStep }
    var isResting: Bool { engine.isResting }
    var planName: String { session.planNameSnapshot }

    var progress: Double {
        guard !engine.steps.isEmpty else { return 0 }
        return Double(min(recordedSetCount, engine.steps.count)) / Double(engine.steps.count)
    }

    private var recordedSetCount: Int {
        (session.items ?? []).reduce(0) { $0 + ($1.sets?.count ?? 0) }
    }

    func start() {
        restTimer.requestAuthorizationIfNeeded()
        apply(engine.handle(.start))
    }

    /// Caminho feliz (G7): 1 toque grava a série com os valores pré-preenchidos.
    func completeSet(reps: Int, weight: Double) {
        apply(engine.handle(.completeSet(reps: reps, weight: weight)))
    }

    func skipSet() { apply(engine.handle(.skipSet)) }
    func skipExercise() { apply(engine.handle(.skipExercise)) }

    func restFinished() { apply(engine.handle(.restFinished)) }
    func skipRest() { apply(engine.handle(.skipRest)) }
    func addRest(_ seconds: TimeInterval) {
        restTimer.add(seconds, nextExerciseName: currentStep?.exerciseName ?? "")
    }

    func finishEarly() { apply(engine.handle(.finish)) }

    func abandon() {
        restTimer.cancel()
        session.status = .abandoned
        session.endedAt = .now
        try? context.save()
        isFinished = true
    }

    // MARK: - Efeitos

    private func apply(_ effects: [RunnerEngine.Effect]) {
        for effect in effects {
            switch effect {
            case let .recordSet(stepIndex, reps, weight, skipped):
                record(stepIndex: stepIndex, reps: reps, weight: weight, skipped: skipped)
            case let .startRest(duration, _, nextName):
                activeRestPlanned = duration
                restTimer.start(duration: duration, nextExerciseName: nextName)
            case .cancelRest:
                accumulateRestActual()
                restTimer.cancel()
            case .sessionFinished:
                finalizeSession()
            }
        }
        try? context.save()
    }

    private func record(stepIndex: Int, reps: Int, weight: Double, skipped: Bool) {
        guard engine.steps.indices.contains(stepIndex) else { return }
        let step = engine.steps[stepIndex]
        let item = itemFor(step)
        let performed = PerformedSet(
            orderIndex: item.sortedSets.count,
            reps: reps,
            weight: weight,
            targetReps: step.targetReps,
            targetWeight: step.targetWeight,
            restPlanned: step.restAfter,
            skipped: skipped
        )
        performed.item = item
        item.sets = (item.sets ?? []) + [performed]
        context.insert(performed)
        if skipped { item.skipped = item.sortedSets.allSatisfy(\.skipped) }
    }

    private func itemFor(_ step: RunnerStep) -> SessionItem {
        if let existing = itemsByKey[step.itemKey] { return existing }
        let item = SessionItem(
            orderIndex: step.itemKey,
            blockIndex: step.blockIndex,
            blockKind: step.blockKind,
            exerciseId: step.exerciseId,
            exerciseName: step.exerciseName,
            muscleGroups: step.muscleGroups
        )
        item.session = session
        session.items = (session.items ?? []) + [item]
        context.insert(item)
        itemsByKey[step.itemKey] = item
        return item
    }

    private func accumulateRestActual() {
        guard let end = restTimer.endDate else { return }
        let elapsed = max(0, activeRestPlanned - max(0, end.timeIntervalSince(.now)))
        session.totalRestActual += elapsed
        // Registra o descanso real na última série gravada (a que antecede o descanso).
        if let lastSet = session.sortedItems.last?.sortedSets.last {
            lastSet.restActual = elapsed
        }
        activeRestPlanned = 0
    }

    private func finalizeSession() {
        accumulateRestActual()
        restTimer.cancel()
        session.status = .completed
        session.endedAt = .now
        session.totalVolume = (session.items ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { !$0.skipped }
            .reduce(0) { $0 + Double($1.reps) * $1.weight }
        isFinished = true
    }

    // MARK: - Retomada

    private func rebuildItemIndex() {
        for item in session.sortedItems {
            itemsByKey[item.orderIndex] = item
        }
    }

    /// Avança o engine até o próximo passo não gravado, sem regravar nada:
    /// os eventos são aplicados direto na máquina (efeitos descartados).
    private func resumeEngine() {
        _ = engine.handle(.start)
        let alreadyRecorded = recordedSetCount
        var replayed = 0
        while replayed < alreadyRecorded {
            guard case .performing = engine.state else { break }
            _ = engine.handle(.completeSet(reps: 0, weight: 0)) // efeitos ignorados
            if engine.isResting { _ = engine.handle(.skipRest) }
            replayed += 1
        }
    }

    private static func fetchPlan(id: UUID?, context: ModelContext) -> WorkoutPlan? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
