@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Clean Leftover Drive Letter

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

echo.
echo   Starting, please wait...
echo.
rem %~dp0 ends with a backslash, which would escape the quote when passed as an argument, so strip it
set "ORIGIN=%~dp0"
if "%ORIGIN:~-1%"=="\" set "ORIGIN=%ORIGIN:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%PS1FILE%\"' -Verb RunAs"
exit /b 0
