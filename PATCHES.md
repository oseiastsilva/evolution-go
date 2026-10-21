# Patches locais deste fork

Base: **tag oficial `0.7.2`** (`9337afc`) do `evolution-foundation/evolution-go`.
Cada patch é um commit separado na branch `fintalk`, para poder ser reaplicado
(cherry-pick/rebase) quando uma versão nova oficial for adotada — ou descartado
se o upstream incorporar a mesma correção.

## 001 — Container/pool único do sqlstore (vazamento de conexões)

- **Arquivo do patch:** `patches/001-shared-sqlstore-pool.patch`
- **Origem:** PR [#102](https://github.com/evolution-foundation/evolution-go/pull/102)
  (Ay0rus), mesma correção do PR [#117](https://github.com/evolution-foundation/evolution-go/pull/117)
  (guilhermeCassettari, rebaseado para a `develop`).
- **Issues:** [#106](https://github.com/evolution-foundation/evolution-go/issues/106),
  [#109](https://github.com/evolution-foundation/evolution-go/issues/109),
  [#112](https://github.com/evolution-foundation/evolution-go/issues/112),
  [#118](https://github.com/evolution-foundation/evolution-go/issues/118)
- **Problema:** `StartClient()` chamava `sqlstore.New()` a cada conectar/reconectar,
  criando um `*sql.DB` novo (sem limite, sem expiração) que nunca era fechado.
  Cada reconnect vazava um pool; o Postgres enchia de conexões `idle` no
  `evogo_auth` até retornar `FATAL: sorry, too many clients already`.
- **Correção:** um único `sqlstore.Container` compartilhado, criado uma vez
  (`sync.Once`) via `sqlstore.NewWithDB`, com pool limitado
  (Postgres: 20 abertas / 5 idle / lifetime 5min / idle 2min; SQLite: 1).
- **Diferença para o PR #117:** o #117 substitui o `sync.Once` por um mutex que
  só memoriza sucesso (se o Postgres falhar na primeira tentativa, tenta de novo
  na próxima). Se um dia portarmos o #117, atualizar este arquivo.
- **Quando descartar:** quando uma release oficial trouxer a correção (verificar
  se `StartClient` ainda chama `sqlstore.New` por cliente no `whatsmeow.go`).

## 002 — Panic no evento Archive (derruba o processo)

- **Arquivo do patch:** `patches/002-archive-event-panic.patch`
- **Origem:** PR [#195](https://github.com/evolution-foundation/evolution-go/pull/195)
  (EcoosUP), cherry-pick do commit `16c4be6` para a `fintalk` em 2026-10-21.
- **Issues:** [#95](https://github.com/evolution-foundation/evolution-go/issues/95),
  [#101](https://github.com/evolution-foundation/evolution-go/issues/101)
- **Problema:** no handler de `*events.Archive`, `postMap["data"]` ainda continha
  o evento bruto quando o código fazia a asserção
  `postMap["data"].(map[string]interface{})` — panic garantido a cada
  arquivar/desarquivar de conversa, matando o processo (todas as instâncias).
- **Correção:** normaliza `postMap["data"]` via marshal/unmarshal JSON (mesmo
  passo que os outros cases do switch) antes da asserção; se estiver nil, cria
  o mapa vazio.
- **Quando descartar:** quando uma release oficial trouxer o handler do Archive
  sem a asserção insegura em `pkg/whatsmeow/service/whatsmeow.go`.

## 003 — Mutex nos mapas compartilhados (concurrent map writes)

- **Arquivo do patch:** `patches/003-shared-maps-mutex.patch`
- **Origem:** PR [#196](https://github.com/evolution-foundation/evolution-go/pull/196)
  (EcoosUP), cherry-pick do commit `3860fa2` para a `fintalk` em 2026-10-21.
- **Issue:** [#203](https://github.com/evolution-foundation/evolution-go/issues/203)
  (`fatal error: concurrent map writes` em `StartClient`)
- **Problema:** `clientPointer`, `myClientPointer` e `killChannel` eram `map`
  comuns criados na inicialização e passados por referência para 11 pacotes,
  lidos/escritos de várias goroutines sem sincronização. Como o erro é fatal
  (não é panic recuperável), uma ocorrência derruba o processo inteiro —
  tipicamente na subida, com várias instâncias conectando ao mesmo tempo.
- **Correção:** novo pacote `pkg/safemap` (map genérico com `sync.RWMutex` e
  teste próprio, incluindo `-race`) e migração de todos os acessos nos
  serviços para `Get`/`Set`/`Delete`/`Range` etc.
- **Quando descartar:** quando uma release oficial proteger esses mapas
  (verificar se `main.go` ainda cria `map[string]...` comuns para eles).

## 004 — Não remover o nono dígito de celular BR (DDD >= 31)

- **Arquivo do patch:** `patches/004-br-ninth-digit.patch`
- **Origem:** PR [#208](https://github.com/evolution-foundation/evolution-go/pull/208)
  (alejandro-mero), cherry-pick do commit `2de8bfb` para a `fintalk` em
  2026-10-21.
- **Issue:** [#214](https://github.com/evolution-foundation/evolution-go/issues/214)
- **Problema:** `formatBRNumber` (`pkg/utils/utils.go`) removia o 9 de todo
  celular brasileiro de 13 dígitos com DDD >= 31 e primeiro dígito >= 7
  (ex.: DDD 41, 45, 48), de forma irreversível já no middleware de validação
  do JID. Para números registrados no WhatsApp com os 9 dígitos, o envio
  falhava mesmo o restante do código sabendo lidar com as duas formas.
- **Correção:** remove a regra de remoção do 9 para DDD >= 31, mantendo o
  número como informado; testes de `formatBRNumber` atualizados.
- **Quando descartar:** quando uma release oficial parar de reescrever o
  número dessa forma (verificar `formatBRNumber` em `pkg/utils/utils.go`).

## Como adicionar um patch novo

1. Faça a alteração em commit próprio, com mensagem `fix(escopo): descrição`.
2. Exporte uma cópia: `git format-patch -1 HEAD --stdout > patches/NNN-nome.patch`
   (ou `git diff <tag-oficial>..HEAD -- <arquivos> > patches/NNN-nome.patch`).
3. Registre aqui: origem (issue/PR), problema, correção e quando descartar.
