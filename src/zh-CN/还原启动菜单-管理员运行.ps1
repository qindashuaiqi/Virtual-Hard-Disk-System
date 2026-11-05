<#
  还原启动菜单（一键关闭残留的开机菜单）
  作者：connectsegabot

  用途：卸载新系统后，如果开机菜单还在（没直接进原系统），
        双击对应的 bat 跑一次即可。它会：
          1. 把 displaybootmenu 设为 No（关掉菜单，直接进默认系统）
          2. 把 timeout 设为 0（不等，秒进）
        这样开机就恢复到「不显示菜单、直接进原系统」的默认状态。

  如果你之前自己配过开机菜单（比如双系统），不想完全关掉，
  请改用下面两句手动命令，把 timeout 换成你要的秒数：
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
Write-Host ("还原启动菜单（关闭残留的开机菜单） v{0} - 作者：connectsegabot" -f $Script:Version)
Write-Host '============================================'
Write-Host ''

if (-not (Test-Admin)) {
    Write-Host '[错误] 需要管理员权限。请右键本脚本，选择「使用 PowerShell 运行」，或通过附带的 bat 以管理员身份运行。' -ForegroundColor Red
    Write-Host ''
    Write-Host '按任意键退出...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

Write-Host '即将执行：'
Write-Host '  bcdedit /set {bootmgr} displaybootmenu No   （开机不再显示菜单）'
Write-Host '  bcdedit /set {bootmgr} timeout 0            （不等待，直接进默认系统）'
Write-Host ''
Write-Host '注意：如果你是多系统用户（机器上还有另一个 Windows、Linux 或 WinPE 启动项），' -ForegroundColor Yellow
Write-Host '      菜单关掉后开机就没法选系统了。要恢复请在管理员命令行执行：' -ForegroundColor Yellow
Write-Host '          bcdedit /set {bootmgr} displaybootmenu Yes' -ForegroundColor Yellow
Write-Host '          bcdedit /set {bootmgr} timeout 10' -ForegroundColor Yellow
Write-Host ''
$ans = Read-Host '确定继续？输入 y 再回车确认，直接回车取消'
if ($ans -ne 'y' -and $ans -ne 'Y') {
    Write-Host ''
    Write-Host '已取消，没有做任何修改。' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '按任意键退出...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 0
}

Write-Host ''
Write-Host '正在关闭开机菜单...'
$r1 = & bcdedit /set '{bootmgr}' displaybootmenu No 2>&1 | Out-String
Write-Host ("  displaybootmenu No  =>  {0}" -f ($r1 -replace '\s+', ' ').Trim())

$r2 = & bcdedit /set '{bootmgr}' timeout 0 2>&1 | Out-String
Write-Host ("  timeout 0           =>  {0}" -f ($r2 -replace '\s+', ' ').Trim())

Write-Host ''
Write-Host '完成。现在开机会直接进默认系统，不再显示菜单。' -ForegroundColor Green
Write-Host ''
Write-Host '按任意键退出...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
