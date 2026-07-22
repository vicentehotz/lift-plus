# RFC-0003 — Timer de descanso e notificações no PWA iOS

- Status: **rascunho**
- Data: 2026-07-22
- Relacionada: RFC-0001 (risco R1 — ponto mais sensível da migração)

## Problema

No app nativo, o descanso (G4) usa **data absoluta** + **notificação local** que
dispara mesmo com o app em background ou fechado. No PWA em **iOS/Safari**, isso é
limitado: o iOS **suspende JS em background** e restringe fortemente notificações/
execução de PWAs. Como o timer é feature central, é preciso ser honesto sobre o que
dá e o que não dá — e mitigar.

## O que o iOS PWA permite (e não permite)

- **Contagem enquanto a aba está visível e ativa:** ✅ confiável (mesmo relógio por
  data absoluta: `endsAt = now + rest`, deriva-se o restante de `endsAt - now`).
- **Tela bloqueada / app em background / outra aba:** ⚠️ o timer JS **pausa**; ao
  voltar ao foreground recalcula-se pelo `endsAt` (o número fica correto), mas
  **nenhum código roda enquanto está fora**.
- **Web Push / Notifications:** disponível em iOS **16.4+**, porém **só para PWA
  instalado** na Tela de Início e **após permissão**; entrega em background é
  **melhor-esforço**, sem garantia de disparo pontual como a notificação local
  nativa. Requer um *push service* (servidor) para push real — o que conflita com
  "sem backend".

Conclusão: **não dá** para garantir um "bip" pontual com o telefone bloqueado e o
app fechado, como no nativo, sem um servidor de push.

## Estratégia proposta (camadas de mitigação)

Priorizar a experiência com a **tela ligada e o app aberto** (o caso real de quem
está treinando e olhando o descanso), degradando com transparência:

1. **Relógio por data absoluta** (igual ao nativo): guardar `endsAt`; a UI deriva o
   restante. Reabrir/voltar do background **sempre** mostra o tempo correto.
2. **Alerta local com a aba ativa:** ao chegar a zero, **som + vibração**
   (`navigator.vibrate`, quando suportado) + destaque visual grande. Cobre bem o
   fluxo "durante a série".
3. **Wake Lock opcional:** `navigator.wakeLock` para manter a tela acesa durante o
   descanso (quando o usuário permitir), reduzindo o cenário de background.
4. **Notificação via Service Worker quando instalado e permitido:** agendar uma
   `showNotification` best-effort; documentar que a pontualidade em background não é
   garantida no iOS. **Sem servidor de push** — nada de infra externa.
5. **Transparência na UI:** na primeira vez, explicar que "o aviso é confiável com o
   app aberto; com a tela bloqueada pode atrasar" e sugerir manter o app aberto no
   descanso.

## Fora de escopo (por ora)

- Push server dedicado (violaria "sem backend"). Reavaliar só se o timer em
  background virar requisito duro.

## Impacto no design

- O `RunnerEngine` portado permanece igual (é lógica pura por data absoluta); a
  diferença é só a **camada de efeitos** (som/vibração/notificação) e o aviso de
  expectativa.

## Testes

- Lógica de tempo (derivar restante, expiração ao voltar do background) testável no
  Vitest com relógio simulado — sem depender do navegador.

## Decisão pedida

Aceitar a estratégia em camadas e a limitação assumida (sem "bip" garantido com app
fechado no iOS, salvo adoção futura de push server). É o principal trade-off da
migração.
