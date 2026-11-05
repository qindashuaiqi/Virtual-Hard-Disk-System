@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Clean Leftover Drive Letter
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
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
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
set "PS1FILE=%WORKDIR%\Clean-Esp-DriveLetter.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/IyBSZW1vdmUgYSBsZWZ0b3ZlciBFU1AgZHJpdmUgbGV0dGVyIChTOikNCiMgUnVuIGFzIGFk
>> "%B64FILE%" echo bWluaXN0cmF0b3IuIE9ubHkgdGhlICJhY2Nlc3MgcGF0aCIgaXMgcmVtb3ZlZCwgbm8gcGFydGl0
>> "%B64FILE%" echo aW9uIGRhdGEgaXMgdG91Y2hlZCAtIGNvbXBsZXRlbHkgc2FmZS4NCiMgQXV0aG9yOiBjb25uZWN0
>> "%B64FILE%" echo c2VnYWJvdA0KJFNjcmlwdDpWZXJzaW9uID0gJzEuMzEnDQpXcml0ZS1Ib3N0ICgiQ2xlYW4gbGVm
>> "%B64FILE%" echo dG92ZXIgZHJpdmUgbGV0dGVyIHZ7MH0gLSBhdXRob3I6IGNvbm5lY3RzZWdhYm90IiAtZiAkU2Ny
>> "%B64FILE%" echo aXB0OlZlcnNpb24pDQpXcml0ZS1Ib3N0ICI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT0iDQokZXNwR3VpZCA9ICdjMTJhNzMyOC1mODFmLTExZDItYmE0Yi0wMGEwYzkz
>> "%B64FILE%" echo ZWM5M2InDQpmb3JlYWNoICgkcGFydCBpbiAoR2V0LVBhcnRpdGlvbiAtRUEgU2lsZW50bHlDb250
>> "%B64FILE%" echo aW51ZSkpIHsNCiAgICBpZiAoLW5vdCAkcGFydC5Ecml2ZUxldHRlcikgeyBjb250aW51ZSB9DQog
>> "%B64FILE%" echo ICAgJGdwdCA9IChbc3RyaW5nXSRwYXJ0LkdwdFR5cGUgLXJlcGxhY2UgJ1t7fV0nLCAnJykuVG9M
>> "%B64FILE%" echo b3dlcigpDQogICAgaWYgKCRncHQgLW5lICRlc3BHdWlkKSB7IGNvbnRpbnVlIH0NCiAgICAkZGwg
>> "%B64FILE%" echo PSBbc3RyaW5nXSRwYXJ0LkRyaXZlTGV0dGVyDQogICAgV3JpdGUtSG9zdCAoIkVGSSBzeXN0ZW0g
>> "%B64FILE%" echo cGFydGl0aW9uIGhvbGRpbmcgZHJpdmUgbGV0dGVyIHswfTogKERpc2t7MX0gUGFydHsyfSkiIC1m
>> "%B64FILE%" echo ICRkbCwgJHBhcnQuRGlza051bWJlciwgJHBhcnQuUGFydGl0aW9uTnVtYmVyKQ0KICAgIHRyeSB7
>> "%B64FILE%" echo DQogICAgICAgICMgVXNlIC1Ecml2ZUxldHRlcjogLUFjY2Vzc1BhdGggZXhwZWN0cyBhIHZvbHVt
>> "%B64FILE%" echo ZSBhY2Nlc3MgcGF0aCAoIlM6XCIpLCBhbmQgIlM6IiBpcyByZWplY3RlZCBhcyBpbnZhbGlkDQog
>> "%B64FILE%" echo ICAgICAgIFJlbW92ZS1QYXJ0aXRpb25BY2Nlc3NQYXRoIC1EaXNrTnVtYmVyICRwYXJ0LkRpc2tO
>> "%B64FILE%" echo dW1iZXIgLVBhcnRpdGlvbk51bWJlciAkcGFydC5QYXJ0aXRpb25OdW1iZXIgLURyaXZlTGV0dGVy
>> "%B64FILE%" echo ICRkbCAtRUEgU3RvcCB8IE91dC1OdWxsDQogICAgICAgIFdyaXRlLUhvc3QgIlJlbW92ZWQgZHJp
>> "%B64FILE%" echo dmUgbGV0dGVyICRkbGA6ICAoZ3JlZW4gPSBzdWNjZXNzKSIgLUZvcmVncm91bmRDb2xvciBHcmVl
>> "%B64FILE%" echo bg0KICAgIH0gY2F0Y2ggew0KICAgICAgICBXcml0ZS1Ib3N0ICgiUmVtb3ZhbCBmYWlsZWQ6IHsw
>> "%B64FILE%" echo fSIgLWYgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIC1Gb3JlZ3JvdW5kQ29sb3IgUmVkDQogICAgfQ0K
>> "%B64FILE%" echo fQ0KV3JpdGUtSG9zdCAiIg0KV3JpdGUtSG9zdCAiRG9uZS4gVGhpcyB3aW5kb3cgY2xvc2VzIGlu
>> "%B64FILE%" echo IDUgc2Vjb25kcy4iDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=1325"
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
del "%B64FILE%" "%RAW%" >nul 2>&1

echo.
echo   Starting, please wait...
echo.

rem %~dp0 ends with a backslash. Appending "." gives a path without one, which
rem avoids the fragile  if "%X:~-1%"=="\"  comparison in a batch file.
rem No nested quoting anywhere below on purpose.
set "ORIGIN=%~dp0."

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo   [ERROR] The script exited with code %RC%.
    echo           Text report, no window:
    echo             powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ConsoleMode
    echo.
    pause
    exit /b %RC%
)
echo.
pause
exit /b 0
