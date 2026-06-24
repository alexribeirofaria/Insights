#!/bin/bash
set -euo pipefail

files=$(git status --porcelain=v1 -uall | awk '{print $2}' | sort -u)

if [ -z "${files}" ]; then
  echo "Nenhuma alteração encontrada."
  exit 0
fi

for file in $files; do
  status_line=$(git status --porcelain=v1 -uall -- "$file" | head -n 1 || true)
  status=""
  if [ -n "$status_line" ]; then
    status=$(echo "$status_line" | awk '{print $1}' | head -c 1)
    # status may be "M" or "A" depending on index/worktree; if empty fallback
    if [ -z "$status" ]; then status=$(echo "$status_line" | awk '{print $1}' | head -c 1); fi
  fi

  diff_content=$(git diff -- "$file" 2>/dev/null || true)
  diff_cached_content=$(git diff --cached -- "$file" 2>/dev/null || true)
  combined_diff="$diff_content\n$diff_cached_content"

  case "$status" in
    A|"??") tipo="feat";    acao="adicionar" ;;
    M)       tipo="fix";     acao="atualizar" ;;
    D)       tipo="chore";   acao="remover"   ;;
    *)       tipo="chore";   acao="atualizar" ;;
  esac

  if echo "$combined_diff" | grep -qiE "\.test\.|\.spec\.|describe\(|it\(|test\("; then
    tipo="test"
    acao="atualizar testes em"
  elif echo "$combined_diff" | grep -qiE "README|\.md$|\/docs\/|documentation"; then
    tipo="docs"
    acao="atualizar documentação em"
  elif echo "$combined_diff" | grep -qiE "package\.json|\.env|\.config\.|tsconfig|webpack|vite|eslint|prettier"; then
    tipo="chore"
    acao="atualizar configuração de"
  elif echo "$combined_diff" | grep -qiE "function |const .* = \(|=> {|def "; then
    if [[ "$status" == "A" || "$status" == "??" ]]; then
      tipo="feat"; acao="adicionar função em"
    else
      tipo="refactor"; acao="refatorar função em"
    fi
  elif echo "$combined_diff" | grep -qiE "class |interface |type "; then
    tipo="refactor"
    acao="atualizar estrutura de"
  elif echo "$combined_diff" | grep -qiE "fix|bug|erro|error|correct|corrig"; then
    tipo="fix"
    acao="corrigir problema em"
  fi

  nome_arquivo=$(basename "$file")
  nome_sem_ext="${nome_arquivo%.*}"
  mensagem="$tipo: $acao $nome_sem_ext"

  # tenta commitar mudanças de working tree (staged ou unstaged)
  git add -A -- "$file" || true

  if git diff --cached --quiet -- "$file"; then
    echo "ℹ️ Sem alterações staged para $file (pulando)."
    continue
  fi

  git commit -m "$mensagem" || true
  echo "✅ Commit criado → [$mensagem]"
done

echo ""
echo "🎉 Todos os commits foram criados com sucesso!"
