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
cd /d "%~dp0"

rem ---------------------------------------------------------------- admin rights
rem Ask for elevation once, here, on the bat itself - never inside a nested
rem   powershell -Command "... Start-Process -ArgumentList '\"...\"' ..."
rem string. That form only survives some consoles: when the escaping breaks,
rem powershell dies while parsing, this file reaches "exit /b 0", the window
rem closes and the user sees nothing but a flash - no message, and no log file
rem either (measured 2026-11-05, the whole English release was dead this way).
rem Doing it here and then running the script with a plain -File keeps every
rem error on screen.
fltmc >nul 2>&1
if errorlevel 1 (
    echo   Requesting administrator rights - confirm the UAC prompt...
    if "%~1"=="" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '%*' } catch { exit 9 }"
    )
    if errorlevel 9 (
        echo.
        echo   [ERROR] Could not get administrator rights.
        echo           Right-click this file and choose "Run as administrator".
        echo.
        pause
    )
    exit /b
)

rem ---------------------------------------------------------------- unpack
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
rem NOTE: never put a half-width ) inside an echo line that lives inside a
rem   parenthesised block. cmd treats it as the end of the block, the rest of
rem   the line becomes garbage and the whole batch dies with
rem   ". was unexpected at this time." before printing anything - measured
rem   2026-11-05, this single line killed all 11 English bats on startup.
rem   Colons, dashes and semicolons are safe; the Chinese build uses full-width
rem   parens, which cmd does not treat as syntax, so it was never affected.
if not "%GOT%"=="%NEED%" (
    echo.
    echo   [ERROR] Self-extraction failed - expected %NEED% bytes, got %GOT% bytes.
    echo           Copy this file again, or disable antivirus temporarily and retry.
    echo.
    pause
    exit /b 1
)
del "%B64FILE%" "%RAW%" >nul 2>&1

echo.
echo   Starting, please wait...
echo.

rem %~dp0 ends with a backslash. Appending "." gives a path without one, which
rem avoids the fragile  if "%X:~-1%"=="\"  comparison in a batch file.
rem No nested quoting anywhere below on purpose.
set "ORIGIN=%~dp0."

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%"%PSARGS% %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo   [ERROR] The script exited with code %RC%.
    echo           The unpacked script was kept for diagnosis:
    echo             %PS1FILE%
    echo           Text report, no window:
    echo             powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ConsoleMode
    echo.
    pause
    exit /b %RC%
)

rem [audit P3-17] Clean up after a successful run. Only payload.b64/.dat used to
rem   be deleted, so %TEMP% kept one folder plus one ps1 per run, forever.
rem   The ps1 is removed after the script has exited, never while it runs.
del "%PS1FILE%" >nul 2>&1
rmdir "%WORKDIR%" >nul 2>&1
%TAIL%
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

    ps_args = ' -OriginDir "%ORIGIN%"' if with_origin else ''
    # Console tools finish on their own; the script prints a report, so keep the
    # window up long enough to read it. GUI scripts close when the window is closed.
    tail = 'echo.\r\npause' if keep_window else ''

    bat = BAT_TEMPLATE
    bat = bat.replace('%B64LINES%', lines)
    bat = bat.replace('%PSARGS%', ps_args)
    bat = bat.replace('%TAIL%', tail)
    bat = bat.replace('%PS1NAME%', ps1_name)
    bat = bat.replace('%PS1SIZE%', str(len(raw)))
    bat = bat.replace('%TITLE%', title)

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
