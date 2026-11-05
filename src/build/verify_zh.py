# -*- coding: utf-8 -*-
"""Self-test the Chinese release: decode every embedded payload and compare it
byte for byte with the source ps1.

This is the zh-CN twin of verify_en.py. The bat files are GBK, so they are
decoded with cp936 (the payload itself is plain ASCII base64).
"""
import base64
import io
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ZH = os.path.join(REPO, 'zh-CN')
SRC = os.path.join(REPO, 'src', 'zh-CN')

PAIRS = {
    u'\u53cc\u51fb\u6211-\u88c5\u7cfb\u7edf.bat': 'Install-To-VHD.ps1',
    u'\u53cc\u51fb\u6211-\u5378\u8f7d\u65b0\u7cfb\u7edf.bat': 'Uninstall-VHDSystem.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u4fee\u590d\u542f\u52a8\u83dc\u5355-\u7ba1\u7406\u5458\u8fd0\u884c.bat': 'Repair-Boot.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u4fee\u597d\u83dc\u5355\u6307\u5411-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u4fee\u597d\u83dc\u5355\u6307\u5411-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u6e05\u7406ESP\u76d8\u7b26-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u6e05\u7406ESP\u76d8\u7b26-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u8fd8\u539f\u542f\u52a8\u83dc\u5355-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u8fd8\u539f\u542f\u52a8\u83dc\u5355-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u6e05\u7406\u5b89\u88c5\u6b8b\u7559-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u6e05\u7406\u5b89\u88c5\u6b8b\u7559-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u6ce8\u5165\u7f51\u5361\u9a71\u52a8-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u6ce8\u5165\u7f51\u5361\u9a71\u52a8-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u5168\u91cf\u6ce8\u5165\u9a71\u52a8-\u7ba1\u7406\u5458\u8fd0\u884c.bat': u'\u5168\u91cf\u6ce8\u5165\u9a71\u52a8-\u7ba1\u7406\u5458\u8fd0\u884c.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u65b0\u7cfb\u7edf-\u8bca\u65ad\u5e76\u88c5\u9a71\u52a8.bat': u'\u65b0\u7cfb\u7edf-\u8bca\u65ad\u5e76\u88c5\u9a71\u52a8.ps1',
    u'\u6025\u6551\u5de5\u5177\\\u65b0\u7cfb\u7edf-\u6e05\u7406\u5e7d\u7075\u663e\u5361.bat': u'\u65b0\u7cfb\u7edf-\u6e05\u7406\u5e7d\u7075\u663e\u5361.ps1',
}

fails = 0
for bat, ps1 in PAIRS.items():
    p = os.path.join(ZH, bat)
    if not os.path.exists(p):
        print('FAIL %-46s missing' % bat)
        fails += 1
        continue
    raw = io.open(p, 'rb').read()
    try:
        text = raw.decode('cp936')
    except Exception as e:
        print('FAIL %-46s not GBK (%s)' % (bat, e))
        fails += 1
        continue
    if b'\n' in raw.replace(b'\r\n', b''):
        print('FAIL %-46s has bare LF line endings' % bat)
        fails += 1
        continue
    if '-----BEGIN-----' not in text:
        print('FAIL %-46s no payload block' % bat)
        fails += 1
        continue
    body = text.split('-----BEGIN-----')[1].split('-----END-----')[0]
    chunks = re.findall(r'echo (\S+)\r?\n', body)
    data = base64.b64decode(''.join(chunks))
    want = io.open(os.path.join(SRC, ps1), 'rb').read()
    if data == want:
        print('OK   %-46s payload == %s (%d bytes)' % (bat, ps1, len(want)))
    else:
        print('FAIL %-46s payload mismatch: %d vs %d bytes' % (bat, len(data), len(want)))
        fails += 1

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
