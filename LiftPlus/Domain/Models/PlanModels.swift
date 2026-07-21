import Foundation
import SwiftData

// Modelos da árvore "planejado". Restrições CloudKit respeitadas desde a v1:
// todos os atributos com default ou opcionais, sem @Attribute(.unique),
// relacionamentos opcionais com inverso, ordenação por orderIndex explícito.

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var primaryMuscleRaw: String = MuscleGroup.other.rawValue
    var secondaryMusclesRaw: [String] = []
    var equipmentRaw: String = Equipment.other.rawValue
    var instructions: String = ""
    var commonMistakes: String = ""
    var isCustom: Bool = false
    /// Identificador estável do seed do bundle; nil para exercícios do usuário.
    /// Unicidade garantida em código (SeedService), não por constraint.
    var seedSlug: String?

    init(name: String,
         primaryMuscle: MuscleGroup,
         secondaryMuscles: [MuscleGroup] = [],
         equipment: Equipment = .other,
         instructions: String = "",
         commonMistakes: String = "",
         isCustom: Bool = false,
         seedSlug: String? = nil) {
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.instructions = instructions
        self.commonMistakes = commonMistakes
        self.isCustom = isCustom
        self.seedSlug = seedSlug
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .other }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        secondaryMusclesRaw.compactMap(MuscleGroup.init(rawValue:))
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }
}

@Model
final class WorkoutPlan {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var isArchived: Bool = false
    var orderIndex: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \WorkoutBlock.plan)
    var blocks: [WorkoutBlock]? = []

    @Relationship(deleteRule: .cascade, inverse: \ScheduleEntry.plan)
    var schedules: [ScheduleEntry]? = []

    init(name: String, orderIndex: Int = 0) {
        self.name = name
        self.orderIndex = orderIndex
    }

    var sortedBlocks: [WorkoutBlock] {
        (blocks ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class WorkoutBlock {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var kindRaw: String = BlockKind.single.rawValue
    /// Número de passagens do bloco. Para `single`, é derivado do nº de
    /// séries planejadas; para bi-set/tri-set/circuito, é o nº de voltas.
    var rounds: Int = 3
    var restBetweenRounds: TimeInterval = 60
    var restAfterBlock: TimeInterval = 90
    var notes: String = ""

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.block)
    var exercises: [PlannedExercise]? = []

    init(kind: BlockKind, orderIndex: Int = 0, rounds: Int = 3) {
        self.kindRaw = kind.rawValue
        self.orderIndex = orderIndex
        self.rounds = rounds
    }

    var kind: BlockKind {
        get { BlockKind(rawValue: kindRaw) ?? .single }
        set { kindRaw = newValue.rawValue }
    }

    var sortedExercises: [PlannedExercise] {
        (exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Voltas efetivas: para `single`, o nº de séries do exercício manda.
    var effectiveRounds: Int {
        if kind == .single, let sets = sortedExercises.first?.sortedSets, !sets.isEmpty {
            return sets.count
        }
        return max(rounds, 1)
    }
}

@Model
final class PlannedExercise {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var notes: String = ""

    var block: WorkoutBlock?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.plannedExercise)
    var sets: [PlannedSet]? = []

    init(exercise: Exercise?, orderIndex: Int = 0) {
        self.exercise = exercise
        self.orderIndex = orderIndex
    }

    var sortedSets: [PlannedSet] {
        (sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class PlannedSet {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var targetReps: Int = 10
    var targetWeight: Double = 0
    var isWarmup: Bool = false

    var plannedExercise: PlannedExercise?

    init(orderIndex: Int = 0, targetReps: Int = 10, targetWeight: Double = 0, isWarmup: Bool = false) {
        self.orderIndex = orderIndex
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.isWarmup = isWarmup
    }
}

/// Alocação de uma ficha a um dia da semana (1 = domingo … 7 = sábado,
/// convenção de `Calendar.current.component(.weekday,...)`).
@Model
final class ScheduleEntry {
    var id: UUID = UUID()
    var weekday: Int = 2

    var plan: WorkoutPlan?

    init(weekday: Int, plan: WorkoutPlan?) {
        self.weekday = weekday
        self.plan = plan
    }
}
