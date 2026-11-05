"""Package the two distributable folders (en / zh-CN) into release zips.

Each zip keeps the folder at the top level so unzipping gives a clean
"en/Start.bat" / "zh-CN/开始.bat" tree - no src, no .git, no build noise.

Usage:  python make_release.py <version> [out_dir]
  e.g.   python make_release.py v1.32
"""

import hashlib
import os
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def pack(src_subdir, out_dir, version):
    src = os.path.join(REPO, src_subdir)
    out = os.path.join(out_dir, 'Virtual-Hard-Disk-System-%s-%s.zip' % (version, src_subdir))
    count = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
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
    version = sys.argv[1] if len(sys.argv) > 1 else 'v1.32'
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, '_release')
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
