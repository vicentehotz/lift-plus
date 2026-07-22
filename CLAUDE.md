# CLAUDE.md — Regras permanentes do projeto Lift+

App nativo iOS (Swift/SwiftUI/SwiftData) de controle de treino de academia,
**offline-first**. Este arquivo define as regras que valem para **todo** trabalho
neste repositório. Leia antes de qualquer alteração.

## Contexto técnico

- **Stack:** Swift 5.10+, SwiftUI, SwiftData, Swift Charts, iOS 17+.
- **Arquitetura:** MVVM — Views SwiftUI → ViewModels `@Observable` → serviços de
  domínio (puros/testáveis) → SwiftData. Views nunca acessam SwiftData direto.
- **Persistência:** store local SwiftData é a fonte da verdade; o app é 100%
  funcional offline. O schema é compatível com CloudKit (atributos com default,
  sem `@Attribute(.unique)`, relacionamentos com inverso, `orderIndex` explícito)
  para o sync da v3 sem migração destrutiva.
- **Projeto Xcode:** o `.xcodeproj` **não é versionado** — é gerado do
  `project.yml` via XcodeGen (`xcodegen generate`).
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) roda build + testes em
  runner macOS a cada push. Todo push deve manter o CI verde.

## Regras permanentes (obrigatórias)

### 1. Toda feature nova é registrada em `FEATURES.md`
Nenhuma feature entra no código sem uma entrada correspondente em `FEATURES.md`,
criada **antes ou junto** da implementação (nunca depois, como pensamento tardio).

### 2. `FEATURES.md` é incremental — nunca sobrescrito
Cada feature é uma **entrada nova** no arquivo. Não se edita nem se apaga entradas
anteriores para "atualizar": mudanças de escopo viram uma nova entrada que
referencia a anterior. O arquivo é um histórico append-only.

### 3. Todo plano gerado vira uma spec em `/specs`
Qualquer plano de implementação produzido (por um humano ou por um agente) é salvo
como arquivo de especificação em `specs/`, no formato:

```
specs/YYYY-MM-DD-nome-da-feature.md
```

Essas specs são o histórico de decisões e a **referência do code review**: a
implementação de uma feature é validada contra a sua spec. Uma feature em
`FEATURES.md` deve apontar para a spec que a originou.

## Fluxo de trabalho de uma feature

1. **Planejar** → salvar o plano em `specs/YYYY-MM-DD-nome-da-feature.md`.
2. **Registrar** → adicionar a entrada em `FEATURES.md` (com link para a spec).
3. **Implementar** → seguir MVVM, Swift moderno, testabilidade, acessibilidade e
   as Human Interface Guidelines da Apple.
4. **Testar** → cobrir a lógica de domínio com testes; manter o CI verde.
5. **Revisar** → validar a implementação contra a spec correspondente.

## Convenções de código

- Nomes e comentários acompanham o estilo do código ao redor (PT-BR nos
  comentários de domínio já existentes).
- Lógica de domínio (ex.: `RunnerEngine`, `MetricsService`) é **pura** e testável,
  sem I/O nem dependência de UI.
- Ordenação sempre por campo `orderIndex` explícito (restrição CloudKit).
- Peso armazenado sempre em kg (canônico); conversão só na apresentação.
- Acessibilidade não é opcional: Dark Mode (cores semânticas), Dynamic Type e
  VoiceOver em toda tela nova.

## Git

- Desenvolver na branch designada; manter o CI verde antes de considerar pronto.
- Não criar PRs nem branches novos sem pedido explícito.
