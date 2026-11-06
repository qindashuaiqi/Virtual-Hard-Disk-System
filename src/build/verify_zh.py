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

from inline_shared import inline_bytes

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

    # 载荷 = 源 ps1 内联共享模块之后的内容，所以比对基准也要内联
    src_path = os.path.join(SRC, ps1)
    want, inlined = inline_bytes(io.open(src_path, 'rb').read(), 'zh-CN')

    if data != want:
        print('FAIL %-46s payload mismatch: %d vs %d bytes' % (bat, len(data), len(want)))
        fails += 1
        continue

    # 不能只靠上面的比对自证：确认被内联模块里的每个函数真的进了载荷，
    # 且没有运行期 dot-source 引用残留（那会在用户机器上直接失败）
    bad = []
    for rel in inlined:
        mod = os.path.join(REPO, 'src', 'shared', rel.replace('/', os.sep))
        mod_txt = io.open(mod, 'r', encoding='utf-8-sig').read()
        for fn in re.findall(r'^\s*function\s+([A-Za-z0-9_\-]+)', mod_txt, re.M):
            if not re.search(rb'function\s+' + fn.encode('ascii') + rb'\b', data):
                bad.append(u'缺少函数 %s（来自 %s）' % (fn, rel))
    if re.search(rb'\$PSScriptRoot[\\/]\.\.[\\/]shared', data, re.I):
        bad.append(u'运行期 dot-source 引用没有被内联掉')
    if bad:
        print('FAIL %-46s %s' % (bat, u'; '.join(bad)))
        fails += 1
        continue

    extra = (u' [+%s]' % u','.join(inlined)) if inlined else u''
    print('OK   %-46s payload == %s (%d bytes)%s' % (bat, ps1, len(want), extra))

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
