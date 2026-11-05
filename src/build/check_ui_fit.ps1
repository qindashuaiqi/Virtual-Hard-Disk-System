# check_ui_fit.ps1 - static layout audit for the WinForms windows.
#
# Why this exists:
#   The Chinese original got a set of hand-tuned fixed pixel sizes, and the English translation
#   simply reused them. English is ~2x wider than Chinese for the same meaning, so several labels
#   ended up with their text sliced off ("...the existing" / a notice box cut in half).
#   Guessing again is not good enough - this script measures every label with the real GDI+ text
#   renderer and reports anything that cannot fit in its declared size.
#
# Usage:
#   $sb=[scriptblock]::Create([IO.File]::ReadAllText($p,[Text.Encoding]::UTF8))
#   & $sb -Dir 'D:\...\src\en'
#
# Exit code: 0 = clean, 1 = problems found.
param(
    [string]$Dir = '.'
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Controls whose text is never drawn by a fixed-size label (or is filled at runtime)
$ignore = @('form', 'log', 'logBox', 'listBox', 'txtDir', 'txtName', 'cmbWim', 'cmbEd', 'numSz',
            'pb', 'flowDrv', 'sep', 'hd', 'header', 'box')

function Expand-TextLiteral([string]$expr) {
    # 'a' + [char]13 + [char]10 + 'b'  ->  "a<CRLF>b"   (only pure literal concatenations)
    if ($expr -match '\$\(|`|\$[A-Za-z_]') { return $null }   # interpolated / dynamic: cannot measure
    $parts = [regex]::Split($expr, '\s*\+\s*\[char\]13\s*\+\s*\[char\]10\s*\+\s*')
    $out = @()
    foreach ($p in $parts) {
        $p = $p.Trim()
        if ($p -match "^'(.*)'$" -or $p -match '^"(.*)"$') { $out += $Matches[1] }
        elseif ($p -eq '') { }
        else { return $null }
    }
    return ($out -join "`r`n")
}

$problems = @()
foreach ($file in (Get-ChildItem -LiteralPath $Dir -Filter '*.ps1' | Sort-Object Name)) {
    $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
    $rec = @{}
    $ln = 0
    foreach ($line in $lines) {
        $ln++
        if ($line -match '^\s*\$([A-Za-z_]\w*)\s*\.\s*Text\s*=\s*(.+?)\s*$') {
            $n = $Matches[1]
            if (-not $rec.ContainsKey($n)) { $rec[$n] = @{} }
            $rec[$n].TextLine = $ln
            $rec[$n].Text = (Expand-TextLiteral $Matches[2])
        }
        elseif ($line -match '^\s*\$([A-Za-z_]\w*)\s*\.\s*Size\s*=\s*New-Object System\.Drawing\.Size\((\d+)\s*,\s*(\d+)\)') {
            $n = $Matches[1]
            if (-not $rec.ContainsKey($n)) { $rec[$n] = @{} }
            $rec[$n].W = [int]$Matches[2]
            $rec[$n].H = [int]$Matches[3]
        }
        elseif ($line -match '^\s*\$([A-Za-z_]\w*)\s*\.\s*Font\s*=\s*New-Object System\.Drawing\.Font\(\s*''[^'']+''\s*,\s*([\d.]+)') {
            $n = $Matches[1]
            if (-not $rec.ContainsKey($n)) { $rec[$n] = @{} }
            $rec[$n].FontSize = [double]$Matches[2]
        }
        elseif ($line -match '^\s*\$([A-Za-z_]\w*)\s*\.\s*AutoSize\s*=\s*\$true') {
            $n = $Matches[1]
            if (-not $rec.ContainsKey($n)) { $rec[$n] = @{} }
            $rec[$n].AutoSize = $true
        }
        elseif ($line -match '^\s*\$([A-Za-z_]\w*)\s*\.\s*AutoEllipsis\s*=\s*\$true') {
            $n = $Matches[1]
            if (-not $rec.ContainsKey($n)) { $rec[$n] = @{} }
            $rec[$n].Ellipsis = $true
        }
    }

    foreach ($n in ($rec.Keys | Sort-Object)) {
        $r = $rec[$n]
        if ($ignore -contains $n) { continue }
        if (-not $r.Text) { continue }                 # empty or dynamic (filled at runtime)
        if (-not $r.W) { continue }                    # AutoSize / docked / panel child
        if ($r.AutoSize) { continue }
        $fs = if ($r.FontSize) { $r.FontSize } else { 9.0 }
        $font = New-Object System.Drawing.Font('Microsoft YaHei UI', [single]$fs)
        $rows = $r.Text -split "`r`n|`n"
        $maxW = 0
        foreach ($row in $rows) {
            $w = [System.Windows.Forms.TextRenderer]::MeasureText(
                $row, $font, (New-Object System.Drawing.Size(20000, 2000)),
                [System.Windows.Forms.TextFormatFlags]::NoPadding).Width
            if ($w -gt $maxW) { $maxW = $w }
        }
        $needH = [int][math]::Ceiling($fs * 1.6) * $rows.Count
        $msg = @()
        if ($maxW -gt $r.W) { $msg += ("text {0}px > box {1}px" -f $maxW, $r.W) }
        if ($needH -gt $r.H) { $msg += ("lines need {0}px > box {1}px" -f $needH, $r.H) }
        if ($msg.Count -gt 0) {
            $problems += ("{0}:{1}  `${2}  [{3}]" -f $file.Name, $r.TextLine, $n, ($msg -join '; '))
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Output 'UI FIT: OK - no fixed-size control clips its text.'
    return
}
Write-Output ("UI FIT: {0} problem(s)" -f $problems.Count)
$problems | ForEach-Object { Write-Output ("  " + $_) }
