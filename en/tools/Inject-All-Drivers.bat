@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Inject All Drivers
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
    set "ELEV_ARGS=%*"
    if defined ELEV_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList $env:ELEV_ARGS } catch { exit 9 }"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
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
set "PS1FILE=%WORKDIR%\Inject-All-Drivers.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oDQogICAgW3N0cmluZ10kT3JpZ2luRGlyID0gJycNCikNCg0KIyA9PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMgSW5q
>> "%B64FILE%" echo ZWN0IEFsbCBEcml2ZXJzICB2MS4zDQojIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QNCiMNCiMgUHVy
>> "%B64FILE%" echo cG9zZTogdGhlIGluc3RhbGxlZCB2aXJ0dWFsIHN5c3RlbSBzaG93cyAiYSBwaWxlIG9mIHVua25v
>> "%B64FILE%" echo d24gZGV2aWNlcyIgaW4gRGV2aWNlIE1hbmFnZXIuDQojICAgVGhpcyBtb3ZlcyBldmVyeSB0aGly
>> "%B64FILE%" echo ZC1wYXJ0eSBkcml2ZXIgcGFja2FnZSBmcm9tIHRoaXMgbWFjaGluZSAoY2hpcHNldCwgQUNQSSwg
>> "%B64FILE%" echo UENJZSwgbmV0d29yaywgYXVkaW8sIEJsdWV0b290aCwgR1BVLi4uKQ0KIyAgIGludG8gdGhlIHZp
>> "%B64FILE%" echo cnR1YWwgc3lzdGVtIGluIG9uZSBnbywgc28gUG5QIHBpY2tzIHRoZW0gdXAgYWZ0ZXIgYSByZWJv
>> "%B64FILE%" echo b3QuDQojDQojIERpZmZlcmVuY2UgZnJvbSAiSW5qZWN0IE5ldHdvcmsgRHJpdmVycyI6IHRoYXQg
>> "%B64FILE%" echo b25lIG1vdmVzIG9ubHkgdGhlIDkgTmV0LWNsYXNzIHBhY2thZ2VzLCB0aGlzIG9uZSBtb3ZlcyBh
>> "%B64FILE%" echo bGwgMTYwKy4NCiMNCiMgSXQgYWxzbyBrZWVwcyBhIGNvcHkgb2YgdGhlIGV4cG9ydGVkIGRyaXZl
>> "%B64FILE%" echo cnMgaW4gTmV3U3lzdGVtRHJpdmVyIG9uIHRoZSB2aGR4IGRyaXZlLCBzbyBpZiBzb21lIGRldmlj
>> "%B64FILE%" echo ZXMgc3RheQ0KIyB1bmJvdW5kIHlvdSBjYW4gc3RpbGwgaW5zdGFsbCB0aGVtIG9uIHRoZSBzcG90
>> "%B64FILE%" echo IGluc2lkZSB0aGUgbmV3IHN5c3RlbSB3aXRoIERpYWdub3NlLUFuZC1JbnN0YWxsLURyaXZlcnMu
>> "%B64FILE%" echo YmF0Lg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT0NCg0KJEVycm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdDb250aW51ZScNCiRTY3Jp
>> "%B64FILE%" echo cHQ6VmVyc2lvbiA9ICcxLjMyJw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQp0cnkg
>> "%B64FILE%" echo eyAkSG9zdC5VSS5SYXdVSS5XaW5kb3dUaXRsZSA9ICJJbmplY3QgQWxsIERyaXZlcnMgdiQoJFNj
>> "%B64FILE%" echo cmlwdDpWZXJzaW9uKSAtIGNvbm5lY3RzZWdhYm90IiB9IGNhdGNoIHt9DQoNCiMgW3YxLjMyXSBT
>> "%B64FILE%" echo aGFyZWQgbW9kdWxlLiBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSBpbmxpbmVzIHRoaXMgZmls
>> "%B64FILE%" echo ZSBhdA0KIyBidWlsZCB0aW1lLCBhbmQgdGhlIC5iYXQgcGF5bG9hZCBpcyBzdGlsbCBhIHNlbGYt
>> "%B64FILE%" echo Y29udGFpbmVkIHNpbmdsZSBmaWxlLg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMgU2hhcmVkIGxvZ2dpbmcgaGVscGVycyAg
>> "%B64FILE%" echo IHYxLjMyDQojDQojIFRoaXMgZmlsZSBpcyBOT1Qgd2hhdCBnZXRzIHNoaXBwZWQuIHNyYy9idWls
>> "%B64FILE%" echo ZC9pbmxpbmVfc2hhcmVkLnB5IGlubGluZXMgaXRzDQojIGNvbnRlbnQgaW50byBldmVyeSBlbnRy
>> "%B64FILE%" echo eSBzY3JpcHQgd2hpbGUgdGhlIC5iYXQgcGF5bG9hZHMgYXJlIGJ1aWx0LCBzbyB0aGUNCiMgcmVs
>> "%B64FILE%" echo ZWFzZWQgbGF1bmNoZXJzIHN0YXkgc2VsZi1jb250YWluZWQgc2luZ2xlIGZpbGVzICh0aGUgc2Vs
>> "%B64FILE%" echo Zi1leHRyYWN0aW5nIGJhdA0KIyBoYXMgbm8gd2F5IHRvIHJlZmVyZW5jZSBhbiBleHRlcm5hbCBt
>> "%B64FILE%" echo b2R1bGUgYXQgcnVuIHRpbWUpLg0KIw0KIyBSdWxlOiBlZGl0IGhlcmUsIG5ldmVyIGNvcHktcGFz
>> "%B64FILE%" echo dGUgdGhlc2UgZnVuY3Rpb25zIGJhY2sgaW50byBhbiBlbnRyeSBzY3JpcHQuDQojID09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQpm
>> "%B64FILE%" echo dW5jdGlvbiBTYXkgew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtzdHJpbmddJENvbG9yID0g
>> "%B64FILE%" echo J0dyYXknKQ0KICAgIFdyaXRlLUhvc3QgJFRleHQgLUZvcmVncm91bmRDb2xvciAkQ29sb3INCn0N
>> "%B64FILE%" echo Cg0KU2F5ICIiDQpTYXkgIiAgSW5qZWN0IEFsbCBEcml2ZXJzICB2JCgkU2NyaXB0OlZlcnNpb24p
>> "%B64FILE%" echo IiAnQ3lhbicNClNheSAiICBBdXRob3I6IGNvbm5lY3RzZWdhYm90IiAnRGFya0dyYXknDQpTYXkg
>> "%B64FILE%" echo IiAgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tIiAnRGFya0dyYXknDQpTYXkgIiINCg0KJGFkbWluID0gKFtTZWN1cml0eS5QcmluY2lw
>> "%B64FILE%" echo YWwuV2luZG93c1ByaW5jaXBhbF1bU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06
>> "%B64FILE%" echo OkdldEN1cnJlbnQoKSkuSXNJblJvbGUoW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzQnVpbHRJ
>> "%B64FILE%" echo blJvbGVdOjpBZG1pbmlzdHJhdG9yKQ0KaWYgKC1ub3QgJGFkbWluKSB7DQogICAgU2F5ICIgIFtF
>> "%B64FILE%" echo UlJPUl0gQWRtaW5pc3RyYXRvciByaWdodHMgYXJlIHJlcXVpcmVkLiBDbG9zZSB0aGlzIHdpbmRv
>> "%B64FILE%" echo dywgcmlnaHQtY2xpY2sgdGhpcyBmaWxlIC0+IFJ1biBhcyBhZG1pbmlzdHJhdG9yLiIgJ1JlZCcN
>> "%B64FILE%" echo CiAgICBTYXkgIiINCiAgICBSZWFkLUhvc3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCiAgICBl
>> "%B64FILE%" echo eGl0IDENCn0NCg0KIyAtLS0tLS0tLS0tIEV4Y2x1ZGUgInRoZSBzeXN0ZW0gcnVubmluZyByaWdo
>> "%B64FILE%" echo dCBub3ciIC0tLS0tLS0tLS0NCiRzeXNMZXR0ZXIgPSAoW3N0cmluZ10kZW52OlN5c3RlbURyaXZl
>> "%B64FILE%" echo KS5UcmltRW5kKCc6JykuVG9VcHBlcigpDQokc3lzVm9sSWQgPSAnJw0KdHJ5IHsgJHN5c1ZvbElk
>> "%B64FILE%" echo ID0gW3N0cmluZ10oR2V0LVZvbHVtZSAtRHJpdmVMZXR0ZXIgJHN5c0xldHRlciAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU3RvcCkuVW5pcXVlSWQgfSBjYXRjaCB7fQ0KDQpmdW5jdGlvbiBUZXN0LUlzUnVubmluZ1N5
>> "%B64FILE%" echo c3RlbSB7DQogICAgcGFyYW0oJFZvbCkNCiAgICBpZiAoKFtzdHJpbmddJFZvbC5Ecml2ZUxldHRl
>> "%B64FILE%" echo cikuVG9VcHBlcigpIC1lcSAkc3lzTGV0dGVyKSB7IHJldHVybiAkdHJ1ZSB9DQogICAgaWYgKCRz
>> "%B64FILE%" echo eXNWb2xJZCAtYW5kIChbc3RyaW5nXSRWb2wuVW5pcXVlSWQgLWVxICRzeXNWb2xJZCkpIHsgcmV0
>> "%B64FILE%" echo dXJuICR0cnVlIH0NCiAgICByZXR1cm4gJGZhbHNlDQp9DQoNCmZ1bmN0aW9uIEdldC1UYXJnZXRD
>> "%B64FILE%" echo YW5kaWRhdGVzIHsNCiAgICAkbGlzdCA9IEAoKQ0KICAgICR2aGREaXNrcyA9IEB7fQ0KICAgIGZv
>> "%B64FILE%" echo cmVhY2ggKCRkIGluIEAoR2V0LURpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7
>> "%B64FILE%" echo DQogICAgICAgIGlmIChbc3RyaW5nXSRkLkJ1c1R5cGUgLWVxICdGaWxlIEJhY2tlZCBWaXJ0dWFs
>> "%B64FILE%" echo JykgeyAkdmhkRGlza3NbW2ludF0kZC5OdW1iZXJdID0gJHRydWUgfQ0KICAgIH0NCiAgICBmb3Jl
>> "%B64FILE%" echo YWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7
>> "%B64FILE%" echo DQogICAgICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7IGNvbnRpbnVlIH0NCiAgICAgICAg
>> "%B64FILE%" echo JHJvb3QgPSAiezB9OlwiIC1mICR2LkRyaXZlTGV0dGVyDQogICAgICAgIGlmICgtbm90IChUZXN0
>> "%B64FILE%" echo LVBhdGggLUxpdGVyYWxQYXRoICgkcm9vdCArICdXaW5kb3dzXFN5c3RlbTMyXG50b3Nrcm5sLmV4
>> "%B64FILE%" echo ZScpKSkgeyBjb250aW51ZSB9DQogICAgICAgICRkaXNrTnVtID0gLTENCiAgICAgICAgdHJ5IHsg
>> "%B64FILE%" echo JGRpc2tOdW0gPSBbaW50XShHZXQtUGFydGl0aW9uIC1Ecml2ZUxldHRlciAkdi5Ecml2ZUxldHRl
>> "%B64FILE%" echo ciAtRXJyb3JBY3Rpb24gU3RvcCkuRGlza051bWJlciB9IGNhdGNoIHt9DQogICAgICAgICRsaXN0
>> "%B64FILE%" echo ICs9IFtwc2N1c3RvbW9iamVjdF1Aew0KICAgICAgICAgICAgTGV0dGVyICA9IFtzdHJpbmddJHYu
>> "%B64FILE%" echo RHJpdmVMZXR0ZXINCiAgICAgICAgICAgIExhYmVsICAgPSBbc3RyaW5nXSR2LkZpbGVTeXN0ZW1M
>> "%B64FILE%" echo YWJlbA0KICAgICAgICAgICAgUnVubmluZyA9IChUZXN0LUlzUnVubmluZ1N5c3RlbSAkdikNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIElzVmhkICAgPSAoJGRpc2tOdW0gLWdlIDAgLWFuZCAkdmhkRGlza3MuQ29udGFp
>> "%B64FILE%" echo bnNLZXkoJGRpc2tOdW0pKQ0KICAgICAgICAgICAgRGlzayAgICA9ICRkaXNrTnVtDQogICAgICAg
>> "%B64FILE%" echo ICAgICBTaXplR0IgID0gW21hdGhdOjpSb3VuZCgkdi5TaXplIC8gMUdCLCAxKQ0KICAgICAgICAg
>> "%B64FILE%" echo ICAgRnJlZUdCICA9IFttYXRoXTo6Um91bmQoJHYuU2l6ZVJlbWFpbmluZyAvIDFHQiwgMSkNCiAg
>> "%B64FILE%" echo ICAgICAgfQ0KICAgIH0NCiAgICByZXR1cm4gJGxpc3QNCn0NCg0KZnVuY3Rpb24gRmluZC1WaGR4
>> "%B64FILE%" echo RmlsZXMgew0KICAgICRmb3VuZCA9IEAoKQ0KICAgIGlmICgkU2NyaXB0Ok9yaWdpbkRpciAtYW5k
>> "%B64FILE%" echo IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRTY3JpcHQ6T3JpZ2luRGlyKSkgew0KICAgICAgICAk
>> "%B64FILE%" echo YyA9IEpvaW4tUGF0aCAkU2NyaXB0Ok9yaWdpbkRpciAnTmV3U3lzdGVtRGlzay52aGR4Jw0KICAg
>> "%B64FILE%" echo ICAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkYykgeyAkZm91bmQgKz0gJGMgfQ0KICAg
>> "%B64FILE%" echo IH0NCiAgICBmb3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9uIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpKSB7DQogICAgICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7IGNvbnRpbnVl
>> "%B64FILE%" echo IH0NCiAgICAgICAgaWYgKCR2LkRyaXZlVHlwZSAtbmUgJ0ZpeGVkJykgeyBjb250aW51ZSB9DQog
>> "%B64FILE%" echo ICAgICAgICRjID0gInswfTpcTmV3U3lzdGVtRGlzay52aGR4IiAtZiAkdi5Ecml2ZUxldHRlcg0K
>> "%B64FILE%" echo ICAgICAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkYykgew0KICAgICAgICAgICAgJGZ1
>> "%B64FILE%" echo bGwgPSAoR2V0LUl0ZW0gLUxpdGVyYWxQYXRoICRjKS5GdWxsTmFtZQ0KICAgICAgICAgICAgaWYg
>> "%B64FILE%" echo KCRmb3VuZCAtbm90Y29udGFpbnMgJGZ1bGwpIHsgJGZvdW5kICs9ICRmdWxsIH0NCiAgICAgICAg
>> "%B64FILE%" echo fQ0KICAgIH0NCiAgICByZXR1cm4gJGZvdW5kDQp9DQoNCmZ1bmN0aW9uIE1vdW50LVZoZHggew0K
>> "%B64FILE%" echo ICAgIHBhcmFtKFtzdHJpbmddJFBhdGgpDQogICAgJGRwRmlsZSA9IEpvaW4tUGF0aCAkZW52OlRF
>> "%B64FILE%" echo TVAgKCJhdHRhY2hfYWxsX3swfS50eHQiIC1mICRQSUQpDQogICAgQCgic2VsZWN0IHZkaXNrIGZp
>> "%B64FILE%" echo bGU9YCIkUGF0aGAiIiwgJ2F0dGFjaCB2ZGlzaycsICdleGl0JykgfCBTZXQtQ29udGVudCAtTGl0
>> "%B64FILE%" echo ZXJhbFBhdGggJGRwRmlsZSAtRW5jb2RpbmcgRGVmYXVsdA0KICAgICRyID0gJycNCiAgICB0cnkg
>> "%B64FILE%" echo eyAkciA9ICgmIGRpc2twYXJ0IC9zICRkcEZpbGUgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2gg
>> "%B64FILE%" echo eyAkciA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlIH0NCiAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBh
>> "%B64FILE%" echo dGggJGRwRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUNCiAgICBpZiAo
>> "%B64FILE%" echo JHIgLW1hdGNoICdzdWNjZXNzZnVsbHl85oiQ5YqfJykgeyByZXR1cm4gJHRydWUgfQ0KICAgIFNh
>> "%B64FILE%" echo eSAoIiAgICAgIG1vdW50IHJldHVybmVkOiAiICsgKCgkciAtcmVwbGFjZSAiXHMrIiwgJyAnKS5U
>> "%B64FILE%" echo cmltKCkpKSAnWWVsbG93Jw0KICAgIHJldHVybiAkZmFsc2UNCn0NCg0KZnVuY3Rpb24gRGlzbW91
>> "%B64FILE%" echo bnQtVmhkeCB7DQogICAgcGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkZHBGaWxlID0gSm9pbi1Q
>> "%B64FILE%" echo YXRoICRlbnY6VEVNUCAoImRldGFjaF9hbGxfezB9LnR4dCIgLWYgJFBJRCkNCiAgICBAKCJzZWxl
>> "%B64FILE%" echo Y3QgdmRpc2sgZmlsZT1gIiRQYXRoYCIiLCAnZGV0YWNoIHZkaXNrJywgJ2V4aXQnKSB8IFNldC1D
>> "%B64FILE%" echo b250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0DQogICAgdHJ5IHsg
>> "%B64FILE%" echo JiBkaXNrcGFydCAvcyAkZHBGaWxlIDI+JjEgfCBPdXQtTnVsbCB9IGNhdGNoIHt9DQogICAgUmVt
>> "%B64FILE%" echo b3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRs
>> "%B64FILE%" echo eUNvbnRpbnVlDQp9DQoNCiMgLS0tLS0tLS0tLSBbMS80XSBGaW5kIHRoZSB0YXJnZXQgLS0tLS0t
>> "%B64FILE%" echo LS0tLQ0KU2F5ICJbMS80XSBGaW5kaW5nIHRoZSB0YXJnZXQgc3lzdGVtIC4uLiIgJ1doaXRlJw0K
>> "%B64FILE%" echo DQokYXR0YWNoZWRWaGR4ID0gJycNCiR0YXJnZXRzID0gQChHZXQtVGFyZ2V0Q2FuZGlkYXRlcykN
>> "%B64FILE%" echo CiR1c2FibGUgPSBAKCR0YXJnZXRzIHwgV2hlcmUtT2JqZWN0IHsgLW5vdCAkXy5SdW5uaW5nIH0p
>> "%B64FILE%" echo DQokdmhkVGFyZ2V0cyA9IEAoJHVzYWJsZSB8IFdoZXJlLU9iamVjdCB7ICRfLklzVmhkIH0pDQoN
>> "%B64FILE%" echo CmlmICgkdmhkVGFyZ2V0cy5Db3VudCAtZXEgMCkgew0KICAgIGZvcmVhY2ggKCRmIGluIEAoRmlu
>> "%B64FILE%" echo ZC1WaGR4RmlsZXMpKSB7DQogICAgICAgIFNheSAoIiAgICAgIGZvdW5kIHZpcnR1YWwgZGlzayB7
>> "%B64FILE%" echo MH0sIG1vdW50aW5nIC4uLiIgLWYgJGYpICdEYXJrR3JheScNCiAgICAgICAgaWYgKE1vdW50LVZo
>> "%B64FILE%" echo ZHggLVBhdGggJGYpIHsNCiAgICAgICAgICAgICRhdHRhY2hlZFZoZHggPSAkZg0KICAgICAgICAg
>> "%B64FILE%" echo ICAgU2F5ICIgICAgICBtb3VudGVkIiAnR3JlZW4nDQogICAgICAgICAgICBicmVhaw0KICAgICAg
>> "%B64FILE%" echo ICB9DQogICAgfQ0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7DQogICAgICAgIFN0YXJ0LVNsZWVw
>> "%B64FILE%" echo IC1TZWNvbmRzIDINCiAgICAgICAgJHRhcmdldHMgPSBAKEdldC1UYXJnZXRDYW5kaWRhdGVzKQ0K
>> "%B64FILE%" echo ICAgICAgICAkdXNhYmxlID0gQCgkdGFyZ2V0cyB8IFdoZXJlLU9iamVjdCB7IC1ub3QgJF8uUnVu
>> "%B64FILE%" echo bmluZyB9KQ0KICAgICAgICAkdmhkVGFyZ2V0cyA9IEAoJHVzYWJsZSB8IFdoZXJlLU9iamVjdCB7
>> "%B64FILE%" echo ICRfLklzVmhkIH0pDQogICAgfQ0KfQ0KDQppZiAoJHZoZFRhcmdldHMuQ291bnQgLWVxIDEpIHsN
>> "%B64FILE%" echo CiAgICAkdGFyZ2V0ID0gJHZoZFRhcmdldHNbMF0NCn0gZWxzZWlmICgkdXNhYmxlLkNvdW50IC1l
>> "%B64FILE%" echo cSAwKSB7DQogICAgU2F5ICIiDQogICAgU2F5ICIgIFtFUlJPUl0gTm8gaW5qZWN0YWJsZSB2aXJ0
>> "%B64FILE%" echo dWFsIHN5c3RlbSBmb3VuZC4iICdSZWQnDQogICAgU2F5ICgiICAgICAgICAgezB9OiBpcyB0aGUg
>> "%B64FILE%" echo cnVubmluZyBzeXN0ZW0gYW5kIGNhbm5vdCBiZSB0aGUgdGFyZ2V0IChESVNNIHJlcG9ydHMgRXJy
>> "%B64FILE%" echo b3IgODcpLiIgLWYgJHN5c0xldHRlcikgJ1llbGxvdycNCiAgICBTYXkgIiAgICAgICAgIEFuZCBu
>> "%B64FILE%" echo byBOZXdTeXN0ZW1EaXNrLnZoZHggd2FzIGZvdW5kLiIgJ1llbGxvdycNCiAgICBTYXkgIiINCiAg
>> "%B64FILE%" echo ICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRhY2hlZFZoZHgg
>> "%B64FILE%" echo fQ0KICAgIFJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0KICAgIGV4aXQgMQ0KfSBl
>> "%B64FILE%" echo bHNlIHsNCiAgICBTYXkgIiAgICAgIFNldmVyYWwgaW5qZWN0YWJsZSBzeXN0ZW1zIGZvdW5kOiIg
>> "%B64FILE%" echo J1doaXRlJw0KICAgIGZvciAoJGkgPSAwOyAkaSAtbHQgJHVzYWJsZS5Db3VudDsgJGkrKykgew0K
>> "%B64FILE%" echo ICAgICAgICAkdCA9ICR1c2FibGVbJGldDQogICAgICAgICRraW5kID0gaWYgKCR0LklzVmhkKSB7
>> "%B64FILE%" echo ICd2aXJ0dWFsIGRpc2snIH0gZWxzZSB7ICdwaHlzaWNhbCBwYXJ0aXRpb24nIH0NCiAgICAgICAg
>> "%B64FILE%" echo U2F5ICgiICAgICAgW3swfV0gezF9OiAgezJ9ICB7M30gR0IgbGFiZWw9ezR9IiAtZiAoJGkgKyAx
>> "%B64FILE%" echo KSwgJHQuTGV0dGVyLCAka2luZCwgJHQuU2l6ZUdCLCAkdC5MYWJlbCkNCiAgICB9DQogICAgJHNl
>> "%B64FILE%" echo bCA9IFJlYWQtSG9zdCAiICAgICAgRW50ZXIgYSBudW1iZXIgKGRlZmF1bHQgMSkiDQogICAgJGlk
>> "%B64FILE%" echo eCA9IDENCiAgICBbaW50XTo6VHJ5UGFyc2UoJHNlbCwgW3JlZl0kaWR4KSB8IE91dC1OdWxsDQog
>> "%B64FILE%" echo ICAgaWYgKCRpZHggLWx0IDEgLW9yICRpZHggLWd0ICR1c2FibGUuQ291bnQpIHsgJGlkeCA9IDEg
>> "%B64FILE%" echo fQ0KICAgICR0YXJnZXQgPSAkdXNhYmxlWyRpZHggLSAxXQ0KfQ0KDQppZiAoJHRhcmdldC5SdW5u
>> "%B64FILE%" echo aW5nKSB7DQogICAgU2F5ICIgIFtFUlJPUl0gVGhlIHNlbGVjdGVkIHZvbHVtZSBpcyB0aGUgcnVu
>> "%B64FILE%" echo bmluZyBzeXN0ZW0uIEFib3J0ZWQuIiAnUmVkJw0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERp
>> "%B64FILE%" echo c21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhkeCB9DQogICAgUmVhZC1Ib3N0ICIgIFByZXNz
>> "%B64FILE%" echo IEVudGVyIHRvIGV4aXQiDQogICAgZXhpdCAxDQp9DQpTYXkgKCIgICAgICB0YXJnZXQ6IHswfTog
>> "%B64FILE%" echo IHsxfSBHQiBmcmVlIiAtZiAkdGFyZ2V0LkxldHRlciwgJHRhcmdldC5GcmVlR0IpICdHcmVlbicN
>> "%B64FILE%" echo Cg0KIyAtLS0tLS0tLS0tIFsyLzRdIEV4cG9ydCBhbGwgdGhpcmQtcGFydHkgZHJpdmVycyBmcm9t
>> "%B64FILE%" echo IHRoaXMgbWFjaGluZSAtLS0tLS0tLS0tDQpTYXkgIlsyLzRdIEV4cG9ydGluZyBhbGwgdGhpcmQt
>> "%B64FILE%" echo cGFydHkgZHJpdmVycyBmcm9tIHRoaXMgbWFjaGluZSAuLi4iICdXaGl0ZScNCiRkcnZEaXIgPSBK
>> "%B64FILE%" echo b2luLVBhdGggJGVudjpURU1QICgiYWxsZHJ2X3swfSIgLWYgJFBJRCkNCnRyeSB7IGlmIChUZXN0
>> "%B64FILE%" echo LVBhdGggLUxpdGVyYWxQYXRoICRkcnZEaXIpIHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRk
>> "%B64FILE%" echo cnZEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQ0K
>> "%B64FILE%" echo TmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkZHJ2RGlyIC1Gb3JjZSB8IE91dC1O
>> "%B64FILE%" echo dWxsDQoNCiRlbnVtVGV4dCA9ICcnDQp0cnkgeyAkZW51bVRleHQgPSAoJiBwbnB1dGlsIC9lbnVt
>> "%B64FILE%" echo LWRyaXZlcnMgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2gge30NCiRvZW1zID0gTmV3LU9iamVj
>> "%B64FILE%" echo dCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQpmb3JlYWNoICgkYmxrIGluICgkZW51bVRl
>> "%B64FILE%" echo eHQgLXNwbGl0ICIoPzpccj9cbil7Mix9IikpIHsNCiAgICAkbSA9IFtyZWdleF06Ok1hdGNoKCRi
>> "%B64FILE%" echo bGssICcoP2kpXGIob2VtXGQrXC5pbmYpXGInKQ0KICAgIGlmICgtbm90ICRtLlN1Y2Nlc3MpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICRubSA9ICRtLkdyb3Vwc1sxXS5WYWx1ZS5Ub0xvd2VyKCkNCiAgICBp
>> "%B64FILE%" echo ZiAoLW5vdCAkb2Vtcy5Db250YWlucygkbm0pKSB7IFt2b2lkXSRvZW1zLkFkZCgkbm0pIH0NCn0N
>> "%B64FILE%" echo ClNheSAoIiAgICAgIHRoaXJkLXBhcnR5IGRyaXZlciBwYWNrYWdlczogezB9IiAtZiAkb2Vtcy5D
>> "%B64FILE%" echo b3VudCkgJ0RhcmtHcmF5Jw0KDQokb2tFeHBvcnQgPSAwDQpmb3JlYWNoICgkb2VtIGluICRvZW1z
>> "%B64FILE%" echo KSB7DQogICAgJGVyID0gKCYgcG5wdXRpbCAvZXhwb3J0LWRyaXZlciAkb2VtICRkcnZEaXIgMj4m
>> "%B64FILE%" echo MSB8IE91dC1TdHJpbmcpDQogICAgaWYgKCRlciAtbWF0Y2ggJ3N1Y2Nlc3NmdWxseXzmiJDlip8n
>> "%B64FILE%" echo KSB7ICRva0V4cG9ydCsrIH0NCn0NCg0KIyBbdjEuMl0gcG5wdXRpbCAvZW51bS1kcml2ZXJzIGxp
>> "%B64FILE%" echo c3RzIG9ubHkgdGhpcmQtcGFydHkgb2VtKi5pbmYgZmlsZXMsIHdoaWxlIHBoeXNpY2FsIGFkYXB0
>> "%B64FILE%" echo ZXJzIHVzdWFsbHkgdXNlIGluLWJveA0KIyBwYWNrYWdlcyAtIG5vdCBpbiB0aGUgb2VtIGxpc3Qs
>> "%B64FILE%" echo IHNvIG5vdGhpbmcgd2FzIGV4cG9ydGVkLCBhbmQgYSB0cmltbWVkIGltYWdlIG9yIGEgZnJlc2gg
>> "%B64FILE%" echo U2VydmVyIHN5c3RlbSBsYWNrcyBleGFjdGx5IHRoYXQgcGFja2FnZS4NCiMgU28gdGhlIElORiB1
>> "%B64FILE%" echo c2VkIGJ5ICJ0aGUgcGh5c2ljYWwgYWRhcHRlcnMgdGhhdCByZWFsbHkgZXhpc3QiIGlzIGV4cG9y
>> "%B64FILE%" echo dGVkIHRvbzogdGhpcmQtcGFydHkgb2VtIG9uZXMgYXJlIGFscmVhZHkgZG9uZSAoc2tpcHBlZCk7
>> "%B64FILE%" echo DQojIGluLWJveCBvbmVzIGFyZSBjb3BpZWQgd2hvbGUgZnJvbSBEcml2ZXJTdG9yZVxGaWxlUmVw
>> "%B64FILE%" echo b3NpdG9yeSAtIGJvdGggZm9yIGluamVjdGlvbiBhbmQgZm9yIHRoZSBOZXdTeXN0ZW1Ecml2ZXIg
>> "%B64FILE%" echo YmFja3VwLg0KdHJ5IHsNCiAgICAkcGh5c05ldHMgPSBAKEdldC1QbnBEZXZpY2UgLUNsYXNzIE5l
>> "%B64FILE%" echo dCAtUHJlc2VudE9ubHkgLUVBIFNpbGVudGx5Q29udGludWUgfA0KICAgICAgICBXaGVyZS1PYmpl
>> "%B64FILE%" echo Y3QgeyAkXy5JbnN0YW5jZUlkIC1tYXRjaCAnXihQQ0l8VVNCKScgfSkNCiAgICBmb3JlYWNoICgk
>> "%B64FILE%" echo ZGV2IGluICRwaHlzTmV0cykgew0KICAgICAgICB0cnkgew0KICAgICAgICAgICAgJGRydkluZiA9
>> "%B64FILE%" echo ICcnDQogICAgICAgICAgICB0cnkgeyAkZHJ2SW5mID0gW3N0cmluZ10oR2V0LVBucERldmljZVBy
>> "%B64FILE%" echo b3BlcnR5IC1JbnN0YW5jZUlkICRkZXYuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZp
>> "%B64FILE%" echo Y2VfRHJpdmVySW5mUGF0aCcgLUVBIFN0b3ApLkRhdGEgfSBjYXRjaCB7fQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo aWYgKC1ub3QgJGRydkluZikgeyBjb250aW51ZSB9DQogICAgICAgICAgICAkZHJ2SW5mID0gJGRy
>> "%B64FILE%" echo dkluZi5Ub0xvd2VyKCkNCiAgICAgICAgICAgIFNheSAoIiAgICAgIHBoeXNpY2FsIGFkYXB0ZXIg
>> "%B64FILE%" echo ezB9IGlzIHVzaW5nIHsxfSIgLWYgJGRldi5GcmllbmRseU5hbWUsICRkcnZJbmYpICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICAgICAgICAgIGlmICgkZHJ2SW5mIC1tYXRjaCAnXm9lbVxkK1wuaW5mJCcpIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICAgICAgICAgIyBUaGUgRmlsZVJlcG9zaXRvcnkgcGFja2FnZSBmb2xkZXIg
>> "%B64FILE%" echo aXMgbmFtZWQgPGluZiBmaWxlIG5hbWU+XzxhcmNoaXRlY3R1cmU+XzxoYXNoPiwgZm9yIGV4YW1w
>> "%B64FILE%" echo bGUNCiAgICAgICAgICAgICMgcnQ2NDB4NjQuaW5mX2FtZDY0X2NiZjRlMjM5ODFjM2M4YTMuIEl0
>> "%B64FILE%" echo IG11c3QgYmUgbWF0Y2hlZCB3aXRoIHRoZSBmdWxsIGZpbGUgbmFtZSBpbmNsdWRpbmcgLmluZjsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICMgYW4gZWFybGllciB2ZXJzaW9uIHVzZWQgdGhlIG5hbWUgd2l0aG91dCB0
>> "%B64FILE%" echo aGUgZXh0ZW5zaW9uIChydDY0MHg2NF8qKSwgd2hpY2ggbmV2ZXIgbWF0Y2hlcywgc28gbm90IGEg
>> "%B64FILE%" echo c2luZ2xlDQogICAgICAgICAgICAjIGluLWJveCBkcml2ZXIgd2FzIGNvcGllZCAtIHRoZSBzeW1w
>> "%B64FILE%" echo dG9tIGJlaW5nICJpbmplY3RlZCwgYnV0IHRoZSBhZGFwdGVyIHN0aWxsIGhhcyBubyBkcml2ZXIi
>> "%B64FILE%" echo Lg0KICAgICAgICAgICAgJGZyUm9vdCA9ICIkZW52OlN5c3RlbVJvb3RcU3lzdGVtMzJcRHJpdmVy
>> "%B64FILE%" echo U3RvcmVcRmlsZVJlcG9zaXRvcnkiDQogICAgICAgICAgICAkcGtnRGlycyA9IEAoR2V0LUNoaWxk
>> "%B64FILE%" echo SXRlbSAkZnJSb290IC1EaXJlY3RvcnkgLUZpbHRlciAoJGRydkluZiArICdfKicpIC1FQSBTaWxl
>> "%B64FILE%" echo bnRseUNvbnRpbnVlKQ0KICAgICAgICAgICAgaWYgKCRwa2dEaXJzLkNvdW50IC1lcSAwKSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgJHBrZ0RpcnMgPSBAKEdldC1DaGlsZEl0ZW0gJGZyUm9vdCAtRGlyZWN0
>> "%B64FILE%" echo b3J5IC1FQSBTaWxlbnRseUNvbnRpbnVlIHwNCiAgICAgICAgICAgICAgICAgICAgV2hlcmUtT2Jq
>> "%B64FILE%" echo ZWN0IHsgJF8uTmFtZS5Ub0xvd2VyKCkuU3RhcnRzV2l0aCgkZHJ2SW5mICsgJ18nKSB9KQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgfQ0KICAgICAgICAgICAgaWYgKCRwa2dEaXJzLkNvdW50IC1lcSAwKSB7DQogICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgU2F5ICgiICBObyBkcml2ZXIgcGFja2FnZSBmb2xkZXIgZm91bmQgZm9yIHsw
>> "%B64FILE%" echo fSAodGhlIGRyaXZlciBuYW1lIG1heSBkaWZmZXIgZnJvbSB0aGUgZm9sZGVyIG5hbWUpIiAtZiAk
>> "%B64FILE%" echo ZHJ2SW5mKSAnWWVsbG93Jw0KICAgICAgICAgICAgfQ0KICAgICAgICAgICAgZm9yZWFjaCAoJHBk
>> "%B64FILE%" echo IGluICRwa2dEaXJzKSB7DQogICAgICAgICAgICAgICAgQ29weS1JdGVtIC1MaXRlcmFsUGF0aCAk
>> "%B64FILE%" echo cGQuRnVsbE5hbWUgLURlc3RpbmF0aW9uICRkcnZEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxl
>> "%B64FILE%" echo bnRseUNvbnRpbnVlDQogICAgICAgICAgICAgICAgU2F5ICgiICBDb3BpZWQgdGhlIGluLWJveCBu
>> "%B64FILE%" echo ZXR3b3JrIGRyaXZlciBwYWNrYWdlOiAiICsgJHBkLk5hbWUpICdEYXJrR3JheScNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIH0NCiAgICAgICAgfSBjYXRjaCB7IFNheSAoIiAgICAgIGluLWJveCBuZXR3b3JrIGRyaXZl
>> "%B64FILE%" echo ciBleHBvcnQgZmFpbGVkOiAiICsgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpICdZZWxsb3cnIH0NCiAg
>> "%B64FILE%" echo ICB9DQp9IGNhdGNoIHsgU2F5ICgiICAgICAgaW4tYm94IG5ldHdvcmsgZHJpdmVyIGV4cG9ydCB0
>> "%B64FILE%" echo aHJldzogIiArICRfLkV4Y2VwdGlvbi5NZXNzYWdlKSAnWWVsbG93JyB9DQoNCiRpbmZGaWxlcyA9
>> "%B64FILE%" echo IEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJGRydkRpciAtUmVjdXJzZSAtRmlsdGVyICou
>> "%B64FILE%" echo aW5mIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQ0KJGRydk1CID0gMA0KdHJ5IHsgJGRy
>> "%B64FILE%" echo dk1CID0gW21hdGhdOjpSb3VuZCgoKEdldC1DaGlsZEl0ZW0gJGRydkRpciAtUmVjdXJzZSAtRmls
>> "%B64FILE%" echo ZSB8IE1lYXN1cmUtT2JqZWN0IExlbmd0aCAtU3VtKS5TdW0pIC8gMU1CLCAxKSB9IGNhdGNoIHt9
>> "%B64FILE%" echo DQpTYXkgKCIgICAgICBleHBvcnQgY29tcGxldGU6IHswfSBwYWNrYWdlcyAvIHsxfSBJTkYgZmls
>> "%B64FILE%" echo ZXMgLyB7Mn0gTUIiIC1mICRva0V4cG9ydCwgJGluZkZpbGVzLkNvdW50LCAkZHJ2TUIpICdHcmVl
>> "%B64FILE%" echo bicNCmlmICgkaW5mRmlsZXMuQ291bnQgLWVxIDApIHsNCiAgICBTYXkgIiAgW0VSUk9SXSBOb3Qg
>> "%B64FILE%" echo YSBzaW5nbGUgSU5GIHdhcyBleHBvcnRlZCwgY2Fubm90IGNvbnRpbnVlLiIgJ1JlZCcNCiAgICB0
>> "%B64FILE%" echo cnkgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRydkRpciAtUmVjdXJzZSAtRm9yY2UgLUVB
>> "%B64FILE%" echo IFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fQ0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERp
>> "%B64FILE%" echo c21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhkeCB9DQogICAgUmVhZC1Ib3N0ICIgIFByZXNz
>> "%B64FILE%" echo IEVudGVyIHRvIGV4aXQiDQogICAgZXhpdCAxDQp9DQoNCiMgLS0tLS0tLS0tLSBFeGNsdWRlIGlu
>> "%B64FILE%" echo ZGlyZWN0IGRpc3BsYXkgKElERCkgZHJpdmVycyAtLS0tLS0tLS0tDQojIFtXaHkgZXhjbHVkZSB0
>> "%B64FILE%" echo aGVtXSBSZW1vdGUgc3RyZWFtaW5nIC8gZW11bGF0b3IgLyBzY3JlZW4gbWlycm9yaW5nIHNvZnR3
>> "%B64FILE%" echo YXJlIGluc3RhbGxzIGFuICJJbmRpcmVjdCBEaXNwbGF5IERyaXZlciIgKElERCkNCiMgdGhhdCBy
>> "%B64FILE%" echo ZWdpc3RlcnMgYSBkZXZpY2UgYXMgUk9PVFxESVNQTEFZXE5OTk4gLSBpbnN0YW50aWF0ZWQgYnkg
>> "%B64FILE%" echo dGhlIHNvZnR3YXJlIGl0c2VsZiwgd2l0aCBubyByZWFsIEdQVSBoYXJkd2FyZS4NCiMgT25jZSBz
>> "%B64FILE%" echo dWNoIGFuIElORiBpcyBpbmplY3RlZCwgUG5QIG9uIHRoZSBuZXcgc3lzdGVtJ3MgZmlyc3QgYm9v
>> "%B64FILE%" echo dCBjcmVhdGVzIGEgZGV2aWNlIGZyb20gdGhlIFJvb3QgZW51bWVyYXRlZCBJRCwNCiMgYW5kIHRo
>> "%B64FILE%" echo ZSBQZXJmb3JtYW5jZSB0YWIgb2YgVGFzayBNYW5hZ2VyIGdhaW5zIGEgR1BVIHdpdGggZW1wdHkg
>> "%B64FILE%" echo VlJBTSAvIDNEIC8gVmlkZW8gY291bnRlcnMuDQojIFRoZSB1c2VyIHNlZXMgImFuIGVtcHR5IEdQ
>> "%B64FILE%" echo VSBhcHBlYXJlZCBhZnRlciBpbnN0YWxsaW5nIiwgYW5kIGRlbGV0aW5nIGdob3N0IEdQVXMgaGFz
>> "%B64FILE%" echo IG5vIGVmZmVjdCBvbiBpdC4NCiMgSXQgZXhpc3RzIG9uIHRoaXMgbWFjaGluZSBidXQgdGhlIHRh
>> "%B64FILE%" echo cmdldCBtYXkgbm90IG5lZWQgaXQgYXQgYWxsIC0gYSBjbGVhciBjYXNlIG9mICJjb3B5aW5nIGl0
>> "%B64FILE%" echo IG92ZXIgb25seSBhZGRzIG5vaXNlIi4NCiRpZGRQYXQgPSAnKD9pKShHYW1lVmlld2VySWRkfElk
>> "%B64FILE%" echo ZERyaXZlcnxJZGRTYW1wbGVEcml2ZXJ8dXNibW1pZGR8VmlydHVhbFxzKkRpc3BsYXl8VmlydHVh
>> "%B64FILE%" echo bERpc3BsYXl8TXVNdUlkZHxzcGFjZWRlc2t8YXN0cm9wYWR8UGFyc2VjLipJZGR8T2N1bHVzLioo
>> "%B64FILE%" echo SWRkfERpc3BsYXkpKScNCiRieURpciA9IEB7fQ0KZm9yZWFjaCAoJGluZiBpbiAkaW5mRmlsZXMp
>> "%B64FILE%" echo IHsNCiAgICAkZG4gPSAkaW5mLkRpcmVjdG9yeU5hbWUNCiAgICBpZiAoLW5vdCAkYnlEaXIuQ29u
>> "%B64FILE%" echo dGFpbnNLZXkoJGRuKSkgeyAkYnlEaXJbJGRuXSA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rp
>> "%B64FILE%" echo b25zLkFycmF5TGlzdCB9DQogICAgW3ZvaWRdJGJ5RGlyWyRkbl0uQWRkKCRpbmYpDQp9DQokZXhj
>> "%B64FILE%" echo bHVkZWRQa2dzID0gQCgpDQokZXhjbHVkZWRJbmYgPSBAKCkNCmZvcmVhY2ggKCRkbiBpbiBAKCRi
>> "%B64FILE%" echo eURpci5LZXlzKSkgew0KICAgICRsaXN0ID0gJGJ5RGlyWyRkbl0NCiAgICAkYWxsTWF0Y2ggPSAk
>> "%B64FILE%" echo dHJ1ZQ0KICAgICRoaXROYW1lID0gJycNCiAgICBmb3JlYWNoICgkaW5mIGluICRsaXN0KSB7DQog
>> "%B64FILE%" echo ICAgICAgICR0eHQgPSAnJw0KICAgICAgICB0cnkgeyAkdHh0ID0gW0lPLkZpbGVdOjpSZWFkQWxs
>> "%B64FILE%" echo VGV4dCgkaW5mLkZ1bGxOYW1lLCBbVGV4dC5FbmNvZGluZ106OkRlZmF1bHQpIH0gY2F0Y2ggeyAk
>> "%B64FILE%" echo YWxsTWF0Y2ggPSAkZmFsc2U7IGJyZWFrIH0NCiAgICAgICAgaWYgKCR0eHQgLW5vdG1hdGNoICRp
>> "%B64FILE%" echo ZGRQYXQpIHsgJGFsbE1hdGNoID0gJGZhbHNlOyBicmVhayB9DQogICAgICAgIGlmICgtbm90ICRo
>> "%B64FILE%" echo aXROYW1lKSB7ICRoaXROYW1lID0gJGluZi5OYW1lIH0NCiAgICB9DQogICAgaWYgKCRhbGxNYXRj
>> "%B64FILE%" echo aCAtYW5kICRsaXN0LkNvdW50IC1ndCAwKSB7DQogICAgICAgICRleGNsdWRlZFBrZ3MgKz0gW1BT
>> "%B64FILE%" echo Q3VzdG9tT2JqZWN0XUB7IERpciA9ICRkbjsgSW5mID0gJGhpdE5hbWUgfQ0KICAgICAgICBmb3Jl
>> "%B64FILE%" echo YWNoICgkaW5mIGluICRsaXN0KSB7ICRleGNsdWRlZEluZiArPSAkaW5mLkZ1bGxOYW1lIH0NCiAg
>> "%B64FILE%" echo ICB9DQp9DQokZXhjbHVkZWRNQiA9IDANCmlmICgkZXhjbHVkZWRQa2dzLkNvdW50IC1ndCAwKSB7
>> "%B64FILE%" echo DQogICAgU2F5ICgiICAgICAgZXhjbHVkZWQgezB9IHZpcnR1YWwgZGlzcGxheSBkcml2ZXJzICh0
>> "%B64FILE%" echo aGV5IHdvdWxkIGFkZCBhbiBlbXB0eSBHUFUgdG8gdGhlIG5ldyBzeXN0ZW0pOiIgLWYgJGV4Y2x1
>> "%B64FILE%" echo ZGVkUGtncy5Db3VudCkgJ1llbGxvdycNCiAgICBmb3JlYWNoICgkZSBpbiAkZXhjbHVkZWRQa2dz
>> "%B64FILE%" echo KSB7DQogICAgICAgIFNheSAoIiAgICAgICAgLSAiICsgJGUuSW5mKSAnRGFya0dyYXknDQogICAg
>> "%B64FILE%" echo ICAgIHRyeSB7ICRleGNsdWRlZE1CICs9IFttYXRoXTo6Um91bmQoKChHZXQtQ2hpbGRJdGVtICRl
>> "%B64FILE%" echo LkRpciAtUmVjdXJzZSAtRmlsZSB8IE1lYXN1cmUtT2JqZWN0IExlbmd0aCAtU3VtKS5TdW0pIC8g
>> "%B64FILE%" echo MU1CLCAxKSB9IGNhdGNoIHt9DQogICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0
>> "%B64FILE%" echo aCAkZS5EaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30N
>> "%B64FILE%" echo CiAgICB9DQogICAgIyBSZWNvdW50IHRoZSBJTkYgZmlsZXMgdG8gaW5qZWN0DQogICAgJGluZkZp
>> "%B64FILE%" echo bGVzID0gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1GaWx0
>> "%B64FILE%" echo ZXIgKi5pbmYgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpDQogICAgdHJ5IHsgJGRydk1C
>> "%B64FILE%" echo ID0gW21hdGhdOjpSb3VuZCgoKEdldC1DaGlsZEl0ZW0gJGRydkRpciAtUmVjdXJzZSAtRmlsZSB8
>> "%B64FILE%" echo IE1lYXN1cmUtT2JqZWN0IExlbmd0aCAtU3VtKS5TdW0pIC8gMU1CLCAxKSB9IGNhdGNoIHt9DQog
>> "%B64FILE%" echo ICAgU2F5ICgiICAgICAgYWN0dWFsbHkgaW5qZWN0aW5nOiB7MH0gSU5GIGZpbGVzIC8gezF9IE1C
>> "%B64FILE%" echo ICh7Mn0gTUIgZXhjbHVkZWQpIiAtZiAkaW5mRmlsZXMuQ291bnQsICRkcnZNQiwgJGV4Y2x1ZGVk
>> "%B64FILE%" echo TUIpICdHcmVlbicNCiAgICBpZiAoJGluZkZpbGVzLkNvdW50IC1lcSAwKSB7DQogICAgICAgIFNh
>> "%B64FILE%" echo eSAiICBbRVJST1JdIE5vIGluamVjdGFibGUgZHJpdmVyIHBhY2thZ2UgbGVmdCBhZnRlciBleGNs
>> "%B64FILE%" echo dXNpb24uIiAnUmVkJw0KICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRy
>> "%B64FILE%" echo dkRpciAtUmVjdXJzZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fQ0KICAg
>> "%B64FILE%" echo ICAgICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRhY2hlZFZo
>> "%B64FILE%" echo ZHggfQ0KICAgICAgICBSZWFkLUhvc3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCiAgICAgICAg
>> "%B64FILE%" echo ZXhpdCAxDQogICAgfQ0KfSBlbHNlIHsNCiAgICBTYXkgIiAgICAgIE5vIHZpcnR1YWwgZGlzcGxh
>> "%B64FILE%" echo eSAoSUREKSBkcml2ZXIgZm91bmQiICdEYXJrR3JheScNCn0NCg0KIyBTcGFjZSBjaGVjazogdGhl
>> "%B64FILE%" echo IGRyaXZlciBzdG9yZSB0YWtlcyByb3VnaGx5IHRoZSBzYW1lIHNpemUgYWdhaW4sIGtlZXAgMS41
>> "%B64FILE%" echo eCBoZWFkcm9vbQ0KJG5lZWRHQiA9IFttYXRoXTo6Um91bmQoKCRkcnZNQiAvIDEwMjQpICogMS41
>> "%B64FILE%" echo ICsgMC41LCAxKQ0KaWYgKCR0YXJnZXQuRnJlZUdCIC1sdCAkbmVlZEdCKSB7DQogICAgU2F5ICgi
>> "%B64FILE%" echo ICBbRVJST1JdIFRoZSB0YXJnZXQgc3lzdGVtIGhhcyBvbmx5IHswfSBHQiBsZWZ0IGFuZCBpbmpl
>> "%B64FILE%" echo Y3Rpb24gbmVlZHMgYWJvdXQgezF9IEdCLiBFbmxhcmdlIG9yIGNsZWFuIGl0IGZpcnN0LiIgLWYg
>> "%B64FILE%" echo JHRhcmdldC5GcmVlR0IsICRuZWVkR0IpICdSZWQnDQogICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRkcnZEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0g
>> "%B64FILE%" echo Y2F0Y2gge30NCiAgICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRh
>> "%B64FILE%" echo dHRhY2hlZFZoZHggfQ0KICAgIFJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0KICAg
>> "%B64FILE%" echo IGV4aXQgMQ0KfQ0KU2F5ICgiICAgICAgc3BhY2UgY2hlY2sgcGFzc2VkIChuZWVkIHswfSBHQiwg
>> "%B64FILE%" echo ezF9IEdCIGZyZWUpIiAtZiAkbmVlZEdCLCAkdGFyZ2V0LkZyZWVHQikgJ0RhcmtHcmF5Jw0KDQoj
>> "%B64FILE%" echo IEtlZXAgYSBjb3B5IGZvciAiaW5zdGFsbCBvbiB0aGUgc3BvdCBpbnNpZGUgdGhlIG5ldyBzeXN0
>> "%B64FILE%" echo ZW0iOiBwdXQgaXQgaW4gTmV3U3lzdGVtRHJpdmVyIG9uIHRoZSB2aGR4IGRyaXZlDQoka2VlcERp
>> "%B64FILE%" echo ciA9ICcnDQokdmhkeFBhdGggPSAkYXR0YWNoZWRWaGR4DQppZiAoLW5vdCAkdmhkeFBhdGgpIHsN
>> "%B64FILE%" echo CiAgICBmb3JlYWNoICgkZiBpbiBAKEZpbmQtVmhkeEZpbGVzKSkgeyAkdmhkeFBhdGggPSAkZjsg
>> "%B64FILE%" echo YnJlYWsgfQ0KfQ0KaWYgKCR2aGR4UGF0aCkgew0KICAgIHRyeSB7DQogICAgICAgICRrZWVwRGly
>> "%B64FILE%" echo ID0gSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQgJHZoZHhQYXRoKSAnTmV3U3lzdGVtRHJp
>> "%B64FILE%" echo dmVyJw0KICAgICAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAka2VlcERpcikgeyBSZW1v
>> "%B64FILE%" echo dmUtSXRlbSAtTGl0ZXJhbFBhdGggJGtlZXBEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRs
>> "%B64FILE%" echo eUNvbnRpbnVlIH0NCiAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAk
>> "%B64FILE%" echo a2VlcERpciAtRm9yY2UgfCBPdXQtTnVsbA0KICAgICAgICBTYXkgKCIgICAgICBhbHNvIHNhdmlu
>> "%B64FILE%" echo ZyBhIGNvcHkgdG8gezB9IChpbnN0YWxsYWJsZSBpbnNpZGUgdGhlIG5ldyBzeXN0ZW0pLi4uIiAt
>> "%B64FILE%" echo ZiAka2VlcERpcikgJ0RhcmtHcmF5Jw0KICAgICAgICBDb3B5LUl0ZW0gLVBhdGggKEpvaW4tUGF0
>> "%B64FILE%" echo aCAkZHJ2RGlyICcqJykgLURlc3RpbmF0aW9uICRrZWVwRGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEg
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZQ0KICAgICAgICBTYXkgIiAgICAgIGNvcHkgc2F2ZWQiICdHcmVlbicN
>> "%B64FILE%" echo CiAgICB9IGNhdGNoIHsNCiAgICAgICAgJGtlZXBEaXIgPSAnJw0KICAgICAgICBTYXkgKCIgICAg
>> "%B64FILE%" echo ICBmYWlsZWQgdG8gc2F2ZSB0aGUgY29weSAoZG9lcyBub3QgYWZmZWN0IGluamVjdGlvbik6ICIg
>> "%B64FILE%" echo KyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1llbGxvdycNCiAgICB9DQp9DQoNCiMgLS0tLS0tLS0t
>> "%B64FILE%" echo LSBbMy80XSBJbmplY3QgLS0tLS0tLS0tLQ0KU2F5ICJbMy80XSBJbmplY3RpbmcgYWxsIGRyaXZl
>> "%B64FILE%" echo cnMgKDMtMTAgbWludXRlcywgZG8gbm90IGNsb3NlIHRoaXMgd2luZG93KS4uLiIgJ1doaXRlJw0K
>> "%B64FILE%" echo JGxvZ0ZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICgiYWxsZHJ2X3swfS5sb2ciIC1mICRQSUQp
>> "%B64FILE%" echo DQokZXJyRmlsZSA9ICRsb2dGaWxlICsgJy5lcnInDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRl
>> "%B64FILE%" echo cmFsUGF0aCAkbG9nRmlsZSkgeyBSZW1vdmUtSXRlbSAkbG9nRmlsZSAtRm9yY2UgLUVBIFNpbGVu
>> "%B64FILE%" echo dGx5Q29udGludWUgfSB9IGNhdGNoIHt9DQoNCiRkaXNtQXJncyA9ICcvRW5nbGlzaCAvSW1hZ2U6
>> "%B64FILE%" echo ezB9OlwgL0FkZC1Ecml2ZXIgL0RyaXZlcjoiezF9IiAvUmVjdXJzZScgLWYgJHRhcmdldC5MZXR0
>> "%B64FILE%" echo ZXIsICRkcnZEaXINClNheSAoIiAgICAgIGRpc20gezB9IiAtZiAkZGlzbUFyZ3MpICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCg0KJHByb2MgPSBTdGFydC1Qcm9jZXNzIC1GaWxlUGF0aCAnZGlzbS5leGUnIC1Bcmd1bWVu
>> "%B64FILE%" echo dExpc3QgJGRpc21BcmdzIGANCiAgICAgICAgICAgIC1SZWRpcmVjdFN0YW5kYXJkT3V0cHV0ICRs
>> "%B64FILE%" echo b2dGaWxlIC1SZWRpcmVjdFN0YW5kYXJkRXJyb3IgJGVyckZpbGUgYA0KICAgICAgICAgICAgLU5v
>> "%B64FILE%" echo TmV3V2luZG93IC1QYXNzVGhydSAtRXJyb3JBY3Rpb24gU3RvcA0KDQokc3cgPSBbU3lzdGVtLkRp
>> "%B64FILE%" echo YWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0TmV3KCkNCiRsYXN0QmVhdCA9IDANCndoaWxlICgt
>> "%B64FILE%" echo bm90ICRwcm9jLkhhc0V4aXRlZCkgew0KICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgOTAw
>> "%B64FILE%" echo DQogICAgaWYgKCgkc3cuRWxhcHNlZE1pbGxpc2Vjb25kcyAtICRsYXN0QmVhdCkgLWdlIDUwMDAp
>> "%B64FILE%" echo IHsNCiAgICAgICAgJGxhc3RCZWF0ID0gJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMNCiAgICAgICAg
>> "%B64FILE%" echo JGRvbmUgPSAwDQogICAgICAgIHRyeSB7ICRkb25lID0gQChbcmVnZXhdOjpNYXRjaGVzKFtJTy5G
>> "%B64FILE%" echo aWxlXTo6UmVhZEFsbFRleHQoJGxvZ0ZpbGUpLCAnKD9pKUluc3RhbGxpbmcgXGQrIG9mIFxkKycp
>> "%B64FILE%" echo KS5Db3VudCB9IGNhdGNoIHt9DQogICAgICAgIFNheSAoIiAgICAgIHswfSBzZWNvbmRzIGVsYXBz
>> "%B64FILE%" echo ZWQsIHsxfSBwcm9jZXNzZWQgLi4uIiAtZiBbaW50XSRzdy5FbGFwc2VkLlRvdGFsU2Vjb25kcywg
>> "%B64FILE%" echo JGRvbmUpICdEYXJrR3JheScNCiAgICB9DQogICAgaWYgKCRzdy5FbGFwc2VkTWlsbGlzZWNvbmRz
>> "%B64FILE%" echo IC1ndCAxODAwMDAwKSB7DQogICAgICAgIHRyeSB7IFN0b3AtUHJvY2VzcyAtSWQgJHByb2MuSWQg
>> "%B64FILE%" echo LUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30NCiAgICAgICAgU2F5ICIgICAg
>> "%B64FILE%" echo ICBPdmVyIDMwIG1pbnV0ZXMsIGdpdmluZyB1cCIgJ1JlZCcNCiAgICAgICAgYnJlYWsNCiAgICB9
>> "%B64FILE%" echo DQp9DQp0cnkgeyAkcHJvYy5XYWl0Rm9yRXhpdCgpIH0gY2F0Y2gge30NCg0KIyAtLS0tLS0tLS0t
>> "%B64FILE%" echo IFs0LzRdIFJlc3VsdCAtLS0tLS0tLS0tDQpTYXkgIiINCiR0eHQgPSAnJw0KdHJ5IHsgaWYgKFRl
>> "%B64FILE%" echo c3QtUGF0aCAtTGl0ZXJhbFBhdGggJGxvZ0ZpbGUpIHsgJHR4dCA9IFtJTy5GaWxlXTo6UmVhZEFs
>> "%B64FILE%" echo bFRleHQoJGxvZ0ZpbGUsIFtUZXh0LkVuY29kaW5nXTo6RGVmYXVsdCkgfSB9IGNhdGNoIHt9DQok
>> "%B64FILE%" echo ZXJyVHh0ID0gJycNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRlcnJGaWxlKSB7
>> "%B64FILE%" echo ICRlcnJUeHQgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRlcnJGaWxlLCBbVGV4dC5FbmNvZGlu
>> "%B64FILE%" echo Z106OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0KDQokb2tMaXN0ID0gQChbcmVnZXhdOjpNYXRjaGVz
>> "%B64FILE%" echo KCR0eHQsICcoP2kpSW5zdGFsbGluZyBcZCsgb2YgXGQrIC0gKC4rPyk6XHMqKD86VGhlIGRyaXZl
>> "%B64FILE%" echo ciBwYWNrYWdlIHdhcyBzdWNjZXNzZnVsbHkgaW5zdGFsbGVkfOmpseWKqOWMhS4qP+W3suaIkOWK
>> "%B64FILE%" echo n+WuieijhSknKSB8IEZvckVhY2gtT2JqZWN0IHsgJF8uR3JvdXBzWzFdLlZhbHVlIH0pDQokZmFp
>> "%B64FILE%" echo bExpc3QgPSBAKFtyZWdleF06Ok1hdGNoZXMoJHR4dCwgJyg/aSlJbnN0YWxsaW5nIFxkKyBvZiBc
>> "%B64FILE%" echo ZCsgLSAoLis/KTpccypFcnJvcicpIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5Hcm91cHNbMV0uVmFs
>> "%B64FILE%" echo dWUgfSkNCg0KU2F5ICJbNC80XSBSZXN1bHQ6IiAnV2hpdGUnDQpTYXkgKCIgICAgICBpbmplY3Rl
>> "%B64FILE%" echo ZCBzdWNjZXNzZnVsbHk6IHswfSBkcml2ZXIgcGFja2FnZXMiIC1mICRva0xpc3QuQ291bnQpICdH
>> "%B64FILE%" echo cmVlbicNCmlmICgkZmFpbExpc3QuQ291bnQgLWd0IDApIHsNCiAgICBTYXkgKCIgICAgICBub3Qg
>> "%B64FILE%" echo YXBwbGljYWJsZSAgICAgOiB7MH0gKFdpbmRvd3MgdmVyc2lvbiBtaXNtYXRjaCwgc2VlIHRoZSBs
>> "%B64FILE%" echo b2cpIiAtZiAkZmFpbExpc3QuQ291bnQpICdZZWxsb3cnDQogICAgZm9yZWFjaCAoJGYgaW4gKCRm
>> "%B64FILE%" echo YWlsTGlzdCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEyKSkgeyBTYXkgKCIgICAgICAgIC0gIiAr
>> "%B64FILE%" echo ICRmKSAnRGFya0dyYXknIH0NCiAgICBpZiAoJGZhaWxMaXN0LkNvdW50IC1ndCAxMikgeyBTYXkg
>> "%B64FILE%" echo KCIgICAgICAgIC4uLiBhbmQgezB9IG1vcmUiIC1mICgkZmFpbExpc3QuQ291bnQgLSAxMikpICdE
>> "%B64FILE%" echo YXJrR3JheScgfQ0KfQ0KU2F5ICgiICAgICAgbG9nOiB7MH0iIC1mICRsb2dGaWxlKSAnR3JheScN
>> "%B64FILE%" echo Cg0KU2F5ICIiDQppZiAoJG9rTGlzdC5Db3VudCAtZ3QgMCkgew0KICAgIFNheSAiICBJbmplY3Rp
>> "%B64FILE%" echo b24gY29tcGxldGUuIEFmdGVyIHJlYm9vdGluZyBpbnRvIHRoZSBuZXcgc3lzdGVtIERldmljZSBN
>> "%B64FILE%" echo YW5hZ2VyIHNob3VsZCBoYXZlIGZhciBmZXdlciB1bmtub3duIGRldmljZXMuIiAnR3JlZW4nDQog
>> "%B64FILE%" echo ICAgaWYgKCRrZWVwRGlyKSB7DQogICAgICAgIFNheSAoIiAgSWYgYSBmZXcgc3RpbGwgc2hvdyBh
>> "%B64FILE%" echo biBleGNsYW1hdGlvbiBtYXJrLCBydW4gRGlhZ25vc2UtQW5kLUluc3RhbGwtRHJpdmVycyBpbnNp
>> "%B64FILE%" echo ZGUgdGhlIG5ldyBzeXN0ZW07IGl0IHVzZXMgezB9IiAtZiAka2VlcERpcikgJ0dyYXknDQogICAg
>> "%B64FILE%" echo fQ0KfSBlbHNlIHsNCiAgICBTYXkgIiAgTm90IGEgc2luZ2xlIHBhY2thZ2Ugd2FzIGluamVjdGVk
>> "%B64FILE%" echo LCBjaGVjayB0aGUgZXJyb3JzIGluIHRoZSBsb2cuIiAnUmVkJw0KICAgIGlmICgkZXJyVHh0LlRy
>> "%B64FILE%" echo aW0oKSkgeyBmb3JlYWNoICgkbCBpbiBAKCRlcnJUeHQgLXNwbGl0ICJbYHJgbl0rIiB8IFdoZXJl
>> "%B64FILE%" echo LU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgU2VsZWN0LU9iamVjdCAtTGFzdCA2KSkgeyBTYXkgKCIg
>> "%B64FILE%" echo ICAgICAiICsgJGwpICdZZWxsb3cnIH0gfQ0KfQ0KDQojIC0tLS0tLS0tLS0gV3JhcC11cCAtLS0t
>> "%B64FILE%" echo LS0tLS0tDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZHJ2RGlyKSB7IFJlbW92
>> "%B64FILE%" echo ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlD
>> "%B64FILE%" echo b250aW51ZSB9IH0gY2F0Y2gge30NCmlmICgkYXR0YWNoZWRWaGR4KSB7DQogICAgU2F5ICIiDQog
>> "%B64FILE%" echo ICAgU2F5ICgiICBEaXNtb3VudGluZyB0aGUgdGVtcG9yYXJpbHkgbW91bnRlZCB2aXJ0dWFsIGRp
>> "%B64FILE%" echo c2sgLi4uIikgJ0RhcmtHcmF5Jw0KICAgIERpc21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhk
>> "%B64FILE%" echo eA0KICAgIFNheSAiICBEaXNtb3VudGVkIiAnRGFya0dyYXknDQp9DQpTYXkgIiINClJlYWQtSG9z
>> "%B64FILE%" echo dCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=20433"
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
