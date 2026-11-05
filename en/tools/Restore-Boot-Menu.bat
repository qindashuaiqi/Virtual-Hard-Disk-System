@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Restore Boot Menu
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
set "PS1FILE=%WORKDIR%\Restore-Boot-Menu.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/PCMNCiAgUmVzdG9yZSBCb290IE1lbnUgKHN3aXRjaCBvZmYgYSBsZWZ0b3ZlciBib290IG1l
>> "%B64FILE%" echo bnUgaW4gb25lIGNsaWNrKQ0KICBBdXRob3I6IGNvbm5lY3RzZWdhYm90DQoNCiAgUHVycG9zZTog
>> "%B64FILE%" echo YWZ0ZXIgdW5pbnN0YWxsaW5nIGEgdmlydHVhbCBzeXN0ZW0sIGlmIHRoZSBib290IG1lbnUgc3Rp
>> "%B64FILE%" echo bGwgYXBwZWFycyAoaW5zdGVhZCBvZiBib290aW5nIHRoZSBvcmlnaW5hbCBzeXN0ZW0gZGlyZWN0
>> "%B64FILE%" echo bHkpLA0KICAgICAgICBydW4gdGhlIG1hdGNoaW5nIGJhdCBvbmNlLiBJdCB3aWxsOg0KICAgICAg
>> "%B64FILE%" echo ICAgIDEuIHNldCBkaXNwbGF5Ym9vdG1lbnUgdG8gTm8gKG5vIG1lbnUsIGJvb3QgdGhlIGRlZmF1
>> "%B64FILE%" echo bHQgc3lzdGVtIGRpcmVjdGx5KQ0KICAgICAgICAgIDIuIHNldCB0aW1lb3V0IHRvIDAgKG5vIHdh
>> "%B64FILE%" echo aXQsIGluc3RhbnQgYm9vdCkNCiAgICAgICAgd2hpY2ggcmVzdG9yZXMgdGhlIGRlZmF1bHQgIm5v
>> "%B64FILE%" echo IG1lbnUsIGJvb3QgdGhlIG9yaWdpbmFsIHN5c3RlbSBkaXJlY3RseSIgYmVoYXZpb3VyLg0KDQog
>> "%B64FILE%" echo IElmIHlvdSBjb25maWd1cmVkIGEgYm9vdCBtZW51IHlvdXJzZWxmIGJlZm9yZSAoYSBkdWFsLWJv
>> "%B64FILE%" echo b3Qgc2V0dXAsIGZvciBleGFtcGxlKSBhbmQgZG8gbm90IHdhbnQgaXQgc3dpdGNoZWQgb2ZmLA0K
>> "%B64FILE%" echo ICB1c2UgdGhlIHR3byBjb21tYW5kcyBiZWxvdyBpbnN0ZWFkIGFuZCBzZXQgdGltZW91dCB0byB0
>> "%B64FILE%" echo aGUgbnVtYmVyIG9mIHNlY29uZHMgeW91IHdhbnQ6DQogICAgICBiY2RlZGl0IC9zZXQge2Jvb3Rt
>> "%B64FILE%" echo Z3J9IGRpc3BsYXlib290bWVudSBObw0KICAgICAgYmNkZWRpdCAvc2V0IHtib290bWdyfSB0aW1l
>> "%B64FILE%" echo b3V0IDUNCiM+DQoNCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3JpcHQ6VmVy
>> "%B64FILE%" echo c2lvbiA9ICcxLjMyJw0KDQpmdW5jdGlvbiBUZXN0LUFkbWluIHsNCiAgICAkaWQgPSBbU2VjdXJp
>> "%B64FILE%" echo dHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKQ0KICAgICRwID0gTmV3
>> "%B64FILE%" echo LU9iamVjdCBTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbCgkaWQpDQogICAgcmV0
>> "%B64FILE%" echo dXJuICRwLklzSW5Sb2xlKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6
>> "%B64FILE%" echo QWRtaW5pc3RyYXRvcikNCn0NCg0KV3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAoIlJlc3RvcmUg
>> "%B64FILE%" echo Qm9vdCBNZW51IChzd2l0Y2ggb2ZmIGEgbGVmdG92ZXIgYm9vdCBtZW51KSB2ezB9IC0gYXV0aG9y
>> "%B64FILE%" echo OiBjb25uZWN0c2VnYWJvdCIgLWYgJFNjcmlwdDpWZXJzaW9uKQ0KV3JpdGUtSG9zdCAnPT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0nDQpXcml0ZS1Ib3N0ICcnDQoN
>> "%B64FILE%" echo CmlmICgtbm90IChUZXN0LUFkbWluKSkgew0KICAgIFdyaXRlLUhvc3QgJ1tFUlJPUl0gQWRtaW5p
>> "%B64FILE%" echo c3RyYXRvciByaWdodHMgYXJlIHJlcXVpcmVkLiBSaWdodC1jbGljayB0aGlzIHNjcmlwdCBhbmQg
>> "%B64FILE%" echo Y2hvb3NlICJSdW4gd2l0aCBQb3dlclNoZWxsIiwgb3IgcnVuIHRoZSBidW5kbGVkIGJhdCBhcyBh
>> "%B64FILE%" echo ZG1pbmlzdHJhdG9yLicgLUZvcmVncm91bmRDb2xvciBSZWQNCiAgICBXcml0ZS1Ib3N0ICcnDQog
>> "%B64FILE%" echo ICAgV3JpdGUtSG9zdCAnUHJlc3MgYW55IGtleSB0byBleGl0Li4uJw0KICAgICRudWxsID0gJEhv
>> "%B64FILE%" echo c3QuVUkuUmF3VUkuUmVhZEtleSgnTm9FY2hvLEluY2x1ZGVLZXlEb3duJykNCiAgICBleGl0IDEN
>> "%B64FILE%" echo Cn0NCg0KV3JpdGUtSG9zdCAnQWJvdXQgdG8gcnVuOicNCldyaXRlLUhvc3QgJyAgYmNkZWRpdCAv
>> "%B64FILE%" echo c2V0IHtib290bWdyfSBkaXNwbGF5Ym9vdG1lbnUgTm8gICAobm8gbWVudSBhdCBib290KScNCldy
>> "%B64FILE%" echo aXRlLUhvc3QgJyAgYmNkZWRpdCAvc2V0IHtib290bWdyfSB0aW1lb3V0IDAgICAgICAgICAgICAo
>> "%B64FILE%" echo bm8gd2FpdCwgYm9vdCB0aGUgZGVmYXVsdCBzeXN0ZW0gZGlyZWN0bHkpJw0KV3JpdGUtSG9zdCAn
>> "%B64FILE%" echo Jw0KV3JpdGUtSG9zdCAnTm90ZTogaWYgdGhpcyBpcyBhIG11bHRpLWJvb3QgbWFjaGluZSAoYW5v
>> "%B64FILE%" echo dGhlciBXaW5kb3dzLCBMaW51eCBvciBXaW5QRSBlbnRyeSBleGlzdHMpLCcgLUZvcmVncm91bmRD
>> "%B64FILE%" echo b2xvciBZZWxsb3cNCldyaXRlLUhvc3QgJyAgICAgIHRoZSBtZW51IGlzIGdvbmUgYW5kIHlvdSBj
>> "%B64FILE%" echo YW4gbm8gbG9uZ2VyIGNob29zZSBhIHN5c3RlbS4gVG8gcmVzdG9yZSBpdCwgcnVuIGFzIGFkbWlu
>> "%B64FILE%" echo aXN0cmF0b3I6JyAtRm9yZWdyb3VuZENvbG9yIFllbGxvdw0KV3JpdGUtSG9zdCAnICAgICAgICAg
>> "%B64FILE%" echo IGJjZGVkaXQgL3NldCB7Ym9vdG1ncn0gZGlzcGxheWJvb3RtZW51IFllcycgLUZvcmVncm91bmRD
>> "%B64FILE%" echo b2xvciBZZWxsb3cNCldyaXRlLUhvc3QgJyAgICAgICAgICBiY2RlZGl0IC9zZXQge2Jvb3RtZ3J9
>> "%B64FILE%" echo IHRpbWVvdXQgMTAnIC1Gb3JlZ3JvdW5kQ29sb3IgWWVsbG93DQpXcml0ZS1Ib3N0ICcnDQokYW5z
>> "%B64FILE%" echo ID0gUmVhZC1Ib3N0ICdDb250aW51ZT8gVHlwZSB5IGFuZCBwcmVzcyBFbnRlciB0byBjb25maXJt
>> "%B64FILE%" echo LCBvciBqdXN0IHByZXNzIEVudGVyIHRvIGNhbmNlbCcNCmlmICgkYW5zIC1uZSAneScgLWFuZCAk
>> "%B64FILE%" echo YW5zIC1uZSAnWScpIHsNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9zdCAnQ2FuY2Vs
>> "%B64FILE%" echo bGVkLCBub3RoaW5nIHdhcyBjaGFuZ2VkLicgLUZvcmVncm91bmRDb2xvciBDeWFuDQogICAgV3Jp
>> "%B64FILE%" echo dGUtSG9zdCAnJw0KICAgIFdyaXRlLUhvc3QgJ1ByZXNzIGFueSBrZXkgdG8gZXhpdC4uLicNCiAg
>> "%B64FILE%" echo ICAkbnVsbCA9ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXkoJ05vRWNobyxJbmNsdWRlS2V5RG93bicp
>> "%B64FILE%" echo DQogICAgZXhpdCAwDQp9DQoNCldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgJ1N3aXRjaGluZyB0
>> "%B64FILE%" echo aGUgYm9vdCBtZW51IG9mZi4uLicNCiRyMSA9ICYgYmNkZWRpdCAvc2V0ICd7Ym9vdG1ncn0nIGRp
>> "%B64FILE%" echo c3BsYXlib290bWVudSBObyAyPiYxIHwgT3V0LVN0cmluZw0KV3JpdGUtSG9zdCAoIiAgZGlzcGxh
>> "%B64FILE%" echo eWJvb3RtZW51IE5vICA9PiAgezB9IiAtZiAoJHIxIC1yZXBsYWNlICdccysnLCAnICcpLlRyaW0o
>> "%B64FILE%" echo KSkNCg0KJHIyID0gJiBiY2RlZGl0IC9zZXQgJ3tib290bWdyfScgdGltZW91dCAwIDI+JjEgfCBP
>> "%B64FILE%" echo dXQtU3RyaW5nDQpXcml0ZS1Ib3N0ICgiICB0aW1lb3V0IDAgICAgICAgICAgID0+ICB7MH0iIC1m
>> "%B64FILE%" echo ICgkcjIgLXJlcGxhY2UgJ1xzKycsICcgJykuVHJpbSgpKQ0KDQpXcml0ZS1Ib3N0ICcnDQpXcml0
>> "%B64FILE%" echo ZS1Ib3N0ICdEb25lLiBUaGUgbWFjaGluZSBub3cgYm9vdHMgdGhlIGRlZmF1bHQgc3lzdGVtIGRp
>> "%B64FILE%" echo cmVjdGx5IHdpdGhvdXQgYSBtZW51LicgLUZvcmVncm91bmRDb2xvciBHcmVlbg0KV3JpdGUtSG9z
>> "%B64FILE%" echo dCAnJw0KV3JpdGUtSG9zdCAnUHJlc3MgYW55IGtleSB0byBleGl0Li4uJw0KJG51bGwgPSAkSG9z
>> "%B64FILE%" echo dC5VSS5SYXdVSS5SZWFkS2V5KCdOb0VjaG8sSW5jbHVkZUtleURvd24nKQ0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=3294"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" %*
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
echo.
pause
exit /b 0
