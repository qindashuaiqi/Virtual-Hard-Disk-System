# -*- coding: utf-8 -*-
"""Self-test the English release: decode every embedded payload and compare it
byte for byte with the source ps1, and check the bat files are ASCII + CRLF."""
import base64
import glob
import io
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EN = os.path.join(REPO, 'en')  # release folder
SRC = os.path.join(REPO, 'src', 'en')

PAIRS = {
    'Install-System.bat': 'Install-To-VHD.ps1',
    'Uninstall-System.bat': 'Uninstall-VHDSystem.ps1',
    'tools/Repair-Boot-Menu.bat': 'Repair-Boot.ps1',
    'tools/Fix-Boot-Entry-Device.bat': 'Fix-Boot-Entry-Device.ps1',
    'tools/Clean-Esp-DriveLetter.bat': 'Clean-Esp-DriveLetter.ps1',
    'tools/Restore-Boot-Menu.bat': 'Restore-Boot-Menu.ps1',
    'tools/Clean-Install-Residue.bat': 'Clean-Install-Residue.ps1',
    'tools/Inject-Network-Drivers.bat': 'Inject-Network-Drivers.ps1',
    'tools/Inject-All-Drivers.bat': 'Inject-All-Drivers.ps1',
    'tools/Diagnose-And-Install-Drivers.bat': 'Diagnose-And-Install-Drivers.ps1',
    'tools/Clean-Ghost-GPU.bat': 'Clean-Ghost-GPU.ps1',
    'Start.bat': None,
}

fails = 0
for bat, ps1 in PAIRS.items():
    p = os.path.join(EN, bat)
    raw = io.open(p, 'rb').read()
    try:
        raw.decode('ascii')
    except Exception as e:
        print('FAIL %-38s not ASCII (%s)' % (bat, e))
        fails += 1
        continue
    if b'\n' in raw.replace(b'\r\n', b''):
        print('FAIL %-38s has bare LF line endings' % bat)
        fails += 1
        continue
    if ps1 is None:
        print('OK   %-38s ascii + CRLF' % bat)
        continue
    body = re.split(r'-----BEGIN-----', raw.decode('ascii'))[1].split('-----END-----')[0]
    chunks = re.findall(r'echo (\S+)\r?\n', body)
    data = base64.b64decode(''.join(chunks))
    want = io.open(os.path.join(SRC, ps1), 'rb').read()
    if data == want:
        print('OK   %-38s payload == %s (%d bytes)' % (bat, ps1, len(want)))
    else:
        print('FAIL %-38s payload mismatch: %d vs %d bytes' % (bat, len(data), len(want)))
        fails += 1

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
