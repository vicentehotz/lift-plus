import SwiftUI
import SwiftData

/// Seleção de exercício do catálogo com busca e filtro por grupo muscular,
/// além de criação de exercício custom. Usado pelo editor de fichas.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let onPick: (Exercise) -> Void

    @State private var search = ""
    @State private var muscleFilter: MuscleGroup?
    @State private var showingCustom = false

    private var filtered: [Exercise] {
        exercises.filter { ex in
            let matchesSearch = search.isEmpty
                || ex.name.localizedCaseInsensitiveContains(search)
            let matchesMuscle = muscleFilter == nil
                || ex.primaryMuscle == muscleFilter
                || ex.secondaryMuscles.contains(muscleFilter!)
            return matchesSearch && matchesMuscle
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Todos", isOn: muscleFilter == nil) { muscleFilter = nil }
                        ForEach(MuscleGroup.allCases) { muscle in
                            FilterChip(title: muscle.displayName, isOn: muscleFilter == muscle) {
                                muscleFilter = muscle
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                ForEach(filtered) { exercise in
                    HStack {
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                Text(exercise.primaryMuscle.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        ExerciseInfoButton(exercise: exercise)
                    }
                }
            }
            .searchable(text: $search, prompt: "Buscar exercício")
            .navigationTitle("Escolher exercício")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustom = true
                    } label: {
                        Label("Novo", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCustom) {
                CustomExerciseEditor { exercise in
                    context.insert(exercise)
                    try? context.save()
                    onPick(exercise)
                    dismiss()
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? Color.accentColor : Color(.tertiarySystemFill),
                            in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Criação de exercício do usuário (isCustom = true, sem seedSlug).
struct CustomExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Exercise) -> Void

    @State private var name = ""
    @State private var primary: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var instructions = ""
    @State private var mistakes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercício") {
                    TextField("Nome", text: $name)
                    Picker("Músculo principal", selection: $primary) {
                        ForEach(MuscleGroup.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Equipamento", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Execução (opcional)") {
                    TextField("Como executar", text: $instructions, axis: .vertical)
                }
                Section("Erros comuns (opcional)") {
                    TextField("Erros comuns", text: $mistakes, axis: .vertical)
                }
            }
            .navigationTitle("Novo exercício")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salvar") {
                        let exercise = Exercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            primaryMuscle: primary,
                            equipment: equipment,
                            instructions: instructions,
                            commonMistakes: mistakes,
                            isCustom: true
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
