param()

# ============================================================
# New System: diagnose and install drivers  v1.1
# Author: connectsegabot
#
# Where to run: **inside the newly installed virtual system** (not the original one).
#
# What v1.1 fixed:
#  1) v1.0 counted every device with Problem≠0 as "faulty", so 553 CM_PROB_PHANTOM entries
#     (historical device records a cloned image leaves in the registry) drowned out the 3 real faults.
#     A phantom is not a fault - the hardware left the machine long ago, only the record was never cleaned.
#  2) v1.0 ran pnputil /add-driver <folder> /subdirs in one shot, and with 154 INF files in that folder
#     it still reported "total driver packages: 0".
#     v1.1 first matches the hardware IDs of the faulty devices against the INF files, then installs INF by INF.
#     That avoids /subdirs and does not have to walk all 154 packages.
#
# Report file: <some drive>:\<ProductName>-logs\new-system-report.txt
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.33'
try { $Host.UI.RawUI.WindowTitle = "New System Diagnose and Install Drivers v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] Shared module. src/build/inline_shared.py inlines this file at
# build time, and the .bat payload is still a self-contained single file.
. "$PSScriptRoot\..\shared\en\Logging.ps1"

Say ""
Say "  New System Diagnose and Install Drivers  v$($Script:Version)" 'Cyan'
Say "  Author: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [ERROR] Administrator rights are required. Right-click -> Run as administrator." 'Red'
    Read-Host "  Press Enter to exit"
    exit 1
}

$report = New-Object System.Collections.ArrayList
function Add-Line { param([string]$T = '') [void]$report.Add($T) }

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
Add-Line "==================== New system diagnostics v$($Script:Version) ===================="
Add-Line ("Computer     : " + $env:COMPUTERNAME)
Add-Line ("System       : " + $os.Caption + "  Build " + $os.BuildNumber)
Add-Line ("Boot time    : " + $os.LastBootUpTime)
Add-Line ("Uptime       : " + [string]([datetime]::Now - $os.LastBootUpTime))
Add-Line ("System drive : " + $env:SystemDrive)
Add-Line ""

# ---------- Real faults only, no phantoms ----------
#   22 = CM_PROB_DISABLED (disabled, usually on purpose)
#   45 = CM_PROB_PHANTOM (historical record, device not present)
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

Say "[1/4] Collecting genuinely faulty devices (phantoms skipped)..." 'White'
$problems = @(Get-RealProblems)
Add-Line "---------- Genuinely faulty devices ----------"
Add-Line ("{0} in total" -f $problems.Count)
Add-Line ""
foreach ($d in $problems) {
    $hw = @()
    try { $hw = @((Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data) } catch {}
    Add-Line ("[{0}] {1}" -f $d.Status, $d.FriendlyName)
    Add-Line ("    problem code: {0}   class: {1}" -f $d.Problem, $d.Class)
    Add-Line ("    instance ID: {0}" -f $d.InstanceId)
    if ($hw.Count -gt 0) { Add-Line ("    hardware ID: " + ($hw -join ' ; ')) }
    Add-Line ""
}
Say ("      {0} genuine faults" -f $problems.Count) 'DarkGray'

# ---------- Find the driver folders ----------
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
Add-Line "---------- Driver library ----------"
if ($allInf.Count -eq 0) { Add-Line "no INF found at all" }
foreach ($dd in $drvDirs) { Add-Line ("folder: " + $dd) }
Add-Line ("INF files in total: {0}" -f $allInf.Count)
Add-Line ""
Say ("      {0} driver folders, {1} INF files" -f $drvDirs.Count, $allInf.Count) 'DarkGray'

# ---------- Match INF files by hardware ID ----------
Say "[2/4] Matching INF files by hardware ID ..." 'White'
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
Say ("      read the contents of {0} INF files" -f $infText.Count) 'DarkGray'

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
    Say ("      {0}  -> {1} matching INF files" -f $d.FriendlyName, $matched.Count) 'DarkGray'
    Add-Line ("match: {0}  ({1} INF files)" -f $d.FriendlyName, $matched.Count)
    foreach ($mi in $matched) { Add-Line ("    " + $mi) }
}

# ---------- Install on the spot ----------
Say "[3/4] Installing on the spot (force a device rescan first)..." 'White'
Add-Line ""
Add-Line "---------- On-the-spot installation result ----------"
$scan = ''
try { $scan = (& pnputil /scan-devices 2>&1 | Out-String) } catch {}
$scanTxt = ($scan -replace "\s+", ' ').Trim()
Say ("      device rescan: " + $scanTxt) 'DarkGray'
Add-Line ("device rescan: " + $scanTxt)
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
        # [v1.32] English pnputil says "Driver package added successfully" (added BEFORE
        # successfully) - the old pattern 'successfully added' never matched, so every
        # install was reported as "not added" even when it worked. Also fall back to
        # checking the driver store, so a verdict no longer depends on localized text.
        $okAdd = ($t -match '已成功添加|已成功导入|added successfully|successfully added')
        if (-not $okAdd) {
            try { $enumTxt = (& pnputil.exe /enum-drivers 2>&1 | Out-String) } catch { $enumTxt = '' }
            if ($enumTxt -and $enumTxt.IndexOf($leaf, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $okAdd = $true }
        }
        if ($okAdd) { Say ("      {0} => added" -f $leaf) 'Green' } else { Say ("      {0} => not added" -f $leaf) 'Yellow' }
        Add-Line ("--- {0}" -f $inf)
        Add-Line ("    result: " + $(if ($okAdd) { 'added' } else { 'not added' }))
        foreach ($l in @($t -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Add-Line ("    " + $l) }
        if ($e.Trim()) { foreach ($l in @($e -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 4)) { Add-Line ("    [err] " + $l) } }
    }
}

# ---------- Re-check ----------
Say "[4/4] Re-checking ..." 'White'
Start-Sleep -Seconds 5
try { & pnputil /scan-devices 2>&1 | Out-Null } catch {}
Start-Sleep -Seconds 5
$after = @(Get-RealProblems)
Add-Line ""
Add-Line "---------- Still faulty after installation ----------"
Add-Line ("{0} in total" -f $after.Count)
foreach ($d in $after) {
    Add-Line ("[{0}] {1}   problem code {2}" -f $d.Status, $d.FriendlyName, $d.Problem)
    Add-Line ("    instance ID: {0}" -f $d.InstanceId)
}

$netAll = @(Get-NetAdapter -ErrorAction SilentlyContinue)
$netUp = @($netAll | Where-Object { $_.Status -eq 'Up' })
Add-Line ""
Add-Line "---------- Network adapters ----------"
foreach ($a in $netAll) { Add-Line ("{0} | {1} | {2}" -f $a.Name, $a.InterfaceDescription, $a.Status) }
Add-Line ("adapters with status Up: {0}" -f $netUp.Count)
Add-Line ""
Add-Line "==================== Diagnostics finished ===================="

# ---------- Write the report ----------
# [v1.29] The report is no longer dropped in the drive root; everything goes to <drive>:\<ProductName>-logs\
# (previously every drive root gained a "new-system-report.txt", and a few installs made a mess)
$saved = @()
foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
    if (-not $v.DriveLetter) { continue }
    if ($v.DriveType -ne 'Fixed') { continue }
    $dir = "{0}:\Virtual Hard Disk System-logs" -f $v.DriveLetter
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        $outFile = Join-Path $dir 'new-system-report.txt'
        $report -join "`r`n" | Set-Content -LiteralPath $outFile -Encoding UTF8 -ErrorAction Stop
        $saved += $outFile
    } catch {}
}

Say ""
Say ("  genuine faults: {0} before -> {1} after" -f $problems.Count, $after.Count) 'Cyan'
Say ("  adapters Up: {0}" -f $netUp.Count) 'Cyan'
if ($saved.Count -gt 0) {
    Say "  Report written to:" 'Green'
    foreach ($s in $saved) { Say ("      " + $s) 'Green' }
}
Say ""
Read-Host "  Press Enter to exit"
