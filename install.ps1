<#
Setup para Windows (usa winget).
Uso:  powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Only docker,claude] [-Skip firefox] [-List]
Idempotente: pode rodar varias vezes.
#>
param(
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$List
)

$ErrorActionPreference = 'Continue'

# nome -> ids do winget
$WingetTools = [ordered]@{
  base     = @('Git.Git', 'GitHub.cli', 'jqlang.jq')
  docker   = @('Docker.DockerDesktop')
  nvm      = @('CoreyButler.NVMforWindows')
  uv       = @('astral-sh.uv')
  ollama   = @('Ollama.Ollama')
  zed      = @('ZedIndustries.Zed')
  firefox  = @('Mozilla.Firefox')
  dbeaver  = @('DBeaver.DBeaver.Community')
  obsidian = @('Obsidian.Obsidian')
  obs      = @('OBSProject.OBSStudio')
  vlc      = @('VideoLAN.VLC')
  spotify  = @('Spotify.Spotify')
  controllers = @('8BitDo.UltimateSoftwareV2','GameSir.GameSirConnect','AntiMicroX.antimicrox')
}
$All = @('base','docker','nvm','uv','claude','gemini','ollama','zed','firefox','dbeaver','obsidian','obs','vlc','spotify','controllers','tablet')

if ($List) { $All; return }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget nao encontrado. Instale o 'App Installer' pela Microsoft Store."; exit 1
}

function Want($t) {
  if ($Only.Count -gt 0 -and $Only -notcontains $t) { return $false }
  if ($Skip -contains $t) { return $false }
  return $true
}

function Install-Winget($id) {
  $installed = winget list --id $id -e --accept-source-agreements 2>$null | Select-String ([regex]::Escape($id))
  if ($installed) { Write-Host "  ja instalado: $id" -ForegroundColor DarkGray; return }
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
}

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path','User')
  # NVM for Windows define estas variaveis
  foreach ($v in 'NVM_HOME','NVM_SYMLINK') {
    $val = [Environment]::GetEnvironmentVariable($v,'Machine'); if (-not $val) { $val = [Environment]::GetEnvironmentVariable($v,'User') }
    if ($val) { Set-Item "env:$v" $val }
  }
}

function Ensure-Node {
  Refresh-Path
  if (Get-Command npm -ErrorAction SilentlyContinue) { return }
  Install-Winget 'CoreyButler.NVMforWindows'; Refresh-Path
  if (Get-Command nvm -ErrorAction SilentlyContinue) {
    nvm install lts
    nvm use lts
    Refresh-Path
    try { corepack enable } catch { Write-Host '  corepack enable precisa de terminal admin (opcional)' -ForegroundColor Yellow }
  } else {
    Write-Host '  Reabra o terminal e rode de novo para concluir o Node via nvm.' -ForegroundColor Yellow
  }
}

foreach ($t in $All) {
  if (-not (Want $t)) { continue }
  Write-Host "`n==> $t" -ForegroundColor Cyan
  switch ($t) {
    'nvm' { Ensure-Node }
    'tablet' {
      Write-Host '  Huion nao esta no winget. Baixe o driver oficial: https://www.huion.com/download' -ForegroundColor Yellow
      Write-Host '  (alternativa: winget install OpenTabletDriver.OpenTabletDriver, nao usar junto com o driver Huion)'
    }
    'claude' {
      if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Host '  ja instalado'; break }
      irm https://claude.ai/install.ps1 | iex
    }
    'gemini' {
      Ensure-Node
      if (Get-Command gemini -ErrorAction SilentlyContinue) { Write-Host '  ja instalado'; break }
      if (Get-Command npm -ErrorAction SilentlyContinue) { npm install -g '@google/gemini-cli' }
      else { Write-Host '  npm indisponivel nesta sessao; reabra o terminal e rode -Only gemini' -ForegroundColor Yellow }
    }
    default { foreach ($id in $WingetTools[$t]) { Install-Winget $id } }
  }
}

Write-Host "`nPronto! Reabra o terminal. Docker Desktop pode pedir reinicio/WSL2." -ForegroundColor Green
Write-Host "Rode 'claude' e 'gemini' para autenticar."
