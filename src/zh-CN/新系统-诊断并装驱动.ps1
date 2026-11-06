param()

# ============================================================
# 新系统诊断并装驱动  v1.1
# 作者: connectsegabot
#
# 在哪运行：**新装的那个虚拟系统里**（不是原来的系统）。
#
# v1.1 修了什么：
#  1) v1.0 把所有 Problem≠0 的设备都算「有问题」，结果 553 个 CM_PROB_PHANTOM
#     （克隆镜像留在注册表里的历史设备记录）把真正的 3 个故障淹掉了。
#     phantom 不是故障 —— 设备早就不在机器上了，只是记录没清。
#  2) v1.0 用 pnputil /add-driver <目录> /subdirs 一次装完，实测该目录下
#     154 个 INF 却报「驱动程序包总数: 0」。
#     v1.1 改成：先按故障设备的硬件 ID 去 INF 里找匹配项，再逐个 INF 装。
#     既绕开 /subdirs，也不用把 154 个包全跑一遍。
#
# 结果文件：<某个盘>:\新系统诊断.txt
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.33'
try { $Host.UI.RawUI.WindowTitle = "新系统诊断并装驱动 v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] 共享模块。打包时由 src/build/inline_shared.py 内联本文件，
# .bat 载荷仍是自包含单文件。
. "$PSScriptRoot\..\shared\zh-CN\Logging.ps1"

Say ""
Say "  新系统诊断并装驱动  v$($Script:Version)" 'Cyan'
Say "  作者: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [错误] 需要管理员权限。请右键 -> 以管理员身份运行。" 'Red'
    Read-Host "  按回车退出"
    exit 1
}

$report = New-Object System.Collections.ArrayList
function Add-Line { param([string]$T = '') [void]$report.Add($T) }

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
Add-Line "==================== 新系统诊断 v$($Script:Version) ===================="
Add-Line ("计算机名 : " + $env:COMPUTERNAME)
Add-Line ("系统     : " + $os.Caption + "  Build " + $os.BuildNumber)
Add-Line ("启动时间 : " + $os.LastBootUpTime)
Add-Line ("运行时长 : " + [string]([datetime]::Now - $os.LastBootUpTime))
Add-Line ("系统盘   : " + $env:SystemDrive)
Add-Line ""

# ---------- 只要真故障，不要 phantom ----------
#   22 = CM_PROB_DISABLED（被禁用，通常是有意为之）
#   45 = CM_PROB_PHANTOM（历史记录，设备不在）
$ignoreProblem = @(0, 22, 45)
function Get-RealProblems {
    $list = @()
    $seen = @{}
    foreach ($d in @(Get-PnpDevice -ErrorAction SilentlyContinue)) {
        if (-not $d) { continue }
        $p = $d.Problem
        if ($p -eq $null) { $p = 0 }
        if ($ignoreProblem -contains [int]$p) { continue }
        if ($d.Status -eq 'Unknown') { continue }
        if ($seen.ContainsKey($d.InstanceId)) { continue }
        $seen[$d.InstanceId] = 1
        $list += $d
    }
    return $list
}

Say "[1/4] 收集真故障设备（跳过 phantom）..." 'White'
$problems = @(Get-RealProblems)
Add-Line "---------- 真故障设备 ----------"
Add-Line ("共 {0} 个" -f $problems.Count)
Add-Line ""
foreach ($d in $problems) {
    $hw = @()
    try { $hw = @((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data) } catch {}
    Add-Line ("[{0}] {1}" -f $d.Status, $d.FriendlyName)
    Add-Line ("    问题码: {0}   类: {1}" -f $d.Problem, $d.Class)
    Add-Line ("    实例ID: {0}" -f $d.InstanceId)
    if ($hw.Count -gt 0) { Add-Line ("    硬件ID: " + ($hw -join ' ; ')) }
    Add-Line ""
}
Say ("      真故障 {0} 个" -f $problems.Count) 'DarkGray'

# ---------- 找驱动目录 ----------
$drvDirs = @()
foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
    if (-not $v.DriveLetter) { continue }
    if (([string]$v.DriveLetter).ToUpper() -eq (([string]$env:SystemDrive).TrimEnd(':').ToUpper())) { continue }
    foreach ($nm in @('NewSystemDriver', '新系统驱动')) {
        $c = "{0}:\{1}" -f $v.DriveLetter, $nm
        if (Test-Path -LiteralPath $c) { $drvDirs += $c }
    }
}
foreach ($c in @('C:\NewSystemDriver', 'C:\新系统驱动')) {
    if (Test-Path -LiteralPath $c) { $drvDirs += $c }
}
$drvDirs = @($drvDirs | Select-Object -Unique)
$allInf = @()
foreach ($dd in $drvDirs) { $allInf += @(Get-ChildItem -LiteralPath $dd -Recurse -Filter *.inf -EA SilentlyContinue) }
Add-Line "---------- 驱动库 ----------"
if ($allInf.Count -eq 0) { Add-Line "没找到任何 INF" }
foreach ($dd in $drvDirs) { Add-Line ("目录: " + $dd) }
Add-Line ("INF 总数: {0}" -f $allInf.Count)
Add-Line ""
Say ("      驱动目录 {0} 个，INF {1} 个" -f $drvDirs.Count, $allInf.Count) 'DarkGray'

# ---------- 按硬件 ID 匹配 INF ----------
Say "[2/4] 按硬件 ID 找匹配的 INF ..." 'White'
function Get-MatchKeys {
    param([string]$inst, $hwList)
    $keys = @()
    foreach ($h in @($hwList)) {
        if (-not $h) { continue }
        $keys += $h
        $keys += ($h -replace '&REV_[0-9A-Fa-f]+', '')
    }
    $m = [regex]::Match($inst, '(?i)((?:PCI|USB)\\VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4}&SUBSYS_[0-9A-F]{8})')
    if ($m.Success) { $keys += $m.Groups[1].Value }
    $m2 = [regex]::Match($inst, '(?i)((?:PCI|USB)\\VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4})')
    if ($m2.Success) { $keys += $m2.Groups[1].Value }
    return @($keys | Where-Object { $_ } | Select-Object -Unique)
}

$infText = @{}
foreach ($f in $allInf) {
    try {
        $t = ''
        try {
            $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Unicode)
            if ($t -notmatch '\[Version\]') { $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default) }
        } catch { $t = '' }
        if ($t) { $infText[$f.FullName] = $t }
    } catch {}
}
Say ("      已读取 {0} 个 INF 内容" -f $infText.Count) 'DarkGray'

$installQueue = New-Object System.Collections.ArrayList
foreach ($d in $problems) {
    $hw = @()
    try { $hw = @((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data) } catch {}
    $keys = Get-MatchKeys -inst $d.InstanceId -hwList $hw
    $matched = @()
    foreach ($kv in $infText.GetEnumerator()) {
        foreach ($k in $keys) {
            if ($kv.Value.IndexOf($k, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $matched += $kv.Key
                break
            }
        }
    }
    $matched = @($matched | Select-Object -Unique)
    [void]$installQueue.Add([pscustomobject]@{ Dev = $d; Keys = $keys; Infs = $matched })
    Say ("      {0}  -> 匹配 {1} 个 INF" -f $d.FriendlyName, $matched.Count) 'DarkGray'
    Add-Line ("匹配: {0}  ({1} 个 INF)" -f $d.FriendlyName, $matched.Count)
    foreach ($mi in $matched) { Add-Line ("    " + $mi) }
}

# ---------- 现场安装 ----------
Say "[3/4] 现场安装（先强制重扫设备）..." 'White'
Add-Line ""
Add-Line "---------- 现场安装结果 ----------"
$scan = ''
try { $scan = (& pnputil /scan-devices 2>&1 | Out-String) } catch {}
$scanTxt = ($scan -replace "\s+", ' ').Trim()
Say ("      设备重扫: " + $scanTxt) 'DarkGray'
Add-Line ("设备重扫: " + $scanTxt)
Start-Sleep -Seconds 3

$log = Join-Path $env:TEMP 'pnputil_one.log'
foreach ($item in $installQueue) {
    if ($item.Infs.Count -eq 0) { continue }
    foreach ($inf in $item.Infs) {
        try { if (Test-Path -LiteralPath $log) { Remove-Item $log -Force -EA SilentlyContinue } } catch {}
        try { if (Test-Path ($log + '.err')) { Remove-Item ($log + '.err') -Force -EA SilentlyContinue } } catch {}
        $p = Start-Process -FilePath 'pnputil.exe' -ArgumentList @('/add-driver', "`"$inf`"", '/install') `
                -RedirectStandardOutput $log -RedirectStandardError ($log + '.err') `
                -NoNewWindow -PassThru -ErrorAction Stop
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited) {
            Start-Sleep -Milliseconds 500
            if ($sw.ElapsedMilliseconds -gt 180000) { try { Stop-Process -Id $p.Id -Force -EA SilentlyContinue } catch {}; break }
        }
        $t = ''
        try { $t = [IO.File]::ReadAllText($log, [Text.Encoding]::Default) } catch {}
        $e = ''
        try { if (Test-Path ($log + '.err')) { $e = [IO.File]::ReadAllText($log + '.err', [Text.Encoding]::Default) } } catch {}
        $leaf = Split-Path -Leaf $inf
        # [v1.32] 英文版 pnputil 的成功提示是 "Driver package added successfully"
        # （added 在 successfully 前面），旧匹配串永远打不中，导致实际装上了也报「未添加」。
        # 另外加驱动仓库兜底：文字匹配不上时查 pnputil /enum-drivers 确认，不再依赖本地化文字。
        $okAdd = ($t -match '已成功添加|已成功导入|added successfully|successfully added')
        if (-not $okAdd) {
            try { $enumTxt = (& pnputil.exe /enum-drivers 2>&1 | Out-String) } catch { $enumTxt = '' }
            if ($enumTxt -and $enumTxt.IndexOf($leaf, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $okAdd = $true }
        }
        if ($okAdd) { Say ("      {0} => 已添加" -f $leaf) 'Green' } else { Say ("      {0} => 未添加" -f $leaf) 'Yellow' }
        Add-Line ("--- {0}" -f $inf)
        Add-Line ("    结果: " + $(if ($okAdd) { '已添加' } else { '未添加' }))
        foreach ($l in @($t -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Add-Line ("    " + $l) }
        if ($e.Trim()) { foreach ($l in @($e -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 4)) { Add-Line ("    [err] " + $l) } }
    }
}

# ---------- 复核 ----------
Say "[4/4] 复核 ..." 'White'
Start-Sleep -Seconds 5
try { & pnputil /scan-devices 2>&1 | Out-Null } catch {}
Start-Sleep -Seconds 5
$after = @(Get-RealProblems)
Add-Line ""
Add-Line "---------- 装完后仍故障 ----------"
Add-Line ("共 {0} 个" -f $after.Count)
foreach ($d in $after) {
    Add-Line ("[{0}] {1}   问题码 {2}" -f $d.Status, $d.FriendlyName, $d.Problem)
    Add-Line ("    实例ID: {0}" -f $d.InstanceId)
}

$netAll = @(Get-NetAdapter -ErrorAction SilentlyContinue)
$netUp = @($netAll | Where-Object { $_.Status -eq 'Up' })
Add-Line ""
Add-Line "---------- 网卡 ----------"
foreach ($a in $netAll) { Add-Line ("{0} | {1} | {2}" -f $a.Name, $a.InterfaceDescription, $a.Status) }
Add-Line ("状态为 Up 的网卡: {0} 个" -f $netUp.Count)
Add-Line ""
Add-Line "==================== 诊断结束 ===================="

# ---------- 写报告 ----------
# 【v1.29】报告不再直接丢在盘根，统一进 <盘>:\虚拟硬盘系统-日志\
# （以前每个盘根都会多一个「新系统诊断.txt」，装几次系统就糊一片）
$saved = @()
foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
    if (-not $v.DriveLetter) { continue }
    if ($v.DriveType -ne 'Fixed') { continue }
    $dir = "{0}:\虚拟硬盘系统-日志" -f $v.DriveLetter
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        $outFile = Join-Path $dir '新系统诊断.txt'
        $report -join "`r`n" | Set-Content -LiteralPath $outFile -Encoding UTF8 -ErrorAction Stop
        $saved += $outFile
    } catch {}
}

Say ""
Say ("  真故障：装前 {0} 个 -> 装后 {1} 个" -f $problems.Count, $after.Count) 'Cyan'
Say ("  网卡 Up: {0} 个" -f $netUp.Count) 'Cyan'
if ($saved.Count -gt 0) {
    Say "  报告已写到：" 'Green'
    foreach ($s in $saved) { Say ("      " + $s) 'Green' }
}
Say ""
Read-Host "  按回车退出"
