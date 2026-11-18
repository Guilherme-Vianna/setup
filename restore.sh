#!/usr/bin/env bash
# Restaura o backup gerado por backup.ps1 no Fedora/Ubuntu.
# Uso: ./restore.sh /caminho/para/setup-backup-AAAAMMDD [--no-ollama]
# Nao sobrescreve arquivos existentes sem fazer backup (.bak).
set -euo pipefail

SRC="${1:-}"; shift || true
PULL_OLLAMA=1
[[ "${1:-}" == "--no-ollama" ]] && PULL_OLLAMA=0
[[ -d "$SRC" ]] || { echo "Uso: $0 /caminho/setup-backup-AAAAMMDD [--no-ollama]"; exit 1; }

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }

# copia dir -> dest, preservando o que ja existe (rsync sem --delete; backup dos alterados)
restore_dir() {
  local from="$1" to="$2"
  [[ -d "$from" ]] || return 0
  mkdir -p "$to"
  rsync -a --backup --suffix=.bak "$from"/ "$to"/
  echo "  $to"
}
restore_file() {
  local from="$1" to="$2"
  [[ -f "$from" ]] || return 0
  [[ -e "$to" ]] && cp -a "$to" "$to.bak"
  cp -a "$from" "$to"; echo "  $to"
}

command -v rsync >/dev/null || { echo "Instale rsync (dnf/apt install rsync)"; exit 1; }

log "SSH"
restore_dir "$SRC/ssh" "$HOME/.ssh"
if [[ -d "$HOME/.ssh" ]]; then
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f ! -name '*.pub' ! -name 'known_hosts*' ! -name 'config' -exec chmod 600 {} +
  find "$HOME/.ssh" -type f \( -name '*.pub' -o -name 'known_hosts*' -o -name config \) -exec chmod 644 {} +
fi

log "Configs"
restore_file "$SRC/gitconfig" "$HOME/.gitconfig"
restore_dir  "$SRC/claude" "$HOME/.claude"
restore_dir  "$SRC/gemini" "$HOME/.gemini"
restore_dir  "$SRC/codex"  "$HOME/.codex"
restore_file "$SRC/aider.conf.yml" "$HOME/.aider.conf.yml"
restore_file "$SRC/aider.model.settings.yml" "$HOME/.aider.model.settings.yml"

log "Projetos e dados"
restore_dir "$SRC/projetos/agro-transparente" "$HOME/dev/agro-transparente"
restore_dir "$SRC/projetos/source-repos"      "$HOME/dev/repos"
restore_dir "$SRC/tools"           "$HOME/tools"
restore_dir "$SRC/iot_db"          "$HOME/iot_db"
restore_dir "$SRC/knime-workspace" "$HOME/knime-workspace"
restore_dir "$SRC/Livros"          "$HOME/Documentos/Livros"
if [[ -d "$SRC/extra" ]]; then
  for d in "$SRC"/extra/*/; do restore_dir "$d" "$HOME/Documentos/$(basename "$d" | sed 's/^[0-9]*-//')"; done
fi

log "Dependencias Python (uv)"
if [[ -f "$SRC/listas/requirements.txt" ]]; then
  echo "  Lista salva em $SRC/listas/requirements.txt."
  echo "  Instale por projeto: uv venv && uv pip install -r requirements.txt"
fi

if [[ $PULL_OLLAMA -eq 1 && -f "$SRC/listas/ollama-models.txt" ]]; then
  log "Modelos do Ollama"
  if command -v ollama >/dev/null; then
    while read -r m; do [[ -n "$m" ]] && ollama pull "$m" || true; done < "$SRC/listas/ollama-models.txt"
  else warn "ollama nao instalado; rode ./install.sh --only ollama e repita."; fi
fi

log "Pronto"
warn "Faca login de novo: 'claude' e 'gemini'. Credenciais nao foram copiadas de proposito."
warn "Teste o SSH: ssh -T git@github.com  (ou 'gh auth login')."
warn "Apague o backup (tem chave SSH privada) quando terminar de conferir."
