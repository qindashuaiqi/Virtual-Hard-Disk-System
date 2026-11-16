# -*- coding: utf-8 -*-
"""把 docs/ 里的指南同步进发行目录 en/ 与 zh-CN/（或只检查两者是否一致）。

为什么需要这一步：发行 zip 里放的是 en/USER-GUIDE.md 和 zh-CN/USER-GUIDE.md 的副本，
v1.36 只改了 docs/ 下的正本，副本就落后了 —— 用户解包看到的还是 v1.35 的说法。
同类问题以前只能靠人记得「改完正本记得复制一份」，而这正是质疑清单 Q9 说的那种漏。

同步规则：
  en     : 与 docs/USER-GUIDE.md 完全一致（发行副本不带 BOM）
  zh-CN  : 与 docs/USER-GUIDE.zh-CN.md 完全一致（同上）

两份副本的换行风格是 CRLF、且不带 BOM，和仓库其它文件一致；这两点都得保持，
否则 git 会把整个文件当成「全部重写」。

用法：
    python src/build/sync_guides.py            # 写：把正本复制到发行目录
    python src/build/sync_guides.py --check    # 只读：不一致就返回 1（check_all.py 用这个）
"""
import io
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECK = '--check' in sys.argv

PAIRS = [
    ('docs/USER-GUIDE.md', 'en/USER-GUIDE.md'),
    ('docs/USER-GUIDE.zh-CN.md', 'zh-CN/USER-GUIDE.md'),
]


def read(p):
    """Read as text with \\n line endings, dropping any BOM."""
    with io.open(p, 'r', encoding='utf-8-sig', newline=None) as f:
        return f.read()


def write_crlf(p, text):
    """Write CRLF, no BOM - the style every other file in the repo uses."""
    with io.open(p, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text)


def main():
    bad = 0
    for src_rel, dst_rel in PAIRS:
        src = read(os.path.join(REPO, src_rel))
        dst_path = os.path.join(REPO, dst_rel)
        if CHECK:
            same = os.path.isfile(dst_path) and read(dst_path) == src
            if not same:
                bad += 1
                print('FAIL %-28s is out of date (run sync_guides.py)' % dst_rel)
            else:
                print('OK   %-28s %d chars, in sync' % (dst_rel, len(src)))
        else:
            write_crlf(dst_path, src)
            print('%-6s synced, %d chars' % (dst_rel, len(src)))
    if CHECK:
        print('\n%d of %d guide copy(ies) out of sync' % (bad, len(PAIRS)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
