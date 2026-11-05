# -*- coding: utf-8 -*-
"""
把 PowerShell 脚本打包成单文件双击 bat（base64 自解压）。

用法： python make_bat_zh.py
源  ： <repo>/src/zh-CN/*.ps1
输出： <repo>/zh-CN/*.bat 和 <repo>/zh-CN/急救工具/*.bat

2026-11-05 修复：原来的外壳用
    powershell -Command "Start-Process ... -ArgumentList '...','\"%PS1FILE%\"' ..."
提权，这层嵌套引号在某些环境下会被 -Command 提前截断，powershell 解析失败直接退出，
而下面紧跟 exit /b 0，窗口一闪就没了 —— 既没有提示也不写日志。
改成：先给 bat 自己提权，再用普通 -File 原地运行脚本，所有错误都留在窗口里。
"""
import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))     # src\build
SRC = os.path.dirname(HERE)                            # src
REPO = os.path.dirname(SRC)                            # 仓库根
ZH_SRC = os.path.join(SRC, 'zh-CN')
OUT_MAIN = os.path.join(REPO, 'zh-CN')
OUT_TOOLS = os.path.join(OUT_MAIN, '急救工具')

BAT_TEMPLATE = r'''@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title %TITLE%
cd /d "%~dp0"

rem ---------------------------------------------------------------- 管理员权限
rem 提权只在这里做一次，作用在 bat 自身。
rem 绝对不要再用 powershell -Command "... Start-Process -ArgumentList '\"...\"' ..."
rem 这种嵌套引号：它只在部分环境成立，一旦被 -Command 提前截断，powershell 解析失败
rem 直接退出，而下面紧跟 exit /b，窗口一闪就没 —— 没有提示，也不写日志，看起来就像闪退。
rem （2026-11-05 实测：整个英文版都因为这个原因打不开。）
rem 改成先提权、再用普通 -File 运行脚本，任何错误都留在窗口里。
fltmc >nul 2>&1
if errorlevel 1 (
    echo   正在申请管理员权限，请在弹窗中选「是」...
    set "ELEV_ARGS=%*"
    if defined ELEV_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList $env:ELEV_ARGS } catch { exit 9 }"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
    )
    if errorlevel 9 (
        echo.
        echo   [错误] 没能获得管理员权限。
        echo          请右键本文件，选择「以管理员身份运行」。
        echo.
        pause
    )
    exit /b
)

rem ---------------------------------------------------------------- 解包
rem 每次用一个全新的随机工作目录。
rem 不能复用固定目录：上一次残留的 ps1 会导致 certutil 拒绝覆盖，
rem 而 "if not exist" 检查又能通过（旧文件在），于是静默跑旧代码 —— 表现为
rem 「明明改了程序，双击还是报同一个错」。
set "WORKDIR=%TEMP%\OneKeyInstall_%RANDOM%%RANDOM%"
mkdir "%WORKDIR%" >nul 2>&1
if not exist "%WORKDIR%" (
    echo.
    echo   [错误] 无法创建临时目录，请检查 %%TEMP%% 是否可写。
    echo.
    pause
    exit /b 1
)

set "B64FILE=%WORKDIR%\payload.b64"
set "RAW=%WORKDIR%\payload.dat"
set "PS1FILE=%WORKDIR%\%PS1NAME%"

> "%B64FILE%" echo -----BEGIN-----
%B64LINES%
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=%PS1SIZE%"
set "GOT=0"
for %%A in ("%PS1FILE%") do if exist "%%A" set "GOT=%%~zA"
if not "%GOT%"=="%NEED%" (
    echo.
    rem Keep the FULL-WIDTH parens on this line. cmd treats a half-width ) as the
    rem end of the enclosing block even inside echo text, and the batch dies with
    rem ". was unexpected at this time." without printing anything - that bug
    rem killed every English launcher in v1.x. The Chinese build was spared only
    rem because （ and ） are not syntax to cmd.
    echo   [错误] 自解压失败（期望 %NEED% 字节，实际 %GOT% 字节）。
    echo          请重新复制本文件，或临时关闭杀毒软件后重试。
    echo.
    pause
    exit /b 1
)
del "%B64FILE%" "%RAW%" >nul 2>&1

echo.
echo   正在启动，请稍候...
echo.

rem %~dp0 结尾带反斜杠，补一个 . 就没有了，避免写 if "%X:~-1%"=="\" 这种易错的判断。
rem 下面一行里不要出现任何嵌套引号。
set "ORIGIN=%~dp0."

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%"%PSARGS% %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo   [错误] 脚本退出码 %RC%。
    echo          解压出的脚本留在这里，方便排查：
    echo             %PS1FILE%
    echo          想看纯文本报告（不开窗口）：
    echo             powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ConsoleMode
    echo.
    pause
    exit /b %RC%
)

rem [审计 P3-17] 成功结束后清理。以前只删 payload.b64 / payload.dat，
rem   于是 TEMP 里每跑一次就多一个文件夹和一个 ps1，越积越多。
rem   ps1 在脚本退出之后才删，运行期间不碰它。
del "%PS1FILE%" >nul 2>&1
rmdir "%WORKDIR%" >nul 2>&1
%TAIL%
exit /b 0
'''


def build(ps1_name, bat_name, title, with_origin=True, keep_window=False):
    ps1_path = os.path.join(ZH_SRC, ps1_name)
    with open(ps1_path, 'rb') as f:
        raw = f.read()

    if raw[:3] != b'\xef\xbb\xbf':
        print('[WARN] %s 缺少 UTF-8 BOM' % ps1_name)

    b64 = base64.b64encode(raw).decode('ascii')
    # 每 76 字符一行（certutil 友好）
    chunks = [b64[i:i + 76] for i in range(0, len(b64), 76)]
    lines = '\r\n'.join('>> "%%B64FILE%%" echo %s' % c for c in chunks)

    ps_args = ' -OriginDir "%ORIGIN%"' if with_origin else ''
    # 控制台工具跑完要留住窗口，让人看得到报告；GUI 脚本关窗口就结束。
    tail = 'echo.\r\npause' if keep_window else ''

    bat = BAT_TEMPLATE
    bat = bat.replace('%B64LINES%', lines)
    bat = bat.replace('%PSARGS%', ps_args)
    bat = bat.replace('%TAIL%', tail)
    bat = bat.replace('%PS1NAME%', ps1_name)
    bat = bat.replace('%PS1SIZE%', str(len(raw)))
    bat = bat.replace('%TITLE%', title)

    bat = bat.replace('\r\n', '\n').replace('\n', '\r\n')
    target = OUT_MAIN if bat_name in ('双击我-装系统.bat', '双击我-卸载新系统.bat') else OUT_TOOLS
    if not os.path.isdir(target):
        os.makedirs(target)
    out = os.path.join(target, bat_name)
    with open(out, 'wb') as f:
        f.write(bat.encode('gbk'))

    print('OK  %-28s <- %-38s (ps1=%d bytes, b64 lines=%d, bat=%d bytes)'
          % (bat_name, ps1_name, len(raw), len(chunks), os.path.getsize(out)))
    return out


if __name__ == '__main__':
    build('Install-To-VHD.ps1', '双击我-装系统.bat', '虚拟硬盘系统')
    build('Uninstall-VHDSystem.ps1', '双击我-卸载新系统.bat', '卸载虚拟系统')
    build('Repair-Boot.ps1', '修复启动菜单-管理员运行.bat', '修复启动菜单')
    build('修好菜单指向-管理员运行.ps1', '修好菜单指向-管理员运行.bat', '修好菜单指向', with_origin=False, keep_window=True)
    build('清理ESP盘符-管理员运行.ps1', '清理ESP盘符-管理员运行.bat', '清理残留盘符', with_origin=False, keep_window=True)
    build('还原启动菜单-管理员运行.ps1', '还原启动菜单-管理员运行.bat', '还原启动菜单', with_origin=False, keep_window=True)
    build('清理安装残留-管理员运行.ps1', '清理安装残留-管理员运行.bat', '清理安装残留', with_origin=True, keep_window=True)
    build('注入网卡驱动-管理员运行.ps1', '注入网卡驱动-管理员运行.bat', '注入网卡驱动', with_origin=False, keep_window=True)
    build('全量注入驱动-管理员运行.ps1', '全量注入驱动-管理员运行.bat', '全量注入驱动', with_origin=False, keep_window=True)
    build('新系统-诊断并装驱动.ps1', '新系统-诊断并装驱动.bat', '新系统诊断并装驱动', with_origin=False, keep_window=True)
    build('新系统-清理幽灵显卡.ps1', '新系统-清理幽灵显卡.bat', '新系统清理幽灵显卡', with_origin=False, keep_window=True)
    print('done')
