# ============================================================
# BCD helpers shared by the installer, the uninstaller, the repair tool and the
# "fix boot entry device" tool.
#
# This file is inlined into every launcher at build time (a released .bat is one
# self-extracting file carrying a single ps1 payload), so a function defined here ends
# up inside each script that references it - while the source still has exactly ONE copy.
#
# Reference it from a script with:
#     . "$PSScriptRoot\..\shared\en\BcdVerify.ps1"
# ============================================================

# Compare the wanted device path with what bcdedit printed back.
#
# The console code page cannot display every character: a Chinese folder name comes back
# as "?" and a byte-level comparison fails although the write was fine. This accepts a
# "?" exactly where the wanted character is non-ASCII - and nothing else: the length must
# match and every ASCII character must be identical.
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

# The device line is the only line carrying "vhd=[". The label in front of it reads
# "device", "Gerät", "デバイス" or "设备" depending on the system language, so the label is
# never matched - only the value.
function Get-BcdDeviceFromOutput {
    param([string]$Text)
    $m = [regex]::Match([string]$Text, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value.Trim()
}

# [v1.36] Is this block a real OS loader (as opposed to a Recovery / memdiag / WinRE stub)?
#
# The label in front of the value is localized - "device", "设备", "Gerät", "デバイス" - so the
# label is never matched, only the value. The old check demanded the literal word "device" and
# therefore skipped every entry on a system that localizes it; the post-delete self-check then
# believed no bootable system was left and restored the BCD backup over a healthy store.
function Test-BcdBlockIsLoader {
    param([string]$Text)
    if (Get-BcdDeviceFromOutput -Text $Text) { return $true }        # any vhd= entry
    return [bool]([regex]::IsMatch([string]$Text, '(?im)^[^\r\n]*?\bpartition=[^\s\r\n]+'))
}

# [v1.36] Delete one boot entry, and say whether it really went away.
#
# The old call sites decided success by searching the output for words like "not found" /
# "找不到" / "invalid". With the console code page pinned to 437 (what the English launcher
# does) a Chinese bcdedit prints mojibake, none of those words match, so a FAILED delete was
# counted as a success - and the uninstaller went on to delete the vhdx, leaving a boot menu
# entry that points at a file which no longer exists (0xc000000f on the next boot).
#
# The exit code does not depend on the system language: 0 = deleted, non-zero = not deleted.
function Remove-BcdEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Guid,
        # Only the unit test passes something else (a stub that exits non-zero).
        [string]$BcdExe = 'bcdedit.exe'
    )
    $res = [PSCustomObject]@{ Ok = $false; Code = -1; Text = '' }
    try {
        $out = (& $BcdExe /delete "$Guid" /f 2>&1 | Out-String)
        $res.Code = $LASTEXITCODE
        $res.Text = (($out -replace '\s+', ' ').Trim())
        $res.Ok = ($res.Code -eq 0)
    } catch {
        $res.Text = $_.Exception.Message
    }
    return $res
}

# [v1.36] May the vhdx be deleted once the boot-entry pass is over?
#
# v1.35 deleted the file unconditionally. When the pass above had just decided "cannot prove
# which entry belongs to this vhdx, nothing was deleted", the result was a file that was gone
# and a menu entry that still pointed at it - 0xc000000f on the next boot.
#
# Rule: delete only when nothing points at the file (nothing matched at all), or when an entry
# was actually removed. "Matched but could not delete", "several candidates with the same name"
# and "the recorded entry no longer matches" all mean: stop, keep the disk.
function Get-UninstallDeleteVerdict {
    param(
        [int]$Removed = 0,
        [int]$HitCount = 0,
        [int]$CandidateCount = 0,
        [bool]$StateRefused = $false
    )
    if ($Removed -gt 0) {
        return [PSCustomObject]@{ Allow = $true; Reason = '' }
    }
    if ($HitCount -gt 0) {
        return [PSCustomObject]@{ Allow = $false; Reason = "matched $HitCount boot entr(ies) but could not delete any of them" }
    }
    if ($CandidateCount -gt 0) {
        return [PSCustomObject]@{ Allow = $false; Reason = "$CandidateCount boot entr(ies) carry the same file name, but none could be proven to be this vhdx" }
    }
    if ($StateRefused) {
        return [PSCustomObject]@{ Allow = $false; Reason = 'the entry recorded in .boot.txt does not point at this vhdx any more' }
    }
    return [PSCustomObject]@{ Allow = $true; Reason = 'no boot entry references this file' }
}

# [v1.36] Run bcdedit so that a non-ASCII path survives verbatim.
#
# Measured 2026-11-13 (Windows 10 22H2 zh-CN, Windows PowerShell 5.1):
#   * a console program whose stdout is redirected writes ANSI bytes (GBK here), while
#     PowerShell decodes them with [Console]::OutputEncoding;
#   * the English launcher runs "chcp 437", so the two disagreed and every Chinese
#     character came back as "?" or as two mojibake characters per character;
#   * assigning [Console]::OutputEncoding also switches the console code page (the .NET
#     setter calls SetConsoleOutputCP), so pointing it at the ANSI code page puts the
#     writer and the reader on the same encoding.
#
# Returns @{ Ok; Text; CodePage }. Ok=$false means bcdedit could not be started or printed
# nothing - the caller must fall back to a plain call, never read that as "wrong path".
function Get-BcdOutputExact {
    param(
        [string[]]$BcdArgs,
        # Only the unit test passes something else.
        [string]$BcdExe = 'bcdedit.exe'
    )
    $out = @{ Ok = $false; Text = ''; CodePage = 0 }
    $cp = 0
    try { $cp = [System.Text.Encoding]::Default.CodePage } catch {}
    if ($cp -le 0) { $cp = 437 }
    $oldEnc = $null
    try {
        try { $oldEnc = [Console]::OutputEncoding } catch {}
        if ($oldEnc) {
            try { [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($cp) }
            catch { $cp = $oldEnc.CodePage }
        }
        $txt = (& $BcdExe @BcdArgs 2>&1 | Out-String)
        if ($txt -and $txt.Length -gt 0) { $out.Ok = $true; $out.Text = $txt }
    } catch {
        $out.Ok = $false
    } finally {
        if ($oldEnc) { try { [Console]::OutputEncoding = $oldEnc } catch {} }
    }
    $out.CodePage = $cp
    return $out
}
