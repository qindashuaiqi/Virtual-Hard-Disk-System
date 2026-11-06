#requires -Version 5.1
# ============================================================
# 清理安装残留  v1.3
# 作者: connectsegabot
#
# 用途：安装过程卡死 / 中途关掉窗口后，机器上会留下
#   1) 一个还没结束的 dism.exe（一直占着 vhdx 文件）
#   2) 一块挂着的虚拟磁盘（占着盘符，比如 E:）
#   3) 一个半成品 vhdx（旧版固定叫 NewSystemDisk.vhdx，现在可以是任意名字）
# 本脚本按顺序清掉它们，让「双击我-装系统.bat」可以干净地重跑。
#
# 第 3 步只处理「没有启动项」的 vhdx，而且分三类：
#   A 装好、启动项还在      → 一律不碰（删它请用「双击我-卸载新系统.bat」）
#   B 本程序装过、条目没了  → 有 .boot.txt 为证，输入 y 即删
#   C 不是本程序创建的      → 可能是 Hyper-V / 别的工具 / 你自己的备份，
#                             默认绝不删，要删得照着输文件名
# ============================================================

param(
    [string]$OriginDir = ''
)

$ErrorActionPreference = 'Continue'
$Script:Version = '1.32'
$Script:OriginDir = $OriginDir

try { $Host.UI.RawUI.WindowTitle = "清理安装残留 v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] 共享模块。打包时由 src/build/inline_shared.py 内联本文件，
# .bat 载荷仍是自包含单文件。
. "$PSScriptRoot\..\shared\zh-CN\Logging.ps1"

Say ""
Say "  清理安装残留  v$($Script:Version)" 'Cyan'
Say "  作者: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [错误] 需要管理员权限。请关掉本窗口，右键本文件 -> 以管理员身份运行。" 'Red'
    Say ""
    Read-Host "  按回车退出"
    exit 1
}

# ---------- 1. 结束残留的 dism ----------
#
# [审计 P3-16] 以前无条件把机器上所有 dism.exe / DismHost 全杀掉。
# 用户自己正在跑 DISM /RestoreHealth 也会被中途打断。卡住的 DismHost 确实该清（正是它挡住重装），
# 但先让用户看清楚在跑什么，再自己决定。
Say "[1/3] 查找残留的 dism.exe ..."
$disms = @(Get-Process -Name dism, DismHost -ErrorAction SilentlyContinue)
$killed = 0
if ($disms.Count -eq 0) {
    Say "      没有在跑的" 'DarkGray'
} else {
    Say ("      找到 {0} 个进程：{1}" -f $disms.Count, (($disms | ForEach-Object { "$($_.ProcessName)(PID $($_.Id))" }) -join '、')) 'Yellow'
    Say "      结束它们也会打断你自己开的 DISM 任务（例如 /RestoreHealth）。" 'DarkGray'
    $ans = Read-Host "      要结束吗？[y/N]"
    if ($ans -match '^(?i)y(es)?$') {
        foreach ($p in $disms) {
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                $killed++
                Say ("      已结束 {0} (PID {1})" -f $p.ProcessName, $p.Id) 'DarkGray'
            } catch {
                Say ("      结束 {0} (PID {1}) 失败：{2}" -f $p.ProcessName, $p.Id, $_.Exception.Message) 'Yellow'
            }
        }
    } else {
        Say "      已跳过" 'DarkGray'
    }
}
Start-Sleep -Milliseconds 800

# ---------- 2. 卸载虚拟磁盘 ----------
#
# [审计 P3-16] 同一个毛病：所有文件型虚拟盘一律卸载，包括 Hyper-V 的虚拟机盘、
# 或者用户正在用的 VHD。卸载本身不丢数据，但会把别人正在做的事打断。
# 改成一块一块问，不点头就不动。
Say "[2/3] 挂载中的虚拟磁盘 ..."
$vds = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { [string]$_.BusType -eq 'File Backed Virtual' })
if ($vds.Count -eq 0) {
    Say "      没有挂着的虚拟磁盘" 'DarkGray'
} else {
    foreach ($d in $vds) {
        $loc = [string]$d.Location
        Say ("      Disk {0}: {1}" -f $d.Number, $loc) 'DarkGray'
        if (-not $loc) { continue }
        $ans = Read-Host "      要卸载这一块吗？[y/N]"
        if ($ans -notmatch '^(?i)y(es)?$') { Say "      保持挂载" 'DarkGray'; continue }
        $dpFile = Join-Path $env:TEMP ("detach_{0}.txt" -f $d.Number)
        @(
            "select vdisk file=`"$loc`"",
            'detach vdisk noerr',
            'exit'
        ) | Set-Content -LiteralPath $dpFile -Encoding Default
        $r = & diskpart /s $dpFile 2>&1 | Out-String
        Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
        if ($r -match 'successfully|成功') { Say "      已卸载" 'Green' }
        else { Say ("      卸载结果：" + ($r -replace "\s+", ' ').Trim()) 'Yellow' }
    }
}
Start-Sleep -Milliseconds 800

# ---------- 3. 处理没有启动项的 vhdx ----------
# v1.0 只认写死的 NewSystemDisk.vhdx。安装器从 v1.11 起允许自定义名字和目录，
# 装到 E:\VHD\maimai.vhdx 时卡死的话，这里根本扫不到，那 20GB 就一直占着盘。
#
# 但「没有启动项」不等于「是本工具的垃圾」。Hyper-V 的虚拟磁盘、别的装机工具、
# 你自己手动放的 vhdx，同样没有 .boot.txt。v1.1 把它们一律列出来问「要删吗」，
# 配的还是一句「删了能腾出 20GB」—— 这是在鼓励用户按 y 删掉别人的东西，
# 「直接回车跳过」只是运气好，不是设计。
#
# v1.2 起分三类处理，见文件头。
Say "[3/3] 检查没有启动项的虚拟磁盘 ..."

# 全盘扫 *.vhdx：只按目录名剪枝，不进系统目录/回收站
# >>> COMMON:Get-AllVhdxFile
# 由 _源码\_build\sync_common.py 从 common\Get-AllVhdxFile.ps1 注入。改这里没用，改完会被覆盖。
function Get-AllVhdxFile {
    param([int]$MaxDepth = 6)
    # 只按目录名剪枝，不进系统目录/回收站/依赖缓存，所以深度开到 6 也不慢。
    # 用 .NET 的目录枚举而不是 Get-ChildItem：后者每层都要生成 PSObject，
    # 实测同一棵树 1074 ms vs 83 ms，差 12 倍（窗口每次刷新都要扫一遍，差别很明显）。
    $skip = @('$RECYCLE.BIN', 'System Volume Information', 'Windows', 'Program Files',
              'Program Files (x86)', 'ProgramData', 'Users', '$WinREAgent', 'Recovery',
              'node_modules', '.git', 'WinSxS')
    $found = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        if ($v.FileSystem -ne 'NTFS') { continue }
        if ($v.DriveType -ne 'Fixed') { continue }
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@("$($v.DriveLetter):\", 0))
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            $dir = [string]$cur[0]
            $d = [int]$cur[1]
            try {
                foreach ($f in [System.IO.Directory]::GetFiles($dir, '*.vhdx')) {
                    [void]$found.Add((New-Object System.IO.FileInfo $f))
                }
            } catch {}
            if ($d -ge $MaxDepth) { continue }
            try {
                foreach ($sub in [System.IO.Directory]::EnumerateDirectories($dir)) {
                    if ($skip -contains [System.IO.Path]::GetFileName($sub)) { continue }
                    try {
                        if ([System.IO.File]::GetAttributes($sub) -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                    } catch { continue }
                    $queue.Enqueue(@($sub, ($d + 1)))
                }
            } catch {}
        }
    }
    return $found.ToArray()
}
# <<< COMMON:Get-AllVhdxFile

function Get-VhdStateGuid {
    param([string]$Path)
    $st = [System.IO.Path]::ChangeExtension($Path, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { return '' }
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\s*Guid\s*=\s*(\{[0-9a-fA-F-]{36}\})\s*$') { return $matches[1] }
    }
    return ''
}

# BCD 里还有没有这条启动项（不判断指向对不对，只看存在）
function Test-BcdEntryPresent {
    param([string]$Guid)
    if (-not $Guid) { return $false }
    $txt = ''
    try { $txt = (& bcdedit /enum $Guid 2>&1 | Out-String) } catch { return $false }
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($txt -match '找不到|not found|无效|invalid|拒绝|denied') { return $false }
    return ($txt -match '(?i)identifier|标识符')
}

# 删 vhdx 的同时把旁边的 .boot.txt 一起清掉。
# 只删 vhdx 的话，下次扫描会把这具空壳重新归到 B 类再问一遍；
# 而且留着 .boot.txt 指向一个已经不存在的 vhdx，对别的工具也是误导。
function Remove-VhdSafely {
    param($Item)
    try {
        Remove-Item -LiteralPath $Item.Path -Force -ErrorAction Stop
        Say "             已删除" 'Green'
        $st = [System.IO.Path]::ChangeExtension($Item.Path, '.boot.txt')
        if (Test-Path -LiteralPath $st) {
            Remove-Item -LiteralPath $st -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Say ("             删除失败：" + $_.Exception.Message) 'Red'
        Say "             通常是还有进程占着它 —— 重启电脑后再跑一次本工具即可。" 'Yellow'
    }
}

$catA = New-Object System.Collections.ArrayList   # 装好的（有条目）
$catB = New-Object System.Collections.ArrayList   # 本工具装过、条目没了
$catC = New-Object System.Collections.ArrayList   # 不是本程序创建的

foreach ($f in @(Get-AllVhdxFile)) {
    $sz = 0
    try { $sz = [math]::Round($f.Length / 1GB, 2) } catch {}
    $st = [System.IO.Path]::ChangeExtension($f.FullName, '.boot.txt')
    $hasState = Test-Path -LiteralPath $st
    $guid = ''
    if ($hasState) { $guid = Get-VhdStateGuid -Path $f.FullName }
    $item = [PSCustomObject]@{ Path = $f.FullName; SizeGB = $sz; HasState = $hasState }
    if (Test-BcdEntryPresent -Guid $guid) {
        [void]$catA.Add($item)
    } elseif ($hasState) {
        [void]$catB.Add($item)
    } else {
        [void]$catC.Add($item)
    }
}

if ($catA.Count -gt 0) {
    Say "      下面这些已经装好、启动项还在，本工具一律不碰：" 'DarkGray'
    foreach ($it in $catA) {
        Say (('        {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'DarkGray'
    }
    Say "      （要删它们请用「双击我-卸载新系统.bat」，会连开机菜单一起清）" 'DarkGray'
}

if (($catB.Count + $catC.Count) -eq 0) {
    Say "      没有需要处理的虚拟磁盘，环境已经是干净的" 'DarkGray'
} else {
    if ($catB.Count -gt 0) {
        Say ""
        Say ("      【B】本工具装过、但启动项已经没了（{0} 个）" -f $catB.Count) 'White'
        Say "          旁边有本工具留下的 .boot.txt，删掉不会影响任何能启动的系统。" 'DarkGray'
        foreach ($it in $catB) {
            Say (('          {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'White'
            $ans = Read-Host "             删除吗？输入 y 删除，直接回车跳过"
            if ($ans -and ($ans.Trim() -ieq 'y')) {
                Remove-VhdSafely -Item $it
            } else {
                Say "             已跳过" 'DarkGray'
            }
        }
    }
    if ($catC.Count -gt 0) {
        Say ""
        Say ("      【C】不是本程序创建的（{0} 个）" -f $catC.Count) 'White'
        Say "          没有本程序留下的 .boot.txt。可能是 Hyper-V 虚拟磁盘、别的装机" 'DarkGray'
        Say "          工具，或者你自己放的备份。默认不删，也不建议删。" 'DarkGray'
        foreach ($it in $catC) {
            $fn = [System.IO.Path]::GetFileName($it.Path)
            Say (('          {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'White'
            $ans = Read-Host ("             确实要删就输入文件名 {0}（直接回车跳过）" -f $fn)
            if (-not $ans) {
                Say "             已跳过" 'DarkGray'
            } elseif ($ans.Trim() -ieq $fn) {
                Remove-VhdSafely -Item $it
            } else {
                # 别用黄字说「文件名不对」—— 很多人会先试 y / yes，其实他是真想删，
                # 只是不知道这一栏要的不是 y。这里只平静地说清楚「怎么删」，不判错。
                Say ("             已跳过。要删这一个，请输入完整文件名：{0}" -f $fn) 'DarkGray'
                if ($ans.Trim() -imatch '^(y|yes|是|删|删除|ok)$') {
                    Say "             （这一栏特意不收 y —— 它防的是手滑删掉别人的虚拟磁盘）" 'DarkGray'
                }
            }
        }
    }
}

# ---------- 第 4 步（v1.29）：清 bcdedit 导出 BCD 时留下的伴生日志 ----------
#
# bcdedit /export 导出的是一个注册表 hive，Windows 会顺手在目标旁边生成
#   xxx.bcd.LOG  xxx.bcd.LOG1  xxx.bcd.LOG2
# 真机实测：D:\ 根上攒了 31 个 .bcd.LOG*，D:\虚拟磁盘\ 里还有 18 个。
# 注意这几个伴生文件带 Hidden + System 属性，Get-ChildItem 必须加 -Force，
# 否则一个都扫不到（v1.29 就是漏了这个，功能静默失效）。
# 这些是导出过程的中间文件，对恢复 BCD 没有任何用处，删掉不影响 .bcd 备份本身。
# v1.29 起安装器/修复工具改成「先导到临时目录再拷贝」，以后不会再产生；
# 这一节是给已经攒下来的那些收尾。
$strayLogs = New-Object System.Collections.ArrayList
#
# 【v1.31 安全加固】以前是拿 '*.bcd.LOG*' 通配去扫 6 个盘的根 + 一级子目录，然后
# 一把 Remove-Item。实测确实没删到过系统文件 —— 但那是靠 -Filter 的 8.3 短名匹配
# 怪癖碰巧不匹配「BCD.LOG」，不是代码里有防护。而 C:\Boot\BCD.LOG / BCD.LOG1 /
# BCD.LOG2 是**活动 BCD 的事务日志**，名字只差两个字母，换个写法或换台机器就可能
# 命中，删掉有损坏启动配置的风险。
#
# 现在改成白名单：只认本程序历代导出的那种固定格式，别的一律不碰。
#   bcd-backup-<yyyyMMdd>-<HHmmss>.bcd.LOG / .LOG1 / .LOG2
#   bcd-backup-fix-<yyyyMMdd>-<HHmmss>.bcd.LOG ...
#   bcd-rescue-<yyyyMMdd>-<HHmmss>.bcd.LOG ...   （早期版本用过这个前缀）
# 关键点：必须以 bcd- 开头、中间带 8 位日期 + 6 位时间、扩展名是 .bcd。
# 系统自己的 C:\Boot\BCD.LOG 三个名字没有一样能对上，所以结构上不可能被选中。
# 目录层面再排除一遍系统目录，双保险。
$isStrayBcdLog = {
    param([string]$n)
    return ($n -match '^bcd-[a-z]+(?:-[a-z]+)*-\d{8}-\d{6}\.bcd\.LOG[0-9]?$')
}
$skipSubDirs = '^(Windows|Program Files.*|\$Recycle\.Bin|System Volume Information|Users|Boot|Recovery|EFI|PerfLogs)$'
foreach ($rt in @('C:\', 'D:\', 'E:\', 'F:\', 'G:\', 'H:\')) {
    if (-not (Test-Path -LiteralPath $rt)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $rt -File -Force -EA SilentlyContinue)) {
        if (& $isStrayBcdLog $f.Name) { [void]$strayLogs.Add($f) }
    }
    foreach ($d in @(Get-ChildItem -LiteralPath $rt -Directory -Force -EA SilentlyContinue)) {
        if ($d.Name -match $skipSubDirs) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $d.FullName -File -Force -EA SilentlyContinue)) {
            if (& $isStrayBcdLog $f.Name) { [void]$strayLogs.Add($f) }
        }
    }
}

if ($strayLogs.Count -gt 0) {
    $sz = ($strayLogs | Measure-Object -Property Length -Sum).Sum
    Say ""
    Say ("      【附】bcdedit 导出 BCD 时留下的伴生日志（{0} 个，共 {1:N1} MB）" -f $strayLogs.Count, ($sz / 1MB)) 'White'
    Say "          就是 bcd-backup-*.bcd 旁边的 .LOG / .LOG1 / .LOG2。" 'DarkGray'
    Say "          它们是导出过程中的中间文件，删掉不影响 .bcd 备份本身，也不影响开机。" 'DarkGray'
    Say "          只认本程序导出的备份名；系统自己的 C:\Boot\BCD.LOG 不在范围内，绝不会动。" 'DarkGray'
    foreach ($f in @($strayLogs | Sort-Object FullName | Select-Object -First 8)) {
        Say ("          " + $f.FullName) 'DarkGray'
    }
    if ($strayLogs.Count -gt 8) { Say ("          …… 还有 {0} 个" -f ($strayLogs.Count - 8)) 'DarkGray' }
    $ans = Read-Host "             全部删除吗？输入 y 删除，直接回车跳过"
    if ($ans -and ($ans.Trim() -ieq 'y')) {
        $okN = 0
        foreach ($f in $strayLogs) {
            try { Remove-Item -LiteralPath $f.FullName -Force -EA Stop; $okN++ } catch {}
        }
        Say ("             已删除 {0} / {1} 个" -f $okN, $strayLogs.Count) 'Green'
        if ($okN -lt $strayLogs.Count) { Say "             删不掉的通常是被别的程序占着，重启后再跑一次即可" 'DarkGray' }
    } else {
        Say "             已跳过（一个都没删）" 'DarkGray'
    }
}

Say ""
Say "  ------------------------------------------------------------" 'DarkGray'
Say "  清理完成。" 'Green'
Say ""
Say "  重新安装的正确姿势：" 'White'
Say "    1. 重新双击「双击我-装系统.bat」" 'DarkGray'
Say "       进度条会显示已写入多少 GB，数字一直在涨就说明在工作，别急着关掉" 'DarkGray'
Say "    2. 装完重启，开机菜单里选新系统" 'DarkGray'
Say ""
Read-Host "  按回车退出"
