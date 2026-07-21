import SwiftUI

/// Ajustes da v1. Sync iCloud e export/import aparecem como itens desativados
/// para deixar clara a evolução planejada (v2/v3), sem prometer o que a v1
/// ainda não entrega.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Backup e sincronização") {
                    LabeledContent("Sincronizar com iCloud", value: "Em breve (v3)")
                        .foregroundStyle(.secondary)
                    LabeledContent("Exportar histórico", value: "Em breve (v2)")
                        .foregroundStyle(.secondary)
                }

                Section("Sobre") {
                    LabeledContent("Versão", value: "1.0")
                    LabeledContent("Modo", value: "100% offline")
                }

                Section {
                    Text("O Lift+ funciona totalmente offline. Todos os seus treinos ficam salvos apenas neste dispositivo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

#Preview {
    SettingsView()
}
