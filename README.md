# setup

Instala as ferramentas de desenvolvimento em **Fedora, Ubuntu/Debian e Windows**.
Linguagens sao instaladas por gerenciadores de versao (nvm para Node, uv para Python).

| Ferramenta | Fedora / Ubuntu | Windows |
|---|---|---|
| Base (git, gh, curl, jq, gcc, make) | dnf / apt | winget (git, gh, jq) |
| Docker + Compose | Docker Engine (repo oficial docker-ce) | Docker Desktop |
| Node.js | **nvm** + Node LTS + corepack (pnpm/yarn) | **nvm-windows** + Node LTS |
| Python | **uv** | **uv** |
| Claude Code | script oficial | script oficial |
| Gemini CLI | npm (via nvm) | npm (via nvm) |
| Ollama | script oficial | winget |
| Zed (editor, sem extensoes) | script oficial | winget |
| Firefox | dnf (Fedora) / Flatpak (Ubuntu) | winget |
| DBeaver, Obsidian, OBS Studio, VLC, Spotify | Flatpak | winget |
| Controles 8BitDo / GameSir | AntiMicroX, jstest-gtk, regras udev, Chromium (firmware 8BitDo via web) | 8BitDo Ultimate Software V2, GameSir Connect, AntiMicroX |
| Radmin VPN | sem versao Linux (ver nota) | winget |
| Mesa Huion | libwacom (driver hid-uclogic ja vem no kernel) | driver oficial (manual) |

## Uso

**Linux:**
```bash
chmod +x install.sh
./install.sh                       # tudo
./install.sh --only docker,claude  # so alguns
./install.sh --skip ollama         # tudo menos
./install.sh --list                # lista nomes
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
.\install.ps1 -Only docker,claude
.\install.ps1 -Skip ollama
```

## Notas
- Radmin VPN so existe para Windows; no Linux use uma alternativa (ZeroTier, Tailscale ou WireGuard).
- Idempotente: pula o que ja esta instalado.
- Linux: faca logout/login depois do Docker para usar sem `sudo`; abra novo terminal para o nvm/uv entrarem no PATH.
- Windows: Docker Desktop pode exigir WSL2 e reinicio; apos instalar o nvm, se o Node nao aparecer, reabra o terminal e rode de novo.
- Para adicionar ferramenta: Linux = funcao `install_xxx` + nome em `ALL_TOOLS`; Windows = entrada em `$WingetTools` + nome em `$All`.
- Deliberadamente fora: VS Code, Java, .NET, CMake, kubectl, cloudflared, pgAdmin, Insomnia, Brave.

## Migracao (backup e restore)
```powershell
# No Windows, antes de formatar (nao copia credenciais de login):
.\backup.ps1 -Dest E:\ -Extra 'C:\caminho\vault-obsidian'
```
```bash
# No Fedora, depois do install.sh:
./restore.sh /run/media/$USER/HD/setup-backup-AAAAMMDD
```
O backup contem sua chave SSH privada: nao suba para nuvem nem para repositorio. O `restore.sh` ajusta as permissoes do `~/.ssh`, guarda `.bak` do que for sobrescrito e baixa de novo os modelos do Ollama.
