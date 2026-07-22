# Lift+

App nativo iOS de controle de treino de academia, **offline-first**. Implementação
das versões **v1** (goals G1–G7) e **v2** (G8, G13) do
[plano de desenvolvimento](docs/PLANO-DE-DESENVOLVIMENTO.md).

## Stack

- **Swift 5.10+** · **SwiftUI** · **SwiftData** · **Swift Charts** · **iOS 17+**
- **Arquitetura:** MVVM — Views SwiftUI → ViewModels `@Observable` → serviços de
  domínio (puros/testáveis) → SwiftData. Views nunca acessam SwiftData direto.
- **Offline-first:** o store local SwiftData é a única fonte da verdade; o app é
  100% funcional em modo avião.
- **CloudKit-ready:** o schema já respeita as restrições do CloudKit (atributos com
  default, sem `@Attribute(.unique)`, relacionamentos com inverso, `orderIndex`
  explícito) para o sync da v3 sem migração destrutiva.

## Requisitos

| Ferramenta | Versão | Uso |
|---|---|---|
| macOS | 14+ | necessário para compilar/rodar (Xcode só roda em macOS) |
| Xcode | 16+ | SDK iOS 17+; abre o formato de projeto gerado |
| XcodeGen | 2.45+ | gera o `.xcodeproj` a partir do `project.yml` |
| xcbeautify | opcional | formata a saída do `xcodebuild` |

O `.xcodeproj` **não é versionado** — é gerado do `project.yml`.

## Como buildar e rodar

```bash
brew install xcodegen
xcodegen generate
open LiftPlus.xcodeproj
```

No Xcode, escolha um simulador de iPhone e aperte **⌘R**. Sem um Mac local, use o
CI (validação automática) ou um Mac na nuvem + Simulador/TestFlight.

### Testes

```bash
xcodegen generate
xcodebuild test -scheme LiftPlus \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Os testes cobrem a lógica de domínio pura — máquina de estados da execução
(`RunnerEngine`), achatamento da ficha em passos (`RunnerStepBuilder`) e o
round-trip de export/import (`ExportService`).

### CI

`.github/workflows/ci.yml` roda `xcodegen generate` + `xcodebuild test` num runner
**macOS** a cada push (qualquer branch), em PRs e sob demanda. É a validação de
compilação e testes sem depender de um Mac local.

## Estrutura de pastas

```
lift-plus/
├─ CLAUDE.md                 # regras permanentes do projeto (LEIA PRIMEIRO)
├─ FEATURES.md               # registro incremental de features
├─ README.md
├─ project.yml               # definição do projeto (XcodeGen)
├─ .github/workflows/ci.yml  # CI (build + testes em macOS)
├─ docs/                     # plano de desenvolvimento (v1→v3)
├─ specs/                    # especificações por feature (YYYY-MM-DD-nome.md)
├─ .claude/
│  └─ agents/                # subagents do projeto (dev iOS, code review)
├─ LiftPlus/
│  ├─ App/                   # entrada, container SwiftData, navegação raiz
│  ├─ Domain/
│  │  ├─ Models/             # @Model: plano (ficha) e sessão (histórico)
│  │  ├─ Enums/              # BlockKind, MuscleGroup, RestKind, …
│  │  └─ Services/           # RunnerEngine, RestTimerService, SeedService, ExportService
│  ├─ Features/              # 1 pasta por tela (View + ViewModel)
│  ├─ UI/                    # design system e dados de preview
│  └─ Resources/             # seed_exercises.json
└─ LiftPlusTests/            # testes de unidade
```

## Agentes do projeto

Os subagents reutilizáveis ficam em `.claude/agents/` e são acionados via Claude
Code. Fluxo previsto (detalhes em `CLAUDE.md`):

- **Agente de desenvolvimento iOS** — implementa features seguindo MVVM, Swift
  moderno, testabilidade, acessibilidade e as guidelines da Apple. Ao trabalhar
  uma feature, salva o plano em `specs/` e registra a entrada em `FEATURES.md`.
- **Agente de code review** — valida cada feature implementada contra a sua spec
  em `specs/`, checando aderência à spec, boas práticas iOS, testes e segurança.

> Os arquivos dos agentes são criados nas fases 3 e 4 desta iniciativa de
> documentação; esta seção descreve o uso pretendido.

## Regras permanentes

Este projeto segue regras de documentação obrigatórias (ver [`CLAUDE.md`](CLAUDE.md)):

1. Toda feature nova é registrada em [`FEATURES.md`](FEATURES.md) antes ou junto da
   implementação.
2. `FEATURES.md` é incremental — entradas nunca são sobrescritas.
3. Todo plano gerado vira uma spec em [`specs/`](specs/), usada como referência do
   code review.

## Acessibilidade

Dark Mode (cores semânticas), Dynamic Type e VoiceOver são considerados em toda
tela. Peso armazenado sempre em kg (canônico); conversão só na apresentação.
