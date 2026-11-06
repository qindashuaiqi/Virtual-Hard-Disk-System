<#
  Fix Boot Entry Target (Virtual Hard Disk System)
  Author: connectsegabot

  Purpose: after installing a virtual system, the boot menu may
    - list the entry but fail with 0xc000000f / file not found on selection
    - or not list it at all
  The cause is a wrong .vhdx path in the menu entry (or a missing displayorder). This tool will:

    1. find every virtual system installed by this toolkit (the ones with an xxx.boot.txt)
    2. compare the path its menu entry points at with the real file path, character by character
    3. fix it when wrong; recreate the entry from the record when missing; add it back when it is not in the menu

  The content of the virtual disk is never touched, and neither is the existing system.
#>

$ErrorActionPreference = 'Stop'
$Script:Version = '1.34'
$Script:LogFile = Join-Path $env:TEMP ("Fix-BootEntry-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Msg
    try { Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8 } catch {}
    $c = 'Gray'
    if ($Level -eq 'OK') { $c = 'Green' }
    if ($Level -eq 'WARN') { $c = 'Yellow' }
    if ($Level -eq 'ERR') { $c = 'Red' }
    Write-Host $line -ForegroundColor $c
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Bcd {
    param([string[]]$BcdArgs, [string]$Tag = '')
    $txt = ''
    try { $txt = (& bcdedit @BcdArgs 2>&1 | Out-String) } catch { $txt = "call failed: $($_.Exception.Message)" }
    $code = $LASTEXITCODE
    $clean = ($txt -replace '\s+', ' ').Trim()
    Write-Log ("bcdedit {0} [{1}] => exit={2}  {3}" -f $Tag, ($BcdArgs -join ' '), $code, $clean)
    $bad = ($txt -match '找不到|not found|无效|invalid|拒绝|denied|失败|failed|错误|error')
    return @{ Ok = (($code -eq 0) -and (-not $bad)); Code = $code; Text = $clean; Raw = $txt }
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

# Full path -> BCD vhd= syntax. The intermediate subfolder must be preserved:
#   D:\VirtualDisks\maimai.vhdx  ->  vhd=[D:]\VirtualDisks\maimai.vhdx
function Get-VhdBcdDevice {
    param([string]$FullPath)
    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetPathRoot($full)
    if (-not $root -or $root.Length -lt 3) { throw "Invalid path: $FullPath" }
    $letter = $root.Substring(0, 1).ToUpper()
    $rel = $full.Substring($root.Length).TrimStart('\')
    if (-not $rel) { throw "Invalid path: $FullPath" }
    return "vhd=[$($letter):]\$rel"
}

# Reverse parsing, used to compare character by character with the real path
function Get-FullPathFromBcdDevice {
    param([string]$Dev)
    if (-not $Dev) { return '' }
    $m = [regex]::Match($Dev, '^vhd=\[([A-Za-z]):\]\\(.+)$')
    if (-not $m.Success) { return '' }
    return ("{0}:\{1}" -f $m.Groups[1].Value.ToUpper(), $m.Groups[2].Value)
}

# Scan every fixed NTFS drive for vhdx. Breadth-first with folder-name pruning,
# never entering Windows / Users / the recycle bin, so depth 6 stays fast.
function Get-AllVhdxFile {
    param([int]$MaxDepth = 6)
    $skip = @('$RECYCLE.BIN', 'System Volume Information', 'Windows', 'Program Files',
              'Program Files (x86)', 'ProgramData', 'Users', '$WinREAgent', 'Recovery',
              'node_modules', '.git', 'WinSxS')
    $found = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-Volume -EA SilentlyContinue)) {
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

Write-Host ''
Write-Host 'Fix Boot Entry Target - author: connectsegabot'
Write-Host '======================================'
Write-Host ''

if (-not (Test-Admin)) {
    Write-Host 'Administrator rights are required.' -ForegroundColor Red
    Write-Host 'Close this window and double-click Fix-Boot-Entry-Device.bat instead; it requests elevation by itself.'
    Write-Host ''
    Write-Host 'Press any key to exit...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

Write-Log "Log: $($Script:LogFile)"

# ---------- Back up the active BCD first ----------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bk = Join-Path $env:TEMP "bcd-backup-$stamp.bcd"
$rb = Invoke-Bcd -BcdArgs @('/export', $bk) -Tag 'export'
if ($rb.Ok -and (Test-Path -LiteralPath $bk)) {
    Write-Log "BCD backed up: $bk" 'OK'
} else {
    Write-Log 'BCD backup failed, continuing (only the device path and the menu order change below, very low risk)' 'WARN'
}

# ---------- Find the targets ----------
Write-Host ''
Write-Host 'Searching for installed virtual systems...'
$items = New-Object System.Collections.ArrayList
foreach ($f in @(Get-AllVhdxFile)) {
    $st = [System.IO.Path]::ChangeExtension($f.FullName, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { continue }
    $sd = @{}
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -EA SilentlyContinue)) {
        if ($ln -match '^\s*([^#=]+)=(.*)$') { $sd[$matches[1].Trim()] = $matches[2].Trim() }
    }
    $g = [string]$sd['Guid']
    if ($g -notmatch '^\{[0-9a-fA-F-]{36}\}$') { continue }
    [void]$items.Add([PSCustomObject]@{
        Path  = $f.FullName
        Guid  = $g
        Name  = [string]$sd['Name']
        Desc  = [string]$sd['Desc']
        State = $st
    })
}

if ($items.Count -eq 0) {
    Write-Host ''
    Write-Host 'No virtual system installed by this toolkit was found.' -ForegroundColor Yellow
    Write-Host '(the xxx.boot.txt written at install time must sit next to the virtual disk)'
    Write-Host ''
    Write-Host 'If one was definitely installed, use Repair-Boot-Menu.bat to rebuild a boot entry.'
    Write-Host ''
    Write-Host 'Press any key to exit...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

Write-Host ("Found {0}:" -f $items.Count)
foreach ($x in $items) { Write-Host ("    {0}" -f $x.Path) }

# ---------- Check each one ----------
$fixedCount = 0
$okCount = 0
$failCount = 0

foreach ($it in $items) {
    Write-Host ''
    Write-Host ("· {0}" -f $it.Path) -ForegroundColor Cyan

    $wantDev = ''
    try { $wantDev = Get-VhdBcdDevice $it.Path }
    catch { Write-Log "Invalid path: $($_.Exception.Message)" 'ERR'; $failCount++; continue }
    $wantFull = [System.IO.Path]::GetFullPath($it.Path)

    $en = Invoke-Bcd -BcdArgs @('/enum', $it.Guid) -Tag 'enum'
    $guid = $it.Guid

    # Entry missing -> create one
    if (-not $en.Ok) {
        Write-Log "The menu has no such entry ($guid), creating one" 'WARN'
        $desc = $it.Desc
        if (-not $desc) { $desc = $it.Name }
        if (-not $desc) { $desc = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }

        $cp = Invoke-Bcd -BcdArgs @('/copy', '{current}', '/d', $desc) -Tag 'copy'
        if (-not $cp.Ok) { $cp = Invoke-Bcd -BcdArgs @('/copy', '{default}', '/d', $desc) -Tag 'copy-default' }
        $gm = [regex]::Match($cp.Raw, '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}')
        if (-not $gm.Success) {
            Write-Log "Failed to create the entry: $($cp.Text)" 'ERR'
            $failCount++
            continue
        }
        $guid = $gm.Value
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'device',   $wantDev) -Tag 'set-device')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'osdevice', $wantDev) -Tag 'set-osdevice')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'path', '\Windows\system32\winload.efi') -Tag 'set-path')

        # Replace the GUID in the state file with the new one, otherwise the uninstaller cannot find it
        try {
            $txt = [System.IO.File]::ReadAllText($it.State, [System.Text.Encoding]::UTF8)
            $txt = [regex]::Replace($txt, '(?m)^Guid=.*', "Guid=$guid")
            [System.IO.File]::WriteAllText($it.State, $txt, (New-Object System.Text.UTF8Encoding($true)))
            Write-Log "State file updated with the new GUID" 'OK'
        } catch { Write-Log "Failed to write the state file (booting is unaffected): $($_.Exception.Message)" 'WARN' }

        $en = Invoke-Bcd -BcdArgs @('/enum', $guid) -Tag 'verify'
        $fixedCount++
    }

    # Check the path device points at
    # Do not depend on the field label ("device" / "Gerät" / "デバイス"): the only line carrying "vhd=[" is the device line
    $dm = [regex]::Match($en.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    $curDev = ''
    if ($dm.Success) { $curDev = $dm.Groups[1].Value.Trim() }
    $curFull = Get-FullPathFromBcdDevice $curDev

    if (Test-BcdTextSame $wantFull $curFull) {
        Write-Log "Target correct: $curDev" 'OK'
        $okCount++
    } else {
        Write-Log ("Wrong target. Current [{0}], expected [{1}]" -f $curDev, $wantDev) 'WARN'
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'device',   $wantDev) -Tag 'fix-device')
        [void](Invoke-Bcd -BcdArgs @('/set', $guid, 'osdevice', $wantDev) -Tag 'fix-osdevice')
        $chk = Invoke-Bcd -BcdArgs @('/enum', $guid) -Tag 'recheck'
        $dm2 = [regex]::Match($chk.Raw, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
        $nowDev = ''
        if ($dm2.Success) { $nowDev = $dm2.Groups[1].Value.Trim() }
        $nowFull = Get-FullPathFromBcdDevice $nowDev
        if (Test-BcdTextSame $wantFull $nowFull) {
            Write-Log "Corrected: $nowDev" 'OK'
            $fixedCount++
        } else {
            Write-Log ("Still wrong after the change, now [{0}]" -f $nowDev) 'ERR'
            Write-Log 'If that shows "?" where the path has non-ASCII characters, it is only the console code page: run  chcp 936  and  bcdedit /enum  to see the real text.' 'ERR'
            Write-Log 'If it really points elsewhere, moving the virtual disk to a plain ASCII folder (such as D:\VHD) and reinstalling is the reliable fix.' 'ERR'
            $failCount++
            continue
        }
    }

    # Make sure it is in the boot menu displayorder
    $bm = Invoke-Bcd -BcdArgs @('/enum', '{bootmgr}') -Tag 'bootmgr'
    $om = [regex]::Match($bm.Raw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+?)\s*$')
    $order = ''
    if ($om.Success) { $order = $om.Groups[1].Value }

    if ($order -notmatch [regex]::Escape($guid)) {
        $ad = Invoke-Bcd -BcdArgs @('/displayorder', $guid, '/addlast') -Tag 'displayorder'
        if ($ad.Ok) {
            Write-Log 'Added back to the boot menu (last position)' 'OK'
            $fixedCount++
        } else {
            Write-Log "Failed to add it back to displayorder: $($ad.Text)" 'ERR'
            $failCount++
        }
        $bm = Invoke-Bcd -BcdArgs @('/enum', '{bootmgr}') -Tag 'bootmgr2'
        $om = [regex]::Match($bm.Raw, '(?im)^\s*(?:displayorder|显示顺序)\s+(.+?)\s*$')
        if ($om.Success) { $order = $om.Groups[1].Value }
    } else {
        Write-Log 'It is in displayorder' 'OK'
    }

    # The menu must be enabled, otherwise the default system boots directly and these options are never shown
    $entryCount = ([regex]::Matches($order, '\{')).Count
    if ($entryCount -ge 2) {
        $dbm = [regex]::Match($bm.Raw, '(?im)^\s*(?:displaybootmenu|显示启动菜单)\s+(\S+)')
        $tmo = [regex]::Match($bm.Raw, '(?im)^\s*timeout\s+(\d+)')
        $needMenu = $false
        if (-not $dbm.Success) { $needMenu = $true }
        elseif ($dbm.Groups[1].Value -notmatch '^(?i:yes)$') { $needMenu = $true }
        $needTimeout = ($tmo.Success -and ([int]$tmo.Groups[1].Value -eq 0))

        if ($needMenu -or $needTimeout) {
            [void](Invoke-Bcd -BcdArgs @('/set', '{bootmgr}', 'displaybootmenu', 'Yes') -Tag 'menu-on')
            if ($needTimeout) {
                [void](Invoke-Bcd -BcdArgs @('/set', '{bootmgr}', 'timeout', '10') -Tag 'timeout-10')
            }
            Write-Log 'Boot menu enabled (otherwise the options are never shown)' 'OK'
            $fixedCount++
        }
    }
}

# ---------- Summary ----------
Write-Host ''
Write-Host '================ Result ================'
Write-Host ("  already correct: {0}" -f $okCount)
Write-Host ("  fixed          : {0}" -f $fixedCount) -ForegroundColor Green
Write-Host ("  failed         : {0}" -f $failCount) -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host ''
if ($fixedCount -gt 0) {
    Write-Host 'Reboot and these systems should now show up in the boot menu and boot.' -ForegroundColor Green
} elseif ($failCount -eq 0 -and $okCount -gt 0) {
    Write-Host 'All menu targets are correct and nothing needed fixing. If the menu still does not appear,'
    Write-Host 'the firmware may not boot from the ESP on this disk, or the menu timeout is too short - try pressing an arrow key.'
} else {
    Write-Host 'Some entries could not be fixed; send me the log below.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host ("Log: {0}" -f $Script:LogFile)
Write-Host ''
Write-Host 'Press any key to exit...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
