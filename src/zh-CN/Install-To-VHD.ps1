#Requires -Version 5.1
<#
  虚拟硬盘系统 - 安装器主程序
  把 .wim 系统镜像安装成一个独立的虚拟硬盘系统，不碰原系统。
  作者：connectsegabot

  原理：
    1. 在指定分区创建一个 .vhdx 虚拟磁盘文件
    2. 在虚拟磁盘里建**一个** NTFS 分区（native boot 的硬性要求：只能有一个）
    3. 用 DISM 把镜像应用到该分区
    4. 用 bcdedit 在**活动 BCD 存储**里加一条 device=vhd=[...] 的启动项
       （活动存储就在物理 ESP 上，但走 BCD API 而不是文件读写，见下）
  重启后开机菜单会多一项，选它进新系统，选原来的进老系统。

  两个踩过的坑，别改回去：

  (1) 不要改回「在 vhdx 里建 ESP + 用 bcdboot」。
      UEFI 固件只读物理磁盘上的 ESP，vhdx 内部的 ESP 它永远看不到，
      结果 bcdboot 报成功、重启却没有菜单（v1.3）。

  (2) 不要改回「给物理 ESP 挂盘符，再读写 S:\EFI\Microsoft\Boot\bcd」。
      运行中的系统握着那个 BCD 的句柄，文件级访问必撞共享冲突：
          文件"S:\EFI\Microsoft\Boot\bcd"正由另一进程使用
      bcdedit 不带 /store 操作的就是活动存储 —— 它本身就在物理 ESP 上，
      不需要盘符、不碰文件、不会有共享冲突（v1.5）。
#>

param(
    # 自动搜索镜像的根目录（可多个，逗号分隔）
    [string]$SearchRoot = '',
    # 目标分区盘符
    [string]$TargetDrive = '',
    # 虚拟磁盘大小 GB
    [int]$SizeGB = 0,
    # 控制台模式：只检查不安装
    [switch]$ConsoleMode,
    # 用户把本程序放在哪个目录（由 bat 传入，因为解包后 $PSScriptRoot 指向临时目录）
    [string]$OriginDir = ''
)

$ErrorActionPreference = 'Stop'
$Script:OriginDir = $OriginDir
$Script:Version = '1.32'
$Script:ProductName = '虚拟硬盘系统'

# ---- 这些必须在注册异常钩子之前定义好 ----
$Script:TempDir = [System.IO.Path]::GetTempPath()
if (-not $Script:TempDir) { $Script:TempDir = 'C:\Windows\Temp\' }
$Script:LogDate = (Get-Date).ToString('yyyyMMdd')
$Script:LogName = "$($Script:ProductName)-$($Script:LogDate).log"
$Script:LogFile = Join-Path $Script:TempDir $Script:LogName
# 【v1.29】日志目录可以在选定安装位置后重定向（见 Set-LogDir）：
# 以前不管装到哪，日志都躺在 %TEMP%，BCD 备份还撒在 vhdx 旁边。
# 现在统一放到 <安装位置>\虚拟硬盘系统-日志\ 下面。
$Script:LogDir = $Script:TempDir
try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogFile', $Script:LogFile) } catch {}
try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogDir', $Script:LogDir) } catch {}
# 默认虚拟硬盘文件名刻意用纯 ASCII：diskpart 的 /s 脚本文件在非中文代码页下
# 会把中文变成 ?，报「文件名、目录名或卷标语法不正确」。
# v1.11 起用户可以自己起名，普通中文名没问题（diskpart 脚本已改用 ANSI/GBK 写，
# 见 Invoke-Diskpart 的注释），只有 ASCII 之外的生僻字/emoji 会被建议剔除。
$Script:DefaultDiskName = 'WinVHD'
$Script:VhdFileName = 'WinVHD.vhdx'

# 支持的镜像格式
$Script:ImagePatterns = @('*.wim', '*.esd', '*.iso')
$Script:SupportedExts = @('.wim', '.esd', '.iso')

# 全局未处理异常钩子：把出错行号写进日志，避免 WinForms 默认弹窗吞掉信息
$Script:LastError = ''
$fatalLogPath = $Script:LogFile
$fatalDir = $Script:TempDir
$fatalHandler = {
    param($s, $e)
    try {
        $ex = $e.ExceptionObject
        $msg = ''
        if ($ex -is [System.Management.Automation.RuntimeException]) {
            $msg = $ex.Message
            if ($ex.ErrorRecord -and $ex.ErrorRecord.InvocationInfo) {
                $ii = $ex.ErrorRecord.InvocationInfo
                $msg = "$msg" + [char]13 + [char]10 + "  出错位置: $($ii.ScriptName):$($ii.ScriptLineNumber)  行内容: $($ii.Line)"
            }
        } else {
            $msg = $ex.ToString()
        }
        $stamp = (Get-Date).ToString('HH:mm:ss')
        # 【v1.29】日志路径可能在安装开始时被 Set-LogDir 改走，闭包里捕获的是旧值，
        # 这里优先用 AppDomain 数据槽里的当前值，取不到才退回捕获值。
        $lp = $null
        $fd = $null
        try { $lp = [System.AppDomain]::CurrentDomain.GetData('VHDX.LogFile') } catch {}
        try { $fd = [System.AppDomain]::CurrentDomain.GetData('VHDX.LogDir') } catch {}
        if (-not $lp) { $lp = $fatalLogPath }
        if (-not $fd) { $fd = $fatalDir }
        Add-Content -LiteralPath $lp -Value "[$stamp] [FATAL] $msg" -Encoding UTF8 -EA SilentlyContinue
        [System.IO.File]::WriteAllText((Join-Path $fd 'fatal.txt'), $msg, [System.Text.Encoding]::UTF8)
    } catch {}
}
[System.AppDomain]::CurrentDomain.add_UnhandledException($fatalHandler.GetNewClosure())

# ============================================================
# 基础
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line = '[{0}] [{1}] {2}' -f $stamp, $Level, $Message
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 -EA SilentlyContinue } catch {}
}

# 【v1.29】附属产物的落脚点：<vhdx 所在目录>\虚拟硬盘系统-日志\
#
# 为什么不再直接放 vhdx 旁边：
#   · YYYYMMDD.log 一天一个，bcd-backup-*.bcd 一次一个，堆几次就一片
#   · bcdedit /export 还会额外生成 .LOG / .LOG1 / .LOG2 三个伴生文件
#   · 用户把 vhdx 放在 D:\ 根的时候，这些东西直接糊在盘根上
# 统一收进一个子目录，vhdx 旁边就只剩 vhdx 和它的 .boot.txt。
function Get-SideLogDir {
    param([string]$VhdPath)
    $base = Split-Path -Parent $VhdPath
    if (-not $base) { return $Script:TempDir }
    $dir = Join-Path $base "$($Script:ProductName)-日志"
    if (-not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {}
    }
    # 建不出来（只读盘、权限）就退回 vhdx 所在目录，绝不因为日志挪不动而中断安装
    if (Test-Path -LiteralPath $dir) { return $dir }
    return $base
}

# 把正在写的日志搬到安装位置下面（已写下的内容一起带过去）
function Set-LogDir {
    param([string]$VhdDir)
    if (-not $VhdDir) { return }
    try {
        $dir = Join-Path $VhdDir "$($Script:ProductName)-日志"
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -EA Stop | Out-Null
        }
    } catch {
        Write-Log "日志目录建不出来，继续留在临时目录：$VhdDir（$($_.Exception.Message)）" 'WARN'
        return
    }
    $newFile = Join-Path $dir $Script:LogName
    if ($newFile -ieq $Script:LogFile) { return }
    # 只有从临时目录第一次切出来时才搬运，避免「装第二个系统时把第一个的日志也搬过去」
    $fromTemp = ($Script:LogFile -ieq (Join-Path $Script:TempDir $Script:LogName))
    if ($fromTemp) {
        try {
            if (Test-Path -LiteralPath $Script:LogFile) {
                $oldText = Get-Content -LiteralPath $Script:LogFile -Encoding UTF8 -Raw -EA SilentlyContinue
                if ($oldText) { Add-Content -LiteralPath $newFile -Value $oldText.TrimEnd() -Encoding UTF8 -EA SilentlyContinue }
                Remove-Item -LiteralPath $Script:LogFile -Force -EA SilentlyContinue
            }
        } catch {}
    }
    $Script:LogFile = $newFile
    $Script:LogDir = $dir
    try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogFile', $newFile) } catch {}
    try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogDir', $dir) } catch {}
    Write-Log "日志位置: $newFile"
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
# 系统名称 / 文件名（v1.11 起支持一台机器装多个系统）
# ============================================================
#
# 两件事必须分开：
#   名称  = 开机菜单里显示的文字，随便写，可以是中文、可以有空格
#   文件名= 磁盘上的 .vhdx 文件，同一块盘里必须唯一
#
# 允许中文文件名：diskpart /s 脚本改用 ANSI(GBK) 写（见 Invoke-Diskpart），
# 中文在 GBK 里能正确落地。真正要挡的是文件系统非法字符和 emoji（GBK 编不出来）。

$Script:BadNameChars = @('\', '/', ':', '*', '?', '"', '<', '>', '|')

function Get-SafeDiskName {
    param([string]$Raw)
    $n = ''
    if ($Raw) { $n = $Raw.Trim() }
    foreach ($c in $Script:BadNameChars) { $n = $n.Replace($c, '') }
    # 【v1.27】括号是 BCD 设备路径的语法字符，名字里绝不能带。
    #
    # 真机案例：镜像版本名 "Windows Server 2022 Standard (Desktop Experience)"
    # 直接当成了 vhdx 文件名，于是 bcdedit 写进去的是
    #   vhd=[D:]\Windows Server 2022 Standard (Desktop Experience).vhdx
    # bcdedit 把 ( ) 当定界符解析，读回来变成
    #   vhd=[D:]\Windows Server 2022 Standard (Desktop Experience.vhdx,locate=...
    # 右括号被吃掉、路径被截断 —— 条目看着在、实际无效。
    # 更麻烦的是进了那个系统后，Windows 注册 WinRE 时也按这套语法拼 ramdisk 路径，
    # 拼出来是坏的，会连带把 BCD 里别的启动项搞丢。
    # 统一换成 -：可读性不变，也不再给 BCD 留坑。
    $n = ($n -replace '[\(\)\[\]\{\}]', '-')
    $n = ($n -replace '-{2,}', '-').Trim('-', ' ', '.')
    # 去掉控制字符
    $n = ($n -replace '[\x00-\x1F]', '')
    # 压缩连续空白
    $n = ($n -replace '\s{2,}', ' ')
    # Windows 文件名不许以点或空格结尾
    $n = $n.TrimEnd('.', ' ')
    if (-not $n) { $n = $Script:DefaultDiskName }
    if ($n.Length -gt 48) { $n = $n.Substring(0, 48).TrimEnd('.', ' ') }
    # 保留名
    if ($n -match '^(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { $n = "$n-" }
    return $n
}

# 这个名字能不能被系统 ANSI 代码页编码？不能的话 diskpart 会写出 ?，文件按问号名建出来，
# 再 Test-Path 原名就找不到。
#
# [审计 P1-5] 这里以前写死 GBK(936)。英文系统（ACP=1252）上中文名能通过校验，diskpart 却把路径写成
# "???.vhdx"，于是"名字明明是合法的却创建失败"，还留下垃圾文件。现在跟 Invoke-Diskpart 写脚本时
# 用的是同一个编码。
function Test-EncodableName {
    param([string]$Name)
    try {
        $enc = Get-AnsiEncoding
        $back = $enc.GetString($enc.GetBytes($Name))
        return ($back -eq $Name)
    } catch {
        return $false
    }
}

# 在指定目录里找一个不冲突的 vhdx 文件名：名称 / 名称-2 / 名称-3 ...
#
# v1.11 起用户能自己选目录（不只是盘根），所以这里收的是完整目录而不是盘符。
# 传盘符（"D"）也兼容，内部会补成 "D:\"。
function Get-UniqueVhdPath {
    param([string]$Folder, [string]$DiskName)
    $base = Get-SafeDiskName $DiskName
    $dir = $Folder
    if (-not $dir) { $dir = "$env:SystemDrive\" }
    if ($dir -match '^[A-Za-z]$') { $dir = "$($dir):\" }
    $dir = $dir.TrimEnd('\')
    if (-not $dir) { $dir = [System.IO.Path]::GetPathRoot($Folder).TrimEnd('\') }
    if ($dir -match '^[A-Za-z]:$') { $dir = "$dir\" }
    $cand = Join-Path $dir "$base.vhdx"
    if (-not (Test-Path -LiteralPath $cand)) { return $cand }
    for ($i = 2; $i -le 99; $i++) {
        # 【v1.27】后缀也用 -2 而不是 (2)：同样的 BCD 括号问题，见 Get-SafeDiskName
        $cand = Join-Path $dir "$base-$i.vhdx"
        if (-not (Test-Path -LiteralPath $cand)) { return $cand }
    }
    throw "同一个目录下已经有太多同名系统了（$base 1~99），换个名称或换个目录再试。"
}

# 把完整路径转成 BCD 里 vhd= 的设备写法。
#
# 必须保留中间的子目录！v1.12 及以前这里用 GetFileName() 只取了文件名，
# 装到 D:\虚拟磁盘\maimai.vhdx 时菜单被写成 vhd=[D:]\maimai.vhdx（该文件根本不存在），
# 结果启动项建好了、菜单里也有，一选就 0xc000000f 找不到文件。
#
#   D:\虚拟磁盘\maimai.vhdx   ->   vhd=[D:]\虚拟磁盘\maimai.vhdx
function Get-VhdBcdDevice {
    param([string]$FullPath)
    if (-not $FullPath) { throw '内部错误：没有传虚拟磁盘路径' }
    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetPathRoot($full)
    if (-not $root -or $root.Length -lt 3) { throw "路径无效（需要完整路径，如 D:\VHD\x.vhdx）：$FullPath" }
    $letter = $root.Substring(0, 1).ToUpper()
    $rel = $full.Substring($root.Length).TrimStart('\')
    if (-not $rel) { throw "路径无效：$FullPath" }
    return "vhd=[$($letter):]\$rel"
}

# 反向解析：vhd=[D:]\虚拟磁盘\maimai.vhdx -> D:\虚拟磁盘\maimai.vhdx
# 用来把 bcdedit 读回来的内容跟真实路径逐字比对。
function Get-FullPathFromBcdDevice {
    param([string]$Dev)
    if (-not $Dev) { return '' }
    $m = [regex]::Match($Dev, '^vhd=\[([A-Za-z]):\]\\(.+)$')
    if (-not $m.Success) { return '' }
    return ("{0}:\{1}" -f $m.Groups[1].Value.ToUpper(), $m.Groups[2].Value)
}

# bcdedit 的输出走控制台代码页，打不出来的字会变成 "?"。英文启动器开头是 chcp 437，
# 中文路径于是整个变成 "?"，写对了也被判成写错。BCD 里存的是原文，比较时要容忍这一点。
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

# 完全绕开控制台的第二种判据：把 BCD 导出成文件，在 hive 里按 UTF-16 找这段路径
# （BCD 就是注册表 hive，字符串元素是 UTF-16 存的）。导不出来时返回 $null。
function Test-BcdStoresPath {
    param([string]$Path)
    if (-not $Path) { return $null }
    $tmp = Join-Path $env:TEMP ("bcd-verify-{0}.bcd" -f ([guid]::NewGuid().ToString('N')))
    try {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        [void](& bcdedit /export $tmp 2>&1 | Out-String)
        if (-not (Test-Path -LiteralPath $tmp)) { return $null }
        $bytes = [System.IO.File]::ReadAllBytes($tmp)
        foreach ($off in 0, 1) {
            $len = $bytes.Length - $off - (($bytes.Length - $off) % 2)
            if ($len -le 0) { continue }
            $s = [System.Text.Encoding]::Unicode.GetString($bytes, $off, $len)
            if ($s.IndexOf($Path, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
        return $false
    } catch {
        return $null
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

# [审计 P0-1] 找到刚挂上的那块盘：按完整路径找，绝不只看文件名。
#
# 原来写的是 "Location -like *文件名*"，只要同名的盘就命中，紧接着就是 select disk N + clean。
# 机器上并存 D:\A\WinVHD.vhdx 和 E:\Backup\WinVHD.vhdx（另一块盘上放个备份就够），
# 就可能把不相干的那块盘的分区表清掉。
#
# 三级判定，一级比一级保守：
#   1. Location 等于完整路径（忽略大小写，容忍 \\?\ 前缀）→ 采用
#   2. 文件名相同，但全机只有一个 → 采用
#   3. 文件名相同且有多个 → 直接报错，绝不挑一个
# 什么都没找到时返回 $null。
function Resolve-VhdDisk {
    param([string]$VhdPath, $Disks)
    if (-not $VhdPath) { return $null }
    $full = [System.IO.Path]::GetFullPath($VhdPath)
    $leaf = [System.IO.Path]::GetFileName($full)

    $clean = {
        param($p)
        if (-not $p) { return '' }
        $s = [string]$p
        if ($s.StartsWith('\\?\')) { $s = $s.Substring(4) }
        return $s.Trim()
    }

    $exact = @($Disks | Where-Object {
        $loc = & $clean $_.Location
        if (-not $loc) { return $false }
        return [string]::Equals($loc, $full, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($exact.Count -eq 1) { return $exact[0] }
    if ($exact.Count -gt 1) {
        throw ("有两块盘都声称来自同一个文件：{0}`n{1}`n`n没有动任何东西。" -f $full,
               (($exact | ForEach-Object { '    磁盘 ' + $_.Number }) -join "`n"))
    }

    $byName = @($Disks | Where-Object {
        $loc = & $clean $_.Location
        if (-not $loc) { return $false }
        return ([System.IO.Path]::GetFileName($loc) -eq $leaf)
    })
    if ($byName.Count -eq 1) { return $byName[0] }
    if ($byName.Count -gt 1) {
        throw (("机器上有多个挂载中的虚拟硬盘都叫 '{0}'：`n{1}`n`n没有动任何东西。" -f $leaf,
               (($byName | ForEach-Object { '    磁盘 ' + $_.Number + ': ' + $_.Location }) -join "`n")) +
              "把其它那个卸掉或改名后再试。")
    }
    return $null
}

# 扫出各固定 NTFS 盘里的所有 vhdx（含子目录，最多 3 层）。
#
# 注意不能用 Get-ChildItem -LiteralPath "D:\*"：-LiteralPath 不展开通配符，
# 会把 "*" 当成字面目录名去找，永远 0 结果。必须用 -Path。
# 跳过回收站等目录，否则清空回收站前会把已删除的文件当成装好的系统列出来。
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

# 把用户写的/选出来的路径规范化成完整目录，并做校验。
# 返回 @{ Ok = $true/false; Folder = 规范化的目录; Msg = 提示文字 }
function Test-TargetFolder {
    param([string]$Raw)
    $r = @{ Ok = $false; Folder = ''; Msg = '' }
    $p = ''
    if ($Raw) { $p = $Raw.Trim().Trim('"').TrimEnd('\') }
    if (-not $p) { $r.Msg = '请填写要存放的文件夹'; return $r }

    # 用户只写了盘符（D: 或 D）→ 当作 D:\
    if ($p -match '^[A-Za-z]$') { $p = "$($p):\" }
    if ($p -match '^[A-Za-z]:$') { $p = "$p\" }

    if ($p -notmatch '^[A-Za-z]:\\') {
        $r.Msg = '要写完整路径，例如 D:\VHD'; return $r
    }
    if ($p -match '(^|\\)\.\.?(\\|$)') {
        $r.Msg = '路径里不要用 . 或 ..'; return $r
    }
    if (-not (Test-EncodableName $p)) {
        $r.Msg = '路径里有系统代码页表示不了的字（emoji 等），请换一个'; return $r
    }
    # [审计 P1-6] 括号在 BCD 设备路径里是语法字符：vhd=[D:]\My (Games)\WinVHD.vhdx 会在 ")" 处被截断
    # （见 Get-SafeDiskName 里 v1.27 的说明）。以前只清洗文件名，文件夹名就这么原样过去了。
    if ($p -match '[\(\)\[\]\{\}]') {
        $r.Msg = '文件夹名里有 ( ) [ ] 或 { }，启动项表达不了这些字符。请换一个不带括号的文件夹，例如 D:\VHD'; return $r
    }
    if (-not (Test-Path -LiteralPath $p)) {
        $r.Msg = "这个文件夹还不存在：$p"
        return $r
    }
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        $r.Msg = "这是个文件，不是文件夹：$p"
        return $r
    }

    # 必须是本地固定盘：网络盘/光驱不可靠（native boot 开机时根本挂不上）
    $letter = $p.Substring(0, 1).ToUpper()
    $vol = Get-Volume -DriveLetter $letter -EA SilentlyContinue
    if (-not $vol) { $r.Msg = "找不到 $letter`: 这个盘"; return $r }
    if ($vol.DriveType -ne 'Fixed') {
        $r.Msg = "$letter`: 不是本地硬盘（U 盘/网络盘/光驱都不行，开机时读不到）"; return $r
    }
    if ($vol.FileSystem -ne 'NTFS') {
        $r.Msg = "$letter`: 是 $($vol.FileSystem) 分区，必须用 NTFS（可能是 exFAT/FAT32）"; return $r
    }

    # 不能放在系统盘的最外层几个受保护目录里（权限/被系统占用）
    $sysDrive = "$($env:SystemDrive.ToUpper())\"
    $lc = $p.ToLower()
    foreach ($bad in @("$($sysDrive.ToLower())windows", "$($sysDrive.ToLower())program files",
                       "$($sysDrive.ToLower())program files (x86)", "$($sysDrive.ToLower())programdata",
                       "$($sysDrive.ToLower())users")) {
        if ($lc -eq $bad -or $lc.StartsWith($bad + '\')) {
            $r.Msg = '别放进 Windows / Program Files / Users 这些系统目录，换个文件夹'; return $r
        }
    }

    $r.Ok = $true
    $r.Folder = $p
    return $r
}

# 这个目录所在的分区还剩多少（GB）；失败返回 -1
#
# 【v1.12】以前只用 Get-Volume 的 SizeRemaining。实测有翻车：
# 同一块盘 Get-Volume / Get-PSDrive / DriveInfo 都报告 436 GB 可用，
# 但界面上却弹「剩余 0 KB」。Volume 对象的 SizeRemaining 在某些场景下会取到 0
# （卷刚挂载、WMI 属性未刷新、或者盘符与卷的关联短暂不一致）。
# 这里改成三路取数，取「最大且有效」的那个：
#   1. Get-Volume 的 SizeRemaining
#   2. [System.IO.DriveInfo] 的 AvailableFreeSpace（直接问文件系统，最贴近真实写入）
#   3. Get-PSDrive 的 Free
# 任何一路返回 > 0 就采信，避免单一来源的错误把用户挡在门外。
function Get-DiskFreeBytes {
    param([string]$Folder)
    $vals = @()
    if (-not $Folder) { return -1 }
    $letter = ''
    if ($Folder -match '^([A-Za-z]):') { $letter = $Matches[1].ToUpper() }
    if (-not $letter) { return -1 }

    try {
        $v = Get-Volume -DriveLetter $letter -EA Stop
        if ($v -and $null -ne $v.SizeRemaining -and [int64]$v.SizeRemaining -gt 0) {
            $vals += [int64]$v.SizeRemaining
        }
    } catch {}

    try {
        $di = New-Object System.IO.DriveInfo("$($letter):\")
        if ($di.IsReady) {
            if ($di.AvailableFreeSpace -gt 0) { $vals += [int64]$di.AvailableFreeSpace }
            elseif ($di.TotalFreeSpace -gt 0) { $vals += [int64]$di.TotalFreeSpace }
        }
    } catch {}

    try {
        $pd = Get-PSDrive -Name $letter -PSProvider FileSystem -EA Stop
        if ($pd -and $null -ne $pd.Free -and [int64]$pd.Free -gt 0) { $vals += [int64]$pd.Free }
    } catch {}

    if (@($vals).Count -eq 0) {
        # 三路都拿不到数：区分「盘不存在」(-1) 和「盘存在但报告 0」(0)
        try {
            $di2 = New-Object System.IO.DriveInfo("$($letter):\")
            if (-not $di2.IsReady) { return -1 }
            return 0
        } catch {
            return -1
        }
    }
    # [审计 P3] 取三个来源里的最小值，不是最大值。这个数字是给空间预检用的，
    # 预检永远不能乐观：Get-Volume、DriveInfo、Get-PSDrive 三个说法不一致时（配额、过滤驱动、
    # 缓存过期），按小的那个算才不会装到一半没空间。
    $min = [int64](($vals | Measure-Object -Minimum).Minimum)
    $max = [int64](($vals | Measure-Object -Maximum).Maximum)
    if ($max -gt 0 -and $min -lt ($max * 0.9)) {
        Write-Log ("可用空间的几个来源对不上：最小 {0} / 最大 {1} 字节，按小的算" -f $min, $max) 'WARN'
    }
    return $min
}

function Get-FreeGB {
    param([string]$Folder)
    $b = Get-DiskFreeBytes $Folder
    if ($b -lt 0) { return -1 }
    return [math]::Round($b / 1GB, 1)
}

# 目录真实可写探针：写一个 64MB 的临时文件再删掉。
#
# 为什么必须做：上面的统计口径再准也只是「报告值」。真正决定成败的是
# 「这个目录能不能写进去这么大的文件」——配额、磁盘压缩、去重、镜像卷、
# 父目录的拒绝写入 ACL、甚至「虚拟磁盘」这类被某些同步/备份软件挂钩的目录，
# 都可能让报告值很漂亮但实际写不进去。更狠的是反向情况：
# 报告值 0、实际能写（这次就是这个），光看报告值会把用户拦死。
#
# 结果返回 @{ Ok=bool; Msg=string; BytesPerSec=... }，
# 其中 Msg 在失败时是一句可读的原因说明。
function Test-FolderWritable {
    param([string]$Folder, [int]$ProbeMB = 64)
    $r = @{ Ok = $false; Msg = '' }
    if (-not $Folder) { $r.Msg = '没有指定目录'; return $r }
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        $r.Msg = "这个文件夹不存在：$Folder"
        return $r
    }
    $probe = $null
    try {
        $probe = Join-Path $Folder ('.vhdspace_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
        $buf = New-Object byte[] (1MB)
        $fs = [System.IO.File]::Open($probe, [System.IO.FileMode]::Create,
                                     [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $fs.SetLength([int64]$ProbeMB * 1MB)   # 稀疏写入，速度快且真的占配额
            $fs.Flush()
        } finally {
            $fs.Close()
        }
        $len = (New-Object System.IO.FileInfo($probe)).Length
        if ($len -lt ([int64]$ProbeMB * 1MB)) {
            $r.Msg = "写测试失败：只能写到 $([math]::Round($len / 1MB)) MB"
        } else {
            $r.Ok = $true
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match 'denied|拒绝|未授权') {
            $r.Msg = '这个文件夹没有写入权限（可能被安全软件保护，或父目录设了拒绝写入）'
        } elseif ($msg -match 'space|空间|磁盘已满') {
            $r.Msg = '往这个文件夹里写测试文件时磁盘满了'
        } elseif ($msg -match 'read-only|只读|写保护') {
            $r.Msg = '这个分区是只读的'
        } else {
            $r.Msg = "写测试失败：$msg"
        }
    } finally {
        if ($probe) {
            try { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force -EA SilentlyContinue } } catch {}
        }
    }
    return $r
}

# 列出这台机器上已经装过的虚拟硬盘系统
#
# v1.11 起允许自定义存放目录，所以不能只看盘根：扫各固定 NTFS 盘根目录
# 往下两层（够覆盖 D:\VHD 这种习惯用法，又不会把整个盘遍历一遍）。
function Find-InstalledSystems {
    $found = @()
    # v1.13：改走 Get-AllVhdxFile，子目录里装的也能列出来。
    # 旧写法用 Get-ChildItem -LiteralPath (Join-Path $root '*')，-LiteralPath 不展开通配符，
    # 子目录扫描等于没写，D:\虚拟磁盘\maimai.vhdx 这种永远列不出来。
    foreach ($f in @(Get-AllVhdxFile)) {
        # 统一走共享函数：Desc → Name → Description 依次退让，谁写的状态文件都能读出名字
        $desc = Get-StateDisplayName -VhdPath $f.FullName
        $found += [PSCustomObject]@{
            Path = $f.FullName
            Name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            Desc = $desc
            SizeGB = [math]::Round($f.Length / 1GB, 1)
        }
    }
    return $found
}

# ============================================================
# diskpart 统一入口（所有 diskpart 调用都必须走这里）
#
# 三件事必须一起做，少一件就会踩坑：
#
# 1) 脚本文件用 **ANSI（当前系统代码页，中文系统即 GBK）** 写，不能用 ASCII。
#    ASCII 编码器会把所有非 ASCII 字符替换成 '?'：
#    路径 "D:\新系统.vhdx" 变成 "D:\???.vhdx"
#    → DiskPart 报「文件名、目录名或卷标语法不正确」
#    → 但文件已被创建成那个问号名字，所以 Test-Path 原路径会失败、
#      脚本却以为自己把 VHD 挂上了。双重误导。
#    实测（Build 26200）：Encoding.ASCII 写出 44 3A 5C 3F 3F 3F 2E 76 68 64 78
#
# 2) 行尾必须 CRLF。diskpart /s 用 LF 也能吃，但混合编码下容易出错，统一 CRLF。
#
# 3) $LASTEXITCODE 判返回值**不可靠**（在 PowerShell 里调 diskpart 常常拿到 $null），
#    必须解析输出文本。英文环境的错误文本是 "DiskPart has encountered an error"，
#    中文环境是 "DiskPart 遇到错误"，两个都要匹配。
# ============================================================

# 取当前系统 ANSI 代码页的编码对象（中文系统 = GBK/936）
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

    $f = Join-Path $Script:TempDir ("dp-$Tag-$(Get-Random).txt")
    # 手工拼 CRLF：不赌 StringBuilder.AppendLine 用哪个换行符
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

function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N0} MB' -f ($bytes / 1MB)) }
    return ('{0:N0} KB' -f ($bytes / 1KB))
}

# ============================================================
# WIM 校验
# ============================================================

# ============================================================
# ISO 挂载
# ============================================================

# 挂载 ISO，返回 { Ok, Drive, Path, Name, Error }
# Path/Name 是里面找到的 install.wim / install.esd 的完整路径与文件名
function Open-IsoImage {
    param([string]$Path)
    $r = [PSCustomObject]@{ Ok = $false; Drive = ''; Path = ''; Name = ''; Error = '' }

    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = 'ISO 文件不存在'; return $r }

    # 挂载：优先用 Mount-DiskImage（Win8+ 自带），否则用 PowerShell 的 COM 方式
    $mounted = $false
    if (Get-Command Mount-DiskImage -EA SilentlyContinue) {
        try {
            Mount-DiskImage -ImagePath $Path -EA Stop | Out-Null
            $mounted = $true
        } catch {
            $r.Error = "挂载 ISO 失败：$($_.Exception.Message)"
            return $r
        }
    } else {
        $r.Error = '系统不支持挂载 ISO（需要 Windows 8 及以上）'
        return $r
    }

    # 等盘符出现
    $drive = ''
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        try {
            $di = Get-DiskImage -ImagePath $Path -EA SilentlyContinue
            if ($di -and $di.Attached) {
                $vols = $di | Get-Volume -EA SilentlyContinue
                foreach ($v in $vols) {
                    if ($v.DriveLetter) { $drive = $v.DriveLetter; break }
                }
                if ($drive) { break }
            }
        } catch {}
    }
    if (-not $drive) {
        try { Dismount-DiskImage -ImagePath $Path -EA SilentlyContinue | Out-Null } catch {}
        $r.Error = 'ISO 挂载后没有拿到盘符'
        return $r
    }
    $r.Drive = $drive

    # 在 ISO 里找镜像：优先 sources\install.wim，其次 sources\install.esd
    $cands = @(
        "$($drive):\sources\install.wim",
        "$($drive):\sources\install.esd",
        "$($drive):\sources\open.wim",
        "$($drive):\sources\boot.wim"
    )
    foreach ($c in $cands) {
        if (Test-Path -LiteralPath $c) {
            $r.Ok = $true
            $r.Path = $c
            $r.Name = [System.IO.Path]::GetFileName($c)
            return $r
        }
    }

    # 兜底：递归找一边（有些第三方 ISO 目录结构不同）
    try {
        $found = Get-ChildItem -LiteralPath "$($drive):\" -Filter 'install.*' -File -Recurse -Depth 3 -EA SilentlyContinue |
                 Where-Object { $_.Extension -in '.wim', '.esd' } | Select-Object -First 1
        if ($found) {
            $r.Ok = $true
            $r.Path = $found.FullName
            $r.Name = $found.Name
            return $r
        }
    } catch {}

    $r.Error = 'ISO 里找不到 sources\install.wim 或 install.esd，可能不是 Windows 安装盘'
    return $r
}

# 读 WIM/ESD 尾部的 XML 元数据（可能有多段，全部解码后合并）。
#
# 为什么不直接调 dism /Get-WimInfo：
#   * 每次要 1~3 秒，界面里每换一个镜像就卡一下；
#   * 精简系统 / PE 里不一定有 dism；
#   * 索引号、索引名、解压后大小本来全都写在这段 XML 里。
# Test-WimFile 和 Get-ImageIndexList 共用它，免得两份解析逻辑各写一遍然后漂移。
function Read-WimXml {
    param([string]$Path)

    $r = [PSCustomObject]@{ Ok = $false; Xml = ''; Error = '' }
    if (-not $Path) { $r.Error = '没有指定文件'; return $r }
    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = '文件不存在'; return $r }

    try {
        $fi = Get-Item -LiteralPath $Path
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $magic = New-Object byte[] 8
            [void]$fs.Read($magic, 0, 8)
            if ([System.Text.Encoding]::ASCII.GetString($magic) -notlike 'MSWIM*') {
                $r.Error = '不是 WIM/ESD 镜像文件（文件头不是 MSWIM）'
                return $r
            }

            $cap = [int64]4MB
            $tailLen = if ($fi.Length -lt $cap) { [int]$fi.Length } else { [int]$cap }
            $fs.Seek($fi.Length - $tailLen, [System.IO.SeekOrigin]::Begin) | Out-Null
            $tail = New-Object byte[] $tailLen
            [void]$fs.Read($tail, 0, $tailLen)
        } finally { $fs.Close() }
    } catch {
        $r.Error = "读取出错：$($_.Exception.Message)"
        return $r
    }

    $xml = ''
    for ($i = 0; $i -le $tail.Length - 8; $i += 2) {
        if ($tail[$i] -ne 0x3C -or $tail[$i + 1] -ne 0x00 -or
            $tail[$i + 2] -ne 0x57 -or $tail[$i + 3] -ne 0x00) { continue }

        $xmlLen = [math]::Floor(($tail.Length - $i) / 2) * 2
        $raw = [System.Text.Encoding]::Unicode.GetString($tail, $i, $xmlLen)

        $cut = [math]::Max($raw.LastIndexOf('</WIM>'), $raw.LastIndexOf('</WINDOWS>'))
        if ($cut -gt 0) {
            $cutLen = if ($raw.Substring($cut).StartsWith('</WINDOWS>')) { 10 } else { 6 }
            # 【v1.25】取到就 break，不能再往后扫。
            # 这个循环找的是 UTF-16 的「<W」，而 XML 里每个 <WINDOWS> 都是一处命中：
            # 以前写 $xml += ... 且不 break，于是同一个 XML 被反复拼接（实测一份真实
            # 单索引镜像里 '</WIM>' 出现了 3 次，XML 从 ~1300 字膨胀到 2551 字）。
            # 单索引靠「正则取第一个」侥幸没暴露；多索引（如 Server 2022 的 4 个版本）
            # 会让 <IMAGE> 计数和版本表成倍重复，版本下拉里出现一堆重复项。
            $xml = $raw.Substring(0, $cut + $cutLen)
            break
        }
    }
    if (-not $xml) { $r.Error = '镜像元数据无法解析，文件可能损坏'; return $r }

    $r.Ok = $true
    $r.Xml = $xml
    return $r
}

# 列出镜像里的每一个索引（也就是「版本」），返回 @(PSCustomObject{Index; Name; Desc})。
#
# 一个 install.wim 里可以塞好几个系统：Windows Server 的官方 ISO 就是
#   1 Standard(Core)  2 Standard(桌面体验)  3 Datacenter(Core)  4 Datacenter(桌面体验)
# 以前固定装索引 1，对 Server 来说正好是「没有图形界面」的那个，装完只有黑框框。
function Get-ImageIndexList {
    param([string]$Path)

    $list = @()
    if (-not $Path) { return $list }

    $xml = ''
    $isIso = ([System.IO.Path]::GetExtension($Path).ToLower() -eq '.iso')
    if ($isIso) {
        $inner = Open-IsoImage -Path $Path
        if (-not $inner.Ok) { return $list }
        try {
            $rd = Read-WimXml -Path $inner.Path
            if ($rd.Ok) { $xml = $rd.Xml }
        } finally {
            Close-IsoImage -Drive $inner.Drive -IsoPath $Path
        }
    } else {
        $rd = Read-WimXml -Path $Path
        if ($rd.Ok) { $xml = $rd.Xml }
    }

    if ($xml) {
        # <IMAGE INDEX="1"> ... </IMAGE>：用前瞻切段，别用非贪婪 .*?</IMAGE> ——
        # 有些镜像的 IMAGE 里没有 DIRCOUNT/SIZE 这些段，贪一点就会串到下一个索引上。
        foreach ($m in [regex]::Matches($xml, '(?s)<IMAGE\s([^>]*)>(.*?)(?=<IMAGE\s|$)')) {
            $attrs = $m.Groups[1].Value
            $body = $m.Groups[2].Value
            $im = [regex]::Match($attrs, 'INDEX="(\d+)"')
            if (-not $im.Success) { continue }

            $nm = ''
            $mm = [regex]::Match($body, '<DISPLAYNAME>(.*?)</DISPLAYNAME>')
            if ($mm.Success) { $nm = $mm.Groups[1].Value.Trim() }
            if (-not $nm) {
                $mm = [regex]::Match($body, '<NAME>(.*?)</NAME>')
                if ($mm.Success) { $nm = $mm.Groups[1].Value.Trim() }
            }
            if (-not $nm) { $nm = '索引 ' + $im.Groups[1].Value }

            $desc = ''
            $md = [regex]::Match($body, '<DESCRIPTION>(.*?)</DESCRIPTION>')
            if ($md.Success) { $desc = $md.Groups[1].Value.Trim() }

            $list += [PSCustomObject]@{
                Index = [int]$im.Groups[1].Value
                Name  = $nm
                Desc  = $desc
            }
        }
    }

    if (@($list).Count -eq 0) {
        # 退路：XML 解不出来（第三方工具重整过的 WIM）才问 dism
        $names = @(Get-ImageIndexNames -Path $Path)
        for ($i = 0; $i -lt $names.Count; $i++) {
            $list += [PSCustomObject]@{ Index = ($i + 1); Name = $names[$i]; Desc = '' }
        }
    }

    return ($list | Sort-Object Index)
}

# 把版本名翻成人话。重点是 Server 的 Core / 桌面体验 —— 这两个名字太像，
# 装错了要重来一遍（20 分钟）。
function Format-EditionLabel {
    param([string]$Name, [string]$Desc = '')

    $n = [string]$Name
    if (-not $n) { return '（未命名）' }

    $hasDesktop = $false
    if ($n -match '(?i)Desktop\s*Experience') {
        $hasDesktop = $true
        $n = ($n -replace '(?i)\s*[(（]\s*Desktop\s*Experience\s*[)）]', '').Trim()
    }
    if (-not $hasDesktop -and $Desc -match '(?i)Desktop\s*Experience') { $hasDesktop = $true }

    if ($hasDesktop) { return "$n　（桌面体验：有图形界面）" }
    if ($n -match '(?i)server') { return "$n　（无图形界面 / Server Core）" }
    return $n
}

# 用 DISM 列出镜像里的所有索引名称，返回字符串数组（失败返回空数组）
function Get-ImageIndexNames {
    param([string]$Path)
    $names = @()
    try {
        $out = & dism.exe /English /Get-WimInfo /WimFile:"$Path" 2>&1 | Out-String
        foreach ($m in [regex]::Matches($out, '(?m)^\s*Name\s*:\s*(.+?)\s*$')) {
            $names += $m.Groups[1].Value.Trim()
        }
    } catch {}
    return $names
}

# 挑一个真正能装成系统的索引（1 起）。
# 官方 ISO 的 install.esd / install.wim 索引 1 有时是「Windows PE」或「Windows Setup」，
# 直接按 1 装出来是个不能用的东西，这里跳过它们。
function Select-ImageIndex {
    param([string]$Path, [int]$Preferred = 1)
    if ($Preferred -lt 1) { $Preferred = 1 }
    $names = Get-ImageIndexNames -Path $Path
    if (@($names).Count -eq 0) { return $Preferred }

    $bad = '^(Windows PE|Windows Setup|Microsoft Windows PE|Windows Recovery)'
    if ($Preferred -le @($names).Count) {
        if ($names[$Preferred - 1] -notmatch $bad) { return $Preferred }
    }
    for ($i = 0; $i -lt @($names).Count; $i++) {
        if ($names[$i] -notmatch $bad) { return ($i + 1) }
    }
    return 1
}

function Close-IsoImage {
    param([string]$Drive, [string]$IsoPath = '')
    if (-not $Drive) { return }

    # 首选：按路径卸载。
    # 注意 Get-DiskImage 不带 -ImagePath 会报「强制参数丢失」，所以绝不能靠枚举。
    if ($IsoPath) {
        try {
            $di = Get-DiskImage -ImagePath $IsoPath -EA Stop
            if ($di.Attached) {
                Dismount-DiskImage -ImagePath $IsoPath -EA Stop | Out-Null
                Start-Sleep -Milliseconds 400
                return
            }
        } catch {}
    }

    # 兜底：只拿到盘符时，用 Storage 模块的 MSFT_DiskImage 反查路径
    try {
        foreach ($di in (Get-CimInstance -ClassName MSFT_DiskImage -Namespace 'root/Microsoft/Windows/Storage' -EA SilentlyContinue)) {
            $diPath = $di.ImagePath
            if (-not $diPath) { continue }
            try {
                $obj = Get-DiskImage -ImagePath $diPath -EA Stop
                if (-not $obj.Attached) { continue }
                $vs = $obj | Get-Volume -EA SilentlyContinue
                foreach ($v in $vs) {
                    if ($v.DriveLetter -eq $Drive) {
                        Dismount-DiskImage -ImagePath $diPath -EA Stop | Out-Null
                        Start-Sleep -Milliseconds 400
                        return
                    }
                }
            } catch {}
        }
    } catch {}
}

# 把用户选的镜像解析成「DISM 真正能吃的文件路径」
# .wim / .esd 直接返回；.iso 先挂载，返回里面 sources\install.wim 或 install.esd
# 返回 { Ok, Path, IsoDrive, Kind, Error }，用完必须用 Close-IsoImage -Drive $r.IsoDrive 卸载
function Resolve-RealImage {
    param([string]$Path)

    $r = [PSCustomObject]@{ Ok = $false; Path = ''; IsoDrive = ''; IsoPath = ''; Kind = ''; Error = '' }
    if (-not $Path) { $r.Error = '没有指定镜像文件'; return $r }

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($ext -eq '.iso') {
        $inner = Open-IsoImage -Path $Path
        if (-not $inner.Ok) { $r.Error = $inner.Error; return $r }
        $r.Ok = $true
        $r.Path = $inner.Path
        $r.IsoDrive = $inner.Drive
        $r.IsoPath = $Path
        $r.Kind = 'ISO'
        return $r
    }

    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = '镜像文件不存在'; return $r }
    $r.Ok = $true
    $r.Path = $Path
    if ($ext -eq '.esd') { $r.Kind = 'ESD' } else { $r.Kind = 'WIM' }
    return $r
}

function Test-WimFile {
    param([string]$Path)

    $r = [PSCustomObject]@{
        Valid    = $false
        Error    = ''
        SizeGB   = 0
        UncompGB = 0
        Images   = 0
        Name     = ''
        Build    = ''
        Kind     = 'WIM'
        # 多版本镜像的索引表。ISO 在外层就顺手解析掉（那时已挂载，省一次挂载）。
        IndexList = @()
    }

    if (-not $Path) { $r.Error = '没有指定文件'; return $r }
    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = '文件不存在'; return $r }

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $r.Kind = switch ($ext) { '.esd' { 'ESD' } '.iso' { 'ISO' } default { 'WIM' } }

    # ISO 先挂载，取出里面的 install.wim / install.esd 再继续校验
    if ($ext -eq '.iso') {
        $inner = Open-IsoImage -Path $Path
        if (-not $inner.Ok) { $r.Error = $inner.Error; return $r }
        $r.Kind = 'ISO'
        try {
            $innerInfo = Test-WimFile -Path $inner.Path
            if (-not $innerInfo.Valid) {
                $r.Error = "ISO 里的 $($inner.Name) 不可用：$($innerInfo.Error)"
                return $r
            }
            $fi = Get-Item -LiteralPath $Path
            $r.SizeGB = [math]::Round($fi.Length / 1GB, 2)
            $r.Valid = $true
            $r.Name = "$($innerInfo.Name)  〔ISO〕"
            $r.Build = $innerInfo.Build
            $r.Images = $innerInfo.Images
            $r.UncompGB = $innerInfo.UncompGB
            # 趁 ISO 还挂着，把版本索引表一起解出来 —— 否则界面那边为了列版本
            # 还得再挂一次 ISO（多花 1~2 秒，还会闪一下光驱）
            $r.IndexList = @($innerInfo.IndexList)
            if (@($r.IndexList).Count -le 1 -and $r.Images -gt 1) {
                $r.IndexList = @(Get-ImageIndexList -Path $inner.Path)
            }
            $r | Add-Member -NotePropertyName IsoMount -NotePropertyValue $inner.Drive -Force
            return $r
        } finally {
            Close-IsoImage -Drive $inner.Drive -IsoPath $Path
        }
    }

    $fi = Get-Item -LiteralPath $Path
    $r.SizeGB = [math]::Round($fi.Length / 1GB, 2)

    # 读尾部 XML 的那段逻辑抽到 Read-WimXml 了，这里和 Get-ImageIndexList 共用
    $rd = Read-WimXml -Path $Path
    if (-not $rd.Ok) {
        $r.Error = $rd.Error
        return $r
    }
    $xml = $rd.Xml

    $r.Images = ([regex]::Matches($xml, '<IMAGE\s')).Count
    if ($r.Images -lt 1) { $r.Images = 1 }

    $m = [regex]::Match($xml, '<DISPLAYNAME>(.*?)</DISPLAYNAME>')
    if (-not $m.Success) { $m = [regex]::Match($xml, '<NAME>(.*?)</NAME>') }
    if ($m.Success) { $r.Name = $m.Groups[1].Value }

    $mB = [regex]::Match($xml, '<BUILD>(\d+)</BUILD>')
    $mS = [regex]::Match($xml, '<SPBUILD>(\d+)</SPBUILD>')
    if ($mB.Success) {
        $r.Build = if ($mS.Success) { "$($mB.Groups[1].Value).$($mS.Groups[1].Value)" } else { $mB.Groups[1].Value }
    }

    $maxTb = [int64]0
    foreach ($mt in [regex]::Matches($xml, '<TOTALBYTES>(\d+)</TOTALBYTES>')) {
        $v = [int64]$mt.Groups[1].Value
        if ($v -gt $maxTb) { $maxTb = $v }
    }
    if ($maxTb -gt 0) { $r.UncompGB = [math]::Round($maxTb / 1GB, 2) }

    if (-not $r.Name) { $r.Error = '镜像缺少名称信息，可能不是系统镜像'; return $r }

    # [审计 P3] 架构不对的镜像当场拒掉。x86 / ARM64 镜像能顺利装完，然后永远起不来，
    # 用户要等 20 分钟装完 + 重启才发现。WIM 的 <ARCH>：0=x86 5=ARM 6=Itanium 9=x64 12=ARM64。
    $mArch = [regex]::Match($xml, '<ARCH>(\d+)</ARCH>')
    if ($mArch.Success) {
        $arch = [int]$mArch.Groups[1].Value
        if (@(0, 5, 6, 12) -contains $arch) {
            $archName = switch ($arch) { 0 { 'x86（32 位）' } 5 { 'ARM' } 6 { 'Itanium' } 12 { 'ARM64' } }
            $r.Error = "这个镜像是 $archName 的。启动项里的 vhd= 原生启动只支持 x64 系统，请换 x64 镜像。"
            return $r
        }
    }

    # 多索引才去解析版本表（单索引没必要，反正只有它）
    if ($r.Images -gt 1) { $r.IndexList = @(Get-ImageIndexList -Path $Path) }

    $r.Valid = $true
    return $r
}

# ============================================================
# 分区枚举
# ============================================================

# 列出「能放 vhdx」的分区。
#
# 【v1.16 修正】原来这里无条件 `if ($v.DriveLetter -eq $sysLetter) { continue }`，
# 把系统盘整个剔掉了。单盘机器（只有 C:）于是返回空列表 → 界面进 else 分支，
# 连「浏览...」和路径输入框一起被禁用 —— 用户明明有 500 GB 空着，却一个按钮都点不了，
# 也没法手动指定 C 盘下的文件夹（Test-TargetFolder 那边其实是允许 C 盘的）。
#
# 现在系统盘也返回，只打 IsSystem 标记，由界面决定怎么提示 + 排到列表最后。
# 想排除系统盘就传 -ExcludeSystem（目前没有调用方这么用，留给以后）。
function Get-TargetVolumes {
    param([switch]$ExcludeSystem)
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $list = @()
    foreach ($v in (Get-Volume -EA SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        if (-not $v.DriveType) { continue }
        # 必须是本地固定盘：U 盘 / 网络盘 / 光驱开机时都读不到，native boot 起不来
        if ($v.DriveType -ne 'Fixed') { continue }
        if ($v.FileSystem -ne 'NTFS') { continue }
        $isSys = ($v.DriveLetter -eq $sysLetter)
        if ($isSys -and $ExcludeSystem) { continue }
        $free = Get-DiskFreeBytes ("$($v.DriveLetter):\")
        if ($free -lt 10GB) { continue }
        $list += [PSCustomObject]@{
            Letter   = $v.DriveLetter
            Label    = $v.FileSystemLabel
            Free     = $free
            Total    = $v.Size
            FreeGB   = [math]::Round($free / 1GB, 1)
            TotalGB  = [math]::Round($v.Size / 1GB, 1)
            IsSystem = $isSys
        }
    }
    # 非系统盘排前面：默认选中第一个就是「推荐的那个」
    return ($list | Sort-Object @{ Expression = { [int]$_.IsSystem } }, Letter)
}

function Find-WimFiles {
    param([string]$Roots)

    $results = @()
    $dirs = @()
    if ($Roots) {
        $dirs += ($Roots -split ',' | ForEach-Object { $_.Trim() })
    } else {
        # $PSScriptRoot 是解包后的临时目录，不是用户放 bat 的目录，
        # 所以要把 OriginDir（bat 传入的 %~dp0）也加进来
        $roots = @()
        if ($Script:OriginDir) { $roots += $Script:OriginDir }
        if ($PSScriptRoot) { $roots += $PSScriptRoot }
        foreach ($r in $roots) {
            if (-not $r) { continue }
            $dirs += $r
            try {
                $parent = [System.IO.Path]::GetDirectoryName($r)
                if ($parent) { $dirs += $parent }
            } catch {}
        }
        $profileDir = $env:USERPROFILE
        if (-not $profileDir) { $profileDir = [Environment]::GetFolderPath('UserProfile') }
        if ($profileDir) {
            $dirs += (Join-Path $profileDir 'Downloads')
            $dirs += (Join-Path $profileDir 'Desktop')
        }
        # 【已取消】原来会把每个盘的根目录都加进来扫，太慢太重：
        #   21GB 的 wim 只为了列个名字也要扫，而盘符根目录下通常什么都没有。
        #   现在只认「用户放 bat 的目录、其上级、桌面、下载」这四类，
        #   外加用户自己在下拉框里选的搜索目录。放的别处可以用「浏览」按钮指定。
    }

    foreach ($d in $dirs) {
        if (-not $d) { continue }
        try {
            if (-not (Test-Path -LiteralPath $d)) { continue }
            foreach ($pat in $Script:ImagePatterns) {
                # 先扫本层
                $items = Get-ChildItem -LiteralPath $d -Filter $pat -File -EA SilentlyContinue
                if ($items) { foreach ($it in $items) { $results += $it.FullName } }
                # 非盘符根目录的，再往下扫两层（大众常把镜像放在子文件夹）
                if ($d -notmatch '^[A-Za-z]:\\?$') {
                    $sub = Get-ChildItem -LiteralPath $d -Filter $pat -File -Recurse -Depth 2 -EA SilentlyContinue
                    if ($sub) { foreach ($it in $sub) { $results += $it.FullName } }
                }
            }
        } catch {}
    }

    if (-not $results) { return @() }

    # 明显的非 Windows 安装盘直接不列出来，免得用户看到一串「有效=False」心慌
    $noise = @('kali', 'ubuntu', 'debian', 'centos', 'fedora', 'archlinux',
               'manjaro', 'linuxmint', 'opensuse', 'alpine', 'freebsd', 'pfsense',
               'proxmox', 'esxi', 'vsphere', 'memtest', 'gparted')
    $win = @()
    foreach ($p in ($results | Select-Object -Unique)) {
        $leaf = [System.IO.Path]::GetFileName($p).ToLower()
        if ([System.IO.Path]::GetExtension($p).ToLower() -eq '.iso') {
            $isNoise = $false
            foreach ($k in $noise) { if ($leaf -like "*$k*") { $isNoise = $true; break } }
            if ($isNoise) { continue }
        }
        $win += $p
    }
    return $win
}

# ============================================================
# 主体：安装到虚拟磁盘
# ============================================================

# 卸载虚拟磁盘：优先 Hyper-V 模块，没有就用 diskpart（不依赖额外组件）
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

# 检查本机能不能创建 VHD/VHDX（Hyper-V 模块 或 diskpart 二者有其一即可）
function Test-VhdCapability {
    if (Get-Command New-VHD -EA SilentlyContinue) { return @{ Ok = $true; Mode = 'Hyper-V' } }
    # 没有 Hyper-V 模块也没关系，diskpart 自带 create vdisk
    if (Get-Command diskpart -EA SilentlyContinue) {
        $build = [int](Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue).BuildNumber
        # Win7/2008R2 不支持 vhdx，win8 及以上才支持
        if ($build -ge 9200) { return @{ Ok = $true; Mode = 'diskpart' } }
        return @{ Ok = $false; Mode = ''; Reason = '系统版本过旧，不支持 VHDX（需要 Windows 8 / Server 2012 以上）' }
    }
    return @{ Ok = $false; Mode = ''; Reason = '找不到 diskpart，系统环境异常' }
}

# ============================================================
# 引导：在物理 ESP 的 BCD 里加一条 vhd= 启动项
#
# 【为什么不能再用 bcdboot】
# bcdboot 只会把启动文件写到「你指定的那个分区」。而虚拟磁盘内部的 ESP，
# UEFI 固件根本不会去读 —— 固件只认物理磁盘上的 ESP。
# 所以 v1.3 及以前无论怎么调 bcdboot 参数，结果都是「exit=0 但重启没菜单」，
# 甚至会把 C:\EFI、C:\Boot 写出来当垃圾（/f ALL 的坑）。
#
# native boot VHD 的正确做法：
#   vhdx 里：单个 NTFS 分区（系统文件）
#   物理ESP：/EFI/Microsoft/Boot/BCD 里加一条
#            device  = vhd=[D:]\NewSystemDisk.vhdx
#            osdevice= vhd=[D:]\NewSystemDisk.vhdx
#            path    = \Windows\system32\winload.efi
# ============================================================

$GUID_ESP   = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
$GUID_MSR   = 'e3c9e316-0b5c-4db8-817d-f92df00215ae'

function Get-PartGpt {
    param($Partition)
    $t = [string]$Partition.GptType
    return ($t -replace '[{}]', '').ToLower()
}

# 找物理磁盘上的 ESP（按系统盘所在磁盘定位，不会误选虚拟磁盘）
function Find-PhysicalEsp {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $sysPart = Get-Partition -DriveLetter $sysLetter -EA SilentlyContinue
    if (-not $sysPart) { return $null }
    foreach ($p in (Get-Partition -DiskNumber $sysPart.DiskNumber -EA SilentlyContinue)) {
        if ((Get-PartGpt $p) -eq $GUID_ESP) { return $p }
    }
    return $null
}

# 给 ESP 临时挂盘符。Set-Partition 在不干净的挂载状态下会报
# "The requested access path is already in use."，所以多候选 + mountvol 兜底。
function Mount-EspLetter {
    param([int]$DiskNumber, [int]$PartitionNumber)

    $p = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -EA SilentlyContinue
    if ($p -and $p.DriveLetter) { return @{ Ok = $true; Letter = [string]$p.DriveLetter; Mode = '已有盘符' } }

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
    try { Remove-PartitionAccessPath -DriveLetter $Letter -EA SilentlyContinue | Out-Null } catch {}
    if (Test-Path -LiteralPath ("{0}:\EFI" -f $Letter)) {
        try { & mountvol ("{0}:" -f $Letter) /D 2>&1 | Out-Null } catch {}
    }
}

# bcdedit 统一入口。
#
# 【为什么不用 /store —— v1.5 的核心修正】
# 原来是把物理 ESP 挂个盘符，再把 S:\EFI\Microsoft\Boot\bcd 当普通文件复制/改写。
# 真机上直接撞锁：
#     文件"S:\EFI\Microsoft\Boot\bcd"正由另一进程使用，因此该进程无法访问此文件
# 运行中的系统自己握着那个 BCD 的句柄，文件级访问必被拒。
# bcdedit 不带 /store 时操作的是「活动 BCD 存储」，也就是当前系统实际启动用的
# 那一份 —— 它本来就存在物理 ESP 上。改它等于改物理 ESP，且不需要盘符、
# 不碰文件、不会有共享冲突。
#
# $Store 传空字符串 = 活动存储。
function Invoke-BcdEdit {
    param([string]$Store = '', [string[]]$BcdArgs, [string]$Tag = '')

    $all = @()
    if ($Store) { $all += @('/store', $Store) }
    $all += $BcdArgs

    $txt = ''
    try { $txt = (& bcdedit @all 2>&1 | Out-String) } catch { $txt = "调用异常: $($_.Exception.Message)" }
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

# 备份活动 BCD 存储：走 bcdedit /export（BCD API），不是文件复制，绕开文件锁。
# 失败也不阻断安装：后面只新增条目 + 改菜单超时，都能用 bcdedit 反向撤回。
function Backup-BcdStore {
    param([string]$Dest)
    # 【v1.29】bcdedit /export 导出的是一个注册表 hive，Windows 会顺手在目标旁边
    # 生成 X.bcd.LOG / X.bcd.LOG1 / X.bcd.LOG2 三个事务日志。
    # 以前直接导出到 vhdx 目录，结果那里堆了几十个 .bcd.LOG*，删了 .bcd 也留着。
    # 现在先导到临时目录，只把 .bcd 拷到目的地，临时文件连三个伴生 LOG 一起清掉。
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

# 装/修启动条目。返回 @{ Ok; Guid; Desc; BcdPath; Backup; Error }
# $ExistingGuid 非空时先删掉旧条目（重复运行不叠加）
function Install-BootEntry {
    param(
        [string]$VhdFullPath,
        [string]$ExistingGuid = '',
        [string]$EditionName = '',      # 镜像版本名，名称留空时的兜底
        [string]$DisplayName = ''       # 用户给这个系统起的名字，直接作为开机菜单文字
    )

    $r = [PSCustomObject]@{
        Ok = $false; Guid = ''; Desc = ''; BcdPath = ''
        Backup = ''; EspLetter = ''; OrigTimeout = '30'; OrigDisplay = ''
        OrigDisplaySet = '0'    # 安装前 BCD 里是否真的写过 displaybootmenu（1=写过，0=本来没有）
        Error = ''
    }

    if ((Get-FirmwareType) -ne 2) {
        $r.Error = '只支持 UEFI。这台机器是 Legacy BIOS，虚拟磁盘启动需要另一套引导方式。'
        return $r
    }

    # ---------- 定位活动 BCD 存储 ----------
    #
    # 不挂载物理 ESP、不读写 BCD 文件。原因见 Invoke-BcdEdit 上面的注释：
    # ESP 上的 bcd 被运行中的系统占用，文件级访问必撞共享冲突。
    #
    # 仍然把 ESP 找出来只为了日志能看出「菜单落在哪块盘」，找不到不影响流程。
    $esp = Find-PhysicalEsp
    if ($esp) {
        Write-Log ("物理 ESP（仅记录，不挂载）: 磁盘 {0} 分区 {1}，{2:N0} MB" -f
                   $esp.DiskNumber, $esp.PartitionNumber, ($esp.Size / 1MB))
    } else {
        Write-Log '没能定位物理 ESP（不影响：启动项写在活动 BCD 存储上）' 'WARN'
    }
    $r.BcdPath = '活动 BCD 存储'

    # 备份：改坏了要能还原
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    # 【v1.29】备份进「虚拟硬盘系统-日志」，不再散落在 vhdx 旁边
    $backupDir = Get-SideLogDir -VhdPath $VhdFullPath
    $backup = Join-Path $backupDir ("bcd-backup-$stamp.bcd")
    $bk = Backup-BcdStore -Dest $backup
    if ($bk.Ok) {
        $r.Backup = $backup
        Write-Log ("BCD 已备份（{0}，{1} 字节）: {2}" -f $bk.Mode, $bk.Size, $backup)
    } else {
        Write-Log ("BCD 备份失败，仍然继续（只新增条目 + 改菜单超时，可用 bcdedit 撤回）: {0}" -f $bk.Error) 'WARN'
        $r.Backup = ''
    }

    # 重复运行时先删掉上次的条目
    if ($ExistingGuid -and $ExistingGuid -match '^\{[0-9a-fA-F-]{36}\}$') {
        Write-Log "删除上次留下的启动条目 $ExistingGuid"
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $ExistingGuid) -Tag 'del-old')
    }

    # 记下原 bootmgr 设置，卸载时要还原
    $bm = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm').Raw
    $m = [regex]::Match($bm, '(?im)^\s*timeout\s+(\d+)')
    if ($m.Success) { $r.OrigTimeout = $m.Groups[1].Value }

    # BCD 里从来没有设过 displaybootmenu 时，/enum 输出里根本不会有这一行。
    # 这时不能当成「原值是 No」写死，要单独记一个标记 OrigDisplaySet=0：
    #
    #   单系统机器：没设过 → 本来就不弹菜单
    #   多系统机器：没设过 → 本来正常弹菜单（双系统就靠它选）
    #
    # 两种情况的最终效果都是「没设过」，所以卸载时要用 bcdedit /deletevalue 恢复成
    # 「未设置」，而不是硬设 No —— 硬设 No 会把多系统用户的菜单一起关掉。
    $r.OrigDisplay = 'No'
    $r.OrigDisplaySet = '0'
    if ($bm -match '(?im)^\s*displaybootmenu\s+(\S+)') {
        $r.OrigDisplay = $matches[1]
        $r.OrigDisplaySet = '1'
    }
    Write-Log "原 bootmgr: timeout=$($r.OrigTimeout) displaybootmenu=$($r.OrigDisplay)（显式写入=$($r.OrigDisplaySet)）"

    # 数一下机器上已经有几个系统。多系统机器上这次安装只是「加一项」，
    # 别人的启动项一律不碰；卸载后菜单也会按原样还原。
    $osCount = 0
    $osRaw = ''
    try {
        $osRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', 'osloader') -Tag 'oslist').Raw
        $osCount = ([regex]::Matches($osRaw, '(?m)^\s*(?:identifier|标识符)\s+\{')).Count
    } catch {}
    if ($osCount -ge 1) {
        Write-Log "机器上已有 $osCount 个启动项（多系统）：本次只新增一项，原有条目不动"
    }

    # 复制「当前正在运行的这个系统」的启动项。
    #
    # 用 {current} 而不是 {default}：多系统机器上 {default} 可能指向另一个系统，
    # 复制它会得到错误的 osdevice/path，新条目实际指向别人的系统。
    # 括号必须带引号，否则 PowerShell 会把 {current} 当成脚本块。
    #
    # 指向 vhdx。盘符用 vhdx 文件所在的卷，路径用方括号语法
    #
    # 【v1.13】必须用完整相对路径，不能只取文件名。
    #   D:\虚拟磁盘\maimai.vhdx  ->  vhd=[D:]\虚拟磁盘\maimai.vhdx
    # v1.12 写成 vhd=[D:]\maimai.vhdx，文件其实在子目录里 → 菜单能建、一点就找不到文件。
    $vhdDrive = [System.IO.Path]::GetPathRoot($VhdFullPath).Substring(0, 1).ToUpper()
    $dev = Get-VhdBcdDevice $VhdFullPath
    Write-Log "device => $dev"

    # 开机菜单文字（v1.11）：
    #   用户给了名称 → 直接用（这样一台机器装多个系统时，菜单里各自是什么一目了然）
    #   没给 → 退回「镜像版本名（虚拟系统）」
    # 重名时补上盘符区分，否则开机菜单里会出现两行一模一样的文字，根本不知道选哪个。
    if ($DisplayName) {
        $desc = $DisplayName
    } elseif ($EditionName) {
        $desc = "$EditionName（虚拟系统）"
    } else {
        $desc = 'Windows（虚拟系统）'
    }
    if ($osRaw -and ($osRaw -match [regex]::Escape($desc))) {
        $desc = "$desc ($($vhdDrive):)"
        Write-Log "已有同名启动项，描述改为「$desc」以便区分"
    }
    # 建新启动条目：/copy 优先，无源（BCD 主加载项被清空）时 /create 从零建。
    # v1.18 之前只写死 {current} 退回 {default}，一旦 BCD 主加载项被弄丢就装不动；
    # v1.19 起连 osloader 里都只剩 Recovery 时，也走 /create 造一条全新加载项。
    $nb = New-BootEntryGuid -Desc $desc
    if (-not $nb.Guid) {
        $r.Error = $nb.Error
        return $r
    }
    $guid = $nb.Guid
    $r.Guid = $guid
    Write-Log "新启动条目: $guid（来源：$($nb.Tag)）"

    # 指向 vhdx 的设备路径（$dev）已在复制条目之前算好，这里直接写入
    $allOk = $true
    foreach ($s in @(
        @('/set', $guid, 'device',   $dev),
        @('/set', $guid, 'osdevice', $dev),
        @('/set', $guid, 'path',     '\Windows\system32\winload.efi')
    )) {
        $x = Invoke-BcdEdit -Store '' -BcdArgs $s -Tag 'set'
        if (-not $x.Ok) { $allOk = $false }
    }
    if (-not $allOk) {
        $r.Error = "写入启动条目参数失败。日志：$($Script:LogFile)"
        return $r
    }

    # 校验：vhd= 真的写进去了吗（被拦截时 bcdedit 可能假成功）
    $chk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify'
    if ($chk.Raw -notmatch '(?i)vhd=') {
        $r.Error = "启动条目里没写进 vhd= 设备路径，BCD 写入被拦截了。$($chk.Text)"
        return $r
    }

    # 【v1.13】逐字核对 device 指向的路径。
    # vhd= 写进去了、但指向别处（比如少了子目录），和没写进去一样致命：
    # 菜单里有这一项，一选就 0xc000000f 找不到文件。必须当场发现问题。
    $wantFull = [System.IO.Path]::GetFullPath($VhdFullPath)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        # [审计 P1-4] 不要依赖字段名：bcdedit 在德语系统上写 "Gerät"、日语写 "デバイス"、中文写 "设备"。
        # 字段名对不上会被当成「路径写错了」，其实写对了。带 vhd= 的只有 device 那一行。
        $dm = [regex]::Match($chk.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
        $backFull = ''
        if ($dm.Success) { $backFull = Get-FullPathFromBcdDevice $dm.Groups[1].Value.Trim() }
        # 路径里的中文被打成 "?" 只是控制台显示不出来，BCD 里存的是对的
        if (Test-BcdTextSame $wantFull $backFull) {
            if ($backFull -ne $wantFull) {
                Write-Log ("路径读回是 ""{0}""：控制台代码页显示不了这些字，BCD 里存的是 {1}" -f $backFull, $wantFull) 'WARN'
            }
            break
        }
        # 还是不一样：直接问 BCD 存储本身，绕开控制台
        $stored = Test-BcdStoresPath $wantFull
        if ($stored -eq $true) {
            Write-Log '控制台把回读显示弄花了，但导出的 BCD 存储里确实是正确路径' 'WARN'
            break
        }
        Write-Log ("设备路径读回不一致（第 {0} 次）：期望 {1}，实际 {2}" -f $attempt, $wantFull, $backFull) 'WARN'
        if ($attempt -ge 2) {
            $r.Error = ("启动菜单指向的文件路径不对，装完也进不去。`n`n" +
                        "应该指向：$wantFull`n实际写成：$backFull`n`n" +
                        "如果「实际写成」里是「?」而路径本来有中文，那只是控制台代码页的显示问题：" +
                        "可以先 chcp 936 再 bcdedit /enum $guid 看一眼。`n" +
                        "否则多半是改 BCD 时虚拟磁盘还挂载着，bcdedit 把 vhd= 换成了 partition=X:。`n" +
                        "可以运行「急救工具\修好菜单指向」重试，或换个不含中文的目录再装。")
            return $r
        }
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'device',   $dev) -Tag 'fixdev')
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'osdevice', $dev) -Tag 'fixosdev')
        $chk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify-retry'
    }
    # 中文描述偶尔会因命令行编码丢字，读回确认一下。
    # v1.11：判据从「必须含『虚拟系统』」改成「读回来等于我写的 $desc」——
    # 用户自定义名称里通常不含「虚拟系统」四个字，用旧判据会把好名字误判成写入失败。
    $descBack = ''
    # [审计 P1-4] 判定改成「输出里有没有我刚写进去的那串文字」，不再按字段名取：
    # 字段名在德语系统是 "Beschreibung"、日语 "説明"、中文 "描述"。
    $descBack = ''
    if ($chk.Raw -match [regex]::Escape($desc)) { $descBack = $desc }
    if ($descBack -ne $desc) {
        # 被 "?" 遮住只是显示问题，别因此把名字换成英文
        $looseDesc = ($desc -replace '[^\x20-\x7E]', '?')
        $looseRaw = ($chk.Raw -replace '[^\x20-\x7E]', '?')
        if ($looseRaw -match [regex]::Escape($looseDesc)) {
            $descBack = $desc
            Write-Log "描述被控制台代码页遮住了，保留「$desc」" 'WARN'
        }
    }
    if ($descBack -ne $desc) {
        Write-Log "描述读回不一致（期望「$desc」，实际「$descBack」），改用不含中文的写法" 'WARN'
        $asciiName = ($desc -replace '[^\x20-\x7E]', '').Trim()
        if (-not $asciiName) { $asciiName = if ($EditionName) { "$EditionName (VHD)" } else { 'Windows (VHD)' } }
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'description', $asciiName) -Tag 'desc-en')
        $desc = $asciiName
    }
    $r.Desc = $desc

    # 必须打开开机菜单：timeout=0 / displaybootmenu=No 时会直接进默认系统，看不到选项
    [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu')
    if ($r.OrigTimeout -eq '0') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout')
        Write-Log '原 timeout=0，已改成 10 秒，否则看不到菜单'
    }

    $r.Ok = $true
    return $r
}

function Invoke-Install {
    param(
        [string]$WimPath,
        [string]$TargetFolder,          # 存放目录（完整路径，如 D:\VHD，也兼容只传 "D"）
        [int]$SizeGB,
        [int]$ImageIndex = 1,
        [string]$EditionName = '',      # 镜像里的版本名（如「Windows 10 专业版」）
        [string]$DiskName = '',         # 用户给这个系统起的名字（决定 vhdx 文件名 + 菜单文字）
        [scriptblock]$OnProgress,
        [scriptblock]$OnStatus
    )
    $DriveLetter = ''
    if ($TargetFolder) { $DriveLetter = $TargetFolder.Substring(0, 1).ToUpper() }

    $report = {
        param($pct, $msg)
        if ($OnProgress) { & $OnProgress $pct }
        if ($OnStatus) { & $OnStatus $msg }
    }

    # 【v1.11】不再写死 NewSystemDisk.vhdx，按用户给的名字生成，重名自动加 (2)(3)
    $safeName = Get-SafeDiskName $DiskName
    if (-not (Test-EncodableName $safeName)) {
        throw ("名称「$safeName」里有系统编码不支持的字（emoji 等），无法用作文件名。`n请改成中文、英文、数字和常用符号。")
    }
    $folderChk = Test-TargetFolder $TargetFolder
    if (-not $folderChk.Ok) { throw "存放位置不可用：$($folderChk.Msg)" }
    $targetFolder = $folderChk.Folder
    $vhdPath = Get-UniqueVhdPath -Folder $targetFolder -DiskName $safeName
    $Script:VhdFileName = [System.IO.Path]::GetFileName($vhdPath)
    Write-Log "本次系统名称: $safeName   虚拟硬盘文件: $vhdPath"
    $mounted = $false
    $osLetter = $null
    $diskNum = -1
    $espLetter = ''
    $isoDrive = ''
    $isoPath = ''
    $realImage = $WimPath
    $bcdTriesReached = $false
    $bcdOk = $false

    # 【关键安全标志】只有「本次运行真正创建出来的 vhdx」才允许在失败时删除。
    #
    # 没有这个标志时的真实事故：目标文件已存在 → 预检 throw「已经装过一次了」→
    # 落到 catch，$bcdTriesReached 还是 false → $keepVhd=false → 把用户
    # **已经装好、可能正在使用的那个系统整个删掉**，而提示语还写着「请先运行卸载工具」。
    # 用户手滑点第二次安装就丢几十 GB 数据和整个系统。
    $createdHere = $false

    try {
        # ---------- 预检 ----------
        & $report 1 '检查环境...'

        if (-not (Test-Admin)) {
            throw '需要管理员权限。请右键本程序选择「以管理员身份运行」。'
        }
        if (Test-Path -LiteralPath $vhdPath) {
            throw "已经装过一次了。`n目标文件已存在：$vhdPath`n`n请先运行卸载工具，或手动删除该文件。"
        }

        # ---------- 解析镜像（ISO 要先挂载） ----------
        $ri = Resolve-RealImage -Path $WimPath
        if (-not $ri.Ok) { throw $ri.Error }
        $realImage = $ri.Path
        $isoDrive = $ri.IsoDrive
        $isoPath = $ri.IsoPath
        Write-Log "镜像格式: $($ri.Kind)  实际文件: $realImage"
        if ($ri.Kind -eq 'ISO') { Write-Log "ISO 已挂载到 $isoDrive`:" }

        $cap = Test-VhdCapability
        if (-not $cap.Ok) { throw $cap.Reason }
        Write-Log "虚拟磁盘方式: $($cap.Mode)"

        $needBytes = [int64]$SizeGB * 1GB
        # 和界面用同一套判定（三路取最大值 + 实测写入），不要在这里再信一次 Get-Volume
        $freeB = Get-DiskFreeBytes $targetFolder
        Write-Log ("预检空间: 报告剩余 {0}，需要 {1}" -f (Format-Size $freeB), (Format-Size ($needBytes + 5GB)))
        if ($freeB -lt ($needBytes + 5GB)) {
            $wchk = Test-FolderWritable -Folder $targetFolder -ProbeMB 64
            if (-not $wchk.Ok) {
                throw ("空间不足。目录 {0}: 报告剩余 {1}，需要 {2}。实际写入测试：{3}" -f `
                       $targetFolder, (Format-Size $freeB), (Format-Size ($needBytes + 5GB)), $wchk.Msg)
            }
            Write-Log "报告值偏小但实测可写，继续" 'WARN'
        }

        # ---------- 创建虚拟磁盘 ----------
        & $report 3 ("创建 {0} GB 虚拟磁盘..." -f $SizeGB)
        Write-Log "VHDX $vhdPath SizeMB=$([int]($needBytes / 1MB))"

        $diskNum = -1
        $hasHyperV = [bool](Get-Command New-VHD -EA SilentlyContinue)

        if ($hasHyperV) {
            # 优先用 Hyper-V 模块（能直接拿到 DiskNumber，最省事）
            try {
                $null = New-VHD -Path $vhdPath -SizeBytes $needBytes -Dynamic -EA Stop
                $createdHere = $true
                $h = Mount-VHD -Path $vhdPath -Passthru -EA Stop
                $mounted = $true
                Start-Sleep -Milliseconds 900
                $diskNum = $h.DiskNumber
                Write-Log "Hyper-V 模块路径，DiskNumber=$diskNum"
            } catch {
                Write-Log "Hyper-V 路径失败，转 diskpart: $($_.Exception.Message)" 'WARN'
                $diskNum = -1
            }
        }

        if ($diskNum -lt 0) {
            # 兜底：diskpart 原生 create vdisk，不需要 Hyper-V 模块
            & $report 3 '用 diskpart 创建虚拟磁盘...'
            $dp = Invoke-Diskpart -Tag 'mk' -Lines @(
                "create vdisk file=`"$vhdPath`" maximum=$([int]($needBytes / 1MB)) type=expandable",
                "select vdisk file=`"$vhdPath`"",
                'attach vdisk',
                'exit'
            )
            Write-Log "diskpart create+attach: $($dp.Text)"

            if (-not (Test-Path -LiteralPath $vhdPath)) {
                # 文件都不存在：直接报 diskpart 的原话，别猜
                $hint = ''
                if (-not $dp.Ok) { $hint = "`n`ndiskpart 提示：$($dp.Error)" }
                throw ("创建虚拟磁盘失败，文件没能建立。`n`n目标路径：$vhdPath$hint")
            }
            # 走到这里文件是本进程刚建出来的（预检已挡住「已存在」的情况）
            $createdHere = $true
            if (-not $dp.Ok) {
                # 文件建出来了但后续命令报错 → 别慌，先看是不是已经挂上了
                Write-Log "diskpart 有报错，继续尝试识别磁盘: $($dp.Error)" 'WARN'
            }
            $mounted = $true
            Start-Sleep -Milliseconds 1500

            # 从所有磁盘里找出刚挂载的那一个。
            #
            # 判定顺序（每一步都比「按容量猜」安全得多）：
            #   1. BusType = 'File Backed Virtual' —— vhdx/vhd 挂载后特有的总线类型，
            #      物理硬盘（NVMe / SATA / SAS / USB）绝不可能是它。这是最硬的判据。
            #   2. Location 里含 vhdx 文件名 —— 个别系统上 BusType 报得不准时兜底。
            #   3. 系统里只有一块虚拟磁盘 → 那必然是刚挂上的这块。
            #
            # 【已删除】原来还有一条「容量与目标值相差 64MB 以内、且非系统盘」的兜底。
            #   那是个会导致灾难的写法：紧接着就是 select disk + clean。机器上只要恰好
            #   有一块同容量的盘（小 SSD、U 盘、用户自己另一个 VHD），Location 匹配再失败，
            #   就会把整块盘的分区表清掉。找不到就报错让人看日志，绝不猜。
            $allDisks = @(Get-Disk -EA SilentlyContinue)
            $vhdDisks = @($allDisks | Where-Object { ([string]$_.BusType) -eq 'File Backed Virtual' })

            $hit = Resolve-VhdDisk -VhdPath $vhdPath -Disks $vhdDisks
            if (-not $hit) { $hit = Resolve-VhdDisk -VhdPath $vhdPath -Disks $allDisks }
            if ($hit) {
                $diskNum = $hit.Number
                Write-Log "按完整路径命中 Disk$diskNum（$($hit.Location)）"
            }
            if ($diskNum -lt 0 -and $vhdDisks.Count -eq 1) {
                # 最后一招：全机只有一块文件型虚拟盘。只有当它不是别的 vhdx 文件时才敢用——
                # 否则那是别的工具（Hyper-V、备份）的盘，绝不能 clean。
                $only = $vhdDisks[0]
                $onlyLoc = [string]$only.Location
                if ($onlyLoc) {
                    if ($onlyLoc.StartsWith('\\?\')) { $onlyLoc = $onlyLoc.Substring(4) }
                    $wantFull = [System.IO.Path]::GetFullPath($vhdPath)
                    if ([System.IO.Path]::GetFileName($onlyLoc) -ne [System.IO.Path]::GetFileName($wantFull)) {
                        throw ("唯一挂着的虚拟盘（Disk{0}）来自`n    {1}`n并不是这次创建的文件：`n    {2}`n`n没有动任何东西。" -f
                               $only.Number, $onlyLoc, $wantFull)
                    }
                }
                $diskNum = $only.Number
                Write-Log "系统里只有一块虚拟磁盘，判定为 Disk$diskNum"
            }

            if ($diskNum -lt 0) {
                $list = ($allDisks | ForEach-Object {
                    "  Disk {0}: {1}  BusType={2}  Location={3}" -f $_.Number, $_.FriendlyName, $_.BusType, $_.Location
                }) -join "`n"
                throw ("虚拟磁盘已创建并挂载，但没能确定它在系统里的磁盘编号。`n`n" +
                       "为避免误清空其它硬盘的分区表，这里不会按容量去猜。`n`n" +
                       "当前所有磁盘：`n$list`n`n" +
                       "请重启后重试；若反复出现，请把日志发给开发者。`n" +
                       "日志：$($Script:LogFile)")
            }
            Write-Log "diskpart 路径，DiskNumber=$diskNum"
        }

        if ($diskNum -lt 0) { throw '虚拟磁盘文件已创建，但系统没有识别出这块磁盘（可能 attach 失败）。请重启后重试。' }
        Write-Log "虚拟磁盘编号: $diskNum"

        # ---------- 分区 ----------
        & $report 9 '初始化磁盘并分区...'

        # 【只建一个分区，绝不建 ESP】
        #
        # 这是 v1.4 的核心修正。virtual disk 启动（native boot）的硬性要求是：
        # 虚拟磁盘里只有一个分区，bootmgr 会把它当作启动分区。
        #
        # v1.3 及以前建了「ESP + 系统分区」两个分区，于是：
        #   * bcdboot 把启动文件写进 vhdx 内部的 ESP —— UEFI 固件只读物理磁盘上的
        #     ESP，永远不会进 vhdx 里找，所以开机菜单里根本不会出现新系统。
        #   * 而且 vhdx 有多个分区时，bootmgr 用 vhd= 定位很可能落到第一个分区
        #     （那个空 ESP）上，即使 BCD 写对了也起不来。
        #
        # 启动项现在写在「活动 BCD 存储」里（见后面的「引导」段），vhdx 里
        # 只留系统分区。
        # ——【v1.8 修正】单分区必须靠 PowerShell 原生分区命令才能保证 ——
        #
        # 2026-11-04 12:00 那次安装的日志里出现了「虚拟磁盘分区数: 2」。
        # 原因：diskpart 的  clean → convert gpt → create partition primary
        # 会在 GPT 表里自动插入一个 16MB 的 MSR（Reserved）分区，结果是
        #   分区1 = Reserved(MSR)   分区2 = 系统分区
        # bootmgr 用 vhd= 定位时取的是虚拟磁盘的「第一个分区」，也就是那个空的
        # MSR 分区，开机自然找不到系统。
        #
        # Initialize-Disk 只写 GPT 头、不会建 MSR；New-Partition 只建一个数据分区。
        # clean 仍交给 diskpart（这条路径已验证可用）。
        # [审计 P0-1] clean 之前的最后一道闸。整个程序里破坏性最强的一条命令就是它。
        # 如果这块盘能报出自己来自哪个文件，那必须是我们的文件；对不上说明前面匹配错了，
        # 再 clean 就是清别人的分区表。
        if (-not $createdHere) {
            throw "拒绝清空 Disk$diskNum：这个文件不是本次运行创建的。"
        }
        $guardDisk = $null
        try { $guardDisk = Get-Disk -Number $diskNum -EA Stop } catch {}
        if ($guardDisk) {
            $gl = [string]$guardDisk.Location
            if ($gl) {
                if ($gl.StartsWith('\\?\')) { $gl = $gl.Substring(4) }
                $wantFull = [System.IO.Path]::GetFullPath($vhdPath)
                if (-not [string]::Equals($gl.Trim(), $wantFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw ("拒绝清空 Disk{0}。`n`n这块盘报出的文件是：`n    {1}`n而本次创建的是：`n    {2}`n`n没有删除任何东西。多半是还挂着另一个同名的虚拟硬盘，卸掉它再试。" -f $diskNum, $gl, $wantFull)
                }
            }
            $bt = [string]$guardDisk.BusType
            if ($bt -and ($bt -notin @('File Backed Virtual', 'Virtual', 'Unknown'))) {
                throw ("拒绝清空 Disk{0}：它的总线类型是 '{1}'，不是虚拟磁盘。" -f $diskNum, $bt)
            }
        }

        $dp = Invoke-Diskpart -Tag 'vhd' -Lines @(
            "select disk $diskNum",
            'clean',
            'exit'
        )
        Write-Log "diskpart clean: $($dp.Text)"
        if (-not $dp.Ok) { throw "清空虚拟磁盘失败：`n`n$($dp.Text)" }

        try {
            Initialize-Disk -Number $diskNum -PartitionStyle GPT -Confirm:$false -EA Stop | Out-Null
        } catch {
            throw "把虚拟磁盘初始化为 GPT 失败：$($_.Exception.Message)"
        }

        $newPart = $null
        try {
            $newPart = New-Partition -DiskNumber $diskNum -UseMaximumSize -AssignDriveLetter -EA Stop
        } catch {
            throw "在虚拟磁盘上创建分区失败：$($_.Exception.Message)"
        }
        try {
            Format-Volume -Partition $newPart -FileSystem NTFS -NewFileSystemLabel 'NewSystem' `
                          -Confirm:$false -Force -EA Stop | Out-Null
        } catch {
            throw "格式化新分区失败：$($_.Exception.Message)"
        }
        Write-Log "已创建单个 NTFS 分区（PartitionNumber=$($newPart.PartitionNumber)）"

        # 找新分区盘符
        Start-Sleep -Milliseconds 800
        $osLetter = $newPart.DriveLetter
        $parts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
        if (-not $osLetter) { foreach ($p in $parts) {
            if ($p.DriveLetter) {
                $v = Get-Volume -DriveLetter $p.DriveLetter -EA SilentlyContinue
                if ($v -and $v.FileSystem -eq 'NTFS') { $osLetter = $p.DriveLetter; break }
            }
        } }
        if (-not $osLetter) {
            # New-Partition 偶发不给盘符，自己补一个
            $one = @($parts) | Select-Object -First 1
            if ($one) {
                foreach ($c in @('W','V','U','T','N','M','L','K')) {
                    if (Get-Volume -DriveLetter $c -EA SilentlyContinue) { continue }
                    try {
                        Set-Partition -DiskNumber $diskNum -PartitionNumber $one.PartitionNumber -NewDriveLetter $c -EA Stop
                        Start-Sleep -Milliseconds 500
                        $osLetter = $c
                        break
                    } catch {}
                }
            }
        }
        if (-not $osLetter) {
            throw '分区完成但没能分配盘符，请重试。'
        }
        Write-Log "系统分区盘符: $osLetter"

        $partCount = @($parts).Count
        Write-Log "虚拟磁盘分区数: $partCount （native boot 要求 = 1）"

        # 兜底：万一某些环境下还是冒出一个 MSR(Reserved) 分区，当场删掉再复核。
        # MSR 是普通保留分区，删掉不影响数据（里面本来就没有文件系统）。
        if ($partCount -gt 1) {
            $msrGuid = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
            foreach ($p in @($parts)) {
                $isMsr = ([string]$p.Type -eq 'Reserved') -or (([string]$p.GptType).ToLower() -eq $msrGuid)
                if (-not $isMsr) { continue }
                Write-Log "发现 MSR 保留分区（PartitionNumber=$($p.PartitionNumber)），删除它" 'WARN'
                try {
                    Remove-Partition -DiskNumber $diskNum -PartitionNumber $p.PartitionNumber -Confirm:$false -EA Stop
                } catch {
                    Write-Log "删除 MSR 失败: $($_.Exception.Message)" 'WARN'
                }
            }
            Start-Sleep -Milliseconds 1000
            $parts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
            $partCount = @($parts).Count
            Write-Log "清理后分区数: $partCount"
        }

        if ($partCount -ne 1) {
            # v1.8：以前这里只写 WARN，结果要等装完 20 多分钟、重启才发现开不了机。
            # 现在直接失败并清理，让人一分钟内就知道问题，不浪费一次完整安装。
            throw ("虚拟磁盘里出现了 $partCount 个分区，而 native boot 要求恰好 1 个。`n`n" +
                   "多出来的通常是 16MB 的 MSR(Reserved) 分区 —— bootmgr 用 vhd= 时会定位到它，`n" +
                   "结果就是重启后菜单里没有新系统，或者选了进不去。`n`n" +
                   "日志：$($Script:LogFile)")
        }

        # ---------- 应用镜像 ----------
        & $report 12 '恢复系统文件（最耗时的一步）...'

        # 官方镜像的索引 1 有时是 WinPE / Windows Setup，装出来不能用，这里自动跳过
        $pick = Select-ImageIndex -Path $realImage -Preferred $ImageIndex
        if ($pick -ne $ImageIndex) {
            Write-Log "索引 $ImageIndex 不是可安装的系统，自动改用索引 $pick"
            $ImageIndex = $pick
        }

        Write-Log "DISM /Apply-Image index=$ImageIndex => $osLetter`:\"

        # ---------- 【v1.8 重写】DISM 输出走文件，主线程轮询 ----------
        #
        # v1.7 用 Process 的 StandardOutput 逐字符读，实测会死锁：
        #   Peek() 在管道暂时没数据时可能直接返回 -1（而不是阻塞），此时进程还活着，
        #   脚本就掉进「sleep 100ms → continue」的无限空转，再也不去读管道；
        #   DISM 的 stdout 缓冲（约 4KB）写满后彻底阻塞，双方互等 ——
        #   2026-11-04 12:04 实测：停在已写 11.75GB、CPU 时间冻在 51.72s 不动。
        #
        # 现在改成 Start-Process 把 stdout/stderr 直接重定向到临时文件：
        #   * 文件没有固定大小的缓冲区，DISM 不会因为没人读而阻塞；
        #   * 主线程每 0.8 秒轮询文件 + 目标盘已用空间，并调用 $report 刷新界面
        #     （$report 内部会 DoEvents，窗口不会假死）；
        #   * 就算 DISM 一个字都不输出，也能靠「已写入 X.X GB」心跳看到在动。
        $dismOut = Join-Path $env:TEMP ("dism_apply_{0}.log" -f $PID)
        $dismErr = Join-Path $env:TEMP ("dism_apply_{0}.err" -f $PID)
        foreach ($tf in @($dismOut, $dismErr)) {
            try { if (Test-Path -LiteralPath $tf) { Remove-Item -LiteralPath $tf -Force -EA SilentlyContinue } } catch {}
        }

        # /CheckIntegrity 去掉：manifest 在选镜像时已经读过一遍，装的时候再全程校验
        # 会让这一步慢 20%~30%，而它并不能救回损坏的 wim（坏了 Apply 一样会失败）。
        $dismArgs = '/English /Apply-Image /ImageFile:"{0}" /Index:{1} /ApplyDir:{2}:\' -f $realImage, $ImageIndex, $osLetter
        Write-Log "DISM 参数: $dismArgs"

        $proc = $null
        try {
            $proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
                        -RedirectStandardOutput $dismOut -RedirectStandardError $dismErr `
                        -NoNewWindow -PassThru -EA Stop
        } catch {
            throw "无法启动 DISM：$($_.Exception.Message)"
        }

        # 心跳基线：目标分区当前已用多少
        $baseUsed = 0
        $volNow = Get-Volume -DriveLetter $osLetter -EA SilentlyContinue
        if ($volNow) { $baseUsed = [double]($volNow.Size - $volNow.SizeRemaining) }
        Write-Log ("写入前分区已用: {0:N2} GB" -f ($baseUsed / 1GB))

        $lastPct     = 12
        $lastBeatMs  = 0
        $lastGrowMs  = 0
        $lastOutMs   = 0
        $lastOutLen  = -1
        $lastUsedGB  = -1
        # 连续 10 分钟「DISM 输出没长、目标盘也没长」才判定卡死。
        # 为什么不是 4 分钟：DISM 刚起来那段时间只在解压 WIM 元数据，目标盘一个字节都不写；
        # 慢盘 + 杀软实时扫描的机器上，光走到「开始写文件」就能磨好几分钟，
        # 4 分钟的判据会把正常安装误杀（尤其 20GB 的镜像）。
        # 改成双信号之后反而更安全：两个都不动才是真卡死，所以阈值可以放宽。
        $guardMs     = 600000
        $swLoop      = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 800

            # 1) 读 DISM 输出文件，取最近的百分比
            $txt = ''
            try {
                $fsr = New-Object System.IO.FileStream($dismOut, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                try {
                    $sr = New-Object System.IO.StreamReader($fsr, [System.Text.Encoding]::Default)
                    $txt = $sr.ReadToEnd()
                    $sr.Close()
                } finally { $fsr.Close() }
            } catch {}

            $pct = -1
            if ($txt) {
                $ms = [regex]::Matches($txt, '(\d+(?:\.\d+)?)\s*%')
                if ($ms.Count -gt 0) {
                    $pct = [double]$ms[$ms.Count - 1].Groups[1].Value
                    if ($pct -gt 100) { $pct = 100 }
                }
            }

            # 2) 输出文件心跳：DISM 还在往日志里写字，就说明它还活着。
            #    看的是文件长度而不是内容 —— 百分比可能长时间停在同一个数字上。
            $outLen = -1
            try { $outLen = (Get-Item -LiteralPath $dismOut -EA Stop).Length } catch {}
            if ($outLen -ne $lastOutLen) {
                $lastOutLen = $outLen
                $lastOutMs = $swLoop.ElapsedMilliseconds
            }

            # 3) 已用空间心跳（真正的"没卡死"证据）
            $volNow = Get-Volume -DriveLetter $osLetter -EA SilentlyContinue
            $usedGB = $lastUsedGB
            if ($volNow) {
                $usedGB = [math]::Round((($volNow.Size - $volNow.SizeRemaining) / 1GB), 2)
                if ($usedGB -ne $lastUsedGB) { $lastUsedGB = $usedGB; $lastGrowMs = $swLoop.ElapsedMilliseconds }
            }

            # 4) 刷新界面
            if ($pct -ge 0) {
                $overall = [int](12 + $pct * 0.74)
                if ($overall -gt $lastPct) { $lastPct = $overall }
            }
            if (($swLoop.ElapsedMilliseconds - $lastBeatMs) -ge 3000) {
                $lastBeatMs = $swLoop.ElapsedMilliseconds
                $msg = '正在恢复系统文件'
                if ($pct -ge 0)   { $msg += ('  {0:N0}%' -f $pct) }
                if ($usedGB -ge 0) { $msg += ('   已写入 {0:N1} GB' -f $usedGB) }
                & $report $lastPct $msg
            }

            # 5) 看门狗：输出和目标盘**同时**停住才算卡死
            $aliveMs = [Math]::Max($lastGrowMs, $lastOutMs)
            if (($swLoop.ElapsedMilliseconds - $aliveMs) -ge $guardMs) {
                try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
                Write-Log ("DISM 连续 10 分钟毫无进展（输出停在 {0} 字节、目标盘不再增长），已强制结束" -f $lastOutLen) 'WARN'
                $stuckMsg = "恢复系统文件时卡住了：" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "DISM 连续 10 分钟既没有新输出、目标盘也没有任何新数据写入，已自动结束这次安装。" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "常见原因：" + [char]13 + [char]10 +
                            "  · 放虚拟磁盘的那块硬盘响应异常" + [char]13 + [char]10 +
                            "  · 杀毒软件/安全卫士正在实时扫描写入的文件" + [char]13 + [char]10 +
                            "  · 镜像文件本身损坏" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "建议：关掉杀毒软件实时防护后重试，或把虚拟磁盘建到另一块硬盘上。" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "日志：" + $Script:LogFile
                throw $stuckMsg
            }
        }

        $proc.WaitForExit()

        $errOut = ''
        $tailText = ''
        try { if (Test-Path -LiteralPath $dismErr) { $errOut = [IO.File]::ReadAllText($dismErr, [Text.Encoding]::Default) } } catch {}
        try { if (Test-Path -LiteralPath $dismOut) { $tailText = [IO.File]::ReadAllText($dismOut, [Text.Encoding]::Default) } } catch {}

        # Start-Process -PassThru 返回的对象在进程已退出时，ExitCode 常常读成 $null
        # （句柄已被内部收掉）。所以这里同时准备「按事实判断」的后备方案：
        # 内核文件在不在 + DISM 有没有打印成功字样，比一个数字更可信。
        $dismCode = $null
        try { $dismCode = $proc.ExitCode } catch { $dismCode = $null }
        if ($null -eq $dismCode) { Write-Log 'DISM 退出码: 未取到（改用文件与输出判定）' }
        else { Write-Log "DISM 退出码: $dismCode" }

        $tail = @()
        if ($tailText) {
            $tail = @($tailText -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 20)
            Write-Log ("DISM 尾部: " + ($tail -join ' | '))
        }

        $hasKernel = Test-Path -LiteralPath "$($osLetter):\Windows\System32\ntoskrnl.exe"
        $okText    = ($tailText -match 'completed successfully|operation completed|操作成功完成')

        if (($null -ne $dismCode) -and ($dismCode -ne 0)) {
            throw ("恢复系统文件失败（DISM 返回 {0}）`n`n{1}`n`n{2}" -f $dismCode, $errOut, ($tail -join "`n"))
        }
        if (($null -eq $dismCode) -and (-not $hasKernel) -and (-not $okText)) {
            throw ("恢复系统文件失败（没取到 DISM 退出码，也没看到成功字样）`n`n{0}`n`n{1}" -f $errOut, ($tail -join "`n"))
        }

        if (-not $hasKernel) {
            throw '恢复完成后找不到系统内核，镜像可能不完整。'
        }

        # ---------- 这里不再「离线注入网卡驱动」（v1.26 删除） ----------
        #
        # 原实现在这一段用 DISM /Add-Driver 把本机网卡驱动注入刚展开的镜像。
        # 2026-11-05 取证后确认它从来没生效过，整段删掉：
        #
        #   1) 宿主是 Windows 11，实际装的镜像是 Win10 19041 / Server 2022。
        #      导出的驱动包是 W11 专用（Killer 那个文件名就叫 e5xw11x64.inf），
        #      INF 的 NTamd64 装饰和签名跟目标系统版本对不上，首启 PnP 直接拒绝。
        #   2) 证据：23:33 安装时 DISM 报 8 个包全部 "successfully installed"，
        #      23:53 首启后设备管理器里「网络控制器」「以太网控制器」仍然没有
        #      驱动（诊断报告里是两个 [Error]），最后是靠「诊断并装驱动」从
        #      E:\NewSystemDriver 在线装上的 —— WiFi 用的还是里面的
        #      _win10_wifi 版本，说明注入进去的那份根本没被采用。
        #
        # 结论：跨版本注入是白等 30 秒 + 日志噪音，还容易让人以为「装完就有网」。
        # 正确姿势：装完进新系统跑 急救工具\新系统-诊断并装驱动.bat，
        # 它在线 pnputil /add-driver /install + /scan-devices，装得上装不上都有结论。
        # 真要在安装阶段就把驱动带过去，前提是镜像版本 = 宿主版本，那时再考虑加回来。
        # ---------- 【v1.21】预埋「挂载原系统盘」的首启脚本 ----------
        #
        # 单分区机器（原系统 C: = 系统+引导+数据三合一，vhdx 也放 C:）进新系统后，
        # 原 C: 变成「系统分区」—— Windows 的规矩：系统分区和启动卷不是同一个时，
        # 系统分区默认不给盘符（System Reserved 同款待遇）。用户在新系统里就看不到
        # 原来的 C:，文件和急救工具全都够不着。
        #
        # 修法：往新系统写一个 SetupComplete.cmd（微软官方首启钩子，SYSTEM 身份、
        # 安装完成阶段自动跑一次），调用按安装时记录的「磁盘签名/UniqueId + 分区
        # 偏移」生成的 mount-host.ps1：找到宿主分区，没盘符就分 D: 起的第一个空位。
        # 任何一步失败都只写日志退出，不阻塞开机。
        try {
            $hostDrive = ((Split-Path -Path $vhdPath -Qualifier) -replace ':', '')
            $hostPart = Get-Partition -DriveLetter $hostDrive -EA Stop
            $hostDisk = Get-Disk -Number $hostPart.DiskNumber -EA Stop

            $scriptsDir = Join-Path "$($osLetter):\" 'Windows\Setup\Scripts'
            [void][System.IO.Directory]::CreateDirectory($scriptsDir)

            $hostUid = [string]$hostDisk.UniqueId
            $hostSig = [int64]$hostDisk.Signature
            $hostOff = [int64]$hostPart.Offset
            Write-Log ("宿主分区: 磁盘 {0}（Signature={1}, UniqueId={2}）偏移 {3}" -f $hostDisk.Number, $hostSig, $hostUid, $hostOff)

            $mountPs = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$log = Join-Path `$env:SystemRoot 'Temp\mount-host.log'
function Log(`$m) { try { Add-Content -LiteralPath `$log -Value ((Get-Date -Format s) + ' ' + `$m) } catch {} }
Log 'mount-host start (v$($Script:Version))'
# GPT 用 UniqueId 精确匹配；MBR 退回 Signature（签名 0 时跳过，防止误匹配别的 GPT 盘）
`$disk = Get-Disk | Where-Object { `$_.UniqueId -eq '$hostUid' } | Select-Object -First 1
if (-not `$disk) { `$disk = Get-Disk | Where-Object { `$_.Signature -eq $hostSig -and $hostSig -ne 0 } | Select-Object -First 1 }
if (-not `$disk) { Log 'host disk not found'; exit 0 }
`$part = Get-Partition -DiskNumber `$disk.Number | Where-Object { `$_.Offset -eq $hostOff } | Select-Object -First 1
if (-not `$part) { Log 'host partition not found'; exit 0 }
if (`$part.DriveLetter) { Log ('already has letter ' + `$part.DriveLetter); exit 0 }
`$okType = `$false
try { if (`$part.GptType -eq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}') { `$okType = `$true } } catch {}
try { if (`$part.MbrType -eq 7) { `$okType = `$true } } catch {}
if (-not `$okType) { Log ('skip: not a basic data partition'); exit 0 }
`$used = @(Get-Volume | Where-Object { `$_.DriveLetter } | ForEach-Object { `$_.DriveLetter })
`$letter = [char[]](68..90) | Where-Object { `$used -notcontains `$_ } | Select-Object -First 1
if (-not `$letter) { Log 'no free letter'; exit 0 }
try {
    `$part | Set-Partition -NewDriveLetter `$letter
    Log ('assigned ' + `$letter + ': to host partition (disk ' + `$disk.Number + ' part ' + `$part.PartitionNumber + ')')
} catch { Log ('assign failed: ' + `$_.Exception.Message) }
exit 0
"@
            [System.IO.File]::WriteAllText((Join-Path $scriptsDir 'mount-host.ps1'), $mountPs, (New-Object System.Text.UTF8Encoding $false))
            $setupCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%WINDIR%\Setup\Scripts\mount-host.ps1`"`r`n"
            [System.IO.File]::WriteAllText((Join-Path $scriptsDir 'SetupComplete.cmd'), $setupCmd, (New-Object System.Text.ASCIIEncoding))
            Write-Log '已预埋首启脚本：新系统首次启动完成后会自动给原系统分区分配盘符（D: 起的第一个空位）'
        } catch {
            Write-Log "预埋首启挂载脚本失败（不影响安装；进新系统后可用磁盘管理手动分配盘符）: $($_.Exception.Message)" 'WARN'
        }

        # ---------- 引导 ----------
        & $report 96 '配置启动菜单...'
        $fw = Get-FirmwareType
        Write-Log "固件类型: $fw"

        # 系统分区必须落在 vhdx 的「第一个分区」上，否则 bootmgr 用 vhd= 定位时会
        # 落到别处（这正是 v1.3 建了多分区后起不来的原因之一）。
        $osPartNo = $null
        foreach ($p in (Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)) {
            if ([string]$p.DriveLetter -eq [string]$osLetter) { $osPartNo = [int]$p.PartitionNumber; break }
        }
        # 【v1.9.1 修正】以前这里拿「分区编号」和 1 比，但删掉 MSR 后 GPT 不会
        # 重新编号，系统分区仍然是 2 号 —— 于是每次装完都会打一条「开机很可能
        # 找不到系统」的 WARN，纯属误报。真正要看的是「分区总数」。
        $partNow = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
        Write-Log "系统分区号: $osPartNo，分区总数: $($partNow.Count) （native boot 要求总数 = 1）"
        if ($partNow.Count -ne 1) {
            Write-Log "vhdx 里有 $($partNow.Count) 个分区，开机很可能找不到系统" 'WARN'
        }

        # ---------- 【关键】先卸载 vhdx，再注册启动项 ----------
        #
        # 实测（修复工具 19:48 那次）：vhdx 挂载状态下 bcdedit /set device vhd=[...]
        # 会返回「操作成功完成」，但读回发现 device 被写成了内部卷的 partition=X: ——
        # bcdedit 解析 vhd= 时发现虚拟盘正连着，就把它解析成那个卷了。
        # 必须卸载后写，vhd= 才能原样进 BCD。
        & $report 97 '卸载虚拟磁盘...'
        try {
            Dismount-VhdSafe -Path $vhdPath
            $mounted = $false
            Write-Log 'vhdx 已卸载（bcdedit 要求在未挂载状态下写 vhd= 设备）'
        } catch {
            Write-Log "卸载 vhdx 失败: $($_.Exception.Message)" 'WARN'
        }

        $be = Install-BootEntry -VhdFullPath $vhdPath -EditionName $EditionName -DisplayName $safeName
        $bcdTriesReached = $true
        $bcdOk = [bool]$be.Ok
        $espLetter = $be.EspLetter

        if (-not $be.Ok) {
            # [recovery] 这一步失败也要留下状态文件。虚拟磁盘本身是完整的，而修复工具只认这个文件——
            # 否则下面提示「去跑修复启动菜单」，修复工具会说「没找到本工具装的系统」。
            if ($be.Guid) {
                $partialPath = [System.IO.Path]::ChangeExtension($vhdPath, '.boot.txt')
                try {
                    $pl = @(
                        "# $($Script:ProductName) - 部分状态（注册启动项这一步失败，磁盘本身完整）",
                        "Version=$($Script:Version)",
                        "Name=$safeName",
                        "Desc=$($be.Desc)",
                        "VhdPath=$vhdPath",
                        "Guid=$($be.Guid)",
                        "Description=$($be.Desc)",
                        "BcdPath=$($be.BcdPath)",
                        "OrigTimeout=$($be.OrigTimeout)",
                        "OrigDisplayMenu=$($be.OrigDisplay)",
                        "OrigDisplayMenuSet=$($be.OrigDisplaySet)",
                        "BcdBackup=$($be.Backup)",
                        "Created=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
                    )
                    [System.IO.File]::WriteAllLines($partialPath, $pl, (New-Object System.Text.UTF8Encoding $false))
                    Write-Log "已写入部分状态文件，修复工具能找到这块盘：$partialPath" 'WARN'
                } catch {
                    Write-Log "部分状态文件写不进去：$($_.Exception.Message)" 'WARN'
                }
            }
            throw ("配置启动菜单失败。`n`n" +
                   "系统文件已经完整写进虚拟磁盘了（DISM 成功），只是最后一步「注册启动项」没成功。`n`n" +
                   "原因：$($be.Error)`n`n" +
                   "可能办法：`n" +
                   "  1. 临时关闭杀毒软件后重跑（有些会拦截 bcdedit 写引导）`n" +
                   "  2. 用管理员命令行跑一下  bcdedit /enum  ，确认原 BCD 本身没坏`n" +
                   "  3. 日志：$($Script:LogFile)")
        }
        Write-Log "启动条目注册成功: $($be.Guid)"

        # 记录状态，卸载和修复都要用
        $statePath = [System.IO.Path]::ChangeExtension($vhdPath, '.boot.txt')
        try {
            $lines = @(
                "# $($Script:ProductName) - 启动条目状态（卸载时要用，别删）",
                "Version=$($Script:Version)",
                "Name=$safeName",
                "Desc=$($be.Desc)",
                "VhdPath=$vhdPath",
                "Guid=$($be.Guid)",
                "Description=$($be.Desc)",
                "BcdPath=$($be.BcdPath)",
                "OrigTimeout=$($be.OrigTimeout)",
                "OrigDisplayMenu=$($be.OrigDisplay)",
                "OrigDisplayMenuSet=$($be.OrigDisplaySet)",
                "BcdBackup=$($be.Backup)",
                "Created=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
            )
            [System.IO.File]::WriteAllLines($statePath, $lines, (New-Object System.Text.UTF8Encoding $false))
            Write-Log "状态文件: $statePath"
        } catch {
            Write-Log "写状态文件失败（不影响启动，但卸载时要手动删条目）: $($_.Exception.Message)" 'WARN'
        }

        # 顺手清掉历史版本留下的垃圾目录 C:\EFI
        #
        # 【v1.31 高危修正】这里以前是 @('C:\EFI', 'C:\Boot')，两个都删。
        # C:\Boot 是 Windows 的系统引导目录 —— BCD / BCD.LOG / bootvhd.dll /
        # BOOTSTAT.DAT 全在里面。删掉它，BIOS/MBR 引导直接起不来，还会连带删掉
        # 活动 BCD 的事务日志。而放行条件只有一个「创建时间 < 48 小时」，可是
        # Windows 更新、装系统、修复引导都会重建这个目录 —— 等于随时可能误删
        # 系统文件。**C:\Boot 从此一律不动，不要再往下面这个列表里加它。**
        #
        # C:\EFI 才是真垃圾（UEFI 只读 ESP 上的 \EFI，不读 C: 盘这个）。但也不能
        # 无脑递归删：rEFInd / OpenCore / Clover 会拿它当自家目录。要求三条同时满足
        # 才删：48 小时内创建、子目录只有 Microsoft/Boot、里面没有 BCD 或 bootmgfw.efi。
        foreach ($junk in @('C:\EFI')) {
            if (-not (Test-Path -LiteralPath $junk)) { continue }
            try {
                $age = (Get-Date) - (Get-Item -LiteralPath $junk).CreationTime
                if ($age.TotalHours -ge 48) { continue }

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
        & $report 99 '清理...'

        Release-EspLetter -Letter $espLetter
        $espLetter = ''

        Dismount-VhdSafe -Path $vhdPath
        $mounted = $false

        & $report 100 '安装完成'
        Write-Log "安装完成: $vhdPath"

        return [PSCustomObject]@{ Ok = $true; VhdPath = $vhdPath; Drive = $DriveLetter; Folder = $targetFolder }

    } catch {
        $msg = $_.Exception.Message
        Write-Log "失败: $msg" 'ERROR'

        # 回滚。但「系统文件已经装好、只差注册启动项」这种情况不要删 ——
        # DISM 跑了十几分钟（20GB 镜像），删掉等于全白费，而且再跑一次还是同样的错。
        $keepVhd = ($bcdTriesReached -and -not $bcdOk)
        if ($keepVhd) {
            Write-Log "系统文件已完整写入，保留虚拟磁盘以便后续补注册启动项：$vhdPath" 'WARN'
        }

        try {
            if ($mounted) { Dismount-VhdSafe -Path $vhdPath }
        } catch {}
        Release-EspLetter -Letter $espLetter

        # 【双重保护】两个条件同时满足才删：
        #   1. 不是「系统已装好、只差注册启动项」的情况（$keepVhd）
        #   2. 这个文件确实是**本次运行**创建的（$createdHere）
        # 少任何一个都可能删掉用户的既有系统或几十 GB 的有效安装成果。
        if (-not $keepVhd -and $createdHere) {
            try {
                if (Test-Path -LiteralPath $vhdPath) { Remove-Item -LiteralPath $vhdPath -Force -EA SilentlyContinue }
            } catch {}
        }

        if ($keepVhd) {
            throw ("$msg`n`n" +
                   "【注意】系统文件已经完整写入虚拟磁盘，所以这次没有删除它。`n" +
                   "文件位置：$vhdPath`n`n" +
                   "可以只补「注册启动项」这一步，不用重装：`n" +
                   "  打开「开始.bat」选 8（修复启动菜单），或双击「急救工具\修复启动菜单-管理员运行.bat」`n" +
                   "  （它会自己找到这个虚拟磁盘，不管叫什么名字、放在哪个目录）`n`n" +
                   "如果还是失败，临时关闭杀毒软件后整体重跑一次。`n" +
                   "日志：$($Script:LogFile)")
        }
        throw $msg
    } finally {
        # ISO 无论成功失败都要卸载，否则光驱盘符会一直挂着
        if ($isoDrive) {
            try { Close-IsoImage -Drive $isoDrive -IsoPath $isoPath } catch {}
            Write-Log "ISO 已卸载 ($isoDrive`:)"
        }
    }
}

# ============================================================
# 控制台模式
# ============================================================

if ($ConsoleMode) {
    $out = @()
    $out += "$($Script:ProductName) v$($Script:Version)"
    $out += '管理员: ' + (Test-Admin)
    $out += '固件: ' + $(switch (Get-FirmwareType) { 2 { 'UEFI' } 1 { 'Legacy BIOS' } default { '未知' } })
    $out += ''
    $out += '可存放分区:'
    foreach ($v in (Get-TargetVolumes)) {
        $tag = ''
        if ($v.Label) { $tag = "[$($v.Label)]" }
        if ($v.IsSystem) { $tag += '(系统盘)' }
        $out += ('  {0}: 剩余 {1} / 共 {2} {3}' -f $v.Letter, $v.FreeGB, $v.TotalGB, $tag)
    }
    $out += ''
    # 没有显式指定 -SearchRoot（大众双击就是这样）时，要把「程序所在目录/其上级/桌面/下载」
    # 一起加进来。原来只传 $SearchRoot，导致 OriginDir 被完全忽略 → 明明 wim 就在旁边也显示「无」。
    $rootsArg = $SearchRoot
    if (-not $rootsArg) {
        $guess = @()
        if ($Script:OriginDir) { $guess += $Script:OriginDir }
        if ($PSScriptRoot) { $guess += $PSScriptRoot }
        $rootsArg = ($guess | Select-Object -Unique) -join ','
    }
    $out += '找到的镜像:'
    $wims = Find-WimFiles -Roots $rootsArg
    if (-not $wims) {
        $out += '  （无）'
    } else {
        foreach ($w in $wims) {
            $info = Test-WimFile -Path $w
            $out += "  $w"
            # 无效时别输出「解压后 0 GB」这种看着像出错的废话
            if ($info.Valid) {
                $out += ('    有效=True  {0}  {1}  文件 {2} GB  装好后约 {3} GB' -f $info.Name, $info.Build, $info.SizeGB, $info.UncompGB)
                # 多版本镜像把每个索引都列出来（界面里能选，控制台至少让人看见）
                if ($info.Images -gt 1) {
                    foreach ($e in @($info.IndexList)) {
                        $out += ('      索引 {0}: {1}' -f $e.Index, (Format-EditionLabel -Name $e.Name -Desc $e.Desc))
                    }
                }
            } else {
                $out += ('    有效=False  {0}' -f $info.Error)
            }
        }
    }
    # 诊断输出写给调用者看
    $diagPath = Join-Path $Script:TempDir 'console-report.txt'
    $out -join "`r`n" | Set-Content -LiteralPath $diagPath -Encoding UTF8
    Write-Host ($out -join "`r`n")
    exit 0
}

# ============================================================
# 入口
# ============================================================

Write-Log "启动 v$($Script:Version)  管理员=$(Test-Admin)"

if (-not (Test-Admin)) {
    # 自我提权
    try {
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
        if ($SearchRoot) { $argList += @('-SearchRoot', "`"$SearchRoot`"") }
        if ($TargetDrive) { $argList += @('-TargetDrive', $TargetDrive) }
        if ($SizeGB -gt 0) { $argList += @('-SizeGB', $SizeGB) }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host '需要管理员权限才能装系统。请右键本文件，选择「以管理员身份运行」后重试。' -ForegroundColor Yellow
        Write-Host ''
        Read-Host '按回车退出'
        exit 1
    }
}

# 弹窗统一走这里，参数用强类型枚举而不是字符串。
#
# 教训一：'DefaultButton1' 这种字符串能通过 PowerShell 语法检查，
#   直到 MessageBox.Show 绑定时才发现枚举里根本没这个成员，直接抛
#   「无法将 'DefaultButton1' 转换为 'MessageBoxDefaultButton'」。
#   正确的是 Button1 / Button2 / Button3（没有 Default 前缀）。
#   用强类型参数后，写错枚举名在调用处立刻报错，不会等到运行时。
#
# 教训二：GetNewClosure() 只捕获变量，不捕获函数定义。
#   闭包在**新的会话状态**里执行，连脚本级 function 都解析不到
#   （实测：闭包内 Get-Command Show-Box 返回 null）。
#   所以 Guard 里必须先用 (Get-Item function:Show-Box).ScriptBlock
#   把它变成变量，才能跟着闭包一起走。详见 Guard 的注释。
function Show-Box {
    param(
        [string]$Text,
        [string]$Caption = '提示',
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information,
        [System.Windows.Forms.MessageBoxDefaultButton]$Default = [System.Windows.Forms.MessageBoxDefaultButton]::Button1
    )
    return [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $Buttons, $Icon, $Default)
}

function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:Busy = $false
    $script:SelWim = $null
    $script:SelEdition = ''
    $script:SelIndex = 1        # 镜像里要装第几个索引（Server 镜像一个 wim 里通常有 4 个版本）
    $script:EdList = @()        # 当前镜像的版本表，和 $cmbEd 的条目一一对应
    $script:SelDrive = if ($TargetDrive) { $TargetDrive } else { $null }
    $script:WimList = @()
    $script:SysList = @()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$($Script:ProductName) v$($Script:Version) - connectsegabot"
    $form.Size = New-Object System.Drawing.Size(800, 876)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

    # [审计 P1-7] 安装是在 UI 线程上跑的，10~40 分钟，期间一直在刷新控件。
    # 中途点右上角关窗口会把那些控件释放掉，finally 里的清理也可能走不到。
    # 干活期间禁止关闭（状态栏会说明原因）。
    $form.Add_FormClosing({
        param($sender, $e)
        if ($script:Busy) {
            $e.Cancel = $true
            try {
                $lblSt.Text = '正在安装，装完之前不能关闭窗口'
                $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            } catch {}
        }
    })

    # ---- 顶栏 ----
    $hd = New-Object System.Windows.Forms.Panel
    $hd.Location = New-Object System.Drawing.Point(0, 0)
    $hd.Size = New-Object System.Drawing.Size(800, 86)
    $hd.BackColor = [System.Drawing.Color]::FromArgb(28, 56, 94)
    $form.Controls.Add($hd)

    $t1 = New-Object System.Windows.Forms.Label
    $t1.Text = $Script:ProductName
    $t1.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 20, [System.Drawing.FontStyle]::Bold)
    $t1.ForeColor = [System.Drawing.Color]::White
    $t1.Location = New-Object System.Drawing.Point(26, 14)
    $t1.Size = New-Object System.Drawing.Size(560, 36)
    $hd.Controls.Add($t1)

    $t2 = New-Object System.Windows.Forms.Label
    $t2.Text = '不用 U 盘、不用改 BIOS。每个系统都是独立的一个虚拟硬盘文件，可装多个，原系统完好无损。  作者：connectsegabot'
    $t2.ForeColor = [System.Drawing.Color]::FromArgb(168, 196, 226)
    $t2.Location = New-Object System.Drawing.Point(28, 52)
    $t2.Size = New-Object System.Drawing.Size(742, 20)
    $hd.Controls.Add($t2)

    # ---- 第 1 步 ----
    $y1 = 102
    $s1 = New-Object System.Windows.Forms.Label
    $s1.Text = '① 选择系统镜像'
    $s1.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $s1.ForeColor = [System.Drawing.Color]::FromArgb(36, 48, 70)
    $s1.Location = New-Object System.Drawing.Point(26, $y1)
    $s1.Size = New-Object System.Drawing.Size(300, 24)
    $form.Controls.Add($s1)

    $cmbWim = New-Object System.Windows.Forms.ComboBox
    $cmbWim.Location = New-Object System.Drawing.Point(28, ($y1 + 28))
    $cmbWim.Size = New-Object System.Drawing.Size(586, 26)
    $cmbWim.DropDownStyle = 'DropDownList'
    $form.Controls.Add($cmbWim)

    $btnPickWim = New-Object System.Windows.Forms.Button
    $btnPickWim.Text = '浏览...'
    $btnPickWim.Location = New-Object System.Drawing.Point(622, ($y1 + 26))
    $btnPickWim.Size = New-Object System.Drawing.Size(128, 30)
    $btnPickWim.FlatStyle = 'System'
    $form.Controls.Add($btnPickWim)

    $lblWim = New-Object System.Windows.Forms.Label
    $lblWim.Text = '正在搜索镜像文件...'
    $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblWim.Location = New-Object System.Drawing.Point(30, ($y1 + 58))
    $lblWim.Size = New-Object System.Drawing.Size(720, 20)
    $form.Controls.Add($lblWim)

    # 【v1.17】版本选择。一个 install.wim 里可以有好几个系统：
    #   Windows Server 2022 的官方 ISO → 1 Standard(Core) 2 Standard(桌面) 3 DC(Core) 4 DC(桌面)
    # 以前固定装索引 1，Server 正好是「没有图形界面」那个，装完只有命令行。
    # 只有多索引时才显示这三件套，单版本镜像界面和以前一模一样。
    $lblEd = New-Object System.Windows.Forms.Label
    $lblEd.Text = '版本'
    $lblEd.ForeColor = [System.Drawing.Color]::FromArgb(68, 80, 98)
    $lblEd.Location = New-Object System.Drawing.Point(30, ($y1 + 81))
    $lblEd.Size = New-Object System.Drawing.Size(44, 18)
    $lblEd.Visible = $false
    $form.Controls.Add($lblEd)

    $cmbEd = New-Object System.Windows.Forms.ComboBox
    $cmbEd.Location = New-Object System.Drawing.Point(76, ($y1 + 79))
    $cmbEd.Size = New-Object System.Drawing.Size(496, 24)
    $cmbEd.DropDownStyle = 'DropDownList'
    $cmbEd.Visible = $false
    $form.Controls.Add($cmbEd)

    $lblEdHint = New-Object System.Windows.Forms.Label
    $lblEdHint.Text = '镜像里有多个版本，选一个'
    $lblEdHint.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
    $lblEdHint.Location = New-Object System.Drawing.Point(580, ($y1 + 81))
    $lblEdHint.Size = New-Object System.Drawing.Size(190, 18)
    $lblEdHint.Visible = $false
    $form.Controls.Add($lblEdHint)

    # ---- 第 2 步 ----
    $y2 = 212
    $s2 = New-Object System.Windows.Forms.Label
    $s2.Text = '② 选择存放位置和大小'
    $s2.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $s2.ForeColor = [System.Drawing.Color]::FromArgb(36, 48, 70)
    $s2.Location = New-Object System.Drawing.Point(26, $y2)
    $s2.Size = New-Object System.Drawing.Size(320, 24)
    $form.Controls.Add($s2)

    # 【v1.11】原来只能从下拉框里挑一个盘符，vhdx 只能落在盘根。
    # 现在改成可编辑的完整路径 + 浏览按钮：用户想放 D:\VHD\Win11 也行。
    $txtDir = New-Object System.Windows.Forms.TextBox
    $txtDir.Location = New-Object System.Drawing.Point(28, ($y2 + 28))
    $txtDir.Size = New-Object System.Drawing.Size(470, 26)
    $txtDir.BorderStyle = 'FixedSingle'
    $form.Controls.Add($txtDir)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = '浏览...'
    $btnBrowse.Location = New-Object System.Drawing.Point(504, ($y2 + 26))
    $btnBrowse.Size = New-Object System.Drawing.Size(96, 30)
    $btnBrowse.FlatStyle = 'System'
    $form.Controls.Add($btnBrowse)

    $lblSz = New-Object System.Windows.Forms.Label
    $lblSz.Text = '大小'
    $lblSz.ForeColor = [System.Drawing.Color]::FromArgb(68, 80, 98)
    $lblSz.Location = New-Object System.Drawing.Point(614, ($y2 + 32))
    $lblSz.Size = New-Object System.Drawing.Size(36, 20)
    $form.Controls.Add($lblSz)

    $numSz = New-Object System.Windows.Forms.NumericUpDown
    $numSz.Location = New-Object System.Drawing.Point(650, ($y2 + 28))
    $numSz.Size = New-Object System.Drawing.Size(70, 26)
    $numSz.Minimum = 10
    $numSz.Maximum = 1000
    $numSz.Value = 60
    # 【v1.20】记录最近一次「自动填入」的建议值。只有当前值还等于它
    # （用户没手动改过）时，下次选镜像才允许再次自动填；
    # 用户手动改过的大小绝不能被拍回去。
    $script:SzSuggested = 60
    $form.Controls.Add($numSz)

    $lblGb = New-Object System.Windows.Forms.Label
    $lblGb.Text = 'GB'
    $lblGb.Location = New-Object System.Drawing.Point(726, ($y2 + 32))
    $lblGb.Size = New-Object System.Drawing.Size(30, 20)
    $form.Controls.Add($lblGb)

    # 盘符快捷按钮：点一下就把路径换成「该盘根目录」，比手打省事
    $flowDrv = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowDrv.Location = New-Object System.Drawing.Point(26, ($y2 + 58))
    $flowDrv.Size = New-Object System.Drawing.Size(744, 26)
    $flowDrv.FlowDirection = 'LeftToRight'
    $flowDrv.WrapContents = $false
    $flowDrv.AutoScroll = $true
    $form.Controls.Add($flowDrv)

    $lblDrive = New-Object System.Windows.Forms.Label
    $lblDrive.Text = ''
    $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblDrive.Location = New-Object System.Drawing.Point(30, ($y2 + 88))
    $lblDrive.Size = New-Object System.Drawing.Size(740, 20)
    $form.Controls.Add($lblDrive)

    # ---- 第 3 步：系统名称 ----
    $y3 = 344
    $s3 = New-Object System.Windows.Forms.Label
    $s3.Text = '③ 给这个系统起个名字'
    $s3.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $s3.ForeColor = [System.Drawing.Color]::FromArgb(36, 48, 70)
    $s3.Location = New-Object System.Drawing.Point(26, $y3)
    $s3.Size = New-Object System.Drawing.Size(360, 24)
    $form.Controls.Add($s3)

    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object System.Drawing.Point(28, ($y3 + 28))
    $txtName.Size = New-Object System.Drawing.Size(440, 26)
    $txtName.MaxLength = 48
    $txtName.Text = $Script:DefaultDiskName
    $txtName.BorderStyle = 'FixedSingle'
    $form.Controls.Add($txtName)

    $btnNameGen = New-Object System.Windows.Forms.Button
    $btnNameGen.Text = '用版本名'
    $btnNameGen.Location = New-Object System.Drawing.Point(476, ($y3 + 26))
    $btnNameGen.Size = New-Object System.Drawing.Size(96, 30)
    $btnNameGen.FlatStyle = 'System'
    $form.Controls.Add($btnNameGen)

    $btnNameNum = New-Object System.Windows.Forms.Button
    $btnNameNum.Text = '加序号'
    $btnNameNum.Location = New-Object System.Drawing.Point(578, ($y3 + 26))
    $btnNameNum.Size = New-Object System.Drawing.Size(80, 30)
    $btnNameNum.FlatStyle = 'System'
    $form.Controls.Add($btnNameNum)

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = ''
    $lblName.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblName.Location = New-Object System.Drawing.Point(30, ($y3 + 60))
    $lblName.Size = New-Object System.Drawing.Size(740, 20)
    $form.Controls.Add($lblName)

    # ---- 已有系统 ----
    $y4 = 432
    $s4 = New-Object System.Windows.Forms.Label
    $s4.Text = '这台机器上已经装过的系统'
    $s4.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $s4.ForeColor = [System.Drawing.Color]::FromArgb(68, 80, 98)
    $s4.Location = New-Object System.Drawing.Point(26, $y4)
    $s4.Size = New-Object System.Drawing.Size(400, 20)
    $form.Controls.Add($s4)

    $lblSysList = New-Object System.Windows.Forms.Label
    $lblSysList.Text = '正在扫描...'
    $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblSysList.Location = New-Object System.Drawing.Point(28, ($y4 + 22))
    $lblSysList.Size = New-Object System.Drawing.Size(740, 58)
    $lblSysList.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
    $form.Controls.Add($lblSysList)

    # ---- 提示框 ----
    $y5 = 526
    $box = New-Object System.Windows.Forms.Panel
    $box.Location = New-Object System.Drawing.Point(28, $y5)
    $box.Size = New-Object System.Drawing.Size(742, 74)
    $box.BackColor = [System.Drawing.Color]::FromArgb(237, 245, 254)
    $box.BorderStyle = 'FixedSingle'
    $form.Controls.Add($box)

    $lblBox = New-Object System.Windows.Forms.Label
    $lblBox.Text = "装好之后重启，开机菜单会多出一项（就是你起的名称），选它就进新系统。" + [char]13 + [char]10 + "想再装一个就再跑一次，换个名字即可。不想要了运行「双击我-卸载新系统.bat」，删干净，原系统一点不受影响。"
    $lblBox.ForeColor = [System.Drawing.Color]::FromArgb(42, 78, 128)
    $lblBox.Location = New-Object System.Drawing.Point(10, 10)
    $lblBox.Size = New-Object System.Drawing.Size(722, 54)
    $box.Controls.Add($lblBox)

    # ---- 第 4 步：开始 ----
    $y6 = 618
    $sep = New-Object System.Windows.Forms.Panel
    $sep.Location = New-Object System.Drawing.Point(26, $y6)
    $sep.Size = New-Object System.Drawing.Size(746, 1)
    $sep.BackColor = [System.Drawing.Color]::FromArgb(218, 223, 230)
    $form.Controls.Add($sep)

    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Text = '开始安装'
    $btnGo.Location = New-Object System.Drawing.Point(28, ($y6 + 14))
    $btnGo.Size = New-Object System.Drawing.Size(152, 44)
    $btnGo.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 198)
    $btnGo.ForeColor = [System.Drawing.Color]::White
    $btnGo.FlatStyle = 'Flat'
    $btnGo.FlatAppearance.BorderSize = 0
    $btnGo.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $btnGo.Enabled = $false
    $form.Controls.Add($btnGo)

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point(196, ($y6 + 18))
    $pb.Size = New-Object System.Drawing.Size(578, 18)
    $pb.Minimum = 0
    $pb.Maximum = 100
    $form.Controls.Add($pb)

    $lblSt = New-Object System.Windows.Forms.Label
    $lblSt.Text = '等待开始'
    $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(86, 96, 112)
    $lblSt.Location = New-Object System.Drawing.Point(198, ($y6 + 40))
    $lblSt.Size = New-Object System.Drawing.Size(576, 20)
    $form.Controls.Add($lblSt)

    $log = New-Object System.Windows.Forms.TextBox
    $log.Location = New-Object System.Drawing.Point(28, ($y6 + 66))
    $log.Size = New-Object System.Drawing.Size(746, 112)
    $log.Multiline = $true
    $log.ScrollBars = 'Vertical'
    $log.ReadOnly = $true
    $log.BackColor = [System.Drawing.Color]::FromArgb(252, 252, 253)
    $log.ForeColor = [System.Drawing.Color]::FromArgb(66, 76, 90)
    $log.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $log.BorderStyle = 'FixedSingle'
    $form.Controls.Add($log)

    $lblFoot = New-Object System.Windows.Forms.Label
    $lblFoot.Text = "固件: $(switch (Get-FirmwareType) { 2 { 'UEFI' } 1 { 'Legacy BIOS' } default { '未知' } })    日志: $Script:LogFile"
    $lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(150, 158, 170)
    $lblFoot.Location = New-Object System.Drawing.Point(30, ($y6 + 182))
    $lblFoot.Size = New-Object System.Drawing.Size(742, 18)
    $form.Controls.Add($lblFoot)

    function AddLog([string]$m) {
        $stamp = (Get-Date).ToString('HH:mm:ss')
        # 注意：方法调用的参数按逗号切分，-f 只能拿到第一个参数，
        # 必须先用变量拼好整行再传进去
        $line = '[' + $stamp + '] ' + $m + [char]13 + [char]10
        $log.AppendText($line)
        $log.SelectionStart = $log.TextLength
        $log.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
        Write-Log $m
    }

    function UpdateGo {
        $btnGo.Enabled = (-not $script:Busy -and $null -ne $script:SelWim -and $script:SelDrive)
    }

    # 路径框下方那行：校验目录 + 显示最终文件名 + 剩余空间
    function UpdateDirHint {
        $raw = $txtDir.Text
        if (-not $raw -or -not $raw.Trim()) {
            $lblDrive.Text = '填一个文件夹，或者点上面的硬盘按钮。'
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            $lblDrive.Tag = 'bad'
            $script:SelDrive = $null
            UpdateGo
            return
        }
        $chk = Test-TargetFolder $raw
        if (-not $chk.Ok) {
            $lblDrive.Text = $chk.Msg
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            $lblDrive.Tag = 'bad'
            # 仍然记下盘符，让「开始」按钮的可用状态跟着盘符走；
            # 真正拦下是在点「开始」时用 Test-TargetFolder 再判一次。
            if ($raw.Trim() -match '^([A-Za-z])') { $script:SelDrive = $Matches[1].ToUpper() } else { $script:SelDrive = $null }
            UpdateGo
            return
        }
        $script:SelDrive = $chk.Folder.Substring(0, 1).ToUpper()
        $freeB = Get-DiskFreeBytes $chk.Folder
        $free = if ($freeB -ge 0) { [math]::Round($freeB / 1GB, 1) } else { -1 }
        $need = [int64]$numSz.Value + 5
        $txt = "可用分区 $($script:SelDrive):　剩余 $free GB"
        # 落在系统盘（单盘机器只有它可选）时明确说一句：这不算错误，但会吃系统空间。
        # 不拦，只提示 —— 否则单 C 盘的用户根本没法装。
        $onSys = ($script:SelDrive -eq $env:SystemDrive.TrimEnd(':').ToUpper())
        if ($free -lt 0) {
            # 拿不到数字不算错误，交给点「开始」时的真实写入探针去判定
            $txt = "可用分区 $($script:SelDrive):　剩余空间未知（会实际写一次测试）"
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
            $lblDrive.Tag = 'ok'
        } elseif ($free -lt $need) {
            $txt = $txt + "　—— 不够装 $($numSz.Value) GB（含 5GB 余量），换个大点的分区或调小"
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            $lblDrive.Tag = 'bad'
        } else {
            if ($onSys) {
                $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
            } else {
                $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(26, 124, 68)
            }
            $lblDrive.Tag = 'ok'
        }
        if ($onSys) { $txt += '　· 这是系统盘，虚拟磁盘会占走系统空间' }
        $lblDrive.Text = $txt
        UpdateGo
    }

    # 名称框下方那行说明：实时显示最终会生成什么文件名、会不会重名
    function UpdateNameHint {
        $raw = $txtName.Text
        $safe = Get-SafeDiskName $raw
        $parts = @()
        if ($safe -ne $raw.Trim()) {
            $parts += "已自动去掉非法字符 → 「$safe」"
        }
        if (-not (Test-EncodableName $safe)) {
            $lblName.Text = "这个名称里有系统编码不支持的字（如 emoji），换一个吧。"
            $lblName.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            return
        }
        $chk = Test-TargetFolder $txtDir.Text
        if ($chk.Ok) {
            try {
                $p = Get-UniqueVhdPath -Folder $chk.Folder -DiskName $safe
                $fn = [System.IO.Path]::GetFileName($p)
                $parts += "文件：$($chk.Folder.TrimEnd('\'))\$fn"
                if ($fn -ne "$safe.vhdx") {
                    $parts += '（同名已存在，自动加序号）'
                }
            } catch {
                $parts += $_.Exception.Message
            }
        }
        $parts += '开机菜单里就显示这个名字'
        $lblName.Text = ($parts -join '　　')
        $lblName.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    }

    function Refresh-SysList {
        $script:SysList = @(Find-InstalledSystems)
        if ($script:SysList.Count -eq 0) {
            $lblSysList.Text = '还没有装过。可以装多个，每个都用不同的名称。'
            $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
        } else {
            $lines = @()
            foreach ($s in ($script:SysList | Select-Object -First 4)) {
                $d = $s.Name
                if ($s.Desc) { $d = "$($s.Desc)  ←  $($s.Name)" }
                $lines += ('  · ' + $d + '    ' + $s.SizeGB + ' GB')
            }
            if ($script:SysList.Count -gt 4) { $lines += ('  ... 还有 ' + ($script:SysList.Count - 4) + ' 个') }
            $lblSysList.Text = ($lines -join [char]13 + [char]10)
            $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 88)
        }
    }

    # 把事件处理器包一层，任何异常都变成可读提示，而不是 WinForms 默认的「未处理的异常」弹窗
    # 注意：不能 return { & $Body }，因为返回的脚本块执行时 $Body 已不在作用域内（会是 $null）
    # 必须用 .GetNewClosure() 把变量一起捕获进去
    #
    # 还有个更隐蔽的坑：GetNewClosure() **只捕获变量，不捕获函数定义**。
    # 返回的闭包在新的会话状态里执行，连脚本级 function Show-Box 都解析不到
    # （已实测：闭包内 Get-Command Show-Box 返回 null）。
    # 所以 Show-Box 必须先用 (Get-Item function:Show-Box).ScriptBlock 变成变量，
    # 才能跟着 GetNewClosure 一起进闭包。
    function Guard {
        param([string]$Name, [scriptblock]$Body)
        $logPath = $Script:LogFile
        $tag = $Name
        $boxFn = $null
        try { $boxFn = (Get-Item function:Show-Box -EA Stop).ScriptBlock } catch {}
        # 同上：Add-Content 也是命令，闭包里可能解析不到，提前变变量
        $logFn = $null
        try { $logFn = (Get-Item function:Add-Content -EA Stop).ScriptBlock } catch {}
        if (-not $logFn) { $logFn = { param($LiteralPath, $Value) [System.IO.File]::AppendAllText($LiteralPath, [string]$Value) } }
        $handler = {
            param($sender, $e)
            try {
                & $Body $sender $e
            } catch {
                $ex = $_.Exception
                $detail = $ex.Message
                $line = ''
                if ($_.InvocationInfo) {
                    $line = $_.InvocationInfo.ScriptLineNumber
                    $detail = "$detail" + [char]13 + [char]10 + [char]13 + [char]10 + "出错语句（第 $line 行）：" + [char]13 + [char]10 + $_.InvocationInfo.Line.Trim()
                }
                try {
                    # 【v1.29】日志路径可能在安装开始时改走，闭包捕获的是旧值，
                    # 优先用 AppDomain 数据槽里的当前值
                    $lp = $null
                    try { $lp = [System.AppDomain]::CurrentDomain.GetData('VHDX.LogFile') } catch {}
                    if (-not $lp) { $lp = $logPath }
                    $rec = ('[{0}] [EVENT-ERR] {1}: {2} @L{3}' -f (Get-Date).ToString('HH:mm:ss'), $tag, $ex.Message, $line) + [char]13 + [char]10
                    & $logFn -LiteralPath $lp -Value $rec
                } catch {}
                try {
                    if ($boxFn) {
                        $msg = "[$tag] 出错：" + [char]13 + [char]10 + [char]13 + [char]10 + $detail + [char]13 + [char]10 + [char]13 + [char]10 +
                               "日志：$lp"
                        & $boxFn -Text $msg `
                                  -Caption '操作出错' `
                                  -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                                  -Icon ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                    }
                } catch {}
            }
        }
        return $handler.GetNewClosure()
    }

    function Set-Wim([string]$path) {
        $info = Test-WimFile -Path $path
        if (-not $info.Valid) {
            Show-Box -Text ("这个文件不能用。" + [char]13 + [char]10 + [char]13 + [char]10 + $info.Error) `
                     -Caption '镜像无效' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            AddLog "镜像无效: $($info.Error)"
            return
        }
        $script:SelWim = $path
        # 记下版本名，安装时用它决定启动菜单里显示什么（而不是硬编码 Windows 10）
        $script:SelEdition = [string]$info.Name
        $script:SelIndex = 1
        $lblWim.Text = "$($info.Name)    版本 $($info.Build)    文件 $($info.SizeGB) GB，装好后约 $($info.UncompGB) GB"
        $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(26, 124, 68)
        AddLog "镜像: $($info.Name)  $($info.Build)"

        # ---- 版本选择（v1.17）----
        # 一个 wim 里可能有好几个系统。Server 的官方 ISO 索引 1 正好是「无图形界面」的
        # Server Core，以前固定装它 —— 用户装完发现只有黑框框，只能重来。
        $idxList = @($info.IndexList)
        if ($idxList.Count -le 1 -and $info.Images -gt 1) {
            $idxList = @(Get-ImageIndexList -Path $path)
        }
        $script:EdList = @($idxList)
        $cmbEd.Items.Clear()
        if ($script:EdList.Count -gt 1) {
            foreach ($it in $script:EdList) {
                [void]$cmbEd.Items.Add((Format-EditionLabel -Name $it.Name -Desc $it.Desc))
            }
            # 默认选「带图形界面」的那个；都没有（比如 Win10 多版本 ISO）才退回第一个
            $pick = 0
            for ($i = 0; $i -lt $script:EdList.Count; $i++) {
                if ($script:EdList[$i].Name -match '(?i)Desktop\s*Experience') { $pick = $i; break }
            }
            $script:SelIndex = [int]$script:EdList[$pick].Index
            $script:SelEdition = [string]$script:EdList[$pick].Name
            $cmbEd.SelectedIndex = $pick
            $lblEd.Visible = $true
            $cmbEd.Visible = $true
            $lblEdHint.Visible = $true
            AddLog ("这个镜像有 {0} 个版本，默认选「{1}」（索引 {2}）" -f `
                    $script:EdList.Count, $script:EdList[$pick].Name, $script:SelIndex)
        } else {
            $lblEd.Visible = $false
            $cmbEd.Visible = $false
            $lblEdHint.Visible = $false
            $script:SelIndex = 1
        }

        if ($info.UncompGB -gt 0) {
            $suggest = [int]([math]::Ceiling($info.UncompGB * 1.3 / 10) * 10)
            if ($suggest -lt 40) { $suggest = 40 }
            if ($suggest -le $numSz.Maximum) {
                # 【v1.20】以前这里无条件 $numSz.Value = $suggest：
                # 用户手动把大小改成 80，再重选一次镜像（或刷新分区列表
                # 触发 Refresh-All 重选第 0 项），就被拍回建议值——小镜像
                # 建议值钳在 40，看起来就是「我设的大小自己变回 40G」。
                # 现在只在「当前值 == 上次自动填入值」时才覆盖。
                if ([int]$numSz.Value -eq [int]$script:SzSuggested) {
                    $numSz.Value = $suggest
                    $script:SzSuggested = $suggest
                    AddLog "建议磁盘大小: $suggest GB（已自动填入）"
                } else {
                    AddLog "建议磁盘大小: $suggest GB（保留你手动设置的大小 $([int]$numSz.Value) GB）"
                }
            }
        }
        UpdateGo
    }

    function Refresh-All {
        # 分区：先在快捷条上按盘生成按钮，默认路径取第一个可用盘的根目录
        $flowDrv.Controls.Clear()
        $vols = @(Get-TargetVolumes)
        foreach ($v in $vols) {
            $b = New-Object System.Windows.Forms.Button
            # 系统盘也列出来（单盘机器没别的可选），但明确标出来并排在最后：
            # 装到 C 盘会占走系统分区空间，不是首选。
            if ($v.IsSystem) {
                $b.Text = "$($v.Letter):  剩余 $($v.FreeGB) GB · 系统盘"
                $b.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
            } else {
                $b.Text = "$($v.Letter):  剩余 $($v.FreeGB) GB"
            }
            $b.AutoSize = $true
            $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
            $b.FlatStyle = 'System'
            $b.Tag = "$($v.Letter):\"
            # 直接调函数（不经过闭包），避免 GetNewClosure 捕获不到脚本函数的老问题
            $b.Add_Click({
                param($sender, $ev)
                $txtDir.Text = [string]$sender.Tag
            })
            [void]$flowDrv.Controls.Add($b)
        }

        if ($vols.Count -gt 0) {
            # 路径框和「浏览...」只要机器上有任何一块能放的盘就必须可用。
            # v1.15 及以前这里是跟着「非系统盘」走的，单 C 盘机器两个控件都被禁用，
            # 用户连手动指定文件夹的入口都没有。
            $txtDir.Enabled = $true
            $btnBrowse.Enabled = $true
            if (-not $txtDir.Text.Trim()) {
                # 优先落在非系统盘（已按 IsSystem 排序，第一个就是它）。
                # 只有系统盘时填 C:\ 而不是 C:\虚拟磁盘 —— 后者多半不存在，
                # 会立刻显示「这个文件夹还不存在」的红字，等于把用户挡在门口。
                $pick = $vols[0].Letter
                if (-not $vols[0].IsSystem -and $script:SelDrive) {
                    foreach ($v in $vols) { if ($v.Letter -eq $script:SelDrive) { $pick = $v.Letter; break } }
                }
                $txtDir.Text = "$($pick):\"
            }
        } else {
            $txtDir.Enabled = $false
            $btnBrowse.Enabled = $false
            $lblDrive.Text = '没有可用分区（需要本地固定硬盘上的 NTFS 分区，剩余 10GB 以上）'
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            $script:SelDrive = $null
        }

        # 镜像
        $cmbWim.Items.Clear()
        $script:WimList = @(Find-WimFiles -Roots $SearchRoot)
        if ($script:WimList.Count -eq 0) {
            $lblWim.Text = '没有自动找到镜像，请点「浏览...」手动选择 .wim / .esd / .iso 文件'
            $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(186, 106, 30)
            AddLog '未找到 .wim / .esd / .iso 镜像'
        } else {
            foreach ($w in $script:WimList) { [void]$cmbWim.Items.Add($w) }
            $cmbWim.SelectedIndex = 0
            AddLog "找到 $($script:WimList.Count) 个镜像文件"
        }
        Refresh-SysList
        UpdateDirHint
        UpdateNameHint
        UpdateGo
    }

    $cmbWim.Add_SelectedIndexChanged((Guard '选择镜像' {
        if ($cmbWim.SelectedIndex -ge 0) { Set-Wim $cmbWim.SelectedItem.ToString() }
    }))

    # 用户换版本：索引号跟着走，装的时候用它
    $cmbEd.Add_SelectedIndexChanged((Guard '选择版本' {
        $i = $cmbEd.SelectedIndex
        if ($i -ge 0 -and $i -lt @($script:EdList).Count) {
            $it = $script:EdList[$i]
            $script:SelIndex = [int]$it.Index
            $script:SelEdition = [string]$it.Name
            AddLog ("版本: {0}（索引 {1}）" -f $it.Name, $it.Index)
            UpdateNameHint
        }
    }))

    $txtName.Add_TextChanged((Guard '名称变化' { UpdateNameHint }))

    $btnNameGen.Add_Click((Guard '用版本名' {
        $e = [string]$script:SelEdition
        if (-not $e) {
            Show-Box -Text '还没选镜像，先在上面选一个镜像。' -Caption '提示' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }
        $txtName.Text = Get-SafeDiskName $e
    }))

    $btnNameNum.Add_Click((Guard '加序号' {
        $base = Get-SafeDiskName $txtName.Text
        $base = ($base -replace '\s*\(\d+\)$', '')
        for ($i = 2; $i -le 99; $i++) {
            $cand = "$base ($i)"
            $dup = $false
            foreach ($s in $script:SysList) {
                if ($s.Name -eq $cand -or $s.Desc -eq $cand) { $dup = $true; break }
            }
            if (-not $dup) { $txtName.Text = $cand; break }
        }
    }))

    $txtDir.Add_TextChanged((Guard '路径变化' {
        UpdateDirHint
        UpdateNameHint
    }))

    $btnBrowse.Add_Click((Guard '浏览存放目录' {
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = '选一个文件夹用来放虚拟硬盘（要求：本地硬盘、NTFS、剩余空间够）'
        $fb.ShowNewFolderButton = $true
        $cur = $txtDir.Text.Trim()
        if ($cur -and (Test-Path -LiteralPath $cur -PathType Container)) { $fb.SelectedPath = $cur }
        if ($fb.ShowDialog() -eq 'OK') { $txtDir.Text = $fb.SelectedPath }
    }))

    $numSz.Add_ValueChanged((Guard '调整大小' {
        UpdateDirHint
    }))

    $btnPickWim.Add_Click((Guard '浏览镜像' {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = '选择系统镜像（支持 .wim / .esd / .iso）'
        $ofd.Filter = '系统镜像 (*.wim;*.esd;*.iso)|*.wim;*.esd;*.iso|WIM 镜像 (*.wim)|*.wim|ESD 镜像 (*.esd)|*.esd|ISO 光盘 (*.iso)|*.iso|所有文件 (*.*)|*.*'
        if ($ofd.ShowDialog() -eq 'OK') {
            if (-not $cmbWim.Items.Contains($ofd.FileName)) { [void]$cmbWim.Items.Add($ofd.FileName) }
            $cmbWim.SelectedItem = $ofd.FileName
        }
    }))

    $form.AllowDrop = $true
    $form.Add_DragEnter({
        try {
            if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = 'Copy' }
        } catch {}
    })
    $form.Add_DragDrop((Guard '拖放镜像' {
        $fs = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($fs -and $fs.Count -gt 0 -and $fs[0] -match '\.(wim|esd|iso)$') {
            $p = $fs[0]
            if (-not $cmbWim.Items.Contains($p)) { [void]$cmbWim.Items.Add($p) }
            $cmbWim.SelectedItem = $p
        }
    }))

    # 主按钮同样要包 Guard：它是唯一一个会跑十几分钟、还会调 Get-Volume / Show-Box
    # 的处理器，而这些调用一旦在 try 之外抛错，就会弹 WinForms 默认的「未处理异常」
    # 黑框，$btnGo.Enabled 也可能停在 false，用户只能去任务管理器结束进程。
    $btnGo.Add_Click((Guard '开始安装' {
        if (-not $script:SelWim -or -not $script:SelDrive) { return }
        $size = [int]$numSz.Value

        # 名称校验（v1.11）
        $diskName = Get-SafeDiskName $txtName.Text
        if (-not $diskName) { $diskName = $Script:DefaultDiskName }
        if (-not (Test-EncodableName $diskName)) {
            Show-Box -Text ("名称里有系统编码不支持的字（emoji 之类），没法用作文件名。" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "请改成中文、英文、数字或常用符号。") `
                     -Caption '名称不能用' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $dirChk = Test-TargetFolder $txtDir.Text
        if (-not $dirChk.Ok) {
            Show-Box -Text ("存放位置不能用：" + [char]13 + [char]10 + [char]13 + [char]10 + $dirChk.Msg) `
                     -Caption '存放位置' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $targetDir = $dirChk.Folder
        $targetPath = ''
        try { $targetPath = Get-UniqueVhdPath -Folder $targetDir -DiskName $diskName }
        catch {
            Show-Box -Text $_.Exception.Message -Caption '名称冲突' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        # 空间检查（v1.12）：报告值 + 真实写入探针，两道都过才继续。
        #
        # 以前这里只看 $vol.SizeRemaining，而且 $vol 是上面某个分支留下的旧对象。
        # 报告值不可靠（实测同一目录有 436GB 可用却报 0KB），所以：
        #   · 报告值足够 → 直接过
        #   · 报告值不足 → 不立刻拒绝，先真写一个 64MB 的探针文件验证
        #   · 探针写不进去 → 才报「空间不足」，并说明是报告值还是实测
        $needBytes = [int64]$size * 1GB + 5GB
        $freeB = Get-DiskFreeBytes $targetDir
        $reportTxt = if ($freeB -ge 0) { Format-Size $freeB } else { '未知' }
        if ($freeB -lt $needBytes) {
            AddLog "分区报告剩余 $reportTxt（需要 $(Format-Size $needBytes)），做一次真实写入测试..."
            $wchk = Test-FolderWritable -Folder $targetDir -ProbeMB 64
            if (-not $wchk.Ok) {
                $msg = '空间不够，装不了。' + [char]13 + [char]10 + [char]13 + [char]10 +
                       ('目录：{0}' -f $targetDir) + [char]13 + [char]10 +
                       ('需要：{0}（设定 {1} GB + 5GB 余量）' -f (Format-Size $needBytes), $size) + [char]13 + [char]10 +
                       ('系统报告剩余：{0}' -f $reportTxt) + [char]13 + [char]10 +
                       ('实际写入测试：{0}' -f $wchk.Msg) + [char]13 + [char]10 + [char]13 + [char]10 +
                       '怎么办：' + [char]13 + [char]10 +
                       '  · 把「大小」调小一点' + [char]13 + [char]10 +
                       '  · 换个剩余空间更大的文件夹' + [char]13 + [char]10 +
                       '  · 清理一下这个分区'
                Show-Box -Text $msg -Caption '空间不足' `
                         -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                         -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                return
            }
            AddLog "实测可写（$($wchk.Msg)），报告值明显偏小，按实测继续"
        } else {
            # 报告值够，也要确认能写 —— 配额 / ACL / 只读 这类问题报告值看不出来
            $wchk = Test-FolderWritable -Folder $targetDir -ProbeMB 64
            if (-not $wchk.Ok) {
                Show-Box -Text ('这个文件夹写不进去：' + [char]13 + [char]10 + [char]13 + [char]10 +
                                ('目录：{0}' -f $targetDir) + [char]13 + [char]10 +
                                ('原因：{0}' -f $wchk.Msg) + [char]13 + [char]10 + [char]13 + [char]10 +
                                '换个文件夹试试（比如 D:\VHD）。') `
                         -Caption '无法写入' `
                         -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                         -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                return
            }
        }

        $m = "确认开始安装？" + [char]13 + [char]10 + [char]13 + [char]10 +
             "    系统名称：$diskName   （开机菜单里显示这一行）" + [char]13 + [char]10 +
             "    镜像：$($script:SelWim)" + [char]13 + [char]10 +
             "    版本：$($script:SelEdition)（索引 $($script:SelIndex)）" + [char]13 + [char]10 +
             "    位置：$targetPath" + [char]13 + [char]10 +
             "    大小：最大 $size GB（文件按实际使用增长；但请留够剩余空间，预检按该值检查）" + [char]13 + [char]10 + [char]13 + [char]10 +
             "需要 10～40 分钟，期间别关机。" + [char]13 + [char]10 +
             "原系统不会被改动，已装好的其他系统也不会被改动。"
        $r = Show-Box -Text $m -Caption '确认' `
             -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo) `
             -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) `
             -Default ([System.Windows.Forms.MessageBoxDefaultButton]::Button1)
        if ($r -ne 'Yes') { return }

        $script:Busy = $true
        $btnGo.Enabled = $false
        $btnPickWim.Enabled = $false
        $cmbWim.Enabled = $false
        $txtDir.Enabled = $false
        $btnBrowse.Enabled = $false
        $numSz.Enabled = $false
        $txtName.Enabled = $false
        $btnNameGen.Enabled = $false
        $btnNameNum.Enabled = $false
        $pb.Value = 0

        try {
            # 【v1.29】日志跟着安装位置走：<存放目录>\虚拟硬盘系统-日志\
            Set-LogDir -VhdDir $targetDir
            AddLog '========== 开始安装 =========='
            AddLog "系统名称: $diskName"
            AddLog "版本: $($script:SelEdition)（索引 $($script:SelIndex)）"
            AddLog "磁盘大小: $size GB"
            $res = Invoke-Install -WimPath $script:SelWim -TargetFolder $targetDir -SizeGB $size `
                -ImageIndex ([int]$script:SelIndex) `
                -EditionName $script:SelEdition -DiskName $diskName `
                -OnProgress { param($p) if ($p -ge 0 -and $p -le 100) { $pb.Value = $p; [System.Windows.Forms.Application]::DoEvents() } } `
                -OnStatus { param($s) $lblSt.Text = $s; [System.Windows.Forms.Application]::DoEvents(); Write-Log $s }

            AddLog '========== 安装完成 =========='
            $lblSt.Text = "安装完成，重启后菜单里选「$diskName」"
            $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(0, 132, 66)
            $pb.Value = 100

            $okMsg = "装好了！" + [char]13 + [char]10 + [char]13 + [char]10 +
                     "接下来：" + [char]13 + [char]10 +
                     "1. 重启电脑" + [char]13 + [char]10 +
                     "2. 开机时会出现选择菜单（没出现就按一下方向键）" + [char]13 + [char]10 +
                     "3. 选「$diskName」进入新系统" + [char]13 + [char]10 + [char]13 + [char]10 +
                     "第一次进桌面要初始化几分钟，正常现象。" + [char]13 + [char]10 + [char]13 + [char]10 +
                     "想再装一个：关掉本窗口重新打开，换个名称即可。" + [char]13 + [char]10 +
                     "不想要了：运行「双击我-卸载新系统.bat」。"
            Show-Box -Text $okMsg -Caption '安装成功' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

            $ask = Show-Box -Text '现在重启吗？' -Caption '重启' `
                   -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo) `
                   -Icon ([System.Windows.Forms.MessageBoxIcon]::Question) `
                   -Default ([System.Windows.Forms.MessageBoxDefaultButton]::Button2)
            if ($ask -eq 'Yes') { Restart-Computer -Force }

        } catch {
            AddLog "失败: $_"
            $lblSt.Text = '安装失败'
            $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(188, 50, 50)
            $pb.Value = 0
            # 提示语必须和实际清理行为一致：
            #   * 系统文件已写完、只差注册启动项 → 故意保留 vhdx（不重装也能救回来）
            #   * 其它失败 → 本次创建的文件才会被删（$createdHere）
            # 原来固定写「已自动清理」，但 BCD 失败时是刻意保留的，用户会误以为空间回来了。
            # Invoke-Install 在保留 vhdx 时会把「系统文件已经完整写入虚拟磁盘」写进异常消息。
            $keepVhdHint = ("$_" -match '系统文件已经完整写入虚拟磁盘')
            $cleanNote = if ($keepVhdHint) {
                "系统文件已完整写入虚拟磁盘，为免重装已保留该文件（未删除）。" + [char]13 + [char]10 +
                "可以打开「开始.bat」选 8（修复启动菜单），或双击「急救工具\修复启动菜单-管理员运行.bat」，只补注册启动项。"
            } else {
                "本次创建的虚拟磁盘文件已清理，原系统没受影响。"
            }
            $failMsg = "安装失败：" + [char]13 + [char]10 + [char]13 + [char]10 + "$_" + [char]13 + [char]10 + [char]13 + [char]10 +
                       "常见原因：" + [char]13 + [char]10 +
                       "  · 目标分区空间不足" + [char]13 + [char]10 +
                       "  · 镜像文件损坏" + [char]13 + [char]10 +
                       "  · 杀毒软件拦截" + [char]13 + [char]10 + [char]13 + [char]10 +
                       $cleanNote + [char]13 + [char]10 + [char]13 + [char]10 +
                       "日志：$Script:LogFile"
            Show-Box -Text $failMsg -Caption '安装失败' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        } finally {
            $script:Busy = $false
            $btnPickWim.Enabled = $true
            $cmbWim.Enabled = $true
            $txtDir.Enabled = $true
            $btnBrowse.Enabled = $true
            $numSz.Enabled = $true
            $txtName.Enabled = $true
            $btnNameGen.Enabled = $true
            $btnNameNum.Enabled = $true
            Refresh-SysList
            UpdateNameHint
            UpdateDirHint
            UpdateGo
        }
    }))

    $form.Add_Shown({
        AddLog "程序启动 v$($Script:Version)"
        AddLog "管理员: $(Test-Admin)"
        try {
            Refresh-All
        } catch {
            AddLog "界面刷新失败: $($_.Exception.Message)"
            $initMsg = "界面初始化出错：" + [char]13 + [char]10 + [char]13 + [char]10 +
                       $_.Exception.Message + [char]13 + [char]10 + [char]13 + [char]10 +
                       "日志：$Script:LogFile"
            Show-Box -Text $initMsg -Caption '初始化失败' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })

    [void]$form.ShowDialog()
}

try {
    Show-Gui
} catch {
    $msg = $_.Exception.Message
    Write-Log "顶层异常: $msg" 'ERROR'
    try {
        Add-Type -AssemblyName System.Windows.Forms -EA SilentlyContinue
        $startMsg = "程序启动失败：" + [char]13 + [char]10 + [char]13 + [char]10 +
                    $msg + [char]13 + [char]10 + [char]13 + [char]10 +
                    "日志：$Script:LogFile"
        [System.Windows.Forms.MessageBox]::Show(
            $startMsg, '启动失败',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button1) | Out-Null
    } catch {
        Write-Host "启动失败: $msg" -ForegroundColor Red
    }
    if ($ConsoleMode) { Write-Host "启动失败: $msg" -ForegroundColor Red; Read-Host '按回车退出' }
}
