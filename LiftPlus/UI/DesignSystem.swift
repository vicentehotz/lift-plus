import SwiftUI

/// Formatação compartilhada. Peso armazenado sempre em kg (canônico);
/// a conversão de unidade viverá aqui quando entrar em Ajustes.
enum Format {
    static func weight(_ kg: Double) -> String {
        if kg == 0 { return "—" }
        let rounded = (kg * 100).rounded() / 100
        return rounded == rounded.rounded()
            ? "\(Int(rounded)) kg"
            : String(format: "%.2f kg", rounded)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Botão de ação primária na zona do polegar (G7: execução com uma mão).
struct BigActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityAddTraits(.isButton)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

extension View {
    /// Cartão com fundo semântico (adapta a Dark Mode automaticamente).
    func cardBackground() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
