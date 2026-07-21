import SwiftUI
import SwiftData

/// Home: mostra o(s) treino(s) do dia (via agenda) e permite iniciar ou
/// retomar uma sessão em andamento.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [ScheduleEntry]
    @Query(filter: #Predicate<WorkoutSession> { $0.statusRaw == "inProgress" })
    private var inProgress: [WorkoutSession]

    @State private var runningPlan: WorkoutPlan?
    @State private var resumingSession: WorkoutSession?

    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    private var todaysPlans: [WorkoutPlan] {
        entries.filter { $0.weekday == todayWeekday }.compactMap(\.plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let session = inProgress.first {
                        resumeCard(session)
                    }

                    if todaysPlans.isEmpty {
                        EmptyStateView(
                            systemImage: "moon.zzz",
                            title: "Sem treino agendado hoje",
                            message: "Aproveite o descanso ou escolha uma ficha na aba Fichas."
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(todaysPlans) { plan in
                            planCard(plan)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Self.greeting)
            .fullScreenCover(item: $runningPlan) { plan in
                WorkoutRunnerView(plan: plan, existingSession: nil)
            }
            .fullScreenCover(item: $resumingSession) { session in
                WorkoutRunnerView(plan: nil, existingSession: session)
            }
        }
    }

    private func resumeCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Treino em andamento", systemImage: "figure.run")
                .font(.headline)
            Text(session.planNameSnapshot)
                .foregroundStyle(.secondary)
            BigActionButton(title: "Retomar treino", systemImage: "play.fill") {
                resumingSession = session
            }
        }
        .cardBackground()
    }

    private func planCard(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.name).font(.title3.weight(.semibold))
            Text("\(plan.sortedBlocks.count) bloco(s)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            BigActionButton(title: "Iniciar treino", systemImage: "play.fill") {
                runningPlan = plan
            }
            .disabled(!inProgress.isEmpty)
        }
        .cardBackground()
    }

    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
