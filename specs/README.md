# /specs — Especificações de features

Cada plano de implementação gerado no projeto é salvo aqui como um arquivo de
especificação, seguindo a convenção definida em [`CLAUDE.md`](../CLAUDE.md):

```
specs/YYYY-MM-DD-nome-da-feature.md
```

## Para que servem

- **Histórico de decisões** — registram o raciocínio e o escopo acordados antes da
  implementação.
- **Referência do code review** — a implementação de cada feature é validada
  contra a sua spec correspondente (ver o agente de code review em
  `.claude/agents/`).

## Vínculo com `FEATURES.md`

Toda feature registrada em [`FEATURES.md`](../FEATURES.md) aponta para a spec que a
originou. Uma spec descreve **uma** feature (ou uma revisão de escopo de uma
feature anterior).

## Sugestão de estrutura de uma spec

```markdown
# <Nome da feature>

- Data: YYYY-MM-DD
- Feature relacionada: F<N> (FEATURES.md)
- Status: proposta | aprovada | implementada

## Objetivo
<o problema e o resultado esperado>

## Escopo
<o que entra e o que fica de fora>

## Design / abordagem
<modelo de dados, telas, fluxo, tipos e assinaturas principais>

## Testes
<o que será coberto e como>

## Riscos e decisões em aberto
```

> O plano macro original do produto (v1→v3) está em
> [`docs/PLANO-DE-DESENVOLVIMENTO.md`](../docs/PLANO-DE-DESENVOLVIMENTO.md).
