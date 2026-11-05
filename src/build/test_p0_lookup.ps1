# test_p0_lookup.ps1 - unit test for Resolve-VhdDisk (audit P0-1).
#
# The function is pulled straight out of the real source with the AST, so this tests the shipped
# code and not a copy of it. Install-To-VHD.ps1 cannot simply be dot-sourced (that would start the
# installer), which is why the definition is extracted first.
#
# Usage: & test_p0_lookup.ps1 -Ps1 <path to Install-To-VHD.ps1>

param([string]$Ps1 = '')

$ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref]$null, [ref]$null)
$fn = $ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Resolve-VhdDisk'
}, $true)
if (-not $fn -or $fn.Count -eq 0) { throw 'Resolve-VhdDisk not found in the source' }
. ([scriptblock]::Create($fn[0].Extent.Text))

$disksBoth = @(
    [pscustomobject]@{ Number = 1; Location = 'D:\A\WinVHD.vhdx' },
    [pscustomobject]@{ Number = 2; Location = 'E:\Backup\WinVHD.vhdx' }
)
$disksOne = @( [pscustomobject]@{ Number = 3; Location = 'D:\A\WinVHD.vhdx' } )
$disksPrefix = @( [pscustomobject]@{ Number = 4; Location = '\\?\D:\A\WinVHD.vhdx' } )

$cases = @(
    @{ Name = 'exact full path wins over a same-named disk elsewhere'; Vhd = 'D:\A\WinVHD.vhdx'; Disks = $disksBoth; Expect = 'disk:1' }
    @{ Name = 'path matched case-insensitively'; Vhd = 'd:\a\winvhd.vhdx'; Disks = $disksBoth; Expect = 'disk:1' }
    @{ Name = 'Location with the \\?\ prefix'; Vhd = 'D:\A\WinVHD.vhdx'; Disks = $disksPrefix; Expect = 'disk:4' }
    @{ Name = 'two same-named disks, neither is the path -> refuse'; Vhd = 'D:\B\WinVHD.vhdx'; Disks = $disksBoth; Expect = 'throw' }
    @{ Name = 'one disk, unique file name -> accept'; Vhd = 'D:\Other\WinVHD.vhdx'; Disks = $disksOne; Expect = 'disk:3' }
    @{ Name = 'no candidate -> null'; Vhd = 'D:\A\Different.vhdx'; Disks = $disksOne; Expect = 'null' }
    @{ Name = 'empty path -> null'; Vhd = ''; Disks = $disksOne; Expect = 'null' }
)

$fail = 0
foreach ($c in $cases) {
    $got = '?'
    try {
        $v = Resolve-VhdDisk -VhdPath $c.Vhd -Disks $c.Disks
        $got = if ($null -eq $v) { 'null' } else { 'disk:' + $v.Number }
    } catch {
        $got = 'throw'
    }
    if ($got -eq $c.Expect) {
        Write-Output ("  OK   {0}" -f $c.Name)
    } else {
        Write-Output ("  FAIL {0}  (expected {1}, got {2})" -f $c.Name, $c.Expect, $got)
        $fail++
    }
}
if ($fail -eq 0) { Write-Output 'P0 LOOKUP: OK' } else { Write-Output ("P0 LOOKUP: {0} failure(s)" -f $fail) }
