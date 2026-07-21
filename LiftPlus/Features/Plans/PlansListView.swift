import SwiftUI
import SwiftData

struct PlansListView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutPlan> { !$0.isArchived },
           sort: \WorkoutPlan.orderIndex) private var plans: [WorkoutPlan]

    @State private var editingPlan: WorkoutPlan?

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle",
                        title: "Nenhuma ficha",
                        message: "Crie sua primeira ficha de treino para começar."
                    )
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink(value: plan) {
                                planRow(plan)
                            }
                        }
                        .onDelete(perform: archive)
                    }
                }
            }
            .navigationTitle("Fichas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addPlan()
                    } label: {
                        Label("Nova ficha", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanEditorView(plan: plan)
            }
        }
    }

    private func planRow(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name).font(.headline)
            Text(summary(plan))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ plan: WorkoutPlan) -> String {
        let blocks = plan.sortedBlocks
        let exercises = blocks.reduce(0) { $0 + $1.sortedExercises.count }
        return "\(blocks.count) bloco(s) · \(exercises) exercício(s)"
    }

    private func addPlan() {
        let plan = WorkoutPlan(name: "Nova ficha", orderIndex: plans.count)
        context.insert(plan)
        try? context.save()
    }

    private func archive(_ offsets: IndexSet) {
        for index in offsets {
            plans[index].isArchived = true
            plans[index].updatedAt = .now
        }
        try? context.save()
    }
}

#Preview {
    PlansListView()
        .modelContainer(PreviewData.container)
}
