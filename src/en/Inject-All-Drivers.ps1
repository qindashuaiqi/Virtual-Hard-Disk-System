param(
    [string]$OriginDir = ''
)

# ============================================================
# Inject All Drivers  v1.3
# Author: connectsegabot
#
# Purpose: the installed virtual system shows "a pile of unknown devices" in Device Manager.
#   This moves every third-party driver package from this machine (chipset, ACPI, PCIe, network, audio, Bluetooth, GPU...)
#   into the virtual system in one go, so PnP picks them up after a reboot.
#
# Difference from "Inject Network Drivers": that one moves only the 9 Net-class packages, this one moves all 160+.
#
# It also keeps a copy of the exported drivers in NewSystemDriver on the vhdx drive, so if some devices stay
# unbound you can still install them on the spot inside the new system with Diagnose-And-Install-Drivers.bat.
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.33'
$Script:OriginDir = $OriginDir
try { $Host.UI.RawUI.WindowTitle = "Inject All Drivers v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] Shared module. src/build/inline_shared.py inlines this file at
# build time, and the .bat payload is still a self-contained single file.
. "$PSScriptRoot\..\shared\en\Logging.ps1"

Say ""
Say "  Inject All Drivers  v$($Script:Version)" 'Cyan'
Say "  Author: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [ERROR] Administrator rights are required. Close this window, right-click this file -> Run as administrator." 'Red'
    Say ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ---------- Exclude "the system running right now" ----------
$sysLetter = ([string]$env:SystemDrive).TrimEnd(':').ToUpper()
$sysVolId = ''
try { $sysVolId = [string](Get-Volume -DriveLetter $sysLetter -ErrorAction Stop).UniqueId } catch {}

function Test-IsRunningSystem {
    param($Vol)
    if (([string]$Vol.DriveLetter).ToUpper() -eq $sysLetter) { return $true }
    if ($sysVolId -and ([string]$Vol.UniqueId -eq $sysVolId)) { return $true }
    return $false
}

function Get-TargetCandidates {
    $list = @()
    $vhdDisks = @{}
    foreach ($d in @(Get-Disk -ErrorAction SilentlyContinue)) {
        if ([string]$d.BusType -eq 'File Backed Virtual') { $vhdDisks[[int]$d.Number] = $true }
    }
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        $root = "{0}:\" -f $v.DriveLetter
        if (-not (Test-Path -LiteralPath ($root + 'Windows\System32\ntoskrnl.exe'))) { continue }
        $diskNum = -1
        try { $diskNum = [int](Get-Partition -DriveLetter $v.DriveLetter -ErrorAction Stop).DiskNumber } catch {}
        $list += [pscustomobject]@{
            Letter  = [string]$v.DriveLetter
            Label   = [string]$v.FileSystemLabel
            Running = (Test-IsRunningSystem $v)
            IsVhd   = ($diskNum -ge 0 -and $vhdDisks.ContainsKey($diskNum))
            Disk    = $diskNum
            SizeGB  = [math]::Round($v.Size / 1GB, 1)
            FreeGB  = [math]::Round($v.SizeRemaining / 1GB, 1)
        }
    }
    return $list
}

function Find-VhdxFiles {
    $found = @()
    if ($Script:OriginDir -and (Test-Path -LiteralPath $Script:OriginDir)) {
        $c = Join-Path $Script:OriginDir 'NewSystemDisk.vhdx'
        if (Test-Path -LiteralPath $c) { $found += $c }
    }
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        if ($v.DriveType -ne 'Fixed') { continue }
        $c = "{0}:\NewSystemDisk.vhdx" -f $v.DriveLetter
        if (Test-Path -LiteralPath $c) {
            $full = (Get-Item -LiteralPath $c).FullName
            if ($found -notcontains $full) { $found += $full }
        }
    }
    return $found
}

function Mount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("attach_all_{0}.txt" -f $PID)
    @("select vdisk file=`"$Path`"", 'attach vdisk', 'exit') | Set-Content -LiteralPath $dpFile -Encoding Default
    $r = ''
    try { $r = (& diskpart /s $dpFile 2>&1 | Out-String) } catch { $r = $_.Exception.Message }
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
    if ($r -match 'successfully|成功') { return $true }
    Say ("      mount returned: " + (($r -replace "\s+", ' ').Trim())) 'Yellow'
    return $false
}

function Dismount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("detach_all_{0}.txt" -f $PID)
    @("select vdisk file=`"$Path`"", 'detach vdisk', 'exit') | Set-Content -LiteralPath $dpFile -Encoding Default
    try { & diskpart /s $dpFile 2>&1 | Out-Null } catch {}
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
}

# ---------- [1/4] Find the target ----------
Say "[1/4] Finding the target system ..." 'White'

$attachedVhdx = ''
$targets = @(Get-TargetCandidates)
$usable = @($targets | Where-Object { -not $_.Running })
$vhdTargets = @($usable | Where-Object { $_.IsVhd })

if ($vhdTargets.Count -eq 0) {
    foreach ($f in @(Find-VhdxFiles)) {
        Say ("      found virtual disk {0}, mounting ..." -f $f) 'DarkGray'
        if (Mount-Vhdx -Path $f) {
            $attachedVhdx = $f
            Say "      mounted" 'Green'
            break
        }
    }
    if ($attachedVhdx) {
        Start-Sleep -Seconds 2
        $targets = @(Get-TargetCandidates)
        $usable = @($targets | Where-Object { -not $_.Running })
        $vhdTargets = @($usable | Where-Object { $_.IsVhd })
    }
}

if ($vhdTargets.Count -eq 1) {
    $target = $vhdTargets[0]
} elseif ($usable.Count -eq 0) {
    Say ""
    Say "  [ERROR] No injectable virtual system found." 'Red'
    Say ("         {0}: is the running system and cannot be the target (DISM reports Error 87)." -f $sysLetter) 'Yellow'
    Say "         And no NewSystemDisk.vhdx was found." 'Yellow'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
} else {
    Say "      Several injectable systems found:" 'White'
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $t = $usable[$i]
        $kind = if ($t.IsVhd) { 'virtual disk' } else { 'physical partition' }
        Say ("      [{0}] {1}:  {2}  {3} GB label={4}" -f ($i + 1), $t.Letter, $kind, $t.SizeGB, $t.Label)
    }
    $sel = Read-Host "      Enter a number (default 1)"
    $idx = 1
    [int]::TryParse($sel, [ref]$idx) | Out-Null
    if ($idx -lt 1 -or $idx -gt $usable.Count) { $idx = 1 }
    $target = $usable[$idx - 1]
}

if ($target.Running) {
    Say "  [ERROR] The selected volume is the running system. Aborted." 'Red'
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}
Say ("      target: {0}:  {1} GB free" -f $target.Letter, $target.FreeGB) 'Green'

# ---------- [2/4] Export all third-party drivers from this machine ----------
Say "[2/4] Exporting all third-party drivers from this machine ..." 'White'
$drvDir = Join-Path $env:TEMP ("alldrv_{0}" -f $PID)
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
New-Item -ItemType Directory -Path $drvDir -Force | Out-Null

$enumText = ''
try { $enumText = (& pnputil /enum-drivers 2>&1 | Out-String) } catch {}
$oems = New-Object System.Collections.ArrayList
foreach ($blk in ($enumText -split "(?:\r?\n){2,}")) {
    $m = [regex]::Match($blk, '(?i)\b(oem\d+\.inf)\b')
    if (-not $m.Success) { continue }
    $nm = $m.Groups[1].Value.ToLower()
    if (-not $oems.Contains($nm)) { [void]$oems.Add($nm) }
}
Say ("      third-party driver packages: {0}" -f $oems.Count) 'DarkGray'

$okExport = 0
foreach ($oem in $oems) {
    $er = (& pnputil /export-driver $oem $drvDir 2>&1 | Out-String)
    if ($er -match 'successfully|成功') { $okExport++ }
}

# [v1.2] pnputil /enum-drivers lists only third-party oem*.inf files, while physical adapters usually use in-box
# packages - not in the oem list, so nothing was exported, and a trimmed image or a fresh Server system lacks exactly that package.
# So the INF used by "the physical adapters that really exist" is exported too: third-party oem ones are already done (skipped);
# in-box ones are copied whole from DriverStore\FileRepository - both for injection and for the NewSystemDriver backup.
try {
    $physNets = @(Get-PnpDevice -Class Net -PresentOnly -EA SilentlyContinue |
        Where-Object { $_.InstanceId -match '^(PCI|USB)' })
    foreach ($dev in $physNets) {
        try {
            $drvInf = ''
            try { $drvInf = [string](Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -EA Stop).Data } catch {}
            if (-not $drvInf) { continue }
            $drvInf = $drvInf.ToLower()
            Say ("      physical adapter {0} is using {1}" -f $dev.FriendlyName, $drvInf) 'DarkGray'
            if ($drvInf -match '^oem\d+\.inf$') { continue }
            # The FileRepository package folder is named <inf file name>_<architecture>_<hash>, for example
            # rt640x64.inf_amd64_cbf4e23981c3c8a3. It must be matched with the full file name including .inf;
            # an earlier version used the name without the extension (rt640x64_*), which never matches, so not a single
            # in-box driver was copied - the symptom being "injected, but the adapter still has no driver".
            $frRoot = "$env:SystemRoot\System32\DriverStore\FileRepository"
            $pkgDirs = @(Get-ChildItem $frRoot -Directory -Filter ($drvInf + '_*') -EA SilentlyContinue)
            if ($pkgDirs.Count -eq 0) {
                $pkgDirs = @(Get-ChildItem $frRoot -Directory -EA SilentlyContinue |
                    Where-Object { $_.Name.ToLower().StartsWith($drvInf + '_') })
            }
            if ($pkgDirs.Count -eq 0) {
                Say ("  No driver package folder found for {0} (the driver name may differ from the folder name)" -f $drvInf) 'Yellow'
            }
            foreach ($pd in $pkgDirs) {
                Copy-Item -LiteralPath $pd.FullName -Destination $drvDir -Recurse -Force -EA SilentlyContinue
                Say ("  Copied the in-box network driver package: " + $pd.Name) 'DarkGray'
            }
        } catch { Say ("      in-box network driver export failed: " + $_.Exception.Message) 'Yellow' }
    }
} catch { Say ("      in-box network driver export threw: " + $_.Exception.Message) 'Yellow' }

$infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
$drvMB = 0
try { $drvMB = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
Say ("      export complete: {0} packages / {1} INF files / {2} MB" -f $okExport, $infFiles.Count, $drvMB) 'Green'
if ($infFiles.Count -eq 0) {
    Say "  [ERROR] Not a single INF was exported, cannot continue." 'Red'
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}

# ---------- Exclude indirect display (IDD) drivers ----------
# [Why exclude them] Remote streaming / emulator / screen mirroring software installs an "Indirect Display Driver" (IDD)
# that registers a device as ROOT\DISPLAY\NNNN - instantiated by the software itself, with no real GPU hardware.
# Once such an INF is injected, PnP on the new system's first boot creates a device from the Root enumerated ID,
# and the Performance tab of Task Manager gains a GPU with empty VRAM / 3D / Video counters.
# The user sees "an empty GPU appeared after installing", and deleting ghost GPUs has no effect on it.
# It exists on this machine but the target may not need it at all - a clear case of "copying it over only adds noise".
$iddPat = '(?i)(GameViewerIdd|IddDriver|IddSampleDriver|usbmmidd|Virtual\s*Display|VirtualDisplay|MuMuIdd|spacedesk|astropad|Parsec.*Idd|Oculus.*(Idd|Display))'
$byDir = @{}
foreach ($inf in $infFiles) {
    $dn = $inf.DirectoryName
    if (-not $byDir.ContainsKey($dn)) { $byDir[$dn] = New-Object System.Collections.ArrayList }
    [void]$byDir[$dn].Add($inf)
}
$excludedPkgs = @()
$excludedInf = @()
foreach ($dn in @($byDir.Keys)) {
    $list = $byDir[$dn]
    $allMatch = $true
    $hitName = ''
    foreach ($inf in $list) {
        $txt = ''
        try { $txt = [IO.File]::ReadAllText($inf.FullName, [Text.Encoding]::Default) } catch { $allMatch = $false; break }
        if ($txt -notmatch $iddPat) { $allMatch = $false; break }
        if (-not $hitName) { $hitName = $inf.Name }
    }
    if ($allMatch -and $list.Count -gt 0) {
        $excludedPkgs += [PSCustomObject]@{ Dir = $dn; Inf = $hitName }
        foreach ($inf in $list) { $excludedInf += $inf.FullName }
    }
}
$excludedMB = 0
if ($excludedPkgs.Count -gt 0) {
    Say ("      excluded {0} virtual display drivers (they would add an empty GPU to the new system):" -f $excludedPkgs.Count) 'Yellow'
    foreach ($e in $excludedPkgs) {
        Say ("        - " + $e.Inf) 'DarkGray'
        try { $excludedMB += [math]::Round(((Get-ChildItem $e.Dir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
        try { Remove-Item -LiteralPath $e.Dir -Recurse -Force -EA SilentlyContinue } catch {}
    }
    # Recount the INF files to inject
    $infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
    try { $drvMB = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
    Say ("      actually injecting: {0} INF files / {1} MB ({2} MB excluded)" -f $infFiles.Count, $drvMB, $excludedMB) 'Green'
    if ($infFiles.Count -eq 0) {
        Say "  [ERROR] No injectable driver package left after exclusion." 'Red'
        try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
        if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
        Read-Host "  Press Enter to exit"
        exit 1
    }
} else {
    Say "      No virtual display (IDD) driver found" 'DarkGray'
}

# Space check: the driver store takes roughly the same size again, keep 1.5x headroom
$needGB = [math]::Round(($drvMB / 1024) * 1.5 + 0.5, 1)
if ($target.FreeGB -lt $needGB) {
    Say ("  [ERROR] The target system has only {0} GB left and injection needs about {1} GB. Enlarge or clean it first." -f $target.FreeGB, $needGB) 'Red'
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}
Say ("      space check passed (need {0} GB, {1} GB free)" -f $needGB, $target.FreeGB) 'DarkGray'

# Keep a copy for "install on the spot inside the new system": put it in NewSystemDriver on the vhdx drive
$keepDir = ''
$vhdxPath = $attachedVhdx
if (-not $vhdxPath) {
    foreach ($f in @(Find-VhdxFiles)) { $vhdxPath = $f; break }
}
if ($vhdxPath) {
    try {
        $keepDir = Join-Path (Split-Path -Parent $vhdxPath) 'NewSystemDriver'
        if (Test-Path -LiteralPath $keepDir) { Remove-Item -LiteralPath $keepDir -Recurse -Force -EA SilentlyContinue }
        New-Item -ItemType Directory -Path $keepDir -Force | Out-Null
        Say ("      also saving a copy to {0} (installable inside the new system)..." -f $keepDir) 'DarkGray'
        Copy-Item -Path (Join-Path $drvDir '*') -Destination $keepDir -Recurse -Force -EA SilentlyContinue
        Say "      copy saved" 'Green'
    } catch {
        $keepDir = ''
        Say ("      failed to save the copy (does not affect injection): " + $_.Exception.Message) 'Yellow'
    }
}

# ---------- [3/4] Inject ----------
Say "[3/4] Injecting all drivers (3-10 minutes, do not close this window)..." 'White'
$logFile = Join-Path $env:TEMP ("alldrv_{0}.log" -f $PID)
$errFile = $logFile + '.err'
try { if (Test-Path -LiteralPath $logFile) { Remove-Item $logFile -Force -EA SilentlyContinue } } catch {}

$dismArgs = '/English /Image:{0}:\ /Add-Driver /Driver:"{1}" /Recurse' -f $target.Letter, $drvDir
Say ("      dism {0}" -f $dismArgs) 'DarkGray'

$proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
            -RedirectStandardOutput $logFile -RedirectStandardError $errFile `
            -NoNewWindow -PassThru -ErrorAction Stop

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$lastBeat = 0
while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 900
    if (($sw.ElapsedMilliseconds - $lastBeat) -ge 5000) {
        $lastBeat = $sw.ElapsedMilliseconds
        $done = 0
        try { $done = @([regex]::Matches([IO.File]::ReadAllText($logFile), '(?i)Installing \d+ of \d+')).Count } catch {}
        Say ("      {0} seconds elapsed, {1} processed ..." -f [int]$sw.Elapsed.TotalSeconds, $done) 'DarkGray'
    }
    if ($sw.ElapsedMilliseconds -gt 1800000) {
        try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
        Say "      Over 30 minutes, giving up" 'Red'
        break
    }
}
try { $proc.WaitForExit() } catch {}

# ---------- [4/4] Result ----------
Say ""
$txt = ''
try { if (Test-Path -LiteralPath $logFile) { $txt = [IO.File]::ReadAllText($logFile, [Text.Encoding]::Default) } } catch {}
$errTxt = ''
try { if (Test-Path -LiteralPath $errFile) { $errTxt = [IO.File]::ReadAllText($errFile, [Text.Encoding]::Default) } } catch {}

$okList = @([regex]::Matches($txt, '(?i)Installing \d+ of \d+ - (.+?):\s*(?:The driver package was successfully installed|驱动包.*?已成功安装)') | ForEach-Object { $_.Groups[1].Value })
$failList = @([regex]::Matches($txt, '(?i)Installing \d+ of \d+ - (.+?):\s*Error') | ForEach-Object { $_.Groups[1].Value })

Say "[4/4] Result:" 'White'
Say ("      injected successfully: {0} driver packages" -f $okList.Count) 'Green'
if ($failList.Count -gt 0) {
    Say ("      not applicable     : {0} (Windows version mismatch, see the log)" -f $failList.Count) 'Yellow'
    foreach ($f in ($failList | Select-Object -First 12)) { Say ("        - " + $f) 'DarkGray' }
    if ($failList.Count -gt 12) { Say ("        ... and {0} more" -f ($failList.Count - 12)) 'DarkGray' }
}
Say ("      log: {0}" -f $logFile) 'Gray'

Say ""
if ($okList.Count -gt 0) {
    Say "  Injection complete. After rebooting into the new system Device Manager should have far fewer unknown devices." 'Green'
    if ($keepDir) {
        Say ("  If a few still show an exclamation mark, run Diagnose-And-Install-Drivers inside the new system; it uses {0}" -f $keepDir) 'Gray'
    }
} else {
    Say "  Not a single package was injected, check the errors in the log." 'Red'
    if ($errTxt.Trim()) { foreach ($l in @($errTxt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Say ("      " + $l) 'Yellow' } }
}

# ---------- Wrap-up ----------
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
if ($attachedVhdx) {
    Say ""
    Say ("  Dismounting the temporarily mounted virtual disk ...") 'DarkGray'
    Dismount-Vhdx -Path $attachedVhdx
    Say "  Dismounted" 'DarkGray'
}
Say ""
Read-Host "  Press Enter to exit"
