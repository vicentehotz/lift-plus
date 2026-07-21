import SwiftUI
import SwiftData

/// G3: alocação de fichas a dias da semana, em formato de agenda semanal.
struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [ScheduleEntry]
    @Query(filter: #Predicate<WorkoutPlan> { !$0.isArchived },
           sort: \WorkoutPlan.orderIndex) private var plans: [WorkoutPlan]

    @State private var assigningWeekday: Int?

    // 1 = domingo … 7 = sábado (convenção Calendar). Exibimos Seg–Dom.
    private let weekdays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            List {
                ForEach(weekdays, id: \.self) { weekday in
                    Section(Self.weekdayName(weekday)) {
                        let dayEntries = entries.filter { $0.weekday == weekday }
                        if dayEntries.isEmpty {
                            Text("Descanso")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(dayEntries) { entry in
                                HStack {
                                    Text(entry.plan?.name ?? "—")
                                    Spacer()
                                    Button(role: .destructive) {
                                        context.delete(entry)
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remover da agenda")
                                }
                            }
                        }
                        Button {
                            assigningWeekday = weekday
                        } label: {
                            Label("Atribuir ficha", systemImage: "plus")
                                .font(.subheadline)
                        }
                        .disabled(plans.isEmpty)
                    }
                }
            }
            .navigationTitle("Agenda")
            .confirmationDialog("Escolher ficha",
                                isPresented: Binding(get: { assigningWeekday != nil },
                                                     set: { if !$0 { assigningWeekday = nil } }),
                                titleVisibility: .visible) {
                ForEach(plans) { plan in
                    Button(plan.name) { assign(plan) }
                }
                Button("Cancelar", role: .cancel) { assigningWeekday = nil }
            }
        }
    }

    private func assign(_ plan: WorkoutPlan) {
        guard let weekday = assigningWeekday else { return }
        let entry = ScheduleEntry(weekday: weekday, plan: plan)
        context.insert(entry)
        try? context.save()
        assigningWeekday = nil
    }

    static func weekdayName(_ weekday: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        let symbols = cal.weekdaySymbols // index 0 = domingo
        let name = symbols[(weekday - 1) % 7]
        return name.prefix(1).capitalized + name.dropFirst()
    }
}

#Preview {
    ScheduleView()
        .modelContainer(PreviewData.container)
}
