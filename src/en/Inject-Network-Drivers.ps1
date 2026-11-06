param(
    [string]$OriginDir = ''
)

# ============================================================
# Inject Network Drivers  v1.2
# Author: connectsegabot
#
# Purpose: an installed virtual system has no network (the adapter shows an exclamation mark in Device Manager,
#   or the network icon has a red cross). This tool injects "the network driver this machine is currently using" into that system.
#
# The driver is taken from this machine, so the hardware IDs match by definition; once injected the network works.
# Only the driver store of the target system is touched, never its system files or boot configuration.
#
# v1.1 fix (2026-11-04):
#   v1.0 had a fatal flaw in target detection - it only looked for "a volume containing ntoskrnl.exe",
#   and the running C: itself contains a kernel, so with no virtual disk mounted C: was the only candidate,
#   and the script happily injected into C:. DISM then reported:
#       Error: 87  The /Image option that is specified points to a
#       running Windows installation.
#   (DISM refused, so nothing was written and the existing system was not modified.)
#   Since v1.1: exclude the running system drive, prefer a virtual disk, and mount it automatically when needed.
#
# v1.2 fix (2026-11-05):
#   v1.1 only exported third-party oem*.inf packages from pnputil /enum-drivers. Network adapters on physical
#   machines usually rely on in-box drivers that never appear in the oem list -> nothing was exported, the injection
#   step reported "no network driver to export" and exited, which looks like "this tool does nothing".
#   (It always worked in a VM because the virtual NIC driver there happens to be an oem package.)
#   Since v1.2: additionally enumerate the real PCI/USB network adapters, take the INF they actually use,
#   copy in-box packages whole from DriverStore\FileRepository and inject those as well.
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.34'
$Script:OriginDir = $OriginDir
try { $Host.UI.RawUI.WindowTitle = "Inject Network Drivers v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] Shared module. src/build/inline_shared.py inlines this file at
# build time, and the .bat payload is still a self-contained single file.
. "$PSScriptRoot\..\shared\en\Logging.ps1"

Say ""
Say "  Inject Network Drivers  v$($Script:Version)" 'Cyan'
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

# ---------- Identify "the system running right now", which must be excluded ----------
$sysLetter = ([string]$env:SystemDrive).TrimEnd(':').ToUpper()
$sysVolId = ''
try { $sysVolId = [string](Get-Volume -DriveLetter $sysLetter -ErrorAction Stop).UniqueId } catch {}

function Test-IsRunningSystem {
    param($Vol)
    if (([string]$Vol.DriveLetter).ToUpper() -eq $sysLetter) { return $true }
    # The same volume mounted under another drive letter has the same UniqueId, so exclude it too,
    # otherwise DISM also reports Error 87.
    if ($sysVolId -and ([string]$Vol.UniqueId -eq $sysVolId)) { return $true }
    return $false
}

# ---------- Candidate volumes ----------
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
        }
    }
    return $list
}

# ---------- Find a mountable vhdx ----------
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
    $dpFile = Join-Path $env:TEMP ("attach_vhd_{0}.txt" -f $PID)
    @(
        "select vdisk file=`"$Path`"",
        'attach vdisk',
        'exit'
    ) | Set-Content -LiteralPath $dpFile -Encoding Default
    $r = ''
    try { $r = (& diskpart /s $dpFile 2>&1 | Out-String) } catch { $r = $_.Exception.Message }
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
    if ($r -match 'successfully|成功') { return $true }
    Say ("      mount returned: " + (($r -replace "\s+", ' ').Trim())) 'Yellow'
    return $false
}

function Dismount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("detach_vhd_{0}.txt" -f $PID)
    @(
        "select vdisk file=`"$Path`"",
        'detach vdisk',
        'exit'
    ) | Set-Content -LiteralPath $dpFile -Encoding Default
    try { & diskpart /s $dpFile 2>&1 | Out-Null } catch {}
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
}

# ---------- [1/4] Locate the target system ----------
Say "[1/4] Locating the target system ..." 'White'

$attachedVhdx = ''
$targets = @(Get-TargetCandidates)
$usable = @($targets | Where-Object { -not $_.Running })

# Prefer a system inside a virtual disk (the normal case for this tool)
$vhdTargets = @($usable | Where-Object { $_.IsVhd })

if ($vhdTargets.Count -eq 0) {
    $vhdxFiles = @(Find-VhdxFiles)
    if ($vhdxFiles.Count -gt 0) {
        foreach ($f in $vhdxFiles) {
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
}

if ($vhdTargets.Count -eq 1) {
    $target = $vhdTargets[0]
    Say ("      target: {0}:  (system inside a virtual disk, {1} GB)" -f $target.Letter, $target.SizeGB) 'Green'
}
elseif ($usable.Count -eq 0) {
    Say ""
    Say "  [ERROR] No injectable system found." 'Red'
    Say ("         The running system is {0}: and cannot be the target (DISM forbids it)." -f $sysLetter) 'Yellow'
    Say "         And no mounted or mountable NewSystemDisk.vhdx was found." 'Yellow'
    Say "         Check which vhdx file holds the virtual system and whether it is named NewSystemDisk.vhdx." 'Yellow'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}
else {
    Say "      Several injectable systems found, choose one:" 'White'
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $t = $usable[$i]
        $kind = if ($t.IsVhd) { 'virtual disk' } else { 'physical partition' }
        Say ("      [{0}] {1}:  {2}  {3} GB  label={4}" -f ($i + 1), $t.Letter, $kind, $t.SizeGB, $t.Label)
    }
    $sel = Read-Host "      Enter a number (default 1)"
    $idx = 1
    [int]::TryParse($sel, [ref]$idx) | Out-Null
    if ($idx -lt 1 -or $idx -gt $usable.Count) { $idx = 1 }
    $target = $usable[$idx - 1]
    Say ("      target: {0}:" -f $target.Letter) 'Green'
}

# Double safety: never write into the running system
if ($target.Running) {
    Say ""
    Say "  [ERROR] The selected volume is the running system, which DISM forbids (Error 87). Aborted." 'Red'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}

# ---------- [2/4] Export this machine's network drivers ----------
Say "[2/4] Exporting network drivers from this machine ..." 'White'
$netClassGuid = '4d36e972-e325-11ce-bfc1-08002be10318'   # network adapters (language independent)
$drvDir = Join-Path $env:TEMP ("injectnet_{0}" -f $PID)
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
New-Item -ItemType Directory -Path $drvDir -Force | Out-Null

$enumText = ''
try { $enumText = (& pnputil /enum-drivers 2>&1 | Out-String) } catch {}
$netOems = New-Object System.Collections.ArrayList
foreach ($blk in ($enumText -split "(?:\r?\n){2,}")) {
    if ($blk -notmatch $netClassGuid) { continue }
    $m = [regex]::Match($blk, '(?i)\b(oem\d+\.inf)\b')
    if (-not $m.Success) { continue }
    $nm = $m.Groups[1].Value.ToLower()
    if (-not $netOems.Contains($nm)) { [void]$netOems.Add($nm) }
}
Say ("      third-party network driver packages on this machine: {0}" -f $netOems.Count) 'DarkGray'
foreach ($oem in $netOems) {
    $er = (& pnputil /export-driver $oem $drvDir 2>&1 | Out-String)
    if ($er -match 'successfully|succeeded') { Say ("      [ok] {0}" -f $oem) 'DarkGray' }
    else { Say ("      [!!] {0}  {1}" -f $oem, (($er -replace "\s+", ' ').Trim())) 'Yellow' }
}

# [v1.2] pnputil /enum-drivers lists only third-party oem*.inf files, missing in-box network
# drivers: physical machines usually use the ones shipped with Windows (not in the oem list), so nothing was
# exported above and the target system still had no network - which looks like "this tool does nothing". So the INF
# currently used by "the physical adapters that really exist" is exported as well: third-party oem ones are already
# done (skipped), in-box ones are copied whole from DriverStore\FileRepository.
Say "      Exporting the drivers used by the physical adapters (including in-box)..." 'DarkGray'
try {
    $physNets = @(Get-PnpDevice -Class Net -PresentOnly -EA SilentlyContinue |
        Where-Object { $_.InstanceId -match '^(PCI|USB)' })
    foreach ($dev in $physNets) {
        try {
            $drvInf = ''
            try { $drvInf = [string](Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -EA Stop).Data } catch {}
            if (-not $drvInf) { continue }
            $drvInf = $drvInf.ToLower()
            Say ("      adapter {0} is using {1}" -f $dev.FriendlyName, $drvInf) 'DarkGray'
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
        } catch { Say ("      [!!] in-box driver export failed: {0}" -f $_.Exception.Message) 'Yellow' }
    }
} catch { Say ("      [!!] in-box driver export threw: {0}" -f $_.Exception.Message) 'Yellow' }

$infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
if ($infFiles.Count -eq 0) {
    Say ""
    Say "  No network driver available to export (neither third-party nor in-box)." 'Yellow'
    Say "  This usually means the driver is not missing. Run Diagnose-And-Install-Drivers inside the target system to see the real error." 'Yellow'
    Say ""
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  Press Enter to exit"
    exit 1
}
$mb = 0
try { $mb = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
Say ("      export complete: {0} INF files, {1} MB" -f $infFiles.Count, $mb) 'Green'

# ---------- [3/4] Inject ----------
Say "[3/4] Injecting into the target system (may take a minute or two)..." 'White'
$logFile = Join-Path $env:TEMP ("injectnet_{0}.log" -f $PID)
$errFile = $logFile + '.err'
try { if (Test-Path -LiteralPath $logFile) { Remove-Item $logFile -Force -EA SilentlyContinue } } catch {}

# Do not quote the value after /Image: writing "/Image:E:\" makes the trailing \" an escaped quote,
# the argument becomes Image:E:" and fails. A drive path contains no spaces, so no quotes is the safest form.
$dismArgs = '/English /Image:{0}:\ /Add-Driver /Driver:"{1}" /Recurse' -f $target.Letter, $drvDir
Say ("      dism {0}" -f $dismArgs) 'DarkGray'

$proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
            -RedirectStandardOutput $logFile -RedirectStandardError $errFile `
            -NoNewWindow -PassThru -ErrorAction Stop

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$lastBeat = 0
while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 700
    if (($sw.ElapsedMilliseconds - $lastBeat) -ge 3000) {
        $lastBeat = $sw.ElapsedMilliseconds
        Say ("      {0} seconds elapsed..." -f [int]$sw.Elapsed.TotalSeconds) 'DarkGray'
    }
    if ($sw.ElapsedMilliseconds -gt 900000) {
        try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
        Say "      Over 15 minutes, giving up" 'Red'
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

Say "[4/4] Result:" 'White'
$installed = @([regex]::Matches($txt, '(?i)driver package (?:was )?(?:successfully )?installed|驱动包.*?已成功安装')).Count
foreach ($l in @($txt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 10)) { Say ("      " + $l) 'DarkGray' }
if ($errTxt.Trim()) {
    Say "      --- stderr ---" 'DarkGray'
    foreach ($l in @($errTxt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Say ("      " + $l) 'Yellow' }
}

Say ""
if ($txt -match 'completed successfully|操作成功完成') {
    if ($installed -gt 0) { Say ("  Injection complete, {0} driver packages installed into {1}: ." -f $installed, $target.Letter) 'Green' }
    else { Say ("  Injection complete (DISM reported no new driver package; the target may already have them).") 'Green' }
    Say ("  After rebooting into the new system the adapter should be recognised. Log: {0}" -f $logFile) 'Gray'
}
elseif ($txt -match '87' -or $errTxt -match 'running Windows installation|正在运行的') {
    Say "  Failed: DISM considers the target a running Windows installation (Error 87)." 'Red'
    Say "  That means the located volume is not the virtual system; point TargetDir at the folder holding the vhdx and retry." 'Yellow'
}
else {
    Say "  Injection result uncertain, see the output above." 'Yellow'
    Say ("  Full log: {0}" -f $logFile) 'Gray'
    Say "  If it says the driver is not compatible with the image, the local driver requires a newer Windows version;" 'Gray'
    Say "  download the Win10 build from the vendor and install it manually inside the target system." 'Gray'
}

# ---------- Wrap-up ----------
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
if ($attachedVhdx) {
    Say ""
    Say ("  Dismounting the temporarily mounted virtual disk: {0}" -f $attachedVhdx) 'DarkGray'
    Dismount-Vhdx -Path $attachedVhdx
    Say "  Dismounted (it will not linger in This PC)" 'DarkGray'
}
Say ""
Read-Host "  Press Enter to exit"
