import Foundation
import SwiftData

/// Carrega o catálogo de exercícios do bundle no store local, de forma
/// idempotente. Sem @Attribute(.unique) (restrição CloudKit), a deduplicação
/// é feita em código por `seedSlug`: exercícios já presentes são atualizados,
/// não duplicados — seguro rodar a cada launch e após merge de sync (v3).
enum SeedService {
    struct SeedExercise: Decodable {
        let slug: String
        let name: String
        let primaryMuscle: MuscleGroup
        let secondaryMuscles: [MuscleGroup]
        let equipment: Equipment
        let instructions: String
        let commonMistakes: String
    }

    static func seedIfNeeded(context: ModelContext, bundle: Bundle = .main) {
        guard let seeds = load(from: bundle), !seeds.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var bySlug: [String: Exercise] = [:]
        for ex in existing {
            if let slug = ex.seedSlug { bySlug[slug] = ex }
        }

        for seed in seeds {
            if let current = bySlug[seed.slug] {
                current.name = seed.name
                current.primaryMuscle = seed.primaryMuscle
                current.secondaryMusclesRaw = seed.secondaryMuscles.map(\.rawValue)
                current.equipment = seed.equipment
                current.instructions = seed.instructions
                current.commonMistakes = seed.commonMistakes
            } else {
                let exercise = Exercise(
                    name: seed.name,
                    primaryMuscle: seed.primaryMuscle,
                    secondaryMuscles: seed.secondaryMuscles,
                    equipment: seed.equipment,
                    instructions: seed.instructions,
                    commonMistakes: seed.commonMistakes,
                    isCustom: false,
                    seedSlug: seed.slug
                )
                context.insert(exercise)
            }
        }
        try? context.save()
    }

    private static func load(from bundle: Bundle) -> [SeedExercise]? {
        guard let url = bundle.url(forResource: "seed_exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([SeedExercise].self, from: data)
    }
}
