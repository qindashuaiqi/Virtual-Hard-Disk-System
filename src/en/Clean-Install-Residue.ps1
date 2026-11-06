#requires -Version 5.1
# ============================================================
# Clean Install Residue  v1.3
# Author: connectsegabot
#
# Purpose: after an install hangs or the window is closed midway, the machine is left with
#   1) a dism.exe that never finished (still holding the vhdx file)
#   2) a mounted virtual disk (holding a drive letter, e.g. E:)
#   3) a half-built vhdx (older versions always called it NewSystemDisk.vhdx, now any name is possible)
# This script cleans them up in order so Install-System.bat can be rerun cleanly.
#
# Step 3 only handles vhdx files without a boot entry, in three categories:
#   A installed, boot entry still present  -> never touched (use Uninstall-System.bat to delete it)
#   B installed by this toolkit, entry gone -> the .boot.txt proves it; answer y to delete
#   C not created by this toolkit          -> may be Hyper-V, another tool, or your own backup;
#                                            never deleted by default, and deleting requires typing the file name
# ============================================================

param(
    [string]$OriginDir = ''
)

$ErrorActionPreference = 'Continue'
$Script:Version = '1.33'
$Script:OriginDir = $OriginDir

try { $Host.UI.RawUI.WindowTitle = "Clean Install Residue v$($Script:Version) - connectsegabot" } catch {}

# [v1.32] Shared module. src/build/inline_shared.py inlines this file at
# build time, and the .bat payload is still a self-contained single file.
. "$PSScriptRoot\..\shared\en\Logging.ps1"

Say ""
Say "  Clean Install Residue  v$($Script:Version)" 'Cyan'
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

# ---------- 1. Kill leftover dism ----------
#
# [audit P3-16] This used to kill every dism.exe / DismHost on the machine without asking.
# A user running DISM /RestoreHealth (or any other long DISM job) had it terminated mid-way.
# It is still worth offering - a stuck DismHost is exactly what blocks a reinstall - but the
# user gets to see what is running and decide.
Say "[1/3] Looking for leftover dism.exe ..."
$disms = @(Get-Process -Name dism, DismHost -ErrorAction SilentlyContinue)
$killed = 0
if ($disms.Count -eq 0) {
    Say "      none running" 'DarkGray'
} else {
    Say ("      {0} process(es): {1}" -f $disms.Count, (($disms | ForEach-Object { "$($_.ProcessName)(PID $($_.Id))" }) -join ', ')) 'Yellow'
    Say "      Killing them also interrupts a DISM job you started yourself (for example /RestoreHealth)." 'DarkGray'
    $ans = Read-Host "      Kill them? [y/N]"
    if ($ans -match '^(?i)y(es)?$') {
        foreach ($p in $disms) {
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                $killed++
                Say ("      killed {0} (PID {1})" -f $p.ProcessName, $p.Id) 'DarkGray'
            } catch {
                Say ("      failed to kill {0} (PID {1}): {2}" -f $p.ProcessName, $p.Id, $_.Exception.Message) 'Yellow'
            }
        }
    } else {
        Say "      skipped" 'DarkGray'
    }
}
Start-Sleep -Milliseconds 800

# ---------- 2. Dismount virtual disks ----------
#
# [audit P3-16] Same problem: every File Backed Virtual disk was detached, including a Hyper-V
# machine disk or a VHD the user is working with. Nothing is lost by detaching, but the other
# job breaks. Ask per disk, and never touch anything that is not the one we are here for.
Say "[2/3] Mounted virtual disks ..."
$vds = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { [string]$_.BusType -eq 'File Backed Virtual' })
if ($vds.Count -eq 0) {
    Say "      none mounted" 'DarkGray'
} else {
    foreach ($d in $vds) {
        $loc = [string]$d.Location
        Say ("      Disk {0}: {1}" -f $d.Number, $loc) 'DarkGray'
        if (-not $loc) { continue }
        $ans = Read-Host ("      Detach this one? [y/N]")
        if ($ans -notmatch '^(?i)y(es)?$') { Say "      kept mounted" 'DarkGray'; continue }
        $dpFile = Join-Path $env:TEMP ("detach_{0}.txt" -f $d.Number)
        @(
            "select vdisk file=`"$loc`"",
            'detach vdisk noerr',
            'exit'
        ) | Set-Content -LiteralPath $dpFile -Encoding Default
        $r = & diskpart /s $dpFile 2>&1 | Out-String
        Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
        if ($r -match 'successfully|成功') { Say "      dismounted" 'Green' }
        else { Say ("      dismount result: " + ($r -replace "\s+", ' ').Trim()) 'Yellow' }
    }
}
Start-Sleep -Milliseconds 800

# ---------- 3. Handle vhdx files without a boot entry ----------
# v1.0 only knew the hard-coded NewSystemDisk.vhdx. Since v1.11 the installer allows custom names and folders,
# so a hang at E:\VHD\maimai.vhdx was invisible here and those 20GB stayed occupied forever.
#
# But "no boot entry" does not mean "junk from this toolkit". Hyper-V disks, other install tools and vhdx files
# you placed yourself also have no .boot.txt. v1.1 listed them all and asked "delete?", together with
# a hint that "deleting frees 20GB" - that was encouraging users to press y and delete other people's data,
# and "just press Enter to skip" was luck, not design.
#
# Since v1.2 they are handled in three categories, see the file header.
Say "[3/3] Checking virtual disks with no boot entry ..."

# Scan all disks for *.vhdx: prune by folder name only, never entering system folders or the recycle bin
# >>> COMMON:Get-AllVhdxFile
# Injected by the build script from the shared common/Get-AllVhdxFile.ps1. Editing it here has no effect.
function Get-AllVhdxFile {
    param([int]$MaxDepth = 6)
    # Pruning is by folder name only, never entering system folders, the recycle bin or dependency caches, so depth 6 stays fast.
    # Use .NET directory enumeration instead of Get-ChildItem: the latter creates a PSObject per entry,
    # measured 1074 ms vs 83 ms on the same tree, a 12x difference (the window rescans on every refresh, so it is very visible).
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

# Is this boot entry still in the BCD (existence only, the target is not checked)
function Test-BcdEntryPresent {
    param([string]$Guid)
    if (-not $Guid) { return $false }
    $txt = ''
    try { $txt = (& bcdedit /enum $Guid 2>&1 | Out-String) } catch { return $false }
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($txt -match '找不到|not found|无效|invalid|拒绝|denied') { return $false }
    return ($txt -match '(?i)identifier|标识符')
}

# Delete the .boot.txt next to the vhdx along with it.
# Deleting only the vhdx would make the next scan classify the empty shell as B and ask again,
# and a .boot.txt pointing at a vhdx that no longer exists also misleads other tools.
function Remove-VhdSafely {
    param($Item)
    try {
        Remove-Item -LiteralPath $Item.Path -Force -ErrorAction Stop
        Say "             deleted" 'Green'
        $st = [System.IO.Path]::ChangeExtension($Item.Path, '.boot.txt')
        if (Test-Path -LiteralPath $st) {
            Remove-Item -LiteralPath $st -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Say ("             deletion failed: " + $_.Exception.Message) 'Red'
        Say "             usually a process still holds it - reboot and run this tool again." 'Yellow'
    }
}

$catA = New-Object System.Collections.ArrayList   # installed (entry present)
$catB = New-Object System.Collections.ArrayList   # installed by this toolkit, entry gone
$catC = New-Object System.Collections.ArrayList   # not created by this toolkit

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
    Say "      These are installed with their boot entry intact; this tool never touches them:" 'DarkGray'
    foreach ($it in $catA) {
        Say (('        {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'DarkGray'
    }
    Say "      (to delete them use Uninstall-System.bat, it also cleans the boot menu)" 'DarkGray'
}

if (($catB.Count + $catC.Count) -eq 0) {
    Say "      Nothing to handle, the environment is already clean" 'DarkGray'
} else {
    if ($catB.Count -gt 0) {
        Say ""
        Say ("      [B] installed by this toolkit but the boot entry is gone ({0})" -f $catB.Count) 'White'
        Say "          The .boot.txt left by this toolkit sits next to them; deleting these cannot affect any bootable system." 'DarkGray'
        foreach ($it in $catB) {
            Say (('          {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'White'
            $ans = Read-Host "             Delete them? Type y to delete, or press Enter to skip"
            if ($ans -and ($ans.Trim() -ieq 'y')) {
                Remove-VhdSafely -Item $it
            } else {
                Say "             skipped" 'DarkGray'
            }
        }
    }
    if ($catC.Count -gt 0) {
        Say ""
        Say ("      [C] not created by this toolkit ({0})" -f $catC.Count) 'White'
        Say "          No .boot.txt from this toolkit. They may be Hyper-V virtual disks, another install" 'DarkGray'
        Say "          tool, or a backup of your own. Not deleted by default, and not recommended." 'DarkGray'
        foreach ($it in $catC) {
            $fn = [System.IO.Path]::GetFileName($it.Path)
            Say (('          {0}   ({1} GB)' -f $it.Path, $it.SizeGB)) 'White'
            $ans = Read-Host ("             To really delete one, type its file name {0} (or press Enter to skip)" -f $fn)
            if (-not $ans) {
                Say "             skipped" 'DarkGray'
            } elseif ($ans.Trim() -ieq $fn) {
                Remove-VhdSafely -Item $it
            } else {
                # Do not say "wrong file name" in yellow - many people try y / yes first because they do want it deleted,
                # they just do not know that this prompt does not take y. Explain calmly how to delete, never scold.
                Say ("             skipped. To delete this one, type its full file name: {0}" -f $fn) 'DarkGray'
                if ($ans.Trim() -imatch '^(y|yes|是|删|删除|ok)$') {
                    Say "             (this prompt deliberately does not accept y - it guards against deleting somebody else's virtual disk)" 'DarkGray'
                }
            }
        }
    }
}

# ---------- Step 4 (v1.29): clean the companion logs bcdedit leaves when exporting the BCD ----------
#
# bcdedit /export writes a registry hive, and Windows drops companion transaction logs next to it:
#   xxx.bcd.LOG  xxx.bcd.LOG1  xxx.bcd.LOG2
# Measured on real hardware: 31 .bcd.LOG* files piled up in the root of D:\ and another 18 in D:\VirtualDisks\.
# These companion files carry the Hidden + System attributes, so Get-ChildItem must be called with -Force,
# otherwise not a single one is found (exactly what v1.29 missed, making the feature silently do nothing).
# They are intermediate files of the export, useless for restoring the BCD, and deleting them does not affect the .bcd backup.
# Since v1.29 the installer/repair tool export to a temp folder first and then copy, so no new ones appear;
# this section is the clean-up for what has already piled up.
$strayLogs = New-Object System.Collections.ArrayList
#
# [v1.31 hardening] This used to scan the root and first-level subfolders of 6 drives with the '*.bcd.LOG*' wildcard
# and then Remove-Item everything. In practice no system file was ever hit - but that was luck from a -Filter 8.3
# short-name quirk that happened not to match "BCD.LOG", not protection in the code. Meanwhile
# C:\Boot\BCD.LOG / BCD.LOG1 / BCD.LOG2 are the **transaction logs of the active BCD**, two letters away,
# so another spelling or another machine could hit them, and deleting them risks a corrupted boot configuration.
#
# It is a whitelist now: only the exact format this toolkit has exported over the versions is matched, nothing else.
#   bcd-backup-<yyyyMMdd>-<HHmmss>.bcd.LOG / .LOG1 / .LOG2
#   bcd-backup-fix-<yyyyMMdd>-<HHmmss>.bcd.LOG ...
#   bcd-rescue-<yyyyMMdd>-<HHmmss>.bcd.LOG ...   (early versions used this prefix)
# The key point: it must start with bcd-, carry an 8-digit date plus a 6-digit time, and end in .bcd.
# None of the three system names C:\Boot\BCD.LOG matches any of that, so it is structurally impossible to select them.
# The system folders are excluded again at directory level, as a second line of defence.
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
    Say ("      [extra] companion logs left by bcdedit when exporting the BCD ({0} files, {1:N1} MB in total)" -f $strayLogs.Count, ($sz / 1MB)) 'White'
    Say "          These are the .LOG / .LOG1 / .LOG2 files next to bcd-backup-*.bcd." 'DarkGray'
    Say "          They are intermediate files of the export; deleting them affects neither the .bcd backup nor booting." 'DarkGray'
    Say "          Only backup names exported by this toolkit match; the system's own C:\Boot\BCD.LOG is out of scope and never touched." 'DarkGray'
    foreach ($f in @($strayLogs | Sort-Object FullName | Select-Object -First 8)) {
        Say ("          " + $f.FullName) 'DarkGray'
    }
    if ($strayLogs.Count -gt 8) { Say ("          ... and {0} more" -f ($strayLogs.Count - 8)) 'DarkGray' }
    $ans = Read-Host "             Delete them all? Type y to delete, or press Enter to skip"
    if ($ans -and ($ans.Trim() -ieq 'y')) {
        $okN = 0
        foreach ($f in $strayLogs) {
            try { Remove-Item -LiteralPath $f.FullName -Force -EA Stop; $okN++ } catch {}
        }
        Say ("             deleted {0} / {1}" -f $okN, $strayLogs.Count) 'Green'
        if ($okN -lt $strayLogs.Count) { Say "             the ones that cannot be deleted are usually held by another program; reboot and rerun" 'DarkGray' }
    } else {
        Say "             skipped (nothing deleted)" 'DarkGray'
    }
}

Say ""
Say "  ------------------------------------------------------------" 'DarkGray'
Say "  Cleanup complete." 'Green'
Say ""
Say "  How to reinstall properly:" 'White'
Say "    1. Double-click Install-System.bat again" 'DarkGray'
Say "       the progress bar shows how many GB have been written; as long as the number grows it is working, do not close it" 'DarkGray'
Say "    2. Reboot after it finishes and choose the new system in the boot menu" 'DarkGray'
Say ""
Read-Host "  Press Enter to exit"
