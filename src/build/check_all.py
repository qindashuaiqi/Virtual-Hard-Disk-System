# -*- coding: utf-8 -*-
"""发布前的一键门禁：把「靠人记得跑」变成「不跑就发不出去」。

依次执行，任何一步非零退出即整体失败：

  1. 语法解析      check_syntax.ps1                所有 ps1 零语法错误
  2. 载荷一致性    verify_en.py / verify_zh.py      24 个 bat 内嵌 payload 与源码逐字节一致
  3. 启动器实跑    selftest_bat.py en / zh-CN       24 个 bat 真的能起、能解包、能把参数传下去
  4. 单元回归      test_bcd_parse / test_bcd_readback / test_p0_lookup
  5. 界面尺寸      check_ui_fit.ps1（中英各一遍）
  6. 提示框自适应  selftest_notice_box.ps1
  7. 指南副本      sync_guides.py --check         en/ 与 zh-CN/ 里的 USER-GUIDE.md 与 docs/ 正本一致

为什么要有这个文件（质疑清单 Q9）：
    v1.35 及以前，上面这一串只存在于作者的操作习惯里 —— make_release.py 只负责 zip，
    一个校验都不调，所以「这次没漏」是人工维持的结果，不是机制保证。
    现在 make_release.py 打包前会强制跑它。

用法：
    python src/build/check_all.py
    python src/build/check_all.py --quiet     # 只输出失败项
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(REPO, 'src')

# [v1.36] A GBK or cp1252 console cannot print U+FFFD or a Chinese file name, and this script
# prints both kinds of text coming back from the child processes:
#     UnicodeEncodeError: 'gbk' codec can't encode character '\ufffd'
# On GitHub's windows-latest the default is cp1252, so the gate reddened for a reason that has
# nothing to do with the code under test. Pin our own streams and every child's.
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

CHILD_ENV = dict(os.environ)
CHILD_ENV['PYTHONIOENCODING'] = 'utf-8'
CHILD_ENV['PYTHONUTF8'] = '1'

QUIET = '--quiet' in sys.argv


def decode_out(b):
    """Decode a child process' bytes without turning anything into U+FFFD if avoidable.

    Windows PowerShell writes its output in the console code page (cp936 here, cp437 for the
    English launcher) while a Python child writes UTF-8; trying UTF-8 first and falling back
    keeps both readable and never mangles Chinese into question marks.
    """
    if not b:
        return ''
    for enc in ('utf-8', 'gbk', 'cp1252'):
        try:
            text = b.decode(enc)
        except UnicodeDecodeError:
            continue
        if '\ufffd' not in text:
            return text
    return b.decode('utf-8', 'replace')


def ps(script, *args):
    """Run a .ps1 with powershell.exe and return (rc, output)."""
    cmd = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
           os.path.join(HERE, script)] + list(args)
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       env=CHILD_ENV)
    return p.returncode, decode_out(p.stdout)


def py(script, *args):
    cmd = [sys.executable, os.path.join(HERE, script)] + list(args)
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=CHILD_ENV)
    return p.returncode, decode_out(p.stdout)


def main():
    steps = []
    steps.append(('syntax', ps('check_syntax.ps1', '-Root', SRC)))
    steps.append(('verify_en', py('verify_en.py')))
    steps.append(('verify_zh', py('verify_zh.py')))
    steps.append(('selftest_bat en', py('selftest_bat.py', 'en')))
    steps.append(('selftest_bat zh-CN', py('selftest_bat.py', 'zh-CN')))
    steps.append(('bcd parse', ps('test_bcd_parse.ps1')))
    # [v1.36] Both language modules: the zh-CN one used to be skipped entirely, so a change
    # made only there (or only in en) shipped untested.
    steps.append(('bcd readback en', ps('test_bcd_readback.ps1',
                                        '-Ps1', os.path.join(SRC, 'shared', 'en', 'BcdVerify.ps1'))))
    steps.append(('bcd readback zh', ps('test_bcd_readback.ps1',
                                        '-Ps1', os.path.join(SRC, 'shared', 'zh-CN', 'BcdVerify.ps1'))))
    steps.append(('p0 lookup en', ps('test_p0_lookup.ps1', '-Ps1', os.path.join(SRC, 'en', 'Install-To-VHD.ps1'))))
    steps.append(('p0 lookup zh', ps('test_p0_lookup.ps1', '-Ps1', os.path.join(SRC, 'zh-CN', 'Install-To-VHD.ps1'))))
    steps.append(('ui fit en', ps('check_ui_fit.ps1', '-Dir', os.path.join(SRC, 'en'))))
    steps.append(('ui fit zh', ps('check_ui_fit.ps1', '-Dir', os.path.join(SRC, 'zh-CN'))))
    steps.append(('notice box', ps('selftest_notice_box.ps1')))
    steps.append(('guides in sync', py('sync_guides.py', '--check')))

    failed = 0
    for name, (rc, out) in steps:
        ok = (rc == 0)
        if not ok:
            failed += 1
        if not ok or not QUIET:
            print('==== %s: %s' % (name, 'OK' if ok else 'FAILED (rc=%d)' % rc))
            if not ok:
                print(out.rstrip())
            elif out.strip():
                tail = out.rstrip().splitlines()[-3:]
                for line in tail:
                    print('     ' + line)
    print('\n%d step(s), %d failed' % (len(steps), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
