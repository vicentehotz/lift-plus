import SwiftUI
import SwiftData

/// Edição de uma ficha: blocos (single/bi-set/tri-set/circuito), exercícios
/// por bloco e séries/reps/carga por exercício (G1, G2).
struct PlanEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WorkoutPlan

    @State private var pickerBlock: WorkoutBlock?

    var body: some View {
        List {
            Section {
                TextField("Nome da ficha", text: $plan.name)
                    .font(.headline)
                TextField("Observações", text: $plan.notes, axis: .vertical)
                    .font(.subheadline)
            }

            ForEach(plan.sortedBlocks) { block in
                blockSection(block)
            }

            Section {
                Menu {
                    ForEach(BlockKind.allCases) { kind in
                        Button(kind.displayName) { addBlock(kind) }
                    }
                } label: {
                    Label("Adicionar bloco", systemImage: "plus.square.on.square")
                }
            }
        }
        .navigationTitle("Editar ficha")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: plan.name) { _, _ in touch() }
        .sheet(item: $pickerBlock) { block in
            ExercisePickerView { exercise in
                addExercise(exercise, to: block)
            }
        }
    }

    @ViewBuilder
    private func blockSection(_ block: WorkoutBlock) -> some View {
        Section {
            ForEach(block.sortedExercises) { planned in
                exerciseRow(planned, in: block)
            }
            .onDelete { removeExercises($0, from: block) }

            Button {
                pickerBlock = block
            } label: {
                Label("Adicionar exercício", systemImage: "plus")
            }

            if block.kind != .single {
                Stepper("Rodadas: \(block.rounds)", value: bindingRounds(block), in: 1...10)
            }
            restControls(block)
        } header: {
            HStack {
                Text(block.kind.displayName)
                Spacer()
                Button(role: .destructive) {
                    deleteBlock(block)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remover bloco")
            }
        }
    }

    private func exerciseRow(_ planned: PlannedExercise, in block: WorkoutBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(planned.exercise?.name ?? "Exercício")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let exercise = planned.exercise {
                    ExerciseInfoButton(exercise: exercise)
                }
            }
            SetsEditor(planned: planned, block: block)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func restControls(_ block: WorkoutBlock) -> some View {
        if block.kind == .single {
            RestStepper(title: "Descanso entre séries",
                        value: bindingRestRounds(block))
        } else {
            RestStepper(title: "Descanso entre rodadas",
                        value: bindingRestRounds(block))
        }
        RestStepper(title: "Descanso após o bloco",
                    value: bindingRestAfter(block))
    }

    // MARK: - Bindings que persistem

    private func bindingRounds(_ block: WorkoutBlock) -> Binding<Int> {
        Binding(get: { block.rounds }, set: { block.rounds = $0; touch() })
    }
    private func bindingRestRounds(_ block: WorkoutBlock) -> Binding<TimeInterval> {
        Binding(get: { block.restBetweenRounds }, set: { block.restBetweenRounds = $0; touch() })
    }
    private func bindingRestAfter(_ block: WorkoutBlock) -> Binding<TimeInterval> {
        Binding(get: { block.restAfterBlock }, set: { block.restAfterBlock = $0; touch() })
    }

    // MARK: - Mutações

    private func addBlock(_ kind: BlockKind) {
        let block = WorkoutBlock(kind: kind, orderIndex: plan.sortedBlocks.count)
        block.plan = plan
        plan.blocks = (plan.blocks ?? []) + [block]
        context.insert(block)
        touch()
    }

    private func deleteBlock(_ block: WorkoutBlock) {
        context.delete(block)
        reindex()
        touch()
    }

    private func addExercise(_ exercise: Exercise, to block: WorkoutBlock) {
        let planned = PlannedExercise(exercise: exercise, orderIndex: block.sortedExercises.count)
        planned.block = block
        // Séries iniciais: single começa com 3, composto com 1 (as rodadas do
        // bloco definem as repetições do exercício).
        let initialSets = block.kind == .single ? 3 : 1
        for i in 0..<initialSets {
            let set = PlannedSet(orderIndex: i, targetReps: 10, targetWeight: 0)
            set.plannedExercise = planned
            planned.sets = (planned.sets ?? []) + [set]
            context.insert(set)
        }
        block.exercises = (block.exercises ?? []) + [planned]
        context.insert(planned)
        touch()
    }

    private func removeExercises(_ offsets: IndexSet, from block: WorkoutBlock) {
        let sorted = block.sortedExercises
        for index in offsets { context.delete(sorted[index]) }
        touch()
    }

    private func reindex() {
        for (i, block) in plan.sortedBlocks.enumerated() { block.orderIndex = i }
    }

    private func touch() {
        plan.updatedAt = .now
        try? context.save()
    }
}

/// Stepper de descanso em passos de 15s.
private struct RestStepper: View {
    let title: String
    @Binding var value: TimeInterval

    var body: some View {
        Stepper(value: $value, in: 0...600, step: 15) {
            HStack {
                Text(title)
                Spacer()
                Text(Format.duration(value)).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }
}
