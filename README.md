# Lift+

App nativo iOS de controle de treino de academia, **offline-first**. Esta é a
implementação da **v1** (goals G1–G7 do [plano de desenvolvimento](docs/PLANO-DE-DESENVOLVIMENTO.md)).

## Stack

- Swift 5.10 · SwiftUI · SwiftData · iOS 17+
- Arquitetura MVVM (Views → ViewModels `@Observable` → serviços de domínio → SwiftData)
- 100% offline: o store local SwiftData é a única fonte da verdade
- Schema já desenhado para CloudKit sem migração destrutiva (sync chega na v3)

## O que a v1 entrega

| Goal | Descrição | Onde |
|------|-----------|------|
| G1 | Fichas com exercícios (séries, reps, carga, descanso, notas) | `Features/Plans`, `Features/PlanEditor` |
| G2 | Blocos compostos (bi-set, tri-set, circuito) como unidade de execução/descanso | `WorkoutBlock`, `RunnerStepBuilder` |
| G3 | Alocação de fichas a dias da semana + agenda | `Features/Schedule` |
| G4 | Execução com timer de descanso automático e avanço ao próximo item | `Features/Runner`, `RunnerEngine`, `RestTimerService` |
| G5 | Detalhe do exercício (execução, músculos, erros comuns) via sheet | `Features/ExerciseCatalog/ExerciseDetailSheet` |
| G6 | Persistência local, funcional em modo avião | `App/PersistenceController` |
| G7 | Execução com uma mão, 1 toque por série no caminho feliz | `Features/Runner/WorkoutRunnerView` |

Catálogo de exercícios pré-carregado do bundle: `LiftPlus/Resources/seed_exercises.json`.

## Como gerar o projeto e rodar

O `.xcodeproj` não é versionado; é gerado a partir de `project.yml` com
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open LiftPlus.xcodeproj
```

Requer Xcode 15+ (SDK iOS 17). Rode no simulador de iPhone ou em dispositivo.

## Testes

Os testes cobrem a máquina de estados da execução (`RunnerEngine`) e o
achatamento da ficha em passos (`RunnerStepBuilder`) — o núcleo mais crítico da v1:

```bash
xcodebuild test -scheme LiftPlus -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Estrutura

```
LiftPlus/
├─ App/            # entrada, container SwiftData, navegação raiz
├─ Domain/
│  ├─ Models/      # @Model: plano (ficha) e sessão (histórico)
│  ├─ Enums/       # BlockKind, MuscleGroup, RestKind, …
│  └─ Services/    # RunnerEngine, RestTimerService, SeedService
├─ Features/       # 1 pasta por tela (View + ViewModel)
├─ UI/             # design system e dados de preview
└─ Resources/      # seed_exercises.json
LiftPlusTests/     # testes de unidade
```

Acessibilidade: Dark Mode (cores semânticas), Dynamic Type e VoiceOver
considerados nas telas. Peso armazenado sempre em kg (canônico).
