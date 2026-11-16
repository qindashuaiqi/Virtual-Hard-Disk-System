"""Package the two distributable folders (en / zh-CN) into release zips.

Each zip keeps the folder at the top level so unzipping gives a clean
"en/Start.bat" / "zh-CN/开始.bat" tree - no src, no .git, no build noise.

Usage:  python make_release.py <version> [out_dir]
  e.g.   python make_release.py v1.32
"""

import hashlib
import os
import subprocess
import sys
import zipfile

import _utf8_stdout

_utf8_stdout.setup()

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))


def pack(src_subdir, out_dir, version):
    src = os.path.join(REPO, src_subdir)
    out = os.path.join(out_dir, 'Virtual-Hard-Disk-System-%s-%s.zip' % (version, src_subdir))
    count = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        # MIT requires the copyright + license text to be shipped with every
        # copy, so put a LICENSE at the top of each distributable folder.
        license_path = os.path.join(REPO, 'LICENSE')
        if not os.path.isfile(license_path):
            raise SystemExit('LICENSE not found at repo root: %s' % license_path)
        z.write(license_path, os.path.join(src_subdir, 'LICENSE'))
        count += 1
        for root, dirs, files in os.walk(src):
            dirs[:] = [d for d in dirs if d != '__pycache__']
            for f in files:
                if f.endswith(('.pyc', '.log')):
                    continue
                full = os.path.join(root, f)
                arc = os.path.join(src_subdir, os.path.relpath(full, src))
                z.write(full, arc)
                count += 1
    return out, count


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    skip = '--skip-check' in sys.argv

    # [v1.36] The version is required, and validated before the gate runs (no point spending a
    # minute on checks to then fail on a typo). It used to default to 'v1.32', so running the
    # script without an argument silently produced v1.32-named zips out of v1.36 code - a
    # mislabelled release is worse than a missing one.
    if not args:
        raise SystemExit('usage: python make_release.py <version> [out_dir]   e.g. v1.36')
    version = args[0]
    if not version.startswith('v') or not version[1:2].isdigit():
        raise SystemExit('the version should look like v1.36, got %r' % version)
    out_dir = args[1] if len(args) > 1 else os.path.join(REPO, '_release')

    # [v1.36] Everything that used to be "remember to run this first" is now a hard gate
    # (see check_all.py). A release zip that fails the checks is worthless: it is the exact
    # artefact a user double-clicks on a machine nobody can debug remotely.
    if not skip:
        rc = subprocess.call([sys.executable, os.path.join(HERE, 'check_all.py')])
        if rc != 0:
            raise SystemExit('\ncheck_all.py failed - nothing was packaged. '
                             'Fix the failures above, or pass --skip-check to override.')

    os.makedirs(out_dir, exist_ok=True)

    sums = []
    for sub in ('en', 'zh-CN'):
        out, count = pack(sub, out_dir, version)
        digest = sha256(out)
        sums.append('%s  %s' % (digest, os.path.basename(out)))
        print('%-6s %d files  %s' % (sub, count, os.path.basename(out)))

    sums_path = os.path.join(out_dir, 'SHA256SUMS.txt')
    with open(sums_path, 'w', encoding='ascii') as f:
        f.write('\n'.join(sums) + '\n')
    print('\nSHA256SUMS written to', sums_path)


if __name__ == '__main__':
    main()
