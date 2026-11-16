# Unit test for the text helpers in src/shared/<lang>/BcdVerify.ps1.
#
# The functions are pulled straight out of the shipped module with the AST, so this tests
# the code that actually runs (the module is inlined into every launcher at build time).
#
# Covers the regressions that cost data or made a gate lie:
#   1. v1.32 - bcdedit readback through the console code page (chcp 437) turns Chinese
#              characters into "?", and a correct write was reported as a wrong path.
#   2. v1.36 - the device value has to be extracted per entry. Masking both sides and
#              substring-matching the whole block matched any line in it and made two
#              different Chinese folders look identical.
#   3. v1.36 - "delete failed" was counted as success because the check looked for Chinese
#              words in output that the launcher had already turned into mojibake.
#   4. v1.36 - the vhdx was deleted even when no boot entry could be proven to be its own,
#              leaving a menu entry that points at a file which no longer exists.
#   5. v1.36 - the post-delete self-check demanded the literal word "device"; on a system that
#              localizes it ("设备") every entry was skipped.
param([string]$Ps1 = '')

$ErrorActionPreference = 'Stop'
if (-not $Ps1) {
    $Ps1 = Join-Path (Split-Path -Parent $PSScriptRoot) (Join-Path 'shared' (Join-Path 'en' 'BcdVerify.ps1'))
}
if (-not (Test-Path -LiteralPath $Ps1)) { Write-Output "FAIL: module not found: $Ps1"; exit 1 }

$ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref]$null, [ref]$null)
foreach ($name in @('Test-BcdTextSame', 'Get-BcdDeviceFromOutput', 'Test-BcdBlockIsLoader',
                    'Remove-BcdEntry', 'Get-UninstallDeleteVerdict', 'Get-BcdOutputExact')) {
    $fn = $ast.Find({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name
    }, $true)
    if (-not $fn) { Write-Output "FAIL: $name not found in $Ps1"; exit 1 }
    . ([scriptblock]::Create($fn.Extent.Text))
}

$fail = 0
function Chk([string]$name, [bool]$got, [bool]$expect) {
    if ($got -eq $expect) { Write-Output ("  OK   {0}" -f $name) }
    else { Write-Output ("  FAIL {0}: expected {1}, got {2}" -f $name, $expect, $got); $script:fail++ }
}
function ChkEq([string]$name, $got, $expect) {
    if ("$got" -eq "$expect") { Write-Output ("  OK   {0}" -f $name) }
    else { Write-Output ("  FAIL {0}: expected [{1}], got [{2}]" -f $name, $expect, $got); $script:fail++ }
}

$zh = @{}
$zh.Vhd = [string][char]0x865a + [char]0x62df + [char]0x78c1 + [char]0x76d8     # 虚拟磁盘
$zh.Dev = [string][char]0x8bbe + [char]0x5907                                   # 设备
$zh.Desc = [string][char]0x63cf + [char]0x8ff0                                  # 描述

# ---- Test-BcdTextSame: one tolerance only, a "?" over a non-ASCII character
$p = 'D:\' + $zh.Vhd + '\Windows 10 ' + [char]0x4e13 + [char]0x4e1a + [char]0x7248 + '.vhdx'
$masked = 'D:\????\Windows 10 ???.vhdx'
Chk 'identical'                 (Test-BcdTextSame $p $p) $true
Chk 'masked by console code page' (Test-BcdTextSame $p $masked) $true
Chk 'case differs (drive letter)' (Test-BcdTextSame $p $p.ToUpper()) $true
Chk 'length differs'            (Test-BcdTextSame $p 'D:\????\Windows 10 ??.vhdx') $false
Chk 'different drive letter'    (Test-BcdTextSame $p 'E:\????\Windows 10 ???.vhdx') $false
Chk 'different ASCII text'      (Test-BcdTextSame $p 'D:\????\Linux 10 ???.vhdx') $false
Chk 'mask where ASCII expected' (Test-BcdTextSame 'D:\VHD\a.vhdx' 'D:\VHD\?.vhdx') $false
Chk 'plain ASCII path'          (Test-BcdTextSame 'D:\VHD\a.vhdx' 'D:\VHD\a.vhdx') $true
Chk 'empty readback'            (Test-BcdTextSame 'D:\VHD\a.vhdx' '') $false

# ---- Get-BcdDeviceFromOutput: only the vhd= value, whatever the label says
$blockEn = "Windows Boot Loader`r`n-------------------`r`nidentifier              {11111111-2222-3333-4444-555555555555}`r`ndevice                  vhd=[D:]\VirtualDisks\Game.vhdx`r`npath                    \Windows\system32\winload.efi`r`n"
Chk 'english label'   ((Get-BcdDeviceFromOutput -Text $blockEn) -eq 'vhd=[D:]\VirtualDisks\Game.vhdx') $true
$blockZh = "Windows 启动加载器`r`n-------------`r`n标识符                  {11111111-2222-3333-4444-555555555555}`r`n" + $zh.Dev + "                  vhd=[D:]\VirtualDisks\Game.vhdx`r`npath                    \Windows\system32\winload.efi`r`n"
Chk 'chinese label'   ((Get-BcdDeviceFromOutput -Text $blockZh) -eq 'vhd=[D:]\VirtualDisks\Game.vhdx') $true
$blockPart = "Windows Boot Loader`r`n-------------------`r`nidentifier              {11111111-2222-3333-4444-555555555555}`r`ndevice                  partition=C:`r`npath                    \Windows\system32\winload.exe`r`n"
Chk 'rewritten to partition=' ((Get-BcdDeviceFromOutput -Text $blockPart) -eq '') $true
Chk 'no device line'  ((Get-BcdDeviceFromOutput -Text 'identifier {1111}') -eq '') $true
# The block must not have its vhd= taken from a description or a path line
$blockTrap = "identifier              {11111111-2222-3333-4444-555555555555}`r`npath                    \Windows\system32\winload.efi`r`n"
Chk 'no false positive from other lines' ((Get-BcdDeviceFromOutput -Text $blockTrap) -eq '') $true

# ---- Test-BcdBlockIsLoader: the label is localized, so only the value is matched
Chk 'loader: english device + vhd'  (Test-BcdBlockIsLoader -Text $blockEn) $true
Chk 'loader: chinese label + vhd'   (Test-BcdBlockIsLoader -Text $blockZh) $true
Chk 'loader: english partition='    (Test-BcdBlockIsLoader -Text $blockPart) $true
Chk 'loader: chinese partition='    (Test-BcdBlockIsLoader -Text ("标识符  {1111}`r`n" + $zh.Dev + "  partition=C:`r`npath  \windows\system32\winload.exe`r`n")) $true
Chk 'not a loader: recovery ramdisk' (Test-BcdBlockIsLoader -Text "identifier {1111}`r`ndevice          ramdisk=[C:]\Recovery\Winre.wim,{2222}`r`n") $false
Chk 'not a loader: path only'        (Test-BcdBlockIsLoader -Text $blockTrap) $false

# ---- Get-UninstallDeleteVerdict: when may the vhdx be deleted?
Chk 'verdict: nothing matched -> delete'        ((Get-UninstallDeleteVerdict).Allow) $true
Chk 'verdict: an entry was removed -> delete'   ((Get-UninstallDeleteVerdict -Removed 1).Allow) $true
Chk 'verdict: matched but not deleted -> keep'  ((Get-UninstallDeleteVerdict -HitCount 2).Allow) $false
Chk 'verdict: same-name candidates -> keep'     ((Get-UninstallDeleteVerdict -CandidateCount 3).Allow) $false
Chk 'verdict: recorded entry mismatched -> keep' ((Get-UninstallDeleteVerdict -StateRefused $true).Allow) $false
Chk 'verdict: removed wins over candidates'     ((Get-UninstallDeleteVerdict -Removed 1 -CandidateCount 3).Allow) $true
Chk 'verdict: reason is never empty when blocked' (([string](Get-UninstallDeleteVerdict -HitCount 1).Reason).Length -gt 0) $true

# ---- Remove-BcdEntry: the exit code decides, not the words in the output
# A stub stands in for bcdedit: this is exactly the v1.36 bug - the output has no Chinese
# keyword in it (the launcher's chcp turned it into mojibake), so the old check counted a
# failed delete as a success.
$tmp = Join-Path $env:TEMP ("bcdstub_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$stubFail = Join-Path $tmp 'fail.cmd'
$stubOk = Join-Path $tmp 'ok.cmd'
Set-Content -LiteralPath $stubFail -Encoding Ascii -Value @('@echo off', 'echo ??? ?? ??????', 'exit /b 1')
Set-Content -LiteralPath $stubOk -Encoding Ascii -Value @('@echo off', 'echo The operation completed successfully.', 'exit /b 0')
$r1 = Remove-BcdEntry -Guid '{11111111-1111-1111-1111-111111111111}' -BcdExe $stubFail
$r2 = Remove-BcdEntry -Guid '{11111111-1111-1111-1111-111111111111}' -BcdExe $stubOk
Chk 'delete: exit 1 with no keyword -> not ok' ($r1.Ok) $false
ChkEq 'delete: exit 1 keeps the code' $r1.Code 1
Chk 'delete: exit 0 -> ok' ($r2.Ok) $true

# ---- Get-BcdOutputExact: it must report failure instead of pretending to have read something
$exBad = Get-BcdOutputExact -BcdArgs @('/enum') -BcdExe (Join-Path $tmp 'does-not-exist.exe')
Chk 'exact read: missing exe -> Ok=false' ($exBad.Ok) $false
$stubEcho = Join-Path $tmp 'echo.cmd'
Set-Content -LiteralPath $stubEcho -Encoding Ascii -Value @('@echo off', 'echo BCDSTUB_MARKER', 'exit /b 0')
$exOk = Get-BcdOutputExact -BcdArgs @('/enum') -BcdExe $stubEcho
Chk 'exact read: real call -> Ok=true' ($exOk.Ok) $true
Chk 'exact read: text comes through' (($exOk.Text -match 'BCDSTUB_MARKER')) $true
Remove-Item -LiteralPath $tmp -Recurse -Force -EA SilentlyContinue

Write-Output ("{0} failed" -f $fail)
if ($fail -gt 0) { exit 1 }
