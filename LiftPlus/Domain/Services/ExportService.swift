import Foundation
import SwiftData

// MARK: - DTOs versionados (backup manual, independente do iCloud — G13)

/// Arquivo de backup completo. `schemaVersion` permite evoluir o formato de
/// forma retrocompatível sem quebrar backups antigos.
struct BackupFile: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = .now
    var exercises: [ExerciseDTO] = []
    var plans: [PlanDTO] = []
    var schedule: [ScheduleDTO] = []
    var sessions: [SessionDTO] = []
}

struct ExerciseDTO: Codable {
    var id: UUID
    var name: String
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var equipment: String
    var instructions: String
    var commonMistakes: String
    var isCustom: Bool
    var seedSlug: String?
}

struct PlanDTO: Codable {
    var id: UUID
    var name: String
    var notes: String
    var isArchived: Bool
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var blocks: [BlockDTO]
}

struct BlockDTO: Codable {
    var id: UUID
    var orderIndex: Int
    var kind: String
    var rounds: Int
    var restBetweenRounds: TimeInterval
    var restAfterBlock: TimeInterval
    var notes: String
    var exercises: [PlannedExerciseDTO]
}

struct PlannedExerciseDTO: Codable {
    var id: UUID
    var orderIndex: Int
    var notes: String
    var exerciseId: UUID?
    var sets: [PlannedSetDTO]
}

struct PlannedSetDTO: Codable {
    var id: UUID
    var orderIndex: Int
    var targetReps: Int
    var targetWeight: Double
    var isWarmup: Bool
}

struct ScheduleDTO: Codable {
    var id: UUID
    var weekday: Int
    var planId: UUID?
}

struct SessionDTO: Codable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: String
    var planId: UUID?
    var planNameSnapshot: String
    var notes: String
    var totalRestActual: TimeInterval
    var totalVolume: Double
    var items: [SessionItemDTO]
}

struct SessionItemDTO: Codable {
    var id: UUID
    var orderIndex: Int
    var blockIndex: Int
    var blockKind: String
    var exerciseId: UUID?
    var exerciseName: String
    var muscleGroups: [String]
    var skipped: Bool
    var sets: [PerformedSetDTO]
}

struct PerformedSetDTO: Codable {
    var id: UUID
    var orderIndex: Int
    var reps: Int
    var weight: Double
    var targetReps: Int
    var targetWeight: Double
    var restPlanned: TimeInterval
    var restActual: TimeInterval
    var completedAt: Date
    var skipped: Bool
}

struct ImportSummary {
    var exercises = 0
    var plans = 0
    var schedule = 0
    var sessions = 0
}

/// Exporta/importa os dados como arquivo local (JSON completo para restauração,
/// CSV do histórico para análise). O import é **idempotente**: mescla por id,
/// nunca duplicando o que já existe — seguro reimportar o mesmo arquivo.
@MainActor
enum ExportService {
    static let jsonExtension = "json"
    static let csvExtension = "csv"

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Export

    static func makeBackup(context: ModelContext) -> BackupFile {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        let schedule = (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []

        return BackupFile(
            exercises: exercises.map(dto(from:)),
            plans: plans.map(dto(from:)),
            schedule: schedule.map(dto(from:)),
            sessions: sessions.map(dto(from:))
        )
    }

    static func exportJSON(context: ModelContext) throws -> Data {
        try encoder.encode(makeBackup(context: context))
    }

    /// CSV plano do histórico: uma linha por série realizada, ideal para abrir
    /// em planilha. Só sessões concluídas/abandonadas (não as em andamento).
    static func exportSessionsCSV(context: ModelContext) -> Data {
        let sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
            .filter { $0.status != .inProgress }
            .sorted { $0.startedAt < $1.startedAt }

        var rows = ["data,ficha,exercicio,serie,reps,carga_kg,reps_alvo,carga_alvo_kg,descanso_real_s,pulada,duracao_sessao_s"]
        let df = ISO8601DateFormatter()

        for session in sessions {
            for item in session.sortedItems {
                for (i, set) in item.sortedSets.enumerated() {
                    let fields: [String] = [
                        df.string(from: session.startedAt),
                        session.planNameSnapshot,
                        item.exerciseNameSnapshot,
                        "\(i + 1)",
                        "\(set.reps)",
                        trimmed(set.weight),
                        "\(set.targetRepsSnapshot)",
                        trimmed(set.targetWeightSnapshot),
                        trimmed(set.restActual),
                        set.skipped ? "sim" : "nao",
                        "\(Int(session.duration))",
                    ]
                    rows.append(fields.map(escape).joined(separator: ","))
                }
            }
        }
        return Data(rows.joined(separator: "\n").utf8)
    }

    // MARK: - Import (merge idempotente por id)

    @discardableResult
    static func importBackup(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        let backup = try decoder.decode(BackupFile.self, from: data)
        var summary = ImportSummary()

        // Exercícios: dedupe por id e por seedSlug; mapeia id do arquivo → objeto.
        let existingExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var exercisesById = Dictionary(existingExercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var exercisesBySlug: [String: Exercise] = [:]
        for e in existingExercises { if let s = e.seedSlug { exercisesBySlug[s] = e } }

        for dto in backup.exercises {
            if exercisesById[dto.id] != nil { continue }
            if let slug = dto.seedSlug, let existing = exercisesBySlug[slug] {
                exercisesById[dto.id] = existing // reaproveita o seed já presente
                continue
            }
            let e = Exercise(
                name: dto.name,
                primaryMuscle: MuscleGroup(rawValue: dto.primaryMuscle) ?? .other,
                secondaryMuscles: dto.secondaryMuscles.compactMap(MuscleGroup.init(rawValue:)),
                equipment: Equipment(rawValue: dto.equipment) ?? .other,
                instructions: dto.instructions,
                commonMistakes: dto.commonMistakes,
                isCustom: dto.isCustom,
                seedSlug: dto.seedSlug
            )
            e.id = dto.id
            context.insert(e)
            exercisesById[dto.id] = e
            summary.exercises += 1
        }

        // Planos.
        let existingPlanIds = Set(((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []).map(\.id))
        var plansById: [UUID: WorkoutPlan] = [:]
        for p in ((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []) { plansById[p.id] = p }

        for dto in backup.plans where !existingPlanIds.contains(dto.id) {
            let plan = WorkoutPlan(name: dto.name, orderIndex: dto.orderIndex)
            plan.id = dto.id
            plan.notes = dto.notes
            plan.isArchived = dto.isArchived
            plan.createdAt = dto.createdAt
            plan.updatedAt = dto.updatedAt
            context.insert(plan)
            plan.blocks = dto.blocks.map { build($0, exercisesById: exercisesById, context: context) }
            plansById[dto.id] = plan
            summary.plans += 1
        }

        // Agenda.
        let existingScheduleIds = Set(((try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []).map(\.id))
        for dto in backup.schedule where !existingScheduleIds.contains(dto.id) {
            let entry = ScheduleEntry(weekday: dto.weekday, plan: dto.planId.flatMap { plansById[$0] })
            entry.id = dto.id
            context.insert(entry)
            summary.schedule += 1
        }

        // Sessões (autossuficientes: snapshots, sem depender de planos/exercícios).
        let existingSessionIds = Set(((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).map(\.id))
        for dto in backup.sessions where !existingSessionIds.contains(dto.id) {
            context.insert(build(dto, context: context))
            summary.sessions += 1
        }

        try context.save()
        return summary
    }

    /// Recalcula dados derivados (volume por sessão) a partir do histórico bruto.
    /// Idempotente — roda após import ou merge de sync (v3).
    static func rebuildDerivedData(context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for s in sessions {
            s.totalVolume = (s.items ?? [])
                .flatMap { $0.sets ?? [] }
                .filter { !$0.skipped }
                .reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
        try? context.save()
    }

    // MARK: - Mapeamento modelo → DTO

    private static func dto(from e: Exercise) -> ExerciseDTO {
        ExerciseDTO(id: e.id, name: e.name, primaryMuscle: e.primaryMuscleRaw,
                    secondaryMuscles: e.secondaryMusclesRaw, equipment: e.equipmentRaw,
                    instructions: e.instructions, commonMistakes: e.commonMistakes,
                    isCustom: e.isCustom, seedSlug: e.seedSlug)
    }

    private static func dto(from p: WorkoutPlan) -> PlanDTO {
        PlanDTO(id: p.id, name: p.name, notes: p.notes, isArchived: p.isArchived,
                orderIndex: p.orderIndex, createdAt: p.createdAt, updatedAt: p.updatedAt,
                blocks: p.sortedBlocks.map(dto(from:)))
    }

    private static func dto(from b: WorkoutBlock) -> BlockDTO {
        BlockDTO(id: b.id, orderIndex: b.orderIndex, kind: b.kindRaw, rounds: b.rounds,
                 restBetweenRounds: b.restBetweenRounds, restAfterBlock: b.restAfterBlock,
                 notes: b.notes, exercises: b.sortedExercises.map(dto(from:)))
    }

    private static func dto(from pe: PlannedExercise) -> PlannedExerciseDTO {
        PlannedExerciseDTO(id: pe.id, orderIndex: pe.orderIndex, notes: pe.notes,
                           exerciseId: pe.exercise?.id,
                           sets: pe.sortedSets.map { PlannedSetDTO(id: $0.id, orderIndex: $0.orderIndex, targetReps: $0.targetReps, targetWeight: $0.targetWeight, isWarmup: $0.isWarmup) })
    }

    private static func dto(from s: ScheduleEntry) -> ScheduleDTO {
        ScheduleDTO(id: s.id, weekday: s.weekday, planId: s.plan?.id)
    }

    private static func dto(from s: WorkoutSession) -> SessionDTO {
        SessionDTO(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, status: s.statusRaw,
                   planId: s.planId, planNameSnapshot: s.planNameSnapshot, notes: s.notes,
                   totalRestActual: s.totalRestActual, totalVolume: s.totalVolume,
                   items: s.sortedItems.map(dto(from:)))
    }

    private static func dto(from i: SessionItem) -> SessionItemDTO {
        SessionItemDTO(id: i.id, orderIndex: i.orderIndex, blockIndex: i.blockIndexSnapshot,
                       blockKind: i.blockKindSnapshotRaw, exerciseId: i.exerciseId,
                       exerciseName: i.exerciseNameSnapshot, muscleGroups: i.muscleGroupsSnapshotRaw,
                       skipped: i.skipped,
                       sets: i.sortedSets.map { PerformedSetDTO(id: $0.id, orderIndex: $0.orderIndex, reps: $0.reps, weight: $0.weight, targetReps: $0.targetRepsSnapshot, targetWeight: $0.targetWeightSnapshot, restPlanned: $0.restPlanned, restActual: $0.restActual, completedAt: $0.completedAt, skipped: $0.skipped) })
    }

    // MARK: - Mapeamento DTO → modelo

    private static func build(_ dto: BlockDTO, exercisesById: [UUID: Exercise], context: ModelContext) -> WorkoutBlock {
        let block = WorkoutBlock(kind: BlockKind(rawValue: dto.kind) ?? .single, orderIndex: dto.orderIndex, rounds: dto.rounds)
        block.id = dto.id
        block.restBetweenRounds = dto.restBetweenRounds
        block.restAfterBlock = dto.restAfterBlock
        block.notes = dto.notes
        context.insert(block)
        block.exercises = dto.exercises.map { peDTO in
            let pe = PlannedExercise(exercise: peDTO.exerciseId.flatMap { exercisesById[$0] }, orderIndex: peDTO.orderIndex)
            pe.id = peDTO.id
            pe.notes = peDTO.notes
            context.insert(pe)
            pe.sets = peDTO.sets.map { sDTO in
                let set = PlannedSet(orderIndex: sDTO.orderIndex, targetReps: sDTO.targetReps, targetWeight: sDTO.targetWeight, isWarmup: sDTO.isWarmup)
                set.id = sDTO.id
                context.insert(set)
                return set
            }
            return pe
        }
        return block
    }

    private static func build(_ dto: SessionDTO, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(planId: dto.planId, planNameSnapshot: dto.planNameSnapshot)
        session.id = dto.id
        session.startedAt = dto.startedAt
        session.endedAt = dto.endedAt
        session.statusRaw = dto.status
        session.notes = dto.notes
        session.totalRestActual = dto.totalRestActual
        session.totalVolume = dto.totalVolume
        context.insert(session)
        session.items = dto.items.map { iDTO in
            let item = SessionItem(orderIndex: iDTO.orderIndex, blockIndex: iDTO.blockIndex,
                                   blockKind: BlockKind(rawValue: iDTO.blockKind) ?? .single,
                                   exerciseId: iDTO.exerciseId, exerciseName: iDTO.exerciseName,
                                   muscleGroups: iDTO.muscleGroups.compactMap(MuscleGroup.init(rawValue:)))
            item.id = iDTO.id
            item.skipped = iDTO.skipped
            context.insert(item)
            item.sets = iDTO.sets.map { sDTO in
                let set = PerformedSet(orderIndex: sDTO.orderIndex, reps: sDTO.reps, weight: sDTO.weight,
                                       targetReps: sDTO.targetReps, targetWeight: sDTO.targetWeight,
                                       restPlanned: sDTO.restPlanned, skipped: sDTO.skipped)
                set.id = sDTO.id
                set.restActual = sDTO.restActual
                set.completedAt = sDTO.completedAt
                context.insert(set)
                return set
            }
            return item
        }
        return session
    }

    // MARK: - CSV helpers

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.2f", value)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
