<#
Backup para migracao Windows -> Fedora.
Copia configs, chaves, repositorios e listas de pacotes para uma pasta/HD externo.
Uso:  .\backup.ps1 -Dest E:\ [-Extra 'C:\caminho\vault-obsidian','D:\outra'] [-SkipOllama]
Nao apaga nem altera nada na origem. Credenciais de login (Claude/Gemini) NAO sao copiadas: refaca o login.
ATENCAO: a pasta de destino contera sua chave SSH privada. Guarde em local seguro.
#>
param(
  [Parameter(Mandatory)][string]$Dest,
  [string[]]$Extra = @(),
  [switch]$SkipOllama
)

$ErrorActionPreference = 'Continue'
$H   = $env:USERPROFILE
$Out = Join-Path $Dest "setup-backup-$(Get-Date -Format yyyyMMdd)"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Write-Host "Destino: $Out" -ForegroundColor Cyan

function Copy-Dir($src, $name, [string[]]$xd = @(), [string[]]$xf = @()) {
  if (-not (Test-Path $src)) { Write-Host "  (nao existe) $src" -ForegroundColor DarkGray; return }
  Write-Host "  $src -> $name"
  $rc = @($src, (Join-Path $Out $name), '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
  if ($xd) { $rc += '/XD'; $rc += $xd }
  if ($xf) { $rc += '/XF'; $rc += $xf }
  robocopy @args | Out-Null
}
function Copy-File($src, $name) {
  if (Test-Path $src) { Write-Host "  $src -> $name"; Copy-Item $src (Join-Path $Out $name) -Force }
}

Write-Host "`n[1/4] Arquivos pessoais" -ForegroundColor Cyan
Copy-Dir "$H\.ssh"  'ssh' @() @('known_hosts.old')
Copy-File "$H\.gitconfig" 'gitconfig'
Copy-Dir "$H\.claude" 'claude' @('cache','downloads','telemetry','shell-snapshots','paste-cache','session-env','sessions','file-history','projects','backups','daemon','chrome','ide','state') @('.credentials.json','.last-cleanup','.last-update-result.json','stats-cache.json')
Copy-Dir "$H\.gemini" 'gemini' @('tmp','history') @('oauth_creds.json','google_accounts.json')
Copy-Dir "$H\.codex"  'codex'  @('.tmp','vendor_imports','sessions','log') @('auth.json')
Copy-File "$H\.aider.conf.yml" 'aider.conf.yml'
Copy-File "$H\.aider.model.settings.yml" 'aider.model.settings.yml'

Write-Host "`n[2/4] Projetos e dados" -ForegroundColor Cyan
$ex = @('node_modules','.venv','venv','__pycache__','.next','.nuxt','dist','build')
Copy-Dir "$H\agro-transparente" 'projetos\agro-transparente' $ex
Copy-Dir "$H\source\repos"      'projetos\source-repos'      $ex
Copy-Dir "$H\tools"             'tools'
Copy-Dir "$H\iot_db"            'iot_db'
Copy-Dir "$H\knime-workspace"   'knime-workspace'
Copy-Dir "$H\OneDrive\Documentos\Livros" 'Livros'
$i = 0
foreach ($e in $Extra) { $i++; Copy-Dir $e ("extra\" + $i + '-' + (Split-Path $e -Leaf)) $ex }

Write-Host "`n[3/4] Listas de pacotes" -ForegroundColor Cyan
$L = Join-Path $Out 'listas'; New-Item -ItemType Directory -Force -Path $L | Out-Null
winget list --accept-source-agreements 2>$null | Out-File (Join-Path $L 'winget-list.txt') -Encoding utf8
if (Get-Command pip -ErrorAction SilentlyContinue) { pip freeze 2>$null | Out-File (Join-Path $L 'requirements.txt') -Encoding utf8 }
if (Get-Command npm -ErrorAction SilentlyContinue) { npm ls -g --depth=0 2>$null | Out-File (Join-Path $L 'npm-global.txt') -Encoding utf8 }
if (Get-Command code -ErrorAction SilentlyContinue) { code --list-extensions 2>$null | Out-File (Join-Path $L 'vscode-extensions.txt') -Encoding utf8 }
if (Get-Command ollama -ErrorAction SilentlyContinue) {
  # so os nomes: no Fedora rode 'ollama pull' para cada um (restore.sh faz isso)
  ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ } |
    Out-File (Join-Path $L 'ollama-models.txt') -Encoding utf8
}

Write-Host "`n[4/4] Resumo" -ForegroundColor Cyan
$size = (Get-ChildItem $Out -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
"{0:N0} MB em {1}" -f $size, $Out

Write-Host "`nLembretes:" -ForegroundColor Yellow
Write-Host " - De 'git push' em todos os repositorios antes de formatar."
Write-Host " - Cofres do Obsidian, Zotero e Anytype: passe os caminhos em -Extra."
Write-Host " - Modelos do Ollama nao foram copiados (so a lista); baixe de novo no Fedora."
Write-Host " - Pasta contem chave SSH privada: nao suba para nuvem nem repositorio."
