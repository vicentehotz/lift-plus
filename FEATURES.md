# FEATURES.md — Registro incremental de features do Lift+

Registro **append-only** de todas as features do projeto. Cada feature é uma
entrada nova; entradas anteriores **nunca** são sobrescritas ou apagadas. Uma
mudança de escopo vira uma nova entrada que referencia a anterior.

Regras completas em [`CLAUDE.md`](CLAUDE.md). Toda entrada deve apontar para a
spec que a originou em [`/specs`](specs/).

---

## Template de entrada

Copie o bloco abaixo para registrar uma nova feature (adicione ao final do arquivo):

```markdown
### F<N> — <Nome da feature>
- **Descrição:** <o que a feature faz e o problema que resolve, em 1–3 linhas>
- **Status:** planejada | em desenvolvimento | concluída | substituída por F<M>
- **Spec:** [specs/YYYY-MM-DD-nome-da-feature.md](specs/YYYY-MM-DD-nome-da-feature.md)
- **Data:** YYYY-MM-DD
- **Componentes principais:** <arquivos/pastas ou tipos afetados>
- **Observações:** <opcional: decisões, dependências, o que substitui>
```

Campos:
- **Nome** — identificador curto e estável da feature.
- **Descrição** — o quê e por quê, não o como.
- **Status** — estado atual; para escopo alterado, use "substituída por F<M>" e
  crie a nova entrada em vez de editar esta.
- **Spec vinculada** — caminho do arquivo em `/specs` que detalha o plano.

---

## Features

> As entradas abaixo registram o que já existe no repositório (v1 e v2). As specs
> retroativas serão vinculadas conforme forem criadas em `/specs`; o plano macro
> original está em [`docs/PLANO-DE-DESENVOLVIMENTO.md`](docs/PLANO-DE-DESENVOLVIMENTO.md).

### F1 — Fichas de treino com blocos e séries
- **Descrição:** criação/edição de fichas compostas por exercícios (nome, séries,
  reps, carga, descanso, notas), agrupados em blocos single/bi-set/tri-set/circuito.
- **Status:** concluída (v1, goals G1–G2)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md` (spec dedicada pendente de retrofit)
- **Data:** 2026-07-21
- **Componentes principais:** `Features/Plans`, `Features/PlanEditor`, `Domain/Models/PlanModels.swift`

### F2 — Agenda semanal
- **Descrição:** alocação de fichas a dias da semana e visualização em agenda.
- **Status:** concluída (v1, goal G3)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `Features/Schedule`, `Domain/Models/PlanModels.swift` (`ScheduleEntry`)

### F3 — Execução de treino com timer de descanso
- **Descrição:** máquina de estados de execução (série → descanso → próximo item),
  timer por data absoluta com notificação local, avanço automático, execução com
  uma mão (1 toque por série no caminho feliz).
- **Status:** concluída (v1, goals G4, G7)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `Features/Runner`, `Domain/Services/RunnerEngine.swift`, `Domain/Services/RestTimerService.swift`

### F4 — Catálogo de exercícios com detalhe
- **Descrição:** catálogo pré-carregado do bundle (seed), busca/filtro, criação de
  exercícios custom e sheet de detalhe (execução, músculos, erros comuns).
- **Status:** concluída (v1, goal G5)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `Features/ExerciseCatalog`, `Domain/Services/SeedService.swift`, `Resources/seed_exercises.json`

### F5 — Persistência local offline-first
- **Descrição:** store SwiftData como fonte da verdade, 100% funcional em modo
  avião; schema compatível com CloudKit para a v3.
- **Status:** concluída (v1, goal G6)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `App/PersistenceController.swift`, `Domain/Models`

### F6 — Histórico detalhado de sessões
- **Descrição:** lista de sessões e detalhe com realizado vs. planejado (séries
  concluídas, puladas, carga/reps efetivas, duração, descanso real).
- **Status:** concluída (v2, goal G8)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `Features/History`, `Domain/Models/SessionModels.swift`

### F7 — Export/import local (backup manual)
- **Descrição:** exportar backup completo em JSON e histórico em CSV; importar JSON
  de forma idempotente (merge por id, sem duplicar). Independente do iCloud.
- **Status:** concluída (v2, goal G13)
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `Domain/Services/ExportService.swift`, `Features/Settings`

### F8 — Infraestrutura de CI (GitHub Actions)
- **Descrição:** build + testes automáticos em runner macOS a cada push, gerando o
  projeto com XcodeGen. Valida compilação e testes sem Mac local.
- **Status:** concluída
- **Spec:** `docs/PLANO-DE-DESENVOLVIMENTO.md`
- **Data:** 2026-07-21
- **Componentes principais:** `.github/workflows/ci.yml`, `project.yml`

### F9 — Migração para web app (PWA)
- **Descrição:** mudança de direção estruturante — reimplementar o Lift+ como PWA
  (TypeScript/React/Vite/Dexie), offline-first e instalável no iPhone a partir do
  Windows, sem Mac e sem Apple Developer Program. Rewrite; o nativo iOS (F1–F8) é
  preservado como histórico. Features concretas por fase virão como novas entradas.
- **Status:** planejada (RFCs em revisão)
- **Spec:** RFCs [`rfcs/RFC-0001`](rfcs/RFC-0001-web-migration-overview.md),
  0002, 0003, 0004 (specs por feature serão criadas em `/specs` por fase)
- **Data:** 2026-07-22
- **Componentes principais:** `rfcs/`, `.claude/agents/web-developer.md`
- **Observações:** não substitui F1–F8 no histórico; redireciona o desenvolvimento
  futuro. O agente `ios-developer` fica marcado como substituído por `web-developer`.
