# -*- coding: utf-8 -*-
"""构建期把 src/shared/<lang>/*.ps1 内联进入口脚本。

为什么需要这一步:
    发布出去的 .bat 是自解压单文件 —— 载荷是「一个 ps1 的完整 base64」，
    运行期解压到 %TEMP% 再执行，没有任何方式引用同目录外的模块。
    所以共享模块只能在**打包时**内联进载荷。

结果:
    - 源码：每个函数只有一份（src/shared/），改一处就是改一处
    - 产物：每个 bat 仍是自包含单文件，双击即用，分发形态零变化

用法:
    from inline_shared import inline_bytes
    raw, used = inline_bytes(raw, 'en')
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
SHARED = os.path.join(SRC, 'shared')

# 匹配入口脚本里的引用行:
#     . "$PSScriptRoot\..\shared\en\Logging.ps1"
# 行尾用 (?=\r?$) 前瞻，不吃掉 \r，避免把 CRLF 变成 LF
REF_RE = re.compile(
    r'^[ \t]*\.[ \t]+["\']\$PSScriptRoot[\\/]\.\.[\\/]shared[\\/]([^"\']+?)["\'][ \t]*(?=\r?$)',
    re.MULTILINE | re.IGNORECASE,
)


def inline_text(text, lang):
    """返回 (内联后的文本, 已内联模块的相对路径列表)。"""
    used = []
    eol = '\r\n' if '\r\n' in text else '\n'

    def _sub(m):
        rel = m.group(1).replace('\\', '/')
        # 语言目录必须匹配，避免 en 的脚本误引用 zh 的文案
        if not rel.startswith(lang + '/'):
            raise SystemExit(
                '[inline] 语言目录不匹配: %r 不是 %r 下的模块' % (rel, lang))
        path = os.path.join(SHARED, rel)
        if not os.path.isfile(path):
            raise SystemExit('[inline] 找不到共享模块: %s' % path)
        with open(path, 'r', encoding='utf-8-sig') as f:
            body = f.read()
        body = body.replace('\r\n', '\n').replace('\n', eol).rstrip('\r\n')
        used.append(rel)
        return body

    out = REF_RE.sub(_sub, text)

    # 安全网：内联后不应再有任何 shared 引用残留，否则发布出去会在客户机上失败
    leftover = REF_RE.search(out)
    if leftover:
        raise SystemExit('[inline] 内联后仍残留 shared 引用: %r' % leftover.group(0))
    return out, used


def inline_bytes(raw, lang):
    """bytes 版本，保留 UTF-8 BOM 与 CRLF。返回 (bytes, used)。"""
    has_bom = raw[:3] == b'\xef\xbb\xbf'
    text = raw.decode('utf-8-sig')
    new_text, used = inline_text(text, lang)
    out = new_text.encode('utf-8')
    if has_bom:
        out = b'\xef\xbb\xbf' + out
    return out, used


def verify_no_refs(path):
    """给测试用：确认一个已生成的 .ps1/.bat 载荷里没有 shared 引用。"""
    with open(path, 'rb') as f:
        data = f.read()
    return REF_RE.search(data.decode('utf-8', 'replace')) is None
