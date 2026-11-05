# -*- coding: utf-8 -*-
"""
把 PowerShell 脚本打包成单文件双击 bat（base64 自解压）。

用法： python make_bat.py
"""
import base64
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)          # _源码\
BASE = os.path.dirname(ROOT)          # 一键装系统\
RESCUE = os.path.join(BASE, '急救工具')

# 只有这两个留在根目录当门面，其余全部收进 急救工具\
MAIN_BATS = ('双击我-装系统.bat', '双击我-卸载新系统.bat')

BAT_TEMPLATE = r'''@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title %TITLE%

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
    echo   [错误] 自解压失败（期望 %NEED% 字节，实际 %GOT% 字节）。
    echo          请重新复制本文件，或临时关闭杀毒软件后重试。
    echo.
    pause
    exit /b 1
)

echo.
echo   正在启动，请稍候...
echo.
rem %~dp0 结尾带反斜杠，作为参数会转义引号，先去掉
set "ORIGIN=%~dp0"
if "%ORIGIN:~-1%"=="\" set "ORIGIN=%ORIGIN:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File','\"%PS1FILE%\"'%EXTRAARGS% -Verb RunAs -Wait"
exit /b 0
'''


def build(ps1_name, bat_name, title, with_origin=True, keep_window=False):
    ps1_path = os.path.join(ROOT, ps1_name)
    with open(ps1_path, 'rb') as f:
        raw = f.read()

    # 校验：必须是 UTF-8 BOM
    if not (raw[:3] == b'\xef\xbb\xbf'):
        print('[WARN] %s 缺少 UTF-8 BOM' % ps1_name)

    b64 = base64.b64encode(raw).decode('ascii')
    # 每 76 字符一行（certutil 友好）
    chunks = [b64[i:i + 76] for i in range(0, len(b64), 76)]
    lines = '\r\n'.join('>> "%%B64FILE%%" echo %s' % c for c in chunks)

    extra = ",'-OriginDir','\\\"%ORIGIN%\\\"'" if with_origin else ''

    bat = BAT_TEMPLATE
    bat = bat.replace('%B64LINES%', lines)
    bat = bat.replace('%EXTRAARGS%', extra)
    bat = bat.replace('%PS1NAME%', ps1_name)
    bat = bat.replace('%PS1SIZE%', str(len(raw)))
    bat = bat.replace('%TITLE%', title)

    # 控制台脚本需要 -NoExit 保持窗口（否则跑完一闪而过看不到输出）；
    # GUI 脚本用 -Wait 等窗口关闭即可。
    if keep_window:
        bat = bat.replace("-Verb RunAs -Wait", "-Verb RunAs")
        bat = bat.replace("'-STA','-File','\\\"%PS1FILE%\\\"'",
                          "'-NoExit','-File','\\\"%PS1FILE%\\\"'")

    # bat 用 GBK，且必须 CRLF
    bat = bat.replace('\r\n', '\n').replace('\n', '\r\n')
    out_dir = BASE if bat_name in MAIN_BATS else RESCUE
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out = os.path.join(out_dir, bat_name)
    with open(out, 'wb') as f:
        f.write(bat.encode('gbk'))

    print('OK  %s  <- %s  (ps1=%d bytes, b64 lines=%d, bat=%d bytes)'
          % (os.path.join(os.path.basename(out_dir), bat_name) if out_dir != BASE else bat_name,
             ps1_name, len(raw), len(chunks), os.path.getsize(out)))
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
