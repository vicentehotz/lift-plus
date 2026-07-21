import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Documento genérico para o `.fileExporter` (JSON ou CSV).
struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var exportDoc = DataDocument(data: Data())
    @State private var exportType: UTType = .json
    @State private var exportName = "liftplus-backup"
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alert: AlertState?

    var body: some View {
        NavigationStack {
            List {
                Section("Backup e sincronização") {
                    Button {
                        prepareExport(json: true)
                    } label: {
                        Label("Exportar backup (JSON)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        prepareExport(json: false)
                    } label: {
                        Label("Exportar histórico (CSV)", systemImage: "tablecells")
                    }
                    Button {
                        isImporting = true
                    } label: {
                        Label("Importar backup (JSON)", systemImage: "square.and.arrow.down")
                    }
                    LabeledContent("Sincronizar com iCloud", value: "Em breve (v3)")
                        .foregroundStyle(.secondary)
                }

                Section("Sobre") {
                    LabeledContent("Versão", value: "1.0")
                    LabeledContent("Modo", value: "100% offline")
                }

                Section {
                    Text("O Lift+ funciona totalmente offline. Exportar gera um arquivo local que você pode guardar onde quiser — um backup manual, independente de qualquer nuvem.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .fileExporter(isPresented: $isExporting, document: exportDoc,
                          contentType: exportType, defaultFilename: exportName) { result in
                if case .failure(let error) = result {
                    alert = AlertState(title: "Falha ao exportar", message: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert(item: $alert) { state in
                Alert(title: Text(state.title), message: Text(state.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Ações

    private func prepareExport(json: Bool) {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        let stamp = df.string(from: .now)
        if json {
            guard let data = try? ExportService.exportJSON(context: context) else {
                alert = AlertState(title: "Falha ao exportar", message: "Não foi possível gerar o backup.")
                return
            }
            exportDoc = DataDocument(data: data)
            exportType = .json
            exportName = "liftplus-backup-\(stamp)"
        } else {
            exportDoc = DataDocument(data: ExportService.exportSessionsCSV(context: context))
            exportType = .commaSeparatedText
            exportName = "liftplus-historico-\(stamp)"
        }
        isExporting = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let summary = try ExportService.importBackup(data, into: context)
                ExportService.rebuildDerivedData(context: context)
                alert = AlertState(
                    title: "Importado",
                    message: "Adicionados: \(summary.plans) ficha(s), \(summary.sessions) sessão(ões), \(summary.exercises) exercício(s). Itens já existentes foram mantidos."
                )
            } catch {
                alert = AlertState(title: "Falha ao importar", message: "Arquivo inválido ou incompatível.")
            }
        case .failure(let error):
            alert = AlertState(title: "Falha ao importar", message: error.localizedDescription)
        }
    }
}

private struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
