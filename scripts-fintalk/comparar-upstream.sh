#!/usr/bin/env bash
# Compara este fork com o Evolution Go oficial (upstream).
# Uso: ./scripts-fintalk/comparar-upstream.sh [tag-base]   (padrão: 0.7.2)
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${1:-0.7.2}"

echo "== Buscando novidades do upstream =="
git fetch upstream --tags --quiet

echo
echo "== Sua posição =="
echo "Branch atual : $(git branch --show-current)"
echo "Base oficial : $BASE ($(git rev-parse --short "$BASE"))"

echo
echo "== O que o oficial tem de novo (desde $BASE até upstream/main) =="
git --no-pager log --oneline "$BASE..upstream/main" | head -30 || true

echo
echo "== Arquivos alterados no oficial desde $BASE (resumo) =="
git --no-pager diff --stat "$BASE..upstream/main" | tail -20 || true

echo
echo "== O que é só nosso (nossos commits sobre a base) =="
git --no-pager log --oneline "upstream/main..HEAD" || true

echo
echo "== Arquivos em que divergimos do oficial =="
git --no-pager diff --stat upstream/main...HEAD | tail -20 || true

echo
echo "Dica: para ver se o bug do pool já foi corrigido lá:"
echo "  git diff upstream/main -- pkg/whatsmeow/service/whatsmeow.go | head -50"
