# Sistema de RAG sobre o projeto Lift+

- Data: 2026-07-22
- Feature relacionada: (infra de desenvolvimento — não é feature do app)
- Status: **proposta** (nada implementado nesta etapa)

## Objetivo

Dar aos agentes e ao desenvolvedor uma forma de **consultar o próprio projeto em
linguagem natural** — "onde vive a lógica de descanso?", "qual a spec da execução
de treino?", "já existe algo parecido com isto?" — recuperando os trechos mais
relevantes de código, specs, `FEATURES.md` e docs para embasar respostas,
implementações e code reviews.

O RAG é uma **ferramenta de desenvolvimento local**, não um componente do app iOS.
O app permanece offline-first, sem backend nem telemetria; o RAG roda na máquina do
desenvolvedor / no ambiente do Claude Code e **nunca** é embarcado no bundle.

## Escopo

**Entra:**
- Indexação do repositório (código Swift, specs, `FEATURES.md`, docs, `CLAUDE.md`,
  `project.yml`, workflows).
- Pipeline de chunking + embeddings + vector store local.
- Interface de consulta usável durante o desenvolvimento (CLI + integração com os
  agentes).

**Fica de fora (por ora):**
- Qualquer uso em runtime pelo app.
- Reindexação em tempo real por file-watcher (a v1 do RAG reindexará sob demanda).
- Infra hospedada / multiusuário.

## O que será indexado

| Fonte | Peso | Racional | Estratégia de chunk |
|---|---|---|---|
| Código Swift (`LiftPlus/**/*.swift`) | alto | principal alvo de perguntas "onde/como" | por símbolo (tipo/função) |
| Testes (`LiftPlusTests/**/*.swift`) | médio | exemplos de uso e contratos esperados | por método de teste |
| Specs (`specs/*.md`) | alto | fonte da verdade de intenção; base do code review | por seção (`##`) |
| `FEATURES.md` | alto | catálogo de features → dedupe e rastreio | por entrada de feature (`###`) |
| `docs/**` | médio | plano macro, decisões de arquitetura | por seção |
| `CLAUDE.md`, `README.md` | médio | regras e convenções do projeto | por seção |
| `project.yml`, `.github/workflows/**` | baixo | build/CI | arquivo inteiro (pequeno) |

**Excluídos:** `*.xcodeproj` (gerado), `DerivedData/`, `.build/`, binários, e o
`seed_exercises.json` (dado, não conhecimento — indexar no máximo os nomes).

## Estratégia de chunking

Chunking **consciente de estrutura**, não por janela fixa de caracteres:

- **Swift → por símbolo.** Um chunk = uma declaração de topo (`struct`/`class`/
  `enum`/`extension`) ou um método grande, mantendo a assinatura e o doc-comment
  junto do corpo. Preserva a unidade semântica ("o `RunnerEngine.handle` inteiro").
  - Alvo ~200–400 tokens; símbolos maiores que ~600 tokens são divididos por
    método/bloco, repetindo o cabeçalho do tipo no chunk-filho.
  - Ferramenta sugerida: parser leve baseado em regex de topo + chaves, ou
    `SourceKitten`/`swift-syntax` se quisermos precisão (decisão em aberto §Riscos).
- **Markdown → por seção (`##`/`###`).** Cada seção vira um chunk; o título da
  seção e do arquivo entram como prefixo de contexto.
- **`FEATURES.md` → por entrada** (`### F<N>`), já que cada feature é uma unidade.

**Metadados por chunk** (essenciais para filtrar e citar a fonte):
```
{ path, kind: code|spec|feature|doc, symbol?, feature_id?, start_line, end_line,
  git_commit, language }
```
Overlap pequeno (1 assinatura / 1 heading) para não perder contexto de borda.

## Embeddings

- **Modelo:** um modelo de embeddings de código local, para não enviar o código a
  terceiros (coerente com "sem API de terceiros" do produto). Candidatos:
  `nomic-embed-text`, `bge-small`/`bge-base`, ou um embedding de código dedicado,
  rodando via Ollama ou `llama.cpp`.
  - Alternativa: embeddings de um provedor via API **apenas** se o desenvolvedor
    optar explicitamente — não é o default, e nunca para código sensível.
- **Dimensão/normalização:** vetores normalizados (L2) para usar similaridade de
  cosseno.
- **Consistência:** o mesmo modelo indexa e consulta; a versão do modelo é gravada
  no índice para invalidar quando mudar.

## Vector store

- **Local e leve.** Candidatos: **SQLite + sqlite-vec** (um arquivo, zero serviço),
  **LanceDB** ou **Chroma** (persistente em disco). Recomendação: `sqlite-vec` pela
  simplicidade (um arquivo `.db` versionável-ignorado, fácil de recriar).
- **Localização:** `.rag/index.db` (git-ignored). O índice é **derivado** — sempre
  recriável a partir do repo; nunca é fonte da verdade.
- **Busca híbrida:** vetorial (semântica) + palavra-chave (BM25/`FTS5` do SQLite)
  combinadas, porque perguntas de código misturam intenção ("cálculo de volume") e
  termos exatos ("`totalVolume`"). Reordenação simples por soma ponderada.
- **Filtro por metadados:** permitir restringir a `kind=spec` ou a uma `feature_id`
  (ex.: no code review, buscar só a spec da feature em questão).

## Pipeline de indexação

```
enumerar arquivos (respeitando .gitignore + exclusões)
   → chunk por tipo de arquivo (código/markdown)
   → anexar metadados (path, símbolo, linhas, commit)
   → embutir (batch) com o modelo local
   → upsert no vector store (chave = hash do conteúdo do chunk)
```

- **Incremental:** só reindexa arquivos cujo hash mudou desde o último run
  (guardar `path → content_hash`). Chunks órfãos (arquivo removido) são apagados.
- **Gatilho (v1 do RAG):** manual — `rag index` — e opcionalmente um passo no CI
  ou um git hook `post-commit`. File-watcher fica para depois.

## Como o RAG é consultado durante o desenvolvimento

1. **CLI** (`rag query "como o timer de descanso sobrevive ao background?"`):
   retorna os top-k chunks com `path:linhas`, o tipo da fonte e um trecho — clicável
   no terminal.
2. **Pelos agentes do projeto** (fases 3 e 4):
   - **Agente de dev iOS:** antes de implementar, consulta o RAG para achar código
     reutilizável, convenções e specs relacionadas (evita duplicar e mantém padrão).
   - **Agente de code review:** dado o diff de uma feature, recupera a **spec
     correspondente** (`kind=spec`, `feature_id`) e trechos vizinhos para checar
     aderência.
   - Exposto como uma ação/ferramenta simples que os agentes chamam com uma query e
     recebem os chunks + fontes.
3. **Formato de resposta da consulta:**
   ```
   [score] path:start-end  (kind, symbol)
     <trecho>
   ```
   Sempre com a **fonte citável** — o objetivo é fundamentar respostas em arquivos
   reais, nunca substituir a leitura do código.

## Testes / validação

- Conjunto pequeno de perguntas-douradas ("golden queries") com o arquivo esperado
  no top-k (ex.: "avanço automático de descanso" → `RunnerEngine.swift`).
- Verificar recall@k nesse conjunto ao trocar modelo de embedding ou estratégia de
  chunk.

## Riscos e decisões em aberto

| # | Questão | Encaminhamento |
|---|---|---|
| R1 | Parser Swift: regex simples vs. `swift-syntax`/SourceKitten | Começar com regex de topo; migrar para `swift-syntax` se a qualidade do chunk exigir |
| R2 | Modelo de embedding local vs. API | Default local (privacidade); API só opt-in |
| R3 | Vector store: `sqlite-vec` vs. LanceDB/Chroma | Recomendado `sqlite-vec` pela simplicidade; reavaliar se o volume crescer |
| R4 | Custo de reindexação em repositório pequeno | Baixo hoje; incremental por hash resolve |
| R5 | Manter o índice fora do git | Sim — `.rag/` no `.gitignore`; índice é derivado |
| R6 | Overlap de código quebrando símbolos | Chunk por símbolo com cabeçalho repetido nos filhos mitiga |

## Próximos passos (se aprovado)

1. Definir R1–R3 (parser, modelo, store).
2. Registrar a feature de infra em `FEATURES.md` e detalhar a implementação em
   `specs/YYYY-MM-DD-rag-indexer.md`.
3. Implementar `rag index` e `rag query` (script local, fora do target do app).
4. Integrar a consulta aos agentes das fases 3 e 4.
