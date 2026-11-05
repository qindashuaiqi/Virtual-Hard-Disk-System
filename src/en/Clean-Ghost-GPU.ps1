param()

# ============================================================
# New system GPU check-up and clean-up   v2.0
# Author: connectsegabot
#
# Where to run: **inside the newly installed virtual system** (not the original one).
#
# What v1.0 got wrong (users reported "the ghost GPU was not removed at all"):
#   1. It treated the "empty GPU" in Task Manager as a ghost adapter. But the Task Manager GPU list only enumerates
#      **active adapters**; ghost devices (hardware no longer present) never show up there.
#      What really takes that slot is an **IDD virtual display** enumerated under ROOT\DISPLAY
#      (installed by remote streaming / emulator software, Service=WUDFRd, with no real DX engine,
#      so VRAM, 3D and Video are all empty).
#   2. It trusted pnputil's exit code. pnputil /remove-device returns 0x0 for non-present devices
#      while deleting nothing, so the report claimed "3 deleted" although the records were still there.
#      v2.0 re-enumerates after deleting and reports "gone / still present" explicitly.
#   3. The deletion order was reversed. Remove-PnpDevice goes through DIF_REMOVE and can handle absent devices;
#      pnputil is only a supplement. v1.0 tried pnputil first and skipped on success, so nothing was ever fixed.
#
# Report file: <some drive>:\<ProductName>-logs\gpu-report.txt
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.31'
try { $Host.UI.RawUI.WindowTitle = "New System GPU Check-up v$($Script:Version) - connectsegabot" } catch {}

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}

Say ""
Say "  New System GPU Check-up and Clean-up  v$($Script:Version)" 'Cyan'
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
Add-Line "=============== GPU diagnostics v$($Script:Version) ==============="
Add-Line ("Computer : " + $env:COMPUTERNAME)
Add-Line ("System   : " + $os.Caption + "  Build " + $os.BuildNumber)
Add-Line ("System drive : " + $env:SystemDrive)
Add-Line ""

function Get-ProblemText {
    param([int]$Code)
    switch ($Code) {
        0  { return 'OK' }
        3  { return 'driver is corrupt' }
        10 { return 'device cannot start' }
        18 { return 'driver needs reinstalling' }
        22 { return 'disabled' }
        28 { return 'driver not installed' }
        31 { return 'driver cannot load' }
        43 { return 'stopped after reporting a failure' }
        45 { return 'ghost record (device not present)' }
        default { return ("problem code " + $Code) }
    }
}

# ---------- [1/5] Collect ----------
Say "[1/5] Reading display adapters..." 'White'

# Take the set Task Manager really enumerates (active adapters)
$activeNames = @()
try {
    foreach ($vc in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
        if ($vc.Name) { $activeNames += [string]$vc.Name }
    }
} catch {}

$adapters = @()
foreach ($d in @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)) {
    if (-not $d) { continue }

    $present = $false
    try {
        $v = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_IsPresent' -ErrorAction Stop).Data
        if ($v -eq $true) { $present = $true }
    } catch {}

    $prov = ''; $ver = ''; $inf = ''; $svc = ''
    try { $prov = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction Stop).Data } catch {}
    try { $ver = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction Stop).Data } catch {}
    try { $inf = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data } catch {}
    try { $svc = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction Stop).Data } catch {}

    $hw = @()
    try {
        $h = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
        if ($h) { $hw = @($h) }
    } catch {}

    $prob = 0
    if ($d.Problem -ne $null) { $prob = [int]$d.Problem }

    # [key] Identifying an IDD virtual display: ROOT enum + Display class + user-mode driver framework.
    # These devices are fake adapters created by software; Task Manager gives them a GPU slot
    # but there is no engine or VRAM data inside - that is the "empty GPU" users report.
    $isRoot = $d.InstanceId -like 'ROOT\*'
    $isIdd = $false
    if ($isRoot) {
        if ($svc -eq 'WUDFRd' -or $svc -like '*Idd*' -or $d.FriendlyName -like '*Virtual*') { $isIdd = $true }
        else { $isIdd = $true }   # everything under ROOT\DISPLAY is a software adapter
    }

    $kind = ''
    if (-not $present) { $kind = 'ghost' }
    elseif ($isIdd) { $kind = 'virtual display' }
    elseif ($prob -ne 0) { $kind = 'faulty' }
    else { $kind = 'in use' }

    $adapters += [pscustomobject]@{
        Name       = $d.FriendlyName
        InstanceId = $d.InstanceId
        Status     = [string]$d.Status
        Present    = $present
        Problem    = $prob
        Kind       = $kind
        IsIdd      = $isIdd
        Provider   = $prov
        Version    = $ver
        Inf        = $inf
        Service    = $svc
        HwIds      = $hw
    }
}

$realGpu = @($adapters | Where-Object { $_.Kind -eq 'in use' })
$idds    = @($adapters | Where-Object { $_.Kind -eq 'virtual display' })
$ghosts  = @($adapters | Where-Object { $_.Kind -eq 'ghost' })
$faults  = @($adapters | Where-Object { $_.Kind -eq 'faulty' })
$disabled = @($adapters | Where-Object { $_.Status -eq 'Error' -and $_.Problem -eq 22 })

# ---------- [2/5] Lay it out ----------
Say "[2/5] Classification..."
Add-Line "---------- Display adapters ----------"
Add-Line ("{0} in total: {1} really in use / {2} virtual displays / {3} ghosts / {4} faulty" -f `
    $adapters.Count, $realGpu.Count, $idds.Count, $ghosts.Count, $faults.Count)
Add-Line ""
Say ("  {0} in total: {1} really in use / {2} virtual displays / {3} ghosts / {4} faulty" -f `
    $adapters.Count, $realGpu.Count, $idds.Count, $ghosts.Count, $faults.Count) 'Cyan'
Say ""

foreach ($a in $adapters) {
    $col = 'Gray'
    if ($a.Kind -eq 'in use')       { $col = 'Green' }
    if ($a.Kind -eq 'faulty')       { $col = 'Yellow' }
    if ($a.Kind -eq 'virtual display') { $col = 'Magenta' }
    if ($a.Kind -eq 'ghost')        { $col = 'DarkGray' }

    Say ("  [{0}] {1}" -f $a.Kind, $a.Name) $col
    Say ("        status={0}  driver={1} {2}  INF={3}" -f (Get-ProblemText $a.Problem), $a.Provider, $a.Version, $a.Inf) 'DarkGray'
    Say ("        instance={0}" -f $a.InstanceId) 'DarkGray'

    Add-Line ("[{0}] {1}" -f $a.Kind, $a.Name)
    Add-Line ("    status: " + (Get-ProblemText $a.Problem) + "  (Status=" + $a.Status + ", Present=" + $a.Present + ")")
    Add-Line ("    driver: " + $a.Provider + " " + $a.Version + "  INF=" + $a.Inf + "  Service=" + $a.Service)
    Add-Line ("    instance: " + $a.InstanceId)
    if ($a.HwIds.Count -gt 0) { Add-Line ("    hardware: " + ($a.HwIds -join ' ; ')) }
    Add-Line ""
}

# ---------- [3/5] Conclusion: what the empty GPU really is ----------
Say "[3/5] Identifying the empty card in Task Manager..." 'White'
Add-Line "---------- What causes the empty GPU ----------"

if ($idds.Count -gt 0) {
    Add-Line ("The Task Manager Performance tab only enumerates **active** display adapters; ghost devices get no slot.")
    Add-Line ("So the empty GPU without data is actually one of these virtual displays (IDD):")
    foreach ($i in $idds) {
        Add-Line ("    " + $i.Name + "   instance=" + $i.InstanceId + "   INF=" + $i.Inf)
    }
    Add-Line ""
    Add-Line "They are installed by remote streaming / emulator software, have no real DX engine, and their VRAM and 3D usage stay empty."
    Say ("  empty GPU = virtual display ({0}), not a ghost adapter" -f $idds.Count) 'Yellow'
}
if ($ghosts.Count -gt 0) {
    Add-Line ("There are also {0} ghost display adapters (history left by cloning an image):" -f $ghosts.Count)
    foreach ($g in $ghosts) { Add-Line ("    " + $g.Name + "   " + $g.InstanceId) }
    Add-Line "Ghost devices never show up in Task Manager, only under Show hidden devices, and are harmless leftovers."
    Say ("  plus {0} ghost records (harmless, they only clutter Device Manager)" -f $ghosts.Count) 'DarkGray'
}
if ($faults.Count -gt 0) {
    foreach ($f in $faults) { Add-Line ("Faulty adapter: " + $f.Name + " | " + (Get-ProblemText $f.Problem) + " | " + $f.InstanceId) }
    Say ("  {0} adapters are in a faulty state (usually a missing vendor driver)" -f $faults.Count) 'Yellow'
}
if ($disabled.Count -gt 0) {
    foreach ($x in $disabled) { Add-Line ("Disabled adapter: " + $x.Name + " | " + $x.InstanceId) }
}
Add-Line ""

# ---------- [4/5] Actions ----------
Add-Line "---------- Handling ----------"
$didSomething = $false
$stillGhost = 0
$stillIddOn = 0

# 4a. Virtual displays - this is the actual fix for the empty GPU
if ($idds.Count -gt 0) {
    Say "[4/5] Removing the empty GPU..." 'White'
    Say "      Disabling the virtual display makes the empty card disappear from Task Manager;" 'DarkGray'
    Say "      re-enable it when you need streaming/emulator software, it is fully reversible." 'DarkGray'
    Say ""
    foreach ($i in $idds) { Say ("      - " + $i.Name) 'Magenta' }
    Say ""
    $ans = Read-Host "  Disable these virtual displays? Type Y and press Enter to proceed, any other key to skip"
    if ($ans -match '^[Yy]') {
        foreach ($i in $idds) {
            $ok = $false
            $msg = ''
            try {
                Disable-PnpDevice -InstanceId $i.InstanceId -Confirm:$false -ErrorAction Stop
                $ok = $true
            } catch {
                $msg = $_.Exception.Message
                $o = (& pnputil /disable-device $i.InstanceId 2>&1 | Out-String)
                if ($LASTEXITCODE -eq 0) { $ok = $true; $msg = '' }
                elseif (-not $msg) { $msg = ($o -replace '\s+', ' ').Trim() }
            }
            # Re-check: only a problem code of 22 (disabled) means it really took effect
            $now = $null
            try { $now = Get-PnpDevice -InstanceId $i.InstanceId -ErrorAction Stop } catch {}
            $really = $false
            if ($now -ne $null -and $now.Problem -ne $null) {
                if ([int]$now.Problem -eq 22) { $really = $true }
            }
            if ($ok -and $really) {
                Say ("    disabled: " + $i.Name) 'Green'
                Add-Line ("disabling succeeded: " + $i.Name + " | " + $i.InstanceId)
            } elseif ($ok -and -not $really) {
                Say ("    command reported success but the state did not change: " + $i.Name) 'Yellow'
                Add-Line ("disabling result uncertain: " + $i.Name + " | the command returned success but re-check Status=" + $(if ($now) { $now.Status } else { 'none' }) + " Problem=" + $(if ($now) { $now.Problem } else { 'none' }))
            } else {
                Say ("    disabling failed: " + $i.Name) 'Red'
                Add-Line ("disabling failed: " + $i.Name + " | " + $msg)
            }
        }
        $didSomething = $true
        Say ""
    } else {
        Add-Line "user skipped disabling virtual displays"
        Say "      Skipped." 'DarkGray'
        Say "      To do it manually: Device Manager -> Display adapters -> right-click the entry -> Disable device" 'DarkGray'
        Say ""
    }
} else {
    Add-Line "no virtual display (ROOT\DISPLAY) found - if the empty GPU persists, say which slot it is"
}

# 4b. Ghost records
if ($ghosts.Count -eq 0) {
    Say "  No ghost records to clean." 'DarkGray'
} else {
    Say "  Also found $($ghosts.Count) ghost records (image leftovers, not present on this machine, harmless)." 'White'
    Say "      Cleaning them only makes the Show hidden devices list tidier." 'DarkGray'
    Say ""
    $ans2 = Read-Host "  Clean these ghost records? Type Y and press Enter to proceed, any other key to skip"
    if ($ans2 -match '^[Yy]') {
        foreach ($g in $ghosts) {
            $ok = $false; $via = ''; $msg = ''

            # [order fix] Remove-PnpDevice first (DIF_REMOVE handles absent devices)
            try {
                Remove-PnpDevice -InstanceId $g.InstanceId -Confirm:$false -ErrorAction Stop
                $ok = $true; $via = 'Remove-PnpDevice'
            } catch {
                $msg = $_.Exception.Message
            }
            # then fall back to pnputil
            if (-not $ok) {
                $o = (& pnputil /remove-device $g.InstanceId 2>&1 | Out-String)
                if ($LASTEXITCODE -eq 0) { $ok = $true; $via = 'pnputil' }
                else { if (-not $msg) { $msg = ($o -replace '\s+', ' ').Trim() } }
            }

            # [must re-check] the command saying success does not mean it was deleted
            $still = $null
            try { $still = Get-PnpDevice -InstanceId $g.InstanceId -ErrorAction Stop } catch {}
            $gone = ($null -eq $still)

            if ($gone) {
                Say ("    gone: " + $g.Name) 'Green'
                Add-Line ("ghost deleted (" + $via + "): " + $g.InstanceId)
            } else {
                Say ("    still present: " + $g.Name) 'Yellow'
                Add-Line ("ghost not deleted: " + $g.InstanceId + " | attempted via=" + $via + " | command result=" + $(if ($ok) { 'reported success' } else { 'failed' }) + " | error=" + $msg)
                Add-Line "    note: the record still occupies a slot in the registry Enum hive and needs manual handling (see below)"
            }
        }
        $didSomething = $true
    } else {
        Add-Line "user skipped ghost cleanup"
        Say "      Skipped." 'DarkGray'
    }
}

# ---------- [5/5] Re-check ----------
if ($didSomething) {
    Say ""
    Say "[5/5] Re-checking the current state..." 'White'
    Start-Sleep -Milliseconds 500
    $after = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)
    $stillGhost = 0
    $stillIddOn = 0
    foreach ($d in $after) {
        if (-not $d) { continue }
        $pres = $false
        try { $p = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_IsPresent' -ErrorAction Stop).Data; if ($p -eq $true) { $pres = $true } } catch {}
        $pr = 0
        if ($d.Problem -ne $null) { $pr = [int]$d.Problem }
        if (-not $pres) { $stillGhost++ }
        elseif ($d.InstanceId -like 'ROOT\*' -and $pr -ne 22) { $stillIddOn++ }
    }
    Add-Line ""
    Add-Line "---------- Re-check result ----------"
    Add-Line ("ghost records left: " + $stillGhost)
    Add-Line ("virtual displays still enabled: " + $stillIddOn)
    Say ("  re-check: {0} ghost records left, {1} virtual displays still enabled" -f $stillGhost, $stillIddOn) 'Cyan'
} else {
    Add-Line ""
    Add-Line "this run only diagnosed, no device was modified"
}

# ---------- Write the report ----------
Add-Line ""
Add-Line "==================== Diagnostics finished ===================="

# [v1.29] The report is no longer dropped in the drive root; everything goes to <drive>:\<ProductName>-logs\
$saved = @()
foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
    if (-not $v.DriveLetter) { continue }
    if ($v.DriveType -ne 'Fixed') { continue }
    $dir = "{0}:\Virtual Hard Disk System-logs" -f $v.DriveLetter
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        $p = Join-Path $dir 'gpu-report.txt'
        $report -join "`r`n" | Set-Content -LiteralPath $p -Encoding UTF8 -ErrorAction Stop
        $saved += $p
    } catch {}
}

Say ""
Say "  ------------------------------------------------------------" 'DarkGray'
foreach ($p in $saved) { Say ("  report saved: " + $p) 'Green' }

if ($stillGhost -gt 0) {
    Say ""
    Say "  Manual steps when ghost records still cannot be deleted:" 'Yellow'
    Say "    Device Manager -> View -> Show hidden devices -> Display adapters ->" 'DarkGray'
    Say "    right-click the grey entries -> Uninstall device -> reboot." 'DarkGray'
}
Say ""
Say "  After disabling a virtual display, reboot once for the Task Manager GPU list to refresh." 'Cyan'
Say ""
Read-Host "  Press Enter to exit"
