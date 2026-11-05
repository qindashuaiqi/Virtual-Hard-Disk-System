# -*- coding: utf-8 -*-
r"""
Pack a PowerShell script into a single self-extracting .bat (base64 payload).

English build of make_bat.py: same mechanism, English UI text, English file names.
The bat stays ASCII-only, so it is written with plain ASCII (no GBK step needed).

Usage: python make_bat_en.py
Source : <repo>/src/en/*.ps1
Output : <repo>/en/*.bat  and  <repo>/en/tools/*.bat
"""
import base64
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))     # src\build
SRC = os.path.dirname(HERE)                            # src
REPO = os.path.dirname(SRC)                            # repo root
EN_SRC = os.path.join(SRC, 'en')
OUT_MAIN = os.path.join(REPO, 'en')
OUT_TOOLS = os.path.join(OUT_MAIN, 'tools')

BAT_TEMPLATE = r'''@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title %TITLE%

rem Use a brand new random work folder every run.
rem A fixed folder must not be reused: a leftover ps1 from the previous run makes
rem certutil refuse to overwrite, while the "if not exist" check still passes
rem (the old file is there), so stale code runs silently -- which looks like
rem "I changed the program but double-clicking still shows the same error".
set "WORKDIR=%TEMP%\VHDSystem_%RANDOM%%RANDOM%"
mkdir "%WORKDIR%" >nul 2>&1
if not exist "%WORKDIR%" (
    echo.
    echo   [ERROR] Cannot create a temp folder. Check that %%TEMP%% is writable.
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

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=%PS1SIZE%"
set "GOT=0"
for %%A in ("%PS1FILE%") do if exist "%%A" set "GOT=%%~zA"
if not "%GOT%"=="%NEED%" (
    echo.
    echo   [ERROR] Self-extraction failed (expected %NEED% bytes, got %GOT% bytes).
    echo           Copy this file again, or disable antivirus temporarily and retry.
    echo.
    pause
    exit /b 1
)

echo.
echo   Starting, please wait...
echo.
rem %~dp0 ends with a backslash, which would escape the quote when passed as an argument, so strip it
set "ORIGIN=%~dp0"
if "%ORIGIN:~-1%"=="\" set "ORIGIN=%ORIGIN:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File','\"%PS1FILE%\"'%EXTRAARGS% -Verb RunAs -Wait"
exit /b 0
'''


def build(ps1_name, bat_name, title, with_origin=True, keep_window=False, out_dir=None):
    ps1_path = os.path.join(EN_SRC, ps1_name)
    with open(ps1_path, 'rb') as f:
        raw = f.read()

    if raw[:3] != b'\xef\xbb\xbf':
        print('[WARN] %s has no UTF-8 BOM' % ps1_name)

    b64 = base64.b64encode(raw).decode('ascii')
    chunks = [b64[i:i + 76] for i in range(0, len(b64), 76)]
    lines = '\r\n'.join('>> "%%B64FILE%%" echo %s' % c for c in chunks)

    extra = ",'-OriginDir','\\\"%ORIGIN%\\\"'" if with_origin else ''

    bat = BAT_TEMPLATE
    bat = bat.replace('%B64LINES%', lines)
    bat = bat.replace('%EXTRAARGS%', extra)
    bat = bat.replace('%PS1NAME%', ps1_name)
    bat = bat.replace('%PS1SIZE%', str(len(raw)))
    bat = bat.replace('%TITLE%', title)

    # Console scripts need -NoExit to keep the window open (otherwise it flashes and closes);
    # GUI scripts use -Wait and wait for the window to close.
    if keep_window:
        bat = bat.replace("-Verb RunAs -Wait", "-Verb RunAs")
        bat = bat.replace("'-STA','-File','\\\"%PS1FILE%\\\"'",
                          "'-NoExit','-File','\\\"%PS1FILE%\\\"'")

    bat = bat.replace('\r\n', '\n').replace('\n', '\r\n')
    target = out_dir or OUT_TOOLS
    if not os.path.isdir(target):
        os.makedirs(target)
    out = os.path.join(target, bat_name)
    with open(out, 'wb') as f:
        f.write(bat.encode('ascii'))

    print('OK  %-34s <- %-34s (ps1=%d bytes, b64 lines=%d, bat=%d bytes)'
          % (bat_name, ps1_name, len(raw), len(chunks), os.path.getsize(out)))
    return out


if __name__ == '__main__':
    # main entry points (double-click targets)
    build('Install-To-VHD.ps1', 'Install-System.bat', 'Virtual Hard Disk System', out_dir=OUT_MAIN)
    build('Uninstall-VHDSystem.ps1', 'Uninstall-System.bat', 'Uninstall System', out_dir=OUT_MAIN)
    # tools
    build('Repair-Boot.ps1', 'Repair-Boot-Menu.bat', 'Repair Boot Menu', with_origin=True)
    build('Fix-Boot-Entry-Device.ps1', 'Fix-Boot-Entry-Device.bat', 'Fix Boot Entry Target', with_origin=False, keep_window=True)
    build('Clean-Esp-DriveLetter.ps1', 'Clean-Esp-DriveLetter.bat', 'Clean Leftover Drive Letter', with_origin=False, keep_window=True)
    build('Restore-Boot-Menu.ps1', 'Restore-Boot-Menu.bat', 'Restore Boot Menu', with_origin=False, keep_window=True)
    build('Clean-Install-Residue.ps1', 'Clean-Install-Residue.bat', 'Clean Install Residue', with_origin=True, keep_window=True)
    build('Inject-Network-Drivers.ps1', 'Inject-Network-Drivers.bat', 'Inject Network Drivers', with_origin=False, keep_window=True)
    build('Inject-All-Drivers.ps1', 'Inject-All-Drivers.bat', 'Inject All Drivers', with_origin=False, keep_window=True)
    build('Diagnose-And-Install-Drivers.ps1', 'Diagnose-And-Install-Drivers.bat', 'Diagnose and Install Drivers', with_origin=False, keep_window=True)
    build('Clean-Ghost-GPU.ps1', 'Clean-Ghost-GPU.bat', 'Clean Ghost GPU', with_origin=False, keep_window=True)
    print('done')
