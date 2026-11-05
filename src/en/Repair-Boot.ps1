#requires -Version 3.0
<#
  Repair Boot Menu (Repair-Boot.ps1)
  Author: connectsegabot

  What problem this solves
  ------------
  The installer reports "installation complete", yet after a reboot the boot menu has no new entry and the original system starts directly.

  Root cause
  ----
  1) The original installer wrote the boot files into "the ESP partition inside the virtual disk".
     UEFI firmware only reads the ESP **on the physical disk** (Disk0 Part1, 300MB on this machine),
     it never looks for an ESP inside a vhdx.
     So bcdboot returned exit=0 (the files really were written) while effectively doing nothing.

  2) An even earlier attempt (a v1.3 fallback branch) applied `/f ALL` to `C:\`:
     it created C:\EFI\ and C:\Boot\, which UEFI does not recognise either.

  The correct structure for native boot VHD
  -------------------------
     inside the vhdx: one NTFS partition only (the system files)
     physical ESP: /EFI/Microsoft/Boot/BCD gets one entry whose device points at the vhdx file:
               bcdedit /set {new GUID} device vhd=[D:]\VHD\maimai.vhdx
               Note that [D:] must be followed by the full subfolder path, not just the file name (the v1.12 disaster).

  What this script does
  --------------
    1. Mount the existing vhdx
    2. If it contains an ESP partition -> delete it, leaving a single partition (native boot strictly requires
       bootmgr to treat the **first partition** of the vhdx as the boot partition)
    3. Operate on the **active BCD store** directly with bcdedit (no ESP mount, no BCD file I/O)
    4. Back up the active BCD store (bcdedit /export)
    5. Duplicate the original system's boot entry -> add one vhd= entry
    6. Enable the boot menu (displaybootmenu + timeout); with timeout=0 the default system boots straight away
    7. Clean up the junk folder C:\EFI (C:\Boot is never touched since v1.31)
    8. Dismount the vhdx

  Why step 3 needs no drive letter (v1.1 fix)
  -----------------------------------
    v1.0 assigned a drive letter to the physical ESP and then copied S:\EFI\Microsoft\Boot\bcd as a plain file.
    On real hardware that fails immediately:
        The file "S:\EFI\Microsoft\Boot\bcd" is in use by another process, so the process cannot access it
    The running system itself holds a handle on that BCD, so any file-level access is denied.
    bcdedit without /store operates on the active store - which already lives on the physical ESP,
    so it needs no drive letter, touches no file and cannot hit a sharing violation.

  Safety
  ------
    * bootmgfw.efi on the ESP is never overwritten (replacing a newer loader with an older one would break the existing system)
    * Existing boot entries are not modified; the default entry stays the original system
    * The BCD is exported as a backup before any change, and any failing step triggers an automatic bcdedit /import restore
    * The boot menu boots the original system after 10 seconds, so even a bad new entry cannot affect it

  Usage
  ----
    Windows PowerShell (administrator):
        powershell -ExecutionPolicy Bypass -File Repair-Boot.ps1
  or double-click Repair-Boot-Menu.bat next to this script
#>

[CmdletBinding()]
param(
    [string]$VhdPath = '',
    # The folder the user keeps the bat in (passed in by the bat, because $PSScriptRoot points at the temp folder after unpacking)
    [string]$OriginDir = '',
    [switch]$ConsoleMode
)

$ErrorActionPreference = 'Stop'

$Script:Version = '1.31'
$Script:TempDir = [System.IO.Path]::GetTempPath()
if (-not $Script:TempDir) { $Script:TempDir = 'C:\Windows\Temp\' }
$Script:LogDate = (Get-Date).ToString('yyyyMMdd')
$Script:LogName = "Repair-BootMenu-$($Script:LogDate).log"
$Script:LogFile = Join-Path $Script:TempDir $Script:LogName
# [v1.29] Once the vhdx to repair is chosen, the log and the BCD backup move to
# <folder containing the vhdx>\<ProductName>-logs\, no longer scattered in the drive root or next to the vhdx.
$Script:LogDir = $Script:TempDir

# GPT partition type GUIDs measured on this machine, with braces stripped for comparison
$GUID_ESP   = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
$GUID_MSR   = 'e3c9e316-0b5c-4db8-817d-f92df00215ae'
$GUID_BASIC = 'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7'

# ============================================================
# Basics
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line = '[{0}] [{1}] {2}' -f $stamp, $Level, $Message
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 -EA SilentlyContinue } catch {}
    Write-Host $line
}

# [v1.29] Side artifacts all go under <folder containing the vhdx>\<ProductName>-logs\
# Logs used to live in %TEMP% and the BCD backup was dropped next to the vhdx (littering the drive root when it lived there),
# and bcdedit /export adds three companion files: .LOG/.LOG1/.LOG2.
function Get-SideLogDir {
    param([string]$VhdPath)
    $base = Split-Path -Parent $VhdPath
    if (-not $base) { return $Script:TempDir }
    $dir = Join-Path $base "$($Script:ProductName)-logs"
    if (-not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {}
    }
    if (Test-Path -LiteralPath $dir) { return $dir }
    return $base
}

# Move the log being written next to the vhdx (once only, appended in place afterwards)
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
    param([string]$Text, [string]$Title = 'Repair Boot Menu', [string]$Kind = 'Info')
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

# Get the encoding object for the current system ANSI code page (GBK/936 on a Chinese system)
# ASCII cannot be used: the ASCII encoder replaces every non-ASCII character with '?' without throwing.
function Get-AnsiEncoding {
    try {
        $cp = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name ACP -EA Stop).ACP
        return [System.Text.Encoding]::GetEncoding($cp)
    } catch {
        return [System.Text.Encoding]::GetEncoding(936)
    }
}


# bcdedit prints through the console code page, so a character the page cannot carry comes
# back as "?". The English launcher runs "chcp 437", which turned every Chinese character in
# a path into "?" and made a correct BCD write look like a wrong path.
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

# Call diskpart. $Lines is the command array; returns @{ Ok; Text; Path; Error }
function Invoke-Diskpart {
    param([string[]]$Lines, [string]$Tag = 'dp')

    $f = Join-Path $Script:TempDir ("rb-$Tag-$(Get-Random).txt")
    $text = (@($Lines) -join "`r`n") + "`r`n"

    $enc = Get-AnsiEncoding
    try {
        [System.IO.File]::WriteAllText($f, $text, $enc)
    } catch {
        return @{ Ok = $false; Text = ''; Path = $f; Error = "Failed to write the diskpart script: $($_.Exception.Message)" }
    }

    $txt = ''
    try {
        $txt = (& diskpart /s $f 2>&1 | Out-String)
    } catch {
        $txt = "diskpart call failed: $($_.Exception.Message)"
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
# Virtual disk
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

    # [audit P0-2] Full path first, then a unique file name - never "the first disk whose Location
    # contains this name". The caller deletes the ESP/MSR inside whatever disk comes back, so a
    # second virtual disk with the same file name in another folder would be damaged.
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
    if ($exact.Count -eq 1) { Write-Log "Matched Disk$($exact[0].Number) by full path"; return $exact[0].Number }
    if ($exact.Count -gt 1) { throw "Two disks claim the same file ($full); nothing was modified." }

    $byName = @($all | Where-Object {
        $l = & $norm $_.Location
        if (-not $l) { return $false }
        return ([System.IO.Path]::GetFileName($l) -eq $leaf)
    })
    if ($byName.Count -eq 1) { Write-Log "Matched Disk$($byName[0].Number) by file name (unique)"; return $byName[0].Number }
    if ($byName.Count -gt 1) {
        $lines = ($byName | ForEach-Object { '    Disk ' + $_.Number + ': ' + $_.Location }) -join "`n"
        throw ("More than one mounted virtual disk is called '$leaf':`n$lines`n`nRefusing to pick one - nothing was modified.")
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
        if (-not $r.Ok) { Write-Log "Dismounting the virtual disk did not succeed: $($r.Text)" 'WARN' }
        return $r.Ok
    } catch {
        Write-Log "Failed to dismount the virtual disk: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

# ============================================================
# Partition helpers
# ============================================================

function Get-PartGpt {
    param($Partition)
    $t = [string]$Partition.GptType
    return ($t -replace '[{}]', '').ToLower()
}

# Find the ESP on the physical disk (virtual disks excluded)
function Find-PhysicalEsp {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $sysPart = Get-Partition -DriveLetter $sysLetter -EA SilentlyContinue
    if (-not $sysPart) { return $null }
    $sysDisk = $sysPart.DiskNumber

    $parts = Get-Partition -DiskNumber $sysDisk -EA SilentlyContinue
    foreach ($p in $parts) {
        if ((Get-PartGpt $p) -eq $GUID_ESP) { return $p }
    }
    # Fallback for older MBR machines: the type string contains System
    try {
        $cim = Get-CimInstance Win32_DiskPartition -EA Stop |
               Where-Object { $_.DiskIndex -eq $sysDisk -and $_.Type -match 'System' }
        if ($cim) {
            # Map the partition number back to Get-Partition (the CIM Index is 0-based)
            $idx = [int]$cim.Index - 1
            return (Get-Partition -DiskNumber $sysDisk | Where-Object { $_.PartitionNumber -eq $idx })
        }
    } catch {}
    return $null
}

# Temporarily assign a drive letter to the ESP
function Mount-EspLetter {
    param([int]$DiskNumber, [int]$PartitionNumber)

    $p = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -EA SilentlyContinue
    if ($p -and $p.DriveLetter) {
        return @{ Ok = $true; Letter = [string]$p.DriveLetter; Mode = 'already has a letter' }
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

    # Fallback for when Set-Partition reports "access path is already in use"
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
        Write-Log "Released the ESP drive letter $Letter`:"
    } catch {
        Write-Log "Failed to release the ESP drive letter (harmless): $($_.Exception.Message)" 'WARN'
    }
    # A letter mounted by mountvol is not always removable with Remove-PartitionAccessPath
    if (Test-Path -LiteralPath ("{0}:\EFI" -f $Letter)) {
        try { & mountvol ("{0}:" -f $Letter) /D 2>&1 | Out-Null } catch {}
    }
}

# Find the NTFS system partition inside the vhdx and make sure it has a drive letter
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
# Find the virtual disk: any file name, any folder (v1.4)
#
# [Why this changed]
# Up to v1.3 it only looked for NewSystemDisk.vhdx in the **root** of OriginDir, D:\, C:\, E: F: G:.
# Since v1.11 the installer lets the user choose a name and a folder,
# so "installed to E:\VHD\maimai.vhdx -> no menu after reboot -> follow the hint and run the repair tool" turned into
#"virtual disk not found" (the system was intact, the tool was blind).
# Now it uses the same whole-disk scan as the installer, and picks the one most in need of repair.
# ============================================================

# Scan all disks for *.vhdx. Prune by folder name only, never entering system folders, the recycle bin or dependency caches.
# Use .NET directory enumeration instead of Get-ChildItem: the latter creates a PSObject per entry,
# measured 1074 ms vs 83 ms on the same tree. There may be more folders here than in the installer (removable
# disks excluded), and that 12x decides whether "click repair" takes seconds.
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

# >>> COMMON:Get-StateDisplayName
# Injected by the build script from the shared common/Get-StateDisplayName.ps1. Editing it here has no effect.
function Get-StateDisplayName {
    param([string]$VhdPath)
    # The state file carries three keys for "this name" (historical baggage): Desc / Name / Description.
    # The installer writes all three; repair tool v1.4 only wrote Description; the uninstaller reads only Desc|Name.
    # So for a system whose boot entry was restored with the repair tool, the name is empty in both the installer and the uninstaller,
    # and the custom name is lost once more in this corner case.
    # Read Desc -> Name -> Description in that order so whatever wrote it can be read back.
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

# Read the .boot.txt next to the vhdx (the state file the installer writes) to get the boot entry GUID and display name.
# The name part is no longer parsed here: it defers to the shared Get-StateDisplayName (Desc -> Name -> Description).
# v1.5 still had its own Desc/Name/Description parsing here, overlapping the shared function -
# the same thing written twice drifts as soon as one copy is forgotten, which is exactly where P2-5 came from.
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
    # Always ask the shared function for the name, so it matches what the installer/uninstaller read
    $r.Desc = Get-StateDisplayName -VhdPath $Path
    return $r
}

# Turn bcdedit's vhd=[D:]\a\b.vhdx back into D:\a\b.vhdx
# Keeping only the file name would silently drop the "VirtualDisks" level (the v1.12 disaster),
# so the reverse check must compare full paths too, otherwise two truncated strings are compared.
function ConvertFrom-BcdDevice {
    param([string]$Dev)
    $m = [regex]::Match($Dev, '(?i)vhd=\[([A-Za-z]):\]\s*(.*)$')
    if (-not $m.Success) { return '' }
    $p = $m.Groups[2].Value.Trim().TrimStart('\')
    return ('{0}:\{1}' -f $m.Groups[1].Value.ToUpper(), $p)
}

# Is this boot entry still in the BCD, and does it point at this vhdx
function Test-BcdEntryForVhd {
    param([string]$Guid, [string]$VhdPath)
    $out = @{ Exists = $false; DevOk = $false; Dev = '' }
    if (-not $Guid) { return $out }
    if ($Guid -notmatch '^\{[0-9a-fA-F-]{36}\}$') { return $out }
    $r = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $Guid) -Tag 'probe'
    if (-not $r.Ok) { return $out }      # entry does not exist -> "the menu has no such entry"
    $out.Exists = $true
    $m = [regex]::Match($r.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    if ($m.Success) { $out.Dev = $m.Groups[1].Value.Trim() }
    $back = ConvertFrom-BcdDevice $out.Dev
    $out.DevOk = [bool]($back -and (Test-BcdTextSame $VhdPath $back))
    return $out
}

# Pick the vhdx that "most needs repair" out of a pile of candidates.
# Scoring (high to low):
#   has a state file + the entry is already gone from the BCD   -> 4 + 2 = 6 (typical: no menu after reboot)
#   has a state file + the entry exists but points elsewhere      -> 3 + 2 = 5 (typical: 0xc000000f on selection)
#   has a state file                                             -> 2
#   nothing at all                                               -> 0 (maybe created by hand or by another tool)
# On a tie at the top, or when everything scores 0, it refuses to guess: it reports an error listing all candidates.
function Select-VhdForRepair {
    # $OriginDir is kept only for compatibility with old bats: it no longer limits the search scope,
    # because a virtual disk can live anywhere and looking only at the tool folder would recreate the "not found" problem.
    param([string]$Explicit, [string]$OriginDir)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "The specified virtual disk does not exist: $Explicit" }
        return @{ Path = $Explicit; All = @() }
    }

    $vhds = @(Get-AllVhdxFile)
    if ($vhds.Count -eq 0) { return @{ Path = ''; All = @() } }

    Write-Log ("Scanned the whole machine, found {0} virtual disks:" -f $vhds.Count)
    $scored = @()
    foreach ($f in $vhds) {
        $st = Get-VhdStateInfo -Path $f.FullName
        $score = 0
        $why = 'no state file (not installed by this program, or the install was interrupted)'
        if ($st.HasState) {
            $score += 2
            $why = 'has a state file'
            if ($st.Guid) {
                $b = Test-BcdEntryForVhd -Guid $st.Guid -VhdPath $f.FullName
                if (-not $b.Exists) {
                    $score += 4
                    $why = 'the boot entry is gone from the BCD (no menu after reboot)'
                } elseif (-not $b.DevOk) {
                    $score += 3
                    $why = ('the entry exists but points at {0} (not this file)' -f $b.Dev)
                } else {
                    $why = 'boot entry is fine'
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
        Write-Log ("    [{0} pts] {1}  ({2} GB)  {3}" -f $score, $f.FullName, [math]::Round($f.Length / 1GB, 1), $why)
    }

    # [audit P0-3] A single virtual disk used to be taken unconditionally, even without a state file.
    # That disk may well be a Hyper-V machine disk or a backup copy, and the repair flow deletes the
    # ESP/MSR inside it - which leaves that machine unbootable. The state file (.boot.txt) is the only
    # proof that this program created the disk, so without one the user has to name it explicitly.
    if ($scored.Count -eq 1) {
        if ($scored[0].Score -le 0) {
            throw (("Only one virtual disk was found, but this program did not install it (no state file):`n`n" +
                    "    {0}`n`n" +
                    "It was NOT modified - it could belong to Hyper-V or be a backup copy.`n`n" +
                    "If you are sure it is the system to repair (for example the install was interrupted before the state file was written), name it explicitly:`n" +
                    "    Repair-Boot-Menu.bat -VhdPath `"{0}`"") -f $scored[0].Path)
        }
        return @{ Path = $scored[0].Path; All = $scored }
    }

    $sorted = @($scored | Sort-Object -Property @{ Expression = 'Score'; Descending = $true },
                                                 @{ Expression = 'Time';  Descending = $true })
    $top = $sorted[0]
    $tie = @($sorted | Where-Object { $_.Score -eq $top.Score -and $_.Score -gt 0 })
    if (($top.Score -le 0) -or ($tie.Count -gt 1)) {
        $lines = @($scored | ForEach-Object { '    ' + $_.Path + '  (' + $_.Why + ')' })
        throw (("This machine has {0} virtual disks and there is no way to tell which one to repair:`n`n{1}`n`n" +
                "Specify it on the command line:`n" +
                "    powershell -ExecutionPolicy Bypass -File Repair-Boot.ps1 -VhdPath `"full path`"`n`n" +
                "(If you only want to fix the menu target, the Fix-Boot-Entry-Device tool is easier.)") -f $scored.Count, ($lines -join "`n"))
    }
    return @{ Path = $top.Path; All = $scored }
}

# ============================================================
# BCD
# ============================================================

# Single entry point for bcdedit.
#
# [Why /store is no longer used - the core v1.1 fix]
# This used to assign a drive letter to the physical ESP and then copy/overwrite S:\EFI\Microsoft\Boot\bcd as a plain file.
# On real hardware it hits the lock immediately:
#     The file "S:\EFI\Microsoft\Boot\bcd" is in use by another process, so the process cannot access it
# because the running system itself holds a handle on that BCD.
#
# The right way is not to touch the file at all: bcdedit without /store operates on the "active BCD store",
# the very store the current system booted from - which already lives on the physical ESP. Editing it edits
# the physical ESP, and needs no drive letter, no mount and cannot hit a sharing violation.
#
# An empty $Store means the active store. A path means an offline store (kept for later, unused today).
function Invoke-BcdEdit {
    param([string]$Store = '', [string[]]$BcdArgs, [string]$Tag = '')

    $all = @()
    if ($Store) { $all += @('/store', $Store) }
    $all += $BcdArgs

    $txt = ''
    try {
        $txt = (& bcdedit @all 2>&1 | Out-String)
    } catch {
        $txt = "call failed: $($_.Exception.Message)"
    }
    $code = $LASTEXITCODE
    $clean = ($txt -replace '\s+', ' ').Trim()
    Write-Log ("bcdedit {0} [{1}] => exit={2}  {3}" -f $Tag, ($BcdArgs -join ' '), $code, $clean)

    $err = ($txt -match '找不到|not found|无效|invalid|拒绝|denied|失败|failed|错误|error')
    return @{ Ok = (($code -eq 0) -and (-not $err)); Code = $code; Text = $clean; Raw = $txt }
}

# Pick the source boot entry used by /copy, returns @{ Guid; Tag }.
#
# Background (the lesson before v1.18):
#   When the installer / repair tool duplicated a new entry, it hard-coded {current} (falling back to {default}).
#   Both are "logical aliases" and work under normal conditions; but once the primary loader in the BCD is lost
#   (for example after booting a system out of a vhdx, or as a side effect of a repair/uninstall),
#   the osloader enumeration holds nothing but Recovery entries, neither {current} nor {default} resolves to a real loader,
#   and /copy fails with "the specified identifier is not valid" - right at the end of the install.
#
#   Fix: {current} fails -> {default} fails -> pick a "real, healthy" system loader GUID
#   from /enum osloader as the source. The three following /set calls overwrite device/osdevice/path
#   to point at the vhdx anyway, so it does not matter which disk the source entry pointed at; the only
#   requirement is that it is a proper osloader (not Recovery, not ramdisk, not winpe).
function Get-CopySourceGuid {
    # Level 1: {current} (the system running right now, most accurate on multi-boot machines)
    $probe = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{current}') -Tag 'probe-current'
    if ($probe.Ok) { return @{ Guid = '{current}'; Tag = 'current' } }

    # Level 2: {default} (the default system)
    $probe = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{default}') -Tag 'probe-default'
    if ($probe.Ok) { return @{ Guid = '{default}'; Tag = 'default' } }

    # Level 3: pick a real loader from the osloader enumeration.
    # /enum osloader dumps every entry in full, with Recovery entries (ramdisk=) in between.
    # Split by "identifier" and judge each block:
    #   - has device partition= or osdevice partition=  -> a real system loader
    #   - description contains Recovery / the GUID is a known recovery GUID -> skip
    #   - device/osdevice carries ramdisk= -> that is WinRE, skip
    $enum = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', 'osloader') -Tag 'oslist-src'
    $blocks = [regex]::Split($enum.Raw, '(?im)^(?=\s*(?:identifier|标识符)\s+\{)')
    foreach ($b in $blocks) {
        if (-not ($b -match '(?im)\{(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|current|default)\}')) { continue }
        $g = $matches[0]
        # Recovery / WinRE: device or osdevice is a ramdisk, or the description mentions Recovery
        if ($b -match '(?im)ramdisk=') { continue }
        if ($b -match '(?im)description\s+.*recovery') { continue }
        # Must be a loader that really points at a physical disk/partition or a vhd
        if ($b -notmatch '(?im)(?:device|osdevice)\s+(partition=|vhd=)') { continue }
        # Also exclude management entries such as {bootmgr} (they never show up in osloader, but just in case)
        if ($g -ieq '{bootmgr}') { continue }
        Write-Log "Picked a usable source from the osloader enumeration: $g" 'WARN'
        return @{ Guid = $g; Tag = 'osloader-pick' }
    }

    # Nothing picked: hand the raw enumeration to the caller so it can report a locatable error
    return @{ Guid = ''; Tag = 'none'; Raw = $enum.Raw }
}

# Create a new boot loader entry, returns @{ Guid; Tag } (Guid='' plus Error on failure).
#
# Two routes, tried in order:
#   1. /copy <source> /d <description>  - duplicate an existing loader, inherits a pile of default fields, most robust.
#      The source comes from Get-CopySourceGuid: {current} -> {default} -> a real entry from the osloader enumeration.
#   2. /create /d <description> /application osloader - build from scratch, depends on no existing entry.
#      Only used when /copy cannot even find a source (the BCD primary loader is gone, only WinRE left).
#
# Background (the follow-up lesson after v1.18):
#   v1.18 added the third fallback layer to /copy ("pick a real loader from the osloader enumeration"), which was expected to be enough.
#   Real hardware then produced a worse case: the machine had booted a system out of a vhdx before,
#   the BCD lost {current}/{default} together with the only real osloader entry,
#   and /enum osloader returned nothing but two Recovery entries. All three source layers were dead, so /copy had nothing to copy.
#   The only remaining rescue is /create - it needs no source and builds a brand new loader,
#   which is then pointed at the vhdx with /set device/osdevice/path as usual.
#
# Background (v1.24 review):
#   /copy automatically adds the new entry to {bootmgr} displayorder (the boot menu), /create does not.
#   So on the /create fallback the entry existed with correct device/path, yet the boot menu had no such
#   line at all - the user sees "repair reported success, still no menu after reboot", which equals no repair.
#   Both routes therefore end with one confirmation of displayorder (left alone if already present, to keep the user's order).
#
# Return shape: @{ Guid='{...}'; Tag='copy'|'create'; Error='' }
#   Empty Guid with a non-empty Error = both routes failed, the caller reports it and exits.
function New-BootEntryGuid {
    param([string]$Desc)

    $guid = ''
    $tag = ''

    # ---- Route 1: copy (duplicate when a source exists) ----
    $src = Get-CopySourceGuid
    if ($src.Guid) {
        $cp = Invoke-BcdEdit -Store '' -BcdArgs @('/copy', $src.Guid, '/d', $Desc) -Tag "copy-$($src.Tag)"
        $g = [regex]::Match($cp.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if ($g.Success) {
            $guid = $g.Value
            $tag = 'copy'
        } else {
            Write-Log ('/copy ran but returned no new GUID (output: {0}), falling back to /create' -f $cp.Text) 'WARN'
        }
    } else {
        Write-Log 'No usable /copy source ({current}/{default} dead, no real loader in osloader), falling back to /create' 'WARN'
    }

    # ---- Route 2: create (build from scratch when no source exists) ----
    # /application osloader is mandatory, otherwise /create builds an "application" type entry
    # that cannot be copied and is not the boot loader we need.
    if (-not $guid) {
        $cr = Invoke-BcdEdit -Store '' -BcdArgs @('/create', '/d', $Desc, '/application', 'osloader') -Tag 'create'
        $g = [regex]::Match($cr.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if ($g.Success) {
            $guid = $g.Value
            $tag = 'create'
        } else {
            return @{ Guid = ''; Tag = ''; Error = ('Failed to create the boot entry: /copy had no source and /create returned no new GUID.' + "`n" + 'Output: ' + $cr.Text) }
        }
    }

    # ---- Shared wrap-up: confirm the new entry made it into the boot menu ----
    # Look only at the displayorder line; do not -match against the whole enumeration ({bootmgr} output
    # also contains default and other fields, so a false "already in the menu" keeps it out again).
    try {
        $bmRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm-order').Raw
        $dm = [regex]::Match([string]$bmRaw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+)$')
        $inOrder = ($dm.Success -and ($dm.Groups[1].Value -match [regex]::Escape($guid)))
        if (-not $inOrder) {
            $do = Invoke-BcdEdit -Store '' -BcdArgs @('/displayorder', $guid, '/addlast') -Tag 'displayorder'
            if ($do.Ok) {
                Write-Log 'New entry added to the boot menu (displayorder /addlast)'
            } else {
                Write-Log ('Failed to add to the boot menu, the entry may not show up after reboot: ' + $do.Text) 'WARN'
            }
        } else {
            Write-Log 'The new entry is already in the boot menu; displayorder needs no append'
        }
    } catch {
        Write-Log ('Failed to check displayorder (does not affect the entry itself): ' + $_.Exception.Message) 'WARN'
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

# Back up the active BCD store.
# Through bcdedit /export - that is the BCD API, not a file copy, so the file lock cannot block it.
# When it returns Ok=$false the caller should not give up: only "add an entry + change the menu timeout" happen next,
# both reversible with bcdedit, and the file-level backup is just an extra safety net.
function Backup-BcdStore {
    param([string]$Dest)

    # [v1.29] bcdedit /export writes a registry hive and Windows creates
    # X.bcd.LOG / .LOG1 / .LOG2 next to it. Exporting straight into the vhdx folder used to pile those up there.
    # Now it exports into a temp folder, copies only the .bcd to the destination, and removes the temp file with its companion LOGs.
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
        return @{ Ok = $false; Mode = ''; Size = 0; Error = 'Failed to copy the backup file to the destination' }
    }
    foreach ($f in $sidecar) { Remove-Item -LiteralPath $f -Force -EA SilentlyContinue }
    return @{ Ok = $false; Mode = ''; Size = $len; Error = $r.Text }
}

# Restore the active store to its exported state with bcdedit /import
function Restore-BcdStore {
    param([string]$Src)
    if (-not $Src -or -not (Test-Path -LiteralPath $Src)) {
        return @{ Ok = $false; Text = 'No usable backup file' }
    }
    $r = Invoke-BcdEdit -Store '' -BcdArgs @('/import', $Src) -Tag 'import'
    return @{ Ok = $r.Ok; Text = $r.Text }
}

# ============================================================
# State file: the uninstaller uses it to find the GUID again
# ============================================================

function Get-StatePath {
    param([string]$Vhd)
    return [System.IO.Path]::ChangeExtension($Vhd, '.boot.txt')
}

function Save-State {
    param([string]$Path, [hashtable]$Data)
    $lines = @('# Virtual Hard Disk System - boot entry state (needed by the uninstaller, do not delete)')
    foreach ($k in ($Data.Keys | Sort-Object)) { $lines += ('{0}={1}' -f $k, $Data[$k]) }
    [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding $false))
}

# ============================================================
# Main flow
# ============================================================

$resultLines = New-Object System.Collections.ArrayList
function Add-Result([string]$s) { [void]$resultLines.Add($s) }

Write-Log "===== Repair Boot Menu v$($Script:Version) ====="
Write-Log "Author: connectsegabot"
Write-Log "Log: $($Script:LogFile)"

$mounted = $false
$espLetter = ''
$osLetter = ''
$bcdPath = ''
$bcdBackup = ''
$statePath = ''
$newGuid = ''      # entry created by this /copy run; catch uses it to roll back
$restored = $false # whether the BCD was already restored by /import (no need to delete the entry separately)

try {
    if (-not (Test-Admin)) {
        throw 'Administrator rights are required. Right-click and choose "Run as administrator", or double-click Repair-Boot-Menu.bat.'
    }

    $fw = Get-FirmwareType
    Write-Log "Firmware type: $fw (2=UEFI)"
    if ($fw -ne 2) {
        throw ('UEFI machines only. This machine reports firmware type ' + $fw + ', and' +
               'booting from a virtual disk (native boot) needs a different parameter set under Legacy BIOS, which this script does not cover.')
    }

    # ---------- Find the vhdx (v1.4: any name, any folder) ----------
    $pick = Select-VhdForRepair -Explicit $VhdPath -OriginDir $OriginDir
    if (-not $pick.Path) {
        throw ('No .vhdx found anywhere (all fixed NTFS drives scanned, up to 6 levels deep).' + "`n`n" +
               'Possible reasons:' + "`n" +
               '  - the install never reached the virtual disk creation step' + "`n" +
               '  - the virtual disk sits on a removable/USB drive (not recommended for native boot anyway)' + "`n" +
               '  - the virtual disk has already been deleted' + "`n`n" +
               'If the file is definitely there, pass its path with -VhdPath.')
    }
    $VhdPath = $pick.Path
    if (-not (Test-Path -LiteralPath $VhdPath)) { throw "The virtual disk is gone: $VhdPath" }
    $VhdPath = (Resolve-Path -LiteralPath $VhdPath).Path
    Set-LogDir -VhdPath $VhdPath
    Write-Log "Virtual disk being repaired: $VhdPath"
    Write-Log "Log: $Script:LogFile"
    if (@($pick.All).Count -gt 1) {
        Write-Log ("({0} virtual disks on this machine; the one most likely missing a menu or pointing wrong was picked, the rest are untouched)" -f @($pick.All).Count)
    }
    Add-Result ("Virtual disk: $VhdPath")

    $vhdSizeGB = [math]::Round((Get-Item -LiteralPath $VhdPath).Length / 1GB, 1)

    # Drive letter of the volume holding the vhdx (needed in the BCD)
    #
    # The intermediate subfolder must be preserved: D:\VirtualDisks\x.vhdx -> vhd=[D:]\VirtualDisks\x.vhdx
    # Keeping only the file name points the menu at D:\x.vhdx (which does not exist), so even a finished install will not boot.
    $vhdDrive = [System.IO.Path]::GetPathRoot($VhdPath).Substring(0, 1).ToUpper()
    $vhdRel = $VhdPath.Substring([System.IO.Path]::GetPathRoot($VhdPath).Length).TrimStart('\')
    if (-not $vhdRel) { throw "Invalid virtual disk path: $VhdPath" }
    $vhdDev = "vhd=[$($vhdDrive):]\$vhdRel"
    Write-Log "The BCD will point at: $vhdDev"

    # ---------- Mount ----------
    $diskNum = Mount-Vhd -Path $VhdPath
    if ($diskNum -lt 0) { throw 'Failed to mount the virtual disk (the system did not pick up the disk).' }
    $mounted = $true
    Write-Log "Virtual disk number: $diskNum"

    # ---------- Delete the ESP inside the vhdx, leaving a single partition ----------
    $vparts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
    Write-Log ("Partitions inside the vhdx: {0}" -f $vparts.Count)

    if ($vparts.Count -gt 1) {
        $espInVhd = $vparts | Where-Object { (Get-PartGpt $_) -eq $GUID_ESP }
        if ($espInVhd) {
            Write-Log ("Found an ESP inside the vhdx (partition {0}, {1:N0} MB) -> deleting it to leave a single partition" -f
                       $espInVhd.PartitionNumber, ($espInVhd.Size / 1MB))
            $dp = Invoke-Diskpart -Tag 'del' -Lines @(
                "select disk $diskNum",
                ("select partition {0}" -f $espInVhd.PartitionNumber),
                'delete partition override',
                'exit'
            )
            Write-Log "Deleting the ESP inside the vhdx: $($dp.Text)"
            if (-not $dp.Ok) { throw "Failed to delete the ESP inside the vhdx: $($dp.Text)" }
            Start-Sleep -Milliseconds 800
            $vparts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
            Write-Log ("Partition count after deletion: {0}" -f $vparts.Count)
        }
        # Delete the MSR as well (no data loss, but it serves no purpose here)
        $msrInVhd = $vparts | Where-Object { (Get-PartGpt $_) -eq $GUID_MSR }
        if ($msrInVhd) {
            $dp2 = Invoke-Diskpart -Tag 'delmsr' -Lines @(
                "select disk $diskNum",
                ("select partition {0}" -f $msrInVhd.PartitionNumber),
                'delete partition override',
                'exit'
            )
            Write-Log "Deleting the MSR inside the vhdx: $($dp2.Text)"
            Start-Sleep -Milliseconds 500
        }
    }

    # ---------- Confirm the system partition ----------
    $os = Get-VhdOsPartition -DiskNumber $diskNum
    if (-not $os) { throw 'No NTFS system partition inside the vhdx; the virtual disk may be damaged.' }
    $osLetter = $os.Letter
    Write-Log "System partition: $osLetter`: (partition $($os.Number))"

    $need = @(
        "$($osLetter):\Windows\System32\winload.efi",
        "$($osLetter):\Windows\System32\ntoskrnl.exe"
    )
    foreach ($f in $need) {
        if (-not (Test-Path -LiteralPath $f)) {
            throw ("System files missing: $f`nThe system inside the virtual disk is incomplete and must be reinstalled.")
        }
    }
    Write-Log 'System file check passed (winload.efi / ntoskrnl.exe both present)'

    # Confirm it really is "partition 1" - native boot only recognises the first partition
    if ($os.Number -ne 1) {
        Write-Log ("Note: the system partition is partition {0} of the vhdx, not 1. bootmgr usually only accepts the first partition, so boot may fail." -f $os.Number) 'WARN'
    } else {
        Write-Log 'The system partition is partition 1 of the vhdx (native boot requirement met)'
    }

    # ---------- [critical] Dismount the vhdx BEFORE any BCD work ----------
    #
    # Measured (the 19:48 run): with the vhdx mounted,
    #     bcdedit /set {guid} device vhd=[D:]\NewSystemDisk.vhdx
    # bcdedit returned "operation completed successfully", but /enum read device back as partition=E: -
    # E: being the internal volume of the mounted virtual disk. When bcdedit parses vhd= and finds that
    # virtual disk attached, it writes the device as that volume instead of keeping the vhd= file reference.
    # Such an entry always fails at boot (the vhdx is not mounted then).
    #
    # So: dismount as soon as the partition and the system files check out, and do the whole BCD part with the vhdx unmounted.
    [void](Dismount-VhdSafe -Path $VhdPath)
    $mounted = $false
    Write-Log 'vhdx dismounted (bcdedit requires the vhd= device to be written while it is not mounted)'

    # ---------- Locate the active BCD store ----------
    #
    # The physical ESP is no longer assigned a drive letter. Why: see the comment above Invoke-BcdEdit - the bcd file
    # on the ESP is held by the running system, so copying/overwriting it hits a sharing violation. The active store is equivalent and safer.
    #
    # The ESP is still located here purely so the log can show "which disk the boot menu lands on";
    # not finding it does not block anything that follows.
    $esp = Find-PhysicalEsp
    if ($esp) {
        Write-Log ("Physical ESP (logged only, not mounted): disk {0} partition {1}, {2:N0} MB" -f
                   $esp.DiskNumber, $esp.PartitionNumber, ($esp.Size / 1MB))
        Add-Result ("Boot menu location: the ESP on disk {0} partition {1}" -f $esp.DiskNumber, $esp.PartitionNumber)
    } else {
        Write-Log 'Could not locate the physical ESP (harmless: the entry is written to the active BCD store)' 'WARN'
    }
    $bcdPath = 'active BCD store'
    Write-Log "BCD: $bcdPath"

    # ---------- Back up the BCD ----------
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $bcdBackup = Join-Path (Get-SideLogDir -VhdPath $VhdPath) ("bcd-backup-$stamp.bcd")
    $bk = Backup-BcdStore -Dest $bcdBackup
    if ($bk.Ok) {
        Write-Log ("BCD backed up ({0}, {1} bytes): {2}" -f $bk.Mode, $bk.Size, $bcdBackup)
        Add-Result ("BCD backup: $bcdBackup")
    } else {
        Write-Log ("BCD backup failed: {0}" -f $bk.Error) 'WARN'
        $bcdBackup = ''
        Add-Result 'BCD backup: failed (does not affect this repair)'
    }

    # ---------- Read the old state file ----------
    #
    # Two things can only come from the old state file and must not be resampled from the current BCD:
    #
    # 1) the old GUID - a rerun uses it to delete the entry left by the previous run, otherwise entries pile up in the menu.
    # 2) the pre-install originals OrigTimeout / OrigDisplayMenu / OrigDisplayMenuSet -
    #    the only basis for restoring the boot menu when uninstalling. The installer recorded "what it was before",
    #    while the BCD right now already holds the Yes the installer wrote. Resampling here would write the state file
    #    as Yes / Set=1, the uninstaller would restore Yes, and the boot menu would pop up forever - it took
    #    v1.8 and v1.9 to plug that hole, do not let the repair tool open it again.
    $statePath = Get-StatePath -Vhd $VhdPath
    $old = @{}
    if (Test-Path -LiteralPath $statePath) {
        foreach ($ln in (Get-Content -LiteralPath $statePath -Encoding UTF8 -EA SilentlyContinue)) {
            if ($ln -match '^\s*([^#=]+)=(.*)$') { $old[$matches[1].Trim()] = $matches[2].Trim() }
        }
        Write-Log ("Read the old state file ({0} keys): {1}" -f $old.Count, $statePath)
    } else {
        Write-Log 'No old state file (first repair), the originals will be sampled from the current BCD'
    }
    $oldGuid = ''
    if ($old['Guid'] -and $old['Guid'] -match '^\{[0-9a-fA-F-]{36}\}$') { $oldGuid = $old['Guid'] }

    # ---------- Originals: reuse the old record when present, sample only otherwise ----------
    $origTimeout = ''
    $origDisplay = ''
    $origDisplaySet = ''
    if ($old['OrigTimeout']) {
        $origTimeout = $old['OrigTimeout']
        Write-Log "Reusing the recorded original timeout: $origTimeout"
    } else {
        $origTimeout = Get-BcdValue -Store '' -Entry '{bootmgr}' -Key 'timeout'
        if (-not $origTimeout) { $origTimeout = '30' }
        Write-Log "No original timeout in the old record, sampling the current value: $origTimeout"
    }
    if ($old.ContainsKey('OrigDisplayMenuSet')) {
        $origDisplaySet = $old['OrigDisplayMenuSet']
        $origDisplay = $old['OrigDisplayMenu']
        Write-Log "Reusing the recorded original displaybootmenu: ""$origDisplay"" (Set=$origDisplaySet)"
    } elseif ($old.ContainsKey('OrigDisplayMenu')) {
        # v1.3 and earlier recorded the value but not "was it set at all", so infer it from presence
        $origDisplay = $old['OrigDisplayMenu']
        if ($origDisplay) { $origDisplaySet = '1' } else { $origDisplaySet = '0' }
        Write-Log ("The old record lacks OrigDisplayMenuSet, inferred as {0} from the value" -f $origDisplaySet) 'WARN'
    } else {
        $bmRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm').Raw
        if ($bmRaw -match '(?im)^\s*displaybootmenu\s+(\S+)') { $origDisplay = $matches[1] }
        if ($origDisplay) { $origDisplaySet = '1' } else { $origDisplaySet = '0' }
        Write-Log ("No displaybootmenu in the old record, sampling the current value: ""{0}"" / Set={1}" -f $origDisplay, $origDisplaySet)
    }
    if (-not $old['BcdBackup']) { $old['BcdBackup'] = $bcdBackup }
    if (-not $old['Created']) { $old['Created'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
    Write-Log ("Effective originals: timeout={0}  displaybootmenu=""{1}"" (Set={2})" -f $origTimeout, $origDisplay, $origDisplaySet)

    # What name to show in the menu: prefer the name the user chose at install time (Desc / Name in the state file).
    # v1.3 and earlier hard-coded "Windows 10 (Virtual System)" - the user installed a system called maimai,
    # and after the repair the menu said "Windows 10 (Virtual System)", wiping the custom name.
    $stateInfo = Get-VhdStateInfo -Path $VhdPath
    $desc = ''
    if ($stateInfo.Desc) { $desc = $stateInfo.Desc }
    elseif ($stateInfo.Name) { $desc = $stateInfo.Name }
    elseif ($old['Name']) { $desc = $old['Name'] }
    else { $desc = 'Windows (Virtual System)' }
    Write-Log "Menu description: $desc"

    # ---------- Create the new boot entry ----------
    # /copy first, /create from scratch when there is no source (BCD primary loader wiped, only WinRE left).
    # Before v1.18 {default} was hard-coded with no fallback; since v1.19, even when nothing but Recovery
    # is left in osloader, /create builds a brand new loader instead of getting stuck on "no source found".
    $nb = New-BootEntryGuid -Desc $desc
    if (-not $nb.Guid) {
        throw $nb.Error
    }
    # The GUID comes straight from New-BootEntryGuid (/copy and /create both return it internally),
    # it is not scraped out of the output again - that is exactly where the v1.5 regression came from.
    $guid = $nb.Guid
    $newGuid = $guid      # handed to catch as a safety net: delete this half-built entry on failure, so reruns do not pile up
    Write-Log "New boot entry: $guid (source: $($nb.Tag))"

    # ---------- Point it at the vhdx ----------
    # $vhdDev was computed before mounting the virtual disk (see "The BCD will point at" above), so it is used directly here
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
        # Delete the half-built entry just created, then rethrow: when the backup failed, catch cannot rely on /import,
        # and not deleting it would really add one entry per run.
        $rb = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $guid) -Tag 'rollback'
        if ($rb.Ok) { Write-Log 'Deleted the half-built entry created by this run (rollback)' 'WARN' }
        else { Write-Log ("Rollback failed, the menu may show an extra entry: {0}" -f $rb.Text) 'WARN' }
        throw "Failed to set the boot entry parameters, see the log.`n`n$($Script:LogFile)"
    }

    # ---------- Check 1: compare the device path character by character ----------
    $check = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify'
    $devNow = ''
    $mv = [regex]::Match($check.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    if ($mv.Success) { $devNow = $mv.Groups[1].Value.Trim() }
    if ($devNow -notmatch '(?i)vhd=') {
        throw ("The vhd= device path was not written into the boot entry.`n`n" +
               "Common cause: the virtual disk was still mounted while the BCD was edited, and bcdedit silently replaced vhd= with " +
               "partition=X: of the internal volume (this tool dismounts the vhdx before touching the BCD, so it should not happen).`n`n" +
               "Read back: $($check.Text)")
    }
    # vhd= alone is not enough: pointing at the wrong vhdx boots just as badly (the v1.12 trap).
    # Reverse-parse it into a real path and compare it character by character with the file on disk.
    $backPath = ConvertFrom-BcdDevice $devNow
    Write-Log ("Entry check: device={0}  reverse-parsed={1}" -f $devNow, $backPath)
    if ($backPath -and -not (Test-BcdTextSame $VhdPath $backPath)) {
        Write-Log "Wrong target (should be $VhdPath), rewriting once" 'WARN'
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'device', $vhdDev) -Tag 'fix-dev')
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'osdevice', $vhdDev) -Tag 'fix-dev')
        $check = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify2'
        $devNow = ''
        $mv = [regex]::Match($check.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
        if ($mv.Success) { $devNow = $mv.Groups[1].Value.Trim() }
        $backPath = ConvertFrom-BcdDevice $devNow
        if (-not $backPath -or -not (Test-BcdTextSame $VhdPath $backPath)) {
            throw ("The device path cannot be written, or was overwritten after writing.`n`n" +
                   "Expected: $vhdDev`n" +
                   "Read back: $devNow`n`n" +
                   "Common causes:`n" +
                   "  - the virtual disk was still attached while the BCD was edited (it gets replaced by partition=X: of the internal volume)`n" +
                   "  - the path contains characters winload does not accept (usually very long non-ASCII folder names)`n`n" +
                   "The most reliable fix is to move the virtual disk to a short ASCII folder such as D:\VHD and reinstall.`n" +
                   "Log: $($Script:LogFile)")
        }
        Write-Log 'Target correct after the rewrite'
    }

    # ---------- Check 2: menu text ----------
    $descNow = ''
    $md = [regex]::Match($check.Raw, '(?im)^\s*(?:description|描述)\s+(.+)$')
    if ($md.Success) { $descNow = $md.Groups[1].Value.Trim() }
    if ($descNow -ne $desc) {
        # A "?" in the readback is only the console code page; do not rename a good entry
        if (($descNow -replace '[^\x20-\x7E]', '?') -eq ($desc -replace '[^\x20-\x7E]', '?')) {
            Write-Log ('Menu text masked by the console code page, keeping "' + $desc + '"') 'WARN'
        } else {
            # When non-ASCII text cannot be written (command line encoding), fall back to plain ASCII so the menu does not show question marks
            $safeDesc = 'Windows (VHD) ' + [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
            $safeDesc = ($safeDesc -replace '[^\x20-\x7E]', '').Trim()
            if (-not $safeDesc) { $safeDesc = 'Windows (VHD)' }
            Write-Log ("Menu text could not be written correctly (read back ""{0}""), using ""{1}"" instead" -f $descNow, $safeDesc) 'WARN'
            [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'description', $safeDesc) -Tag 'desc-en')
            $desc = $safeDesc
        }
    }

    # ---------- Delete the old entry only after the new one is verified ----------
    #
    # v1.4 deleted first and created second: it continued even when the backup failed (one WARN above), while the old entry was already /delete'd.
    # If /copy or /set then failed, the user lost even the menu that used to work - a perfectly installed system
    # becoming unbootable because "repair" was run is the least acceptable failure mode.
    # The order is reversed now: the new entry passes a character-by-character check -> only then touch the old one. Worst case: one extra menu entry.
    if ($oldGuid -and ($oldGuid -ine $guid)) {
        Write-Log "New entry verified, deleting the old entry left by the previous run: $oldGuid"
        $dr = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $oldGuid) -Tag 'del-old'
        if ($dr.Ok) {
            Write-Log 'Old entry deleted'
        } else {
            Write-Log ("The old entry cannot be deleted (harmless, it only adds one line to the boot menu): {0}" -f $dr.Text) 'WARN'
            Add-Result ("Old boot entry {$oldGuid} could not be deleted; the menu may show one extra line, ignorable")
        }
    }

    # ---------- Enable the boot menu ----------
    # With timeout=0 or displaybootmenu=No the machine boots the default system directly and the menu is never seen
    [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu')
    if ($origTimeout -eq '0') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout')
        Write-Log 'Original timeout=0 changed to 10 seconds, otherwise the menu is never shown'
    }

    # ---------- Clear a leftover one-shot bootsequence ----------
    # {bootmgr} bootsequence is a one-shot "boot straight into this system next time" value, normally cleared
    # by winload after the first boot; but when a boot is interrupted or fails it stays behind - the menu is then
    # short-circuited and stays invisible even with displayorder/default fixed (hit on real hardware on 2026-11-05).
    # So clear it once after the repair: when the value is absent bcdedit errors out, which is silently ignored.
    $bsChk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'menu'
    if (([string]$bsChk.Raw) -match '(?im)^\s*bootsequence\s') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/deletevalue', '{bootmgr}', 'bootsequence') -Tag 'menu')
        Write-Log 'Found a leftover bootsequence (one-shot) and cleared it - otherwise the menu stays short-circuited'
    }

    # ---------- State file ----------
    #
    # Key names must match the installer and the uninstaller: all three understand Desc (the uninstaller also falls back to Name).
    # v1.4 wrote only Description here, so a system whose boot entry was restored with this tool
    # could no longer be read by the installer or uninstaller - the custom name was lost once more in this corner.
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
        # The uninstaller uses it to decide "this entry existed before" vs "it was never set at all":
        # the latter needs bcdedit /deletevalue to restore "not set"; writing No would switch off somebody's dual-boot menu.
        OrigDisplayMenuSet = $origDisplaySet
        BcdBackup        = $old['BcdBackup']
        Created          = $old['Created']
        Repaired         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    Write-Log "State file: $statePath"

    # ---------- Clean up the C:\EFI junk (C:\Boot is never touched) ----------
    #
    # [v1.31 critical fix] This used to be @('C:\EFI', 'C:\Boot'). C:\Boot is the Windows
    # system boot folder (BCD / BCD.LOG / bootvhd.dll / BOOTSTAT.DAT all live there) and deleting it recursively
    # on nothing but "created less than 48 hours ago" could wipe system files at any moment, plus the transaction logs
    # of the active BCD. **C:\Boot is off limits, do not add it back to the list.**
    #
    # C:\EFI may also be used by third-party boot managers such as rEFInd / OpenCore / Clover,
    # and deleting it recursively based on age alone would destroy their boot setup. So inspect the contents first:
    # skip when there are subfolders other than Microsoft / Boot, or when a BCD / bootmgfw.efi sits underneath.
    foreach ($junk in @('C:\EFI')) {
        if (-not (Test-Path -LiteralPath $junk)) { continue }
        try {
            $age = (Get-Date) - (Get-Item -LiteralPath $junk).CreationTime
            if ($age.TotalHours -ge 48) {
                Write-Log "$junk exists but is older than the window, leaving it for you to inspect" 'WARN'
                continue
            }

            $unsafe = $false
            if ($junk -eq 'C:\EFI') {
                $subs = @(Get-ChildItem -LiteralPath $junk -Directory -EA SilentlyContinue)
                foreach ($s in $subs) {
                    if ($s.Name -notin @('Microsoft', 'Boot')) { $unsafe = $true; break }
                }
                # v1.31: if there is a working boot loader underneath (BCD / bootmgfw.efi), leave it alone
                if (-not $unsafe) {
                    $bcdHit = @(Get-ChildItem -LiteralPath $junk -Recurse -Force -EA SilentlyContinue | Where-Object {
                        $_.Name -eq 'BCD' -or $_.Name -like 'BCD.LOG*' -or $_.Name -eq 'bootmgfw.efi'
                    })
                    if ($bcdHit.Count -gt 0) { $unsafe = $true }
                }
            }
            if ($unsafe) {
                Write-Log "Skipping $junk (it contains a third-party boot folder, not created by this program)" 'WARN'
                continue
            }

            Remove-Item -LiteralPath $junk -Recurse -Force -EA Stop
            Write-Log "Removed the junk folder $junk"
        } catch {
            Write-Log "Failed to clean $junk (harmless): $($_.Exception.Message)" 'WARN'
        }
    }

    # ---------- Wrap-up ----------
    Add-Result ''
    Add-Result ("Boot menu entry: $desc")
    Add-Result ("Menu display time: 10 seconds (then boots the original system)")

    Show-Box ("Repair complete.`n`n" +
              "A boot entry has been registered for the virtual disk.`n`n" +
              "Next:`n" +
              "  1. Reboot the machine`n" +
              "  2. The system selection menu appears on the second boot screen`n" +
              "  3. Use the arrow keys to select ""$desc"" and press Enter`n" +
              "  4. Press nothing and the original system boots after 10 seconds`n`n" +
              "Log: $($Script:LogFile)") -Kind 'Info'

    Write-Log '===== Repair complete ====='

} catch {
    $msg = $_.Exception.Message
    Write-Log "Failed: $msg" 'ERROR'

    # Restore the BCD if anything broke.
    # bcdedit /import is used instead of copying the file back - the file route hits the sharing violation,
    # and the active store cannot be written through a file handle at all.
    if ($bcdBackup -and (Test-Path -LiteralPath $bcdBackup)) {
        $rs = Restore-BcdStore -Src $bcdBackup
        if ($rs.Ok) {
            $restored = $true
            Write-Log 'Restored the BCD to the pre-change backup' 'WARN'
        } else {
            Write-Log ("BCD restore FAILED! Run manually:  bcdedit /import ""{0}""   Reason: {1}" -f $bcdBackup, $rs.Text) 'ERROR'
        }
    }

    # When the backup failed, or /import failed too, the entry created by this run may still be in the BCD:
    # its description is the new system's name while its device points at the original system - a menu line that
    # silently boots back into the old system. Delete it separately. Failing that only leaves one extra line, which does not block booting.
    if ($newGuid -and (-not $restored)) {
        $rb = Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $newGuid) -Tag 'rollback-catch'
        if ($rb.Ok) {
            Write-Log "Deleted the entry created by this run: $newGuid (rollback)" 'WARN'
        } else {
            Write-Log ("The entry $newGuid created by this run cannot be deleted (the menu will show one extra line; run tools\Fix-Boot-Entry-Device.bat or delete it manually with bcdedit): {0}" -f $rb.Text) 'WARN'
        }
    }

    Show-Box ("Repair failed.`n`n$msg`n`nLog: $($Script:LogFile)") -Kind 'Error'

} finally {
    if ($mounted -and $VhdPath) { [void](Dismount-VhdSafe -Path $VhdPath) }
    if ($espLetter) { Release-EspLetter -Letter $espLetter }
}
