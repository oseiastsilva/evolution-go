# Patches locais deste fork

Rótulo de versão: **`0.7.3`** (`VERSION` / imagens `evolution-go-fintalk:0.7.3.x`).
Base git: tag oficial **`0.7.2`** (`9337afc`) + patches abaixo (paridade funcional
nos pontos críticos do 0.7.3 oficial, sem merge completo da release).
Cada patch é um commit separado na branch `fintalk`, para poder ser reaplicado
(cherry-pick/rebase) quando uma versão nova oficial for adotada — ou descartado
se o upstream incorporar a mesma correção.

## 001 — Container/pool único do sqlstore (vazamento de conexões)

- **Arquivo do patch:** `patches/001-shared-sqlstore-pool.patch`
- **Origem:** PR [#102](https://github.com/evolution-foundation/evolution-go/pull/102)
  / [#117](https://github.com/evolution-foundation/evolution-go/pull/117); alinhado
  ao `getAuthContainer` da release oficial **0.7.3**.
- **Issues:** [#106](https://github.com/evolution-foundation/evolution-go/issues/106),
  [#109](https://github.com/evolution-foundation/evolution-go/issues/109),
  [#112](https://github.com/evolution-foundation/evolution-go/issues/112),
  [#118](https://github.com/evolution-foundation/evolution-go/issues/118)
- **Problema:** `StartClient()` chamava `sqlstore.New()` a cada conectar/reconectar,
  criando um `*sql.DB` novo (sem limite, sem expiração) que nunca era fechado.
  Cada reconnect vazava um pool; o Postgres enchia de conexões `idle` no
  `evogo_auth` até retornar `FATAL: sorry, too many clients already`.
- **Correção:** um único `sqlstore.Container` compartilhado via mutex (só memoriza
  sucesso — falha tenta de novo no próximo `StartClient`). Postgres reusa o pool
  que o `main.go` já abriu e capou (`w.authDB` / 25 open / 5 idle); SQLite abre
  um DB próprio com `MaxOpenConns(1)`. `Upgrade` com timeout de 60s para não
  travar todos os connects atrás de um Postgres “zumbi”.
- **Quando descartar:** quando a base do fork for a release oficial ≥ 0.7.3
  (já traz o mesmo `getAuthContainer`).

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

## 005 — Atualização do whatsmeow + versão do WhatsApp nunca regride

- **Arquivo do patch:** `patches/005-whatsmeow-2026-11-02.patch`
- **Origem:** atualização manual da dependência (ver README-FINTALK, seção
  "Atualizar só o whatsmeow").
- **Problema:** o whatsmeow de 2026-06-30 anunciava `2.3000.1042386815` e o
  WhatsApp passou a responder `Client outdated (405)` antes de gerar o QR.
  Além disso, `fetchWhatsAppWebVersion` sempre sobrescrevia a versão padrão da
  biblioteca com o `client_revision` do `sw.js` — que pode vir de cache de CDN
  antigo — rebaixando a versão mesmo com whatsmeow novo.
- **Correção:**
  - `go.mau.fi/whatsmeow` → `v0.0.0-20261102152715-54038813c47f` (02/11/2026).
  - Ajustes de API em `pkg/user/service/user_service.go`
    (`UpdateBlocklist`/`GetBlocklist` com `dhash` e `SetStatusMessage` com
    `types.SetStatusInput`).
  - `StartClient` só usa a revisão do `sw.js` se ela for **mais nova** que a
    padrão do whatsmeow (`versaoWhatsAppMaisNova`).
  - `fetchWhatsAppWebVersion` passou a usar `whatsmeow.GetLatestVersion`
    (página atual do WhatsApp Web, com headers de navegador) e tem piso em
    `versaoMinimaWhatsApp` para não aceitar revisão velha de cache.
  - Go 1.26+ (`Dockerfile` com `golang:1.27.3-alpine`) e imagem
    `evolution-go-fintalk:0.7.3.1` para forçar rebuild no Coolify.
- **Quando descartar:** quando o upstream atualizar o whatsmeow e corrigir a
  lógica de versão (verificar `fetchWhatsAppWebVersion` e `StartClient`).

## Como adicionar um patch novo

1. Faça a alteração em commit próprio, com mensagem `fix(escopo): descrição`.
2. Exporte uma cópia: `git format-patch -1 HEAD --stdout > patches/NNN-nome.patch`
   (ou `git diff <tag-oficial>..HEAD -- <arquivos> > patches/NNN-nome.patch`).
3. Registre aqui: origem (issue/PR), problema, correção e quando descartar.
