<#
  Virtual Hard Disk System - uninstaller
  Deletes the virtual hard disk file and removes the matching boot entry from the boot menu. The existing system is not affected.
  Supports several installed systems: each one is listed separately and deleted by name.
  Author: connectsegabot
#>

$ErrorActionPreference = 'Stop'
$Script:Version = '1.34'
$Script:ProductName = 'Virtual Hard Disk System'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Admin {
    try {
        # [audit P1-8] This used to copy itself to a FIXED name (uninstall-system-elevated.ps1) in a
        # user-writable folder and then elevate that path. Any process running as the same user could
        # plant or replace that file beforehand, and the elevated run would execute it.
        # A random name removes the "plant it in advance" half. The remaining copy-to-elevate race
        # cannot be closed by a script at all - that needs an Authenticode signature.
        $psi = Join-Path $env:TEMP ("uninstall-system-{0}.ps1" -f ([guid]::NewGuid().ToString('N').Substring(0, 12)))
        Copy-Item -LiteralPath $PSCommandPath -Destination $psi -Force
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$psi`"") `
            -Verb RunAs -Wait
        Remove-Item -LiteralPath $psi -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

# Detect whether this is running inside the new system (the virtual disk).
# Uninstalling must be done from the original system: running it in the new system would delete the very vhdx in use
# (the file is locked so it fails, but worse, bcdedit would only edit the BCD inside the vhdx,
# which does nothing to the boot menu, so the user thinks "uninstalled but the menu is still there").
function Test-RunningInVhd {
    try {
        $sys = $env:SystemDrive.TrimEnd(':')
        $part = Get-Partition -DriveLetter $sys -EA Stop | Select-Object -First 1
        if (-not $part) { return $false }
        $disk = Get-Disk -Number $part.DiskNumber -EA Stop
        return ([string]$disk.BusType -eq 'File Backed Virtual')
    } catch {
        return $false
    }
}

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

# Find the installed virtual hard disk systems.
#
# Since v1.11 the user picks the name (WinVHD / GameSystem / WorkWin ... all fine),
# so a fixed file name is no longer usable. Instead:
#   1. every .vhdx in the root of a fixed drive (older versions only installed there)
#   2. the two legacy names are always included (NewSystemDisk.vhdx / NewSystem.vhdx),
#      even when the file has been moved into a subfolder
function Find-InstalledVhds {
    $legacy = @('NewSystemDisk.vhdx', '新系统.vhdx')
    $seen = @{}
    $found = @()

    function Add-Hit([string]$Path, [string]$Letter) {
        $key = $Path.ToLower()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = $true
        $fi = Get-Item -LiteralPath $Path -EA SilentlyContinue
        if (-not $fi) { return }
        $desc = Get-StateDisplayName -VhdPath $Path
        $script:FoundVhds += [PSCustomObject]@{
            Path   = $Path
            SizeGB = [math]::Round($fi.Length / 1GB, 1)
            Letter = $Letter
            Desc   = $desc
            Name   = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        }
    }
    $script:FoundVhds = @()

    foreach ($vol in (Get-Volume -EA SilentlyContinue)) {
        if (-not $vol.DriveLetter) { continue }
        if ($vol.FileSystem -ne 'NTFS') { continue }
        if ($vol.DriveType -ne 'Fixed') { continue }
        $letter = $vol.DriveLetter

        # [v1.9] Look below the drive root as well.
        # This used to scan the root only, so a system installed to D:\VirtualDisks\maimai.vhdx was completely invisible to the uninstaller.
        # Breadth-first with folder-name pruning: system folders and the recycle bin are skipped, so depth 6 stays fast.
        $skip = @('$RECYCLE.BIN', 'System Volume Information', 'Windows', 'Program Files',
                  'Program Files (x86)', 'ProgramData', 'Users', '$WinREAgent', 'Recovery',
                  'node_modules', '.git', 'WinSxS')
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@("$($letter):\", 0))
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            $dir = [string]$cur[0]
            $d = [int]$cur[1]
            try {
                foreach ($f in [System.IO.Directory]::GetFiles($dir, '*.vhdx')) { Add-Hit $f $letter }
            } catch {}
            if ($d -ge 6) { continue }
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

        # Legacy-name fallback (in case one ended up in a folder that cannot be reached, at least these fixed names are recognised)
        foreach ($n in $legacy) {
            # This used to read "$root$n" - $root is never defined anywhere in this script (only $rootLen),
            # it expanded to an empty string and produced the relative path "NewSystemDisk.vhdx", Test-Path was always false,
            # so the fallback was effectively absent. $letter is the current volume's drive letter, and only the full path works.
            $p = "$($letter):\$n"
            if (Test-Path -LiteralPath $p) { Add-Hit $p $letter }
        }
    }
    $found = @($script:FoundVhds)
    return $found
}

function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Uninstall Virtual System v$($Script:Version) - connectsegabot"
    $form.Size = New-Object System.Drawing.Size(680, 528)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point(0, 0)
    $header.Size = New-Object System.Drawing.Size(680, 96)
    $header.BackColor = [System.Drawing.Color]::FromArgb(120, 46, 46)
    $form.Controls.Add($header)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Uninstall Virtual System"
    $lblTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.Location = New-Object System.Drawing.Point(24, 8)
    $lblTitle.Size = New-Object System.Drawing.Size(400, 34)
    $header.Controls.Add($lblTitle)

    # [layout fix] Two lines on purpose: the English sentence needs ~880px and the label is only 620px
    # wide, so it used to be cut after "The existing" (the Chinese original fits on one line).
    # 8.5pt keeps it inside the header without moving the list box below.
    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Deletes an installed virtual system and removes its boot entry from the boot menu." + [char]13 + [char]10 + "The original system is not touched.   Author: connectsegabot"
    $lblSub.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8.5)
    $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(232, 190, 190)
    $lblSub.Location = New-Object System.Drawing.Point(26, 46)
    $lblSub.Size = New-Object System.Drawing.Size(620, 34)
    $header.Controls.Add($lblSub)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(24, 112)
    $listBox.Size = New-Object System.Drawing.Size(620, 130)
    $listBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
    $form.Controls.Add($listBox)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Searching..."
    $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(90, 100, 115)
    $lblInfo.Location = New-Object System.Drawing.Point(26, 250)
    $lblInfo.Size = New-Object System.Drawing.Size(618, 40)
    $form.Controls.Add($lblInfo)

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Location = New-Object System.Drawing.Point(24, 296)
    $logBox.Size = New-Object System.Drawing.Size(620, 120)
    $logBox.Multiline = $true
    $logBox.ScrollBars = 'Vertical'
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(252, 252, 253)
    $logBox.ForeColor = [System.Drawing.Color]::FromArgb(68, 78, 92)
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $logBox.BorderStyle = 'FixedSingle'
    $form.Controls.Add($logBox)

    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "Delete the selected system"
    $btnUninstall.Location = New-Object System.Drawing.Point(24, 428)
    $btnUninstall.Size = New-Object System.Drawing.Size(200, 40)
    $btnUninstall.BackColor = [System.Drawing.Color]::FromArgb(180, 52, 52)
    $btnUninstall.ForeColor = [System.Drawing.Color]::White
    $btnUninstall.FlatStyle = 'Flat'
    $btnUninstall.FlatAppearance.BorderSize = 0
    $btnUninstall.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold)
    $btnUninstall.Enabled = $false
    $form.Controls.Add($btnUninstall)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Location = New-Object System.Drawing.Point(544, 428)
    $btnClose.Size = New-Object System.Drawing.Size(100, 40)
    $btnClose.FlatStyle = 'System'
    $form.Controls.Add($btnClose)
    $btnClose.Add_Click({ $form.Close() })

    function Log([string]$m) {
        # Method arguments are split on commas, so -f only receives the first argument; assemble the whole line first
        $line = '[' + (Get-Date).ToString('HH:mm:ss') + '] ' + $m + "`r`n"
        $logBox.AppendText($line)
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    # Split `bcdedit /enum ...` output into one block per boot entry.
    # Returns @{ Blocks; Raw; Parsed; Ok }; when Ok=$false the caller MUST abort the deletion.
    #
    # [v1.34 ROOT CAUSE - read before touching this]
    # Up to v1.33 this was:   $blocks = $bcdOut -split "(?m)^-{20,}"
    # That 20 was a made-up magic number. bcdedit's separator length equals the header length:
    #     "Windows Boot Manager"  20 chars -> 20 dashes
    #     "Windows Boot Loader"   19 chars -> 19 dashes   <- what /enum osloader prints
    # 19 < 20, so the regex never matched and the osloader dump was NEVER split:
    # the whole output became a single block. Three-step chain reaction:
    #   1) that one big block contains vhd=[C:]\NewSystemDisk.vhdx -> judged an "exact match"
    #   2) the GUID taken is the FIRST `identifier {...}` in the block - not the vhdx entry,
    #      but whichever entry bcdedit printed first, i.e. the PHYSICAL host OS
    #   3) bcdedit /delete on the host OS also removed its winresume, and made bcdedit drop
    #      the default / displayorder elements from {bootmgr}
    #      -> next boot fails with 0xc0000098 "does not contain a valid OS entry"
    # Fix: split on the `identifier {GUID}` line (same approach as the installer and repair
    # tool), so no dash length is involved; then self-check the block count and refuse to
    # delete anything when it does not add up.
    function Split-BcdEntries {
        param([string]$Text)

        $t = [string]$Text
        # Every identifier/标识符 line starts one block. Aliases like {current} count too.
        $idRe = '(?im)^\s*(?:identifier|标识符)\s+\{'
        $out = @([regex]::Split($t, '(?im)^(?=\s*(?:identifier|标识符)\s+\{)') | Where-Object { $_ -match '\S' })

        $raw = ([regex]::Matches($t, $idRe)).Count
        $got = 0
        foreach ($b in $out) { if ($b -match $idRe) { $got++ } }

        # raw must be > 0 (otherwise it is an error message / empty output) and every block
        # must carry exactly one identifier line.
        return @{ Blocks = $out; Raw = $raw; Parsed = $got; Ok = (($raw -gt 0) -and ($raw -eq $got)) }
    }

    $script:Items = @()

    function Refresh-List {
        $listBox.Items.Clear()
        $script:Items = Find-InstalledVhds
        if (@($script:Items).Count -eq 0) {
            $lblInfo.Text = "No installed virtual system found. It may already have been uninstalled."
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(118, 128, 144)
            $btnUninstall.Enabled = $false
            return
        }
        # v1.8: with custom names, one folder may hold several vhdx files,
        # so the first list column shows the system name (the one in the boot menu) and the file path goes on the next line.
        foreach ($it in $script:Items) {
            $label = $it.Desc
            if (-not $label) { $label = $it.Name }
            if (-not $label) { $label = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }
            [void]$listBox.Items.Add("$label    $($it.SizeGB) GB used    $($it.Path)")
        }
        $listBox.SelectedIndex = 0
        $lblInfo.Text = "Found $(@($script:Items).Count). Deleting one erases all of its data, with no way back."
        $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(150, 90, 40)
        $btnUninstall.Enabled = $true
    }

    $listBox.Add_SelectedIndexChanged({
        $btnUninstall.Enabled = ($listBox.SelectedIndex -ge 0 -and @($script:Items).Count -gt 0)
    })

    $btnUninstall.Add_Click({
        if ($listBox.SelectedIndex -lt 0) { return }
        $it = $script:Items[$listBox.SelectedIndex]

        $itName = $it.Desc
        if (-not $itName) { $itName = $it.Name }
        if (-not $itName) { $itName = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }
        $r = [System.Windows.Forms.MessageBox]::Show(
            "About to delete:`n`n$itName`n$($it.Path)`n$($it.SizeGB) GB used`n`n" +
            "All data in this virtual system will be lost, permanently.`n" +
            "Its boot entry is removed from the boot menu as well.`n`n" +
            "The existing system (the one you are using now) is not affected at all.`n`n" +
            "Delete it?",
            'Confirm deletion',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ($r -ne 'Yes') { return }

        $btnUninstall.Enabled = $false
        try {
            Log "=== Uninstall started ==="
            Log "Target: $($it.Path)"

            # 1. Remove the BCD boot entry
            #
            # Prefer deleting by the GUID recorded at install time (Xxx.boot.txt is written since v1.4);
            # only fall back to "scan the whole store for an entry containing the vhdx file name" when no state file exists.
            $fileName = [System.IO.Path]::GetFileName($it.Path)
            $statePath = [System.IO.Path]::ChangeExtension($it.Path, '.boot.txt')
            $stateGuid = ''
            $origTimeout = ''
            $origDisplay = ''
            $origDisplaySet = ''
            $bcdBackup = ''
            if (Test-Path -LiteralPath $statePath) {
                $sd = @{}
                foreach ($ln in (Get-Content -LiteralPath $statePath -Encoding UTF8 -EA SilentlyContinue)) {
                    if ($ln -match '^\s*([^#=]+)=(.*)$') { $sd[$matches[1].Trim()] = $matches[2].Trim() }
                }
                if ($sd['Guid'] -match '^\{[0-9a-fA-F-]{36}\}$') { $stateGuid = $sd['Guid'] }
                if ($sd['OrigTimeout']) { $origTimeout = $sd['OrigTimeout'] }
                if ($sd['OrigDisplayMenu']) { $origDisplay = $sd['OrigDisplayMenu'] }
                # [v1.34] BCD backup exported at install time. Needed by the post-delete
                # self-check below - if the store ends up with no bootable entry, restore it.
                if ($sd['BcdBackup']) { $bcdBackup = $sd['BcdBackup'] }
                # Only present since v1.7: 1 = displaybootmenu really was set before the install, 0 = it did not exist.
                # Old state files lack this key, so leave it empty and let the old logic take the safe direction.
                if ($sd.ContainsKey('OrigDisplayMenuSet')) { $origDisplaySet = [string]$sd['OrigDisplayMenuSet'] }
                Log "State file: entry $stateGuid, original timeout=$origTimeout displaybootmenu=$origDisplay (explicitly written=$origDisplaySet)"
            }

            $removed = 0

            # Delete only the entry pointing at **this one vhdx file**.
            #
            # Comparing file names alone is not enough: this toolkit names every drive root's file NewSystemDisk.vhdx,
            # so with one install on D:\ and another on E: a name-based delete would take out the wrong one.
            # What the installer wrote into the BCD is the full device path vhd=[D:]\NewSystemDisk.vhdx,
            # so match that exact string first and fall back to the file name only when nothing hits.
            $vhdLetter = ''
            $exactDev = ''
            try {
                $vhdLetter = [System.IO.Path]::GetPathRoot($it.Path).TrimEnd('\').TrimEnd(':')
                # [v1.9] The exact string must include the subfolder.
                # Installed to D:\VirtualDisks\maimai.vhdx, the BCD holds vhd=[D:]\VirtualDisks\maimai.vhdx;
                # a string built from the file name alone, vhd=[D:]\maimai.vhdx, never matches, so every run fell back and risked collateral damage.
                $rootLen = [System.IO.Path]::GetPathRoot($it.Path).Length
                $rel = $it.Path.Substring($rootLen).TrimStart('\')
                if ($vhdLetter -and $rel) { $exactDev = "vhd=[$($vhdLetter):]\$rel" }
            } catch {}
            if ($exactDev) { Log "Exact-match target: $exactDev" }

            # [v1.34 safety gate] Before deleting the GUID recorded in the state file,
            # check that it really points at this vhdx.
            #
            # Up to v1.33 this was a blind `bcdedit /delete "$stateGuid" /f`. If the GUID in
            # .boot.txt did not match reality - same vhdx installed more than once, a stale
            # state file, an entry replaced in the meantime - the delete took out somebody
            # else's entry, including the host system's, and the next boot died with
            # 0xc0000098 "The Boot Configuration Data file does not contain a valid OS entry".
            # Rule: reject logical aliases, reject a path mismatch, only delete entries that
            # provably belong to this vhdx.
            if ($stateGuid) {
                if ($stateGuid -match '^\{(?:current|default|bootmgr|fwbootmgr|memdiag|ramdiskoptions)\}$') {
                    Log "Refusing: the state file records the alias $stateGuid - deleting it would remove the running/default system"
                    $stateGuid = ''
                } elseif (-not $exactDev) {
                    Log "Cannot compute the target device path; skipping the record-based delete and falling back to the scan below"
                    $stateGuid = ''
                } else {
                    $probe = (& bcdedit /enum "$stateGuid" /v 2>&1 | Out-String)
                    $probeL = ($probe -replace '[^\x20-\x7E]', '?')
                    $devL = ($exactDev -replace '[^\x20-\x7E]', '?')
                    if ($probe -match '找不到|not found|无效|invalid') {
                        Log "Entry $stateGuid from the record no longer exists, skipping"
                        $stateGuid = ''
                    } elseif ($probeL -notmatch [regex]::Escape($devL)) {
                        Log "Refusing: $stateGuid device is not $exactDev - it may point at the host system, not deleting"
                        $stateGuid = ''
                    }
                }
            }
            if ($stateGuid) {
                $del = & bcdedit /delete "$stateGuid" /f 2>&1 | Out-String
                $t = ($del -replace '\s+', ' ').Trim()
                Log "Deleting $stateGuid from the record => $t"
                if ($del -notmatch '找不到|not found|无效|invalid|拒绝|denied') { $removed++ }
            }

            Log "Looking for boot entries (VHD loader mentioning $fileName)"

            $bcdOut = & bcdedit /enum osloader /v 2>&1 | Out-String
            $split = Split-BcdEntries $bcdOut
            if (-not $split.Ok) {
                # When the parse cannot be trusted, delete nothing. Deleting the wrong entry
                # takes the user's original OS boot entry with it.
                Log "FATAL: cannot reliably parse the bcdedit output ($($split.Raw) entries in the text, only $($split.Parsed) blocks parsed)"
                Log "Refusing to continue: neither the virtual disk nor any boot entry was touched."
                Log "Please send the log above plus the full 'bcdedit /enum osloader /v' output to the author."
                return
            }
            $blocks = $split.Blocks

            # Note: -match refreshes $Matches, so the GUID must be captured before the second match
            $hit = New-Object System.Collections.ArrayList
            if ($exactDev) {
                foreach ($blk in $blocks) {
                    if ($blk -notmatch '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})') { continue }
                    $g = $Matches[1]
                    # [chcp 437] The readback may show "?" where the path has non-ASCII characters,
                    # so mask both sides before the exact match; otherwise the entry is left behind.
                    $looseBlk = ($blk -replace '[^\x20-\x7E]', '?')
                    $looseDev = ($exactDev -replace '[^\x20-\x7E]', '?')
                    if ($looseBlk -match [regex]::Escape($looseDev)) {
                        [void]$hit.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    }
                }
            }

            $matchMode = 'exact path'
            if ($hit.Count -eq 0) {
                # Fallback for when the exact string does not match (e.g. an older version wrote vhd=[D:]\sub\NewSystemDisk.vhdx).
                #
                # The fallback must not grab everything either: with one install per drive the file names are identical,
                # so look among entries with the same drive letter first and delete only those;
                # only when that also fails (the letter changed, e.g. D: became F:) compare by full file name.
                $sameLetter = New-Object System.Collections.ArrayList
                $sameName = New-Object System.Collections.ArrayList
                foreach ($blk in $blocks) {
                    # [bilingual] bcdedit output follows the system language:
                    #   English -> identifier / description, Chinese -> 标识符 / 描述
                    if ($blk -notmatch '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})') { continue }
                    $g = $Matches[1]
                    if (-not (($blk -match '\.vhdx') -or ($blk -match 'vhd='))) { continue }
                    if ($blk -notmatch [regex]::Escape($fileName)) { continue }

                    [void]$sameName.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    if ($vhdLetter -and ($blk -match [regex]::Escape("vhd=[$($vhdLetter):"))) {
                        [void]$sameLetter.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    }
                }
                if ($sameLetter.Count -gt 0) {
                    $matchMode = "same-drive fallback ($($vhdLetter):)"
                    foreach ($x in $sameLetter) { [void]$hit.Add($x) }
                } else {
                    # [v1.34] A file-name-only match is too weak to delete on.
                    # Two drives each holding a NewSystemDisk.vhdx would take each other out.
                    # Leave it to the user to confirm.
                    $matchMode = 'file-name-only fallback (deletion disabled, reporting only)'
                }
            }
            if ($hit.Count -gt 0) { Log "Matched $($hit.Count) boot entries ($matchMode)" }
            if ($matchMode -like 'file-name-only*') {
                Log "WARNING: $($sameName.Count) entries matched on file name alone - cannot prove they belong to this vhdx, so nothing was deleted."
                foreach ($x in $sameName) { Log "        candidate $($x.Guid)" }
                Log "      If you are certain, delete manually: bcdedit /delete {GUID} /f"
            }

            foreach ($h in $hit) {
                $desc = ''
                if ($h.Block -match '(?:description|描述)\s+(.+?)\r?\n') { $desc = $Matches[1].Trim() }
                Log "Found boot entry: $($h.Guid)  $desc"
                $del = & bcdedit /delete "$($h.Guid)" /f 2>&1 | Out-String
                Log "Delete: $(($del -replace '\s+', ' ').Trim())"
                if ($del -notmatch '找不到|not found|无效|invalid|拒绝|denied') { $removed++ }
            }
            Log "Removed $removed boot entries in total"

            # [v1.34 safety gate] After deleting, prove the machine can still boot.
            #
            # Up to v1.33 the code only counted how many entries were left, to decide whether
            # to switch the menu off; it never checked whether {bootmgr} default still pointed
            # at an existing entry. A dangling default plus zero real osloader entries means
            # the next boot dies with 0xc0000098 "The Boot Configuration Data file does not
            # contain a valid OS entry" - not even a menu.
            #
            # Two things happen here:
            #  1) collect the entries that are still genuinely bootable (skip WinRE / recovery / memdiag)
            #  2) default not among them -> repoint it at a live system; nothing left -> restore the
            #     backup taken at install time
            $aliveGuids = New-Object System.Collections.ArrayList
            $bmDefault = ''
            $selfCheckOk = $false
            try {
                $afterRaw = (& bcdedit /enum osloader /v 2>&1 | Out-String)
                $spAfter = Split-BcdEntries $afterRaw
                if ($spAfter.Ok) {
                    $selfCheckOk = $true
                    foreach ($ab in $spAfter.Blocks) {
                        if ($ab -notmatch '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})') { continue }
                        $g = $Matches[1]
                        if ($ab -match '(?im)^\s*device\s+ramdisk=') { continue }
                        if ($ab -match '(?im)(?:description|描述)\s+.*(?:Recovery|恢复|内存诊断|Memory Diagnostic|Windows Boot Manager)') { continue }
                        if ($ab -notmatch '(?im)(?:device|osdevice)\s+(?:partition=|vhd=)') { continue }
                        if ($aliveGuids -notcontains $g) { [void]$aliveGuids.Add($g) }
                    }
                } else {
                    Log "WARNING: post-delete self-check cannot parse the bcdedit output ($($spAfter.Raw) in text / $($spAfter.Parsed) parsed), skipping the automatic decision"
                }
                $bmRaw = (& bcdedit /enum '{bootmgr}' /v 2>&1 | Out-String)
                $dm = [regex]::Match($bmRaw, '(?im)^\s*(?:default|默认)\s+(\{[0-9a-fA-F\-]+\})')
                if ($dm.Success) { $bmDefault = $dm.Groups[1].Value }
            } catch {
                Log "Post-delete self-check failed: $($_.Exception.Message)"
            }

            Log "Self-check: $($aliveGuids.Count) bootable system(s) left, default=$bmDefault"
            if (-not $selfCheckOk) {
                # Never touch the BCD on unreliable data: no guessing the default, no /import
                # (an import overwrites the whole store).
                Log "FATAL: self-check data is unreliable, skipped both the default repair and the backup restore. Verify 'bcdedit /enum' by hand."
            } elseif (-not ($bmDefault -and ($aliveGuids -contains $bmDefault))) {
                if ($aliveGuids.Count -gt 0) {
                    $fix = $aliveGuids[0]
                    & bcdedit /set '{bootmgr}' default $fix 2>&1 | Out-Null
                    Log "WARNING: default pointed at $bmDefault (gone); repointed to $fix - otherwise the next boot shows 0xc0000098"
                } else {
                    Log "CRITICAL: no bootable system is left in the store"
                    if ($bcdBackup -and (Test-Path -LiteralPath $bcdBackup)) {
                        Log "Restoring the BCD backup exported at install time: $bcdBackup"
                        $imp = & bcdedit /import "$bcdBackup" 2>&1 | Out-String
                        Log ("Restore result: " + (($imp -replace '\s+', ' ').Trim()))
                        Log "Backup restored (pre-install state). Reboot to confirm the original system still boots, then clean up leftovers by hand"
                    } else {
                        Log "No BCD backup available, manual repair required:"
                        Log "  Boot the Windows installation media -> Repair your computer -> Command Prompt -> bootrec /rebuildbcd"
                    }
                }
            }

            # Count how many systems remain after deletion, to decide whether the menu must stay enabled.
            # [v1.34] Reuse the "genuinely bootable" list collected by the self-check above instead of
            # running bcdedit a third time: the old code used the same -{20,} magic-number split, and
            # when that never split anything it always counted 1 - and then switched the menu off.
            if (-not $selfCheckOk) {
                # On unreliable data assume "another system exists" and keep the menu visible:
                # an extra menu entry is harmless, a hidden one makes the remaining system unreachable.
                $left = 2
            } else {
                $left = $aliveGuids.Count
            }
            Log "Boot entries left: $left"

            # Restore the boot menu: the install may have changed displaybootmenu / timeout,
            # so restore the original values recorded in the state file (not a hard-coded timeout==0).
            if ($removed -gt 0) {
                # [v1.13] Never switch the menu off while another system remains on the machine.
                #
                # The old logic unconditionally restored "the pre-install displaybootmenu / timeout" from the state file.
                # With two VHDX systems installed and only one uninstalled, the remaining entry
                # was still in the BCD, yet the menu was restored to "off / timeout 0" -
                # the user saw "after reboot only the original system is in the menu, the other one is unreachable".
                #
                # The criterion is "how many real systems remain after deletion" ($left already excludes recovery partitions):
                #   >= 2 -> there is something to choose, the menu must stay enabled; = 1 -> only the original system, restore as it was.
                $keepMenu = ($left -ge 2)
                if ($keepMenu) {
                    & bcdedit /set '{bootmgr}' displaybootmenu Yes 2>&1 | Out-Null
                    $t2 = 10
                    if ($origTimeout -match '^\d+$' -and [int]$origTimeout -gt 0) { $t2 = [int]$origTimeout }
                    & bcdedit /set '{bootmgr}' timeout $t2 2>&1 | Out-Null
                    Log "$left systems remain, keeping the boot menu visible (displaybootmenu=Yes, timeout=$t2); otherwise the remaining systems are unreachable"
                } else {
                    if ($origTimeout -ne '') {
                        & bcdedit /set '{bootmgr}' timeout $origTimeout 2>&1 | Out-Null
                        Log "Restored the boot menu timeout to $origTimeout"
                    }
                    if ($origDisplay -eq 'Yes') {
                        & bcdedit /set '{bootmgr}' displaybootmenu Yes 2>&1 | Out-Null
                        Log "Restored displaybootmenu to Yes (the menu was explicitly enabled before the install)"
                    } elseif ($origDisplaySet -eq '1' -and $origDisplay -eq 'No') {
                        & bcdedit /set '{bootmgr}' displaybootmenu No 2>&1 | Out-Null
                        Log "Restored displaybootmenu to No (it was explicitly disabled before the install)"
                    } else {
                        # When displaybootmenu did not exist in the BCD before the install, use /deletevalue to restore "not set"
                        # instead of forcing No:
                        #   - single system: not set = bootmgr never showed a menu -> still boots the original system directly
                        #   - multi system:  not set = the menu shows normally -> the user's original dual-boot menu survives
                        $dv = & bcdedit /deletevalue '{bootmgr}' displaybootmenu 2>&1 | Out-String
                        Log ("Cleared the displaybootmenu setting, restored the system default => " + (($dv -replace '\s+', ' ').Trim()))
                    }
                }
            }

            # Clear a leftover one-shot bootsequence: this value is normally cleared by winload
            # after the first boot, but stays behind when a boot is interrupted - the menu is then short-circuited
            # and everything restored above is wasted. Clear it once at the end of the uninstall; when absent, skip silently.
            try {
                $bsRaw = (& bcdedit /enum '{bootmgr}' 2>&1 | Out-String)
                if ($bsRaw -match '(?im)^\s*bootsequence\s') {
                    $bsDel = & bcdedit /deletevalue '{bootmgr}' bootsequence 2>&1 | Out-String
                    Log ("Found a leftover bootsequence (one-shot) and cleared it => " + (($bsDel -replace '\s+', ' ').Trim()))
                }
            } catch {}

            # 2. Delete the vhdx
            if (Test-Path -LiteralPath $it.Path) {
                Log "Deleting file: $($it.Path)"
                Remove-Item -LiteralPath $it.Path -Force -EA Stop
                Log "File deleted"
            }
            if (Test-Path -LiteralPath $statePath) {
                Remove-Item -LiteralPath $statePath -Force -EA SilentlyContinue
            }

            # 3. Release drive letters the installer/repair tool may have left behind on the physical ESP
            #
            # The old repair tool (v1.0) assigned a drive letter to the physical ESP (usually S:) to read/write the BCD.
            # After switching to the active store a drive letter is no longer needed, but an early one may never have been released,
            # which shows up as "S: still lingers after uninstalling".
            # This scans every partition: anything that is an "EFI system partition (GUID c12a7328-...) holding
            # a non-system drive letter" is a leftover, so release it (no data touched, only the access path removed).
            $espGuid = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
            $sysLetter = $env:SystemDrive.TrimEnd(':')
            $released = 0
            foreach ($part in (Get-Partition -EA SilentlyContinue)) {
                if (-not $part.DriveLetter) { continue }
                $gpt = [string]$part.GptType
                $gpt = ($gpt -replace '[{}]', '').ToLower()
                if ($gpt -ne $espGuid) { continue }
                if ([string]$part.DriveLetter -eq $sysLetter) { continue }
                $dl = [string]$part.DriveLetter
                try {
                    # Use -DriveLetter rather than -AccessPath "S:":
                    # -AccessPath expects a volume access path (like "S:\"), "S:" is rejected as invalid;
                    # and catch only logs one line, so the letter stayed while the user believed it was cleaned.
                    Remove-PartitionAccessPath -DiskNumber $part.DiskNumber `
                        -PartitionNumber $part.PartitionNumber -DriveLetter $dl -EA Stop | Out-Null
                    Log "Released the leftover ESP drive letter $dl`:"
                    $released++
                } catch {
                    Log "Failed to release drive letter $dl (remove it manually in Disk Management): $($_.Exception.Message)"
                }
            }
            if ($released -eq 0) { Log "No leftover ESP drive letters found" }

            Log "=== Uninstall complete ==="
            [System.Windows.Forms.MessageBox]::Show(
                "Uninstall complete.`n`nThe virtual hard disk is deleted and the boot entry removed.`n`n""$itName"" will no longer appear in the boot menu.`n" +
                "(If one entry is still listed, it can be ignored, or reboot once and it cleans itself up.)",
                'Done',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

            Refresh-List
        } catch {
            Log "Failed: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "Deletion failed:`n`n$_`n`n" +
                "The file may be in use. Suggestions:`n" +
                "  1. Reboot and run this tool right away`n" +
                "  2. Or delete the file manually`n`n" +
                "The boot entry can be cleaned up with:`n" +
                "  bcdedit /enum osloader`n" +
                "  bcdedit /delete {matching GUID} /f",
                'Deletion failed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        } finally {
            $btnUninstall.Enabled = ($listBox.SelectedIndex -ge 0)
        }
    })

    $form.Add_Shown({
        if (-not (Test-Admin)) {
            $r = [System.Windows.Forms.MessageBox]::Show(
                "Uninstalling requires administrator rights. Click Yes to restart elevated.",
                'Administrator rights required',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($r -eq 'Yes') {
                if (Request-Admin) { $form.Close(); return }
            }
            $lblInfo.Text = "Administrator rights missing, deletion may fail"
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(190, 90, 60)
        }
        Log "Uninstall tool start v$($Script:Version)"
        Refresh-List

        # [safety gate] Uninstalling is blocked while running inside the new system (see the Test-RunningInVhd comments)
        if (Test-RunningInVhd) {
            $btnUninstall.Enabled = $false
            $lblInfo.Text = "Currently running inside the new system - reboot into the original system and uninstall there."
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(190, 60, 60)
            Log "Detected that the current system runs from a virtual disk, deletion disabled"
            [System.Windows.Forms.MessageBox]::Show(
                "You are running this tool inside the new system.`n`n" +
                "Uninstalling must be done from the original system: a delete from here only touches the new system's own boot configuration,`n" +
                "and the entry in the boot menu stays.`n`n" +
                "Please reboot, choose the original system in the boot menu, and run this tool again.",
                'Uninstall from the original system',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    })

    [void]$form.ShowDialog()
}

try {
    Show-Gui
} catch {
    Write-Host "Start failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
