<#
  Restore Boot Menu (switch off a leftover boot menu in one click)
  Author: connectsegabot

  Purpose: after uninstalling a virtual system, if the boot menu still appears (instead of booting the original system directly),
        run the matching bat once. It will:
          1. set displaybootmenu to No (no menu, boot the default system directly)
          2. set timeout to 0 (no wait, instant boot)
        which restores the default "no menu, boot the original system directly" behaviour.

  If you configured a boot menu yourself before (a dual-boot setup, for example) and do not want it switched off,
  use the two commands below instead and set timeout to the number of seconds you want:
      bcdedit /set {bootmgr} displaybootmenu No
      bcdedit /set {bootmgr} timeout 5
#>

$ErrorActionPreference = 'Stop'
$Script:Version = '1.31'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host ''
Write-Host ("Restore Boot Menu (switch off a leftover boot menu) v{0} - author: connectsegabot" -f $Script:Version)
Write-Host '============================================'
Write-Host ''

if (-not (Test-Admin)) {
    Write-Host '[ERROR] Administrator rights are required. Right-click this script and choose "Run with PowerShell", or run the bundled bat as administrator.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Press any key to exit...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

Write-Host 'About to run:'
Write-Host '  bcdedit /set {bootmgr} displaybootmenu No   (no menu at boot)'
Write-Host '  bcdedit /set {bootmgr} timeout 0            (no wait, boot the default system directly)'
Write-Host ''
Write-Host 'Note: if this is a multi-boot machine (another Windows, Linux or WinPE entry exists),' -ForegroundColor Yellow
Write-Host '      the menu is gone and you can no longer choose a system. To restore it, run as administrator:' -ForegroundColor Yellow
Write-Host '          bcdedit /set {bootmgr} displaybootmenu Yes' -ForegroundColor Yellow
Write-Host '          bcdedit /set {bootmgr} timeout 10' -ForegroundColor Yellow
Write-Host ''
$ans = Read-Host 'Continue? Type y and press Enter to confirm, or just press Enter to cancel'
if ($ans -ne 'y' -and $ans -ne 'Y') {
    Write-Host ''
    Write-Host 'Cancelled, nothing was changed.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Press any key to exit...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 0
}

Write-Host ''
Write-Host 'Switching the boot menu off...'
$r1 = & bcdedit /set '{bootmgr}' displaybootmenu No 2>&1 | Out-String
Write-Host ("  displaybootmenu No  =>  {0}" -f ($r1 -replace '\s+', ' ').Trim())

$r2 = & bcdedit /set '{bootmgr}' timeout 0 2>&1 | Out-String
Write-Host ("  timeout 0           =>  {0}" -f ($r2 -replace '\s+', ' ').Trim())

Write-Host ''
Write-Host 'Done. The machine now boots the default system directly without a menu.' -ForegroundColor Green
Write-Host ''
Write-Host 'Press any key to exit...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
