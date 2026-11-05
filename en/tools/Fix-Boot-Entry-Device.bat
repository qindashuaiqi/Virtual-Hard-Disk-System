@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Fix Boot Entry Target
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
set "PS1FILE=%WORKDIR%\Fix-Boot-Entry-Device.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/PCMNCiAgRml4IEJvb3QgRW50cnkgVGFyZ2V0IChWaXJ0dWFsIEhhcmQgRGlzayBTeXN0ZW0p
>> "%B64FILE%" echo DQogIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QNCg0KICBQdXJwb3NlOiBhZnRlciBpbnN0YWxsaW5n
>> "%B64FILE%" echo IGEgdmlydHVhbCBzeXN0ZW0sIHRoZSBib290IG1lbnUgbWF5DQogICAgLSBsaXN0IHRoZSBlbnRy
>> "%B64FILE%" echo eSBidXQgZmFpbCB3aXRoIDB4YzAwMDAwMGYgLyBmaWxlIG5vdCBmb3VuZCBvbiBzZWxlY3Rpb24N
>> "%B64FILE%" echo CiAgICAtIG9yIG5vdCBsaXN0IGl0IGF0IGFsbA0KICBUaGUgY2F1c2UgaXMgYSB3cm9uZyAudmhk
>> "%B64FILE%" echo eCBwYXRoIGluIHRoZSBtZW51IGVudHJ5IChvciBhIG1pc3NpbmcgZGlzcGxheW9yZGVyKS4gVGhp
>> "%B64FILE%" echo cyB0b29sIHdpbGw6DQoNCiAgICAxLiBmaW5kIGV2ZXJ5IHZpcnR1YWwgc3lzdGVtIGluc3RhbGxl
>> "%B64FILE%" echo ZCBieSB0aGlzIHRvb2xraXQgKHRoZSBvbmVzIHdpdGggYW4geHh4LmJvb3QudHh0KQ0KICAgIDIu
>> "%B64FILE%" echo IGNvbXBhcmUgdGhlIHBhdGggaXRzIG1lbnUgZW50cnkgcG9pbnRzIGF0IHdpdGggdGhlIHJlYWwg
>> "%B64FILE%" echo ZmlsZSBwYXRoLCBjaGFyYWN0ZXIgYnkgY2hhcmFjdGVyDQogICAgMy4gZml4IGl0IHdoZW4gd3Jv
>> "%B64FILE%" echo bmc7IHJlY3JlYXRlIHRoZSBlbnRyeSBmcm9tIHRoZSByZWNvcmQgd2hlbiBtaXNzaW5nOyBhZGQg
>> "%B64FILE%" echo aXQgYmFjayB3aGVuIGl0IGlzIG5vdCBpbiB0aGUgbWVudQ0KDQogIFRoZSBjb250ZW50IG9mIHRo
>> "%B64FILE%" echo ZSB2aXJ0dWFsIGRpc2sgaXMgbmV2ZXIgdG91Y2hlZCwgYW5kIG5laXRoZXIgaXMgdGhlIGV4aXN0
>> "%B64FILE%" echo aW5nIHN5c3RlbS4NCiM+DQoNCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3Jp
>> "%B64FILE%" echo cHQ6VmVyc2lvbiA9ICcxLjMyJw0KJFNjcmlwdDpMb2dGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVN
>> "%B64FILE%" echo UCAoIkZpeC1Cb290RW50cnktezB9LmxvZyIgLWYgKEdldC1EYXRlIC1Gb3JtYXQgJ3l5eXlNTWRk
>> "%B64FILE%" echo JykpDQoNCmZ1bmN0aW9uIFdyaXRlLUxvZyB7DQogICAgcGFyYW0oW3N0cmluZ10kTXNnLCBbc3Ry
>> "%B64FILE%" echo aW5nXSRMZXZlbCA9ICdJTkZPJykNCiAgICAkbGluZSA9ICJbezB9XSBbezF9XSB7Mn0iIC1mIChH
>> "%B64FILE%" echo ZXQtRGF0ZSAtRm9ybWF0ICdISDptbTpzcycpLCAkTGV2ZWwsICRNc2cNCiAgICB0cnkgeyBBZGQt
>> "%B64FILE%" echo Q29udGVudCAtTGl0ZXJhbFBhdGggJFNjcmlwdDpMb2dGaWxlIC1WYWx1ZSAkbGluZSAtRW5jb2Rp
>> "%B64FILE%" echo bmcgVVRGOCB9IGNhdGNoIHt9DQogICAgJGMgPSAnR3JheScNCiAgICBpZiAoJExldmVsIC1lcSAn
>> "%B64FILE%" echo T0snKSB7ICRjID0gJ0dyZWVuJyB9DQogICAgaWYgKCRMZXZlbCAtZXEgJ1dBUk4nKSB7ICRjID0g
>> "%B64FILE%" echo J1llbGxvdycgfQ0KICAgIGlmICgkTGV2ZWwgLWVxICdFUlInKSB7ICRjID0gJ1JlZCcgfQ0KICAg
>> "%B64FILE%" echo IFdyaXRlLUhvc3QgJGxpbmUgLUZvcmVncm91bmRDb2xvciAkYw0KfQ0KDQpmdW5jdGlvbiBUZXN0
>> "%B64FILE%" echo LUFkbWluIHsNCiAgICAkaWQgPSBbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06
>> "%B64FILE%" echo OkdldEN1cnJlbnQoKQ0KICAgICRwID0gTmV3LU9iamVjdCBTZWN1cml0eS5QcmluY2lwYWwuV2lu
>> "%B64FILE%" echo ZG93c1ByaW5jaXBhbCgkaWQpDQogICAgcmV0dXJuICRwLklzSW5Sb2xlKFtTZWN1cml0eS5Qcmlu
>> "%B64FILE%" echo Y2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6QWRtaW5pc3RyYXRvcikNCn0NCg0KZnVuY3Rpb24g
>> "%B64FILE%" echo SW52b2tlLUJjZCB7DQogICAgcGFyYW0oW3N0cmluZ1tdXSRCY2RBcmdzLCBbc3RyaW5nXSRUYWcg
>> "%B64FILE%" echo PSAnJykNCiAgICAkdHh0ID0gJycNCiAgICB0cnkgeyAkdHh0ID0gKCYgYmNkZWRpdCBAQmNkQXJn
>> "%B64FILE%" echo cyAyPiYxIHwgT3V0LVN0cmluZykgfSBjYXRjaCB7ICR0eHQgPSAiY2FsbCBmYWlsZWQ6ICQoJF8u
>> "%B64FILE%" echo RXhjZXB0aW9uLk1lc3NhZ2UpIiB9DQogICAgJGNvZGUgPSAkTEFTVEVYSVRDT0RFDQogICAgJGNs
>> "%B64FILE%" echo ZWFuID0gKCR0eHQgLXJlcGxhY2UgJ1xzKycsICcgJykuVHJpbSgpDQogICAgV3JpdGUtTG9nICgi
>> "%B64FILE%" echo YmNkZWRpdCB7MH0gW3sxfV0gPT4gZXhpdD17Mn0gIHszfSIgLWYgJFRhZywgKCRCY2RBcmdzIC1q
>> "%B64FILE%" echo b2luICcgJyksICRjb2RlLCAkY2xlYW4pDQogICAgJGJhZCA9ICgkdHh0IC1tYXRjaCAn5om+5LiN
>> "%B64FILE%" echo 5YiwfG5vdCBmb3VuZHzml6DmlYh8aW52YWxpZHzmi5Lnu518ZGVuaWVkfOWksei0pXxmYWlsZWR8
>> "%B64FILE%" echo 6ZSZ6K+vfGVycm9yJykNCiAgICByZXR1cm4gQHsgT2sgPSAoKCRjb2RlIC1lcSAwKSAtYW5kICgt
>> "%B64FILE%" echo bm90ICRiYWQpKTsgQ29kZSA9ICRjb2RlOyBUZXh0ID0gJGNsZWFuOyBSYXcgPSAkdHh0IH0NCn0N
>> "%B64FILE%" echo Cg0KIyBiY2RlZGl0IHByaW50cyB0aHJvdWdoIHRoZSBjb25zb2xlIGNvZGUgcGFnZSwgc28gYSBj
>> "%B64FILE%" echo aGFyYWN0ZXIgdGhlIHBhZ2UgY2Fubm90IGNhcnJ5IGNvbWVzDQojIGJhY2sgYXMgIj8iLiBUaGUg
>> "%B64FILE%" echo RW5nbGlzaCBsYXVuY2hlciBydW5zICJjaGNwIDQzNyIsIHdoaWNoIHR1cm5lZCBldmVyeSBDaGlu
>> "%B64FILE%" echo ZXNlIGNoYXJhY3RlciBpbg0KIyBhIHBhdGggaW50byAiPyIgYW5kIG1hZGUgYSBjb3JyZWN0IEJD
>> "%B64FILE%" echo RCB3cml0ZSBsb29rIGxpa2UgYSB3cm9uZyBwYXRoLg0KZnVuY3Rpb24gVGVzdC1CY2RUZXh0U2Ft
>> "%B64FILE%" echo ZSB7DQogICAgcGFyYW0oW3N0cmluZ10kV2FudCwgW3N0cmluZ10kR290KQ0KICAgIGlmICgkbnVs
>> "%B64FILE%" echo bCAtZXEgJEdvdCkgeyByZXR1cm4gJGZhbHNlIH0NCiAgICBpZiAoJEdvdCAtZXEgJFdhbnQpIHsg
>> "%B64FILE%" echo cmV0dXJuICR0cnVlIH0NCiAgICBpZiAoJEdvdC5MZW5ndGggLW5lICRXYW50Lkxlbmd0aCkgeyBy
>> "%B64FILE%" echo ZXR1cm4gJGZhbHNlIH0NCiAgICBmb3IgKCRpID0gMDsgJGkgLWx0ICRXYW50Lkxlbmd0aDsgJGkr
>> "%B64FILE%" echo Kykgew0KICAgICAgICBpZiAoJEdvdFskaV0gLWVxICRXYW50WyRpXSkgeyBjb250aW51ZSB9DQog
>> "%B64FILE%" echo ICAgICAgIGlmICgkR290WyRpXSAtZXEgJz8nIC1hbmQgW2ludF1bY2hhcl0kV2FudFskaV0gLWd0
>> "%B64FILE%" echo IDEyNykgeyBjb250aW51ZSB9DQogICAgICAgIHJldHVybiAkZmFsc2UNCiAgICB9DQogICAgcmV0
>> "%B64FILE%" echo dXJuICR0cnVlDQp9DQoNCiMgRnVsbCBwYXRoIC0+IEJDRCB2aGQ9IHN5bnRheC4gVGhlIGludGVy
>> "%B64FILE%" echo bWVkaWF0ZSBzdWJmb2xkZXIgbXVzdCBiZSBwcmVzZXJ2ZWQ6DQojICAgRDpcVmlydHVhbERpc2tz
>> "%B64FILE%" echo XG1haW1haS52aGR4ICAtPiAgdmhkPVtEOl1cVmlydHVhbERpc2tzXG1haW1haS52aGR4DQpmdW5j
>> "%B64FILE%" echo dGlvbiBHZXQtVmhkQmNkRGV2aWNlIHsNCiAgICBwYXJhbShbc3RyaW5nXSRGdWxsUGF0aCkNCiAg
>> "%B64FILE%" echo ICAkZnVsbCA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZ1bGxQYXRoKCRGdWxsUGF0aCkNCiAgICAk
>> "%B64FILE%" echo cm9vdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldFBhdGhSb290KCRmdWxsKQ0KICAgIGlmICgtbm90
>> "%B64FILE%" echo ICRyb290IC1vciAkcm9vdC5MZW5ndGggLWx0IDMpIHsgdGhyb3cgIkludmFsaWQgcGF0aDogJEZ1
>> "%B64FILE%" echo bGxQYXRoIiB9DQogICAgJGxldHRlciA9ICRyb290LlN1YnN0cmluZygwLCAxKS5Ub1VwcGVyKCkN
>> "%B64FILE%" echo CiAgICAkcmVsID0gJGZ1bGwuU3Vic3RyaW5nKCRyb290Lkxlbmd0aCkuVHJpbVN0YXJ0KCdcJykN
>> "%B64FILE%" echo CiAgICBpZiAoLW5vdCAkcmVsKSB7IHRocm93ICJJbnZhbGlkIHBhdGg6ICRGdWxsUGF0aCIgfQ0K
>> "%B64FILE%" echo ICAgIHJldHVybiAidmhkPVskKCRsZXR0ZXIpOl1cJHJlbCINCn0NCg0KIyBSZXZlcnNlIHBhcnNp
>> "%B64FILE%" echo bmcsIHVzZWQgdG8gY29tcGFyZSBjaGFyYWN0ZXIgYnkgY2hhcmFjdGVyIHdpdGggdGhlIHJlYWwg
>> "%B64FILE%" echo cGF0aA0KZnVuY3Rpb24gR2V0LUZ1bGxQYXRoRnJvbUJjZERldmljZSB7DQogICAgcGFyYW0oW3N0
>> "%B64FILE%" echo cmluZ10kRGV2KQ0KICAgIGlmICgtbm90ICREZXYpIHsgcmV0dXJuICcnIH0NCiAgICAkbSA9IFty
>> "%B64FILE%" echo ZWdleF06Ok1hdGNoKCREZXYsICdedmhkPVxbKFtBLVphLXpdKTpcXVxcKC4rKSQnKQ0KICAgIGlm
>> "%B64FILE%" echo ICgtbm90ICRtLlN1Y2Nlc3MpIHsgcmV0dXJuICcnIH0NCiAgICByZXR1cm4gKCJ7MH06XHsxfSIg
>> "%B64FILE%" echo LWYgJG0uR3JvdXBzWzFdLlZhbHVlLlRvVXBwZXIoKSwgJG0uR3JvdXBzWzJdLlZhbHVlKQ0KfQ0K
>> "%B64FILE%" echo DQojIFNjYW4gZXZlcnkgZml4ZWQgTlRGUyBkcml2ZSBmb3IgdmhkeC4gQnJlYWR0aC1maXJzdCB3
>> "%B64FILE%" echo aXRoIGZvbGRlci1uYW1lIHBydW5pbmcsDQojIG5ldmVyIGVudGVyaW5nIFdpbmRvd3MgLyBVc2Vy
>> "%B64FILE%" echo cyAvIHRoZSByZWN5Y2xlIGJpbiwgc28gZGVwdGggNiBzdGF5cyBmYXN0Lg0KZnVuY3Rpb24gR2V0
>> "%B64FILE%" echo LUFsbFZoZHhGaWxlIHsNCiAgICBwYXJhbShbaW50XSRNYXhEZXB0aCA9IDYpDQogICAgJHNraXAg
>> "%B64FILE%" echo PSBAKCckUkVDWUNMRS5CSU4nLCAnU3lzdGVtIFZvbHVtZSBJbmZvcm1hdGlvbicsICdXaW5kb3dz
>> "%B64FILE%" echo JywgJ1Byb2dyYW0gRmlsZXMnLA0KICAgICAgICAgICAgICAnUHJvZ3JhbSBGaWxlcyAoeDg2KScs
>> "%B64FILE%" echo ICdQcm9ncmFtRGF0YScsICdVc2VycycsICckV2luUkVBZ2VudCcsICdSZWNvdmVyeScsDQogICAg
>> "%B64FILE%" echo ICAgICAgICAgICdub2RlX21vZHVsZXMnLCAnLmdpdCcsICdXaW5TeFMnKQ0KICAgICRmb3VuZCA9
>> "%B64FILE%" echo IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KICAgIGZvcmVhY2ggKCR2
>> "%B64FILE%" echo IGluIEAoR2V0LVZvbHVtZSAtRUEgU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1u
>> "%B64FILE%" echo b3QgJHYuRHJpdmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRmlsZVN5c3Rl
>> "%B64FILE%" echo bSAtbmUgJ05URlMnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgaWYgKCR2LkRyaXZlVHlwZSAtbmUg
>> "%B64FILE%" echo J0ZpeGVkJykgeyBjb250aW51ZSB9DQogICAgICAgICRxdWV1ZSA9IE5ldy1PYmplY3QgU3lzdGVt
>> "%B64FILE%" echo LkNvbGxlY3Rpb25zLlF1ZXVlDQogICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoIiQoJHYuRHJpdmVM
>> "%B64FILE%" echo ZXR0ZXIpOlwiLCAwKSkNCiAgICAgICAgd2hpbGUgKCRxdWV1ZS5Db3VudCAtZ3QgMCkgew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgJGN1ciA9ICRxdWV1ZS5EZXF1ZXVlKCkNCiAgICAgICAgICAgICRkaXIgPSBbc3Ry
>> "%B64FILE%" echo aW5nXSRjdXJbMF0NCiAgICAgICAgICAgICRkID0gW2ludF0kY3VyWzFdDQogICAgICAgICAgICB0
>> "%B64FILE%" echo cnkgew0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRmIGluIFtTeXN0ZW0uSU8uRGlyZWN0b3J5
>> "%B64FILE%" echo XTo6R2V0RmlsZXMoJGRpciwgJyoudmhkeCcpKSB7DQogICAgICAgICAgICAgICAgICAgIFt2b2lk
>> "%B64FILE%" echo XSRmb3VuZC5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLklPLkZpbGVJbmZvICRmKSkNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICB9DQogICAgICAgICAgICB9IGNhdGNoIHt9DQogICAgICAgICAgICBpZiAoJGQgLWdl
>> "%B64FILE%" echo ICRNYXhEZXB0aCkgeyBjb250aW51ZSB9DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgIGZvcmVhY2ggKCRzdWIgaW4gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpFbnVtZXJhdGVEaXJl
>> "%B64FILE%" echo Y3RvcmllcygkZGlyKSkgew0KICAgICAgICAgICAgICAgICAgICBpZiAoJHNraXAgLWNvbnRhaW5z
>> "%B64FILE%" echo IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRzdWIpKSB7IGNvbnRpbnVlIH0NCiAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICAgICAgICAgIGlmIChbU3lzdGVt
>> "%B64FILE%" echo LklPLkZpbGVdOjpHZXRBdHRyaWJ1dGVzKCRzdWIpIC1iYW5kIFtTeXN0ZW0uSU8uRmlsZUF0dHJp
>> "%B64FILE%" echo YnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB9
>> "%B64FILE%" echo IGNhdGNoIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICAkcXVldWUuRW5xdWV1ZShA
>> "%B64FILE%" echo KCRzdWIsICgkZCArIDEpKSkNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9IGNhdGNo
>> "%B64FILE%" echo IHt9DQogICAgICAgIH0NCiAgICB9DQogICAgcmV0dXJuICRmb3VuZC5Ub0FycmF5KCkNCn0NCg0K
>> "%B64FILE%" echo V3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAnRml4IEJvb3QgRW50cnkgVGFyZ2V0IC0gYXV0aG9y
>> "%B64FILE%" echo OiBjb25uZWN0c2VnYWJvdCcNCldyaXRlLUhvc3QgJz09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09Jw0KV3JpdGUtSG9zdCAnJw0KDQppZiAoLW5vdCAoVGVzdC1BZG1pbikpIHsN
>> "%B64FILE%" echo CiAgICBXcml0ZS1Ib3N0ICdBZG1pbmlzdHJhdG9yIHJpZ2h0cyBhcmUgcmVxdWlyZWQuJyAtRm9y
>> "%B64FILE%" echo ZWdyb3VuZENvbG9yIFJlZA0KICAgIFdyaXRlLUhvc3QgJ0Nsb3NlIHRoaXMgd2luZG93IGFuZCBk
>> "%B64FILE%" echo b3VibGUtY2xpY2sgRml4LUJvb3QtRW50cnktRGV2aWNlLmJhdCBpbnN0ZWFkOyBpdCByZXF1ZXN0
>> "%B64FILE%" echo cyBlbGV2YXRpb24gYnkgaXRzZWxmLicNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9z
>> "%B64FILE%" echo dCAnUHJlc3MgYW55IGtleSB0byBleGl0Li4uJw0KICAgICRudWxsID0gJEhvc3QuVUkuUmF3VUku
>> "%B64FILE%" echo UmVhZEtleSgnTm9FY2hvLEluY2x1ZGVLZXlEb3duJykNCiAgICByZXR1cm4NCn0NCg0KV3JpdGUt
>> "%B64FILE%" echo TG9nICJMb2c6ICQoJFNjcmlwdDpMb2dGaWxlKSINCg0KIyAtLS0tLS0tLS0tIEJhY2sgdXAgdGhl
>> "%B64FILE%" echo IGFjdGl2ZSBCQ0QgZmlyc3QgLS0tLS0tLS0tLQ0KJHN0YW1wID0gR2V0LURhdGUgLUZvcm1hdCAn
>> "%B64FILE%" echo eXl5eU1NZGQtSEhtbXNzJw0KJGJrID0gSm9pbi1QYXRoICRlbnY6VEVNUCAiYmNkLWJhY2t1cC0k
>> "%B64FILE%" echo c3RhbXAuYmNkIg0KJHJiID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZXhwb3J0JywgJGJrKSAt
>> "%B64FILE%" echo VGFnICdleHBvcnQnDQppZiAoJHJiLk9rIC1hbmQgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGJr
>> "%B64FILE%" echo KSkgew0KICAgIFdyaXRlLUxvZyAiQkNEIGJhY2tlZCB1cDogJGJrIiAnT0snDQp9IGVsc2Ugew0K
>> "%B64FILE%" echo ICAgIFdyaXRlLUxvZyAnQkNEIGJhY2t1cCBmYWlsZWQsIGNvbnRpbnVpbmcgKG9ubHkgdGhlIGRl
>> "%B64FILE%" echo dmljZSBwYXRoIGFuZCB0aGUgbWVudSBvcmRlciBjaGFuZ2UgYmVsb3csIHZlcnkgbG93IHJpc2sp
>> "%B64FILE%" echo JyAnV0FSTicNCn0NCg0KIyAtLS0tLS0tLS0tIEZpbmQgdGhlIHRhcmdldHMgLS0tLS0tLS0tLQ0K
>> "%B64FILE%" echo V3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAnU2VhcmNoaW5nIGZvciBpbnN0YWxsZWQgdmlydHVh
>> "%B64FILE%" echo bCBzeXN0ZW1zLi4uJw0KJGl0ZW1zID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJy
>> "%B64FILE%" echo YXlMaXN0DQpmb3JlYWNoICgkZiBpbiBAKEdldC1BbGxWaGR4RmlsZSkpIHsNCiAgICAkc3QgPSBb
>> "%B64FILE%" echo U3lzdGVtLklPLlBhdGhdOjpDaGFuZ2VFeHRlbnNpb24oJGYuRnVsbE5hbWUsICcuYm9vdC50eHQn
>> "%B64FILE%" echo KQ0KICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdCkpIHsgY29udGludWUg
>> "%B64FILE%" echo fQ0KICAgICRzZCA9IEB7fQ0KICAgIGZvcmVhY2ggKCRsbiBpbiAoR2V0LUNvbnRlbnQgLUxpdGVy
>> "%B64FILE%" echo YWxQYXRoICRzdCAtRW5jb2RpbmcgVVRGOCAtRUEgU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAg
>> "%B64FILE%" echo ICAgaWYgKCRsbiAtbWF0Y2ggJ15ccyooW14jPV0rKT0oLiopJCcpIHsgJHNkWyRtYXRjaGVzWzFd
>> "%B64FILE%" echo LlRyaW0oKV0gPSAkbWF0Y2hlc1syXS5UcmltKCkgfQ0KICAgIH0NCiAgICAkZyA9IFtzdHJpbmdd
>> "%B64FILE%" echo JHNkWydHdWlkJ10NCiAgICBpZiAoJGcgLW5vdG1hdGNoICdeXHtbMC05YS1mQS1GLV17MzZ9XH0k
>> "%B64FILE%" echo JykgeyBjb250aW51ZSB9DQogICAgW3ZvaWRdJGl0ZW1zLkFkZChbUFNDdXN0b21PYmplY3RdQHsN
>> "%B64FILE%" echo CiAgICAgICAgUGF0aCAgPSAkZi5GdWxsTmFtZQ0KICAgICAgICBHdWlkICA9ICRnDQogICAgICAg
>> "%B64FILE%" echo IE5hbWUgID0gW3N0cmluZ10kc2RbJ05hbWUnXQ0KICAgICAgICBEZXNjICA9IFtzdHJpbmddJHNk
>> "%B64FILE%" echo WydEZXNjJ10NCiAgICAgICAgU3RhdGUgPSAkc3QNCiAgICB9KQ0KfQ0KDQppZiAoJGl0ZW1zLkNv
>> "%B64FILE%" echo dW50IC1lcSAwKSB7DQogICAgV3JpdGUtSG9zdCAnJw0KICAgIFdyaXRlLUhvc3QgJ05vIHZpcnR1
>> "%B64FILE%" echo YWwgc3lzdGVtIGluc3RhbGxlZCBieSB0aGlzIHRvb2xraXQgd2FzIGZvdW5kLicgLUZvcmVncm91
>> "%B64FILE%" echo bmRDb2xvciBZZWxsb3cNCiAgICBXcml0ZS1Ib3N0ICcodGhlIHh4eC5ib290LnR4dCB3cml0dGVu
>> "%B64FILE%" echo IGF0IGluc3RhbGwgdGltZSBtdXN0IHNpdCBuZXh0IHRvIHRoZSB2aXJ0dWFsIGRpc2spJw0KICAg
>> "%B64FILE%" echo IFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0ICdJZiBvbmUgd2FzIGRlZmluaXRlbHkgaW5z
>> "%B64FILE%" echo dGFsbGVkLCB1c2UgUmVwYWlyLUJvb3QtTWVudS5iYXQgdG8gcmVidWlsZCBhIGJvb3QgZW50cnku
>> "%B64FILE%" echo Jw0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0ICdQcmVzcyBhbnkga2V5IHRvIGV4
>> "%B64FILE%" echo aXQuLi4nDQogICAgJG51bGwgPSAkSG9zdC5VSS5SYXdVSS5SZWFkS2V5KCdOb0VjaG8sSW5jbHVk
>> "%B64FILE%" echo ZUtleURvd24nKQ0KICAgIHJldHVybg0KfQ0KDQpXcml0ZS1Ib3N0ICgiRm91bmQgezB9OiIgLWYg
>> "%B64FILE%" echo JGl0ZW1zLkNvdW50KQ0KZm9yZWFjaCAoJHggaW4gJGl0ZW1zKSB7IFdyaXRlLUhvc3QgKCIgICAg
>> "%B64FILE%" echo ezB9IiAtZiAkeC5QYXRoKSB9DQoNCiMgLS0tLS0tLS0tLSBDaGVjayBlYWNoIG9uZSAtLS0tLS0t
>> "%B64FILE%" echo LS0tDQokZml4ZWRDb3VudCA9IDANCiRva0NvdW50ID0gMA0KJGZhaWxDb3VudCA9IDANCg0KZm9y
>> "%B64FILE%" echo ZWFjaCAoJGl0IGluICRpdGVtcykgew0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICgiwrcgezB9IiAtZiAkaXQuUGF0aCkgLUZvcmVncm91bmRDb2xvciBDeWFuDQoNCiAgICAkd2Fu
>> "%B64FILE%" echo dERldiA9ICcnDQogICAgdHJ5IHsgJHdhbnREZXYgPSBHZXQtVmhkQmNkRGV2aWNlICRpdC5QYXRo
>> "%B64FILE%" echo IH0NCiAgICBjYXRjaCB7IFdyaXRlLUxvZyAiSW52YWxpZCBwYXRoOiAkKCRfLkV4Y2VwdGlvbi5N
>> "%B64FILE%" echo ZXNzYWdlKSIgJ0VSUic7ICRmYWlsQ291bnQrKzsgY29udGludWUgfQ0KICAgICR3YW50RnVsbCA9
>> "%B64FILE%" echo IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZ1bGxQYXRoKCRpdC5QYXRoKQ0KDQogICAgJGVuID0gSW52
>> "%B64FILE%" echo b2tlLUJjZCAtQmNkQXJncyBAKCcvZW51bScsICRpdC5HdWlkKSAtVGFnICdlbnVtJw0KICAgICRn
>> "%B64FILE%" echo dWlkID0gJGl0Lkd1aWQNCg0KICAgICMgRW50cnkgbWlzc2luZyAtPiBjcmVhdGUgb25lDQogICAg
>> "%B64FILE%" echo aWYgKC1ub3QgJGVuLk9rKSB7DQogICAgICAgIFdyaXRlLUxvZyAiVGhlIG1lbnUgaGFzIG5vIHN1
>> "%B64FILE%" echo Y2ggZW50cnkgKCRndWlkKSwgY3JlYXRpbmcgb25lIiAnV0FSTicNCiAgICAgICAgJGRlc2MgPSAk
>> "%B64FILE%" echo aXQuRGVzYw0KICAgICAgICBpZiAoLW5vdCAkZGVzYykgeyAkZGVzYyA9ICRpdC5OYW1lIH0NCiAg
>> "%B64FILE%" echo ICAgICAgaWYgKC1ub3QgJGRlc2MpIHsgJGRlc2MgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGaWxl
>> "%B64FILE%" echo TmFtZVdpdGhvdXRFeHRlbnNpb24oJGl0LlBhdGgpIH0NCg0KICAgICAgICAkY3AgPSBJbnZva2Ut
>> "%B64FILE%" echo QmNkIC1CY2RBcmdzIEAoJy9jb3B5JywgJ3tjdXJyZW50fScsICcvZCcsICRkZXNjKSAtVGFnICdj
>> "%B64FILE%" echo b3B5Jw0KICAgICAgICBpZiAoLW5vdCAkY3AuT2spIHsgJGNwID0gSW52b2tlLUJjZCAtQmNkQXJn
>> "%B64FILE%" echo cyBAKCcvY29weScsICd7ZGVmYXVsdH0nLCAnL2QnLCAkZGVzYykgLVRhZyAnY29weS1kZWZhdWx0
>> "%B64FILE%" echo JyB9DQogICAgICAgICRnbSA9IFtyZWdleF06Ok1hdGNoKCRjcC5SYXcsICdce1swLTlhLWZBLUZd
>> "%B64FILE%" echo ezh9LVswLTlhLWZBLUZdezR9LVswLTlhLWZBLUZdezR9LVswLTlhLWZBLUZdezR9LVswLTlhLWZB
>> "%B64FILE%" echo LUZdezEyfVx9JykNCiAgICAgICAgaWYgKC1ub3QgJGdtLlN1Y2Nlc3MpIHsNCiAgICAgICAgICAg
>> "%B64FILE%" echo IFdyaXRlLUxvZyAiRmFpbGVkIHRvIGNyZWF0ZSB0aGUgZW50cnk6ICQoJGNwLlRleHQpIiAnRVJS
>> "%B64FILE%" echo Jw0KICAgICAgICAgICAgJGZhaWxDb3VudCsrDQogICAgICAgICAgICBjb250aW51ZQ0KICAgICAg
>> "%B64FILE%" echo ICB9DQogICAgICAgICRndWlkID0gJGdtLlZhbHVlDQogICAgICAgIFt2b2lkXShJbnZva2UtQmNk
>> "%B64FILE%" echo IC1CY2RBcmdzIEAoJy9zZXQnLCAkZ3VpZCwgJ2RldmljZScsICAgJHdhbnREZXYpIC1UYWcgJ3Nl
>> "%B64FILE%" echo dC1kZXZpY2UnKQ0KICAgICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0Jywg
>> "%B64FILE%" echo JGd1aWQsICdvc2RldmljZScsICR3YW50RGV2KSAtVGFnICdzZXQtb3NkZXZpY2UnKQ0KICAgICAg
>> "%B64FILE%" echo ICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0JywgJGd1aWQsICdwYXRoJywgJ1xX
>> "%B64FILE%" echo aW5kb3dzXHN5c3RlbTMyXHdpbmxvYWQuZWZpJykgLVRhZyAnc2V0LXBhdGgnKQ0KDQogICAgICAg
>> "%B64FILE%" echo ICMgUmVwbGFjZSB0aGUgR1VJRCBpbiB0aGUgc3RhdGUgZmlsZSB3aXRoIHRoZSBuZXcgb25lLCBv
>> "%B64FILE%" echo dGhlcndpc2UgdGhlIHVuaW5zdGFsbGVyIGNhbm5vdCBmaW5kIGl0DQogICAgICAgIHRyeSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAkdHh0ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJGl0LlN0YXRl
>> "%B64FILE%" echo LCBbU3lzdGVtLlRleHQuRW5jb2RpbmddOjpVVEY4KQ0KICAgICAgICAgICAgJHR4dCA9IFtyZWdl
>> "%B64FILE%" echo eF06OlJlcGxhY2UoJHR4dCwgJyg/bSleR3VpZD0uKicsICJHdWlkPSRndWlkIikNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkaXQuU3RhdGUsICR0eHQsIChOZXct
>> "%B64FILE%" echo T2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkdHJ1ZSkpKQ0KICAgICAgICAgICAgV3Jp
>> "%B64FILE%" echo dGUtTG9nICJTdGF0ZSBmaWxlIHVwZGF0ZWQgd2l0aCB0aGUgbmV3IEdVSUQiICdPSycNCiAgICAg
>> "%B64FILE%" echo ICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAiRmFpbGVkIHRvIHdyaXRlIHRoZSBzdGF0ZSBmaWxlIChi
>> "%B64FILE%" echo b290aW5nIGlzIHVuYWZmZWN0ZWQpOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgJ1dBUk4nIH0N
>> "%B64FILE%" echo Cg0KICAgICAgICAkZW4gPSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9lbnVtJywgJGd1aWQpIC1U
>> "%B64FILE%" echo YWcgJ3ZlcmlmeScNCiAgICAgICAgJGZpeGVkQ291bnQrKw0KICAgIH0NCg0KICAgICMgQ2hlY2sg
>> "%B64FILE%" echo dGhlIHBhdGggZGV2aWNlIHBvaW50cyBhdA0KICAgICMgRG8gbm90IGRlcGVuZCBvbiB0aGUgZmll
>> "%B64FILE%" echo bGQgbGFiZWwgKCJkZXZpY2UiIC8gIkdlcsOkdCIgLyAi44OH44OQ44Kk44K5Iik6IHRoZSBvbmx5
>> "%B64FILE%" echo IGxpbmUgY2FycnlpbmcgInZoZD1bIiBpcyB0aGUgZGV2aWNlIGxpbmUNCiAgICAkZG0gPSBbcmVn
>> "%B64FILE%" echo ZXhdOjpNYXRjaCgkZW4uUmF3LCAnKD9pbSleW15cclxuXSo/KHZoZD1cW1teXHJcbl0rKScpDQog
>> "%B64FILE%" echo ICAgJGN1ckRldiA9ICcnDQogICAgaWYgKCRkbS5TdWNjZXNzKSB7ICRjdXJEZXYgPSAkZG0uR3Jv
>> "%B64FILE%" echo dXBzWzFdLlZhbHVlLlRyaW0oKSB9DQogICAgJGN1ckZ1bGwgPSBHZXQtRnVsbFBhdGhGcm9tQmNk
>> "%B64FILE%" echo RGV2aWNlICRjdXJEZXYNCg0KICAgIGlmIChUZXN0LUJjZFRleHRTYW1lICR3YW50RnVsbCAkY3Vy
>> "%B64FILE%" echo RnVsbCkgew0KICAgICAgICBXcml0ZS1Mb2cgIlRhcmdldCBjb3JyZWN0OiAkY3VyRGV2IiAnT0sn
>> "%B64FILE%" echo DQogICAgICAgICRva0NvdW50KysNCiAgICB9IGVsc2Ugew0KICAgICAgICBXcml0ZS1Mb2cgKCJX
>> "%B64FILE%" echo cm9uZyB0YXJnZXQuIEN1cnJlbnQgW3swfV0sIGV4cGVjdGVkIFt7MX1dIiAtZiAkY3VyRGV2LCAk
>> "%B64FILE%" echo d2FudERldikgJ1dBUk4nDQogICAgICAgIFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9z
>> "%B64FILE%" echo ZXQnLCAkZ3VpZCwgJ2RldmljZScsICAgJHdhbnREZXYpIC1UYWcgJ2ZpeC1kZXZpY2UnKQ0KICAg
>> "%B64FILE%" echo ICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0JywgJGd1aWQsICdvc2Rldmlj
>> "%B64FILE%" echo ZScsICR3YW50RGV2KSAtVGFnICdmaXgtb3NkZXZpY2UnKQ0KICAgICAgICAkY2hrID0gSW52b2tl
>> "%B64FILE%" echo LUJjZCAtQmNkQXJncyBAKCcvZW51bScsICRndWlkKSAtVGFnICdyZWNoZWNrJw0KICAgICAgICAk
>> "%B64FILE%" echo ZG0yID0gW3JlZ2V4XTo6TWF0Y2goJGNoay5SYXcsICcoP2ltKV5bXlxyXG5dKj8odmhkPVxbW15c
>> "%B64FILE%" echo clxuXSspJykNCiAgICAgICAgJG5vd0RldiA9ICcnDQogICAgICAgIGlmICgkZG0yLlN1Y2Nlc3Mp
>> "%B64FILE%" echo IHsgJG5vd0RldiA9ICRkbTIuR3JvdXBzWzFdLlZhbHVlLlRyaW0oKSB9DQogICAgICAgICRub3dG
>> "%B64FILE%" echo dWxsID0gR2V0LUZ1bGxQYXRoRnJvbUJjZERldmljZSAkbm93RGV2DQogICAgICAgIGlmIChUZXN0
>> "%B64FILE%" echo LUJjZFRleHRTYW1lICR3YW50RnVsbCAkbm93RnVsbCkgew0KICAgICAgICAgICAgV3JpdGUtTG9n
>> "%B64FILE%" echo ICJDb3JyZWN0ZWQ6ICRub3dEZXYiICdPSycNCiAgICAgICAgICAgICRmaXhlZENvdW50KysNCiAg
>> "%B64FILE%" echo ICAgICAgfSBlbHNlIHsNCiAgICAgICAgICAgIFdyaXRlLUxvZyAoIlN0aWxsIHdyb25nIGFmdGVy
>> "%B64FILE%" echo IHRoZSBjaGFuZ2UsIG5vdyBbezB9XSIgLWYgJG5vd0RldikgJ0VSUicNCiAgICAgICAgICAgIFdy
>> "%B64FILE%" echo aXRlLUxvZyAnSWYgdGhhdCBzaG93cyAiPyIgd2hlcmUgdGhlIHBhdGggaGFzIG5vbi1BU0NJSSBj
>> "%B64FILE%" echo aGFyYWN0ZXJzLCBpdCBpcyBvbmx5IHRoZSBjb25zb2xlIGNvZGUgcGFnZTogcnVuICBjaGNwIDkz
>> "%B64FILE%" echo NiAgYW5kICBiY2RlZGl0IC9lbnVtICB0byBzZWUgdGhlIHJlYWwgdGV4dC4nICdFUlInDQogICAg
>> "%B64FILE%" echo ICAgICAgICBXcml0ZS1Mb2cgJ0lmIGl0IHJlYWxseSBwb2ludHMgZWxzZXdoZXJlLCBtb3Zpbmcg
>> "%B64FILE%" echo dGhlIHZpcnR1YWwgZGlzayB0byBhIHBsYWluIEFTQ0lJIGZvbGRlciAoc3VjaCBhcyBEOlxWSEQp
>> "%B64FILE%" echo IGFuZCByZWluc3RhbGxpbmcgaXMgdGhlIHJlbGlhYmxlIGZpeC4nICdFUlInDQogICAgICAgICAg
>> "%B64FILE%" echo ICAkZmFpbENvdW50KysNCiAgICAgICAgICAgIGNvbnRpbnVlDQogICAgICAgIH0NCiAgICB9DQoN
>> "%B64FILE%" echo CiAgICAjIE1ha2Ugc3VyZSBpdCBpcyBpbiB0aGUgYm9vdCBtZW51IGRpc3BsYXlvcmRlcg0KICAg
>> "%B64FILE%" echo ICRibSA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2VudW0nLCAne2Jvb3RtZ3J9JykgLVRhZyAn
>> "%B64FILE%" echo Ym9vdG1ncicNCiAgICAkb20gPSBbcmVnZXhdOjpNYXRjaCgkYm0uUmF3LCAnKD9pbSleXHMqKD86
>> "%B64FILE%" echo ZGlzcGxheW9yZGVyfOaYvuekuumhuuW6jylccysoLis/KVxzKiQnKQ0KICAgICRvcmRlciA9ICcn
>> "%B64FILE%" echo DQogICAgaWYgKCRvbS5TdWNjZXNzKSB7ICRvcmRlciA9ICRvbS5Hcm91cHNbMV0uVmFsdWUgfQ0K
>> "%B64FILE%" echo DQogICAgaWYgKCRvcmRlciAtbm90bWF0Y2ggW3JlZ2V4XTo6RXNjYXBlKCRndWlkKSkgew0KICAg
>> "%B64FILE%" echo ICAgICAkYWQgPSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9kaXNwbGF5b3JkZXInLCAkZ3VpZCwg
>> "%B64FILE%" echo Jy9hZGRsYXN0JykgLVRhZyAnZGlzcGxheW9yZGVyJw0KICAgICAgICBpZiAoJGFkLk9rKSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICBXcml0ZS1Mb2cgJ0FkZGVkIGJhY2sgdG8gdGhlIGJvb3QgbWVudSAobGFzdCBw
>> "%B64FILE%" echo b3NpdGlvbiknICdPSycNCiAgICAgICAgICAgICRmaXhlZENvdW50KysNCiAgICAgICAgfSBlbHNl
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgIFdyaXRlLUxvZyAiRmFpbGVkIHRvIGFkZCBpdCBiYWNrIHRvIGRpc3Bs
>> "%B64FILE%" echo YXlvcmRlcjogJCgkYWQuVGV4dCkiICdFUlInDQogICAgICAgICAgICAkZmFpbENvdW50KysNCiAg
>> "%B64FILE%" echo ICAgICAgfQ0KICAgICAgICAkYm0gPSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9lbnVtJywgJ3ti
>> "%B64FILE%" echo b290bWdyfScpIC1UYWcgJ2Jvb3RtZ3IyJw0KICAgICAgICAkb20gPSBbcmVnZXhdOjpNYXRjaCgk
>> "%B64FILE%" echo Ym0uUmF3LCAnKD9pbSleXHMqKD86ZGlzcGxheW9yZGVyfOaYvuekuumhuuW6jylccysoLis/KVxz
>> "%B64FILE%" echo KiQnKQ0KICAgICAgICBpZiAoJG9tLlN1Y2Nlc3MpIHsgJG9yZGVyID0gJG9tLkdyb3Vwc1sxXS5W
>> "%B64FILE%" echo YWx1ZSB9DQogICAgfSBlbHNlIHsNCiAgICAgICAgV3JpdGUtTG9nICdJdCBpcyBpbiBkaXNwbGF5
>> "%B64FILE%" echo b3JkZXInICdPSycNCiAgICB9DQoNCiAgICAjIFRoZSBtZW51IG11c3QgYmUgZW5hYmxlZCwgb3Ro
>> "%B64FILE%" echo ZXJ3aXNlIHRoZSBkZWZhdWx0IHN5c3RlbSBib290cyBkaXJlY3RseSBhbmQgdGhlc2Ugb3B0aW9u
>> "%B64FILE%" echo cyBhcmUgbmV2ZXIgc2hvd24NCiAgICAkZW50cnlDb3VudCA9IChbcmVnZXhdOjpNYXRjaGVzKCRv
>> "%B64FILE%" echo cmRlciwgJ1x7JykpLkNvdW50DQogICAgaWYgKCRlbnRyeUNvdW50IC1nZSAyKSB7DQogICAgICAg
>> "%B64FILE%" echo ICRkYm0gPSBbcmVnZXhdOjpNYXRjaCgkYm0uUmF3LCAnKD9pbSleXHMqKD86ZGlzcGxheWJvb3Rt
>> "%B64FILE%" echo ZW51fOaYvuekuuWQr+WKqOiPnOWNlSlccysoXFMrKScpDQogICAgICAgICR0bW8gPSBbcmVnZXhd
>> "%B64FILE%" echo OjpNYXRjaCgkYm0uUmF3LCAnKD9pbSleXHMqdGltZW91dFxzKyhcZCspJykNCiAgICAgICAgJG5l
>> "%B64FILE%" echo ZWRNZW51ID0gJGZhbHNlDQogICAgICAgIGlmICgtbm90ICRkYm0uU3VjY2VzcykgeyAkbmVlZE1l
>> "%B64FILE%" echo bnUgPSAkdHJ1ZSB9DQogICAgICAgIGVsc2VpZiAoJGRibS5Hcm91cHNbMV0uVmFsdWUgLW5vdG1h
>> "%B64FILE%" echo dGNoICdeKD9pOnllcykkJykgeyAkbmVlZE1lbnUgPSAkdHJ1ZSB9DQogICAgICAgICRuZWVkVGlt
>> "%B64FILE%" echo ZW91dCA9ICgkdG1vLlN1Y2Nlc3MgLWFuZCAoW2ludF0kdG1vLkdyb3Vwc1sxXS5WYWx1ZSAtZXEg
>> "%B64FILE%" echo MCkpDQoNCiAgICAgICAgaWYgKCRuZWVkTWVudSAtb3IgJG5lZWRUaW1lb3V0KSB7DQogICAgICAg
>> "%B64FILE%" echo ICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0JywgJ3tib290bWdyfScsICdk
>> "%B64FILE%" echo aXNwbGF5Ym9vdG1lbnUnLCAnWWVzJykgLVRhZyAnbWVudS1vbicpDQogICAgICAgICAgICBpZiAo
>> "%B64FILE%" echo JG5lZWRUaW1lb3V0KSB7DQogICAgICAgICAgICAgICAgW3ZvaWRdKEludm9rZS1CY2QgLUJjZEFy
>> "%B64FILE%" echo Z3MgQCgnL3NldCcsICd7Ym9vdG1ncn0nLCAndGltZW91dCcsICcxMCcpIC1UYWcgJ3RpbWVvdXQt
>> "%B64FILE%" echo MTAnKQ0KICAgICAgICAgICAgfQ0KICAgICAgICAgICAgV3JpdGUtTG9nICdCb290IG1lbnUgZW5h
>> "%B64FILE%" echo YmxlZCAob3RoZXJ3aXNlIHRoZSBvcHRpb25zIGFyZSBuZXZlciBzaG93biknICdPSycNCiAgICAg
>> "%B64FILE%" echo ICAgICAgICRmaXhlZENvdW50KysNCiAgICAgICAgfQ0KICAgIH0NCn0NCg0KIyAtLS0tLS0tLS0t
>> "%B64FILE%" echo IFN1bW1hcnkgLS0tLS0tLS0tLQ0KV3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAnPT09PT09PT09
>> "%B64FILE%" echo PT09PT09PSBSZXN1bHQgPT09PT09PT09PT09PT09PScNCldyaXRlLUhvc3QgKCIgIGFscmVhZHkg
>> "%B64FILE%" echo Y29ycmVjdDogezB9IiAtZiAkb2tDb3VudCkNCldyaXRlLUhvc3QgKCIgIGZpeGVkICAgICAgICAg
>> "%B64FILE%" echo IDogezB9IiAtZiAkZml4ZWRDb3VudCkgLUZvcmVncm91bmRDb2xvciBHcmVlbg0KV3JpdGUtSG9z
>> "%B64FILE%" echo dCAoIiAgZmFpbGVkICAgICAgICAgOiB7MH0iIC1mICRmYWlsQ291bnQpIC1Gb3JlZ3JvdW5kQ29s
>> "%B64FILE%" echo b3IgJChpZiAoJGZhaWxDb3VudCAtZ3QgMCkgeyAnUmVkJyB9IGVsc2UgeyAnR3JheScgfSkNCldy
>> "%B64FILE%" echo aXRlLUhvc3QgJycNCmlmICgkZml4ZWRDb3VudCAtZ3QgMCkgew0KICAgIFdyaXRlLUhvc3QgJ1Jl
>> "%B64FILE%" echo Ym9vdCBhbmQgdGhlc2Ugc3lzdGVtcyBzaG91bGQgbm93IHNob3cgdXAgaW4gdGhlIGJvb3QgbWVu
>> "%B64FILE%" echo dSBhbmQgYm9vdC4nIC1Gb3JlZ3JvdW5kQ29sb3IgR3JlZW4NCn0gZWxzZWlmICgkZmFpbENvdW50
>> "%B64FILE%" echo IC1lcSAwIC1hbmQgJG9rQ291bnQgLWd0IDApIHsNCiAgICBXcml0ZS1Ib3N0ICdBbGwgbWVudSB0
>> "%B64FILE%" echo YXJnZXRzIGFyZSBjb3JyZWN0IGFuZCBub3RoaW5nIG5lZWRlZCBmaXhpbmcuIElmIHRoZSBtZW51
>> "%B64FILE%" echo IHN0aWxsIGRvZXMgbm90IGFwcGVhciwnDQogICAgV3JpdGUtSG9zdCAndGhlIGZpcm13YXJlIG1h
>> "%B64FILE%" echo eSBub3QgYm9vdCBmcm9tIHRoZSBFU1Agb24gdGhpcyBkaXNrLCBvciB0aGUgbWVudSB0aW1lb3V0
>> "%B64FILE%" echo IGlzIHRvbyBzaG9ydCAtIHRyeSBwcmVzc2luZyBhbiBhcnJvdyBrZXkuJw0KfSBlbHNlIHsNCiAg
>> "%B64FILE%" echo ICBXcml0ZS1Ib3N0ICdTb21lIGVudHJpZXMgY291bGQgbm90IGJlIGZpeGVkOyBzZW5kIG1lIHRo
>> "%B64FILE%" echo ZSBsb2cgYmVsb3cuJyAtRm9yZWdyb3VuZENvbG9yIFllbGxvdw0KfQ0KV3JpdGUtSG9zdCAnJw0K
>> "%B64FILE%" echo V3JpdGUtSG9zdCAoIkxvZzogezB9IiAtZiAkU2NyaXB0OkxvZ0ZpbGUpDQpXcml0ZS1Ib3N0ICcn
>> "%B64FILE%" echo DQpXcml0ZS1Ib3N0ICdQcmVzcyBhbnkga2V5IHRvIGV4aXQuLi4nDQokbnVsbCA9ICRIb3N0LlVJ
>> "%B64FILE%" echo LlJhd1VJLlJlYWRLZXkoJ05vRWNobyxJbmNsdWRlS2V5RG93bicpDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=15146"
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
