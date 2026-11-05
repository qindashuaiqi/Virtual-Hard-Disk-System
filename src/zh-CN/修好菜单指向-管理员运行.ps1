<#
  修好启动菜单指向（虚拟硬盘系统）
  作者：connectsegabot

  用途：装好虚拟系统后，开机菜单里可能
    · 有这一项，但一选就报 0xc000000f / 找不到文件
    · 或者压根没这一项
  原因是菜单条目指向的 .vhdx 路径不对（或没进显示顺序）。本工具会：

    1. 找出本工具装过的所有虚拟系统（有 xxx.boot.txt 的那些）
    2. 核对开机菜单里对应条目指向的路径，跟真实文件路径逐字比对
    3. 不对就改回来；条目丢了就按记录补一条；没进菜单就加回去

  不动虚拟磁盘里的系统内容，不动原系统。
#>

$ErrorActionPreference = 'Stop'
$Script:Version = '1.31'
$Script:LogFile = Join-Path $env:TEMP ("修好菜单指向-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Msg
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 } catch {}
    $c = 'Gray'
    if ($Level -eq 'OK') { $c = 'Green' }
    if ($Level -eq 'WARN') { $c = 'Yellow' }
    if ($Level -eq 'ERR') { $c = 'Red' }
    Write-Host $line -ForegroundColor $c
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Bcd {
    param([string[]]$BcdArgs, [string]$Tag = '')
    $txt = ''
    try { $txt = (& bcdedit @BcdArgs 2>&1 | Out-String) } catch { $txt = "调用异常: $($_.Exception.Message)" }
    $code = $LASTEXITCODE
    $clean = ($txt -replace '\s+', ' ').Trim()
    Write-Log ("bcdedit {0} [{1}] => exit={2}  {3}" -f $Tag, ($BcdArgs -join ' '), $code, $clean)
    $bad = ($txt -match '找不到|not found|无效|invalid|拒绝|denied|失败|failed|错误|error')
    return @{ Ok = (($code -eq 0) -and (-not $bad)); Code = $code; Text = $clean; Raw = $txt }
}

# bcdedit 的输出走控制台代码页，打不出来的字会变成 "?"。英文启动器开头是 chcp 437，
# 中文路径于是整个变成 "?"，写对了也被判成写错。
function Test-BcdTextSame {
    param([string]$Want, [string]$Got)
    if ($null -eq $Got) { return $false }
    if ($Got -eq $Want) { return $true }
    if ($Got.Length -ne $Want.Length) { return $false }
    for ($i = 0; $i -lt $Want.Length; $i++) {
        if ($Got[$i] -eq $Want[$i]) { continue }
        if ($Got[$i] -eq '?' -and [int][char]$Want[$i] -gt 127) { continue }
        return $false
    }
    return $true
}

# 完整路径 -> BCD 的 vhd= 写法。必须保留中间子目录：
#   D:\虚拟磁盘\maimai.vhdx  ->  vhd=[D:]\虚拟磁盘\maimai.vhdx
function Get-VhdBcdDevice {
    param([string]$FullPath)
    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetPathRoot($full)
    if (-not $root -or $root.Length -lt 3) { throw "路径无效：$FullPath" }
    $letter = $root.Substring(0, 1).ToUpper()
    $rel = $full.Substring($root.Length).TrimStart('\')
    if (-not $rel) { throw "路径无效：$FullPath" }
    return "vhd=[$($letter):]\$rel"
}

# 反向解析，用来跟真实路径逐字比对
function Get-FullPathFromBcdDevice {
    param([string]$Dev)
    if (-not $Dev) { return '' }
    $m = [regex]::Match($Dev, '^vhd=\[([A-Za-z]):\]\\(.+)$')
    if (-not $m.Success) { return '' }
    return ("{0}:\{1}" -f $m.Groups[1].Value.ToUpper(), $m.Groups[2].Value)
}

# 扫所有固定 NTFS 盘里的 vhdx。广度优先 + 按目录名剪枝，
# 不进 Windows / Users / 回收站，所以深度开到 6 也不慢。
function Get-AllVhdxFile {
    param([int]$MaxDepth = 6)
    $skip = @('$RECYCLE.BIN', 'System Volume Information', 'Windows', 'Program Files',
              'Program Files (x86)', 'ProgramData', 'Users', '$WinREAgent', 'Recovery',
              'node_modules', '.git', 'WinSxS')
    $found = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-Volume -EA SilentlyContinue)) {
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

Write-Host ''
Write-Host '修好启动菜单指向 - 作者：connectsegabot'
Write-Host '======================================'
Write-Host ''

if (-not (Test-Admin)) {
    Write-Host '需要管理员权限。' -ForegroundColor Red
    Write-Host '请关掉这个窗口，直接双击「修好菜单指向-管理员运行.bat」，它会自己申请权限。'
    Write-Host ''
    Write-Host '按任意键退出...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

Write-Log "日志: $($Script:LogFile)"

# ---------- 先备份活动 BCD ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bk = Join-Path $env:TEMP "bcd-backup-$stamp.bcd"
$rb = Invoke-Bcd -BcdArgs @('/export', $bk) -Tag 'export'
if ($rb.Ok -and (Test-Path -LiteralPath $bk)) {
    Write-Log "BCD 已备份: $bk" 'OK'
} else {
    Write-Log 'BCD 备份失败，继续（下面只改设备路径和菜单顺序，风险很低）' 'WARN'
}

# ---------- 找目标 ----------
Write-Host ''
Write-Host '正在查找装好的虚拟系统...'
$items = New-Object System.Collections.ArrayList
foreach ($f in @(Get-AllVhdxFile)) {
    $st = [System.IO.Path]::ChangeExtension($f.FullName, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { continue }
    $sd = @{}
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -EA SilentlyContinue)) {
        if ($ln -match '^\s*([^#=]+)=(.*)$') { $sd[$matches[1].Trim()] = $matches[2].Trim() }
    }
    $g = [string]$sd['Guid']
    if ($g -notmatch '^\{[0-9a-fA-F-]{36}\}$') { continue }
    [void]$items.Add([PSCustomObject]@{
        Path  = $f.FullName
        Guid  = $g
        Name  = [string]$sd['Name']
        Desc  = [string]$sd['Desc']
        State = $st
    })
}

if ($items.Count -eq 0) {
    Write-Host ''
    Write-Host '没找到本工具装过的虚拟系统。' -ForegroundColor Yellow
    Write-Host '（需要虚拟磁盘旁边有安装时写的 xxx.boot.txt）'
    Write-Host ''
    Write-Host '如果确实装过，可以用「修复启动菜单-管理员运行.bat」重建一个启动项。'
    Write-Host ''
    Write-Host '按任意键退出...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

Write-Host ("找到 {0} 个：" -f $items.Count)
foreach ($x in $items) { Write-Host ("    {0}" -f $x.Path) }

# ---------- 逐个核对 ----------
$fixedCount = 0
$okCount = 0
$failCount = 0

foreach ($it in $items) {
    Write-Host ''
    Write-Host ("· {0}" -f $it.Path) -ForegroundColor Cyan

    $wantDev = ''
    try { $wantDev = Get-VhdBcdDevice $it.Path }
    catch { Write-Log "路径无效: $($_.Exception.Message)" 'ERR'; $failCount++; continue }
    $wantFull = [System.IO.Path]::GetFullPath($it.Path)

    $en = Invoke-Bcd -BcdArgs @('/enum', $it.Guid) -Tag 'enum'
    $guid = $it.Guid

    # 条目不存在 → 补一条
    if (-not $en.Ok) {
        Write-Log "菜单里没有这个条目（$guid），补一条" 'WARN'
        $desc = $it.Desc
        if (-not $desc) { $desc = $it.Name }
        if (-not $desc) { $desc = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }

        $cp = Invoke-Bcd -BcdArgs @('/copy', '{current}', '/d', $desc) -Tag 'copy'
        if (-not $cp.Ok) { $cp = Invoke-Bcd -BcdArgs @('/copy', '{default}', '/d', $desc) -Tag 'copy-default' }
        $gm = [regex]::Match($cp.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if (-not $gm.Success) {
            Write-Log "补条目失败：$($cp.Text)" 'ERR'
            $failCount++
            continue
        }
        $guid = $gm.Value
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'device',   $wantDev) -Tag 'set-device')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'osdevice', $wantDev) -Tag 'set-osdevice')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'path', '\Windows\system32\winload.efi') -Tag 'set-path')

        # 状态文件里的 GUID 换成新的，卸载时才找得到
        try {
            $txt = [System.IO.File]::ReadAllText($it.State, [System.Text.Encoding]::UTF8)
            $txt = [regex]::Replace($txt, '(?m)^Guid=.*', "Guid=$guid")
            [System.IO.File]::WriteAllText($it.State, $txt, (New-Object System.Text.UTF8Encoding($true)))
            Write-Log "状态文件已更新为新 GUID" 'OK'
        } catch { Write-Log "写状态文件失败（不影响开机）：$($_.Exception.Message)" 'WARN' }

        $en = Invoke-Bcd -BcdArgs @('/enum', $guid) -Tag 'verify'
        $fixedCount++
    }

    # 核对 device 指向的路径
    # 不依赖字段名（德语 Gerät、日语 デバイス、中文 设备）：带 vhd= 的只有 device 那一行
    $dm = [regex]::Match($en.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    $curDev = ''
    if ($dm.Success) { $curDev = $dm.Groups[1].Value.Trim() }
    $curFull = Get-FullPathFromBcdDevice $curDev

    if (Test-BcdTextSame $wantFull $curFull) {
        Write-Log "指向正确：$curDev" 'OK'
        $okCount++
    } else {
        Write-Log ("指向不对。现在是 [{0}]，应该是 [{1}]" -f $curDev, $wantDev) 'WARN'
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'device',   $wantDev) -Tag 'fix-device')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'osdevice', $wantDev) -Tag 'fix-osdevice')
        $chk = Invoke-Bcd -BcdArgs @('/enum', $guid) -Tag 'recheck'
        $dm2 = [regex]::Match($chk.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
        $nowDev = ''
        if ($dm2.Success) { $nowDev = $dm2.Groups[1].Value.Trim() }
        $nowFull = Get-FullPathFromBcdDevice $nowDev
        if (Test-BcdTextSame $wantFull $nowFull) {
            Write-Log "已改正：$nowDev" 'OK'
            $fixedCount++
        } else {
            Write-Log ("改完还是不对，现在 [{0}]" -f $nowDev) 'ERR'
            Write-Log '如果那里是「?」而路径本来有中文，只是控制台代码页的显示问题：先 chcp 936 再 bcdedit /enum 看一眼。' 'ERR'
            Write-Log '如果确实指到别处，把虚拟磁盘挪到纯英文目录（如 D:\VHD）再重新装一次最稳。' 'ERR'
            $failCount++
            continue
        }
    }

    # 确保它进了开机菜单的显示顺序
    $bm = Invoke-Bcd -BcdArgs @('/enum', '{bootmgr}') -Tag 'bootmgr'
    $om = [regex]::Match($bm.Raw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+?)\s*$')
    $order = ''
    if ($om.Success) { $order = $om.Groups[1].Value }

    if ($order -notmatch [regex]::Escape($guid)) {
        $ad = Invoke-Bcd -BcdArgs @('/displayorder', $guid, '/addlast') -Tag 'displayorder'
        if ($ad.Ok) {
            Write-Log '已加回开机菜单（排在最后）' 'OK'
            $fixedCount++
        } else {
            Write-Log "加回显示顺序失败：$($ad.Text)" 'ERR'
            $failCount++
        }
        $bm = Invoke-Bcd -BcdArgs @('/enum', '{bootmgr}') -Tag 'bootmgr2'
        $om = [regex]::Match($bm.Raw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+?)\s*$')
        if ($om.Success) { $order = $om.Groups[1].Value }
    } else {
        Write-Log '显示顺序里有它' 'OK'
    }

    # 菜单得是打开的，否则开机直接进默认系统，看不到这些选项
    $entryCount = ([regex]::Matches($order, '\{')).Count
    if ($entryCount -ge 2) {
        $dbm = [regex]::Match($bm.Raw, '(?im)^\s*(?:displaybootmenu|显示启动菜单)\s+(\S+)')
        $tmo = [regex]::Match($bm.Raw, '(?im)^\s*timeout\s+(\d+)')
        $needMenu = $false
        if (-not $dbm.Success) { $needMenu = $true }
        elseif ($dbm.Groups[1].Value -notmatch '^(?i:yes)$') { $needMenu = $true }
        $needTimeout = ($tmo.Success -and ([int]$tmo.Groups[1].Value -eq 0))

        if ($needMenu -or $needTimeout) {
            [void](Invoke-Bcd -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu-on')
            if ($needTimeout) {
                [void](Invoke-Bcd -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout-10')
            }
            Write-Log '开机菜单已打开（不然根本看不到选项）' 'OK'
            $fixedCount++
        }
    }
}

# ---------- 结论 ----------
Write-Host ''
Write-Host '================ 结果 ================'
Write-Host ("  本来就对：{0} 个" -f $okCount)
Write-Host ("  已修好  ：{0} 处" -f $fixedCount) -ForegroundColor Green
Write-Host ("  没修好  ：{0} 个" -f $failCount) -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host ''
if ($fixedCount -gt 0) {
    Write-Host '重启电脑，开机菜单里应该就能看到并进入这些系统了。' -ForegroundColor Green
} elseif ($failCount -eq 0 -and $okCount -gt 0) {
    Write-Host '菜单指向都是对的，不用修。如果开机还是看不到菜单，'
    Write-Host '可能是固件没从这块盘的 ESP 启动，或是菜单超时太短，连按方向键试试。'
} else {
    Write-Host '有没修好的项，把下面的日志发给我看看。' -ForegroundColor Yellow
}
Write-Host ''
Write-Host ("日志：{0}" -f $Script:LogFile)
Write-Host ''
Write-Host '按任意键退出...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
