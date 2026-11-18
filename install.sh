#!/usr/bin/env bash
# Setup multiplataforma para Fedora e Ubuntu/Debian.
# Uso: ./install.sh [--only docker,claude,...] [--skip firefox,...] [--list]
# Idempotente: pode rodar varias vezes sem problema.
set -euo pipefail

ALL_TOOLS=(base docker nvm uv claude gemini ollama zed firefox dbeaver obsidian obs vlc controllers tablet)
ONLY=""; SKIP=""
NVM_VERSION="v0.40.3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="$2"; shift 2;;
    --skip) SKIP="$2"; shift 2;;
    --list) printf '%s\n' "${ALL_TOOLS[@]}"; exit 0;;
    -h|--help) sed -n '2,4p' "$0"; exit 0;;
    *) echo "Argumento desconhecido: $1"; exit 1;;
  esac
done

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
want() {
  local t="$1"
  [[ -n "$ONLY" && ",$ONLY," != *",$t,"* ]] && return 1
  [[ ",$SKIP," == *",$t,"* ]] && return 1
  return 0
}

[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"
export PATH="$HOME/.local/bin:$PATH"

# ---- Detecta distro ----
. /etc/os-release
case "${ID}${ID_LIKE:-}" in
  *fedora*|*rhel*) DISTRO=fedora;;
  *ubuntu*|*debian*) DISTRO=debian;;
  *) echo "Distro nao suportada: $ID"; exit 1;;
esac
log "Distro detectada: $PRETTY_NAME ($DISTRO)"

pkg_install() {
  if [[ $DISTRO == fedora ]]; then $SUDO dnf install -y "$@"
  else $SUDO apt-get install -y "$@"; fi
}

ensure_flathub() {
  have flatpak || pkg_install flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

flatpak_app() { ensure_flathub; flatpak install -y flathub "$1"; }

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && set +u && . "$NVM_DIR/nvm.sh" && set -u
  return 0
}

# ---- Instaladores ----
install_base() {
  log "Base: git, gh, curl, wget, unzip, zstd, jq, gcc, make"
  if [[ $DISTRO == fedora ]]; then
    $SUDO dnf install -y git gh curl wget unzip zstd jq gcc gcc-c++ make dnf-plugins-core
  else
    $SUDO apt-get update
    $SUDO apt-get install -y git gh curl wget unzip zstd jq build-essential ca-certificates gnupg
  fi
}

install_docker() {
  if have docker; then log "Docker ja instalado"; else
    log "Docker Engine + Compose"
    if [[ $DISTRO == fedora ]]; then
      $SUDO dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
        || $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
      $SUDO install -m 0755 -d /etc/apt/keyrings
      $SUDO curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
      $SUDO chmod a+r /etc/apt/keyrings/docker.asc
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      $SUDO apt-get update
      $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
  fi
  $SUDO systemctl enable --now docker
  $SUDO usermod -aG docker "${SUDO_USER:-$USER}" && warn "Faca logout/login para usar docker sem sudo."
}

install_nvm() {
  load_nvm
  if have nvm || [[ -s "$HOME/.nvm/nvm.sh" ]]; then log "nvm ja instalado"; else
    log "nvm ${NVM_VERSION}"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    load_nvm
  fi
  log "Node LTS via nvm + corepack (pnpm/yarn)"
  nvm install --lts
  nvm alias default 'lts/*'
  corepack enable
}

install_uv() {
  have uv && { log "uv ja instalado"; return; }
  log "uv (gerenciador de Python)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_claude() {
  have claude && { log "Claude Code ja instalado"; return; }
  log "Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
}

install_gemini() {
  load_nvm
  have npm || { warn "npm nao encontrado, instalando nvm antes"; install_nvm; }
  have gemini && { log "Gemini CLI ja instalado"; return; }
  log "Gemini CLI"
  npm install -g @google/gemini-cli
}

install_ollama() {
  have ollama && { log "Ollama ja instalado"; return; }
  log "Ollama"
  curl -fsSL https://ollama.com/install.sh | sh
}

install_zed() {
  have zed && { log "Zed ja instalado"; return; }
  log "Zed"
  curl -f https://zed.dev/install.sh | sh
}

install_firefox() {
  have firefox && { log "Firefox ja instalado"; return; }
  log "Firefox"
  if [[ $DISTRO == fedora ]]; then pkg_install firefox
  else flatpak_app org.mozilla.firefox; fi
}

install_dbeaver()  { log "DBeaver";  flatpak_app io.dbeaver.DBeaverCommunity; }
install_obsidian() { log "Obsidian"; flatpak_app md.obsidian.Obsidian; }
install_obs()      { log "OBS Studio"; flatpak_app com.obsproject.Studio; }
install_vlc()      { log "VLC"; flatpak_app org.videolan.VLC; }

install_controllers() {
  log "Controles (8BitDo, GameSir): AntiMicroX, jstest-gtk, regras udev"
  flatpak_app io.github.antimicrox.antimicrox
  if [[ $DISTRO == fedora ]]; then
    pkg_install jstest-gtk game-devices-udev || warn "jstest-gtk/game-devices-udev indisponivel"
  else
    pkg_install jstest-gtk || warn "jstest-gtk indisponivel"
    pkg_install steam-devices || warn "steam-devices (multiverse) indisponivel"
  fi
  # Atualizador de firmware do 8BitDo (Ultimate Software V2) e web e usa WebHID: precisa de Chromium
  flatpak_app org.chromium.Chromium
  warn "8BitDo: firmware/mapeamento em https://app.8bitdo.com (abrir no Chromium). GameSir nao tem app Linux: use AntiMicroX ou Steam Input."
}

install_tablet() {
  log "Mesa digitalizadora Huion: libwacom (kernel ja traz o driver hid-uclogic)"
  if [[ $DISTRO == fedora ]]; then pkg_install libwacom
  else pkg_install libwacom-bin || pkg_install libwacom-common; fi
  warn "Huion: se o modelo nao for reconhecido, baixe o driver oficial em https://www.huion.com/download ou use OpenTabletDriver."
}

# ---- Execucao ----
for t in "${ALL_TOOLS[@]}"; do
  want "$t" || continue
  "install_$t" || warn "Falhou: $t (continuando)"
done

log "Pronto! Abra um novo terminal. Rode 'claude' e 'gemini' para autenticar."
