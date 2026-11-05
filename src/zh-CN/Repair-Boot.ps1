#requires -Version 3.0
<#
  修复启动菜单（Repair-Boot.ps1）
  作者：connectsegabot

  解决什么问题
  ------------
  安装程序报告「安装完成」，但重启后开机菜单里根本没有新系统，直接进原系统。

  根因
  ----
  1) 原安装程序把启动文件写到了「虚拟磁盘内部的 ESP 分区」。
     UEFI 固件只会去读**物理磁盘上**的 ESP（本机是 Disk0 Part1，300MB），
     它永远不会进到 vhdx 里面去找 ESP。
     于是 bcdboot 返回 exit=0（文件确实写出来了），但实际上等于什么都没做。

  2) 更早一次（v1.3 的兜底分支）把 `/f ALL` 写到了 `C:\`：
     生成了 C:\EFI\ 和 C:\Boot\ 两个目录，UEFI 同样不认。

  Native Boot VHD 的正确结构
  -------------------------
     vhdx 里：只放一个 NTFS 分区（系统文件）
     物理 ESP：/EFI/Microsoft/Boot/BCD 里加一条，device 指向 vhdx 文件：
               bcdedit /set {新GUID} device vhd=[D:]\VHD\maimai.vhdx
               注意 [D:] 后面必须带完整子目录，不能只剩文件名（v1.12 的血案）。

  本脚本做这几件事
  --------------
    1. 挂载现有的 vhdx
    2. 如果里面有 ESP 分区 → 删掉，让它变成「单分区」（native boot 的硬性要求：
       bootmgr 只会把 vhdx 的**第一个分区**当作启动分区）
    3. 用 bcdedit 直接操作**活动 BCD 存储**（不挂载 ESP、不读写 BCD 文件）
    4. 备份活动 BCD 存储（bcdedit /export）
    5. 复制原系统的启动项 → 新增一条 vhd= 条目
    6. 打开开机菜单（displaybootmenu + timeout），否则 timeout=0 时会直接进默认系统
    7. 清理 C:\EFI、C:\Boot 两个垃圾目录
    8. 卸载 vhdx

  为什么第 3 步不用挂盘符（v1.1 修正）
  -----------------------------------
    v1.0 是给物理 ESP 挂盘符，然后把 S:\EFI\Microsoft\Boot\bcd 当普通文件复制。
    真机上直接失败：
        文件"S:\EFI\Microsoft\Boot\bcd"正由另一进程使用，因此该进程无法访问此文件
    运行中的系统本身就握着那个 BCD 的句柄，文件级访问必然被拒。
    bcdedit 不带 /store 操作的就是活动存储 —— 它本身就在物理 ESP 上，
    不需要盘符、不碰文件、不会有共享冲突。

  安全性
  ------
    * 不覆盖 ESP 上的 bootmgfw.efi（避免用旧版引导程序替换新版导致原系统起不来）
    * 不改动原有启动项，默认项仍是原系统
    * 改 BCD 前先导出备份，任一步失败自动 bcdedit /import 还原
    * 开机菜单 10 秒后自动进原系统，即便新条目有问题也不影响原系统

  用法
  ----
    Windows PowerShell（管理员）：
        powershell -ExecutionPolicy Bypass -File Repair-Boot.ps1
  或者双击同目录的「修复启动菜单-管理员运行.bat」
#>

[CmdletBinding()]
param(
    [string]$VhdPath = '',
    # 用户把 bat 放在哪个目录（由 bat 传入，因为解包后 $PSScriptRoot 指向临时目录）
    [string]$OriginDir = '',
    [switch]$ConsoleMode
)

$ErrorActionPreference = 'Stop'

$Script:Version = '1.31'
$Script:TempDir = [System.IO.Path]::GetTempPath()
if (-not $Script:TempDir) { $Script:TempDir = 'C:\Windows\Temp\' }
$Script:LogDate = (Get-Date).ToString('yyyyMMdd')
$Script:LogName = "修复启动菜单-$($Script:LogDate).log"
$Script:LogFile = Join-Path $Script:TempDir $Script:LogName
# 【v1.29】选定要修的 vhdx 之后，日志和 BCD 备份都挪到
# <vhdx 所在目录>\虚拟硬盘系统-日志\，不再散落在盘根/vhdx 旁边。
$Script:LogDir = $Script:TempDir

# 本机实测的 GPT 分区类型 GUID，比较时统一去掉花括号
$GUID_ESP   = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
$GUID_MSR   = 'e3c9e316-0b5c-4db8-817d-f92df00215ae'
$GUID_BASIC = 'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7'

# ============================================================
# 基础
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line = '[{0}] [{1}] {2}' -f $stamp, $Level, $Message
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 -EA SilentlyContinue } catch {}
    Write-Host $line
}

# 【v1.29】附属产物统一收进 <vhdx 所在目录>\虚拟硬盘系统-日志\
# 以前日志在 %TEMP%、BCD 备份直接丢在 vhdx 旁边（放在盘根就糊在根目录上），
# 而且 bcdedit /export 还会额外生成 .LOG/.LOG1/.LOG2 三个伴生文件。
function Get-SideLogDir {
    param([string]$VhdPath)
    $base = Split-Path -Parent $VhdPath
    if (-not $base) { return $Script:TempDir }
    $dir = Join-Path $base '虚拟硬盘系统-日志'
    if (-not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {}
    }
    if (Test-Path -LiteralPath $dir) { return $dir }
    return $base
}

# 把正在写的日志搬到 vhdx 旁边（只搬一次，之后原地追加）
function Set-LogDir {
    param([string]$VhdPath)
    $dir = Get-SideLogDir -VhdPath $VhdPath
    if (-not $dir -or $dir -eq $Script:TempDir) { return }
    $newFile = Join-Path $dir $Script:LogName
    if ($newFile -ieq $Script:LogFile) { return }
    try {
        if (Test-Path -LiteralPath $Script:LogFile) {
            $oldText = Get-Content -LiteralPath $Script:LogFile -Encoding UTF8 -Raw -EA SilentlyContinue
            if ($oldText) { Add-Content -LiteralPath $newFile -Value $oldText.TrimEnd() -Encoding UTF8 -EA SilentlyContinue }
            Remove-Item -LiteralPath $Script:LogFile -Force -EA SilentlyContinue
        }
    } catch {}
    $Script:LogFile = $newFile
    $Script:LogDir = $dir
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Box {
    param([string]$Text, [string]$Title = '修复启动菜单', [string]$Kind = 'Info')
    if ($ConsoleMode) {
        Write-Host ''
        Write-Host "===== $Title ====="
        Write-Host $Text
        return
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -EA Stop
        $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        if ($Kind -eq 'Error') { $icon = [System.Windows.Forms.MessageBoxIcon]::Error }
        if ($Kind -eq 'Warn')  { $icon = [System.Windows.Forms.MessageBoxIcon]::Warning }
        [void][System.Windows.Forms.MessageBox]::Show($Text, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
    } catch {
        Write-Host $Text
    }
}

# 取当前系统 ANSI 代码页的编码对象（中文系统 = GBK/936）
# 不能用 ASCII：ASCII 编码器把所有非 ASCII 字符替换成 '?'，且不抛异常。
function Get-AnsiEncoding {
    try {
        $cp = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name ACP -EA Stop).ACP
        return [System.Text.Encoding]::GetEncoding($cp)
    } catch {
        return [System.Text.Encoding]::GetEncoding(936)
    }
}

# 调 diskpart。$Lines 是命令数组，返回 @{ Ok; Text; Path; Error }
function Invoke-Diskpart {
    param([string[]]$Lines, [string]$Tag = 'dp')

    $f = Join-Path $Script:TempDir ("rb-$Tag-$(Get-Random).txt")
    $text = (@($Lines) -join "`r`n") + "`r`n"

    $enc = Get-AnsiEncoding
    try {
        [System.IO.File]::WriteAllText($f, $text, $enc)
    } catch {
        return @{ Ok = $false; Text = ''; Path = $f; Error = "写入 diskpart 脚本失败：$($_.Exception.Message)" }
    }

    $txt = ''
    try {
        $txt = (& diskpart /s $f 2>&1 | Out-String)
    } catch {
        $txt = "diskpart 调用异常：$($_.Exception.Message)"
    }
    Remove-Item -LiteralPath $f -Force -EA SilentlyContinue

    $bad = ($txt -match '遇到错误') -or ($txt -match 'encountered an error') -or
           ($txt -match 'is not a valid') -or ($txt -match '无效') -or
           ($txt -match 'failed') -or ($txt -match '失败')
    $clean = ($txt -replace '\s+', ' ').Trim()
    return @{ Ok = (-not $bad); Text = $clean; Path = $f; Error = $(if ($bad) { $clean } else { '' }) }
}

function Get-FirmwareType {
    try {
        if ($env:firmware_type -eq 'UEFI') { return 2 }
        if ($env:firmware_type -eq 'Legacy') { return 1 }
    } catch {}
    try {
        $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -EA Stop).PEFirmwareType
        if ($v -eq 2) { return 2 }
        if ($v -eq 1) { return 1 }
    } catch {}
    try {
        $p = Get-Partition -DriveLetter $env:SystemDrive.TrimEnd(':') -EA Stop
        $d = Get-Disk -Number $p.DiskNumber -EA Stop
        if ($d.PartitionStyle -eq 'GPT') { return 2 }
        if ($d.PartitionStyle -eq 'MBR') { return 1 }
    } catch {}
    return 0
}

# ============================================================
# 虚拟磁盘
# ============================================================

function Mount-Vhd {
    param([string]$Path)
    $r = Invoke-Diskpart -Tag 'at' -Lines @(
        "select vdisk file=`"$Path`"",
        'attach vdisk',
        'exit'
    )
    Write-Log "attach vdisk => $($r.Text)"
    Start-Sleep -Milliseconds 1500

    # [审计 P0-2] 先按完整路径找，再按唯一的文件名找；绝不"取第一个 Location 含这个名字的盘"。
    # 调用方会删掉返回的那块盘里的 ESP/MSR，同名不同目录的另一块盘会被毁。
    $all = @(Get-Disk -EA SilentlyContinue)
    $full = [System.IO.Path]::GetFullPath($Path)
    $leaf = [System.IO.Path]::GetFileName($full)
    $norm = {
        param($p)
        if (-not $p) { return '' }
        $s = [string]$p
        if ($s.StartsWith('\\?\')) { $s = $s.Substring(4) }
        return $s.Trim()
    }

    $exact = @($all | Where-Object {
        $l = & $norm $_.Location
        if (-not $l) { return $false }
        return [string]::Equals($l, $full, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($exact.Count -eq 1) { Write-Log "按完整路径命中 Disk$($exact[0].Number)"; return $exact[0].Number }
    if ($exact.Count -gt 1) { throw "有两块盘都声称来自同一个文件（$full），没有动任何东西。" }

    $byName = @($all | Where-Object {
        $l = & $norm $_.Location
        if (-not $l) { return $false }
        return ([System.IO.Path]::GetFileName($l) -eq $leaf)
    })
    if ($byName.Count -eq 1) { Write-Log "按文件名唯一命中 Disk$($byName[0].Number)"; return $byName[0].Number }
    if ($byName.Count -gt 1) {
        $lines = ($byName | ForEach-Object { '    磁盘 ' + $_.Number + ': ' + $_.Location }) -join "`n"
        throw ("机器上有多个挂载中的虚拟硬盘都叫 '$leaf'：`n$lines`n`n不替你挑，没有动任何东西。")
    }
    return -1
}

function Dismount-VhdSafe {
    param([string]$Path)
    if (Get-Command Dismount-VHD -EA SilentlyContinue) {
        try { Dismount-VHD -Path $Path -EA Stop; return $true } catch {}
    }
    try {
        $r = Invoke-Diskpart -Tag 'um' -Lines @(
            "select vdisk file=`"$Path`"",
            'detach vdisk',
            'exit'
        )
        if (-not $r.Ok) { Write-Log "卸载虚拟磁盘未成功: $($r.Text)" 'WARN' }
        return $r.Ok
    } catch {
        Write-Log "卸载虚拟磁盘失败: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

# ============================================================
# 分区工具
# ============================================================

function Get-PartGpt {
    param($Partition)
    $t = [string]$Partition.GptType
    return ($t -replace '[{}]', '').ToLower()
}

# 找物理磁盘上的 ESP（排除虚拟磁盘）
function Find-PhysicalEsp {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $sysPart = Get-Partition -DriveLetter $sysLetter -EA SilentlyContinue
    if (-not $sysPart) { return $null }
    $sysDisk = $sysPart.DiskNumber

    $parts = Get-Partition -DiskNumber $sysDisk -EA SilentlyContinue
    foreach ($p in $parts) {
        if ((Get-PartGpt $p) -eq $GUID_ESP) { return $p }
    }
    # MBR 老机器兜底：类型字符串里带 System
    try {
        $cim = Get-CimInstance Win32_DiskPartition -EA Stop |
               Where-Object { $_.DiskIndex -eq $sysDisk -and $_.Type -match 'System' }
        if ($cim) {
            # 用分区序号映射回 Get-Partition（CIM 的 Index 从 0 开始）
            $idx = [int]$cim.Index - 1
            return (Get-Partition -DiskNumber $sysDisk | Where-Object { $_.PartitionNumber -eq $idx })
        }
    } catch {}
    return $null
}

# 给 ESP 临时挂一个盘符
function Mount-EspLetter {
    param([int]$DiskNumber, [int]$PartitionNumber)

    $p = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -EA SilentlyContinue
    if ($p -and $p.DriveLetter) {
        return @{ Ok = $true; Letter = [string]$p.DriveLetter; Mode = '已有盘符' }
    }

    $errors = @()
    foreach ($c in @('S','R','Q','P','O','N','M','L','K','J','I','H','G')) {
        if (Get-Volume -DriveLetter $c -EA SilentlyContinue) { continue }
        try {
            Set-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -NewDriveLetter $c -EA Stop
            Start-Sleep -Milliseconds 500
            if (Test-Path -LiteralPath ("{0}:\" -f $c)) {
                return @{ Ok = $true; Letter = $c; Mode = 'Set-Partition' }
            }
        } catch {
            $errors += ("{0}: {1}" -f $c, $_.Exception.Message)
        }
    }

    # Set-Partition 报 "access path is already in use" 时的兜底
    foreach ($c in @('S','R','Q','P')) {
        if (Get-Volume -DriveLetter $c -EA SilentlyContinue) { continue }
        try {
            & mountvol ("{0}:" -f $c) /S 2>&1 | Out-Null
            Start-Sleep -Milliseconds 600
            if (Test-Path -LiteralPath ("{0}:\EFI" -f $c)) {
                return @{ Ok = $true; Letter = $c; Mode = 'mountvol' }
            }
        } catch {
            $errors += ("mountvol {0}: {1}" -f $c, $_.Exception.Message)
        }
    }

    return @{ Ok = $false; Letter = ''; Mode = ''; Error = ($errors -join ' | ') }
}

function Release-EspLetter {
    param([string]$Letter)
    if (-not $Letter) { return }
    try {
        Remove-PartitionAccessPath -DriveLetter $Letter -EA SilentlyContinue | Out-Null
        Write-Log "已释放 ESP 盘符 $Letter`:"
    } catch {
        Write-Log "释放 ESP 盘符失败（不影响使用）: $($_.Exception.Message)" 'WARN'
    }
    # mountvol 挂上去的盘符，Remove-PartitionAccessPath 不一定摘得掉
    if (Test-Path -LiteralPath ("{0}:\EFI" -f $Letter)) {
        try { & mountvol ("{0}:" -f $Letter) /D 2>&1 | Out-Null } catch {}
    }
}

# 找 vhdx 里那个 NTFS 系统分区，并保证它有盘符
function Get-VhdOsPartition {
    param([int]$DiskNumber)
    foreach ($p in (Get-Partition -DiskNumber $DiskNumber -EA SilentlyContinue)) {
        $vol = $null
        if ($p.DriveLetter) { $vol = Get-Volume -DriveLetter $p.DriveLetter -EA SilentlyContinue }
        if (-not $vol) { try { $vol = Get-Volume -Partition $p -EA SilentlyContinue } catch {} }
        if (-not $vol) { continue }
        if ($vol.FileSystem -eq 'NTFS') {
            $letter = [string]$p.DriveLetter
            if (-not $letter) {
                foreach ($c in @('W','V','U','T','N','M','L')) {
                    if (Get-Volume -DriveLetter $c -EA SilentlyContinue) { continue }
                    try {
                        Set-Partition -DiskNumber $DiskNumber -PartitionNumber $p.PartitionNumber -NewDriveLetter $c -EA Stop
                        Start-Sleep -Milliseconds 400
                        $letter = $c
                        break
                    } catch {}
                }
            }
            if ($letter) {
                return [PSCustomObject]@{
                    Letter = $letter
                    Number = [int]$p.PartitionNumber
                    Part   = $p
                }
            }
        }
    }
    return $null
}

# ============================================================
# 找虚拟磁盘：任意文件名、任意目录（v1.4）
#
# 【为什么改这里】
# v1.3 及以前只会在 OriginDir、D:\、C:\、E: F: G: 的**根目录**找
# NewSystemDisk.vhdx。而安装器从 v1.11 起允许用户自己起名字、自己挑目录，
# 于是「装成 E:\VHD\maimai.vhdx → 重启没菜单 → 按提示点修复」变成了
# 「报找不到虚拟磁盘」（系统其实完好，只是工具瞎了）。
# 现在改成和安装器同一套全盘扫描，并且会顺手挑出最该修的那一个。
# ============================================================

# 全盘扫描 *.vhdx。只按目录名剪枝，不进系统目录/回收站/依赖缓存。
# 用 .NET 的目录枚举而不是 Get-ChildItem：后者每层都要生成 PSObject，
# 实测同一棵树 1074 ms vs 83 ms。这里的目录数可能比安装器还多（含移动盘不扫），
# 差这 12 倍直接决定「点开修复要等几秒」。
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

# >>> COMMON:Get-StateDisplayName
# 由 _源码\_build\sync_common.py 从 common\Get-StateDisplayName.ps1 注入。改这里没用。
function Get-StateDisplayName {
    param([string]$VhdPath)
    # 状态文件里「这个名字」有三个键（历史包袱）：Desc / Name / Description。
    # 安装器三个都写；修复工具 v1.4 只写了 Description；卸载器只读 Desc|Name。
    # 于是「用修复工具补过一次启动项」的系统，名字在安装器和卸载器里都是空的，
    # 自定义名字在这个边角上又丢一次。
    # 统一按 Desc → Name → Description 取，谁写的都能读出来。
    $st = [System.IO.Path]::ChangeExtension($VhdPath, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { return '' }
    $vals = @{}
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\s*([^#=]+?)\s*=(.*)$') {
            $k = $matches[1].Trim().ToLower()
            if (-not $vals.ContainsKey($k)) { $vals[$k] = $matches[2].Trim() }
        }
    }
    foreach ($k in @('desc', 'name', 'description')) {
        if ($vals.ContainsKey($k) -and $vals[$k]) { return $vals[$k] }
    }
    return ''
}
# <<< COMMON:Get-StateDisplayName

# 读 vhdx 旁边的 .boot.txt（安装器写的状态文件），拿启动项 GUID 和显示名。
# 名字部分不再自己解析：交给共享的 Get-StateDisplayName（Desc → Name → Description）。
# v1.5 里这里还有一份自己的 Desc/Name/Description 解析，跟共享函数逻辑重叠 ——
# 同一件事写两遍，改一处忘另一处就会漂移，这正是 P2-5 的来源。
function Get-VhdStateInfo {
    param([string]$Path)
    $r = @{ HasState = $false; Guid = ''; Desc = ''; Name = '' }
    $st = [System.IO.Path]::ChangeExtension($Path, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { return $r }
    $r.HasState = $true
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -EA SilentlyContinue)) {
        if ($ln -match '^\s*([^#=]+?)\s*=(.*)$') {
            $k = $matches[1].Trim()
            $v = $matches[2].Trim()
            if ($k -ieq 'Guid') { $r.Guid = $v }
            elseif ($k -ieq 'Name') { if (-not $r.Name) { $r.Name = $v } }
        }
    }
    # 名字统一问共享函数，保证和安装器/卸载器读出来的是同一个
    $r.Desc = Get-StateDisplayName -VhdPath $Path
    return $r
}

# bcdedit 里的 vhd=[D:]\a\b.vhdx 反解成 D:\a\b.vhdx
# 只取文件名会让「虚拟磁盘\maimai.vhdx」这层目录凭空消失（v1.12 的血案），
# 反过来校验时也得按完整路径比，否则比的是两个残缺字符串。
function ConvertFrom-BcdDevice {
    param([string]$Dev)
    $m = [regex]::Match($Dev, '(?i)vhd=\[([A-Za-z]):\]\s*(.*)$')
    if (-not $m.Success) { return '' }
    $p = $m.Groups[2].Value.Trim().TrimStart('\')
    return ('{0}:\{1}' -f $m.Groups[1].Value.ToUpper(), $p)
}

# 这条启动项现在还在不在 BCD 里、是否指向这个 vhdx
function Test-BcdEntryForVhd {
    param([string]$Guid, [string]$VhdPath)
    $out = @{ Exists = $false; DevOk = $false; Dev = '' }
    if (-not $Guid) { return $out }
    if ($Guid -notmatch '^\{[0-9a-fA-F-]{36}\}$') { return $out }
    $r = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $Guid) -Tag 'probe'
    if (-not $r.Ok) { return $out }      # 条目不存在 → 「菜单里没有它」
    $out.Exists = $true
    $m = [regex]::Match($r.Raw, '(?im)^\s*(?:device|设备)\s+(.+)$')
    if ($m.Success) { $out.Dev = $m.Groups[1].Value.Trim() }
    $back = ConvertFrom-BcdDevice $out.Dev
    $out.DevOk = [bool]($back -and ($back -ieq $VhdPath))
    return $out
}

# 从一堆 vhdx 里挑出「最需要修」的那一个。
# 打分依据（高→低）：
#   有状态文件 + 启动项在 BCD 里已经没了   → 4 + 2 = 6（典型：重启没菜单）
#   有状态文件 + 启动项还在但指向错了       → 3 + 2 = 5（典型：菜单一选就 0xc000000f）
#   有状态文件                              → 2
#   什么都没有                              → 0（可能是手工创建/别人工具创建的）
# 最高分并列、或者全是 0 分时不敢猜 —— 报错并列出全部候选，让人自己指。
function Select-VhdForRepair {
    # $OriginDir 保留只为兼容老 bat 传进来的参数：现在不按它限定搜索范围，
    # 因为虚拟磁盘可以放在任何目录，只看工具目录反而会重演「找不到」。
    param([string]$Explicit, [string]$OriginDir)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "指定的虚拟磁盘不存在：$Explicit" }
        return @{ Path = $Explicit; All = @() }
    }

    $vhds = @(Get-AllVhdxFile)
    if ($vhds.Count -eq 0) { return @{ Path = ''; All = @() } }

    Write-Log ("全盘扫到 {0} 个虚拟磁盘：" -f $vhds.Count)
    $scored = @()
    foreach ($f in $vhds) {
        $st = Get-VhdStateInfo -Path $f.FullName
        $score = 0
        $why = '没有状态文件（不是本程序装的，或者装到一半就断了）'
        if ($st.HasState) {
            $score += 2
            $why = '有状态文件'
            if ($st.Guid) {
                $b = Test-BcdEntryForVhd -Guid $st.Guid -VhdPath $f.FullName
                if (-not $b.Exists) {
                    $score += 4
                    $why = '启动项已从 BCD 里消失（重启看不到菜单）'
                } elseif (-not $b.DevOk) {
                    $score += 3
                    $why = ('启动项还在，但指向的是 {0}（不是这个文件）' -f $b.Dev)
                } else {
                    $why = '启动项正常'
                }
            }
        }
        $scored += [PSCustomObject]@{
            Path  = $f.FullName
            SizeGB = [math]::Round($f.Length / 1GB, 1)
            Score = $score
            Why   = $why
            Time  = $f.LastWriteTime
        }
        Write-Log ("    [{0} 分] {1}  ({2} GB)  {3}" -f $score, $f.FullName, [math]::Round($f.Length / 1GB, 1), $why)
    }

    # [审计 P0-3] 以前全机只有一块虚拟盘就直接拿它开工，连状态文件都不看。
    # 那块盘很可能是 Hyper-V 的虚拟机盘或别人放的备份，而修复流程会删掉它里面的 ESP/MSR，
    # 删完那台虚拟机就起不来了。状态文件（.boot.txt）是"这个程序装的"唯一凭据，
    # 没有就得让用户自己点名。
    if ($scored.Count -eq 1) {
        if ($scored[0].Score -le 0) {
            throw (("只找到一块虚拟硬盘，但它不是这个程序装的（没有状态文件）：`n`n" +
                    "    {0}`n`n" +
                    "没有动它——它可能是 Hyper-V 的盘，或者是备份。`n`n" +
                    "如果确定就是它（比如安装中断，状态文件还没写出来），请手动指定：`n" +
                    "    修复启动菜单-管理员运行.bat -VhdPath `"{0}`"") -f $scored[0].Path)
        }
        return @{ Path = $scored[0].Path; All = $scored }
    }

    $sorted = @($scored | Sort-Object -Property @{ Expression = 'Score'; Descending = $true },
                                                 @{ Expression = 'Time';  Descending = $true })
    $top = $sorted[0]
    $tie = @($sorted | Where-Object { $_.Score -eq $top.Score -and $_.Score -gt 0 })
    if (($top.Score -le 0) -or ($tie.Count -gt 1)) {
        $lines = @($scored | ForEach-Object { '    ' + $_.Path + '  （' + $_.Why + '）' })
        throw (("这台机器上有 {0} 个虚拟磁盘，没法确定该修哪一个：`n`n{1}`n`n" +
                "请改用命令行指定：`n" +
                "    powershell -ExecutionPolicy Bypass -File Repair-Boot.ps1 -VhdPath `"完整路径`"`n`n" +
                "（如果只是想修正菜单指向，用「修好菜单指向」那个工具更方便。）") -f $scored.Count, ($lines -join "`n"))
    }
    return @{ Path = $top.Path; All = $scored }
}

# ============================================================
# BCD
# ============================================================

# bcdedit 统一入口。
#
# 【为什么不再用 /store —— 这是 v1.1 的核心修正】
# 原来是把物理 ESP 挂个盘符，再把 S:\EFI\Microsoft\Boot\bcd 当普通文件去复制/覆盖。
# 真机上直接撞锁报错：
#     文件"S:\EFI\Microsoft\Boot\bcd"正由另一进程使用，因此该进程无法访问此文件
# 因为运行中的系统自己就握着那个 BCD 的句柄。
#
# 正确做法是根本不碰文件：bcdedit 不带 /store 时操作的是「活动 BCD 存储」，
# 也就是当前系统实际启动用的那一份 —— 它本来就存在物理 ESP 上。改它等于改
# 物理 ESP，而且不需要盘符、不需要挂载、不会有共享冲突。
#
# $Store 传空字符串 = 活动存储。传路径 = 离线存储（保留着，目前不用）。
function Invoke-BcdEdit {
    param([string]$Store = '', [string[]]$BcdArgs, [string]$Tag = '')

    $all = @()
    if ($Store) { $all += @('/store', $Store) }
    $all += $BcdArgs

    $txt = ''
    try {
        $txt = (& bcdedit @all 2>&1 | Out-String)
    } catch {
        $txt = "调用异常: $($_.Exception.Message)"
    }
    $code = $LASTEXITCODE
    $clean = ($txt -replace '\s+', ' ').Trim()
    Write-Log ("bcdedit {0} [{1}] => exit={2}  {3}" -f $Tag, ($BcdArgs -join ' '), $code, $clean)

    $err = ($txt -match '找不到|not found|无效|invalid|拒绝|denied|失败|failed|错误|error')
    return @{ Ok = (($code -eq 0) -and (-not $err)); Code = $code; Text = $clean; Raw = $txt }
}

# 选 /copy 用的源启动项标识符，返回 @{ Guid; Tag }。
#
# 背景（v1.18 之前的教训）：
#   安装器 / 修复工具复制新启动项时，原本只写死 {current}（退回 {default}）。
#   这两种都是「逻辑别名」，正常情况下没问题；但一旦 BCD 里的主加载项被别的
#   动作弄丢（比如之前把系统装进 vhdx 又 native boot 过、或某次修复/卸载的副作用），
#   osloader 枚举里就只剩 Recovery 条目，{current}/{default} 都解析不到真实加载项，
#   /copy 就会报「指定的项标识符无效」，装到最后一刻失败。
#
#   解决：{current} 失效 → {default} 失效 → 从 /enum osloader 里挑一个「真实、
#   健康」的系统加载项 GUID 当源。挑中之后后面 3 条 /set 会把 device/osdevice/path
#   全部覆盖成指向 vhdx，所以源条目原本指向哪块盘并不重要，唯一要求是它得是
#   一个正经的 osloader（不是 Recovery、不是 ramdisk、不是 winpe）。
function Get-CopySourceGuid {
    # 第 1 层：{current}（当前正在运行的系统，多系统下最准）
    $probe = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{current}') -Tag 'probe-current'
    if ($probe.Ok) { return @{ Guid = '{current}'; Tag = 'current' } }

    # 第 2 层：{default}（默认系统）
    $probe = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{default}') -Tag 'probe-default'
    if ($probe.Ok) { return @{ Guid = '{default}'; Tag = 'default' } }

    # 第 3 层：从 osloader 枚举里挑一个真实加载项。
    # /enum osloader 会把每个条目整块 dump 出来，中间夹着 Recovery 条目（ramdisk=）。
    # 按「标识符」切块，逐块判定：
    #   - 有 device partition= 或 osdevice partition=  → 真实系统加载项
    #   - description 含 Recovery / 标识符是已知恢复 GUID → 跳过
    #   - device/osdevice 带 ramdisk= → 那是 WinRE，跳过
    $enum = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', 'osloader') -Tag 'oslist-src'
    $blocks = [regex]::Split($enum.Raw, '(?im)^(?=\s*(?:标识符|identifier)\s+\{)')
    foreach ($b in $blocks) {
        if (-not ($b -match '(?im)\{(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|current|default)\}')) { continue }
        $g = $matches[0]
        # Recovery / WinRE：device 或 osdevice 是 ramdisk，或描述里带 Recovery
        if ($b -match '(?im)ramdisk=') { continue }
        if ($b -match '(?im)description\s+.*recovery') { continue }
        # 得是真指向物理盘/分区或 vhd 的加载项
        if ($b -notmatch '(?im)(?:device|osdevice)\s+(partition=|vhd=)') { continue }
        # 也排除 {bootmgr} 这类管理项（它不会出现在 osloader 里，但保险）
        if ($g -ieq '{bootmgr}') { continue }
        Write-Log "从 osloader 枚举里挑到可用源: $g" 'WARN'
        return @{ Guid = $g; Tag = 'osloader-pick' }
    }

    # 都挑不到：把枚举原文交给调用方，让它报一个能定位的错
    return @{ Guid = ''; Tag = 'none'; Raw = $enum.Raw }
}

# 创建一个新的启动加载器条目，返回 @{ Guid; Tag }（失败返回 Guid='' + Error）。
#
# 两条路，按顺序走：
#   1. /copy <源> /d <描述>  —— 从现有加载项复制，能继承一堆默认字段，最稳。
#      源由 Get-CopySourceGuid 选：{current} → {default} → osloader 枚举里挑真实项。
#   2. /create /d <描述> /application osloader —— 从零建，不依赖任何现有条目。
#      只有当 /copy 连源都找不到（BCD 主加载项被清空，只剩 WinRE）时才走这条路。
#
# 背景（v1.18 之后的补充教训）：
#   v1.18 给 /copy 加了「从 osloader 枚举挑真实加载项」的第三层兜底，本以为够用。
#   结果真机上出现一种更糟的情况：这台机器之前把系统装进 vhdx 又 native boot 过，
#   BCD 里的 {current}/{default} 连同唯一的真实 osloader 加载项全被清掉，
#   /enum osloader 只剩两个 Recovery 条目。三层源全失效，/copy 无源可复制。
#   这时唯一还能救的就是 /create —— 它不需要源，直接造一个全新加载项，
#   后面照样用 /set device/osdevice/path 指向 vhdx。
#
# 背景（v1.24 复查补充）：
#   /copy 会自动把新条目加进 {bootmgr} 的 displayorder（开机菜单），/create 不会。
#   于是走 /create 兜底时，条目建出来了、device/path 也都对，但开机菜单里根本没有
#   这一行 —— 用户看到的现象就是「修复成功了，重启还是没菜单」，等于白建。
#   所以两条路收尾时统一确认一次 displayorder（已在就不动，避免打乱用户原有顺序）。
#
# 返回结构：@{ Guid='{...}'; Tag='copy'|'create'; Error='' }
#   Guid 为空且 Error 非空 = 两条路都走不通，调用方直接报错退出。
function New-BootEntryGuid {
    param([string]$Desc)

    $guid = ''
    $tag = ''

    # ---- 第 1 路：copy（有源就复制）----
    $src = Get-CopySourceGuid
    if ($src.Guid) {
        $cp = Invoke-BcdEdit -Store '' -BcdArgs @('/copy', $src.Guid, '/d', $Desc) -Tag "copy-$($src.Tag)"
        $g = [regex]::Match($cp.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if ($g.Success) {
            $guid = $g.Value
            $tag = 'copy'
        } else {
            Write-Log ('/copy 执行了但没拿到新 GUID（输出：{0}），退回 /create' -f $cp.Text) 'WARN'
        }
    } else {
        Write-Log '找不到可用的 /copy 源（{current}/{default} 失效、osloader 里也没有真实加载项），改用 /create 从零建' 'WARN'
    }

    # ---- 第 2 路：create（无源从零建）----
    # 必须带 /application osloader，否则 /create 默认建的是「应用程序」类型，
    # 复制不到、也不是我们要的启动加载器。
    if (-not $guid) {
        $cr = Invoke-BcdEdit -Store '' -BcdArgs @('/create', '/d', $Desc, '/application', 'osloader') -Tag 'create'
        $g = [regex]::Match($cr.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if ($g.Success) {
            $guid = $g.Value
            $tag = 'create'
        } else {
            return @{ Guid = ''; Tag = ''; Error = ('创建启动项失败：/copy 无源、/create 也没拿到新 GUID。' + "`n" + '输出：' + $cr.Text) }
        }
    }

    # ---- 统一收尾：确认新条目进了开机菜单 ----
    # 只查 displayorder 那一行，别用整段枚举去 -match（{bootmgr} 的输出里还有
    # default 等其他字段，误判成「已在菜单里」就又不加了）。
    try {
        $bmRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm-order').Raw
        $dm = [regex]::Match([string]$bmRaw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+)$')
        $inOrder = ($dm.Success -and ($dm.Groups[1].Value -match [regex]::Escape($guid)))
        if (-not $inOrder) {
            $do = Invoke-BcdEdit -Store '' -BcdArgs @('/displayorder', $guid, '/addlast') -Tag 'displayorder'
            if ($do.Ok) {
                Write-Log '新条目已加入开机菜单（displayorder /addlast）'
            } else {
                Write-Log ('加入开机菜单失败，开机可能看不到这一项：' + $do.Text) 'WARN'
            }
        } else {
            Write-Log '新条目已在开机菜单里，displayorder 不需要追加'
        }
    } catch {
        Write-Log ('检查 displayorder 失败（不影响条目本身）：' + $_.Exception.Message) 'WARN'
    }

    return @{ Guid = $guid; Tag = $tag; Error = '' }
}

function Get-BcdValue {
    param([string]$Store, [string]$Entry, [string]$Key)
    $r = Invoke-BcdEdit -Store $Store -BcdArgs @('/enum', $Entry) -Tag "enum-$Entry"
    $m = [regex]::Match($r.Raw, ('(?im)^\s*' + [regex]::Escape($Key) + '\s+(\S+)'))
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

# 备份活动 BCD 存储。
# 用 bcdedit /export —— 走的是 BCD API，不是文件复制，所以不会被文件锁挡住。
# 返回 Ok=$false 时调用方不要直接放弃：后面只做「新增条目 + 改菜单超时」，
# 这些都能用 bcdedit 反向撤回，文件级备份只是多一层保险。
function Backup-BcdStore {
    param([string]$Dest)

    # 【v1.29】bcdedit /export 导出的是注册表 hive，Windows 会在目标旁边生成
    # X.bcd.LOG / .LOG1 / .LOG2。以前直接导出到 vhdx 目录，那里就堆一地 .bcd.LOG*。
    # 现在先导到临时目录，只把 .bcd 拷到目的地，临时文件连伴生 LOG 一起清掉。
    $tmp = Join-Path $Script:TempDir ("bcdexp-$(Get-Random).bcd")
    $r = Invoke-BcdEdit -Store '' -BcdArgs @('/export', $tmp) -Tag 'export'
    $len = 0
    if (Test-Path -LiteralPath $tmp) {
        $fi = Get-Item -LiteralPath $tmp -EA SilentlyContinue
        if ($fi) { $len = $fi.Length }
    }
    $sidecar = @($tmp, "$tmp.LOG", "$tmp.LOG1", "$tmp.LOG2")
    if ($r.Ok -and $len -gt 0) {
        $copied = $false
        try {
            $parent = Split-Path -Parent $Dest
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force -EA Stop | Out-Null
            }
            Copy-Item -LiteralPath $tmp -Destination $Dest -Force -EA Stop
            $copied = $true
        } catch { $copied = $false }
        foreach ($f in $sidecar) { Remove-Item -LiteralPath $f -Force -EA SilentlyContinue }
        if ($copied) { return @{ Ok = $true; Mode = 'bcdedit /export'; Size = $len; Error = '' } }
        return @{ Ok = $false; Mode = ''; Size = 0; Error = '备份文件拷贝到目标位置失败' }
    }
    foreach ($f in $sidecar) { Remove-Item -LiteralPath $f -Force -EA SilentlyContinue }
    return @{ Ok = $false; Mode = ''; Size = $len; Error = $r.Text }
}

# 用 bcdedit /import 把活动存储恢复成导出时的状态
function Restore-BcdStore {
    param([string]$Src)
    if (-not $Src -or -not (Test-Path -LiteralPath $Src)) {
        return @{ Ok = $false; Text = '没有可用的备份文件' }
    }
    $r = Invoke-BcdEdit -Store '' -BcdArgs @('/import', $Src) -Tag 'import'
    return @{ Ok = $r.Ok; Text = $r.Text }
}

# ============================================================
# 状态文件：卸载脚本靠它找回 GUID
# ============================================================

function Get-StatePath {
    param([string]$Vhd)
    return [System.IO.Path]::ChangeExtension($Vhd, '.boot.txt')
}

function Save-State {
    param([string]$Path, [hashtable]$Data)
    $lines = @('# 虚拟硬盘系统 - 启动条目状态（卸载时要用，别删）')
    foreach ($k in ($Data.Keys | Sort-Object)) { $lines += ('{0}={1}' -f $k, $Data[$k]) }
    [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding $false))
}

# ============================================================
# 主流程
# ============================================================

$resultLines = New-Object System.Collections.ArrayList
function Add-Result([string]$s) { [void]$resultLines.Add($s) }

Write-Log "===== 修复启动菜单 v$($Script:Version) ====="
Write-Log "作者：connectsegabot"
Write-Log "日志: $($Script:LogFile)"

$mounted = $false
$espLetter = ''
$osLetter = ''
$bcdPath = ''
$bcdBackup = ''
$statePath = ''
$newGuid = ''      # 本次 /copy 建出来的条目，失败时 catch 用它回滚
$restored = $false # BCD 是否已经被 /import 还原（还原成功就不必再单独删条目）

try {
    if (-not (Test-Admin)) {
        throw '需要管理员权限。请右键「以管理员身份运行」，或直接双击「修复启动菜单-管理员运行.bat」。'
    }

    $fw = Get-FirmwareType
    Write-Log "固件类型: $fw （2=UEFI）"
    if ($fw -ne 2) {
        throw ('只支持 UEFI 启动的机器。本机固件类型判定为 ' + $fw + '，' +
               '虚拟磁盘启动（native boot）在 Legacy BIOS 下需要另一套参数，本脚本未覆盖。')
    }

    # ---------- 找 vhdx（v1.4：任意名字、任意目录） ----------
    $pick = Select-VhdForRepair -Explicit $VhdPath -OriginDir $OriginDir
    if (-not $pick.Path) {
        throw ('全盘都没找到任何 .vhdx（已扫过所有固定 NTFS 盘，最多 6 层目录）。' + "`n`n" +
               '可能的情况：' + "`n" +
               '  · 安装确实没走到创建虚拟磁盘那一步' + "`n" +
               '  · 虚拟磁盘放在移动硬盘 / U 盘上（native boot 本来也不建议这么放）' + "`n" +
               '  · 虚拟磁盘已经被删掉了' + "`n`n" +
               '如果确认文件还在，可以用 -VhdPath 直接把路径告诉本脚本。')
    }
    $VhdPath = $pick.Path
    if (-not (Test-Path -LiteralPath $VhdPath)) { throw "虚拟磁盘不见了：$VhdPath" }
    $VhdPath = (Resolve-Path -LiteralPath $VhdPath).Path
    Set-LogDir -VhdPath $VhdPath
    Write-Log "本次修复的虚拟磁盘: $VhdPath"
    Write-Log "日志: $Script:LogFile"
    if (@($pick.All).Count -gt 1) {
        Write-Log ("（机器上一共有 {0} 个虚拟磁盘，按「最可能缺菜单/指错」挑的，其余不动）" -f @($pick.All).Count)
    }
    Add-Result ("虚拟磁盘：$VhdPath")

    $vhdSizeGB = [math]::Round((Get-Item -LiteralPath $VhdPath).Length / 1GB, 1)

    # vhdx 所在卷的盘符（BCD 里要用）
    #
    # 必须保留中间子目录：D:\虚拟磁盘\x.vhdx -> vhd=[D:]\虚拟磁盘\x.vhdx
    # 只取文件名会把菜单指向 D:\x.vhdx（这个文件不存在），装好了也进不去。
    $vhdDrive = [System.IO.Path]::GetPathRoot($VhdPath).Substring(0, 1).ToUpper()
    $vhdRel = $VhdPath.Substring([System.IO.Path]::GetPathRoot($VhdPath).Length).TrimStart('\')
    if (-not $vhdRel) { throw "虚拟磁盘路径无效：$VhdPath" }
    $vhdDev = "vhd=[$($vhdDrive):]\$vhdRel"
    Write-Log "BCD 将指向: $vhdDev"

    # ---------- 挂载 ----------
    $diskNum = Mount-Vhd -Path $VhdPath
    if ($diskNum -lt 0) { throw '虚拟磁盘挂载失败（系统没识别出这块盘）。' }
    $mounted = $true
    Write-Log "虚拟磁盘编号: $diskNum"

    # ---------- 删掉 vhdx 内的 ESP，变单分区 ----------
    $vparts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
    Write-Log ("vhdx 内分区数: {0}" -f $vparts.Count)

    if ($vparts.Count -gt 1) {
        $espInVhd = $vparts | Where-Object { (Get-PartGpt $_) -eq $GUID_ESP }
        if ($espInVhd) {
            Write-Log ("发现 vhdx 内 ESP（分区 {0}，{1:N0} MB）→ 删除，让它变成单分区" -f
                       $espInVhd.PartitionNumber, ($espInVhd.Size / 1MB))
            $dp = Invoke-Diskpart -Tag 'del' -Lines @(
                "select disk $diskNum",
                ("select partition {0}" -f $espInVhd.PartitionNumber),
                'delete partition override',
                'exit'
            )
            Write-Log "删除 vhdx 内 ESP: $($dp.Text)"
            if (-not $dp.Ok) { throw "删除 vhdx 内 ESP 失败：$($dp.Text)" }
            Start-Sleep -Milliseconds 800
            $vparts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
            Write-Log ("删除后分区数: {0}" -f $vparts.Count)
        }
        # MSR 也删掉（不影响数据，但没有意义）
        $msrInVhd = $vparts | Where-Object { (Get-PartGpt $_) -eq $GUID_MSR }
        if ($msrInVhd) {
            $dp2 = Invoke-Diskpart -Tag 'delmsr' -Lines @(
                "select disk $diskNum",
                ("select partition {0}" -f $msrInVhd.PartitionNumber),
                'delete partition override',
                'exit'
            )
            Write-Log "删除 vhdx 内 MSR: $($dp2.Text)"
            Start-Sleep -Milliseconds 500
        }
    }

    # ---------- 确认系统分区 ----------
    $os = Get-VhdOsPartition -DiskNumber $diskNum
    if (-not $os) { throw 'vhdx 里找不到 NTFS 系统分区，虚拟磁盘可能已损坏。' }
    $osLetter = $os.Letter
    Write-Log "系统分区: $osLetter`: (分区 $($os.Number))"

    $need = @(
        "$($osLetter):\Windows\System32\winload.efi",
        "$($osLetter):\Windows\System32\ntoskrnl.exe"
    )
    foreach ($f in $need) {
        if (-not (Test-Path -LiteralPath $f)) {
            throw ("系统文件缺失：$f`n虚拟磁盘里的系统不完整，需要重新安装。")
        }
    }
    Write-Log '系统文件检查通过（winload.efi / ntoskrnl.exe 都在）'

    # 确认它真的是「分区 1」—— native boot 只认第一个分区
    if ($os.Number -ne 1) {
        Write-Log ("注意：系统分区在 vhdx 里是分区 {0} 而不是 1。bootmgr 通常只认第一个分区，可能启动不了。" -f $os.Number) 'WARN'
    } else {
        Write-Log '系统分区是 vhdx 的分区 1 ✓（符合 native boot 要求）'
    }

    # ---------- 【关键】先卸载 vhdx，再做 BCD 操作 ----------
    #
    # 实测（19:48 那次）：vhdx 处于挂载状态时执行
    #     bcdedit /set {guid} device vhd=[D:]\NewSystemDisk.vhdx
    # bcdedit 返回「操作成功完成」，但 /enum 读回发现 device 变成了 partition=E: ——
    # E: 是挂载中的虚拟盘的内部卷。bcdedit 解析 vhd= 时发现该虚拟盘正连着，
    # 就把设备直接写成了那个卷，而不是保留 vhd= 文件引用。
    # 这样的条目重启后必然失败（那时 vhdx 没挂载）。
    #
    # 所以：分区修完、系统文件检查完就卸载，BCD 那一段全程在「vhdx 未挂载」状态下做。
    [void](Dismount-VhdSafe -Path $VhdPath)
    $mounted = $false
    Write-Log 'vhdx 已卸载（bcdedit 要求在未挂载状态下写 vhd= 设备）'

    # ---------- 定位活动 BCD 存储 ----------
    #
    # 不再给物理 ESP 挂盘符。原因见 Invoke-BcdEdit 上面的注释：ESP 上的 bcd 文件
    # 被运行中的系统占用，复制/覆盖都会撞共享冲突。改走活动存储等价且更稳。
    #
    # 这里仍然把 ESP 找出来，纯粹是为了日志里能看出「开机菜单落在哪块盘上」，
    # 找不到也不影响后续流程。
    $esp = Find-PhysicalEsp
    if ($esp) {
        Write-Log ("物理 ESP（仅记录，不挂载）: 磁盘 {0} 分区 {1}，{2:N0} MB" -f
                   $esp.DiskNumber, $esp.PartitionNumber, ($esp.Size / 1MB))
        Add-Result ("启动菜单位置：磁盘 {0} 分区 {1} 的 ESP" -f $esp.DiskNumber, $esp.PartitionNumber)
    } else {
        Write-Log '没能定位物理 ESP（不影响：启动项写在活动 BCD 存储上）' 'WARN'
    }
    $bcdPath = '活动 BCD 存储'
    Write-Log "BCD: $bcdPath"

    # ---------- 备份 BCD ----------
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $bcdBackup = Join-Path (Get-SideLogDir -VhdPath $VhdPath) ("bcd-backup-$stamp.bcd")
    $bk = Backup-BcdStore -Dest $bcdBackup
    if ($bk.Ok) {
        Write-Log ("BCD 已备份（{0}，{1} 字节）: {2}" -f $bk.Mode, $bk.Size, $bcdBackup)
        Add-Result ("BCD 备份：$bcdBackup")
    } else {
        Write-Log ("BCD 备份失败: {0}" -f $bk.Error) 'WARN'
        $bcdBackup = ''
        Add-Result 'BCD 备份：失败（不影响本次修复）'
    }

    # ---------- 读旧状态文件 ----------
    #
    # 有两样东西只能从旧状态文件里拿，不能对着当前 BCD 重新采样：
    #
    # 1) 旧 GUID —— 重复运行靠它删掉上一次留下的条目，否则菜单会一项一项往上叠。
    # 2) 安装前的原值 OrigTimeout / OrigDisplayMenu / OrigDisplayMenuSet ——
    #    这是卸载时把开机菜单恢复原样的唯一依据。安装器记的是「装之前的」，
    #    而此刻 BCD 里已经是安装器改过的 Yes。在这里重新采样，状态文件就会被写成
    #    Yes / Set=1，卸载时按 Yes 还原，开机菜单永远弹着 —— v1.8 / v1.9
    #    两版才把这个坑填掉，不能从修复工具这里又绕回来。
    $statePath = Get-StatePath -Vhd $VhdPath
    $old = @{}
    if (Test-Path -LiteralPath $statePath) {
        foreach ($ln in (Get-Content -LiteralPath $statePath -Encoding UTF8 -EA SilentlyContinue)) {
            if ($ln -match '^\s*([^#=]+)=(.*)$') { $old[$matches[1].Trim()] = $matches[2].Trim() }
        }
        Write-Log ("读到旧状态文件（{0} 个键）: {1}" -f $old.Count, $statePath)
    } else {
        Write-Log '没有旧状态文件（首次修复），原值将采样当前 BCD'
    }
    $oldGuid = ''
    if ($old['Guid'] -and $old['Guid'] -match '^\{[0-9a-fA-F-]{36}\}$') { $oldGuid = $old['Guid'] }

    # ---------- 原值：有旧记录就沿用，没有才采样 ----------
    $origTimeout = ''
    $origDisplay = ''
    $origDisplaySet = ''
    if ($old['OrigTimeout']) {
        $origTimeout = $old['OrigTimeout']
        Write-Log "沿用旧记录的原 timeout: $origTimeout"
    } else {
        $origTimeout = Get-BcdValue -Store '' -Entry '{bootmgr}' -Key 'timeout'
        if (-not $origTimeout) { $origTimeout = '30' }
        Write-Log "旧记录里没有原 timeout，采样当前值: $origTimeout"
    }
    if ($old.ContainsKey('OrigDisplayMenuSet')) {
        $origDisplaySet = $old['OrigDisplayMenuSet']
        $origDisplay = $old['OrigDisplayMenu']
        Write-Log "沿用旧记录的原 displaybootmenu: 「$origDisplay」(Set=$origDisplaySet)"
    } elseif ($old.ContainsKey('OrigDisplayMenu')) {
        # v1.3 及以前只记了值、没记「原本设过没有」，按有没有值倒推
        $origDisplay = $old['OrigDisplayMenu']
        if ($origDisplay) { $origDisplaySet = '1' } else { $origDisplaySet = '0' }
        Write-Log ("旧记录缺 OrigDisplayMenuSet，按值倒推为 {0}" -f $origDisplaySet) 'WARN'
    } else {
        $bmRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm').Raw
        if ($bmRaw -match '(?im)^\s*displaybootmenu\s+(\S+)') { $origDisplay = $matches[1] }
        if ($origDisplay) { $origDisplaySet = '1' } else { $origDisplaySet = '0' }
        Write-Log ("旧记录里没有 displaybootmenu，采样当前值: 「{0}」/ Set={1}" -f $origDisplay, $origDisplaySet)
    }
    if (-not $old['BcdBackup']) { $old['BcdBackup'] = $bcdBackup }
    if (-not $old['Created']) { $old['Created'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
    Write-Log ("生效的原值: timeout={0}  displaybootmenu=「{1}」(Set={2})" -f $origTimeout, $origDisplay, $origDisplaySet)

    # 菜单里显示什么名字：优先用安装时用户起的名字（状态文件里的 Desc / Name）。
    # v1.3 及以前写死「Windows 10（新系统）」—— 用户装了个叫 maimai 的系统，
    # 修完之后菜单变成「Windows 10（新系统）」，自定义名字等于被抹掉了。
    $stateInfo = Get-VhdStateInfo -Path $VhdPath
    $desc = ''
    if ($stateInfo.Desc) { $desc = $stateInfo.Desc }
    elseif ($stateInfo.Name) { $desc = $stateInfo.Name }
    elseif ($old['Name']) { $desc = $old['Name'] }
    else { $desc = 'Windows（虚拟系统）' }
    Write-Log "菜单描述: $desc"

    # ---------- 建新启动条目 ----------
    # /copy 优先，无源（BCD 主加载项被清空，只剩 WinRE）时 /create 从零建。
    # v1.18 之前写死 {default}，没有兜底；v1.19 起连 osloader 里都只剩 Recovery
    # 时，也走 /create 造一条全新加载项，不再卡死在「找不到源」。
    $nb = New-BootEntryGuid -Desc $desc
    if (-not $nb.Guid) {
        throw $nb.Error
    }
    # GUID 由 New-BootEntryGuid 直接返回（/copy 或 /create 都已在内部拿到），
    # 这里不再重复从输出里抠 —— 那正是 v1.5 回归的教训来源。
    $guid = $nb.Guid
    $newGuid = $guid      # 交给 catch 兜底：失败时把这条半成品删掉，别每跑一次多一项
    Write-Log "新启动条目: $guid（来源：$($nb.Tag)）"

    # ---------- 指向 vhdx ----------
    # $vhdDev 在挂载虚拟磁盘之前就算好了（见上面「BCD 将指向」），这里直接用
    $stepOk = $true
    $setList = @(
        @('/set', $guid, 'device',   $vhdDev),
        @('/set', $guid, 'osdevice', $vhdDev),
        @('/set', $guid, 'path',     '\Windows\system32\winload.efi'),
        @('/set', $guid, 'detecthal', 'on')
    )
    foreach ($s in $setList) {
        $r = Invoke-BcdEdit -Store '' -BcdArgs $s -Tag 'set'
        if (-not $r.Ok) { $stepOk = $false }
    }
    if (-not $stepOk) {
        # 先把自己刚建的半成品删掉再抛：备份失败时 catch 没法靠 /import 兜底，
        # 不删就真的会「每跑一次菜单里多一项」。
        $rb = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $guid) -Tag 'rollback'
        if ($rb.Ok) { Write-Log '已删除本次创建的半成品条目（回滚）' 'WARN' }
        else { Write-Log ("回滚失败，菜单里可能多一项：{0}" -f $rb.Text) 'WARN' }
        throw "设置启动条目参数失败，详见日志。`n`n$($Script:LogFile)"
    }

    # ---------- 校验 1：设备路径逐字核对 ----------
    $check = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify'
    $devNow = ''
    $mv = [regex]::Match($check.Raw, '(?im)^\s*(?:device|设备)\s+(.+)$')
    if ($mv.Success) { $devNow = $mv.Groups[1].Value.Trim() }
    if ($devNow -notmatch '(?i)vhd=') {
        throw ("启动条目里没写进 vhd= 设备路径。`n`n" +
               "常见原因：改 BCD 时虚拟磁盘还处于挂载状态，bcdedit 会把 vhd= 偷偷换成" +
               "内部卷的 partition=X:（本工具已在改 BCD 前卸载 vhdx，正常不该再发生）。`n`n" +
               "读回内容：$($check.Text)")
    }
    # 光有 vhd= 不够：指向错的 vhdx 一样起不来（v1.12 就是这个坑）。
    # 反解成真实路径，跟磁盘上的文件逐字比。
    $backPath = ConvertFrom-BcdDevice $devNow
    Write-Log ("条目校验: device={0}  反解={1}" -f $devNow, $backPath)
    if ($backPath -and ($backPath -ine $VhdPath)) {
        Write-Log "指向不对（应为 $VhdPath），重写一次" 'WARN'
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'device', $vhdDev) -Tag 'fix-dev')
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'osdevice', $vhdDev) -Tag 'fix-dev')
        $check = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify2'
        $devNow = ''
        $mv = [regex]::Match($check.Raw, '(?im)^\s*(?:device|设备)\s+(.+)$')
        if ($mv.Success) { $devNow = $mv.Groups[1].Value.Trim() }
        $backPath = ConvertFrom-BcdDevice $devNow
        if (-not $backPath -or ($backPath -ine $VhdPath)) {
            throw ("启动项的设备路径写不进去，或者写进去又被改掉了。`n`n" +
                   "期望：$vhdDev`n" +
                   "读回：$devNow`n`n" +
                   "常见原因：`n" +
                   "  · 改 BCD 时虚拟磁盘还挂在系统上（会被换成内部卷的 partition=X:）`n" +
                   "  · 路径里有 winload 不认的字符（这种情况多见于很长的中文目录）`n`n" +
                   "先把虚拟磁盘换到 D:\VHD 这样的纯英文短目录、重新装一次，最稳。`n" +
                   "日志：$($Script:LogFile)")
        }
        Write-Log '重写后指向正确 ✓'
    }

    # ---------- 校验 2：菜单文字 ----------
    $descNow = ''
    $md = [regex]::Match($check.Raw, '(?im)^\s*(?:description|描述)\s+(.+)$')
    if ($md.Success) { $descNow = $md.Groups[1].Value.Trim() }
    if ($descNow -ne $desc) {
        # 中文写不进去时（命令行编码问题）退到纯英文，别让菜单显示成问号
        $safeDesc = 'Windows (VHD) ' + [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
        $safeDesc = ($safeDesc -replace '[^\x20-\x7E]', '').Trim()
        if (-not $safeDesc) { $safeDesc = 'Windows (VHD)' }
        Write-Log ("菜单文字没能正确写入（读回「{0}」），改用「{1}」" -f $descNow, $safeDesc) 'WARN'
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'description', $safeDesc) -Tag 'desc-en')
        $desc = $safeDesc
    }

    # ---------- 新条目确认可用之后，才删旧条目 ----------
    #
    # v1.4 是先删后建：备份失败也继续（上面只记一条 WARN），旧条目却已经 /delete 了。
    # 万一 /copy 或 /set 这一步失败，用户连原本能用的菜单都没了 —— 装得好的系统
    # 因为跑了「修复」反而进不去，是最不能接受的一种坏。
    # 现在顺序反过来：新条目逐字校验通过 → 才动旧的。最坏情况只是菜单里多一项。
    if ($oldGuid -and ($oldGuid -ine $guid)) {
        Write-Log "新条目已校验通过，删除上次留下的旧条目 $oldGuid"
        $dr = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $oldGuid) -Tag 'del-old'
        if ($dr.Ok) {
            Write-Log '旧条目已删除'
        } else {
            Write-Log ("旧条目删不掉（不影响使用，只是开机菜单里会多一项）: {0}" -f $dr.Text) 'WARN'
            Add-Result ("旧启动项 {$oldGuid} 没删掉，菜单里可能多一项，可忽略")
        }
    }

    # ---------- 打开开机菜单 ----------
    # timeout=0 或 displaybootmenu=No 时，开机会直接进默认系统，根本看不到菜单
    [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu')
    if ($origTimeout -eq '0') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout')
        Write-Log '原 timeout=0，已改成 10 秒，否则看不到菜单'
    }

    # ---------- 清掉残留的一次性直通（bootsequence） ----------
    # {bootmgr} 的 bootsequence 是「下次启动直通指定系统」的一次性值，正常在
    # 首次启动后被 winload 自动清除；但启动被打断/异常时会赖着不走 —— 菜单
    # 从此被短路，修好 displayorder/default 也看不见（2026-11-05 真机踩坑）。
    # 所以修完菜单顺手清一次：没有该值时 bcdedit 报错，静默忽略即可。
    $bsChk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'menu'
    if (([string]$bsChk.Raw) -match '(?im)^\s*bootsequence\s') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/deletevalue', '{bootmgr}', 'bootsequence') -Tag 'menu')
        Write-Log '发现残留的 bootsequence（一次性直通），已清除 —— 否则菜单会被短路'
    }

    # ---------- 状态文件 ----------
    #
    # 键名必须和安装器、卸载器一致：三个程序都认 Desc（卸载器还会退回 Name）。
    # v1.4 这里只写了 Description，于是「用本工具补过一次启动项」的系统，
    # 再打开安装器或卸载器时名字就读不出来了 —— 自定义名字在这个边角上又丢一次。
    $espDisk = ''
    $espPart = ''
    if ($esp) { $espDisk = $esp.DiskNumber; $espPart = $esp.PartitionNumber }
    $nameForState = ''
    if ($old['Name']) { $nameForState = $old['Name'] }
    elseif ($stateInfo.Name) { $nameForState = $stateInfo.Name }
    else { $nameForState = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath) }
    Save-State -Path $statePath -Data @{
        Version          = $Script:Version
        VhdPath          = $VhdPath
        Name             = $nameForState
        Desc             = $desc
        Description      = $desc
        Guid             = $guid
        BcdStore         = 'live'
        EspDisk          = $espDisk
        EspPart          = $espPart
        OrigTimeout      = $origTimeout
        OrigDisplayMenu  = $origDisplay
        # 卸载时靠它判断「原本就有这一项」还是「原本压根没设过」：
        # 后者要用 bcdedit /deletevalue 恢复成未设置，写成 No 会关掉别人的双系统菜单。
        OrigDisplayMenuSet = $origDisplaySet
        BcdBackup        = $old['BcdBackup']
        Created          = $old['Created']
        Repaired         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    Write-Log "状态文件: $statePath"

    # ---------- 清理 C:\EFI 垃圾（C:\Boot 一律不动）----------
    #
    # 【v1.31 高危修正】这里以前是 @('C:\EFI', 'C:\Boot')。C:\Boot 是 Windows 的
    # 系统引导目录（BCD / BCD.LOG / bootvhd.dll / BOOTSTAT.DAT 都在里面），只凭
    # 「创建时间 < 48 小时」就递归删掉，等于随时可能误删系统文件、连带删掉活动 BCD
    # 的事务日志。**C:\Boot 不再碰，别再往列表里加。**
    #
    # C:\EFI 也可能被 rEFInd / OpenCore / Clover 这类第三方引导占用，
    # 只看创建时间就递归删会把人家的引导删掉。所以先看内容：
    # 出现 Microsoft / Boot 以外的子目录，或底下有 BCD / bootmgfw.efi，就跳过。
    foreach ($junk in @('C:\EFI')) {
        if (-not (Test-Path -LiteralPath $junk)) { continue }
        try {
            $age = (Get-Date) - (Get-Item -LiteralPath $junk).CreationTime
            if ($age.TotalHours -ge 48) {
                Write-Log "$junk 存在但创建时间较早，不敢动，留着你自己看" 'WARN'
                continue
            }

            $unsafe = $false
            if ($junk -eq 'C:\EFI') {
                $subs = @(Get-ChildItem -LiteralPath $junk -Directory -EA SilentlyContinue)
                foreach ($s in $subs) {
                    if ($s.Name -notin @('Microsoft', 'Boot')) { $unsafe = $true; break }
                }
                # v1.31：底下真有一条能用的引导（BCD / bootmgfw.efi），就别删
                if (-not $unsafe) {
                    $bcdHit = @(Get-ChildItem -LiteralPath $junk -Recurse -Force -EA SilentlyContinue | Where-Object {
                        $_.Name -eq 'BCD' -or $_.Name -like 'BCD.LOG*' -or $_.Name -eq 'bootmgfw.efi'
                    })
                    if ($bcdHit.Count -gt 0) { $unsafe = $true }
                }
            }
            if ($unsafe) {
                Write-Log "跳过清理 $junk（里面有第三方引导目录，不是本程序创建的）" 'WARN'
                continue
            }

            Remove-Item -LiteralPath $junk -Recurse -Force -EA Stop
            Write-Log "已清理垃圾目录 $junk"
        } catch {
            Write-Log "清理 $junk 失败（不影响使用）: $($_.Exception.Message)" 'WARN'
        }
    }

    # ---------- 收尾 ----------
    Add-Result ''
    Add-Result ("启动菜单条目：$desc")
    Add-Result ("菜单显示时间：10 秒（超时进原系统）")

    Show-Box ("修复完成。`n`n" +
              "已经给虚拟磁盘注册了启动项。`n`n" +
              "下一步：`n" +
              "  1. 重启电脑`n" +
              "  2. 开机第 2 屏会出现系统选择菜单`n" +
              "  3. 用方向键选「$desc」回车`n" +
              "  4. 什么都不按，10 秒后进原系统`n`n" +
              "日志：$($Script:LogFile)") -Kind 'Info'

    Write-Log '===== 修复完成 ====='

} catch {
    $msg = $_.Exception.Message
    Write-Log "失败: $msg" 'ERROR'

    # 改坏了就还原 BCD。
    # 用 bcdedit /import 而不是把文件复制回去 —— 文件路径那条路会被共享冲突挡住，
    # 而且活动存储根本没法用文件句柄写。
    if ($bcdBackup -and (Test-Path -LiteralPath $bcdBackup)) {
        $rs = Restore-BcdStore -Src $bcdBackup
        if ($rs.Ok) {
            $restored = $true
            Write-Log '已将 BCD 还原为修改前的备份' 'WARN'
        } else {
            Write-Log ("BCD 还原失败！可手动执行：  bcdedit /import `"{0}`"   原因：{1}" -f $bcdBackup, $rs.Text) 'ERROR'
        }
    }

    # 备份失败、或者 /import 也失败时，BCD 里可能还留着本次 /copy 出来的条目：
    # 描述是新系统的名字，设备却指向原系统 —— 菜单里多一个点进去就回原系统的坑。
    # 单独删掉它。删不掉也只是多一项，不影响能启动的系统。
    if ($newGuid -and (-not $restored)) {
        $rb = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $newGuid) -Tag 'rollback-catch'
        if ($rb.Ok) {
            Write-Log "已删除本次创建的条目 $newGuid（回滚）" 'WARN'
        } else {
            Write-Log ("本次创建的条目 $newGuid 删不掉（菜单里会多一项，可跑「急救工具\修好菜单指向」或在 bcdedit 里手动删）：{0}" -f $rb.Text) 'WARN'
        }
    }

    Show-Box ("修复失败。`n`n$msg`n`n日志：$($Script:LogFile)") -Kind 'Error'

} finally {
    if ($mounted -and $VhdPath) { [void](Dismount-VhdSafe -Path $VhdPath) }
    if ($espLetter) { Release-EspLetter -Letter $espLetter }
}
