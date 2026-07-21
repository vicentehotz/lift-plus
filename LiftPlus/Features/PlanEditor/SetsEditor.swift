import SwiftUI
import SwiftData

/// Editor das séries planejadas de um exercício. Para `single`, cada linha é
/// uma série (permite pirâmide: cargas/reps diferentes por linha). Para blocos
/// compostos, as séries acompanham o número de rodadas do bloco.
struct SetsEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var planned: PlannedExercise
    let block: WorkoutBlock

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(planned.sortedSets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    Text("\(index + 1)ª")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)

                    NumberField(label: "reps", value: bindingReps(set), format: "%d rep")
                    NumberField(label: "carga", value: bindingWeight(set), format: "%g kg")

                    if block.kind == .single {
                        Button {
                            removeSet(set)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Remover série \(index + 1)")
                    }
                }
            }

            if block.kind == .single {
                Button {
                    addSet()
                } label: {
                    Label("Adicionar série", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bindingReps(_ set: PlannedSet) -> Binding<Double> {
        Binding(get: { Double(set.targetReps) },
                set: { set.targetReps = Int($0); save() })
    }
    private func bindingWeight(_ set: PlannedSet) -> Binding<Double> {
        Binding(get: { set.targetWeight }, set: { set.targetWeight = $0; save() })
    }

    private func addSet() {
        let last = planned.sortedSets.last
        let set = PlannedSet(orderIndex: planned.sortedSets.count,
                             targetReps: last?.targetReps ?? 10,
                             targetWeight: last?.targetWeight ?? 0)
        set.plannedExercise = planned
        planned.sets = (planned.sets ?? []) + [set]
        context.insert(set)
        save()
    }

    private func removeSet(_ set: PlannedSet) {
        guard planned.sortedSets.count > 1 else { return }
        context.delete(set)
        for (i, s) in planned.sortedSets.enumerated() where s.id != set.id {
            s.orderIndex = i
        }
        save()
    }

    private func save() {
        planned.block?.plan?.updatedAt = .now
        try? context.save()
    }
}

/// Campo numérico compacto com stepper via teclado numérico.
private struct NumberField: View {
    let label: String
    @Binding var value: Double
    let format: String

    var body: some View {
        HStack(spacing: 2) {
            TextField(label, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 40)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(label)
    }

    private var unit: String { format.contains("kg") ? "kg" : "reps" }
}
