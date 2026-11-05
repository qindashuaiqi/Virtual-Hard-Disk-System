# -*- coding: utf-8 -*-
"""Build a throw-away preview copy of the GUI so the real layout can be screenshotted.

Two edits only:
  * the self-elevation block is disabled (this session is not admin and there is nobody
    to click the UAC prompt)
  * a one-shot timer is armed on Shown: it renders the form to a PNG and closes it

Nothing else changes, so what the PNG shows is what the shipped script draws.
Usage: python make_gui_preview.py <en|zh-CN>
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))     # src\build
SRC_DIR = os.path.dirname(HERE)                        # src
REPO = os.path.dirname(SRC_DIR)                        # repo root
LANG = sys.argv[1] if len(sys.argv) > 1 else 'en'

if LANG == 'en':
    SRC = os.path.join(SRC_DIR, 'en', 'Install-To-VHD.ps1')
    OUT = os.path.join(HERE, 'gui_preview_en.ps1')
elif LANG == 'un':
    SRC = os.path.join(SRC_DIR, 'en', 'Uninstall-VHDSystem.ps1')
    OUT = os.path.join(HERE, 'gui_preview_un.ps1')
else:
    SRC = os.path.join(SRC_DIR, 'zh-CN', 'Install-To-VHD.ps1')
    OUT = os.path.join(HERE, 'gui_preview_zh.ps1')

src = open(SRC, encoding='utf-8-sig').read()

# The uninstaller only asks for admin rights when the delete button is pressed, so nothing to disable
if LANG != 'un':
    needle = "if (-not (Test-Admin)) {\n    # Self-elevation"
    assert needle in src, 'self-elevation block not found'
    src = src.replace(needle, "if ($false) {\n    # Self-elevation (disabled for the preview harness)", 1)

snap = r'''
    # ---- preview harness: render once to a PNG, then close ----
    $script:PreviewForm = $form
    $form.Add_Shown({
        $tmr = New-Object System.Windows.Forms.Timer
        $tmr.Interval = 2500
        $tmr.Add_Tick({
            $f = $script:PreviewForm
            try {
                $bmp = New-Object System.Drawing.Bitmap([int]$f.Width, [int]$f.Height)
                $f.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, [int]$f.Width, [int]$f.Height)))
                $bmp.Save($env:VHDX_PREVIEW, [System.Drawing.Imaging.ImageFormat]::Png)
                $bmp.Dispose()
            } catch {
                try { [IO.File]::WriteAllText($env:VHDX_PREVIEW + '.err', $_.Exception.Message) } catch {}
            }
            $f.Close()
        })
        $tmr.Start()
    })

'''

needle2 = "    [void]$form.ShowDialog()"
assert needle2 in src, 'ShowDialog call not found'
src = src.replace(needle2, snap + needle2, 1)

# Never block a headless run on Read-Host: write the error out instead
src = src.replace('    Read-Host "Press Enter to exit"',
                  '    [IO.File]::WriteAllText($env:VHDX_PREVIEW + ".err", "$_")')

open(OUT, 'w', encoding='utf-8-sig', newline='\r\n').write(src)
print('wrote', OUT, len(src), 'chars')
