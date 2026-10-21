# Fork Fintalk do Evolution Go

Esta pasta é um **fork do Evolution Go** para uso/estudo do Fintalk, mantido o
mais próximo possível do projeto oficial, com correções próprias pequenas e
documentadas por cima.

- **Base:** tag oficial `0.7.2` do `evolution-foundation/evolution-go`
- **Branch local:** `fintalk` (= `0.7.2` + patches + arquivos desta pasta)
- **Remotos:** `upstream` → repositório oficial. Quando você criar o seu fork
  no GitHub, adicione-o como `origin` (ver abaixo) para publicar seu trabalho.

Estrutura do que é **nosso** (o resto é código oficial, sem alteração):

| Arquivo/pasta | O que é |
|---|---|
| `docker-compose.yml` | Evo Go buildado daqui + Postgres local (porta host 5433) |
| `postgres/init/` | Cria `evogo_auth`/`evogo_users` + `idle_session_timeout` |
| `patches/` | Correções locais exportadas (ver `PATCHES.md`) |
| `fintalk.env.example` | Variáveis do compose — copie para `.env` |
| `scripts-fintalk/` | Comparar com o upstream e checar saúde do ambiente |
| `PATCHES.md` | Registro de cada patch: origem, motivo, quando descartar |

## Rodar local

```bash
cp fintalk.env.example .env        # opcional p/ teste rápido (há padrões dev)
docker compose up -d --build
docker compose logs -f evogo
```

API em `http://localhost:8080` (header `apikey: $GLOBAL_API_KEY`).
Postgres em `localhost:5433` (bancos `evogo_auth`, `evogo_users`).

> Cuidado: `docker compose down` preserva os volumes. `down -v` apaga as
> sessões do WhatsApp e exige parear de novo. Para testar, use um
> número/instância de teste — nunca rode este Evo Go local e o de produção ao
> mesmo tempo com a mesma sessão.

## Conferir as conexões (o bug original)

```bash
docker compose exec postgres psql -U postgres -d evogo_auth \
  -c "SELECT client_addr, state, count(*) FROM pg_stat_activity GROUP BY 1,2 ORDER BY 3 DESC;"
```

Sem o patch, esse número cresce a cada reconnect até 99+ (`idle`).
Com o patch, fica estável em poucas conexões.

## Acompanhar o oficial e atualizar

```bash
./scripts-fintalk/comparar-upstream.sh   # o que mudou lá e o que é só nosso
```

Fluxo quando sair versão nova (ex.: `0.7.3`):

```bash
git fetch upstream --tags
git switch -c teste-0.7.3 0.7.3
git cherry-pick <commits dos nossos patches>   # ver PATCHES.md / git log
docker compose up -d --build                   # testa: enviar/receber/reconectar
# ok? promove a branch, senão descarta a branch de teste
```

Antes de promover, faça backup do Postgres (`pg_dump`): versões novas do
whatsmeow podem migrar as tabelas `whatsmeow_*`.

## Atualizar só o whatsmeow (sem esperar release deles)

A versão da biblioteca fica fixada no `go.mod`
(`go.mau.fi/whatsmeow v0.0.0-...`). Para atualizar por conta própria:

```bash
go get go.mau.fi/whatsmeow@latest
go mod tidy
docker compose up -d --build evogo
```

Teste bem antes: a biblioteca pode mudar APIs e o schema do store de sessão.

## Publicar no seu GitHub

1. Crie o fork em https://github.com/evolution-foundation/evolution-go (Fork)
   ou um repositório novo e importe este.
2. `git remote add origin <url-do-seu-fork>`
3. `git push -u origin fintalk`

Nunca commite o `.env` real (senhas). O `.gitignore` oficial já cobre `.env`.
