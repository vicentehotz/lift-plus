import SwiftUI

/// G5: explicação detalhada do exercício (execução, músculos, erros comuns),
/// acessível a partir de qualquer item de treino via botão (ⓘ).
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    muscles

                    if !exercise.instructions.isEmpty {
                        section(title: "Execução", systemImage: "figure.strengthtraining.traditional") {
                            Text(exercise.instructions)
                        }
                    }
                    if !exercise.commonMistakes.isEmpty {
                        section(title: "Erros comuns", systemImage: "exclamationmark.triangle") {
                            Text(exercise.commonMistakes)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var muscles: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Equipamento", value: exercise.equipment.displayName)
            LabeledContent("Músculo principal", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                LabeledContent("Secundários",
                               value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))
            }
        }
        .font(.subheadline)
        .cardBackground()
    }

    @ViewBuilder
    private func section(title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Botão (ⓘ) reutilizável que apresenta o detalhe do exercício.
struct ExerciseInfoButton: View {
    let exercise: Exercise
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Ver detalhes de \(exercise.name)")
        .sheet(isPresented: $showing) {
            ExerciseDetailSheet(exercise: exercise)
        }
    }
}

#Preview {
    ExerciseDetailSheet(exercise: PreviewData.sampleExercise)
}
