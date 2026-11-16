# Syntax check every .ps1 in the repo, without running any of it.
#
# The installer cannot be executed on a build machine (it wants admin, an image and a
# virtual disk), so a parse is the cheapest thing that catches a broken edit before it
# ships. Exit code 1 when anything fails to parse.
param([string]$Root = '')

$ErrorActionPreference = 'Stop'
# This script lives in <repo>\src\build, so the source root is its parent folder.
# (The first version joined 'src' onto that parent and therefore scanned nothing at
#  all - it printed "0 file(s) parsed, 0 with errors" and exited 0. A gate that checks
#  nothing must never look green, hence the guard at the bottom.)
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path -LiteralPath $Root)) {
    Write-Output ("FAIL root not found: {0}" -f $Root)
    exit 1
}

$files = @(Get-ChildItem -Path $Root -Recurse -Filter *.ps1 -File)
if ($files.Count -eq 0) {
    Write-Output ("FAIL no .ps1 found under {0}" -f $Root)
    exit 1
}
$bad = 0
foreach ($f in $files) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        $bad++
        foreach ($e in $errs) {
            Write-Output ("FAIL {0}:{1}  {2}" -f $f.Name, $e.Extent.StartLineNumber, $e.Message)
        }
    }
}
Write-Output ("{0} file(s) parsed, {1} with errors" -f $files.Count, $bad)
if ($bad -gt 0) { exit 1 }
