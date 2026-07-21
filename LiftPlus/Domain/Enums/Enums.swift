import Foundation

/// Tipo do bloco de exercícios. Todo exercício vive em um bloco,
/// mesmo sozinho (`single`) — o bloco é a unidade de execução e descanso.
enum BlockKind: String, Codable, CaseIterable, Identifiable {
    case single
    case biSet
    case triSet
    case circuit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: "Exercício"
        case .biSet: "Bi-set"
        case .triSet: "Tri-set"
        case .circuit: "Circuito"
        }
    }

    /// Número de exercícios esperado no bloco (nil = livre).
    var expectedExerciseCount: Int? {
        switch self {
        case .single: 1
        case .biSet: 2
        case .triSet: 3
        case .circuit: nil
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quadriceps, hamstrings, glutes, calves
    case abs, lowerBack, fullBody, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Peito"
        case .back: "Costas"
        case .shoulders: "Ombros"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraços"
        case .quadriceps: "Quadríceps"
        case .hamstrings: "Posteriores"
        case .glutes: "Glúteos"
        case .calves: "Panturrilhas"
        case .abs: "Abdômen"
        case .lowerBack: "Lombar"
        case .fullBody: "Corpo inteiro"
        case .other: "Outro"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: "Barra"
        case .dumbbell: "Halteres"
        case .machine: "Máquina"
        case .cable: "Polia"
        case .bodyweight: "Peso corporal"
        case .kettlebell: "Kettlebell"
        case .band: "Elástico"
        case .other: "Outro"
        }
    }
}

enum SessionStatus: String, Codable {
    case inProgress
    case completed
    case abandoned
}

enum RestKind: String, Codable {
    case betweenSets
    case betweenRounds
    case afterBlock
}
