# RFC-0001 — Migração para web app (PWA): visão geral e arquitetura

- Status: **aceita** (2026-07-22) — P0 iniciada
- Data: 2026-07-22
- Substitui a direção nativa iOS descrita em `docs/PLANO-DE-DESENVOLVIMENTO.md`
  (que permanece como histórico).

## Contexto e motivação

O produto foi construído como app nativo iOS (Swift/SwiftUI/SwiftData), com v1 e v2
concluídas e verdes no CI. Porém a restrição do usuário mudou o problema:

- **Sem Mac**, **sem disposição para pagar US$99/ano** (Apple Developer Program),
  desenvolvendo a partir de um **PC Windows**, com a meta de **usar o app no próprio
  iPhone**.

Compilar e assinar um app iOS nativo exige macOS/Xcode em algum ponto — não há como
contornar do Windows puro. Um **PWA (Progressive Web App)** é o único caminho que
atende todas as restrições: desenvolve-se no Windows, hospeda-se de graça, e o
usuário instala via Safari ("Adicionar à Tela de Início") sem Mac, sem US$99 e sem
App Store.

## O que muda e o que se preserva

**Rewrite, não refactor:** o código Swift/SwiftUI não é reaproveitado. O que
**viaja** é o desenho já registrado em specs/RFCs:

- modelo de dados (planejado × realizado, snapshots);
- máquina de estados da execução (`RunnerEngine`) e o achatamento em passos;
- algoritmos (volume, 1RM, aderência) e o formato de export/import;
- os princípios: offline-first, domínio puro/testável, acessibilidade.

A separação em camadas (domínio puro ↔ UI ↔ persistência) que já existe no nativo é
justamente o que torna o port relativamente mecânico.

## Stack proposta

| Camada | Escolha | Racional |
|---|---|---|
| Linguagem | **TypeScript** | tipagem forte; port quase 1:1 dos enums/DTOs de Swift |
| UI | **React 18 + Vite** | ecossistema maduro, `vite-plugin-pwa` para service worker |
| Estado (ViewModels) | **Zustand** | stores leves que espelham os `@Observable` ViewModels |
| Persistência | **Dexie.js (IndexedDB)** | offline-first no navegador; papel da SwiftData (ver RFC-0002) |
| Gráficos (v3) | **Recharts** | equivalente ao Swift Charts |
| PWA | **Workbox** (via vite-plugin-pwa) | manifest + offline + instalável |
| Testes | **Vitest** | unit da lógica de domínio pura (ver RFC-0004) |
| Hospedagem/CI | **GitHub Pages + GitHub Actions** | grátis; reaproveita o GitHub já em uso |

Decisão de default: **sem backend, sem terceiros** — coerente com o princípio do
produto. O app é local-first; a discussão de sync fica adiada (RFC-0002 §Sync).

## Arquitetura (espelha a atual)

```
src/
├─ domain/        # TS puro, portado do Swift: RunnerEngine, stepBuilder,
│                 #   metrics, exportService, enums, tipos. SEM I/O nem React.
├─ data/          # repositórios Dexie (papel da camada SwiftData)
├─ state/         # stores Zustand (papel dos ViewModels)
├─ ui/            # componentes e telas React (papel das Views SwiftUI)
├─ pwa/           # manifest, service worker, ícones
└─ main.tsx
```

Regra mantida do nativo: **a UI nunca fala com o IndexedDB direto** — sempre via
store → repositório. O `domain/` é puro e testável sem navegador.

## Roadmap de migração em fases

| Fase | Escopo | Entrega |
|------|--------|---------|
| **P0 — Shell PWA** | projeto Vite+React+TS, manifest, service worker, deploy no GitHub Pages, CI | PWA vazio **instalável no iPhone** |
| **P1 — Domínio + dados** | port de `RunnerEngine`/stepBuilder + camada Dexie + CRUD de fichas/exercícios (v1: G1–G3, G5, G6) | criar/editar fichas, agenda, catálogo |
| **P2 — Execução + histórico** | runner com timer (ver RFC-0003) + gravação e histórico (v1 G4/G7 + v2 G8) | treinar e ver histórico |
| **P3 — Backup + métricas** | export/import JSON/CSV (G13) + gráficos/PRs (G9–G11) | backup e progresso |
| **P4 — Sync (decisão adiada)** | local-only vs. backend opcional | ver RFC-0002 §Sync |

Cada fase de implementação gera sua **spec** em `/specs` e entradas em
`FEATURES.md`, conforme as regras do `CLAUDE.md`.

## Trade-offs assumidos

- **Ganha:** funciona do Windows, grátis, instalável no iPhone hoje; de brinde vira
  multiplataforma (Android/desktop via mesmo PWA).
- **Perde:** fidelidade nativa. O ponto mais sensível é o **timer de descanso com
  notificação em background** (feature central G4), limitado no iOS PWA — tratado na
  RFC-0003. Sem CloudKit; sem presença na App Store; VoiceOver/haptics menos ricos
  que no nativo.

## Riscos e decisões em aberto

| # | Questão | Encaminhamento |
|---|---|---|
| R1 | Timer/notificação em background no iOS PWA | RFC-0003 (mitigações + expectativa honesta) |
| R2 | Persistência do IndexedDB (eviction do Safari) | `navigator.storage.persist()`; RFC-0002 |
| R3 | Sync entre dispositivos sem backend | adiado; local-first + export/import como ponte (RFC-0002) |
| R4 | Manter ou arquivar o código nativo | manter como histórico numa branch/tag; web nasce em novo diretório |
| R5 | Atualizar `CLAUDE.md` (hoje iOS-cêntrico) e o agente de review | fazer ao **aceitar** esta RFC, junto do início da P0 |

## Decisão pedida

Aprovar a direção (PWA + stack acima) para destravar a P0. As RFCs 0002–0004
detalham dados/offline, timer/notificações e o port do domínio.
