# RFCs — Lift+

RFC (*Request for Comments*) é um documento de decisão de arquitetura/direção do
projeto, mais amplo que uma spec de feature. Enquanto uma **spec** (`/specs`)
descreve **uma** feature a ser implementada, uma **RFC** registra uma **decisão
estruturante** (stack, migração, estratégia transversal) que gera várias features.

## Relação com `/specs` e `FEATURES.md`

- **RFC** → decisão estruturante ("migrar para web app"). Fica em `rfcs/`.
- **Spec** → plano de uma feature concreta derivada da direção. Fica em `specs/`.
- **FEATURES.md** → registro append-only; a iniciativa e cada feature apontam para
  a RFC/spec que as originou.

## Convenção

```
rfcs/RFC-NNNN-titulo-curto.md
```

Status possíveis: `rascunho` · `em revisão` · `aceita` · `substituída por RFC-NNNN` ·
`rejeitada`.

## Índice

| RFC | Título | Status |
|-----|--------|--------|
| [0001](RFC-0001-web-migration-overview.md) | Migração para web app (PWA) — visão geral e arquitetura | rascunho |
| [0002](RFC-0002-data-and-offline.md) | Camada de dados e offline-first no navegador | rascunho |
| [0003](RFC-0003-timer-and-notifications.md) | Timer de descanso e notificações no PWA iOS | rascunho |
| [0004](RFC-0004-domain-port-and-testing.md) | Port da lógica de domínio e testes | rascunho |

> Contexto da decisão: o objetivo do usuário é rodar o app **no próprio iPhone a
> partir de um PC Windows, sem Mac e sem o Apple Developer Program (US$99/ano)**. O
> app nativo iOS não atende essas restrições (build de Swift exige macOS). Um
> **PWA** é o único caminho que satisfaz Windows + sem Mac + sem custo + instalável
> no iPhone. Detalhes e trade-offs na RFC-0001.
