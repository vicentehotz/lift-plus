import SwiftUI
import SwiftData

/// G4/G7: execução do treino. Botão primário grande na zona do polegar,
/// pré-preenchimento com o alvo (1 toque por série no caminho feliz) e timer
/// de descanso que avança automaticamente para o próximo item.
struct WorkoutRunnerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan?
    let existingSession: WorkoutSession?

    @State private var vm: WorkoutRunnerViewModel?
    @State private var reps = 0
    @State private var weight = 0.0
    @State private var showAbandon = false
    // Tick para atualizar a contagem do descanso (relógio é por data absoluta).
    @State private var now = Date.now
    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                unavailable
            }
        }
        .onAppear(perform: bootstrap)
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Conteúdo principal

    private func content(_ vm: WorkoutRunnerViewModel) -> some View {
        ZStack {
            VStack(spacing: 0) {
                header(vm)
                Divider()
                if let step = vm.currentStep {
                    exerciseArea(vm, step: step)
                } else {
                    Spacer()
                }
                Spacer()
                if !vm.isResting, vm.currentStep != nil {
                    actionArea(vm)
                }
            }

            if vm.isResting {
                RestOverlay(
                    remaining: vm.restTimer.remaining,
                    nextExercise: vm.currentStep?.exerciseName ?? "",
                    onSkip: { vm.skipRest(); syncFields(vm) },
                    onAdd: { vm.addRest(15) }
                )
                .transition(.opacity)
            }
        }
        .animation(.default, value: vm.isResting)
        .onChange(of: vm.restTimer.isExpired) { _, expired in
            if expired && vm.isResting {
                vm.restFinished()
                syncFields(vm)
            }
        }
        .onChange(of: vm.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }

    private func header(_ vm: WorkoutRunnerViewModel) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Encerrar") { showAbandon = true }
                    .foregroundStyle(.red)
                Spacer()
                Text(vm.planName).font(.headline)
                Spacer()
                Button("Finalizar") { vm.finishEarly() }
            }
            ProgressView(value: vm.progress)
        }
        .padding()
        .confirmationDialog("Encerrar treino?", isPresented: $showAbandon, titleVisibility: .visible) {
            Button("Descartar treino", role: .destructive) {
                vm.abandon()
            }
            Button("Continuar", role: .cancel) {}
        } message: {
            Text("O que você já registrou fica salvo no histórico como treino incompleto.")
        }
    }

    private func exerciseArea(_ vm: WorkoutRunnerViewModel, step: RunnerStep) -> some View {
        VStack(spacing: 16) {
            if step.blockKind != .single {
                Text(step.blockKind.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
            }
            HStack(spacing: 8) {
                Text(step.exerciseName)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                if let exercise = exercise(for: step) {
                    ExerciseInfoButton(exercise: exercise)
                        .font(.title2)
                }
            }
            Text("Rodada \(step.roundIndex + 1) de \(step.roundCount)")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 32) {
                targetStat("Alvo", "\(step.targetReps) reps")
                targetStat("Carga", Format.weight(step.targetWeight))
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func targetStat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    /// Área de ação: steppers pré-preenchidos + botão primário grande.
    private func actionArea(_ vm: WorkoutRunnerViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RepWeightStepper(label: "Reps", value: Binding(
                    get: { Double(reps) }, set: { reps = Int($0) }), step: 1, unit: "")
                RepWeightStepper(label: "Carga (kg)", value: $weight, step: 2.5, unit: "kg")
            }
            .padding(.horizontal)

            BigActionButton(title: "Série feita", systemImage: "checkmark") {
                vm.completeSet(reps: reps, weight: weight)
                syncFields(vm)
            }
            .padding(.horizontal)

            HStack {
                Button("Pular série") { vm.skipSet(); syncFields(vm) }
                Spacer()
                Button("Pular exercício") { vm.skipExercise(); syncFields(vm) }
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Não foi possível iniciar",
                message: "Esta ficha não tem exercícios ou não está mais disponível."
            )
            Button("Fechar") { dismiss() }
        }
        .padding()
    }

    // MARK: - Suporte

    private func bootstrap() {
        guard vm == nil else { return }
        let model = WorkoutRunnerViewModel(plan: plan, existingSession: existingSession, context: context)
        model?.start()
        vm = model
        if let model { syncFields(model) }
    }

    /// Pré-preenche os campos com o alvo do passo atual (base do "1 toque").
    private func syncFields(_ vm: WorkoutRunnerViewModel) {
        guard let step = vm.currentStep else { return }
        reps = step.targetReps
        weight = step.targetWeight
    }

    private func exercise(for step: RunnerStep) -> Exercise? {
        guard let id = step.exerciseId else { return nil }
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

/// Stepper grande e tocável para reps/carga.
private struct RepWeightStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { value = max(0, value - step) } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("Diminuir \(label)")
                Text(display)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 56)
                Button { value += step } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Aumentar \(label)")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(display) \(unit)")
    }

    private var display: String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// Overlay de descanso: contagem regressiva grande, +15s e pular.
private struct RestOverlay: View {
    let remaining: TimeInterval
    let nextExercise: String
    let onSkip: () -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.96).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Descanso").font(.title2).foregroundStyle(.secondary)
                Text(Format.clock(remaining))
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                    .accessibilityLabel("Descanso: \(Int(remaining)) segundos restantes")
                if !nextExercise.isEmpty {
                    Text("Próximo: \(nextExercise)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    Button { onAdd() } label: {
                        Label("+15s", systemImage: "goforward.15")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    Button { onSkip() } label: {
                        Label("Pular descanso", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
