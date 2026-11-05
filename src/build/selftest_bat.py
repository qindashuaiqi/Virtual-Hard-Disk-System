"""Runtime self-test for the generated .bat launchers.

Why this exists
---------------
`verify_en.py` only compares the embedded payload with the source ps1 byte by
byte. That check passed while every single English launcher was dead: the
self-extraction error message contained a half-width ")" inside an `if (...)`
block, cmd treated it as the end of the block, and the batch aborted with
". was unexpected at this time." before printing a single line. Nothing short
of executing the file would have caught it.

What it does, per launcher
--------------------------
1. static lint: flag half-width parentheses in `echo` lines that sit inside a
   parenthesised block (they terminate the block early)
2. run a doctored copy: the UAC elevation branch is disabled (so the test never
   prompts) and the final script launch is replaced by a marker echo, because a
   human has to click through the real installer
3. assert: exit code 0, marker printed, no "unexpected at this time", and the
   payload files were deleted (that line sits after the size check, so seeing
   them still on disk means the batch died before it)

Usage:  python selftest_bat.py [en|zh-CN]
"""

import glob
import io
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MARKER = 'BATTEST_REACHED_LAUNCH'

LAUNCH_RE = re.compile(r'^powershell -NoProfile[^\r\n]*-File "%PS1FILE%"[^\r\n]*$', re.M)
ELEV_RE = re.compile(r'^fltmc >nul 2>&1\r?\nif errorlevel 1 \($', re.M)


def lint_parens(text, name):
    """Half-width parens inside an echo that lives in a block break cmd."""
    bad = []
    depth = 0
    for no, line in enumerate(text.replace('\r\n', '\n').split('\n'), 1):
        stripped = line.strip()
        if stripped.lower().startswith('rem'):
            continue
        if depth > 0 and stripped.lower().startswith('echo') and ('(' in stripped or ')' in stripped):
            bad.append('%s:%d  %s' % (name, no, stripped[:100]))
        depth += line.count('(') - line.count(')')
        if depth < 0:
            depth = 0
    return bad


def temp_dirs():
    root = os.environ.get('TEMP') or tempfile.gettempdir()
    return set(p for p in glob.glob(os.path.join(root, 'VHDSystem_*')) if os.path.isdir(p))


def run_one(path, encoding, scratch):
    raw = io.open(path, 'rb').read().decode(encoding, errors='replace')
    name = os.path.basename(path)

    # Match on LF-only text: the files are CRLF, which leaves a stray \r before
    # every end-of-line anchor and makes all the regexes below miss.
    lf = raw.replace('\r\n', '\n')

    if 'set "NEED=' not in lf:
        return ('SKIP', '%s  (menu, no payload)' % name, [])

    problems = list(lint_parens(lf, name))

    test = lf
    if not ELEV_RE.search(test):
        problems.append('%s  elevation block not found, cannot neutralise UAC' % name)
    else:
        test = ELEV_RE.sub('if 1==2 (', test, count=1)

    if not LAUNCH_RE.search(test):
        problems.append('%s  final launch line not found' % name)
        return ('FAIL', name, problems)
    test = LAUNCH_RE.sub('echo %s' % MARKER, test, count=1)

    out_path = os.path.join(scratch, 'test_' + re.sub(r'[^A-Za-z0-9._-]', '_', name))
    body = test.replace('\n', '\r\n').encode(encoding, errors='replace')
    io.open(out_path, 'wb').write(body)

    before = temp_dirs()
    p = subprocess.run(['cmd', '/c', out_path], cwd=scratch,
                       stdin=subprocess.DEVNULL, capture_output=True, timeout=300)
    created = temp_dirs() - before
    after_text = p.stdout.decode('gbk', errors='replace') + p.stderr.decode('gbk', errors='replace')

    if p.returncode != 0:
        problems.append('%s  exit code %d' % (name, p.returncode))
    if MARKER not in after_text:
        problems.append('%s  never reached the launch step' % name)
    if 'unexpected at this time' in after_text:
        problems.append('%s  cmd parse error: %s' % (name, after_text.strip().splitlines()[-1][:90]))
    for d in created:
        leftovers = [f for f in os.listdir(d) if f.startswith('payload.')]
        if leftovers:
            problems.append('%s  payload not cleaned up: %s' % (name, ', '.join(leftovers)))

    return ('FAIL' if problems else 'OK', name, problems)


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else 'en'
    if which == 'en':
        encoding = 'ascii'
        targets = sorted(glob.glob(os.path.join(REPO, 'en', '*.bat')))
        targets += sorted(glob.glob(os.path.join(REPO, 'en', 'tools', '*.bat')))
    else:
        encoding = 'gbk'
        targets = sorted(glob.glob(os.path.join(REPO, 'zh-CN', '*.bat')))
        targets += sorted(glob.glob(os.path.join(REPO, 'zh-CN', '急救工具', '*.bat')))

    scratch = tempfile.mkdtemp(prefix='battest_')
    ok = fail = skip = 0
    all_problems = []
    for path in targets:
        state, name, problems = run_one(path, encoding, scratch)
        print('  %-4s %s' % (state, name))
        for p in problems:
            print('       %s' % p)
            all_problems.append(p)
        if state == 'OK':
            ok += 1
        elif state == 'FAIL':
            fail += 1
        else:
            skip += 1

    print('\n%d ok, %d failed, %d skipped' % (ok, fail, skip))
    if all_problems:
        print('\nPROBLEMS:')
        for p in all_problems:
            print('  ' + p)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
