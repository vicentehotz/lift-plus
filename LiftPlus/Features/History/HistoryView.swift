import SwiftUI
import SwiftData

/// Histórico simples da v1: lista de sessões concluídas com detalhe de séries
/// realizadas vs. alvo. Os dados já estão no formato que a v2/v3 vão consumir.
struct HistoryView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.statusRaw != "inProgress" },
           sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    EmptyStateView(
                        systemImage: "clock.arrow.circlepath",
                        title: "Nenhum treino registrado",
                        message: "Suas sessões concluídas aparecerão aqui."
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                sessionRow(session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Histórico")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.planNameSnapshot).font(.headline)
                if session.status == .abandoned {
                    Text("incompleto")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Format.duration(session.duration)) · \(Int(session.totalVolume)) kg de volume")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section("Resumo") {
                LabeledContent("Data", value: session.startedAt.formatted(date: .long, time: .shortened))
                LabeledContent("Duração", value: Format.duration(session.duration))
                LabeledContent("Volume total", value: "\(Int(session.totalVolume)) kg")
                LabeledContent("Descanso real", value: Format.duration(session.totalRestActual))
            }
            ForEach(session.sortedItems) { item in
                Section(item.exerciseNameSnapshot) {
                    ForEach(Array(item.sortedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("\(index + 1)ª").foregroundStyle(.secondary)
                            Spacer()
                            if set.skipped {
                                Text("pulada").foregroundStyle(.secondary)
                            } else {
                                Text("\(set.reps) × \(Format.weight(set.weight))")
                                if set.reps != set.targetRepsSnapshot || set.weight != set.targetWeightSnapshot {
                                    Text("(alvo \(set.targetRepsSnapshot) × \(Format.weight(set.targetWeightSnapshot)))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(session.planNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
