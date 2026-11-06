#Requires -Version 5.1
<#
  Virtual Hard Disk System - installer main program
  Installs a .wim image as an independent virtual hard disk system without touching the existing OS.
  Author: connectsegabot

  How it works:
    1. Create a .vhdx virtual disk file on the target partition
    2. Create **one** NTFS partition inside the virtual disk (native boot requires exactly one)
    3. Apply the image to that partition with DISM
    4. Add a boot entry with device=vhd=[...] to the **active BCD store** using bcdedit
       (the active store lives on the physical ESP, but we go through the BCD API instead of file I/O, see below)
  After a reboot the boot menu shows one extra entry: pick it to boot the new system, pick the old one to boot the original.

  Two pitfalls already paid for, do not undo them:

  (1) Do not go back to "create an ESP inside the vhdx + run bcdboot".
      UEFI firmware only reads the ESP on the physical disk; it never sees an ESP inside a vhdx.
      The result is bcdboot reporting success and no boot menu after reboot (v1.3).

  (2) Do not go back to "assign a drive letter to the physical ESP and read/write S:\EFI\Microsoft\Boot\bcd".
      The running OS holds a handle on that BCD, so any file-level access hits a sharing violation:
          The file "S:\EFI\Microsoft\Boot\bcd" is in use by another process
      bcdedit without /store operates on the active store - which already lives on the physical ESP,
      so it needs no drive letter, touches no file, and cannot hit a sharing violation (v1.5).
#>

param(
    # Root directories to search for images (multiple allowed, comma separated)
    [string]$SearchRoot = '',
    # Drive letter of the target partition
    [string]$TargetDrive = '',
    # Virtual disk size in GB
    [int]$SizeGB = 0,
    # Console mode: check only, never install
    [switch]$ConsoleMode,
    # Directory the user launched this program from (passed in by the bat, because $PSScriptRoot points to the temp folder after unpacking)
    [string]$OriginDir = ''
)

$ErrorActionPreference = 'Stop'
$Script:OriginDir = $OriginDir
$Script:Version = '1.34'
$Script:ProductName = 'Virtual Hard Disk System'

# ---- These must be defined before the exception hook is registered ----
$Script:TempDir = [System.IO.Path]::GetTempPath()
if (-not $Script:TempDir) { $Script:TempDir = 'C:\Windows\Temp\' }
$Script:LogDate = (Get-Date).ToString('yyyyMMdd')
$Script:LogName = "$($Script:ProductName)-$($Script:LogDate).log"
$Script:LogFile = Join-Path $Script:TempDir $Script:LogName
# [v1.29] The log directory can be redirected once an install location is chosen (see Set-LogDir):
# Previously logs always sat in %TEMP% and BCD backups were scattered next to the vhdx.
# Now everything goes under <install location>\<ProductName>-logs\.
$Script:LogDir = $Script:TempDir
try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogFile', $Script:LogFile) } catch {}
try { [System.AppDomain]::CurrentDomain.SetData('VHDX.LogDir', $Script:LogDir) } catch {}
# The default virtual disk file name is deliberately plain ASCII: diskpart's /s script files
# turn Chinese into ? under a non-Chinese code page and fail with "The filename, directory name, or volume label syntax is incorrect".
# Since v1.11 the user can pick a name, and ordinary Chinese names work fine (the diskpart script is now written as ANSI/GBK,
# see the comments in Invoke-Diskpart); only rare CJK characters and emoji outside ASCII get stripped.
$Script:DefaultDiskName = 'WinVHD'
$Script:VhdFileName = 'WinVHD.vhdx'

# Supported image formats
$Script:ImagePatterns = @('*.wim', '*.esd', '*.iso')
$Script:SupportedExts = @('.wim', '.esd', '.iso')

# Global unhandled-exception hook: write the failing line number into the log so the default WinForms dialog does not swallow it
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
                $msg = "$msg" + [char]13 + [char]10 + "  Location: $($ii.ScriptName):$($ii.ScriptLineNumber)  Line: $($ii.Line)"
            }
        } else {
            $msg = $ex.ToString()
        }
        $stamp = (Get-Date).ToString('HH:mm:ss')
        # [v1.29] The log path may be redirected by Set-LogDir when installation starts; a closure captures the old value,
        # so prefer the current value from the AppDomain data slot and fall back to the captured one.
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
# Basics
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line = '[{0}] [{1}] {2}' -f $stamp, $Level, $Message
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 -EA SilentlyContinue } catch {}
}

# [v1.29] Where side artifacts land: <folder containing the vhdx>\<ProductName>-logs\
#
# Why not next to the vhdx any more:
#   - One YYYYMMDD.log per day, one bcd-backup-*.bcd per run; after a few runs they pile up
#   - bcdedit /export also drops three companion files: .LOG / .LOG1 / .LOG2
#   - When the user keeps the vhdx in the root of D:, all of that litter lands in the drive root
# Collect them into one subfolder so only the vhdx and its .boot.txt remain next to it.
function Get-SideLogDir {
    param([string]$VhdPath)
    $base = Split-Path -Parent $VhdPath
    if (-not $base) { return $Script:TempDir }
    $dir = Join-Path $base "$($Script:ProductName)-logs"
    if (-not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {}
    }
    # If it cannot be created (read-only disk, permissions), fall back to the vhdx folder - never abort the install over a log move
    if (Test-Path -LiteralPath $dir) { return $dir }
    return $base
}

# Move the log being written to the install location (carrying over what has been written so far)
function Set-LogDir {
    param([string]$VhdDir)
    if (-not $VhdDir) { return }
    try {
        $dir = Join-Path $VhdDir "$($Script:ProductName)-logs"
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -EA Stop | Out-Null
        }
    } catch {
        Write-Log "Could not create the log directory, staying in the temp folder: $VhdDir ($($_.Exception.Message))" 'WARN'
        return
    }
    $newFile = Join-Path $dir $Script:LogName
    if ($newFile -ieq $Script:LogFile) { return }
    # Move only on the first switch away from the temp folder, so installing a second system does not drag the first system's log along
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
    Write-Log "Log location: $newFile"
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
# System name / file name (since v1.11 one machine can hold several systems)
# ============================================================
#
# Two things must stay separate:
#   Name     = the text shown in the boot menu; free-form, may contain Chinese or spaces
#   FileName = the .vhdx file on disk; must be unique within one disk
#
# Chinese file names are allowed: the diskpart /s script is written as ANSI (GBK) (see Invoke-Diskpart),
# and Chinese survives GBK encoding. What really must be blocked is illegal filesystem characters and emoji (unencodable in GBK).

$Script:BadNameChars = @('\', '/', ':', '*', '?', '"', '<', '>', '|')

function Get-SafeDiskName {
    param([string]$Raw)
    $n = ''
    if ($Raw) { $n = $Raw.Trim() }
    foreach ($c in $Script:BadNameChars) { $n = $n.Replace($c, '') }
    # [v1.27] Parentheses are syntax characters in BCD device paths and must never appear in a name.
    #
    # Real-world case: the image version name "Windows Server 2022 Standard (Desktop Experience)"
    # was used verbatim as the vhdx file name, so bcdedit received
    #   vhd=[D:]\Windows Server 2022 Standard (Desktop Experience).vhdx
    # bcdedit parses ( ) as delimiters and reads it back as
    #   vhd=[D:]\Windows Server 2022 Standard (Desktop Experience.vhdx,locate=...
    # The closing bracket is swallowed and the path is truncated: the entry looks present but is invalid.
    # Worse, after booting that system Windows registers WinRE by composing a ramdisk path with the same syntax,
    # which comes out broken and takes other boot entries in the BCD down with it.
    # Replace them with -: just as readable, and no more traps for the BCD.
    $n = ($n -replace '[\(\)\[\]\{\}]', '-')
    $n = ($n -replace '-{2,}', '-').Trim('-', ' ', '.')
    # Strip control characters
    $n = ($n -replace '[\x00-\x1F]', '')
    # Collapse repeated whitespace
    $n = ($n -replace '\s{2,}', ' ')
    # Windows file names may not end with a dot or a space
    $n = $n.TrimEnd('.', ' ')
    if (-not $n) { $n = $Script:DefaultDiskName }
    if ($n.Length -gt 48) { $n = $n.Substring(0, 48).TrimEnd('.', ' ') }
    # Reserved names
    if ($n -match '^(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { $n = "$n-" }
    return $n
}

# Can the name be encoded in the system ANSI code page? If not, diskpart writes it out with "?", the
# file is created under the question-mark name and Test-Path on the real path fails.
#
# [audit P1-5] This used to hard-code GBK (936). On an English system (ACP 1252) a Chinese name passed
# the check, yet diskpart wrote "???.vhdx" - "the name is valid but the creation fails", plus a junk
# file. Now it uses exactly the encoding Invoke-Diskpart writes the script with.
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

# Find a non-conflicting vhdx file name in the given folder: name / name-2 / name-3 ...
#
# Since v1.11 the user can choose any folder (not just a drive root), so this takes a full folder path.
# Passing a drive letter ("D") still works; it is expanded to "D:\" internally.
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
        # [v1.27] Use -2 instead of (2) for the suffix: same BCD parenthesis problem, see Get-SafeDiskName
        $cand = Join-Path $dir "$base-$i.vhdx"
        if (-not (Test-Path -LiteralPath $cand)) { return $cand }
    }
    throw "Too many systems with the same name already exist in this folder ($base 1~99). Choose another name or another folder."
}

# Turn a full path into the device syntax used by vhd= in the BCD.
#
# The intermediate subfolder MUST be preserved. Up to v1.12 this used GetFileName() and kept the file name only,
# so installing to D:\VirtualDisks\maimai.vhdx wrote vhd=[D:]\maimai.vhdx (a file that does not exist)
# and the entry existed in the menu but died with 0xc000000f on selection.
#
#   D:\VirtualDisks\maimai.vhdx   ->   vhd=[D:]\VirtualDisks\maimai.vhdx
function Get-VhdBcdDevice {
    param([string]$FullPath)
    if (-not $FullPath) { throw 'Internal error: no virtual disk path was passed' }
    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetPathRoot($full)
    if (-not $root -or $root.Length -lt 3) { throw "Invalid path (a full path is required, e.g. D:\VHD\x.vhdx): $FullPath" }
    $letter = $root.Substring(0, 1).ToUpper()
    $rel = $full.Substring($root.Length).TrimStart('\')
    if (-not $rel) { throw "Invalid path: $FullPath" }
    return "vhd=[$($letter):]\$rel"
}

# Reverse parsing: vhd=[D:]\VirtualDisks\maimai.vhdx -> D:\VirtualDisks\maimai.vhdx
# Used to compare what bcdedit reports back against the real path, character by character.
function Get-FullPathFromBcdDevice {
    param([string]$Dev)
    if (-not $Dev) { return '' }
    $m = [regex]::Match($Dev, '^vhd=\[([A-Za-z]):\]\\(.+)$')
    if (-not $m.Success) { return '' }
    return ("{0}:\{1}" -f $m.Groups[1].Value.ToUpper(), $m.Groups[2].Value)
}

# bcdedit prints through the console code page, so a character the page cannot carry comes
# back as "?". The English launcher runs "chcp 437", which turned every Chinese character in
# a path into "?" and made a correct BCD write look like a wrong path. The store is fine;
# compare tolerantly instead of aborting.
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

# Second opinion that never goes through the console: export the store and look for the path
# as UTF-16 inside the hive (a BCD store is a registry hive, string elements are UTF-16).
# Returns $true / $false, or $null when the export was not possible.
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
        # [v1.32] bcdedit /export also drops .LOG / .LOG1 / .LOG2 next to the hive; clean those too.
        foreach ($f in @($tmp, "$tmp.LOG", "$tmp.LOG1", "$tmp.LOG2")) {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

# [audit P0-1] Find the disk that was just attached, by FULL PATH - never by file name alone.
#
# The hazard this replaces: "Location -like *<file name>*" picks any disk whose file has the same
# name, and the caller then runs "select disk N; clean". With D:\A\WinVHD.vhdx and E:\Backup\WinVHD.vhdx
# both present (a backup copy on another volume is enough), the wrong disk could be cleaned.
#
# Order, each step strictly safer than the next:
#   1. Location equals the full path (case-insensitive, \\?\ prefix tolerated) -> accept
#   2. Same file name, EXACTLY ONE candidate -> accept
#   3. Same file name, several candidates -> throw, never pick one
# Returns $null when nothing matched.
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
        throw ("Two disks claim the same file ({0}):`n{1}`n`nNothing was touched." -f $full,
               (($exact | ForEach-Object { '    Disk ' + $_.Number }) -join "`n"))
    }

    $byName = @($Disks | Where-Object {
        $loc = & $clean $_.Location
        if (-not $loc) { return $false }
        return ([System.IO.Path]::GetFileName($loc) -eq $leaf)
    })
    if ($byName.Count -eq 1) { return $byName[0] }
    if ($byName.Count -gt 1) {
        throw ("More than one mounted virtual disk is called '{0}':`n{1}`n`nNothing was touched. " -f $leaf,
               (($byName | ForEach-Object { '    Disk ' + $_.Number + ': ' + $_.Location }) -join "`n")) +
              "Remove or rename the other one and run again."
    }
    return $null
}

# Scan every fixed NTFS drive for vhdx files (including subfolders, up to 3 levels deep).
#
# Do not use Get-ChildItem -LiteralPath "D:\*": -LiteralPath does not expand wildcards,
# it looks for a directory literally named "*" and always returns 0 results. Use -Path.
# Skip folders such as the recycle bin, otherwise files deleted there get listed as installed systems before it is emptied.
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

# Normalize a path typed or picked by the user into a full folder path and validate it.
# Returns @{ Ok = $true/false; Folder = normalized folder; Msg = human readable message }
function Test-TargetFolder {
    param([string]$Raw)
    $r = @{ Ok = $false; Folder = ''; Msg = '' }
    $p = ''
    if ($Raw) { $p = $Raw.Trim().Trim('"').TrimEnd('\') }
    if (-not $p) { $r.Msg = 'Please enter the folder to store the system in'; return $r }

    # The user only typed a drive letter (D: or D) -> treat it as D:\
    if ($p -match '^[A-Za-z]$') { $p = "$($p):\" }
    if ($p -match '^[A-Za-z]:$') { $p = "$p\" }

    if ($p -notmatch '^[A-Za-z]:\\') {
        $r.Msg = 'A full path is required, for example D:\VHD'; return $r
    }
    if ($p -match '(^|\\)\.\.?(\\|$)') {
        $r.Msg = 'Do not use . or .. in the path'; return $r
    }
    if (-not (Test-EncodableName $p)) {
        $r.Msg = 'The path contains characters that the system code page cannot represent (emoji etc.), please pick another one'; return $r
    }
    # [audit P1-6] Brackets are syntax characters in the BCD device path: vhd=[D:]\My (Games)\WinVHD.vhdx
    # is truncated at ")" (see the v1.27 note in Get-SafeDiskName). The FILE name was always sanitised,
    # but the FOLDER name used to pass straight through.
    if ($p -match '[\(\)\[\]\{\}]') {
        $r.Msg = 'The folder name contains ( ) [ ] or { } - a boot entry cannot express those. Please use a folder without brackets, for example D:\VHD'; return $r
    }
    if (-not (Test-Path -LiteralPath $p)) {
        $r.Msg = "This folder does not exist yet: $p"
        return $r
    }
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        $r.Msg = "This is a file, not a folder: $p"
        return $r
    }

    # Must be a local fixed disk: network and optical drives are unreliable (they cannot be mounted at native-boot time anyway)
    $letter = $p.Substring(0, 1).ToUpper()
    $vol = Get-Volume -DriveLetter $letter -EA SilentlyContinue
    if (-not $vol) { $r.Msg = "Drive $letter`: not found"; return $r }
    if ($vol.DriveType -ne 'Fixed') {
        $r.Msg = "$letter`: is not a local hard disk (USB, network and optical drives cannot be read at boot time)"; return $r
    }
    if ($vol.FileSystem -ne 'NTFS') {
        $r.Msg = "$letter`: is a $($vol.FileSystem) partition, NTFS is required (exFAT/FAT32 will not work)"; return $r
    }

    # It must not sit inside the protected top-level folders of the system drive (permissions / held by the OS)
    $sysDrive = "$($env:SystemDrive.ToUpper())\"
    $lc = $p.ToLower()
    foreach ($bad in @("$($sysDrive.ToLower())windows", "$($sysDrive.ToLower())program files",
                       "$($sysDrive.ToLower())program files (x86)", "$($sysDrive.ToLower())programdata",
                       "$($sysDrive.ToLower())users")) {
        if ($lc -eq $bad -or $lc.StartsWith($bad + '\')) {
            $r.Msg = 'Do not use Windows / Program Files / Users and other system folders, pick another folder'; return $r
        }
    }

    $r.Ok = $true
    $r.Folder = $p
    return $r
}

# How much is left on the partition holding this folder (GB); returns -1 on failure
#
# [v1.12] This used to rely on Get-Volume SizeRemaining alone. That failed in practice:
# Get-Volume / Get-PSDrive / DriveInfo all reported 436 GB free on the same disk,
# while the UI popped up "0 KB remaining". The SizeRemaining property of a Volume object can read 0
# (volume just mounted, WMI property not refreshed, or the drive letter and volume briefly out of sync).
# It now queries three sources and takes the largest valid answer:
#   1. Get-Volume SizeRemaining
#   2. [System.IO.DriveInfo] AvailableFreeSpace (asks the filesystem directly, closest to what a write can use)
#   3. Get-PSDrive Free
# Any source returning > 0 is trusted, so an error in a single source cannot lock the user out.
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
        # All three sources failed: distinguish "the drive does not exist" (-1) from "the drive exists but reports 0" (0)
        try {
            $di2 = New-Object System.IO.DriveInfo("$($letter):\")
            if (-not $di2.IsReady) { return -1 }
            return 0
        } catch {
            return -1
        }
    }
    # [audit P3] Take the MINIMUM of the three sources, not the maximum. This number feeds the space
    # preflight, and a preflight must never be optimistic: if Get-Volume, DriveInfo and Get-PSDrive
    # disagree (quotas, filters, a stale cache), the smallest one is the one that will bite.
    $min = [int64](($vals | Measure-Object -Minimum).Minimum)
    $max = [int64](($vals | Measure-Object -Maximum).Maximum)
    if ($max -gt 0 -and $min -lt ($max * 0.9)) {
        Write-Log ("Free space sources disagree: min={0} max={1} bytes; using the smaller value" -f $min, $max) 'WARN'
    }
    return $min
}

function Get-FreeGB {
    param([string]$Folder)
    $b = Get-DiskFreeBytes $Folder
    if ($b -lt 0) { return -1 }
    return [math]::Round($b / 1GB, 1)
}

# Real writability probe: create a 64 MB temp file and delete it again.
#
# Why it is mandatory: even a perfectly accurate free-space number is only a *reported* value. What decides
# whether a write succeeds is "can this folder actually take a file that large" - quotas, disk compression, dedup,
# mirrored volumes, a deny-write ACL on a parent folder, or even a folder such as "VirtualDisks" hooked by sync/backup
# software can all make the reported value look great while the write fails. Worse is the opposite case:
# a reported 0 with writes working fine (which is exactly what happened here); trusting the number alone would lock the user out.
#
# The result is @{ Ok=bool; Msg=string; BytesPerSec=... },
# where Msg is a readable explanation when it fails.
function Test-FolderWritable {
    param([string]$Folder, [int]$ProbeMB = 64)
    $r = @{ Ok = $false; Msg = '' }
    if (-not $Folder) { $r.Msg = 'No folder specified'; return $r }
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        $r.Msg = "This folder does not exist: $Folder"
        return $r
    }
    $probe = $null
    try {
        $probe = Join-Path $Folder ('.vhdspace_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
        $buf = New-Object byte[] (1MB)
        $fs = [System.IO.File]::Open($probe, [System.IO.FileMode]::Create,
                                     [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $fs.SetLength([int64]$ProbeMB * 1MB)   # sparse write: fast, yet it really reserves quota
            $fs.Flush()
        } finally {
            $fs.Close()
        }
        $len = (New-Object System.IO.FileInfo($probe)).Length
        if ($len -lt ([int64]$ProbeMB * 1MB)) {
            $r.Msg = "Write test failed: could only write $([math]::Round($len / 1MB)) MB"
        } else {
            $r.Ok = $true
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match 'denied|拒绝|未授权') {
            $r.Msg = 'No write permission on this folder (it may be protected by security software, or a parent folder denies writes)'
        } elseif ($msg -match 'space|空间|磁盘已满') {
            $r.Msg = 'The disk filled up while writing the test file into this folder'
        } elseif ($msg -match 'read-only|只读|写保护') {
            $r.Msg = 'This partition is read-only'
        } else {
            $r.Msg = "Write test failed: $msg"
        }
    } finally {
        if ($probe) {
            try { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force -EA SilentlyContinue } } catch {}
        }
    }
    return $r
}

# List the virtual hard disk systems already installed on this machine
#
# Since v1.11 the storage folder is customizable, so the drive root alone is not enough: scan each fixed NTFS drive root
# two levels down (covers the usual D:\VHD layout without walking the whole drive).
function Find-InstalledSystems {
    $found = @()
    # v1.13: switched to Get-AllVhdxFile so systems installed in subfolders are listed too.
    # The old code used Get-ChildItem -LiteralPath (Join-Path $root '*'), and -LiteralPath does not expand wildcards,
    # so the subfolder scan did nothing and D:\VirtualDisks\maimai.vhdx could never be listed.
    foreach ($f in @(Get-AllVhdxFile)) {
        # Always go through the shared function: Desc -> Name -> Description fallback, so any state file yields a name
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
# Single entry point for diskpart (every diskpart call must go through here)
#
# Three things must be done together, skipping any one of them breaks something:
#
# 1) Write the script file as **ANSI (the current system code page, i.e. GBK on a Chinese system)**, not ASCII.
#    The ASCII encoder replaces every non-ASCII character with '?':
#    the path "D:\NewSystem.vhdx" becomes "D:\???.vhdx"
#    -> DiskPart reports "The filename, directory name, or volume label syntax is incorrect"
#    -> but the file was already created under that question-mark name, so Test-Path on the original path fails
#       while the script thinks it attached the VHD. Doubly misleading.
#    Measured (Build 26200): Encoding.ASCII writes 44 3A 5C 3F 3F 3F 2E 76 68 64 78
#
# 2) Line endings must be CRLF. diskpart /s tolerates LF, but line endings get messy with mixed encodings, so always CRLF.
#
# 3) $LASTEXITCODE is **unreliable** for the return value (calling diskpart from PowerShell often yields $null),
#    so the output text must be parsed. On an English system the error text is "DiskPart has encountered an error",
#    on a Chinese system it is "DiskPart 遇到错误"; both must match.
# ============================================================

# Get the encoding object for the current system ANSI code page (GBK/936 on a Chinese system)
function Get-AnsiEncoding {
    try {
        $cp = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name ACP -EA Stop).ACP
        return [System.Text.Encoding]::GetEncoding($cp)
    } catch {
        return [System.Text.Encoding]::GetEncoding(936)
    }
}

# Call diskpart. $Lines is the command array; returns @{ Ok; Text; Path; Error }
function Invoke-Diskpart {
    param([string[]]$Lines, [string]$Tag = 'dp')

    $f = Join-Path $Script:TempDir ("dp-$Tag-$(Get-Random).txt")
    # Build CRLF by hand: do not gamble on which newline StringBuilder.AppendLine uses
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

function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N0} MB' -f ($bytes / 1MB)) }
    return ('{0:N0} KB' -f ($bytes / 1KB))
}

# ============================================================
# WIM validation
# ============================================================

# ============================================================
# ISO mounting
# ============================================================

# Mount an ISO, returns { Ok, Drive, Path, Name, Error }
# Path/Name are the full path and file name of the install.wim / install.esd found inside
function Open-IsoImage {
    param([string]$Path)
    $r = [PSCustomObject]@{ Ok = $false; Drive = ''; Path = ''; Name = ''; Error = '' }

    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = 'The ISO file does not exist'; return $r }

    # Mount: prefer Mount-DiskImage (built into Win8+), otherwise the PowerShell COM route
    $mounted = $false
    if (Get-Command Mount-DiskImage -EA SilentlyContinue) {
        try {
            Mount-DiskImage -ImagePath $Path -EA Stop | Out-Null
            $mounted = $true
        } catch {
            $r.Error = "Failed to mount the ISO: $($_.Exception.Message)"
            return $r
        }
    } else {
        $r.Error = 'This system cannot mount an ISO (Windows 8 or later is required)'
        return $r
    }

    # Wait for the drive letter to appear
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
        $r.Error = 'The ISO was mounted but no drive letter appeared'
        return $r
    }
    $r.Drive = $drive

    # Find the image inside the ISO: prefer sources\install.wim, then sources\install.esd
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

    # Fallback: search recursively (some third-party ISOs use a different layout)
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

    $r.Error = 'No sources\install.wim or install.esd inside the ISO; this may not be a Windows installation disc'
    return $r
}

# Read the XML metadata at the end of a WIM/ESD (there may be several blocks; decode them all and merge).
#
# Why not simply call dism /Get-WimInfo:
#   * it takes 1-3 seconds per call, so the UI stutters on every image switch;
#   * trimmed systems / PE may not ship dism at all;
#   * index numbers, index names and unpacked sizes are all written in this XML anyway.
# Test-WimFile and Get-ImageIndexList share it, so the parsing logic exists only once.
function Read-WimXml {
    param([string]$Path)

    $r = [PSCustomObject]@{ Ok = $false; Xml = ''; Error = '' }
    if (-not $Path) { $r.Error = 'No file specified'; return $r }
    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = 'The file does not exist'; return $r }

    try {
        $fi = Get-Item -LiteralPath $Path
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $magic = New-Object byte[] 8
            [void]$fs.Read($magic, 0, 8)
            if ([System.Text.Encoding]::ASCII.GetString($magic) -notlike 'MSWIM*') {
                $r.Error = 'Not a WIM/ESD image (the header is not MSWIM)'
                return $r
            }

            $cap = [int64]4MB
            $tailLen = if ($fi.Length -lt $cap) { [int]$fi.Length } else { [int]$cap }
            $fs.Seek($fi.Length - $tailLen, [System.IO.SeekOrigin]::Begin) | Out-Null
            $tail = New-Object byte[] $tailLen
            [void]$fs.Read($tail, 0, $tailLen)
        } finally { $fs.Close() }
    } catch {
        $r.Error = "Read error: $($_.Exception.Message)"
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
            # [v1.25] Break as soon as it is found; do not keep scanning.
            # This loop looks for a UTF-16 "<W", and every <WINDOWS> in the XML is a hit:
            # the old code did $xml += ... without break, so the same XML was appended again and again (measured on a real
            # single-index image, '</WIM>' appeared 3 times and the XML grew from ~1300 to 2551 characters).
            # Single-index images got away with it because the regex took the first match; multi-index images
            # (e.g. the 4 editions in Server 2022) multiplied the <IMAGE> count and the edition table, filling the dropdown with duplicates.
            $xml = $raw.Substring(0, $cut + $cutLen)
            break
        }
    }
    if (-not $xml) { $r.Error = 'Image metadata could not be parsed; the file may be corrupt'; return $r }

    $r.Ok = $true
    $r.Xml = $xml
    return $r
}

# List every index ("edition") inside the image, returns @(PSCustomObject{Index; Name; Desc}).
#
# One install.wim can hold several systems: the official Windows Server ISO ships
#   1 Standard(Core)  2 Standard(Desktop Experience)  3 Datacenter(Core)  4 Datacenter(Desktop Experience)
# This used to install index 1 unconditionally, which on Server is the one with no GUI - the result booted to a black console.
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
        # <IMAGE INDEX="1"> ... </IMAGE>: split with a lookahead, not with a lazy .*?</IMAGE> -
        # some images lack the DIRCOUNT/SIZE blocks, and a greedy match would then run into the next index.
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
            if (-not $nm) { $nm = 'Index ' + $im.Groups[1].Value }

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
        # Fallback: only ask dism when the XML cannot be parsed (WIMs rebuilt by third-party tools)
        $names = @(Get-ImageIndexNames -Path $Path)
        for ($i = 0; $i -lt $names.Count; $i++) {
            $list += [PSCustomObject]@{ Index = ($i + 1); Name = $names[$i]; Desc = '' }
        }
    }

    return ($list | Sort-Object Index)
}

# Turn an edition name into plain language. The point is Server Core vs Desktop Experience -
# the two names look almost identical, and installing the wrong one costs a full 20-minute rerun.
function Format-EditionLabel {
    param([string]$Name, [string]$Desc = '')

    $n = [string]$Name
    if (-not $n) { return '(unnamed)' }

    $hasDesktop = $false
    if ($n -match '(?i)Desktop\s*Experience') {
        $hasDesktop = $true
        $n = ($n -replace '(?i)\s*[(（]\s*Desktop\s*Experience\s*[)）]', '').Trim()
    }
    if (-not $hasDesktop -and $Desc -match '(?i)Desktop\s*Experience') { $hasDesktop = $true }

    if ($hasDesktop) { return "$n (Desktop Experience: has a GUI)" }
    if ($n -match '(?i)server') { return "$n (no GUI / Server Core)" }
    return $n
}

# List all index names in the image with DISM, returns a string array (empty array on failure)
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

# Pick an index that can actually be installed as a system (1-based).
# On official ISOs, index 1 of install.esd / install.wim is sometimes "Windows PE" or "Windows Setup";
# installing that yields a useless system, so skip them.
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

    # Preferred: unmount by path.
    # Note that Get-DiskImage without -ImagePath fails with "mandatory parameter missing", so never rely on enumeration alone.
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

    # Fallback: when only a drive letter is known, look the path up through the Storage module's MSFT_DiskImage
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

# Resolve the image the user picked into "a file path DISM can actually consume"
# .wim / .esd are returned directly; .iso is mounted first and sources\install.wim or install.esd is returned
# Returns { Ok, Path, IsoDrive, Kind, Error }; always release it afterwards with Close-IsoImage -Drive $r.IsoDrive
function Resolve-RealImage {
    param([string]$Path)

    $r = [PSCustomObject]@{ Ok = $false; Path = ''; IsoDrive = ''; IsoPath = ''; Kind = ''; Error = '' }
    if (-not $Path) { $r.Error = 'No image file specified'; return $r }

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

    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = 'The image file does not exist'; return $r }
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
        # Edition table for multi-edition images. For an ISO this is parsed at the outer level (already mounted, saves one mount).
        IndexList = @()
    }

    if (-not $Path) { $r.Error = 'No file specified'; return $r }
    if (-not (Test-Path -LiteralPath $Path)) { $r.Error = 'The file does not exist'; return $r }

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $r.Kind = switch ($ext) { '.esd' { 'ESD' } '.iso' { 'ISO' } default { 'WIM' } }

    # Mount the ISO first, then validate the install.wim / install.esd inside it
    if ($ext -eq '.iso') {
        $inner = Open-IsoImage -Path $Path
        if (-not $inner.Ok) { $r.Error = $inner.Error; return $r }
        $r.Kind = 'ISO'
        try {
            $innerInfo = Test-WimFile -Path $inner.Path
            if (-not $innerInfo.Valid) {
                $r.Error = "The $($inner.Name) inside the ISO is not usable: $($innerInfo.Error)"
                return $r
            }
            $fi = Get-Item -LiteralPath $Path
            $r.SizeGB = [math]::Round($fi.Length / 1GB, 2)
            $r.Valid = $true
            $r.Name = "$($innerInfo.Name)  [ISO]"
            $r.Build = $innerInfo.Build
            $r.Images = $innerInfo.Images
            $r.UncompGB = $innerInfo.UncompGB
            # While the ISO is still mounted, parse the edition table too - otherwise the UI would need
            # a second mount just to list editions (1-2 extra seconds, plus an audible optical drive spin-up)
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

    # The trailing-XML parsing moved into Read-WimXml and is shared with Get-ImageIndexList here
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

    if (-not $r.Name) { $r.Error = 'The image has no name information; it may not be a Windows image'; return $r }

    # [audit P3] Reject a foreign architecture up front. An x86 / ARM64 image applies without complaint and
    # then simply never boots, which the user only discovers after a 20 minute install and a reboot.
    # WIM <ARCH> codes: 0 = x86, 5 = ARM, 6 = Itanium, 9 = x64, 12 = ARM64.
    $mArch = [regex]::Match($xml, '<ARCH>(\d+)</ARCH>')
    if ($mArch.Success) {
        $arch = [int]$mArch.Groups[1].Value
        if (@(0, 5, 6, 12) -contains $arch) {
            $archName = switch ($arch) { 0 { 'x86 (32-bit)' } 5 { 'ARM' } 6 { 'Itanium' } 12 { 'ARM64' } }
            $r.Error = "This image is $archName. Native-boot VHDX (vhd= in the boot entry) only works with x64 Windows - please pick an x64 image."
            return $r
        }
    }

    # Only parse the edition table for multi-index images (a single-index image has exactly one, so there is no point)
    if ($r.Images -gt 1) { $r.IndexList = @(Get-ImageIndexList -Path $Path) }

    $r.Valid = $true
    return $r
}

# ============================================================
# Partition enumeration
# ============================================================

# List partitions that can hold a vhdx.
#
# [v1.16 fix] This used to run an unconditional `if ($v.DriveLetter -eq $sysLetter) { continue }`,
# which filtered out the system drive entirely. On a single-drive machine (C: only) the list came back empty,
# the UI took the else branch and disabled both "Browse..." and the path box - the user had 500 GB free
# and not a single button would work, nor could the folder on C: be typed in manually (Test-TargetFolder allows C: anyway).
#
# Now the system drive is returned too, flagged with IsSystem so the UI can decide how to warn and sort it last.
# Pass -ExcludeSystem to filter it out (no caller does that today; kept for later).
function Get-TargetVolumes {
    param([switch]$ExcludeSystem)
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $list = @()
    foreach ($v in (Get-Volume -EA SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        if (-not $v.DriveType) { continue }
        # Must be a local fixed disk: USB, network and optical drives cannot be read at boot time, so native boot fails
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
    # Non-system drives come first, so the default selection is the recommended one
    return ($list | Sort-Object @{ Expression = { [int]$_.IsSystem } }, Letter)
}

function Find-WimFiles {
    param([string]$Roots)

    $results = @()
    $dirs = @()
    if ($Roots) {
        $dirs += ($Roots -split ',' | ForEach-Object { $_.Trim() })
    } else {
        # $PSScriptRoot is the temp folder after unpacking, not the folder the user keeps the bat in,
        # so OriginDir (the %~dp0 passed in by the bat) is added as well
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
        # [removed] This used to add the root of every drive to the scan; far too slow and too heavy:
        #   it would scan even for a 21 GB wim just to list a name, while drive roots usually hold nothing relevant.
        #   Now it only considers four locations: the folder holding the bat, its parent, the Desktop and Downloads,
        #   plus whatever search folder the user picks in the dropdown. Anything else can be picked with the "Browse" button.
    }

    foreach ($d in $dirs) {
        if (-not $d) { continue }
        try {
            if (-not (Test-Path -LiteralPath $d)) { continue }
            foreach ($pat in $Script:ImagePatterns) {
                # Scan this level first
                $items = Get-ChildItem -LiteralPath $d -Filter $pat -File -EA SilentlyContinue
                if ($items) { foreach ($it in $items) { $results += $it.FullName } }
                # For non-root folders, scan two levels down (most people keep images in a subfolder)
                if ($d -notmatch '^[A-Za-z]:\\?$') {
                    $sub = Get-ChildItem -LiteralPath $d -Filter $pat -File -Recurse -Depth 2 -EA SilentlyContinue
                    if ($sub) { foreach ($it in $sub) { $results += $it.FullName } }
                }
            }
        } catch {}
    }

    if (-not $results) { return @() }

    # Obvious non-Windows discs are not listed at all, so the user does not see a row of "Valid=False" entries and panic
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
# Main body: install to a virtual disk
# ============================================================

# Dismount the virtual disk: prefer the Hyper-V module, fall back to diskpart (no extra components required)
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

# Check whether this machine can create VHD/VHDX (either the Hyper-V module or diskpart will do)
function Test-VhdCapability {
    if (Get-Command New-VHD -EA SilentlyContinue) { return @{ Ok = $true; Mode = 'Hyper-V' } }
    # No Hyper-V module is fine, diskpart ships its own create vdisk
    if (Get-Command diskpart -EA SilentlyContinue) {
        $build = [int](Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue).BuildNumber
        # Win7/2008R2 does not support vhdx; Windows 8 and later do
        if ($build -ge 9200) { return @{ Ok = $true; Mode = 'diskpart' } }
        return @{ Ok = $false; Mode = ''; Reason = 'This Windows version is too old for VHDX (Windows 8 / Server 2012 or later is required)' }
    }
    return @{ Ok = $false; Mode = ''; Reason = 'diskpart not found; the system environment is broken' }
}

# ============================================================
# Boot: add a vhd= entry to the BCD on the physical ESP
#
# [Why bcdboot can no longer be used]
# bcdboot only writes boot files to "the partition you point it at". But an ESP inside the virtual disk
# is never read by UEFI firmware - firmware only looks at the ESP on the physical disk.
# So no matter how the bcdboot arguments were tweaked up to v1.3, the outcome was "exit=0 but no menu after reboot",
# and it could even write C:\EFI and C:\Boot out as junk (the /f ALL trap).
#
# The correct way to do native boot VHD:
#   inside the vhdx: a single NTFS partition (the system files)
#   physical ESP:   one entry added to /EFI/Microsoft/Boot/BCD
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

# Locate the ESP on the physical disk (found via the disk holding the system drive, so a virtual disk is never picked by mistake)
function Find-PhysicalEsp {
    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $sysPart = Get-Partition -DriveLetter $sysLetter -EA SilentlyContinue
    if (-not $sysPart) { return $null }
    foreach ($p in (Get-Partition -DiskNumber $sysPart.DiskNumber -EA SilentlyContinue)) {
        if ((Get-PartGpt $p) -eq $GUID_ESP) { return $p }
    }
    return $null
}

# Temporarily assign a drive letter to the ESP. Set-Partition fails with
# "The requested access path is already in use." when the mount state is unclean, so try several candidates and fall back to mountvol.
function Mount-EspLetter {
    param([int]$DiskNumber, [int]$PartitionNumber)

    $p = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -EA SilentlyContinue
    if ($p -and $p.DriveLetter) { return @{ Ok = $true; Letter = [string]$p.DriveLetter; Mode = 'already has a letter' } }

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

# Single entry point for bcdedit.
#
# [Why /store is not used - the core v1.5 fix]
# This used to assign a drive letter to the physical ESP and then copy/rewrite S:\EFI\Microsoft\Boot\bcd as an ordinary file.
# On real hardware that hits the lock immediately:
#     The file "S:\EFI\Microsoft\Boot\bcd" is in use by another process, so the process cannot access it
# The running OS holds a handle on that BCD, so any file-level access is denied.
# bcdedit without /store operates on the "active BCD store", the very store the current system booted from -
# which already lives on the physical ESP. Editing it edits the physical ESP, needs no drive letter,
# touches no file and cannot hit a sharing violation.
#
# Passing an empty string for $Store means the active store.
function Invoke-BcdEdit {
    param([string]$Store = '', [string[]]$BcdArgs, [string]$Tag = '')

    $all = @()
    if ($Store) { $all += @('/store', $Store) }
    $all += $BcdArgs

    $txt = ''
    try { $txt = (& bcdedit @all 2>&1 | Out-String) } catch { $txt = "call failed: $($_.Exception.Message)" }
    $code = $LASTEXITCODE
    $clean = ($txt -replace '\s+', ' ').Trim()
    Write-Log ("bcdedit {0} [{1}] => exit={2}  {3}" -f $Tag, ($BcdArgs -join ' '), $code, $clean)

    $err = ($txt -match '找不到|not found|无效|invalid|拒绝|denied|失败|failed|错误|error')
    return @{ Ok = (($code -eq 0) -and (-not $err)); Code = $code; Text = $clean; Raw = $txt }
}

# Pick the source entry used by /copy, returns @{ Guid; Tag }.
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
    $blocks = [regex]::Split($enum.Raw, '(?im)^(?=\s*(?:identifier)\s+\{)')
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
        $dm = [regex]::Match([string]$bmRaw, '(?im)^\s*(?:displayorder)\s+(.+)$')
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

# Back up the active BCD store through bcdedit /export (the BCD API), not a file copy, so the file lock is bypassed.
# A failure does not block the install: only an entry is added and the menu timeout is changed, both reversible with bcdedit.
function Backup-BcdStore {
    param([string]$Dest)
    # [v1.29] bcdedit /export writes a registry hive, and Windows drops X.bcd.LOG / X.bcd.LOG1 / X.bcd.LOG2
    # transaction logs next to the target.
    # This used to export straight into the vhdx folder, which ended up with dozens of .bcd.LOG* files that survived deleting the .bcd.
    # Now it exports into a temp folder, copies only the .bcd to the destination, and removes the temp file with its three companion LOGs.
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

# Install / repair the boot entry. Returns @{ Ok; Guid; Desc; BcdPath; Backup; Error }
# When $ExistingGuid is not empty the old entry is deleted first (a re-run does not stack entries)
function Install-BootEntry {
    param(
        [string]$VhdFullPath,
        [string]$ExistingGuid = '',
        [string]$EditionName = '',      # image edition name, used as a fallback when the name is left empty
        [string]$DisplayName = ''       # the name the user gave this system, used verbatim as the boot menu text
    )

    $r = [PSCustomObject]@{
        Ok = $false; Guid = ''; Desc = ''; BcdPath = ''
        Backup = ''; EspLetter = ''; OrigTimeout = '30'; OrigDisplay = ''
        OrigDisplaySet = '0'    # whether displaybootmenu was really present in the BCD before (1=present, 0=absent)
        Error = ''
    }

    if ((Get-FirmwareType) -ne 2) {
        $r.Error = 'UEFI only. This machine is Legacy BIOS; booting from a virtual disk needs a different boot path.'
        return $r
    }

    # ---------- Locate the active BCD store ----------
    #
    # The physical ESP is not mounted and BCD files are not read or written. Why: see the comment above Invoke-BcdEdit.
    # The bcd on the ESP is held by the running system, so file-level access always hits a sharing violation.
    #
    # The ESP is still located purely so the log can show which disk the menu lands on; not finding it does not block anything.
    $esp = Find-PhysicalEsp
    if ($esp) {
        Write-Log ("Physical ESP (logged only, not mounted): disk {0} partition {1}, {2:N0} MB" -f
                   $esp.DiskNumber, $esp.PartitionNumber, ($esp.Size / 1MB))
    } else {
        Write-Log 'Could not locate the physical ESP (harmless: the entry is written to the active BCD store)' 'WARN'
    }
    $r.BcdPath = 'active BCD store'

    # Backup: a broken change must be reversible
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    # [v1.29] Backups go into "<ProductName>-logs" instead of being scattered next to the vhdx
    $backupDir = Get-SideLogDir -VhdPath $VhdFullPath
    $backup = Join-Path $backupDir ("bcd-backup-$stamp.bcd")
    $bk = Backup-BcdStore -Dest $backup
    if ($bk.Ok) {
        $r.Backup = $backup
        Write-Log ("BCD backed up ({0}, {1} bytes): {2}" -f $bk.Mode, $bk.Size, $backup)
    } else {
        Write-Log ("BCD backup failed, continuing anyway (only an entry is added and the menu timeout changed, both reversible with bcdedit): {0}" -f $bk.Error) 'WARN'
        $r.Backup = ''
    }

    # On a re-run, delete the entry left by the previous run first
    if ($ExistingGuid -and $ExistingGuid -match '^\{[0-9a-fA-F-]{36}\}$') {
        Write-Log "Removing the boot entry left by the previous run: $ExistingGuid"
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/delete', $ExistingGuid) -Tag 'del-old')
    }

    # Record the original bootmgr settings so the uninstaller can restore them
    $bm = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', '{bootmgr}') -Tag 'bm').Raw
    $m = [regex]::Match($bm, '(?im)^\s*timeout\s+(\d+)')
    if ($m.Success) { $r.OrigTimeout = $m.Groups[1].Value }

    # When displaybootmenu was never set in the BCD, the line is absent from /enum output entirely.
    # That must not be recorded as "the original value was No"; a separate flag OrigDisplaySet=0 is recorded instead:
    #
    #   single-system machine: never set -> never showed a menu
    #   multi-system machine:  never set -> showed the menu normally (that is how you pick a system)
    #
    # Both cases end up as "never set", so the uninstaller must use bcdedit /deletevalue to restore
    # "not set" rather than forcing No - forcing No would switch off the menu for multi-boot users.
    $r.OrigDisplay = 'No'
    $r.OrigDisplaySet = '0'
    if ($bm -match '(?im)^\s*displaybootmenu\s+(\S+)') {
        $r.OrigDisplay = $matches[1]
        $r.OrigDisplaySet = '1'
    }
    Write-Log "Original bootmgr: timeout=$($r.OrigTimeout) displaybootmenu=$($r.OrigDisplay) (explicitly written=$($r.OrigDisplaySet))"

    # Count how many systems already exist on this machine. On a multi-boot machine this install only "adds one entry";
    # no other boot entry is touched, and the menu is restored as-is after uninstalling.
    $osCount = 0
    $osRaw = ''
    try {
        $osRaw = (Invoke-BcdEdit -Store '' -BcdArgs @('/enum', 'osloader') -Tag 'oslist').Raw
        $osCount = ([regex]::Matches($osRaw, '(?m)^\s*(?:identifier|标识符)\s+\{')).Count
    } catch {}
    if ($osCount -ge 1) {
        Write-Log "The machine already has $osCount boot entries (multi-boot): this run only adds one, existing entries are left alone"
    }

    # Duplicate the boot entry of "the system running right now".
    #
    # Use {current} rather than {default}: on a multi-boot machine {default} may point at another system,
    # and duplicating it yields the wrong osdevice/path, so the new entry actually boots somebody else's system.
    # The braces must be quoted, otherwise PowerShell treats {current} as a script block.
    #
    # Point at the vhdx. The drive letter comes from the volume holding the vhdx file, the path uses bracket syntax.
    #
    # [v1.13] The full relative path is mandatory, not just the file name.
    #   D:\VirtualDisks\maimai.vhdx  ->  vhd=[D:]\VirtualDisks\maimai.vhdx
    # v1.12 wrote vhd=[D:]\maimai.vhdx while the file actually sat in a subfolder -> the menu was built, and failed to find the file on selection.
    $vhdDrive = [System.IO.Path]::GetPathRoot($VhdFullPath).Substring(0, 1).ToUpper()
    $dev = Get-VhdBcdDevice $VhdFullPath
    Write-Log "device => $dev"

    # Boot menu text (v1.11):
    #   the user gave a name -> use it (so on a machine with several systems it is obvious which one is which)
    #   no name -> fall back to "<image edition> (Virtual System)"
    # On a name clash add the drive letter, otherwise the boot menu shows two identical lines and there is no way to tell them apart.
    if ($DisplayName) {
        $desc = $DisplayName
    } elseif ($EditionName) {
        $desc = "$EditionName (Virtual System)"
    } else {
        $desc = 'Windows (Virtual System)'
    }
    if ($osRaw -and ($osRaw -match [regex]::Escape($desc))) {
        $desc = "$desc ($($vhdDrive):)"
        Write-Log "An entry with the same name exists; the description was changed to $desc so they can be told apart"
    }
    # Create the new boot entry: /copy first, /create from scratch when there is no source (BCD primary loader wiped).
    # Before v1.18 only {current} with a {default} fallback was tried, so a lost primary loader made installation impossible;
    # since v1.19, even when nothing but Recovery is left in osloader, /create builds a brand new loader.
    $nb = New-BootEntryGuid -Desc $desc
    if (-not $nb.Guid) {
        $r.Error = $nb.Error
        return $r
    }
    $guid = $nb.Guid
    $r.Guid = $guid
    Write-Log "New boot entry: $guid (source: $($nb.Tag))"

    # The device path pointing at the vhdx ($dev) was computed before duplicating the entry, so it is written directly here
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
        $r.Error = "Failed to write the boot entry parameters. Log: $($Script:LogFile)"
        return $r
    }

    # Verify: did vhd= really get written? (bcdedit can report fake success when the write is blocked)
    $chk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify'
    if ($chk.Raw -notmatch '(?i)vhd=') {
        $r.Error = "The vhd= device path was not written into the boot entry; the BCD write was blocked. $($chk.Text)"
        return $r
    }

    # [v1.13] Compare the path device points at, character by character.
    # vhd= being present but pointing elsewhere (for example a missing subfolder) is as fatal as not writing it:
    # the menu shows the entry and selection dies with 0xc000000f, file not found. It must be caught right here.
    $wantFull = [System.IO.Path]::GetFullPath($VhdFullPath)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        # [audit P1-4] Do not depend on the field label: bcdedit prints "device", "Gerät", "デバイス"
        # or "设备" depending on the host language, and a label mismatch read as "the path is wrong"
        # even though it was written correctly. The only line carrying "vhd=[" is the device line.
        $dm = [regex]::Match($chk.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
        $backFull = ''
        if ($dm.Success) { $backFull = Get-FullPathFromBcdDevice $dm.Groups[1].Value.Trim() }
        # "?" where the path has a non-ASCII character is a console display artefact, not a bad write
        if (Test-BcdTextSame $wantFull $backFull) {
            if ($backFull -ne $wantFull) {
                Write-Log ("Path read back as ""{0}"" - the console code page cannot show those characters, the store holds {1}" -f $backFull, $wantFull) 'WARN'
            }
            break
        }
        # Still different: ask the store directly, bypassing the console
        $stored = Test-BcdStoresPath $wantFull
        if ($stored -eq $true) {
            # [v1.32] This is a whole-store search (heuristic), not a check of this specific entry's
            # device element: an OLD entry pointing at the same file would also make it return true.
            Write-Log 'The console mangles the readback, and the path is present somewhere in the exported store (whole-store heuristic, not tied to this exact entry)' 'WARN'
            break
        }
        Write-Log ("Device path read back differs (attempt {0}): expected {1}, got {2}" -f $attempt, $wantFull, $backFull) 'WARN'
        if ($attempt -ge 2) {
            $r.Error = ("The boot entry points at a different file path, so it will not boot either.`n`n" +
                        "It should point at: $wantFull`nActually written: $backFull`n`n" +
                        "If ""actually written"" shows ""?"" where the path has non-ASCII characters, that is only the console code page: " +
                        "run  chcp 936  then  bcdedit /enum $guid  to see the real text.`n" +
                        "Otherwise the virtual disk was probably still mounted while the BCD was edited, and bcdedit rewrote vhd= into partition=X:.`n" +
                        "Run ""tools\Fix-Boot-Entry-Device.bat"" to retry, or reinstall into a folder without non-ASCII characters.")
            return $r
        }
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'device',   $dev) -Tag 'fixdev')
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'osdevice', $dev) -Tag 'fixosdev')
        $chk = Invoke-BcdEdit -Store '' -BcdArgs @('/enum', $guid) -Tag 'verify-retry'
    }
    # A non-ASCII description occasionally loses characters through the command line, so read it back.
    # v1.11: the criterion changed from "must contain the words Virtual System" to "must equal the $desc I wrote" -
    # a user-supplied name usually does not contain those words, and the old check misjudged good names as write failures.
    #
    # [audit P1-4] The check is now "the output contains exactly the text I wrote", not a label match:
    # the label is "description", "Beschreibung", "説明" or "描述" depending on the host language.
    $descBack = ''
    if ($chk.Raw -match [regex]::Escape($desc)) { $descBack = $desc }
    if ($descBack -ne $desc) {
        # A "?"-masked readback is a display problem; renaming a good entry to ASCII is worse
        $looseDesc = ($desc -replace '[^\x20-\x7E]', '?')
        $looseRaw = ($chk.Raw -replace '[^\x20-\x7E]', '?')
        if ($looseRaw -match [regex]::Escape($looseDesc)) {
            $descBack = $desc
            Write-Log "Description read back masked by the console code page, keeping ""$desc""" 'WARN'
        }
    }
    if ($descBack -ne $desc) {
        Write-Log "Description read back differs (expected ""$desc"", got ""$descBack""), retrying with an ASCII-only description" 'WARN'
        $asciiName = ($desc -replace '[^\x20-\x7E]', '').Trim()
        if (-not $asciiName) { $asciiName = if ($EditionName) { "$EditionName (VHD)" } else { 'Windows (VHD)' } }
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', $guid, 'description', $asciiName) -Tag 'desc-en')
        $desc = $asciiName
    }
    $r.Desc = $desc

    # The boot menu must be enabled: with timeout=0 / displaybootmenu=No the default system boots straight away and no choice is shown
    [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu')
    if ($r.OrigTimeout -eq '0') {
        [void](Invoke-BcdEdit -Store '' -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout')
        Write-Log 'Original timeout=0 changed to 10 seconds, otherwise the menu is never shown'
    }

    $r.Ok = $true
    return $r
}

function Invoke-Install {
    param(
        [string]$WimPath,
        [string]$TargetFolder,          # storage folder (full path such as D:\VHD; a bare "D" is accepted too)
        [int]$SizeGB,
        [int]$ImageIndex = 1,
        [string]$EditionName = '',      # edition name inside the image (e.g. "Windows 10 Pro")
        [string]$DiskName = '',         # the name the user gave this system (drives the vhdx file name and the menu text)
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

    # [v1.11] NewSystemDisk.vhdx is no longer hard-coded; the name comes from the user, with -2/-3 suffixes on clashes
    $safeName = Get-SafeDiskName $DiskName
    if (-not (Test-EncodableName $safeName)) {
        throw ("The name ""$safeName"" contains characters the system code page cannot encode (emoji etc.), so it cannot be used as a file name.`nUse letters, digits and common punctuation instead.")
    }
    $folderChk = Test-TargetFolder $TargetFolder
    if (-not $folderChk.Ok) { throw "Storage location unusable: $($folderChk.Msg)" }
    $targetFolder = $folderChk.Folder
    $vhdPath = Get-UniqueVhdPath -Folder $targetFolder -DiskName $safeName
    $Script:VhdFileName = [System.IO.Path]::GetFileName($vhdPath)
    Write-Log "System name: $safeName   virtual disk file: $vhdPath"
    $mounted = $false
    $osLetter = $null
    $diskNum = -1
    $espLetter = ''
    $isoDrive = ''
    $isoPath = ''
    $realImage = $WimPath
    $bcdTriesReached = $false
    $bcdOk = $false

    # [critical safety flag] Only a vhdx actually created by THIS run may be deleted on failure.
    #
    # The real incident without this flag: the target file already existed -> the preflight threw "already installed" ->
    # control fell into catch with $bcdTriesReached still false -> $keepVhd=false -> the user's
    # **already installed, possibly in-use system was wiped**, while the message still said "run the uninstaller first".
    # One accidental second click on install destroyed tens of GB of data and a whole system.
    $createdHere = $false

    try {
        # ---------- Preflight ----------
        & $report 1 'Checking the environment...'

        if (-not (Test-Admin)) {
            throw 'Administrator rights are required. Right-click this program and choose "Run as administrator".'
        }
        # [v1.32] Reject Legacy BIOS up front, before any work is done. This used to sit inside
        # Install-BootEntry, so a Legacy machine would build the whole VHDX and run DISM first, only
        # to be rejected at the very last step - wasting minutes and leaving a half-built disk behind.
        if ((Get-FirmwareType) -ne 2) {
            throw 'This machine boots in Legacy BIOS mode. Native-boot VHD uses the UEFI boot path (winload.efi) and cannot start from a Legacy BIOS.`n`nPlease enable UEFI boot in the firmware settings (with CSM disabled), or use this tool on a UEFI machine.'
        }
        if (Test-Path -LiteralPath $vhdPath) {
            throw "Already installed once.`nThe target file already exists: $vhdPath`n`nRun the uninstaller first, or delete that file manually."
        }

        # ---------- Resolve the image (an ISO must be mounted first) ----------
        $ri = Resolve-RealImage -Path $WimPath
        if (-not $ri.Ok) { throw $ri.Error }
        $realImage = $ri.Path
        $isoDrive = $ri.IsoDrive
        $isoPath = $ri.IsoPath
        Write-Log "Image format: $($ri.Kind)  real file: $realImage"
        if ($ri.Kind -eq 'ISO') { Write-Log "ISO mounted at $isoDrive`:" }

        $cap = Test-VhdCapability
        if (-not $cap.Ok) { throw $cap.Reason }
        Write-Log "Virtual disk method: $($cap.Mode)"

        $needBytes = [int64]$SizeGB * 1GB
        # Use the same judgement as the UI (largest of three sources + a real write test), do not trust Get-Volume again here
        $freeB = Get-DiskFreeBytes $targetFolder
        Write-Log ("Preflight space: reported free {0}, required {1}" -f (Format-Size $freeB), (Format-Size ($needBytes + 5GB)))
        if ($freeB -lt ($needBytes + 5GB)) {
            $wchk = Test-FolderWritable -Folder $targetFolder -ProbeMB 64
            if (-not $wchk.Ok) {
                throw ("Not enough space. Folder {0}: reported free {1}, required {2}. Real write test: {3}" -f `
                       $targetFolder, (Format-Size $freeB), (Format-Size ($needBytes + 5GB)), $wchk.Msg)
            }
            Write-Log "The reported value is low but the write test passed, continuing" 'WARN'
        }

        # ---------- Create the virtual disk ----------
        & $report 3 ("Creating a {0} GB virtual disk..." -f $SizeGB)
        Write-Log "VHDX $vhdPath SizeMB=$([int]($needBytes / 1MB))"

        $diskNum = -1
        $hasHyperV = [bool](Get-Command New-VHD -EA SilentlyContinue)

        if ($hasHyperV) {
            # Prefer the Hyper-V module (it returns DiskNumber directly, which is the least work)
            try {
                $null = New-VHD -Path $vhdPath -SizeBytes $needBytes -Dynamic -EA Stop
                $createdHere = $true
                $h = Mount-VHD -Path $vhdPath -Passthru -EA Stop
                $mounted = $true
                Start-Sleep -Milliseconds 900
                $diskNum = $h.DiskNumber
                Write-Log "Hyper-V module path, DiskNumber=$diskNum"
            } catch {
                Write-Log "Hyper-V path failed, switching to diskpart: $($_.Exception.Message)" 'WARN'
                $diskNum = -1
            }
        }

        if ($diskNum -lt 0) {
            # Fallback: diskpart's native create vdisk, no Hyper-V module required
            & $report 3 'Creating the virtual disk with diskpart...'
            $dp = Invoke-Diskpart -Tag 'mk' -Lines @(
                "create vdisk file=`"$vhdPath`" maximum=$([int]($needBytes / 1MB)) type=expandable",
                "select vdisk file=`"$vhdPath`"",
                'attach vdisk',
                'exit'
            )
            Write-Log "diskpart create+attach: $($dp.Text)"

            if (-not (Test-Path -LiteralPath $vhdPath)) {
                # The file does not even exist: report diskpart's own words, do not guess
                $hint = ''
                if (-not $dp.Ok) { $hint = "`n`ndiskpart said: $($dp.Error)" }
                throw ("Failed to create the virtual disk, the file was never created.`n`nTarget path: $vhdPath$hint")
            }
            # Reaching here means this process just created the file (the preflight already rejected an existing one)
            $createdHere = $true
            if (-not $dp.Ok) {
                # The file was created but a later command failed -> do not panic, first check whether it is already attached
                Write-Log "diskpart reported an error, still trying to identify the disk: $($dp.Error)" 'WARN'
            }
            $mounted = $true
            Start-Sleep -Milliseconds 1500

            # Find the disk that was just attached among all disks.
            #
            # Order of tests (each one is far safer than guessing by capacity):
            #   1. BusType = 'File Backed Virtual' - the bus type only a mounted vhdx/vhd has;
            #      a physical disk (NVMe / SATA / SAS / USB) can never report it. This is the hardest evidence.
            #   2. Location contains the vhdx file name - a fallback for systems that report BusType badly.
            #   3. Exactly one virtual disk in the system -> that must be the one just attached.
            #
            # [removed] There used to be a fourth fallback: "capacity within 64 MB of the target and not the system disk".
            #   That was a catastrophic design: the very next step is select disk + clean, so any machine that happened
            #   to have a disk of the same size (a small SSD, a USB stick, another VHD of the user's) plus a failed
            #   Location match would have had that disk's partition table wiped. Fail with a log instead, never guess.
            $allDisks = @(Get-Disk -EA SilentlyContinue)
            $vhdDisks = @($allDisks | Where-Object { ([string]$_.BusType) -eq 'File Backed Virtual' })

            $hit = Resolve-VhdDisk -VhdPath $vhdPath -Disks $vhdDisks
            if (-not $hit) { $hit = Resolve-VhdDisk -VhdPath $vhdPath -Disks $allDisks }
            if ($hit) {
                $diskNum = $hit.Number
                Write-Log "Matched Disk$diskNum by full path ($($hit.Location))"
            }
            if ($diskNum -lt 0 -and $vhdDisks.Count -eq 1) {
                # Last resort: exactly one file-backed virtual disk exists. Accept it only when it does not
                # point at some other vhdx file - otherwise it belongs to another tool (Hyper-V, backup) and
                # must never be cleaned.
                $only = $vhdDisks[0]
                $onlyLoc = [string]$only.Location
                if ($onlyLoc) {
                    if ($onlyLoc.StartsWith('\\?\')) { $onlyLoc = $onlyLoc.Substring(4) }
                    $wantFull = [System.IO.Path]::GetFullPath($vhdPath)
                    if ([System.IO.Path]::GetFileName($onlyLoc) -ne [System.IO.Path]::GetFileName($wantFull)) {
                        throw ("The only mounted virtual disk (Disk{0}) comes from`n    {1}`nwhich is not the file this install created:`n    {2}`n`nNothing was touched." -f
                               $only.Number, $onlyLoc, $wantFull)
                    }
                }
                $diskNum = $only.Number
                Write-Log "Only one virtual disk in the system, assuming Disk$diskNum"
            }

            if ($diskNum -lt 0) {
                $list = ($allDisks | ForEach-Object {
                    "  Disk {0}: {1}  BusType={2}  Location={3}" -f $_.Number, $_.FriendlyName, $_.BusType, $_.Location
                }) -join "`n"
                throw ("The virtual disk was created and attached, but its disk number could not be determined.`n`n" +
                       "To avoid wiping another disk's partition table, nothing is guessed by capacity here.`n`n" +
                       "All current disks:`n$list`n`n" +
                       "Reboot and try again; if this keeps happening, send the log to the developer.`n" +
                       "Log: $($Script:LogFile)")
            }
            Write-Log "diskpart path, DiskNumber=$diskNum"
        }

        if ($diskNum -lt 0) { throw 'The virtual disk file was created, but the system did not pick up the disk (attach probably failed). Reboot and try again.' }
        Write-Log "Virtual disk number: $diskNum"

        # ---------- Partitioning ----------
        & $report 9 'Initializing the disk and creating a partition...'

        # [Create exactly one partition, never an ESP]
        #
        # This is the core v1.4 fix. Booting a virtual disk (native boot) strictly requires:
        # exactly one partition inside the virtual disk, which bootmgr treats as the boot partition.
        #
        # Up to v1.3 two partitions were created ("ESP + system"), which meant:
        #   * bcdboot wrote the boot files into the ESP inside the vhdx - UEFI firmware only reads the ESP
        #     on the physical disk, never looks inside a vhdx, so the new system never appeared in the boot menu.
        #   * and with several partitions in the vhdx, bootmgr locating it via vhd= is likely to land on the first
        #     partition (that empty ESP), so even a correct BCD entry would not boot.
        #
        # The boot entry now lives in the "active BCD store" (see the boot section below) and the vhdx
        # carries nothing but the system partition.
        # -- [v1.8 fix] A single partition can only be guaranteed with PowerShell's native partition cmdlets --
        #
        # The log of the 2026-11-04 12:00 install showed "virtual disk partition count: 2".
        # Cause: diskpart's clean -> convert gpt -> create partition primary
        # automatically inserts a 16 MB MSR (Reserved) partition into the GPT, resulting in
        #   partition 1 = Reserved(MSR)   partition 2 = system partition
        # bootmgr locating the disk via vhd= takes the "first partition", i.e. that empty
        # MSR partition, so of course no system is found at boot.
        #
        # Initialize-Disk only writes the GPT header and creates no MSR; New-Partition creates a single data partition.
        # clean is still delegated to diskpart (that path is verified working).
        # [audit P0-1] Last gate before "clean", the single most destructive command in this program.
        # If the disk reports which file it comes from, that file must be ours. A mismatch means the earlier
        # match went wrong, and cleaning would destroy an unrelated disk's partition table.
        if (-not $createdHere) {
            throw "Refusing to clean Disk$($diskNum): this run did not create that file."
        }
        $guardDisk = $null
        try { $guardDisk = Get-Disk -Number $diskNum -EA Stop } catch {}
        if ($guardDisk) {
            $gl = [string]$guardDisk.Location
            if ($gl) {
                if ($gl.StartsWith('\\?\')) { $gl = $gl.Substring(4) }
                $wantFull = [System.IO.Path]::GetFullPath($vhdPath)
                if (-not [string]::Equals($gl.Trim(), $wantFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw ("Refusing to clean Disk{0}.`n`nThat disk reports its file as:`n    {1}`nbut this install created:`n    {2}`n`nNothing was deleted. Another virtual disk with the same file name is probably mounted - remove it and try again." -f $diskNum, $gl, $wantFull)
                }
            }
            $bt = [string]$guardDisk.BusType
            if ($bt -and ($bt -notin @('File Backed Virtual', 'Virtual', 'Unknown'))) {
                throw ("Refusing to clean Disk{0}: its bus type is '{1}', which is not a virtual disk." -f $diskNum, $bt)
            }
        }

        $dp = Invoke-Diskpart -Tag 'vhd' -Lines @(
            "select disk $diskNum",
            'clean',
            'exit'
        )
        Write-Log "diskpart clean: $($dp.Text)"
        if (-not $dp.Ok) { throw "Failed to clean the virtual disk:`n`n$($dp.Text)" }

        try {
            Initialize-Disk -Number $diskNum -PartitionStyle GPT -Confirm:$false -EA Stop | Out-Null
        } catch {
            throw "Failed to initialize the virtual disk as GPT: $($_.Exception.Message)"
        }

        $newPart = $null
        try {
            $newPart = New-Partition -DiskNumber $diskNum -UseMaximumSize -AssignDriveLetter -EA Stop
        } catch {
            throw "Failed to create the partition on the virtual disk: $($_.Exception.Message)"
        }
        try {
            Format-Volume -Partition $newPart -FileSystem NTFS -NewFileSystemLabel 'NewSystem' `
                          -Confirm:$false -Force -EA Stop | Out-Null
        } catch {
            throw "Failed to format the new partition: $($_.Exception.Message)"
        }
        Write-Log "Single NTFS partition created (PartitionNumber=$($newPart.PartitionNumber))"

        # Find the drive letter of the new partition
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
            # New-Partition occasionally assigns no drive letter, so assign one
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
            throw 'The partition is ready but no drive letter could be assigned, please retry.'
        }
        Write-Log "System partition drive letter: $osLetter"

        $partCount = @($parts).Count
        Write-Log "Virtual disk partition count: $partCount (native boot requires 1)"

        # Safety net: if an MSR (Reserved) partition still shows up in some environments, delete it on the spot and re-check.
        # An MSR is an ordinary reserved partition; deleting it loses no data (it holds no filesystem).
        if ($partCount -gt 1) {
            $msrGuid = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
            foreach ($p in @($parts)) {
                $isMsr = ([string]$p.Type -eq 'Reserved') -or (([string]$p.GptType).ToLower() -eq $msrGuid)
                if (-not $isMsr) { continue }
                Write-Log "Found an MSR reserved partition (PartitionNumber=$($p.PartitionNumber)), deleting it" 'WARN'
                try {
                    Remove-Partition -DiskNumber $diskNum -PartitionNumber $p.PartitionNumber -Confirm:$false -EA Stop
                } catch {
                    Write-Log "Failed to delete the MSR: $($_.Exception.Message)" 'WARN'
                }
            }
            Start-Sleep -Milliseconds 1000
            $parts = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
            $partCount = @($parts).Count
            Write-Log "Partition count after cleanup: $partCount"
        }

        if ($partCount -ne 1) {
            # v1.8: this used to log a WARN only, so the machine failed to boot 20 minutes later, after the whole install.
            # Now it fails and cleans up immediately, so the problem surfaces within a minute instead of wasting a full install.
            throw ("The virtual disk ended up with $partCount partitions while native boot requires exactly 1.`n`n" +
                   "The extra one is usually the 16 MB MSR (Reserved) partition - bootmgr lands on it when locating a vhd=,`n" +
                   "so after a reboot the boot menu either has no new system, or booting it fails.`n`n" +
                   "Log: $($Script:LogFile)")
        }

        # ---------- Apply the image ----------
        & $report 12 'Restoring system files (the slowest step)...'

        # Index 1 of an official image is sometimes WinPE / Windows Setup, which installs something unusable, so skip it automatically
        $pick = Select-ImageIndex -Path $realImage -Preferred $ImageIndex
        if ($pick -ne $ImageIndex) {
            Write-Log "Index $ImageIndex is not an installable system, switching to index $pick"
            $ImageIndex = $pick
        }

        Write-Log "DISM /Apply-Image index=$ImageIndex => $osLetter`:\"

        # ---------- [v1.8 rewrite] DISM output goes to a file, the main thread polls ----------
        #
        # v1.7 read Process StandardOutput character by character, which deadlocks in practice:
        #   Peek() can return -1 (instead of blocking) while the pipe momentarily has no data, and the process is still alive,
        #   so the script falls into an endless "sleep 100ms -> continue" spin and never reads the pipe again;
        #   once DISM's stdout buffer (~4KB) fills up it blocks for good, and both sides wait forever -
        #   measured on 2026-11-04 12:04: it stopped at 11.75GB written with CPU time frozen at 51.72s.
        #
        # Now Start-Process redirects stdout/stderr straight into temp files:
        #   * a file has no fixed-size buffer, so DISM never blocks waiting for a reader;
        #   * the main thread polls the file and the used space of the target disk every 0.8 seconds and calls $report to refresh the UI
        #     ($report pumps DoEvents internally, so the window does not freeze);
        #   * even if DISM prints nothing at all, the "written X.X GB" heartbeat shows it is moving.
        $dismOut = Join-Path $env:TEMP ("dism_apply_{0}.log" -f $PID)
        $dismErr = Join-Path $env:TEMP ("dism_apply_{0}.err" -f $PID)
        foreach ($tf in @($dismOut, $dismErr)) {
            try { if (Test-Path -LiteralPath $tf) { Remove-Item -LiteralPath $tf -Force -EA SilentlyContinue } } catch {}
        }

        # /CheckIntegrity dropped: the manifest was already read when the image was picked, and verifying again for the whole
        # apply makes this step 20-30% slower while it cannot rescue a corrupt wim (Apply would fail the same way).
        $dismArgs = '/English /Apply-Image /ImageFile:"{0}" /Index:{1} /ApplyDir:{2}:\' -f $realImage, $ImageIndex, $osLetter
        Write-Log "DISM arguments: $dismArgs"

        $proc = $null
        try {
            $proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
                        -RedirectStandardOutput $dismOut -RedirectStandardError $dismErr `
                        -NoNewWindow -PassThru -EA Stop
        } catch {
            throw "Cannot start DISM: $($_.Exception.Message)"
        }

        # Heartbeat baseline: how much the target partition currently uses
        $baseUsed = 0
        $volNow = Get-Volume -DriveLetter $osLetter -EA SilentlyContinue
        if ($volNow) { $baseUsed = [double]($volNow.Size - $volNow.SizeRemaining) }
        Write-Log ("Partition in use before writing: {0:N2} GB" -f ($baseUsed / 1GB))

        $lastPct     = 12
        $lastBeatMs  = 0
        $lastGrowMs  = 0
        $lastOutMs   = 0
        $lastOutLen  = -1
        $lastUsedGB  = -1
        # Declare a stall only after 10 minutes with "no DISM output growth and no target growth".
        # Why not 4 minutes: right after starting, DISM only unpacks the WIM metadata and writes not a single byte to the target;
        # on a slow disk with real-time AV scanning, just reaching "start writing files" can take minutes,
        # so a 4-minute rule would kill healthy installs (especially with a 20 GB image).
        # Two signals together are actually safer: a genuine stall moves neither, which allows a looser threshold.
        $guardMs     = 600000
        $swLoop      = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 800

            # 1) Read the DISM output file and take the latest percentage
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

            # 2) Output file heartbeat: as long as DISM keeps writing to its log, it is alive.
            #    The file length is what matters, not the content - the percentage can sit on one number for a long time.
            $outLen = -1
            try { $outLen = (Get-Item -LiteralPath $dismOut -EA Stop).Length } catch {}
            if ($outLen -ne $lastOutLen) {
                $lastOutLen = $outLen
                $lastOutMs = $swLoop.ElapsedMilliseconds
            }

            # 3) Used-space heartbeat (the real "not stuck" evidence)
            $volNow = Get-Volume -DriveLetter $osLetter -EA SilentlyContinue
            $usedGB = $lastUsedGB
            if ($volNow) {
                $usedGB = [math]::Round((($volNow.Size - $volNow.SizeRemaining) / 1GB), 2)
                if ($usedGB -ne $lastUsedGB) { $lastUsedGB = $usedGB; $lastGrowMs = $swLoop.ElapsedMilliseconds }
            }

            # 4) Refresh the UI
            if ($pct -ge 0) {
                $overall = [int](12 + $pct * 0.74)
                if ($overall -gt $lastPct) { $lastPct = $overall }
            }
            if (($swLoop.ElapsedMilliseconds - $lastBeatMs) -ge 3000) {
                $lastBeatMs = $swLoop.ElapsedMilliseconds
                $msg = 'Restoring system files'
                if ($pct -ge 0)   { $msg += ('  {0:N0}%' -f $pct) }
                if ($usedGB -ge 0) { $msg += ('   written {0:N1} GB' -f $usedGB) }
                & $report $lastPct $msg
            }

            # 5) Watchdog: only when output AND target are **both** frozen is it a stall
            $aliveMs = [Math]::Max($lastGrowMs, $lastOutMs)
            if (($swLoop.ElapsedMilliseconds - $aliveMs) -ge $guardMs) {
                try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
                Write-Log ("DISM made no progress for 10 minutes (output stuck at {0} bytes, target no longer growing), forced termination" -f $lastOutLen) 'WARN'
                $stuckMsg = "Stalled while restoring system files:" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "DISM produced no new output and wrote no new data to the target for 10 minutes, so this install was aborted automatically." + [char]13 + [char]10 + [char]13 + [char]10 +
                            "Common causes:" + [char]13 + [char]10 +
                            "  - the disk holding the virtual disk is responding abnormally" + [char]13 + [char]10 +
                            "  - antivirus / security suite is scanning the files being written in real time" + [char]13 + [char]10 +
                            "  - the image file itself is corrupt" + [char]13 + [char]10 + [char]13 + [char]10 +
                            "Suggestion: turn off real-time protection and retry, or create the virtual disk on another physical disk." + [char]13 + [char]10 + [char]13 + [char]10 +
                            "Log: " + $Script:LogFile
                throw $stuckMsg
            }
        }

        $proc.WaitForExit()

        $errOut = ''
        $tailText = ''
        try { if (Test-Path -LiteralPath $dismErr) { $errOut = [IO.File]::ReadAllText($dismErr, [Text.Encoding]::Default) } } catch {}
        try { if (Test-Path -LiteralPath $dismOut) { $tailText = [IO.File]::ReadAllText($dismOut, [Text.Encoding]::Default) } } catch {}

        # Start-Process -PassThru often reports ExitCode as $null once the process has exited
        # (the handle has been released internally). So a fact-based fallback is prepared here:
        # whether the kernel file exists plus whether DISM printed its success line is more trustworthy than one number.
        $dismCode = $null
        try { $dismCode = $proc.ExitCode } catch { $dismCode = $null }
        if ($null -eq $dismCode) { Write-Log 'DISM exit code: not available (judging by files and output instead)' }
        else { Write-Log "DISM exit code: $dismCode" }

        $tail = @()
        if ($tailText) {
            $tail = @($tailText -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 20)
            Write-Log ("DISM tail: " + ($tail -join ' | '))
        }

        $hasKernel = Test-Path -LiteralPath "$($osLetter):\Windows\System32\ntoskrnl.exe"
        $okText    = ($tailText -match 'completed successfully|operation completed')

        if (($null -ne $dismCode) -and ($dismCode -ne 0)) {
            throw ("Failed to restore the system files (DISM returned {0})`n`n{1}`n`n{2}" -f $dismCode, $errOut, ($tail -join "`n"))
        }
        if (($null -eq $dismCode) -and (-not $hasKernel) -and (-not $okText)) {
            throw ("Failed to restore the system files (no DISM exit code and no success text)`n`n{0}`n`n{1}" -f $errOut, ($tail -join "`n"))
        }

        if (-not $hasKernel) {
            throw 'No system kernel found after restoring; the image may be incomplete.'
        }

        # ---------- No more "offline network driver injection" here (removed in v1.26) ----------
        #
        # The original code used DISM /Add-Driver in this section to inject the host's network drivers into the freshly applied image.
        # After gathering evidence on 2026-11-05 it turned out never to have worked, so the whole block was deleted:
        #
        #   1) The host is Windows 11 while the installed images were Win10 19041 / Server 2022.
        #      The exported driver package is W11-only (the Killer one is literally named e5xw11x64.inf),
        #      and its NTamd64 decorations and signatures do not match the target build, so first-boot PnP rejects it outright.
        #   2) Evidence: at 23:33 DISM reported "successfully installed" for all 8 packages,
        #      yet after first boot at 23:53 Device Manager still had no driver for "Network Controller" /
        #      "Ethernet Controller" (two [Error] entries in the diagnostic report). It was finally fixed by
        #      "Diagnose and install drivers" installing online from E:\NewSystemDriver - and WiFi used the
        #      _win10_wifi package from there, which proves the injected copy was never used.
        #
        # Conclusion: cross-version injection is 30 seconds of waiting plus log noise, and it misleads people into thinking "network works right after install".
        # The right way: after installing, boot the new system and run tools\Diagnose-And-Install-Drivers.bat,
        # which runs pnputil /add-driver /install + /scan-devices online and reports a clear result either way.
        # To really carry drivers over during installation, the image build must equal the host build; revisit only then.
        # ---------- [v1.21] Pre-seed a first-boot script that mounts the original system partition ----------
        #
        # On a single-partition machine (original C: = system + boot + data in one, vhdx also on C:), after booting the new system
        # the original C: becomes a "system partition" - a Windows rule: when the system partition and the boot volume differ,
        # the system partition gets no drive letter by default (same treatment as System Reserved). The user then cannot see
        # the original C: in the new system, and neither their files nor the toolkit can be reached.
        #
        # Fix: write a SetupComplete.cmd into the new system (Microsoft's official first-boot hook, runs once as SYSTEM
        # at the end of setup), which calls mount-host.ps1 generated from the "disk signature/UniqueId + partition
        # offset" recorded at install time: it finds the host partition and, if it has no letter, assigns the first free letter from D: up.
        # Any failing step only writes a log entry and exits; booting is never blocked.
        try {
            $hostDrive = ((Split-Path -Path $vhdPath -Qualifier) -replace ':', '')
            $hostPart = Get-Partition -DriveLetter $hostDrive -EA Stop
            $hostDisk = Get-Disk -Number $hostPart.DiskNumber -EA Stop

            $scriptsDir = Join-Path "$($osLetter):\" 'Windows\Setup\Scripts'
            [void][System.IO.Directory]::CreateDirectory($scriptsDir)

            $hostUid = [string]$hostDisk.UniqueId
            $hostSig = [int64]$hostDisk.Signature
            $hostOff = [int64]$hostPart.Offset
            Write-Log ("Host partition: disk {0} (Signature={1}, UniqueId={2}) offset {3}" -f $hostDisk.Number, $hostSig, $hostUid, $hostOff)

            $mountPs = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$log = Join-Path `$env:SystemRoot 'Temp\mount-host.log'
function Log(`$m) { try { Add-Content -LiteralPath `$log -Value ((Get-Date -Format s) + ' ' + `$m) } catch {} }
Log 'mount-host start (v$($Script:Version))'
# GPT matches exactly on UniqueId; MBR falls back to Signature (skipped when the signature is 0, to avoid matching another GPT disk)
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
            Write-Log 'First-boot script pre-seeded: the new system will assign a drive letter to the original system partition after its first boot (first free letter from D: up)'
        } catch {
            Write-Log "Failed to pre-seed the first-boot mount script (does not affect the install; assign a letter manually in Disk Management afterwards): $($_.Exception.Message)" 'WARN'
        }

        # ---------- Boot ----------
        & $report 96 'Configuring the boot menu...'
        $fw = Get-FirmwareType
        Write-Log "Firmware type: $fw"

        # The system partition must be the "first partition" of the vhdx, otherwise bootmgr locating it via vhd=
        # lands elsewhere (one of the reasons v1.3 with several partitions would not boot).
        $osPartNo = $null
        foreach ($p in (Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)) {
            if ([string]$p.DriveLetter -eq [string]$osLetter) { $osPartNo = [int]$p.PartitionNumber; break }
        }
        # [v1.9.1 fix] This used to compare the partition *number* with 1, but GPT does not renumber after the MSR is
        # deleted, so the system partition stays number 2 - which logged a "boot will probably fail" WARN after every
        # install, a pure false alarm. What actually matters is the *total* partition count.
        $partNow = @(Get-Partition -DiskNumber $diskNum -EA SilentlyContinue)
        Write-Log "System partition number: $osPartNo, total partitions: $($partNow.Count) (native boot requires a total of 1)"
        if ($partNow.Count -ne 1) {
            Write-Log "The vhdx has $($partNow.Count) partitions, boot will probably fail" 'WARN'
        }

        # ---------- [critical] Dismount the vhdx BEFORE registering the boot entry ----------
        #
        # Measured (the 19:48 run of the repair tool): with the vhdx mounted, bcdedit /set device vhd=[...]
        # returns "operation completed successfully", but reading it back shows device was written as partition=X: of the internal volume -
        # when bcdedit parses vhd= and finds the virtual disk still attached, it resolves it to that volume.
        # Writing after dismounting is mandatory for vhd= to land in the BCD verbatim.
        & $report 97 'Dismounting the virtual disk...'
        try {
            Dismount-VhdSafe -Path $vhdPath
            $mounted = $false
            Write-Log 'vhdx dismounted (bcdedit requires the vhd= device to be written while it is not mounted)'
        } catch {
            Write-Log "Failed to dismount the vhdx: $($_.Exception.Message)" 'WARN'
        }

        # [v1.32] Write a PROVISIONAL state file BEFORE the boot entry step. If bcdedit is so broken
        # that neither /copy nor /create produces a GUID (the worst case - exactly when Repair is most
        # needed), the old code wrote no state file at all and Repair refused to touch the disk. This
        # marker proves "this program created this disk, files are applied, the entry is still missing",
        # so the repair tools can find and fix it. It is overwritten by the full state below on success.
        $statePath = [System.IO.Path]::ChangeExtension($vhdPath, '.boot.txt')
        try {
            $provisional = @(
                "# $($Script:ProductName) - provisional state (files applied, boot entry not yet registered)",
                "Status=FilesApplied",
                "Version=$($Script:Version)",
                "Name=$safeName",
                "VhdPath=$vhdPath",
                "Guid=",
                "Created=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
            )
            [System.IO.File]::WriteAllLines($statePath, $provisional, (New-Object System.Text.UTF8Encoding $false))
            Write-Log "Provisional state file written (so repair tools can find this disk even if the boot entry step fails): $statePath"
        } catch {
            Write-Log "Could not write the provisional state file: $($_.Exception.Message)" 'WARN'
        }

        # [v1.32] Set the flag BEFORE the call. If Install-BootEntry throws (instead of returning),
        # the catch must still know we reached the BCD stage, so it keeps the VHDX instead of deleting
        # it and leaving a .boot.txt that points at a removed file.
        $bcdTriesReached = $true
        $be = Install-BootEntry -VhdFullPath $vhdPath -EditionName $EditionName -DisplayName $safeName
        $bcdOk = [bool]$be.Ok
        $espLetter = $be.EspLetter

        if (-not $be.Ok) {
            # [recovery] Keep a state file even here. The virtual disk is complete, and the repair
            # tools find a system only through this file - without it, the advice below ("run
            # Repair-Boot-Menu") ends in "no virtual system installed by this toolkit was found".
            if ($be.Guid) {
                $partialPath = [System.IO.Path]::ChangeExtension($vhdPath, '.boot.txt')
                try {
                    $pl = @(
                        "# $($Script:ProductName) - partial state (the boot entry step failed, the disk itself is complete)",
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
                    Write-Log "Partial state file written so the repair tools can find this disk: $partialPath" 'WARN'
                } catch {
                    Write-Log "Could not write the partial state file: $($_.Exception.Message)" 'WARN'
                }
            }
            throw ("Failed to configure the boot menu.`n`n" +
                   "The system files are fully written into the virtual disk (DISM succeeded); only the last step, registering the boot entry, failed.`n`n" +
                   "Reason: $($be.Error)`n`n" +
                   "What you can try:`n" +
                   "  1. Turn off antivirus temporarily and rerun (some block bcdedit writes to the boot store)`n" +
                   "  2. Run  bcdedit /enum  in an administrator console and confirm the existing BCD is not broken`n" +
                   "  3. Log: $($Script:LogFile)")
        }
        Write-Log "Boot entry registered: $($be.Guid)"

        # Write the state file; both the uninstaller and the repair tool need it
        $statePath = [System.IO.Path]::ChangeExtension($vhdPath, '.boot.txt')
        try {
            $lines = @(
                "# $($Script:ProductName) - boot entry state (needed by the uninstaller, do not delete)",
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
            Write-Log "State file: $statePath"
        } catch {
            Write-Log "Failed to write the state file (booting still works, but the entry must be removed by hand when uninstalling): $($_.Exception.Message)" 'WARN'
        }

        # Clean up the junk folder C:\EFI left behind by historical versions
        #
        # [v1.31 critical fix] This used to be @('C:\EFI', 'C:\Boot'), deleting both.
        # C:\Boot is the Windows system boot folder - BCD / BCD.LOG / bootvhd.dll /
        # BOOTSTAT.DAT all live there. Delete it and BIOS/MBR boot fails outright, and it also removes
        # the transaction logs of the active BCD. The only release condition was "created less than 48 hours ago", yet
        # Windows Update, installing a system or repairing the boot all recreate this folder - so it could delete
        # system files at any time. **C:\Boot is off limits from now on, do not add it back to the list below.**
        #
        # C:\EFI is the real junk (UEFI only reads \EFI on the ESP, never this one on C:). But it must not be
        # deleted recursively on sight either: rEFInd / OpenCore / Clover use it as their own folder. Three conditions
        # must all hold before deleting: created within 48 hours, subfolders limited to Microsoft/Boot, and no BCD or bootmgfw.efi inside.
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
        & $report 99 'Cleaning up...'

        Release-EspLetter -Letter $espLetter
        $espLetter = ''

        Dismount-VhdSafe -Path $vhdPath
        $mounted = $false

        & $report 100 'Installation complete'
        Write-Log "Installation complete: $vhdPath"

        return [PSCustomObject]@{ Ok = $true; VhdPath = $vhdPath; Drive = $DriveLetter; Folder = $targetFolder }

    } catch {
        $msg = $_.Exception.Message
        Write-Log "Failed: $msg" 'ERROR'

        # Roll back. But do not delete when "the system files are installed and only the boot entry is missing":
        # DISM ran for a dozen minutes (20GB image), deleting it throws all of that away, and a rerun hits the same error.
        $keepVhd = ($bcdTriesReached -and -not $bcdOk)
        if ($keepVhd) {
            Write-Log "System files are fully written; keeping the virtual disk so the boot entry can be registered later: $vhdPath" 'WARN'
        }

        try {
            if ($mounted) { Dismount-VhdSafe -Path $vhdPath }
        } catch {}
        Release-EspLetter -Letter $espLetter

        # [double protection] Delete only when both conditions hold:
        #   1. this is not the "system installed, only the boot entry missing" case ($keepVhd)
        #   2. the file really was created by **this run** ($createdHere)
        # Missing either one can delete the user's existing system or tens of GB of valid installation work.
        if (-not $keepVhd -and $createdHere) {
            try {
                if (Test-Path -LiteralPath $vhdPath) { Remove-Item -LiteralPath $vhdPath -Force -EA SilentlyContinue }
            } catch {}
        }

        if ($keepVhd) {
            throw ("$msg`n`n" +
                   "[NOTE] The system files are fully written into the virtual disk, so it was not deleted this time.`n" +
                   "File location: $vhdPath`n`n" +
                   "You can run just the 'register the boot entry' step instead of reinstalling:`n" +
                   "  open Start.bat and choose 8 (Repair boot menu), or run tools\Repair-Boot-Menu.bat`n" +
                   "  (it finds this virtual disk by itself, whatever the name or folder)`n`n" +
                   "If it still fails, turn off antivirus temporarily and rerun the whole thing.`n" +
                   "Log: $($Script:LogFile)")
        }
        throw $msg
    } finally {
        # The ISO must be dismounted whether it succeeded or failed, otherwise the optical drive letter stays occupied
        if ($isoDrive) {
            try { Close-IsoImage -Drive $isoDrive -IsoPath $isoPath } catch {}
            Write-Log "ISO dismounted ($isoDrive`:)"
        }
    }
}

# ============================================================
# Console mode
# ============================================================

if ($ConsoleMode) {
    $out = @()
    $out += "$($Script:ProductName) v$($Script:Version)"
    $out += 'Administrator: ' + (Test-Admin)
    $out += 'Firmware: ' + $(switch (Get-FirmwareType) { 2 { 'UEFI' } 1 { 'Legacy BIOS' } default { 'unknown' } })
    $out += ''
    $out += 'Usable partitions:'
    foreach ($v in (Get-TargetVolumes)) {
        $tag = ''
        if ($v.Label) { $tag = "[$($v.Label)]" }
        if ($v.IsSystem) { $tag += '(system drive)' }
        $out += ('  {0}: {1} free / {2} total {3}' -f $v.Letter, $v.FreeGB, $v.TotalGB, $tag)
    }
    $out += ''
    # When -SearchRoot is not given explicitly (the usual double-click), "the program folder / its parent / Desktop / Downloads"
    # must be added too. Passing only $SearchRoot ignored OriginDir entirely -> "none" even with the wim sitting right next to it.
    $rootsArg = $SearchRoot
    if (-not $rootsArg) {
        $guess = @()
        if ($Script:OriginDir) { $guess += $Script:OriginDir }
        if ($PSScriptRoot) { $guess += $PSScriptRoot }
        $rootsArg = ($guess | Select-Object -Unique) -join ','
    }
    $out += 'Images found:'
    $wims = Find-WimFiles -Roots $rootsArg
    if (-not $wims) {
        $out += '  (none)'
    } else {
        foreach ($w in $wims) {
            $info = Test-WimFile -Path $w
            $out += "  $w"
            # On failure, do not print noise such as "0 GB after unpacking" that looks like an error
            if ($info.Valid) {
                $out += ('    Valid=True  {0}  {1}  file {2} GB  about {3} GB installed' -f $info.Name, $info.Build, $info.SizeGB, $info.UncompGB)
                # List every index of a multi-edition image (the UI can pick one; the console should at least show them)
                if ($info.Images -gt 1) {
                    foreach ($e in @($info.IndexList)) {
                        $out += ('      index {0}: {1}' -f $e.Index, (Format-EditionLabel -Name $e.Name -Desc $e.Desc))
                    }
                }
            } else {
                $out += ('    Valid=False  {0}' -f $info.Error)
            }
        }
    }
    # Diagnostic output for the caller
    $diagPath = Join-Path $Script:TempDir 'console-report.txt'
    $out -join "`r`n" | Set-Content -LiteralPath $diagPath -Encoding UTF8
    Write-Host ($out -join "`r`n")
    exit 0
}

# ============================================================
# Entry point
# ============================================================

Write-Log "Starting v$($Script:Version)  admin=$(Test-Admin)"

if (-not (Test-Admin)) {
    # Self-elevation
    try {
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
        if ($SearchRoot) { $argList += @('-SearchRoot', "`"$SearchRoot`"") }
        if ($TargetDrive) { $argList += @('-TargetDrive', $TargetDrive) }
        if ($SizeGB -gt 0) { $argList += @('-SizeGB', $SizeGB) }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host 'Administrator rights are required to install a system. Right-click this file, choose "Run as administrator" and retry.' -ForegroundColor Yellow
        Write-Host ''
        Read-Host 'Press Enter to exit'
        exit 1
    }
}

# All dialogs go through here; parameters use strongly typed enums instead of strings.
#
# Lesson 1: a string such as 'DefaultButton1' passes the PowerShell parser,
#   and only fails when MessageBox.Show binds it, throwing
#   "Cannot convert 'DefaultButton1' to 'MessageBoxDefaultButton'".
#   The correct values are Button1 / Button2 / Button3 (no Default prefix).
#   With a typed parameter a wrong enum name fails at the call site instead of at runtime.
#
# Lesson 2: GetNewClosure() captures variables, not function definitions.
#   The closure runs in a **new session state**, where not even a script-level function resolves
#   (measured: Get-Command Show-Box inside the closure returns null).
#   So Guard must first turn it into a variable with (Get-Item function:Show-Box).ScriptBlock
#   for it to travel with the closure. See the Guard comments.
function Show-Box {
    param(
        [string]$Text,
        [string]$Caption = 'Notice',
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
    $script:SelIndex = 1        # which index to install (a Server image usually holds 4 editions in one wim)
    $script:EdList = @()        # edition table of the current image, index-aligned with $cmbEd items
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

    # [audit P1-7] An install runs on the UI thread for 10-40 minutes and keeps updating the controls.
    # Closing the window in the middle disposed those controls and could skip the cleanup in finally.
    # Refuse to close while a job is running (the status line explains why).
    $form.Add_FormClosing({
        param($sender, $e)
        if ($script:Busy) {
            $e.Cancel = $true
            try {
                $lblSt.Text = 'Installation in progress - the window cannot be closed until it finishes'
                $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            } catch {}
        }
    })

    # ---- Header ----
    $hd = New-Object System.Windows.Forms.Panel
    $hd.Location = New-Object System.Drawing.Point(0, 0)
    $hd.Size = New-Object System.Drawing.Size(800, 86)
    $hd.BackColor = [System.Drawing.Color]::FromArgb(28, 56, 94)
    $form.Controls.Add($hd)

    $t1 = New-Object System.Windows.Forms.Label
    $t1.Text = $Script:ProductName
    $t1.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 20, [System.Drawing.FontStyle]::Bold)
    $t1.ForeColor = [System.Drawing.Color]::White
    $t1.Location = New-Object System.Drawing.Point(26, 8)
    $t1.Size = New-Object System.Drawing.Size(560, 36)
    $hd.Controls.Add($t1)

    # [layout fix] The tagline is split into two short lines on purpose. The Chinese original fits on one
    # line, but English at the same font size needs about 950px and was silently clipped by the
    # 742px single-line label (the text just stopped in the middle of a sentence). Two lines at 8.5pt
    # stay well inside the header, so no other control has to move.
    $t2 = New-Object System.Windows.Forms.Label
    $t2.Text = 'No USB stick, no BIOS changes. Every system is a separate virtual hard disk file - install as many as you like.' + [char]13 + [char]10 + 'The existing system stays untouched.   Author: connectsegabot'
    $t2.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
    $t2.ForeColor = [System.Drawing.Color]::FromArgb(168, 196, 226)
    $t2.Location = New-Object System.Drawing.Point(28, 46)
    $t2.Size = New-Object System.Drawing.Size(742, 34)
    $hd.Controls.Add($t2)

    # ---- Step 1 ----
    $y1 = 102
    $s1 = New-Object System.Windows.Forms.Label
    $s1.Text = '(1) Choose the system image'
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
    $btnPickWim.Text = 'Browse...'
    $btnPickWim.Location = New-Object System.Drawing.Point(622, ($y1 + 26))
    $btnPickWim.Size = New-Object System.Drawing.Size(128, 30)
    $btnPickWim.FlatStyle = 'System'
    $form.Controls.Add($btnPickWim)

    $lblWim = New-Object System.Windows.Forms.Label
    $lblWim.Text = 'Searching for image files...'
    $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblWim.Location = New-Object System.Drawing.Point(30, ($y1 + 58))
    $lblWim.Size = New-Object System.Drawing.Size(720, 20)
    $lblWim.AutoEllipsis = $true
    $form.Controls.Add($lblWim)

    # [v1.17] Edition selection. One install.wim can hold several systems:
    #   the official Windows Server 2022 ISO -> 1 Standard(Core) 2 Standard(Desktop) 3 DC(Core) 4 DC(Desktop)
    # Previously index 1 was installed unconditionally, which on Server is the one with no GUI, leaving a console-only system.
    # The three controls only appear for multi-index images; single-edition images look exactly as before.
    $lblEd = New-Object System.Windows.Forms.Label
    $lblEd.Text = 'Edition'
    $lblEd.ForeColor = [System.Drawing.Color]::FromArgb(68, 80, 98)
    $lblEd.Location = New-Object System.Drawing.Point(30, ($y1 + 81))
    $lblEd.Size = New-Object System.Drawing.Size(52, 18)
    $lblEd.Visible = $false
    $form.Controls.Add($lblEd)

    $cmbEd = New-Object System.Windows.Forms.ComboBox
    $cmbEd.Location = New-Object System.Drawing.Point(84, ($y1 + 79))
    $cmbEd.Size = New-Object System.Drawing.Size(486, 24)
    $cmbEd.DropDownStyle = 'DropDownList'
    $cmbEd.Visible = $false
    $form.Controls.Add($cmbEd)

    $lblEdHint = New-Object System.Windows.Forms.Label
    # [layout fix] Short text on purpose: the slot is only 190px wide.
    $lblEdHint.Text = 'several editions - pick one'
    $lblEdHint.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
    $lblEdHint.Location = New-Object System.Drawing.Point(580, ($y1 + 81))
    $lblEdHint.Size = New-Object System.Drawing.Size(190, 18)
    $lblEdHint.AutoEllipsis = $true
    $lblEdHint.Visible = $false
    $form.Controls.Add($lblEdHint)

    # ---- Step 2 ----
    $y2 = 212
    $s2 = New-Object System.Windows.Forms.Label
    $s2.Text = '(2) Choose the storage folder and size'
    $s2.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $s2.ForeColor = [System.Drawing.Color]::FromArgb(36, 48, 70)
    $s2.Location = New-Object System.Drawing.Point(26, $y2)
    $s2.Size = New-Object System.Drawing.Size(320, 24)
    $form.Controls.Add($s2)

    # [v1.11] This used to be a drive dropdown with the vhdx limited to the drive root.
    # It is now an editable full path plus a browse button: putting it in D:\VHD\Win11 is fine.
    $txtDir = New-Object System.Windows.Forms.TextBox
    $txtDir.Location = New-Object System.Drawing.Point(28, ($y2 + 28))
    $txtDir.Size = New-Object System.Drawing.Size(470, 26)
    $txtDir.BorderStyle = 'FixedSingle'
    $form.Controls.Add($txtDir)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = 'Browse...'
    $btnBrowse.Location = New-Object System.Drawing.Point(504, ($y2 + 26))
    $btnBrowse.Size = New-Object System.Drawing.Size(96, 30)
    $btnBrowse.FlatStyle = 'System'
    $form.Controls.Add($btnBrowse)

    $lblSz = New-Object System.Windows.Forms.Label
    $lblSz.Text = 'Size'
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
    # [v1.20] Remember the last "auto-filled" suggestion. Only while the current value still equals it
    # (the user has not edited it) may the next image selection auto-fill again;
    # a size the user typed manually must never be overwritten.
    $script:SzSuggested = 60
    $form.Controls.Add($numSz)

    $lblGb = New-Object System.Windows.Forms.Label
    $lblGb.Text = 'GB'
    $lblGb.Location = New-Object System.Drawing.Point(726, ($y2 + 32))
    $lblGb.Size = New-Object System.Drawing.Size(30, 20)
    $form.Controls.Add($lblGb)

    # Drive shortcut buttons: one click replaces the path with "the root of that drive", easier than typing
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
    $lblDrive.AutoEllipsis = $true
    $form.Controls.Add($lblDrive)

    # ---- Step 3: system name ----
    $y3 = 344
    $s3 = New-Object System.Windows.Forms.Label
    $s3.Text = '(3) Give this system a name'
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
    $btnNameGen.Text = 'Use edition name'
    $btnNameGen.Location = New-Object System.Drawing.Point(476, ($y3 + 26))
    $btnNameGen.Size = New-Object System.Drawing.Size(116, 30)
    $btnNameGen.FlatStyle = 'System'
    $form.Controls.Add($btnNameGen)

    $btnNameNum = New-Object System.Windows.Forms.Button
    $btnNameNum.Text = 'Add number'
    $btnNameNum.Location = New-Object System.Drawing.Point(600, ($y3 + 26))
    $btnNameNum.Size = New-Object System.Drawing.Size(96, 30)
    $btnNameNum.FlatStyle = 'System'
    $form.Controls.Add($btnNameNum)

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text = ''
    $lblName.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblName.Location = New-Object System.Drawing.Point(30, ($y3 + 60))
    $lblName.Size = New-Object System.Drawing.Size(740, 20)
    $form.Controls.Add($lblName)

    # ---- Existing systems ----
    $y4 = 432
    $s4 = New-Object System.Windows.Forms.Label
    $s4.Text = 'Systems already installed on this machine'
    $s4.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $s4.ForeColor = [System.Drawing.Color]::FromArgb(68, 80, 98)
    $s4.Location = New-Object System.Drawing.Point(26, $y4)
    $s4.Size = New-Object System.Drawing.Size(400, 20)
    $form.Controls.Add($s4)

    # [layout fix] 72px instead of 58px: up to 4 entries plus an "and N more" line are printed here,
    # and English entries are taller than the Chinese ones they replaced (the last line used to be cut).
    $lblSysList = New-Object System.Windows.Forms.Label
    $lblSysList.Text = 'Scanning...'
    $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    $lblSysList.Location = New-Object System.Drawing.Point(28, ($y4 + 22))
    $lblSysList.Size = New-Object System.Drawing.Size(740, 72)
    $lblSysList.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
    $form.Controls.Add($lblSysList)

    # ---- Notice box ----
    # [layout fix] This used to be a fixed 742x74 panel with a 722x54 label inside. The English notice
    # wraps to three or four lines and the third one was sliced off by the panel border, so the label
    # now grows with its own text and everything below it is positioned from the real height.
    $y5 = 540
    $lblBox = New-Object System.Windows.Forms.Label
    $lblBox.Text = "After installing, reboot and the boot menu will show one extra entry (the name you chose); pick it to boot the new system." + [char]13 + [char]10 + "Install another one by running it again with a different name. To remove it later run Uninstall-System.bat: it is deleted completely and the existing system is not affected at all."
    $lblBox.ForeColor = [System.Drawing.Color]::FromArgb(42, 78, 128)
    $lblBox.BackColor = [System.Drawing.Color]::FromArgb(237, 245, 254)
    $lblBox.BorderStyle = 'FixedSingle'
    $lblBox.Padding = New-Object System.Windows.Forms.Padding(10, 7, 10, 7)
    $lblBox.AutoSize = $true
    $lblBox.Location = New-Object System.Drawing.Point(28, $y5)
    # MaximumSize is what makes an AutoSize label wrap; MinimumSize keeps the box the same width as
    # the other controls even when every line happens to be short
    $lblBox.MaximumSize = New-Object System.Drawing.Size(742, 0)
    $lblBox.MinimumSize = New-Object System.Drawing.Size(742, 0)
    $form.Controls.Add($lblBox)
    # The new height is applied on the next layout pass - force it before measuring
    $lblBox.PerformLayout()

    # ---- Step 4: start ----
    # Everything below is placed from the real bottom edge of the notice box, so a three-line
    # English text can never push the buttons or the footer out of the window again.
    $boxH = $lblBox.Height
    if ($boxH -lt 40) { $boxH = 80 }      # layout not measured yet (should not happen): safe fallback
    $y6 = $y5 + $boxH + 14
    $sep = New-Object System.Windows.Forms.Panel
    $sep.Location = New-Object System.Drawing.Point(26, $y6)
    $sep.Size = New-Object System.Drawing.Size(746, 1)
    $sep.BackColor = [System.Drawing.Color]::FromArgb(218, 223, 230)
    $form.Controls.Add($sep)

    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Text = 'Start installation'
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
    $lblSt.Text = 'Waiting to start'
    $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(86, 96, 112)
    $lblSt.Location = New-Object System.Drawing.Point(198, ($y6 + 40))
    $lblSt.Size = New-Object System.Drawing.Size(576, 20)
    $lblSt.AutoEllipsis = $true
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
    $lblFoot.Text = "Firmware: $(switch (Get-FirmwareType) { 2 { 'UEFI' } 1 { 'Legacy BIOS' } default { 'unknown' } })    Log: $Script:LogFile"
    $lblFoot.ForeColor = [System.Drawing.Color]::FromArgb(150, 158, 170)
    $lblFoot.Location = New-Object System.Drawing.Point(30, ($y6 + 182))
    $lblFoot.Size = New-Object System.Drawing.Size(742, 18)
    $lblFoot.AutoEllipsis = $true
    $form.Controls.Add($lblFoot)

    # [layout fix] Window height follows the real content instead of the hard-coded 876px, so a longer
    # English block never pushes the footer out of view. Capped to the screen working area; if the
    # content still does not fit (very small screen), the form scrolls instead of clipping.
    $needH = $y6 + 258
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if ($needH -gt ($wa.Height - 16)) {
        $needH = $wa.Height - 16
        $form.AutoScroll = $true
    }
    $form.Size = New-Object System.Drawing.Size(800, $needH)

    function AddLog([string]$m) {
        $stamp = (Get-Date).ToString('HH:mm:ss')
        # Note: method arguments are split on commas, so -f only receives the first argument;
        # the whole line must be assembled into a variable first
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

    # The line under the path box: validate the folder + show the final file name + free space
    function UpdateDirHint {
        $raw = $txtDir.Text
        if (-not $raw -or -not $raw.Trim()) {
            $lblDrive.Text = 'Enter a folder, or click a drive button above.'
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
            # Still record the drive letter so the Start button's enabled state follows it;
            # the real gate is Test-TargetFolder when Start is clicked.
            if ($raw.Trim() -match '^([A-Za-z])') { $script:SelDrive = $Matches[1].ToUpper() } else { $script:SelDrive = $null }
            UpdateGo
            return
        }
        $script:SelDrive = $chk.Folder.Substring(0, 1).ToUpper()
        $freeB = Get-DiskFreeBytes $chk.Folder
        $free = if ($freeB -ge 0) { [math]::Round($freeB / 1GB, 1) } else { -1 }
        $need = [int64]$numSz.Value + 5
        $txt = "Usable partition $($script:SelDrive):  $free GB free"
        # When it lands on the system drive (the only choice on a single-drive machine) say so plainly: not an error, but it eats system space.
        # Warn only, never block - otherwise a user with only C: could not install at all.
        $onSys = ($script:SelDrive -eq $env:SystemDrive.TrimEnd(':').ToUpper())
        if ($free -lt 0) {
            # No number is not an error; the real write probe on Start decides
            $txt = "Usable partition $($script:SelDrive):  free space unknown (a real write test will run)"
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
            $lblDrive.Tag = 'ok'
        } elseif ($free -lt $need) {
            $txt = $txt + "  -- not enough for $($numSz.Value) GB (including 5GB headroom), pick a larger partition or lower it"
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
        if ($onSys) { $txt += '  - this is the system drive, the virtual disk will consume system space' }
        $lblDrive.Text = $txt
        UpdateGo
    }

    # The line under the name box: live preview of the resulting file name and whether it clashes
    function UpdateNameHint {
        $raw = $txtName.Text
        $safe = Get-SafeDiskName $raw
        $parts = @()
        if ($safe -ne $raw.Trim()) {
            $parts += ('illegal characters removed automatically -> "' + $safe + '"')
        }
        if (-not (Test-EncodableName $safe)) {
            $lblName.Text = "This name contains characters the system code page cannot encode (emoji etc.), please choose another."
            $lblName.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            return
        }
        $chk = Test-TargetFolder $txtDir.Text
        if ($chk.Ok) {
            try {
                $p = Get-UniqueVhdPath -Folder $chk.Folder -DiskName $safe
                $fn = [System.IO.Path]::GetFileName($p)
                $parts += "file: $($chk.Folder.TrimEnd('\'))\$fn"
                if ($fn -ne "$safe.vhdx") {
                    $parts += '(a file with this name exists, a number is appended automatically)'
                }
            } catch {
                $parts += $_.Exception.Message
            }
        }
        $parts += 'the boot menu shows exactly this name'
        $lblName.Text = ($parts -join '    ')
        $lblName.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
    }

    function Refresh-SysList {
        $script:SysList = @(Find-InstalledSystems)
        if ($script:SysList.Count -eq 0) {
            $lblSysList.Text = 'Nothing installed yet. Several systems are allowed, each with a different name.'
            $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(116, 126, 142)
        } else {
            $lines = @()
            foreach ($s in ($script:SysList | Select-Object -First 4)) {
                $d = $s.Name
                if ($s.Desc) { $d = "$($s.Desc)  ←  $($s.Name)" }
                $lines += ('  · ' + $d + '    ' + $s.SizeGB + ' GB')
            }
            if ($script:SysList.Count -gt 4) { $lines += ('  ... and ' + ($script:SysList.Count - 4) + ' more') }
            $lblSysList.Text = ($lines -join [char]13 + [char]10)
            $lblSysList.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 88)
        }
    }

    # Wrap event handlers so any exception becomes a readable message instead of the WinForms "unhandled exception" dialog
    # Note: do not return { & $Body }, because $Body is out of scope when the returned script block runs (it would be $null)
    # The variables must be captured with .GetNewClosure()
    #
    # There is a subtler trap: GetNewClosure() **captures variables, not function definitions**.
    # The returned closure runs in a new session state where even the script-level function Show-Box does not resolve
    # (measured: Get-Command Show-Box inside the closure returns null).
    # So Show-Box must first be turned into a variable with (Get-Item function:Show-Box).ScriptBlock
    # to travel into the closure with GetNewClosure.
    function Guard {
        param([string]$Name, [scriptblock]$Body)
        $logPath = $Script:LogFile
        $tag = $Name
        $boxFn = $null
        try { $boxFn = (Get-Item function:Show-Box -EA Stop).ScriptBlock } catch {}
        # Same as above: Add-Content is a command too and may not resolve inside a closure, so hoist it into a variable
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
                    $detail = "$detail" + [char]13 + [char]10 + [char]13 + [char]10 + "Failing statement (line $line):" + [char]13 + [char]10 + $_.InvocationInfo.Line.Trim()
                }
                try {
                    # [v1.29] The log path may be redirected when installation starts, and the closure captured the old value,
                    # so prefer the current value from the AppDomain data slot
                    $lp = $null
                    try { $lp = [System.AppDomain]::CurrentDomain.GetData('VHDX.LogFile') } catch {}
                    if (-not $lp) { $lp = $logPath }
                    $rec = ('[{0}] [EVENT-ERR] {1}: {2} @L{3}' -f (Get-Date).ToString('HH:mm:ss'), $tag, $ex.Message, $line) + [char]13 + [char]10
                    & $logFn -LiteralPath $lp -Value $rec
                } catch {}
                try {
                    if ($boxFn) {
                        $msg = "[$tag] Error:" + [char]13 + [char]10 + [char]13 + [char]10 + $detail + [char]13 + [char]10 + [char]13 + [char]10 +
                               "Log: $lp"
                        & $boxFn -Text $msg `
                                  -Caption 'Operation failed' `
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
            Show-Box -Text ("This file cannot be used." + [char]13 + [char]10 + [char]13 + [char]10 + $info.Error) `
                     -Caption 'Invalid image' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            AddLog "Invalid image: $($info.Error)"
            return
        }
        $script:SelWim = $path
        # Remember the edition name; it decides what the boot menu shows (instead of hard-coding Windows 10)
        $script:SelEdition = [string]$info.Name
        $script:SelIndex = 1
        $lblWim.Text = "$($info.Name)    build $($info.Build)    file $($info.SizeGB) GB, about $($info.UncompGB) GB installed"
        $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(26, 124, 68)
        AddLog "Image: $($info.Name)  $($info.Build)"

        # ---- Edition selection (v1.17) ----
        # One wim can hold several systems. Index 1 of the official Server ISO happens to be the "no GUI"
        # Server Core, which used to be installed unconditionally - the user ended up with a black console and had to start over.
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
            # Default to the edition with a GUI; only fall back to the first one when none has it (e.g. multi-edition Win10 ISOs)
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
            AddLog ("This image has {0} editions, defaulting to ""{1}"" (index {2})" -f `
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
                # [v1.20] This used to run an unconditional $numSz.Value = $suggest:
                # the user manually set the size to 80, then picked another image again (or refreshed the partition list,
                # which triggers Refresh-All and reselects item 0), and it was snapped back to the suggestion - for small images
                # the suggestion is clamped at 40, so it looked like "the size I set turned itself back into 40G".
                # Now it only overwrites while "current value == the last auto-filled value".
                if ([int]$numSz.Value -eq [int]$script:SzSuggested) {
                    $numSz.Value = $suggest
                    $script:SzSuggested = $suggest
                    AddLog "Suggested disk size: $suggest GB (auto-filled)"
                } else {
                    AddLog "Suggested disk size: $suggest GB (keeping your manual size of $([int]$numSz.Value) GB)"
                }
            }
        }
        UpdateGo
    }

    function Refresh-All {
        # Partitions: build the shortcut buttons per drive first, the default path is the root of the first usable drive
        $flowDrv.Controls.Clear()
        $vols = @(Get-TargetVolumes)
        foreach ($v in $vols) {
            $b = New-Object System.Windows.Forms.Button
            # The system drive is listed too (nothing else to choose on a single-drive machine) but clearly marked and sorted last:
            # installing onto C: consumes system partition space, so it is not the first choice.
            if ($v.IsSystem) {
                $b.Text = "$($v.Letter):  $($v.FreeGB) GB free - system drive"
                $b.ForeColor = [System.Drawing.Color]::FromArgb(150, 110, 40)
            } else {
                $b.Text = "$($v.Letter):  $($v.FreeGB) GB free"
            }
            $b.AutoSize = $true
            $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
            $b.FlatStyle = 'System'
            $b.Tag = "$($v.Letter):\"
            # Call the function directly (not through a closure), avoiding the old problem of GetNewClosure missing script functions
            $b.Add_Click({
                param($sender, $ev)
                $txtDir.Text = [string]$sender.Tag
            })
            [void]$flowDrv.Controls.Add($b)
        }

        if ($vols.Count -gt 0) {
            # As long as the machine has any usable drive, the path box and "Browse..." must stay enabled.
            # Up to v1.15 these followed "non-system drives", so on a single-C: machine both controls were disabled and
            # the user had no way at all to pick a folder manually.
            $txtDir.Enabled = $true
            $btnBrowse.Enabled = $true
            if (-not $txtDir.Text.Trim()) {
                # Prefer a non-system drive (already sorted by IsSystem, so the first one is it).
                # With only the system drive, fill in C:\ rather than C:\VirtualDisks - the latter usually does not exist and
                # would immediately show a red "this folder does not exist", effectively blocking the user at the door.
                $pick = $vols[0].Letter
                if (-not $vols[0].IsSystem -and $script:SelDrive) {
                    foreach ($v in $vols) { if ($v.Letter -eq $script:SelDrive) { $pick = $v.Letter; break } }
                }
                $txtDir.Text = "$($pick):\"
            }
        } else {
            $txtDir.Enabled = $false
            $btnBrowse.Enabled = $false
            $lblDrive.Text = 'No usable partition (an NTFS partition on a local fixed disk with at least 10GB free is required)'
            $lblDrive.ForeColor = [System.Drawing.Color]::FromArgb(190, 80, 60)
            $script:SelDrive = $null
        }

        # Image
        $cmbWim.Items.Clear()
        $script:WimList = @(Find-WimFiles -Roots $SearchRoot)
        if ($script:WimList.Count -eq 0) {
            $lblWim.Text = 'No image found automatically; click "Browse..." to pick a .wim / .esd / .iso file'
            $lblWim.ForeColor = [System.Drawing.Color]::FromArgb(186, 106, 30)
            AddLog 'No .wim / .esd / .iso image found'
        } else {
            foreach ($w in $script:WimList) { [void]$cmbWim.Items.Add($w) }
            $cmbWim.SelectedIndex = 0
            AddLog "Found $($script:WimList.Count) image files"
        }
        Refresh-SysList
        UpdateDirHint
        UpdateNameHint
        UpdateGo
    }

    $cmbWim.Add_SelectedIndexChanged((Guard 'select image' {
        if ($cmbWim.SelectedIndex -ge 0) { Set-Wim $cmbWim.SelectedItem.ToString() }
    }))

    # The user switched edition: the index follows, and installation uses it
    $cmbEd.Add_SelectedIndexChanged((Guard 'select edition' {
        $i = $cmbEd.SelectedIndex
        if ($i -ge 0 -and $i -lt @($script:EdList).Count) {
            $it = $script:EdList[$i]
            $script:SelIndex = [int]$it.Index
            $script:SelEdition = [string]$it.Name
            AddLog ("Edition: {0} (index {1})" -f $it.Name, $it.Index)
            UpdateNameHint
        }
    }))

    $txtName.Add_TextChanged((Guard 'name changed' { UpdateNameHint }))

    $btnNameGen.Add_Click((Guard 'use edition name' {
        $e = [string]$script:SelEdition
        if (-not $e) {
            Show-Box -Text 'No image selected yet; pick one above first.' -Caption 'Notice' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }
        $txtName.Text = Get-SafeDiskName $e
    }))

    $btnNameNum.Add_Click((Guard 'add number' {
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

    $txtDir.Add_TextChanged((Guard 'path changed' {
        UpdateDirHint
        UpdateNameHint
    }))

    $btnBrowse.Add_Click((Guard 'browse storage folder' {
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = 'Pick a folder to store the virtual hard disk in (local disk, NTFS, enough free space)'
        $fb.ShowNewFolderButton = $true
        $cur = $txtDir.Text.Trim()
        if ($cur -and (Test-Path -LiteralPath $cur -PathType Container)) { $fb.SelectedPath = $cur }
        if ($fb.ShowDialog() -eq 'OK') { $txtDir.Text = $fb.SelectedPath }
    }))

    $numSz.Add_ValueChanged((Guard 'size changed' {
        UpdateDirHint
    }))

    $btnPickWim.Add_Click((Guard 'browse for image' {
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = 'Select a system image (.wim / .esd / .iso supported)'
        $ofd.Filter = 'System images (*.wim;*.esd;*.iso)|*.wim;*.esd;*.iso|WIM image (*.wim)|*.wim|ESD image (*.esd)|*.esd|ISO disc (*.iso)|*.iso|All files (*.*)|*.*'
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
    $form.Add_DragDrop((Guard 'drop image' {
        $fs = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($fs -and $fs.Count -gt 0 -and $fs[0] -match '\.(wim|esd|iso)$') {
            $p = $fs[0]
            if (-not $cmbWim.Items.Contains($p)) { [void]$cmbWim.Items.Add($p) }
            $cmbWim.SelectedItem = $p
        }
    }))

    # The main button needs Guard too: it is the only handler that runs for a dozen minutes and calls Get-Volume / Show-Box,
    # and if one of those throws outside a try, the default WinForms "unhandled exception" black box appears
    # while $btnGo.Enabled may stay false, leaving the user with Task Manager as the only way out.
    $btnGo.Add_Click((Guard 'start installation' {
        if (-not $script:SelWim -or -not $script:SelDrive) { return }
        $size = [int]$numSz.Value

        # Name validation (v1.11)
        $diskName = Get-SafeDiskName $txtName.Text
        if (-not $diskName) { $diskName = $Script:DefaultDiskName }
        if (-not (Test-EncodableName $diskName)) {
            Show-Box -Text ("The name contains characters the system code page cannot encode (emoji etc.), so it cannot be used as a file name." + [char]13 + [char]10 + [char]13 + [char]10 +
                            "Use letters, digits, spaces or common punctuation instead.") `
                     -Caption 'Invalid name' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $dirChk = Test-TargetFolder $txtDir.Text
        if (-not $dirChk.Ok) {
            Show-Box -Text ("The storage folder cannot be used: " + [char]13 + [char]10 + [char]13 + [char]10 + $dirChk.Msg) `
                     -Caption 'Storage folder' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $targetDir = $dirChk.Folder
        $targetPath = ''
        try { $targetPath = Get-UniqueVhdPath -Folder $targetDir -DiskName $diskName }
        catch {
            Show-Box -Text $_.Exception.Message -Caption 'Name clash' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        # Space check (v1.12): reported value + a real write probe; both must pass to continue.
        #
        # This used to look at $vol.SizeRemaining only, and $vol was a stale object left over from an earlier branch.
        # The reported value is unreliable (measured: 436GB free in that folder, reported as 0KB), so:
        #   - reported value sufficient -> pass
        #   - reported value insufficient -> do not reject yet, write a real 64MB probe file first
        #   - probe write fails -> only then report "not enough space", stating whether it is the report or the measurement
        $needBytes = [int64]$size * 1GB + 5GB
        $freeB = Get-DiskFreeBytes $targetDir
        $reportTxt = if ($freeB -ge 0) { Format-Size $freeB } else { 'unknown' }
        if ($freeB -lt $needBytes) {
            AddLog "Partition reports $reportTxt free (need $(Format-Size $needBytes)), running a real write test..."
            $wchk = Test-FolderWritable -Folder $targetDir -ProbeMB 64
            if (-not $wchk.Ok) {
                $msg = 'Not enough space, cannot install.' + [char]13 + [char]10 + [char]13 + [char]10 +
                       ('Folder: {0}' -f $targetDir) + [char]13 + [char]10 +
                       ('Required: {0} (configured {1} GB + 5GB headroom)' -f (Format-Size $needBytes), $size) + [char]13 + [char]10 +
                       ('Reported free: {0}' -f $reportTxt) + [char]13 + [char]10 +
                       ('Real write test: {0}' -f $wchk.Msg) + [char]13 + [char]10 + [char]13 + [char]10 +
                       'What to do:' + [char]13 + [char]10 +
                       '  - lower the "Size" a little' + [char]13 + [char]10 +
                       '  - pick a folder with more free space' + [char]13 + [char]10 +
                       '  - free up space on this partition'
                Show-Box -Text $msg -Caption 'Not enough space' `
                         -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                         -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                return
            }
            AddLog "Write test passed ($($wchk.Msg)); the reported value is clearly wrong, continuing with the measurement"
        } else {
            # Even a sufficient reported value must be verified - quotas / ACLs / read-only cannot be seen in the number
            $wchk = Test-FolderWritable -Folder $targetDir -ProbeMB 64
            if (-not $wchk.Ok) {
                Show-Box -Text ('This folder is not writable:' + [char]13 + [char]10 + [char]13 + [char]10 +
                                ('Folder: {0}' -f $targetDir) + [char]13 + [char]10 +
                                ('Reason: {0}' -f $wchk.Msg) + [char]13 + [char]10 + [char]13 + [char]10 +
                                'Try another folder (for example D:\VHD).') `
                         -Caption 'Cannot write' `
                         -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                         -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                return
            }
        }

        $m = "Start the installation?" + [char]13 + [char]10 + [char]13 + [char]10 +
             "    System name: $diskName   (this line is what the boot menu shows)" + [char]13 + [char]10 +
             "    Image: $($script:SelWim)" + [char]13 + [char]10 +
             "    Edition: $($script:SelEdition) (index $($script:SelIndex))" + [char]13 + [char]10 +
             "    Location: $targetPath" + [char]13 + [char]10 +
             "    Size: up to $size GB (the file grows as needed; still keep the free space, the preflight checks against this value)" + [char]13 + [char]10 + [char]13 + [char]10 +
             "Takes 10-40 minutes, do not power off meanwhile." + [char]13 + [char]10 +
             "The existing system is not touched, and neither are other installed systems."
        $r = Show-Box -Text $m -Caption 'Confirm' `
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
            # [v1.29] Logs follow the install location: <storage folder>\<ProductName>-logs\
            Set-LogDir -VhdDir $targetDir
            AddLog '========== Installation started =========='
            AddLog "System name: $diskName"
            AddLog "Edition: $($script:SelEdition) (index $($script:SelIndex))"
            AddLog "Disk size: $size GB"
            $res = Invoke-Install -WimPath $script:SelWim -TargetFolder $targetDir -SizeGB $size `
                -ImageIndex ([int]$script:SelIndex) `
                -EditionName $script:SelEdition -DiskName $diskName `
                -OnProgress { param($p) if ($p -ge 0 -and $p -le 100) { $pb.Value = $p; [System.Windows.Forms.Application]::DoEvents() } } `
                -OnStatus { param($s) $lblSt.Text = $s; [System.Windows.Forms.Application]::DoEvents(); Write-Log $s }

            AddLog '========== Installation complete =========='
            $lblSt.Text = "Installed; pick ""$diskName"" in the boot menu after rebooting"
            $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(0, 132, 66)
            $pb.Value = 100

            $okMsg = "Done!" + [char]13 + [char]10 + [char]13 + [char]10 +
                     "Next:" + [char]13 + [char]10 +
                     "1. Reboot the machine" + [char]13 + [char]10 +
                     "2. A selection menu appears at boot (if it does not, press an arrow key)" + [char]13 + [char]10 +
                     "3. Choose ""$diskName"" to boot the new system" + [char]13 + [char]10 + [char]13 + [char]10 +
                     "The first desktop takes a few minutes to initialize, that is normal." + [char]13 + [char]10 + [char]13 + [char]10 +
                     "To install another one: close this window, open it again and use a different name." + [char]13 + [char]10 +
                     "To remove it later: run Uninstall-System.bat."
            Show-Box -Text $okMsg -Caption 'Installation succeeded' `
                     -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) `
                     -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

            $ask = Show-Box -Text 'Reboot now?' -Caption 'Reboot' `
                   -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo) `
                   -Icon ([System.Windows.Forms.MessageBoxIcon]::Question) `
                   -Default ([System.Windows.Forms.MessageBoxDefaultButton]::Button2)
            if ($ask -eq 'Yes') { Restart-Computer -Force }

        } catch {
            AddLog "Failed: $_"
            $lblSt.Text = 'Installation failed'
            $lblSt.ForeColor = [System.Drawing.Color]::FromArgb(188, 50, 50)
            $pb.Value = 0
            # The message must match what was actually cleaned up:
            #   * system files written, only the boot entry missing -> the vhdx is deliberately kept (a rerun of the entry step rescues it)
            #   * any other failure -> only files created by this run are deleted ($createdHere)
            # This used to always claim "cleaned up automatically", while the BCD failure case deliberately keeps the disk, so users assumed space came back.
            # Invoke-Install puts "The system files are fully written into the virtual disk" into the exception message when it keeps the vhdx.
            $keepVhdHint = ("$_" -match 'fully written into the virtual disk')
            $cleanNote = if ($keepVhdHint) {
                "The system files are fully written into the virtual disk, so the file was kept (not deleted) to avoid a reinstall." + [char]13 + [char]10 +
                "Open Start.bat and choose 8 (Repair boot menu), or run tools\Repair-Boot-Menu.bat, to just register the boot entry."
            } else {
                "The virtual disk file created by this run has been cleaned up; the existing system was not affected."
            }
            $failMsg = "Installation failed:" + [char]13 + [char]10 + [char]13 + [char]10 + "$_" + [char]13 + [char]10 + [char]13 + [char]10 +
                       "Common causes:" + [char]13 + [char]10 +
                       "  - not enough space on the target partition" + [char]13 + [char]10 +
                       "  - the image file is corrupt" + [char]13 + [char]10 +
                       "  - antivirus blocked the operation" + [char]13 + [char]10 + [char]13 + [char]10 +
                       $cleanNote + [char]13 + [char]10 + [char]13 + [char]10 +
                       "Log: $Script:LogFile"
            Show-Box -Text $failMsg -Caption 'Installation failed' `
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
        AddLog "Program start v$($Script:Version)"
        AddLog "Administrator: $(Test-Admin)"
        try {
            Refresh-All
        } catch {
            AddLog "UI refresh failed: $($_.Exception.Message)"
            $initMsg = "UI initialization failed:" + [char]13 + [char]10 + [char]13 + [char]10 +
                       $_.Exception.Message + [char]13 + [char]10 + [char]13 + [char]10 +
                       "Log: $Script:LogFile"
            Show-Box -Text $initMsg -Caption 'Initialization failed' `
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
    Write-Log "Top-level exception: $msg" 'ERROR'
    try {
        Add-Type -AssemblyName System.Windows.Forms -EA SilentlyContinue
        $startMsg = "Program start failed:" + [char]13 + [char]10 + [char]13 + [char]10 +
                    $msg + [char]13 + [char]10 + [char]13 + [char]10 +
                    "Log: $Script:LogFile"
        [System.Windows.Forms.MessageBox]::Show(
            $startMsg, 'Start failed',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button1) | Out-Null
    } catch {
        Write-Host "Start failed: $msg" -ForegroundColor Red
    }
    if ($ConsoleMode) { Write-Host "Start failed: $msg" -ForegroundColor Red; Read-Host 'Press Enter to exit' }
}
