# selftest_notice_box.ps1 - runtime check of the auto-growing notice box.
#
# The notice box in Install-To-VHD.ps1 relies on a WinForms detail: an AutoSize label only wraps
# when MaximumSize is set, and the new height is applied on the next layout pass. If that did not
# happen exactly as assumed, the block below the box would overlap it. This script rebuilds the
# same control with the same properties and prints what WinForms actually computes.
#
# Usage: $sb=[scriptblock]::Create([IO.File]::ReadAllText($p,[Text.Encoding]::UTF8)); & $sb

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(800, 900)
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$y5 = 540
$lblBox = New-Object System.Windows.Forms.Label
$lblBox.Text = "After installing, reboot and the boot menu will show one extra entry (the name you chose); pick it to boot the new system." + [char]13 + [char]10 + "Install another one by running it again with a different name. To remove it later run Uninstall-System.bat: it is deleted completely and the existing system is not affected at all."
$lblBox.ForeColor = [System.Drawing.Color]::FromArgb(42, 78, 128)
$lblBox.BackColor = [System.Drawing.Color]::FromArgb(237, 245, 254)
$lblBox.BorderStyle = 'FixedSingle'
$lblBox.Padding = New-Object System.Windows.Forms.Padding(10, 7, 10, 7)
$lblBox.AutoSize = $true
$lblBox.Location = New-Object System.Drawing.Point(28, $y5)
$lblBox.MaximumSize = New-Object System.Drawing.Size(742, 0)
$lblBox.MinimumSize = New-Object System.Drawing.Size(742, 0)
$form.Controls.Add($lblBox)
$lblBox.PerformLayout()

$boxH = $lblBox.Height
if ($boxH -lt 40) { $boxH = 80 }
$y6 = $y5 + $boxH + 14
$needH = $y6 + 258
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$lines = ($lblBox.Text -split "`r`n|`n").Count
Write-Output ("notice label size     : {0} x {1}" -f $lblBox.Width, $lblBox.Height)
Write-Output ("explicit text lines   : {0}" -f $lines)
Write-Output ("assumed line height   : {0} px" -f [int][math]::Ceiling(9 * 1.6))
Write-Output ("y6 (start of step 4)  : {0}" -f $y6)
Write-Output ("window height needed  : {0}" -f $needH)
Write-Output ("screen working area   : {0} x {1}" -f $wa.Width, $wa.Height)
Write-Output ("footer bottom edge    : {0}" -f ($y6 + 200))
Write-Output ("log box bottom edge   : {0}" -f ($y6 + 178))

$ok = $true
if ($lblBox.Width -ne 742) { Write-Output 'FAIL: notice box is not 742px wide'; $ok = $false }
if ($lblBox.Height -lt 60) { Write-Output 'FAIL: notice box did not wrap (height too small)'; $ok = $false }
if ($needH -gt $wa.Height) { Write-Output 'WARN: window taller than the screen, form will scroll' }
if ($ok) { Write-Output 'NOTICE BOX: OK - wraps to its own height, controls below stay clear.' }
