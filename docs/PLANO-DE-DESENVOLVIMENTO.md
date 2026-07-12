# Lift+ — Plano de Desenvolvimento

App nativo iOS de controle de treino de academia, **offline-first**.

**Versionamento de escopo:**
- **v1:** fichas, blocos, agenda, execução com timer, catálogo com detalhes (G1–G7)
- **v2:** histórico detalhado de sessões (G8) + export/import local JSON/CSV (G13)
- **v3:** métricas e progresso (G9–G11) + sync iCloud/CloudKit (G12)

- **Stack:** Swift 5.10+, SwiftUI, SwiftData, Swift Charts, iOS 17+
- **Arquitetura:** MVVM (Views SwiftUI → ViewModels `@Observable` → camada de domínio/repositórios → SwiftData)
- **Rede:** exclusivamente CloudKit (iCloud privado, v3). Nenhum backend próprio, nenhuma API de terceiros, nenhuma telemetria.

---

## 1. Modelo de dados

### 1.1 Princípio central: planejado × realizado

O modelo separa rigidamente duas árvores:

- **Planejado (Plano):** `WorkoutPlan → WorkoutBlock → PlannedExercise → PlannedSet` — o que o usuário *pretende* fazer. Editável a qualquer momento.
- **Realizado (Histórico):** `WorkoutSession → SessionItem → PerformedSet` — o que *de fato* aconteceu em uma execução. Imutável após o fim da sessão (exceto correções manuais explícitas).

A sessão **copia por valor** os dados planejados no momento do início (snapshot desnormalizado: nome do exercício, alvos de séries/reps/carga). Assim, editar ou apagar uma ficha nunca corrompe o histórico — requisito essencial para o histórico da v2 (G8) e as métricas da v3 (G9–G11).

`Exercise` é a entidade de catálogo (seed do bundle + exercícios do usuário), referenciada por ambas as árvores.

### 1.2 Entidades

| Entidade | Campos principais | Observações |
|---|---|---|
| **Exercise** | `id: UUID`, `name`, `muscleGroups: [MuscleGroup]` (primário + secundários), `equipment`, `instructions` (execução passo a passo), `commonMistakes`, `mediaAssetName?`, `isCustom: Bool`, `seedSlug: String?` | Catálogo. Seed identificado por `seedSlug` estável (permite atualizar seed sem duplicar). Alimenta o tooltip/sheet do G5. |
| **WorkoutPlan** (Ficha) | `id`, `name`, `notes?`, `colorTag?`, `isArchived`, `createdAt`, `updatedAt`, `orderIndex` | Arquivar em vez de deletar quando houver histórico vinculado. |
| **WorkoutBlock** | `id`, `orderIndex`, `kind: BlockKind` (`single`, `biSet`, `triSet`, `circuit`), `rounds: Int` (nº de passagens/séries do bloco), `restBetweenRounds: TimeInterval`, `restAfterBlock: TimeInterval`, `notes?` | **Todo exercício vive dentro de um bloco**, mesmo sozinho (`single`, 1 exercício). Unifica o modelo de execução: o descanso pertence ao bloco (G2), não ao exercício. |
| **PlannedExercise** | `id`, `orderIndex`, ref → `Exercise`, `notes?` | Posição do exercício dentro do bloco. |
| **PlannedSet** | `id`, `orderIndex`, `targetReps: Int?`, `targetRepsRange: (min,max)?`, `targetWeight: Double?`, `isWarmup: Bool` | Uma linha por série permite pirâmide (12/10/8 com cargas diferentes). Para `single`, `rounds` do bloco = nº de `PlannedSet`. |
| **ScheduleEntry** | `id`, `weekday: Int (1–7)`, ref → `WorkoutPlan` | Agenda semanal (G3). Vários planos por dia permitidos. |
| **WorkoutSession** | `id`, `startedAt`, `endedAt?`, `status` (`inProgress`, `completed`, `abandoned`), `planId: UUID?` (ref fraca), `planNameSnapshot: String`, `notes?`, `totalRestActual: TimeInterval` | `planNameSnapshot` preserva histórico se a ficha for renomeada/apagada. Sessão `inProgress` persistida permite retomar após kill do app. |
| **SessionItem** | `id`, `orderIndex`, `blockKindSnapshot`, `exerciseId: UUID?` (ref fraca ao catálogo), `exerciseNameSnapshot`, `muscleGroupsSnapshot`, `skipped: Bool` | Um por exercício executado, agrupável por bloco via `blockIndexSnapshot`. |
| **PerformedSet** | `id`, `orderIndex`, `reps: Int`, `weight: Double`, `targetRepsSnapshot?`, `targetWeightSnapshot?`, `restPlanned: TimeInterval?`, `restActual: TimeInterval?`, `completedAt: Date`, `skipped: Bool` | Grava alvo *e* realizado → aderência e "vs. sessão anterior" (G10, G11). |
| **PersonalRecord** (v3, materializada) | `id`, `exerciseId`, `kind` (`maxWeight`, `maxVolumeSet`, `estimated1RM`), `value`, `date`, `sessionId` | Cache derivado do histórico; recalculável do zero. |
| **AppSettings** | singleton local: `iCloudSyncEnabled`, `defaultRest`, `weightUnit`, `hapticsEnabled`… | Fora do store sincronizado (UserDefaults ou store local separado). |

### 1.3 Diagrama textual

```text
Exercise (catálogo: seed do bundle + custom)
   ▲ ref forte                ▲ ref fraca por UUID + snapshot de nome
   │                          │
WorkoutPlan 1─* WorkoutBlock 1─* PlannedExercise 1─* PlannedSet     [PLANEJADO]
   ▲
   │ ref fraca (planId) + planNameSnapshot
ScheduleEntry (*─1 WorkoutPlan)   [AGENDA]

WorkoutSession 1─* SessionItem 1─* PerformedSet                     [REALIZADO]
WorkoutSession/PerformedSet ──derivam──▶ PersonalRecord, métricas   [v3]
```

### 1.4 Restrições que o CloudKit impõe ao schema (desenhar já na v1)

Para `NSPersistentCloudKitContainer` / SwiftData + CloudKit funcionar sem migração destrutiva na v3:

1. **Todos os atributos opcionais ou com valor default** — CloudKit não suporta atributos obrigatórios sem default.
2. **Sem `@Attribute(.unique)` / unique constraints** — CloudKit não suporta unicidade; deduplicação (ex.: seed de exercícios) deve ser feita em código, por `seedSlug`.
3. **Relacionamentos sempre com inverso definido** e sempre opcionais.
4. **Sem delete rule `Deny`**; usar `cascade`/`nullify`.
5. **Sem ordered relationships** — por isso todo ordenamento usa campo explícito `orderIndex`.
6. **Referências entre árvores plano↔histórico por UUID "fraco" + snapshot**, não por relacionamento — evita conflitos de sync entre objetos de ciclos de vida diferentes e mantém o histórico autossuficiente.
7. Assets do seed (imagens/instruções) ficam **no bundle, fora do store** — não sincronizam, não pesam no iCloud.
8. Evoluções de schema apenas **aditivas** (campos novos opcionais); nunca renomear/retipar campo publicado.

---

## 2. Mapa de telas e navegação

`TabView` com 4 abas + fluxos modais:

```text
Tab 1 — Hoje (home)
 ├─ Treino do dia (via ScheduleEntry) + botão grande "Iniciar treino"
 ├─ Sessão em andamento? → banner "Retomar treino"
 └─ → WorkoutRunnerView (fullScreenCover)

Tab 2 — Fichas
 ├─ Lista de WorkoutPlans (reordenável, arquivar)
 ├─ → PlanEditorView
 │    ├─ lista de blocos (drag & drop, agrupar em bi-set/tri-set/circuito)
 │    ├─ → BlockEditorView (tipo, rounds, descansos)
 │    ├─ → ExercisePickerView (busca no catálogo, filtro por grupo muscular,
 │    │     criar exercício custom)
 │    └─ → PlannedSetsEditor (séries/reps/carga por linha)
 └─ (ⓘ em qualquer exercício) → ExerciseDetailSheet  [G5: execução, músculos,
       erros comuns — sheet com detents .medium/.large]

Tab 3 — Agenda
 ├─ Grade semanal Seg–Dom com fichas alocadas
 └─ Atribuir/remover ficha por dia (menu de contexto ou sheet)

Tab 4 — Histórico (v1 simples; v2 detalhado; vira "Progresso" na v3)
 ├─ Histórico: lista de sessões → SessionDetailView (séries realizadas vs. alvo)  [v2]
 ├─ Gráficos (Swift Charts): volume, 1RM estimado, frequência, streak  [v3]
 ├─ PRs por exercício  [v3]
 └─ Ajustes ⚙️
      ├─ Sync iCloud (toggle + estado: última sync, erro, conta indisponível)  [v3]
      ├─ Exportar/Importar JSON/CSV (share sheet / file importer)  [G13, v2]
      └─ unidade de peso, descanso padrão, notificações, sobre

Modal global — WorkoutRunnerView (execução, G4/G7)
 ├─ item atual (exercício ou bloco) em destaque, série corrente
 ├─ botão único gigante na metade inferior da tela: "✓ Série feita"
 │   → dispara timer de descanso automaticamente
 ├─ overlay de descanso: contagem regressiva, +15s / pular
 ├─ stepper rápido de reps/carga (pré-preenchido com o alvo; 0 toques se
 │   o realizado == planejado)  [G7: 1 toque por série no caminho feliz]
 ├─ swipe: pular série / pular exercício
 └─ Finalizar → SessionSummaryView → grava histórico
```

**Acessibilidade transversal:** Dynamic Type em todas as telas (layouts com `ViewThatFits`/scroll), VoiceOver com labels e `accessibilityValue` no timer, Dark Mode via cores semânticas, alvos de toque ≥ 44 pt (o botão principal do runner ocupa a zona do polegar — G7).

---

## 3. Máquina de estados da execução (WorkoutRunner)

Implementada como enum de estado + reducer no `WorkoutRunnerViewModel`; a sessão `inProgress` é persistida a cada transição (crash-safe).

```swift
enum RunnerState {
    case idle                                   // pré-início
    case performingSet(item: ItemCursor, set: Int)
    case resting(kind: RestKind, remaining: TimeInterval)
    case betweenItems(next: ItemCursor)         // transição instantânea
    case paused(previous: RunnerState)
    case finished(summary: SessionSummary)
}

enum RestKind { case betweenSets, betweenRounds, afterBlock }

enum RunnerEvent {
    case start, completeSet(reps: Int, weight: Double)
    case skipSet, skipItem, restFinished, addRest(TimeInterval)
    case skipRest, pause, resume, finish, abandon
}
```

**Transições principais:**

```text
idle ──start──▶ performingSet(primeiro item, série 1)
                 │ cria WorkoutSession(status: .inProgress)

performingSet ──completeSet──▶ grava PerformedSet(realizado + snapshot do alvo)
   ├─ há próxima posição DENTRO da rodada do bloco?
   │    • single: próxima série → resting(.betweenSets)
   │    • biSet/triSet/circuit: próximo exercício da rodada SEM descanso
   │      (bloco é a unidade de descanso — G2)
   ├─ fim da rodada e rounds restantes → resting(.betweenRounds)
   ├─ fim do bloco e há próximo bloco → resting(.afterBlock)
   └─ fim do último bloco → finished

resting: timer decrementa; registra restActual ao sair
   ├─ restFinished (auto) ─▶ betweenItems ─▶ performingSet(próximo)  [avanço
   │     automático — G4; haptic + som]
   ├─ skipRest ─▶ idem, imediato
   └─ addRest(+15s) ─▶ permanece em resting

skipSet/skipItem: grava PerformedSet/SessionItem com skipped = true (G8) e
   segue as mesmas regras de avanço

finished ──▶ SessionSummary; endedAt = now; status = .completed;
   recalcula PRs (v3); volta ao app

abandon ──▶ status = .abandoned (histórico mantém o que foi feito)
```

**Timer em background (constraint):** ao entrar em `resting`, o VM grava `restEndDate = now + rest` e agenda `UNNotificationRequest` para essa data ("Descanso acabou — próximo: Supino"). A UI deriva o restante de `restEndDate − now` (nunca conta ticks acumulados), então suspensão do app não desvia o relógio. Ao voltar ao foreground, o estado é recomputado a partir de `restEndDate`; se já expirou, aplica `restFinished`. Notificação é cancelada em `skipRest`/`pause`. Não é necessário Background Task API — apenas data absoluta + notificação local.

---

## 4. Métricas da v3

Todas derivadas exclusivamente de `WorkoutSession`/`SessionItem`/`PerformedSet` (séries com `skipped == true` e `isWarmup == true` são excluídas dos cálculos de volume/PR; puladas contam para aderência).

| Métrica | Fórmula | Granularidade | Derivação |
|---|---|---|---|
| Volume da sessão | `Σ (reps × weight)` sobre PerformedSets válidos | por sessão | **Materializada** no fim da sessão (campo `totalVolume` em `WorkoutSession`) — barata e evita reagregação em toda listagem |
| Volume por grupo muscular | volume da série atribuído ao(s) grupo(s) via `muscleGroupsSnapshot` (primário 100%; opcional: secundários 50% — decisão em aberto §8) | sessão / semana / mês | Sob demanda, agregando sessões do período (fetch + reduce); cacheável em memória no VM |
| Carga máxima por exercício | `max(weight)` com reps ≥ 1 | por exercício, série temporal (1 ponto por sessão) | Sob demanda para o gráfico; máximo histórico materializado em `PersonalRecord` |
| 1RM estimado | **Epley:** `weight × (1 + reps/30)`; para reps > 12 o valor é exibido como aproximação | por série → melhor da sessão → série temporal | Melhor 1RM da sessão calculado no fim da sessão; recorde materializado em `PersonalRecord` |
| Treinos por semana/mês | contagem de sessões `completed` agrupadas por semana ISO / mês | semanal, mensal | Sob demanda (Swift Charts consome direto) |
| Streak atual / maior streak | semanas consecutivas com ≥ 1 sessão (ou com aderência ≥ X% — decisão em aberto §8) | semanas | Sob demanda; O(nº de semanas), trivial |
| Aderência ao plano | `sessões realizadas no dia agendado ÷ ScheduleEntries da semana`; e por sessão: `séries feitas ÷ séries planejadas` | semanal | Sob demanda |
| Tempo médio de treino | `média(endedAt − startedAt)` | semana/mês | Sob demanda |
| Descanso real vs. planejado | `Σ restActual` vs. `Σ restPlanned` por sessão; razão média por período | sessão / período | `restActual` já é capturado pelo runner; agregação sob demanda |
| PR (destaque automático) | ao fim de cada sessão, compara melhores valores da sessão com `PersonalRecord`; se superou → atualiza + badge/celebração | evento | **Materializada** (tabela `PersonalRecord`), recalculável do zero a partir do histórico (idempotente — importante pós-sync/import) |
| Comparação com sessão anterior | para cada exercício da sessão, busca a última sessão contendo o mesmo `exerciseId` e diffa série a série (carga, reps, volume) | por exercício, em tempo real no runner | Sob demanda no início da sessão (1 fetch por exercício, pré-carregado) |

**Regra geral:** materializar apenas o que é (a) caro de recomputar em listas (volume/sessão) ou (b) precisa de detecção de evento (PRs). Todo o resto é calculado sob demanda — o volume de dados de um usuário de academia (centenas de sessões) é pequeno para SwiftData + agregação em memória. Tudo que é materializado deve ser **recalculável do zero** (função `rebuildDerivedData()`), executada após import (G13, v2) ou merge de sync (G12, v3).

Embora as métricas só sejam exibidas na v3, os dados brutos de que dependem (`restActual`, snapshots de alvo, `skipped`, `muscleGroupsSnapshot`) são capturados desde a v1/v2 — o histórico acumulado fica retroativamente disponível para os gráficos quando a v3 chegar.

---

## 5. Estratégia de sync (v3 — iCloud/CloudKit)

**Mecanismo:** SwiftData com `cloudKitDatabase: .private` (equivalente a `NSPersistentCloudKitContainer`), banco privado do usuário, zona única. Nenhum servidor próprio.

| Aspecto | Decisão |
|---|---|
| **Quando dispara** | Automático pelo framework: push após save local (coalescido), fetch em launch/foreground e via push silencioso do CloudKit. Nunca manual, nunca bloqueante — toda escrita vai **primeiro ao store local** e a UI conclui imediatamente. |
| **O que sincroniza** | `Exercise` (custom), `WorkoutPlan/Block/PlannedExercise/PlannedSet`, `ScheduleEntry`, `WorkoutSession/SessionItem/PerformedSet`, `PersonalRecord`. **Não sincroniza:** `AppSettings` (local), assets do seed (bundle), sessão `inProgress` (só sobe quando `completed`/`abandoned` — evita conflito de sessão ao vivo entre devices). |
| **Opt-in/out** | Toggle em Ajustes, default **off**. Implementação: dois containers/configurações (local-only e CloudKit) sobre o mesmo schema; desligar mantém tudo local. App 100% funcional sem conta iCloud. |
| **Conflitos — regra geral** | Last-writer-wins por campo (comportamento CloudKit), aceitável para fichas: a edição mais recente vence; `updatedAt` exibido ao usuário. |
| **Conflitos — mesma ficha editada em 2 devices** | LWW por campo pode mesclar de forma estranha mas nunca perde a ficha; blocos/exercícios adicionados em devices diferentes coexistem (são registros novos). Deleção × edição: deleção vence (cascade) — mitigado pelo padrão "arquivar em vez de apagar". |
| **Conflitos — sessões/histórico** | Por design, quase impossíveis: sessões são imutáveis, criadas em um único device e com UUID próprio. Duas sessões simultâneas em dois devices = dois registros, ambos preservados. |
| **Deduplicação** | Sem unique constraints (restrição CloudKit) → dedupe em código no evento de import do sync: exercícios seed por `seedSlug`, custom por (nome normalizado + criação próxima). |
| **Estados de erro e comunicação** | Painel "Sync" em Ajustes com estado observado via `NSPersistentCloudKitContainer.eventChangedNotification` / eventos equivalentes: ✅ "Sincronizado às HH:mm" · ⏳ "Sincronizando…" · ⚠️ "iCloud sem espaço" (link p/ Ajustes do sistema) · ⚠️ "Sem conta iCloud" (toggle desabilitado com explicação) · 📴 "Offline — sincroniza quando houver rede" (informativo, nunca bloqueia). Erros **nunca** geram alertas modais durante o uso; no máximo um badge discreto em Ajustes. |
| **Pós-merge** | Ao receber import remoto: dedupe + `rebuildDerivedData()` (PRs/volumes) para consistência. |

---

## 6. Arquitetura de pastas e módulos

```text
LiftPlus/
├─ App/                     # LiftPlusApp, RootTabView, DI (ModelContainer factory
│                           #   local vs. CloudKit), AppRouter
├─ Domain/
│  ├─ Models/               # @Model: Exercise, WorkoutPlan, …, PerformedSet
│  ├─ Enums/                # BlockKind, MuscleGroup, RestKind, SessionStatus
│  └─ Services/
│     ├─ SeedService        # importa/atualiza catálogo do bundle (dedupe por slug)
│     ├─ RunnerEngine       # máquina de estados pura (§3), testável sem UI
│     ├─ RestTimerService   # restEndDate, UNUserNotificationCenter
│     ├─ MetricsService     # fórmulas da §4 (funções puras sobre o histórico)
│     ├─ PRService          # detecção/materialização de recordes
│     ├─ ExportService      # JSON/CSV (Codable DTOs versionados)  [v2]
│     └─ SyncMonitor        # estados de sync p/ Ajustes            [v3]
├─ Features/                # 1 pasta por feature: View(s) + ViewModel
│  ├─ Today/  ├─ Plans/  ├─ PlanEditor/  ├─ ExerciseCatalog/
│  ├─ Schedule/  ├─ Runner/  ├─ History/  ├─ Progress/ (v3)  └─ Settings/
├─ UI/                      # DS: cores semânticas, tipografia, RestRing,
│                           #   SetRow, BigActionButton, EmptyState
├─ Resources/               # seed_exercises.json, assets, Localizable
└─ Tests/
   ├─ RunnerEngineTests     # transições da máquina de estados (prioridade máxima)
   ├─ MetricsTests          # fórmulas com fixtures de histórico
   └─ SeedAndMigrationTests # dedupe, schema aditivo, import/export round-trip
```

Regras: Views não tocam SwiftData diretamente (sempre via ViewModel/serviço); `RunnerEngine` e `MetricsService` são **puros** (entrada → saída, sem I/O) para teste unitário barato; DI por inicializador (sem singletons além do `ModelContainer`).

---

## 7. Roadmap em fases

| Fase | Escopo | Goals |
|---|---|---|
| **F0 — Fundação** (1–2 sem) | Projeto, CI local, schema SwiftData completo (já CloudKit-compliant, §1.4), seed de exercícios, design system base, esqueleto de navegação | G6 (base) |
| **F1 — MVP** (2–3 sem) | CRUD de fichas com blocos (single/bi/tri/circuito), catálogo com busca + ExerciseDetailSheet, agenda semanal, **runner completo** com timer background + notificação + avanço automático, gravação de sessão no histórico (dados já no formato G8), lista de histórico simples | G1–G7, G8 (captura) |
| **F1.5 — Polimento v1** (1–2 sem) | VoiceOver/Dynamic Type auditados, haptics, retomada de sessão pós-kill, empty states, edição de sessão em andamento (ajustar carga/reps), arquivamento de fichas — **release v1 na App Store** | G7 refinado |
| **F2 — Histórico + Backup (v2)** (1–2 sem) | Histórico detalhado: SessionDetailView (realizado vs. alvo, séries puladas, duração, descanso real), export/import JSON/CSV via share sheet / file importer — **release v2** | G8 (exibição), G13 |
| **F3 — Progresso (v3)** (2–3 sem) | Aba Progresso: Swift Charts (volume, 1RM, frequência, streak, aderência, descanso real×planejado), PRs com celebração, comparação com sessão anterior no runner | G9, G10, G11 |
| **F4 — Sync (v3)** (2 sem + beta) | Toggle iCloud, container CloudKit, SyncMonitor/UI de estados, dedupe pós-merge, `rebuildDerivedData`, testes multi-device via TestFlight — **release v3** | G12 |

Sync (F4) por último deliberadamente: histórico (F2) e métricas (F3) entregam valor imediato e validam o modelo de dados com uso real antes de congelar o schema no CloudKit (schema publicado em produção é praticamente imutável).

---

## 8. Riscos técnicos e decisões em aberto

**Riscos**

1. **SwiftData + CloudKit em iOS 17** é a parte mais imatura da stack (bugs conhecidos de sync, sem controle fino de merge). *Mitigação:* schema compliant desde F0; sync isolado atrás do toggle; plano B documentado de migrar a camada de persistência para Core Data + `NSPersistentCloudKitContainer` mantendo os mesmos modelos de domínio — por isso Views nunca tocam SwiftData diretamente.
2. **Confiabilidade do timer em background:** notificação local pode ser silenciada (Foco/permissão negada). *Mitigação:* relógio por data absoluta (§3) garante correção ao reabrir; onboarding pede permissão de notificação com explicação; fallback visual claro.
3. **Schema CloudKit é imutável em produção:** erro de modelagem custa caro. *Mitigação:* campos de reserva não; disciplina de mudanças apenas aditivas; validar modelo com dados reais durante F1–F3 antes do deploy CloudKit.
4. **Deduplicação sem unique constraints** (seed em múltiplos devices). *Mitigação:* `seedSlug` + dedupe idempotente no import.
5. **Curadoria do seed de exercícios** (conteúdo de instruções/erros comuns, sem API de terceiros): esforço editorial, não técnico. *Mitigação:* começar com ~80–120 exercícios essenciais; estrutura JSON versionada para crescer.

**Decisões em aberto**

| # | Questão | Recomendação |
|---|---|---|
| D1 | Volume de grupos musculares secundários: 0%, 50% ou 100%? | 50% para secundários (padrão comum), configurável depois |
| D2 | Streak: qualquer sessão na semana ou aderência mínima ao plano? | ≥ 1 sessão/semana (simples e motivador); aderência é métrica separada |
| D3 | Fórmula de 1RM (Epley vs. Brzycki) e teto de reps | Epley, marcar como estimativa acima de 12 reps |
| D4 | Unidade: kg/lb com conversão ou armazenar sempre kg? | Armazenar kg canônico; converter na UI |
| D5 | Live Activity / Dynamic Island para o timer de descanso | Fora do escopo v1; candidato para v2/v3 (mesmo `restEndDate` alimenta a Activity) |
| D6 | Apple Watch companion | Fora de escopo; modelo de dados já comporta (sessões por device) |
| D7 | Mídia dos exercícios: ilustrações estáticas vs. vídeo no bundle | Ilustrações/fotos estáticas (tamanho de bundle e custo de produção) |
