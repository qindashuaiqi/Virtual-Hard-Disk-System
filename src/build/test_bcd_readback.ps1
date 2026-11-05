# Unit test for Test-BcdTextSame: extracted from the real script by AST, so the
# shipped code is what is tested (never a copy that can drift).
#
# Covers the regression that aborted a finished install: bcdedit readback through the
# console code page (chcp 437) turns Chinese characters into "?".
param([string]$Ps1)

$ErrorActionPreference = 'Stop'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Ps1, [ref]$null, [ref]$null)
$fn = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-BcdTextSame'
}, $true)
if (-not $fn) { Write-Output "FAIL: Test-BcdTextSame not found in $Ps1"; exit 1 }
. ([scriptblock]::Create($fn.Extent.Text))

$p = 'D:\' + [char]0x865a + [char]0x62df + [char]0x78c1 + [char]0x76d8 + '\Windows 10 ' + [char]0x4e13 + [char]0x4e1a + [char]0x7248 + '.vhdx'
$masked = 'D:\????\Windows 10 ???.vhdx'
$cases = @(
    @{ Want = $p;          Got = $p;                                  Expect = $true;  Name = 'identical' },
    @{ Want = $p;          Got = $masked;                             Expect = $true;  Name = 'masked by console code page' },
    @{ Want = $p;          Got = $p.ToUpper();                        Expect = $true;  Name = 'case differs (drive letter)' },
    @{ Want = $p;          Got = 'D:\????\Windows 10 ??.vhdx';        Expect = $false; Name = 'length differs' },
    @{ Want = $p;          Got = 'E:\????\Windows 10 ???.vhdx';       Expect = $false; Name = 'different drive letter' },
    @{ Want = $p;          Got = 'D:\????\Linux 10 ???.vhdx';         Expect = $false; Name = 'different ASCII text' },
    @{ Want = 'D:\VHD\a.vhdx'; Got = 'D:\VHD\?.vhdx';                 Expect = $false; Name = 'mask where ASCII expected' },
    @{ Want = 'D:\VHD\a.vhdx'; Got = 'D:\VHD\a.vhdx';                 Expect = $true;  Name = 'plain ASCII path' },
    @{ Want = 'D:\VHD\a.vhdx'; Got = '';                              Expect = $false; Name = 'empty readback' }
)

$fail = 0
foreach ($c in $cases) {
    $got = Test-BcdTextSame $c.Want $c.Got
    if ([bool]$got -eq [bool]$c.Expect) {
        Write-Output ("  OK   {0}" -f $c.Name)
    } else {
        Write-Output ("  FAIL {0}: expected {1}, got {2}" -f $c.Name, $c.Expect, $got)
        $fail++
    }
}
Write-Output ("{0} passed, {1} failed" -f ($cases.Count - $fail), $fail)
if ($fail -gt 0) { exit 1 }
