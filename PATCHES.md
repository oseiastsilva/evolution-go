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

## Como adicionar um patch novo

1. Faça a alteração em commit próprio, com mensagem `fix(escopo): descrição`.
2. Exporte uma cópia: `git format-patch -1 HEAD --stdout > patches/NNN-nome.patch`
   (ou `git diff <tag-oficial>..HEAD -- <arquivos> > patches/NNN-nome.patch`).
3. Registre aqui: origem (issue/PR), problema, correção e quando descartar.
