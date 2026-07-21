import Foundation

/// Passo atômico da execução: uma série de um exercício, já achatada a partir
/// dos blocos (rodada a rodada). O descanso pertence ao passo *após* concluí-lo,
/// derivado das regras do bloco (§3 do plano): dentro da rodada de um bloco
/// composto não há descanso; entre rodadas usa `restBetweenRounds`; ao fim do
/// bloco usa `restAfterBlock`.
struct RunnerStep: Equatable, Identifiable {
    let id: Int
    /// Identifica a instância de exercício (SessionItem) a que a série pertence.
    let itemKey: Int
    let exerciseId: UUID?
    let exerciseName: String
    let muscleGroups: [MuscleGroup]
    let blockIndex: Int
    let blockKind: BlockKind
    let roundIndex: Int
    let roundCount: Int
    let setOrderIndex: Int
    let targetReps: Int
    let targetWeight: Double
    let isWarmup: Bool
    let restAfter: TimeInterval
    let restKind: RestKind?
}

/// Máquina de estados pura da execução do treino. Não faz I/O: cada evento
/// devolve efeitos que o ViewModel materializa (gravar série, agendar
/// notificação, finalizar sessão).
struct RunnerEngine {
    enum State: Equatable {
        case idle
        case performing(stepIndex: Int)
        case resting(afterStepIndex: Int, nextStepIndex: Int, duration: TimeInterval, kind: RestKind)
        case finished
    }

    enum Event: Equatable {
        case start
        case completeSet(reps: Int, weight: Double)
        case skipSet
        case skipExercise
        case restFinished
        case skipRest
        case finish
    }

    enum Effect: Equatable {
        case recordSet(stepIndex: Int, reps: Int, weight: Double, skipped: Bool)
        case startRest(duration: TimeInterval, kind: RestKind, nextExerciseName: String)
        case cancelRest
        case sessionFinished
    }

    let steps: [RunnerStep]
    private(set) var state: State = .idle
    /// itemKeys cujos passos futuros devem ser pulados (exercício pulado).
    private var skippedItems: Set<Int> = []

    init(steps: [RunnerStep]) {
        self.steps = steps
    }

    var currentStep: RunnerStep? {
        switch state {
        case .performing(let i): steps.indices.contains(i) ? steps[i] : nil
        case .resting(_, let next, _, _): steps.indices.contains(next) ? steps[next] : nil
        default: nil
        }
    }

    @discardableResult
    mutating func handle(_ event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .start):
            guard let first = firstActiveIndex(from: 0) else {
                state = .finished
                return [.sessionFinished]
            }
            state = .performing(stepIndex: first)
            return []

        case (.performing(let i), .completeSet(let reps, let weight)):
            return advance(from: i, effects: [.recordSet(stepIndex: i, reps: reps, weight: weight, skipped: false)])

        case (.performing(let i), .skipSet):
            return advance(from: i, effects: [.recordSet(stepIndex: i, reps: 0, weight: 0, skipped: true)])

        case (.performing(let i), .skipExercise):
            let key = steps[i].itemKey
            skippedItems.insert(key)
            var effects: [Effect] = []
            // Registra como puladas todas as séries restantes deste exercício.
            for j in i..<steps.count where steps[j].itemKey == key {
                effects.append(.recordSet(stepIndex: j, reps: 0, weight: 0, skipped: true))
            }
            return advance(from: i, effects: effects, skipRestAfterCurrent: true)

        case (.resting(_, let next, _, _), .restFinished),
             (.resting(_, let next, _, _), .skipRest):
            // Sair do descanso sempre encerra o timer/notificação (real ou pulado).
            var effects: [Effect] = [.cancelRest]
            if let idx = firstActiveIndex(from: next) {
                state = .performing(stepIndex: idx)
            } else {
                state = .finished
                effects.append(.sessionFinished)
            }
            return effects

        case (_, .finish) where state != .finished:
            let wasResting = isResting
            state = .finished
            return (wasResting ? [Effect.cancelRest] : []) + [.sessionFinished]

        default:
            return []
        }
    }

    var isResting: Bool {
        if case .resting = state { return true }
        return false
    }

    // MARK: - Avanço

    private mutating func advance(from index: Int, effects: [Effect], skipRestAfterCurrent: Bool = false) -> [Effect] {
        var effects = effects
        guard let next = firstActiveIndex(from: index + 1) else {
            state = .finished
            effects.append(.sessionFinished)
            return effects
        }
        let rest = skipRestAfterCurrent ? 0 : steps[index].restAfter
        if rest > 0, let kind = steps[index].restKind {
            state = .resting(afterStepIndex: index, nextStepIndex: next, duration: rest, kind: kind)
            effects.append(.startRest(duration: rest, kind: kind, nextExerciseName: steps[next].exerciseName))
        } else {
            // Bloco composto dentro da rodada, ou exercício pulado: avanço imediato.
            state = .performing(stepIndex: next)
        }
        return effects
    }

    private func firstActiveIndex(from index: Int) -> Int? {
        var i = index
        while i < steps.count {
            if !skippedItems.contains(steps[i].itemKey) { return i }
            i += 1
        }
        return nil
    }
}

// MARK: - Achatamento do plano em passos

enum RunnerStepBuilder {
    /// Achata a ficha em uma sequência linear de passos, rodada a rodada.
    static func steps(for plan: WorkoutPlan) -> [RunnerStep] {
        var steps: [RunnerStep] = []
        var itemKey = 0
        var itemKeyByExercise: [UUID: Int] = [:]
        let blocks = plan.sortedBlocks.filter { !$0.sortedExercises.isEmpty }

        for (blockIndex, block) in blocks.enumerated() {
            let exercises = block.sortedExercises
            let rounds = block.effectiveRounds
            let isLastBlock = blockIndex == blocks.count - 1

            // Cada instância de exercício no bloco vira um SessionItem (itemKey).
            for ex in exercises where itemKeyByExercise[ex.id] == nil {
                itemKeyByExercise[ex.id] = itemKey
                itemKey += 1
            }

            for round in 0..<rounds {
                for (exIndex, ex) in exercises.enumerated() {
                    let sets = ex.sortedSets
                    let planned = sets.indices.contains(round) ? sets[round] : sets.last
                    let isLastOfRound = exIndex == exercises.count - 1
                    let isLastRound = round == rounds - 1

                    let restAfter: TimeInterval
                    let restKind: RestKind?
                    if !isLastOfRound {
                        // Dentro da rodada de bloco composto: sem descanso (G2).
                        restAfter = 0
                        restKind = nil
                    } else if !isLastRound {
                        restAfter = block.restBetweenRounds
                        restKind = block.kind == .single ? .betweenSets : .betweenRounds
                    } else if !isLastBlock {
                        restAfter = block.restAfterBlock
                        restKind = .afterBlock
                    } else {
                        restAfter = 0
                        restKind = nil
                    }

                    steps.append(RunnerStep(
                        id: steps.count,
                        itemKey: itemKeyByExercise[ex.id] ?? 0,
                        exerciseId: ex.exercise?.id,
                        exerciseName: ex.exercise?.name ?? "Exercício",
                        muscleGroups: [ex.exercise?.primaryMuscle ?? .other] + (ex.exercise?.secondaryMuscles ?? []),
                        blockIndex: blockIndex,
                        blockKind: block.kind,
                        roundIndex: round,
                        roundCount: rounds,
                        setOrderIndex: round,
                        targetReps: planned?.targetReps ?? 10,
                        targetWeight: planned?.targetWeight ?? 0,
                        isWarmup: planned?.isWarmup ?? false,
                        restAfter: restAfter,
                        restKind: restKind
                    ))
                }
            }
        }
        return steps
    }
}
