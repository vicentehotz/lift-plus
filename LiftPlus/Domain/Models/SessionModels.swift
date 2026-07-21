import Foundation
import SwiftData

// Modelos da árvore "realizado". A sessão é um snapshot autossuficiente:
// referencia o plano e o catálogo apenas por UUID fraco + nome copiado,
// de modo que editar/apagar fichas nunca corrompe o histórico.

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var statusRaw: String = SessionStatus.inProgress.rawValue
    var planId: UUID?
    var planNameSnapshot: String = ""
    var notes: String = ""
    var totalRestActual: TimeInterval = 0
    /// Volume total (Σ reps × carga) materializado no fim da sessão.
    var totalVolume: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \SessionItem.session)
    var items: [SessionItem]? = []

    init(planId: UUID?, planNameSnapshot: String) {
        self.planId = planId
        self.planNameSnapshot = planNameSnapshot
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var sortedItems: [SessionItem] {
        (items ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }
}

@Model
final class SessionItem {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var blockIndexSnapshot: Int = 0
    var blockKindSnapshotRaw: String = BlockKind.single.rawValue
    var exerciseId: UUID?
    var exerciseNameSnapshot: String = ""
    var muscleGroupsSnapshotRaw: [String] = []
    var skipped: Bool = false

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \PerformedSet.item)
    var sets: [PerformedSet]? = []

    init(orderIndex: Int,
         blockIndex: Int,
         blockKind: BlockKind,
         exerciseId: UUID?,
         exerciseName: String,
         muscleGroups: [MuscleGroup]) {
        self.orderIndex = orderIndex
        self.blockIndexSnapshot = blockIndex
        self.blockKindSnapshotRaw = blockKind.rawValue
        self.exerciseId = exerciseId
        self.exerciseNameSnapshot = exerciseName
        self.muscleGroupsSnapshotRaw = muscleGroups.map(\.rawValue)
    }

    var sortedSets: [PerformedSet] {
        (sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class PerformedSet {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var reps: Int = 0
    var weight: Double = 0
    var targetRepsSnapshot: Int = 0
    var targetWeightSnapshot: Double = 0
    var restPlanned: TimeInterval = 0
    var restActual: TimeInterval = 0
    var completedAt: Date = Date.now
    var skipped: Bool = false

    var item: SessionItem?

    init(orderIndex: Int,
         reps: Int,
         weight: Double,
         targetReps: Int,
         targetWeight: Double,
         restPlanned: TimeInterval,
         skipped: Bool = false) {
        self.orderIndex = orderIndex
        self.reps = reps
        self.weight = weight
        self.targetRepsSnapshot = targetReps
        self.targetWeightSnapshot = targetWeight
        self.restPlanned = restPlanned
        self.skipped = skipped
    }
}
