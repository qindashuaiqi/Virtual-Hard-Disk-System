# -*- coding: utf-8 -*-
"""Make a build script print UTF-8 whatever code page the console is on.

Why: a Windows console defaults to cp936 (Chinese) or cp1252 (GitHub's windows-latest
runner). Both raise UnicodeEncodeError the moment a script prints a Chinese file name or a
U+FFFD replacement character, so `check_all.py` reddened on CI for a reason that had
nothing to do with the code under test:

    UnicodeEncodeError: 'gbk' codec can't encode character '\\ufffd'
    UnicodeEncodeError: 'charmap' codec can't encode characters ...

Calling setup() reconfigures sys.stdout/sys.stderr to UTF-8 with errors='replace'. It is a
no-op on a Python without reconfigure() (3.6 and older) and never raises.
"""
import sys


def setup():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding='utf-8', errors='replace')
        except Exception:
            pass
