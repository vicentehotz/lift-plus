# RFC-0004 — Port da lógica de domínio e testes

- Status: **rascunho**
- Data: 2026-07-22
- Relacionada: RFC-0001

## Objetivo

Definir como a lógica de domínio pura do app nativo é portada de Swift para
TypeScript **preservando o comportamento** (validado pelos testes existentes), e
como fica a estratégia de testes/CI no web.

## O que porta (praticamente 1:1)

O domínio já é puro e testável no nativo, então o port é mecânico:

| Swift (nativo) | TypeScript (web) | Notas |
|---|---|---|
| `RunnerEngine` (máquina de estados) | `domain/runnerEngine.ts` | enum `State/Event/Effect` → union types discriminadas |
| `RunnerStepBuilder` | `domain/stepBuilder.ts` | achatamento da ficha em passos |
| `MetricsService` (v3) | `domain/metrics.ts` | volume, 1RM (Epley), aderência |
| `ExportService` DTOs | `domain/export.ts` | **mesmos `rawValue`** → JSON compatível |
| enums (`BlockKind`, …) | `domain/enums.ts` | strings idênticas às do Swift |

Princípios mantidos:
- **Domínio sem I/O nem UI** — funções/estruturas puras (entrada → saída).
- Efeitos colaterais (persistência, som, notificação) ficam nas bordas (stores/UI),
  não no domínio.

### Exemplo de port (assinaturas, não implementação)

```ts
type RunnerState =
  | { kind: 'idle' }
  | { kind: 'performing'; stepIndex: number }
  | { kind: 'resting'; afterStepIndex: number; nextStepIndex: number; duration: number; rest: RestKind }
  | { kind: 'finished' };

type RunnerEvent =
  | { type: 'start' }
  | { type: 'completeSet'; reps: number; weight: number }
  | { type: 'skipSet' } | { type: 'skipExercise' }
  | { type: 'restFinished' } | { type: 'skipRest' } | { type: 'finish' };

type RunnerEffect =
  | { type: 'recordSet'; stepIndex: number; reps: number; weight: number; skipped: boolean }
  | { type: 'startRest'; duration: number; rest: RestKind; nextExerciseName: string }
  | { type: 'cancelRest' } | { type: 'sessionFinished' };

// pura: (estado, evento) -> [novoEstado, efeitos]
declare function handle(state: RunnerState, steps: RunnerStep[], event: RunnerEvent): [RunnerState, RunnerEffect[]];
```

## Testes e CI

- **Vitest** para o domínio: **portar os casos** de `RunnerEngineTests`,
  `StepBuilderTests` e `ExportServiceTests` — eles são a rede de segurança que prova
  que o comportamento não regrediu na tradução.
- **Repositórios** testados com `fake-indexeddb`.
- **CI (GitHub Actions):** roda em runner **Linux** (rápido/barato, ao contrário do
  macOS do app nativo): `npm ci && npm run test && npm run build`. Deploy do build
  para **GitHub Pages** no push da branch principal.
- Meta: manter os mesmos invariantes testados no nativo (descanso só entre séries,
  bloco como unidade de descanso, skip, round-trip de export).

## Estratégia de convivência com o código nativo

- O código Swift atual é preservado como **histórico** (branch/tag), não apagado.
- O web nasce em novo diretório/estrutura (RFC-0001) para não misturar as duas
  stacks durante a transição.

## Decisão pedida

Aprovar o port do domínio para TS com paridade de testes (Vitest) e o CI web em
Linux + deploy no GitHub Pages.
