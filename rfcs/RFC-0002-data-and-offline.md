# RFC-0002 — Camada de dados e offline-first no navegador

- Status: **rascunho**
- Data: 2026-07-22
- Relacionada: RFC-0001

## Objetivo

Definir como o PWA guarda os dados **localmente**, permanece 100% funcional
**offline** e preserva o modelo "planejado × realizado" do app nativo — assumindo o
papel que a SwiftData tinha.

## Store: IndexedDB via Dexie.js

- **IndexedDB** é o único armazenamento local do navegador adequado a volume e
  consultas; `localStorage` não serve (síncrono, ~5 MB, só string).
- **Dexie.js** dá uma API tipada e ergonômica sobre o IndexedDB (índices,
  transações, migrações de schema versionadas).
- O acesso fica isolado em **repositórios** (`src/data/`); o resto do app não conhece
  Dexie — espelha a regra "Views não acessam a persistência direto".

## Modelo de dados (port do nativo)

Mantém a separação e os snapshots. Tabelas Dexie (chave primária `id: string` =
UUID; ordenação por `orderIndex` explícito):

```ts
// planejado
exercises:  'id, seedSlug, name'
plans:      'id, orderIndex, isArchived'
blocks:     'id, planId, orderIndex'
plannedExercises: 'id, blockId, orderIndex'
plannedSets: 'id, plannedExerciseId, orderIndex'
schedule:   'id, weekday, planId'

// realizado (snapshots autossuficientes)
sessions:   'id, startedAt, status, planId'
sessionItems: 'id, sessionId, orderIndex, exerciseId'
performedSets: 'id, itemId, orderIndex'
```

Observações de port:
- Relacionamentos do SwiftData viram **chaves estrangeiras explícitas** (`planId`,
  `blockId`, …); as buscas hierárquicas são montadas no repositório.
- Enums (`BlockKind`, `MuscleGroup`, `RestKind`, `SessionStatus`) migram como union
  types/`enum` de TS com os **mesmos `rawValue`** do Swift — isso mantém o formato de
  export/import **compatível** entre o app nativo e o web (mesmos JSONs).
- Sessões continuam sendo snapshots (nome/músculos/alvos copiados), então editar/
  apagar fichas não corrompe o histórico.

## Offline-first

- **App shell** cacheado pelo service worker (Workbox, `vite-plugin-pwa`) → a UI
  abre sem rede.
- **Dados** no IndexedDB → toda leitura/escrita é local; não há chamada de rede no
  caminho crítico. O app é a fonte da verdade, igual ao nativo.
- **Persistência durável:** solicitar `navigator.storage.persist()` no primeiro uso
  para reduzir o risco de o Safari despejar (evict) o IndexedDB sob pressão de
  armazenamento (R2 da RFC-0001). Expor no app um aviso de "backup recomendado".

## Export/import (G13) — ponte de portabilidade

- Reusar os **mesmos DTOs versionados** do `ExportService` nativo (JSON completo +
  CSV do histórico). Como os `rawValue` são idênticos, um backup exportado no app
  nativo pode ser importado no web e vice-versa — caminho de migração dos dados do
  usuário sem servidor.
- Import continua **idempotente** (merge por `id`), com `rebuildDerivedData`
  recalculando volume.

## Sync entre dispositivos (decisão adiada — R3)

Sem CloudKit e mantendo "sem backend próprio", as opções são:

| Opção | Prós | Contras |
|---|---|---|
| **Local-only + export/import manual** (default) | zero backend; coerente com o produto | sync manual |
| Backend opcional (ex.: Supabase/Firebase) | sync automático | quebra "sem backend/terceiros"; contas |
| Arquivo em nuvem do usuário (iCloud Drive/Drive via share) | sem backend próprio | semi-manual, atrito |

**Encaminhamento:** começar **local-only** com export/import como ponte; decidir sync
só se/quando houver necessidade real (nova RFC).

## Testes

- Repositórios testados com `fake-indexeddb` no Vitest (sem navegador).
- Round-trip export→import e idempotência portados dos testes nativos.

## Decisão pedida

Aprovar Dexie/IndexedDB, o port do schema com `rawValue` idênticos e a postura
**local-only + export/import** como estratégia inicial de portabilidade/sync.
