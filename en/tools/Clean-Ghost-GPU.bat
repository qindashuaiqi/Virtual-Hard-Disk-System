@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Clean Ghost GPU
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
set "PS1FILE=%WORKDIR%\Clean-Ghost-GPU.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oKQ0KDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PQ0KIyBOZXcgc3lzdGVtIEdQVSBjaGVjay11cCBhbmQgY2xlYW4t
>> "%B64FILE%" echo dXAgICB2Mi4wDQojIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QNCiMNCiMgV2hlcmUgdG8gcnVuOiAq
>> "%B64FILE%" echo Kmluc2lkZSB0aGUgbmV3bHkgaW5zdGFsbGVkIHZpcnR1YWwgc3lzdGVtKiogKG5vdCB0aGUgb3Jp
>> "%B64FILE%" echo Z2luYWwgb25lKS4NCiMNCiMgV2hhdCB2MS4wIGdvdCB3cm9uZyAodXNlcnMgcmVwb3J0ZWQgInRo
>> "%B64FILE%" echo ZSBnaG9zdCBHUFUgd2FzIG5vdCByZW1vdmVkIGF0IGFsbCIpOg0KIyAgIDEuIEl0IHRyZWF0ZWQg
>> "%B64FILE%" echo dGhlICJlbXB0eSBHUFUiIGluIFRhc2sgTWFuYWdlciBhcyBhIGdob3N0IGFkYXB0ZXIuIEJ1dCB0
>> "%B64FILE%" echo aGUgVGFzayBNYW5hZ2VyIEdQVSBsaXN0IG9ubHkgZW51bWVyYXRlcw0KIyAgICAgICoqYWN0aXZl
>> "%B64FILE%" echo IGFkYXB0ZXJzKio7IGdob3N0IGRldmljZXMgKGhhcmR3YXJlIG5vIGxvbmdlciBwcmVzZW50KSBu
>> "%B64FILE%" echo ZXZlciBzaG93IHVwIHRoZXJlLg0KIyAgICAgIFdoYXQgcmVhbGx5IHRha2VzIHRoYXQgc2xvdCBp
>> "%B64FILE%" echo cyBhbiAqKklERCB2aXJ0dWFsIGRpc3BsYXkqKiBlbnVtZXJhdGVkIHVuZGVyIFJPT1RcRElTUExB
>> "%B64FILE%" echo WQ0KIyAgICAgIChpbnN0YWxsZWQgYnkgcmVtb3RlIHN0cmVhbWluZyAvIGVtdWxhdG9yIHNvZnR3
>> "%B64FILE%" echo YXJlLCBTZXJ2aWNlPVdVREZSZCwgd2l0aCBubyByZWFsIERYIGVuZ2luZSwNCiMgICAgICBzbyBW
>> "%B64FILE%" echo UkFNLCAzRCBhbmQgVmlkZW8gYXJlIGFsbCBlbXB0eSkuDQojICAgMi4gSXQgdHJ1c3RlZCBwbnB1
>> "%B64FILE%" echo dGlsJ3MgZXhpdCBjb2RlLiBwbnB1dGlsIC9yZW1vdmUtZGV2aWNlIHJldHVybnMgMHgwIGZvciBu
>> "%B64FILE%" echo b24tcHJlc2VudCBkZXZpY2VzDQojICAgICAgd2hpbGUgZGVsZXRpbmcgbm90aGluZywgc28gdGhl
>> "%B64FILE%" echo IHJlcG9ydCBjbGFpbWVkICIzIGRlbGV0ZWQiIGFsdGhvdWdoIHRoZSByZWNvcmRzIHdlcmUgc3Rp
>> "%B64FILE%" echo bGwgdGhlcmUuDQojICAgICAgdjIuMCByZS1lbnVtZXJhdGVzIGFmdGVyIGRlbGV0aW5nIGFuZCBy
>> "%B64FILE%" echo ZXBvcnRzICJnb25lIC8gc3RpbGwgcHJlc2VudCIgZXhwbGljaXRseS4NCiMgICAzLiBUaGUgZGVs
>> "%B64FILE%" echo ZXRpb24gb3JkZXIgd2FzIHJldmVyc2VkLiBSZW1vdmUtUG5wRGV2aWNlIGdvZXMgdGhyb3VnaCBE
>> "%B64FILE%" echo SUZfUkVNT1ZFIGFuZCBjYW4gaGFuZGxlIGFic2VudCBkZXZpY2VzOw0KIyAgICAgIHBucHV0aWwg
>> "%B64FILE%" echo aXMgb25seSBhIHN1cHBsZW1lbnQuIHYxLjAgdHJpZWQgcG5wdXRpbCBmaXJzdCBhbmQgc2tpcHBl
>> "%B64FILE%" echo ZCBvbiBzdWNjZXNzLCBzbyBub3RoaW5nIHdhcyBldmVyIGZpeGVkLg0KIw0KIyBSZXBvcnQgZmls
>> "%B64FILE%" echo ZTogPHNvbWUgZHJpdmU+Olw8UHJvZHVjdE5hbWU+LWxvZ3NcZ3B1LXJlcG9ydC50eHQNCiMgPT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo DQoNCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnQ29udGludWUnDQokU2NyaXB0OlZlcnNpb24g
>> "%B64FILE%" echo PSAnMS4zMicNCnRyeSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIk5ldyBTeXN0ZW0g
>> "%B64FILE%" echo R1BVIENoZWNrLXVwIHYkKCRTY3JpcHQ6VmVyc2lvbikgLSBjb25uZWN0c2VnYWJvdCIgfSBjYXRj
>> "%B64FILE%" echo aCB7fQ0KDQojIFt2MS4zMl0gU2hhcmVkIG1vZHVsZS4gc3JjL2J1aWxkL2lubGluZV9zaGFyZWQu
>> "%B64FILE%" echo cHkgaW5saW5lcyB0aGlzIGZpbGUgYXQNCiMgYnVpbGQgdGltZSwgYW5kIHRoZSAuYmF0IHBheWxv
>> "%B64FILE%" echo YWQgaXMgc3RpbGwgYSBzZWxmLWNvbnRhaW5lZCBzaW5nbGUgZmlsZS4NCiMgPT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQojIFNoYXJl
>> "%B64FILE%" echo ZCBsb2dnaW5nIGhlbHBlcnMgICB2MS4zMg0KIw0KIyBUaGlzIGZpbGUgaXMgTk9UIHdoYXQgZ2V0
>> "%B64FILE%" echo cyBzaGlwcGVkLiBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSBpbmxpbmVzIGl0cw0KIyBjb250
>> "%B64FILE%" echo ZW50IGludG8gZXZlcnkgZW50cnkgc2NyaXB0IHdoaWxlIHRoZSAuYmF0IHBheWxvYWRzIGFyZSBi
>> "%B64FILE%" echo dWlsdCwgc28gdGhlDQojIHJlbGVhc2VkIGxhdW5jaGVycyBzdGF5IHNlbGYtY29udGFpbmVkIHNp
>> "%B64FILE%" echo bmdsZSBmaWxlcyAodGhlIHNlbGYtZXh0cmFjdGluZyBiYXQNCiMgaGFzIG5vIHdheSB0byByZWZl
>> "%B64FILE%" echo cmVuY2UgYW4gZXh0ZXJuYWwgbW9kdWxlIGF0IHJ1biB0aW1lKS4NCiMNCiMgUnVsZTogZWRpdCBo
>> "%B64FILE%" echo ZXJlLCBuZXZlciBjb3B5LXBhc3RlIHRoZXNlIGZ1bmN0aW9ucyBiYWNrIGludG8gYW4gZW50cnkg
>> "%B64FILE%" echo c2NyaXB0Lg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT0NCg0KZnVuY3Rpb24gU2F5IHsNCiAgICBwYXJhbShbc3RyaW5nXSRUZXh0
>> "%B64FILE%" echo LCBbc3RyaW5nXSRDb2xvciA9ICdHcmF5JykNCiAgICBXcml0ZS1Ib3N0ICRUZXh0IC1Gb3JlZ3Jv
>> "%B64FILE%" echo dW5kQ29sb3IgJENvbG9yDQp9DQoNClNheSAiIg0KU2F5ICIgIE5ldyBTeXN0ZW0gR1BVIENoZWNr
>> "%B64FILE%" echo LXVwIGFuZCBDbGVhbi11cCAgdiQoJFNjcmlwdDpWZXJzaW9uKSIgJ0N5YW4nDQpTYXkgIiAgQXV0
>> "%B64FILE%" echo aG9yOiBjb25uZWN0c2VnYWJvdCIgJ0RhcmtHcmF5Jw0KU2F5ICIgIC0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSIgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo U2F5ICIiDQoNCiRhZG1pbiA9IChbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NQcmluY2lwYWxd
>> "%B64FILE%" echo W1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzSWRlbnRpdHldOjpHZXRDdXJyZW50KCkpLklzSW5S
>> "%B64FILE%" echo b2xlKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6QWRtaW5pc3RyYXRv
>> "%B64FILE%" echo cikNCmlmICgtbm90ICRhZG1pbikgew0KICAgIFNheSAiICBbRVJST1JdIEFkbWluaXN0cmF0b3Ig
>> "%B64FILE%" echo cmlnaHRzIGFyZSByZXF1aXJlZC4gUmlnaHQtY2xpY2sgLT4gUnVuIGFzIGFkbWluaXN0cmF0b3Iu
>> "%B64FILE%" echo IiAnUmVkJw0KICAgIFJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0KICAgIGV4aXQg
>> "%B64FILE%" echo MQ0KfQ0KDQokcmVwb3J0ID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0
>> "%B64FILE%" echo DQpmdW5jdGlvbiBBZGQtTGluZSB7IHBhcmFtKFtzdHJpbmddJFQgPSAnJykgW3ZvaWRdJHJlcG9y
>> "%B64FILE%" echo dC5BZGQoJFQpIH0NCg0KJG9zID0gR2V0LUNpbUluc3RhbmNlIFdpbjMyX09wZXJhdGluZ1N5c3Rl
>> "%B64FILE%" echo bSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0KQWRkLUxpbmUgIj09PT09PT09PT09PT09
>> "%B64FILE%" echo PSBHUFUgZGlhZ25vc3RpY3MgdiQoJFNjcmlwdDpWZXJzaW9uKSA9PT09PT09PT09PT09PT0iDQpB
>> "%B64FILE%" echo ZGQtTGluZSAoIkNvbXB1dGVyIDogIiArICRlbnY6Q09NUFVURVJOQU1FKQ0KQWRkLUxpbmUgKCJT
>> "%B64FILE%" echo eXN0ZW0gICA6ICIgKyAkb3MuQ2FwdGlvbiArICIgIEJ1aWxkICIgKyAkb3MuQnVpbGROdW1iZXIp
>> "%B64FILE%" echo DQpBZGQtTGluZSAoIlN5c3RlbSBkcml2ZSA6ICIgKyAkZW52OlN5c3RlbURyaXZlKQ0KQWRkLUxp
>> "%B64FILE%" echo bmUgIiINCg0KZnVuY3Rpb24gR2V0LVByb2JsZW1UZXh0IHsNCiAgICBwYXJhbShbaW50XSRDb2Rl
>> "%B64FILE%" echo KQ0KICAgIHN3aXRjaCAoJENvZGUpIHsNCiAgICAgICAgMCAgeyByZXR1cm4gJ09LJyB9DQogICAg
>> "%B64FILE%" echo ICAgIDMgIHsgcmV0dXJuICdkcml2ZXIgaXMgY29ycnVwdCcgfQ0KICAgICAgICAxMCB7IHJldHVy
>> "%B64FILE%" echo biAnZGV2aWNlIGNhbm5vdCBzdGFydCcgfQ0KICAgICAgICAxOCB7IHJldHVybiAnZHJpdmVyIG5l
>> "%B64FILE%" echo ZWRzIHJlaW5zdGFsbGluZycgfQ0KICAgICAgICAyMiB7IHJldHVybiAnZGlzYWJsZWQnIH0NCiAg
>> "%B64FILE%" echo ICAgICAgMjggeyByZXR1cm4gJ2RyaXZlciBub3QgaW5zdGFsbGVkJyB9DQogICAgICAgIDMxIHsg
>> "%B64FILE%" echo cmV0dXJuICdkcml2ZXIgY2Fubm90IGxvYWQnIH0NCiAgICAgICAgNDMgeyByZXR1cm4gJ3N0b3Bw
>> "%B64FILE%" echo ZWQgYWZ0ZXIgcmVwb3J0aW5nIGEgZmFpbHVyZScgfQ0KICAgICAgICA0NSB7IHJldHVybiAnZ2hv
>> "%B64FILE%" echo c3QgcmVjb3JkIChkZXZpY2Ugbm90IHByZXNlbnQpJyB9DQogICAgICAgIGRlZmF1bHQgeyByZXR1
>> "%B64FILE%" echo cm4gKCJwcm9ibGVtIGNvZGUgIiArICRDb2RlKSB9DQogICAgfQ0KfQ0KDQojIC0tLS0tLS0tLS0g
>> "%B64FILE%" echo WzEvNV0gQ29sbGVjdCAtLS0tLS0tLS0tDQpTYXkgIlsxLzVdIFJlYWRpbmcgZGlzcGxheSBhZGFw
>> "%B64FILE%" echo dGVycy4uLiIgJ1doaXRlJw0KDQojIFRha2UgdGhlIHNldCBUYXNrIE1hbmFnZXIgcmVhbGx5IGVu
>> "%B64FILE%" echo dW1lcmF0ZXMgKGFjdGl2ZSBhZGFwdGVycykNCiRhY3RpdmVOYW1lcyA9IEAoKQ0KdHJ5IHsNCiAg
>> "%B64FILE%" echo ICBmb3JlYWNoICgkdmMgaW4gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfVmlkZW9Db250cm9sbGVy
>> "%B64FILE%" echo IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJHZjLk5hbWUp
>> "%B64FILE%" echo IHsgJGFjdGl2ZU5hbWVzICs9IFtzdHJpbmddJHZjLk5hbWUgfQ0KICAgIH0NCn0gY2F0Y2gge30N
>> "%B64FILE%" echo Cg0KJGFkYXB0ZXJzID0gQCgpDQpmb3JlYWNoICgkZCBpbiBAKEdldC1QbnBEZXZpY2UgLUNsYXNz
>> "%B64FILE%" echo IERpc3BsYXkgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgaWYgKC1ub3Qg
>> "%B64FILE%" echo JGQpIHsgY29udGludWUgfQ0KDQogICAgJHByZXNlbnQgPSAkZmFsc2UNCiAgICB0cnkgew0KICAg
>> "%B64FILE%" echo ICAgICAkdiA9IChHZXQtUG5wRGV2aWNlUHJvcGVydHkgLUluc3RhbmNlSWQgJGQuSW5zdGFuY2VJ
>> "%B64FILE%" echo ZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZpY2VfSXNQcmVzZW50JyAtRXJyb3JBY3Rpb24gU3RvcCku
>> "%B64FILE%" echo RGF0YQ0KICAgICAgICBpZiAoJHYgLWVxICR0cnVlKSB7ICRwcmVzZW50ID0gJHRydWUgfQ0KICAg
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCg0KICAgICRwcm92ID0gJyc7ICR2ZXIgPSAnJzsgJGluZiA9ICcnOyAkc3Zj
>> "%B64FILE%" echo ID0gJycNCiAgICB0cnkgeyAkcHJvdiA9IFtzdHJpbmddKEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAt
>> "%B64FILE%" echo SW5zdGFuY2VJZCAkZC5JbnN0YW5jZUlkIC1LZXlOYW1lICdERVZQS0VZX0RldmljZV9Ecml2ZXJQ
>> "%B64FILE%" echo cm92aWRlcicgLUVycm9yQWN0aW9uIFN0b3ApLkRhdGEgfSBjYXRjaCB7fQ0KICAgIHRyeSB7ICR2
>> "%B64FILE%" echo ZXIgPSBbc3RyaW5nXShHZXQtUG5wRGV2aWNlUHJvcGVydHkgLUluc3RhbmNlSWQgJGQuSW5zdGFu
>> "%B64FILE%" echo Y2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZpY2VfRHJpdmVyVmVyc2lvbicgLUVycm9yQWN0aW9u
>> "%B64FILE%" echo IFN0b3ApLkRhdGEgfSBjYXRjaCB7fQ0KICAgIHRyeSB7ICRpbmYgPSBbc3RyaW5nXShHZXQtUG5w
>> "%B64FILE%" echo RGV2aWNlUHJvcGVydHkgLUluc3RhbmNlSWQgJGQuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtF
>> "%B64FILE%" echo WV9EZXZpY2VfRHJpdmVySW5mUGF0aCcgLUVycm9yQWN0aW9uIFN0b3ApLkRhdGEgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KICAgIHRyeSB7ICRzdmMgPSBbc3RyaW5nXShHZXQtUG5wRGV2aWNlUHJvcGVydHkgLUluc3Rh
>> "%B64FILE%" echo bmNlSWQgJGQuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZpY2VfU2VydmljZScgLUVy
>> "%B64FILE%" echo cm9yQWN0aW9uIFN0b3ApLkRhdGEgfSBjYXRjaCB7fQ0KDQogICAgJGh3ID0gQCgpDQogICAgdHJ5
>> "%B64FILE%" echo IHsNCiAgICAgICAgJGggPSAoR2V0LVBucERldmljZVByb3BlcnR5IC1JbnN0YW5jZUlkICRkLklu
>> "%B64FILE%" echo c3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0hhcmR3YXJlSWRzJyAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU3RvcCkuRGF0YQ0KICAgICAgICBpZiAoJGgpIHsgJGh3ID0gQCgkaCkgfQ0KICAgIH0gY2F0
>> "%B64FILE%" echo Y2gge30NCg0KICAgICRwcm9iID0gMA0KICAgIGlmICgkZC5Qcm9ibGVtIC1uZSAkbnVsbCkgeyAk
>> "%B64FILE%" echo cHJvYiA9IFtpbnRdJGQuUHJvYmxlbSB9DQoNCiAgICAjIFtrZXldIElkZW50aWZ5aW5nIGFuIElE
>> "%B64FILE%" echo RCB2aXJ0dWFsIGRpc3BsYXk6IFJPT1QgZW51bSArIERpc3BsYXkgY2xhc3MgKyB1c2VyLW1vZGUg
>> "%B64FILE%" echo ZHJpdmVyIGZyYW1ld29yay4NCiAgICAjIFRoZXNlIGRldmljZXMgYXJlIGZha2UgYWRhcHRlcnMg
>> "%B64FILE%" echo Y3JlYXRlZCBieSBzb2Z0d2FyZTsgVGFzayBNYW5hZ2VyIGdpdmVzIHRoZW0gYSBHUFUgc2xvdA0K
>> "%B64FILE%" echo ICAgICMgYnV0IHRoZXJlIGlzIG5vIGVuZ2luZSBvciBWUkFNIGRhdGEgaW5zaWRlIC0gdGhhdCBp
>> "%B64FILE%" echo cyB0aGUgImVtcHR5IEdQVSIgdXNlcnMgcmVwb3J0Lg0KICAgICRpc1Jvb3QgPSAkZC5JbnN0YW5j
>> "%B64FILE%" echo ZUlkIC1saWtlICdST09UXConDQogICAgJGlzSWRkID0gJGZhbHNlDQogICAgaWYgKCRpc1Jvb3Qp
>> "%B64FILE%" echo IHsNCiAgICAgICAgaWYgKCRzdmMgLWVxICdXVURGUmQnIC1vciAkc3ZjIC1saWtlICcqSWRkKicg
>> "%B64FILE%" echo LW9yICRkLkZyaWVuZGx5TmFtZSAtbGlrZSAnKlZpcnR1YWwqJykgeyAkaXNJZGQgPSAkdHJ1ZSB9
>> "%B64FILE%" echo DQogICAgICAgIGVsc2UgeyAkaXNJZGQgPSAkdHJ1ZSB9ICAgIyBldmVyeXRoaW5nIHVuZGVyIFJP
>> "%B64FILE%" echo T1RcRElTUExBWSBpcyBhIHNvZnR3YXJlIGFkYXB0ZXINCiAgICB9DQoNCiAgICAka2luZCA9ICcn
>> "%B64FILE%" echo DQogICAgaWYgKC1ub3QgJHByZXNlbnQpIHsgJGtpbmQgPSAnZ2hvc3QnIH0NCiAgICBlbHNlaWYg
>> "%B64FILE%" echo KCRpc0lkZCkgeyAka2luZCA9ICd2aXJ0dWFsIGRpc3BsYXknIH0NCiAgICBlbHNlaWYgKCRwcm9i
>> "%B64FILE%" echo IC1uZSAwKSB7ICRraW5kID0gJ2ZhdWx0eScgfQ0KICAgIGVsc2UgeyAka2luZCA9ICdpbiB1c2Un
>> "%B64FILE%" echo IH0NCg0KICAgICRhZGFwdGVycyArPSBbcHNjdXN0b21vYmplY3RdQHsNCiAgICAgICAgTmFtZSAg
>> "%B64FILE%" echo ICAgICA9ICRkLkZyaWVuZGx5TmFtZQ0KICAgICAgICBJbnN0YW5jZUlkID0gJGQuSW5zdGFuY2VJ
>> "%B64FILE%" echo ZA0KICAgICAgICBTdGF0dXMgICAgID0gW3N0cmluZ10kZC5TdGF0dXMNCiAgICAgICAgUHJlc2Vu
>> "%B64FILE%" echo dCAgICA9ICRwcmVzZW50DQogICAgICAgIFByb2JsZW0gICAgPSAkcHJvYg0KICAgICAgICBLaW5k
>> "%B64FILE%" echo ICAgICAgID0gJGtpbmQNCiAgICAgICAgSXNJZGQgICAgICA9ICRpc0lkZA0KICAgICAgICBQcm92
>> "%B64FILE%" echo aWRlciAgID0gJHByb3YNCiAgICAgICAgVmVyc2lvbiAgICA9ICR2ZXINCiAgICAgICAgSW5mICAg
>> "%B64FILE%" echo ICAgICA9ICRpbmYNCiAgICAgICAgU2VydmljZSAgICA9ICRzdmMNCiAgICAgICAgSHdJZHMgICAg
>> "%B64FILE%" echo ICA9ICRodw0KICAgIH0NCn0NCg0KJHJlYWxHcHUgPSBAKCRhZGFwdGVycyB8IFdoZXJlLU9iamVj
>> "%B64FILE%" echo dCB7ICRfLktpbmQgLWVxICdpbiB1c2UnIH0pDQokaWRkcyAgICA9IEAoJGFkYXB0ZXJzIHwgV2hl
>> "%B64FILE%" echo cmUtT2JqZWN0IHsgJF8uS2luZCAtZXEgJ3ZpcnR1YWwgZGlzcGxheScgfSkNCiRnaG9zdHMgID0g
>> "%B64FILE%" echo QCgkYWRhcHRlcnMgfCBXaGVyZS1PYmplY3QgeyAkXy5LaW5kIC1lcSAnZ2hvc3QnIH0pDQokZmF1
>> "%B64FILE%" echo bHRzICA9IEAoJGFkYXB0ZXJzIHwgV2hlcmUtT2JqZWN0IHsgJF8uS2luZCAtZXEgJ2ZhdWx0eScg
>> "%B64FILE%" echo fSkNCiRkaXNhYmxlZCA9IEAoJGFkYXB0ZXJzIHwgV2hlcmUtT2JqZWN0IHsgJF8uU3RhdHVzIC1l
>> "%B64FILE%" echo cSAnRXJyb3InIC1hbmQgJF8uUHJvYmxlbSAtZXEgMjIgfSkNCg0KIyAtLS0tLS0tLS0tIFsyLzVd
>> "%B64FILE%" echo IExheSBpdCBvdXQgLS0tLS0tLS0tLQ0KU2F5ICJbMi81XSBDbGFzc2lmaWNhdGlvbi4uLiINCkFk
>> "%B64FILE%" echo ZC1MaW5lICItLS0tLS0tLS0tIERpc3BsYXkgYWRhcHRlcnMgLS0tLS0tLS0tLSINCkFkZC1MaW5l
>> "%B64FILE%" echo ICgiezB9IGluIHRvdGFsOiB7MX0gcmVhbGx5IGluIHVzZSAvIHsyfSB2aXJ0dWFsIGRpc3BsYXlz
>> "%B64FILE%" echo IC8gezN9IGdob3N0cyAvIHs0fSBmYXVsdHkiIC1mIGANCiAgICAkYWRhcHRlcnMuQ291bnQsICRy
>> "%B64FILE%" echo ZWFsR3B1LkNvdW50LCAkaWRkcy5Db3VudCwgJGdob3N0cy5Db3VudCwgJGZhdWx0cy5Db3VudCkN
>> "%B64FILE%" echo CkFkZC1MaW5lICIiDQpTYXkgKCIgIHswfSBpbiB0b3RhbDogezF9IHJlYWxseSBpbiB1c2UgLyB7
>> "%B64FILE%" echo Mn0gdmlydHVhbCBkaXNwbGF5cyAvIHszfSBnaG9zdHMgLyB7NH0gZmF1bHR5IiAtZiBgDQogICAg
>> "%B64FILE%" echo JGFkYXB0ZXJzLkNvdW50LCAkcmVhbEdwdS5Db3VudCwgJGlkZHMuQ291bnQsICRnaG9zdHMuQ291
>> "%B64FILE%" echo bnQsICRmYXVsdHMuQ291bnQpICdDeWFuJw0KU2F5ICIiDQoNCmZvcmVhY2ggKCRhIGluICRhZGFw
>> "%B64FILE%" echo dGVycykgew0KICAgICRjb2wgPSAnR3JheScNCiAgICBpZiAoJGEuS2luZCAtZXEgJ2luIHVzZScp
>> "%B64FILE%" echo ICAgICAgIHsgJGNvbCA9ICdHcmVlbicgfQ0KICAgIGlmICgkYS5LaW5kIC1lcSAnZmF1bHR5Jykg
>> "%B64FILE%" echo ICAgICAgeyAkY29sID0gJ1llbGxvdycgfQ0KICAgIGlmICgkYS5LaW5kIC1lcSAndmlydHVhbCBk
>> "%B64FILE%" echo aXNwbGF5JykgeyAkY29sID0gJ01hZ2VudGEnIH0NCiAgICBpZiAoJGEuS2luZCAtZXEgJ2dob3N0
>> "%B64FILE%" echo JykgICAgICAgIHsgJGNvbCA9ICdEYXJrR3JheScgfQ0KDQogICAgU2F5ICgiICBbezB9XSB7MX0i
>> "%B64FILE%" echo IC1mICRhLktpbmQsICRhLk5hbWUpICRjb2wNCiAgICBTYXkgKCIgICAgICAgIHN0YXR1cz17MH0g
>> "%B64FILE%" echo IGRyaXZlcj17MX0gezJ9ICBJTkY9ezN9IiAtZiAoR2V0LVByb2JsZW1UZXh0ICRhLlByb2JsZW0p
>> "%B64FILE%" echo LCAkYS5Qcm92aWRlciwgJGEuVmVyc2lvbiwgJGEuSW5mKSAnRGFya0dyYXknDQogICAgU2F5ICgi
>> "%B64FILE%" echo ICAgICAgICBpbnN0YW5jZT17MH0iIC1mICRhLkluc3RhbmNlSWQpICdEYXJrR3JheScNCg0KICAg
>> "%B64FILE%" echo IEFkZC1MaW5lICgiW3swfV0gezF9IiAtZiAkYS5LaW5kLCAkYS5OYW1lKQ0KICAgIEFkZC1MaW5l
>> "%B64FILE%" echo ICgiICAgIHN0YXR1czogIiArIChHZXQtUHJvYmxlbVRleHQgJGEuUHJvYmxlbSkgKyAiICAoU3Rh
>> "%B64FILE%" echo dHVzPSIgKyAkYS5TdGF0dXMgKyAiLCBQcmVzZW50PSIgKyAkYS5QcmVzZW50ICsgIikiKQ0KICAg
>> "%B64FILE%" echo IEFkZC1MaW5lICgiICAgIGRyaXZlcjogIiArICRhLlByb3ZpZGVyICsgIiAiICsgJGEuVmVyc2lv
>> "%B64FILE%" echo biArICIgIElORj0iICsgJGEuSW5mICsgIiAgU2VydmljZT0iICsgJGEuU2VydmljZSkNCiAgICBB
>> "%B64FILE%" echo ZGQtTGluZSAoIiAgICBpbnN0YW5jZTogIiArICRhLkluc3RhbmNlSWQpDQogICAgaWYgKCRhLkh3
>> "%B64FILE%" echo SWRzLkNvdW50IC1ndCAwKSB7IEFkZC1MaW5lICgiICAgIGhhcmR3YXJlOiAiICsgKCRhLkh3SWRz
>> "%B64FILE%" echo IC1qb2luICcgOyAnKSkgfQ0KICAgIEFkZC1MaW5lICIiDQp9DQoNCiMgLS0tLS0tLS0tLSBbMy81
>> "%B64FILE%" echo XSBDb25jbHVzaW9uOiB3aGF0IHRoZSBlbXB0eSBHUFUgcmVhbGx5IGlzIC0tLS0tLS0tLS0NClNh
>> "%B64FILE%" echo eSAiWzMvNV0gSWRlbnRpZnlpbmcgdGhlIGVtcHR5IGNhcmQgaW4gVGFzayBNYW5hZ2VyLi4uIiAn
>> "%B64FILE%" echo V2hpdGUnDQpBZGQtTGluZSAiLS0tLS0tLS0tLSBXaGF0IGNhdXNlcyB0aGUgZW1wdHkgR1BVIC0t
>> "%B64FILE%" echo LS0tLS0tLS0iDQoNCmlmICgkaWRkcy5Db3VudCAtZ3QgMCkgew0KICAgIEFkZC1MaW5lICgiVGhl
>> "%B64FILE%" echo IFRhc2sgTWFuYWdlciBQZXJmb3JtYW5jZSB0YWIgb25seSBlbnVtZXJhdGVzICoqYWN0aXZlKiog
>> "%B64FILE%" echo ZGlzcGxheSBhZGFwdGVyczsgZ2hvc3QgZGV2aWNlcyBnZXQgbm8gc2xvdC4iKQ0KICAgIEFkZC1M
>> "%B64FILE%" echo aW5lICgiU28gdGhlIGVtcHR5IEdQVSB3aXRob3V0IGRhdGEgaXMgYWN0dWFsbHkgb25lIG9mIHRo
>> "%B64FILE%" echo ZXNlIHZpcnR1YWwgZGlzcGxheXMgKElERCk6IikNCiAgICBmb3JlYWNoICgkaSBpbiAkaWRkcykg
>> "%B64FILE%" echo ew0KICAgICAgICBBZGQtTGluZSAoIiAgICAiICsgJGkuTmFtZSArICIgICBpbnN0YW5jZT0iICsg
>> "%B64FILE%" echo JGkuSW5zdGFuY2VJZCArICIgICBJTkY9IiArICRpLkluZikNCiAgICB9DQogICAgQWRkLUxpbmUg
>> "%B64FILE%" echo IiINCiAgICBBZGQtTGluZSAiVGhleSBhcmUgaW5zdGFsbGVkIGJ5IHJlbW90ZSBzdHJlYW1pbmcg
>> "%B64FILE%" echo LyBlbXVsYXRvciBzb2Z0d2FyZSwgaGF2ZSBubyByZWFsIERYIGVuZ2luZSwgYW5kIHRoZWlyIFZS
>> "%B64FILE%" echo QU0gYW5kIDNEIHVzYWdlIHN0YXkgZW1wdHkuIg0KICAgIFNheSAoIiAgZW1wdHkgR1BVID0gdmly
>> "%B64FILE%" echo dHVhbCBkaXNwbGF5ICh7MH0pLCBub3QgYSBnaG9zdCBhZGFwdGVyIiAtZiAkaWRkcy5Db3VudCkg
>> "%B64FILE%" echo J1llbGxvdycNCn0NCmlmICgkZ2hvc3RzLkNvdW50IC1ndCAwKSB7DQogICAgQWRkLUxpbmUgKCJU
>> "%B64FILE%" echo aGVyZSBhcmUgYWxzbyB7MH0gZ2hvc3QgZGlzcGxheSBhZGFwdGVycyAoaGlzdG9yeSBsZWZ0IGJ5
>> "%B64FILE%" echo IGNsb25pbmcgYW4gaW1hZ2UpOiIgLWYgJGdob3N0cy5Db3VudCkNCiAgICBmb3JlYWNoICgkZyBp
>> "%B64FILE%" echo biAkZ2hvc3RzKSB7IEFkZC1MaW5lICgiICAgICIgKyAkZy5OYW1lICsgIiAgICIgKyAkZy5JbnN0
>> "%B64FILE%" echo YW5jZUlkKSB9DQogICAgQWRkLUxpbmUgIkdob3N0IGRldmljZXMgbmV2ZXIgc2hvdyB1cCBpbiBU
>> "%B64FILE%" echo YXNrIE1hbmFnZXIsIG9ubHkgdW5kZXIgU2hvdyBoaWRkZW4gZGV2aWNlcywgYW5kIGFyZSBoYXJt
>> "%B64FILE%" echo bGVzcyBsZWZ0b3ZlcnMuIg0KICAgIFNheSAoIiAgcGx1cyB7MH0gZ2hvc3QgcmVjb3JkcyAoaGFy
>> "%B64FILE%" echo bWxlc3MsIHRoZXkgb25seSBjbHV0dGVyIERldmljZSBNYW5hZ2VyKSIgLWYgJGdob3N0cy5Db3Vu
>> "%B64FILE%" echo dCkgJ0RhcmtHcmF5Jw0KfQ0KaWYgKCRmYXVsdHMuQ291bnQgLWd0IDApIHsNCiAgICBmb3JlYWNo
>> "%B64FILE%" echo ICgkZiBpbiAkZmF1bHRzKSB7IEFkZC1MaW5lICgiRmF1bHR5IGFkYXB0ZXI6ICIgKyAkZi5OYW1l
>> "%B64FILE%" echo ICsgIiB8ICIgKyAoR2V0LVByb2JsZW1UZXh0ICRmLlByb2JsZW0pICsgIiB8ICIgKyAkZi5JbnN0
>> "%B64FILE%" echo YW5jZUlkKSB9DQogICAgU2F5ICgiICB7MH0gYWRhcHRlcnMgYXJlIGluIGEgZmF1bHR5IHN0YXRl
>> "%B64FILE%" echo ICh1c3VhbGx5IGEgbWlzc2luZyB2ZW5kb3IgZHJpdmVyKSIgLWYgJGZhdWx0cy5Db3VudCkgJ1ll
>> "%B64FILE%" echo bGxvdycNCn0NCmlmICgkZGlzYWJsZWQuQ291bnQgLWd0IDApIHsNCiAgICBmb3JlYWNoICgkeCBp
>> "%B64FILE%" echo biAkZGlzYWJsZWQpIHsgQWRkLUxpbmUgKCJEaXNhYmxlZCBhZGFwdGVyOiAiICsgJHguTmFtZSAr
>> "%B64FILE%" echo ICIgfCAiICsgJHguSW5zdGFuY2VJZCkgfQ0KfQ0KQWRkLUxpbmUgIiINCg0KIyAtLS0tLS0tLS0t
>> "%B64FILE%" echo IFs0LzVdIEFjdGlvbnMgLS0tLS0tLS0tLQ0KQWRkLUxpbmUgIi0tLS0tLS0tLS0gSGFuZGxpbmcg
>> "%B64FILE%" echo LS0tLS0tLS0tLSINCiRkaWRTb21ldGhpbmcgPSAkZmFsc2UNCiRzdGlsbEdob3N0ID0gMA0KJHN0
>> "%B64FILE%" echo aWxsSWRkT24gPSAwDQoNCiMgNGEuIFZpcnR1YWwgZGlzcGxheXMgLSB0aGlzIGlzIHRoZSBhY3R1
>> "%B64FILE%" echo YWwgZml4IGZvciB0aGUgZW1wdHkgR1BVDQppZiAoJGlkZHMuQ291bnQgLWd0IDApIHsNCiAgICBT
>> "%B64FILE%" echo YXkgIls0LzVdIFJlbW92aW5nIHRoZSBlbXB0eSBHUFUuLi4iICdXaGl0ZScNCiAgICBTYXkgIiAg
>> "%B64FILE%" echo ICAgIERpc2FibGluZyB0aGUgdmlydHVhbCBkaXNwbGF5IG1ha2VzIHRoZSBlbXB0eSBjYXJkIGRp
>> "%B64FILE%" echo c2FwcGVhciBmcm9tIFRhc2sgTWFuYWdlcjsiICdEYXJrR3JheScNCiAgICBTYXkgIiAgICAgIHJl
>> "%B64FILE%" echo LWVuYWJsZSBpdCB3aGVuIHlvdSBuZWVkIHN0cmVhbWluZy9lbXVsYXRvciBzb2Z0d2FyZSwgaXQg
>> "%B64FILE%" echo aXMgZnVsbHkgcmV2ZXJzaWJsZS4iICdEYXJrR3JheScNCiAgICBTYXkgIiINCiAgICBmb3JlYWNo
>> "%B64FILE%" echo ICgkaSBpbiAkaWRkcykgeyBTYXkgKCIgICAgICAtICIgKyAkaS5OYW1lKSAnTWFnZW50YScgfQ0K
>> "%B64FILE%" echo ICAgIFNheSAiIg0KICAgICRhbnMgPSBSZWFkLUhvc3QgIiAgRGlzYWJsZSB0aGVzZSB2aXJ0dWFs
>> "%B64FILE%" echo IGRpc3BsYXlzPyBUeXBlIFkgYW5kIHByZXNzIEVudGVyIHRvIHByb2NlZWQsIGFueSBvdGhlciBr
>> "%B64FILE%" echo ZXkgdG8gc2tpcCINCiAgICBpZiAoJGFucyAtbWF0Y2ggJ15bWXldJykgew0KICAgICAgICBmb3Jl
>> "%B64FILE%" echo YWNoICgkaSBpbiAkaWRkcykgew0KICAgICAgICAgICAgJG9rID0gJGZhbHNlDQogICAgICAgICAg
>> "%B64FILE%" echo ICAkbXNnID0gJycNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgRGlzYWJsZS1Q
>> "%B64FILE%" echo bnBEZXZpY2UgLUluc3RhbmNlSWQgJGkuSW5zdGFuY2VJZCAtQ29uZmlybTokZmFsc2UgLUVycm9y
>> "%B64FILE%" echo QWN0aW9uIFN0b3ANCiAgICAgICAgICAgICAgICAkb2sgPSAkdHJ1ZQ0KICAgICAgICAgICAgfSBj
>> "%B64FILE%" echo YXRjaCB7DQogICAgICAgICAgICAgICAgJG1zZyA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlDQogICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgJG8gPSAoJiBwbnB1dGlsIC9kaXNhYmxlLWRldmljZSAkaS5JbnN0YW5jZUlk
>> "%B64FILE%" echo IDI+JjEgfCBPdXQtU3RyaW5nKQ0KICAgICAgICAgICAgICAgIGlmICgkTEFTVEVYSVRDT0RFIC1l
>> "%B64FILE%" echo cSAwKSB7ICRvayA9ICR0cnVlOyAkbXNnID0gJycgfQ0KICAgICAgICAgICAgICAgIGVsc2VpZiAo
>> "%B64FILE%" echo LW5vdCAkbXNnKSB7ICRtc2cgPSAoJG8gLXJlcGxhY2UgJ1xzKycsICcgJykuVHJpbSgpIH0NCiAg
>> "%B64FILE%" echo ICAgICAgICAgIH0NCiAgICAgICAgICAgICMgUmUtY2hlY2s6IG9ubHkgYSBwcm9ibGVtIGNvZGUg
>> "%B64FILE%" echo b2YgMjIgKGRpc2FibGVkKSBtZWFucyBpdCByZWFsbHkgdG9vayBlZmZlY3QNCiAgICAgICAgICAg
>> "%B64FILE%" echo ICRub3cgPSAkbnVsbA0KICAgICAgICAgICAgdHJ5IHsgJG5vdyA9IEdldC1QbnBEZXZpY2UgLUlu
>> "%B64FILE%" echo c3RhbmNlSWQgJGkuSW5zdGFuY2VJZCAtRXJyb3JBY3Rpb24gU3RvcCB9IGNhdGNoIHt9DQogICAg
>> "%B64FILE%" echo ICAgICAgICAkcmVhbGx5ID0gJGZhbHNlDQogICAgICAgICAgICBpZiAoJG5vdyAtbmUgJG51bGwg
>> "%B64FILE%" echo LWFuZCAkbm93LlByb2JsZW0gLW5lICRudWxsKSB7DQogICAgICAgICAgICAgICAgaWYgKFtpbnRd
>> "%B64FILE%" echo JG5vdy5Qcm9ibGVtIC1lcSAyMikgeyAkcmVhbGx5ID0gJHRydWUgfQ0KICAgICAgICAgICAgfQ0K
>> "%B64FILE%" echo ICAgICAgICAgICAgaWYgKCRvayAtYW5kICRyZWFsbHkpIHsNCiAgICAgICAgICAgICAgICBTYXkg
>> "%B64FILE%" echo KCIgICAgZGlzYWJsZWQ6ICIgKyAkaS5OYW1lKSAnR3JlZW4nDQogICAgICAgICAgICAgICAgQWRk
>> "%B64FILE%" echo LUxpbmUgKCJkaXNhYmxpbmcgc3VjY2VlZGVkOiAiICsgJGkuTmFtZSArICIgfCAiICsgJGkuSW5z
>> "%B64FILE%" echo dGFuY2VJZCkNCiAgICAgICAgICAgIH0gZWxzZWlmICgkb2sgLWFuZCAtbm90ICRyZWFsbHkpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgKCIgICAgY29tbWFuZCByZXBvcnRlZCBzdWNjZXNzIGJ1dCB0
>> "%B64FILE%" echo aGUgc3RhdGUgZGlkIG5vdCBjaGFuZ2U6ICIgKyAkaS5OYW1lKSAnWWVsbG93Jw0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIEFkZC1MaW5lICgiZGlzYWJsaW5nIHJlc3VsdCB1bmNlcnRhaW46ICIgKyAkaS5OYW1l
>> "%B64FILE%" echo ICsgIiB8IHRoZSBjb21tYW5kIHJldHVybmVkIHN1Y2Nlc3MgYnV0IHJlLWNoZWNrIFN0YXR1cz0i
>> "%B64FILE%" echo ICsgJChpZiAoJG5vdykgeyAkbm93LlN0YXR1cyB9IGVsc2UgeyAnbm9uZScgfSkgKyAiIFByb2Js
>> "%B64FILE%" echo ZW09IiArICQoaWYgKCRub3cpIHsgJG5vdy5Qcm9ibGVtIH0gZWxzZSB7ICdub25lJyB9KSkNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIH0gZWxzZSB7DQogICAgICAgICAgICAgICAgU2F5ICgiICAgIGRpc2FibGluZyBm
>> "%B64FILE%" echo YWlsZWQ6ICIgKyAkaS5OYW1lKSAnUmVkJw0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICgiZGlz
>> "%B64FILE%" echo YWJsaW5nIGZhaWxlZDogIiArICRpLk5hbWUgKyAiIHwgIiArICRtc2cpDQogICAgICAgICAgICB9
>> "%B64FILE%" echo DQogICAgICAgIH0NCiAgICAgICAgJGRpZFNvbWV0aGluZyA9ICR0cnVlDQogICAgICAgIFNheSAi
>> "%B64FILE%" echo Ig0KICAgIH0gZWxzZSB7DQogICAgICAgIEFkZC1MaW5lICJ1c2VyIHNraXBwZWQgZGlzYWJsaW5n
>> "%B64FILE%" echo IHZpcnR1YWwgZGlzcGxheXMiDQogICAgICAgIFNheSAiICAgICAgU2tpcHBlZC4iICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICAgICAgU2F5ICIgICAgICBUbyBkbyBpdCBtYW51YWxseTogRGV2aWNlIE1hbmFnZXIg
>> "%B64FILE%" echo LT4gRGlzcGxheSBhZGFwdGVycyAtPiByaWdodC1jbGljayB0aGUgZW50cnkgLT4gRGlzYWJsZSBk
>> "%B64FILE%" echo ZXZpY2UiICdEYXJrR3JheScNCiAgICAgICAgU2F5ICIiDQogICAgfQ0KfSBlbHNlIHsNCiAgICBB
>> "%B64FILE%" echo ZGQtTGluZSAibm8gdmlydHVhbCBkaXNwbGF5IChST09UXERJU1BMQVkpIGZvdW5kIC0gaWYgdGhl
>> "%B64FILE%" echo IGVtcHR5IEdQVSBwZXJzaXN0cywgc2F5IHdoaWNoIHNsb3QgaXQgaXMiDQp9DQoNCiMgNGIuIEdo
>> "%B64FILE%" echo b3N0IHJlY29yZHMNCmlmICgkZ2hvc3RzLkNvdW50IC1lcSAwKSB7DQogICAgU2F5ICIgIE5vIGdo
>> "%B64FILE%" echo b3N0IHJlY29yZHMgdG8gY2xlYW4uIiAnRGFya0dyYXknDQp9IGVsc2Ugew0KICAgIFNheSAiICBB
>> "%B64FILE%" echo bHNvIGZvdW5kICQoJGdob3N0cy5Db3VudCkgZ2hvc3QgcmVjb3JkcyAoaW1hZ2UgbGVmdG92ZXJz
>> "%B64FILE%" echo LCBub3QgcHJlc2VudCBvbiB0aGlzIG1hY2hpbmUsIGhhcm1sZXNzKS4iICdXaGl0ZScNCiAgICBT
>> "%B64FILE%" echo YXkgIiAgICAgIENsZWFuaW5nIHRoZW0gb25seSBtYWtlcyB0aGUgU2hvdyBoaWRkZW4gZGV2aWNl
>> "%B64FILE%" echo cyBsaXN0IHRpZGllci4iICdEYXJrR3JheScNCiAgICBTYXkgIiINCiAgICAkYW5zMiA9IFJlYWQt
>> "%B64FILE%" echo SG9zdCAiICBDbGVhbiB0aGVzZSBnaG9zdCByZWNvcmRzPyBUeXBlIFkgYW5kIHByZXNzIEVudGVy
>> "%B64FILE%" echo IHRvIHByb2NlZWQsIGFueSBvdGhlciBrZXkgdG8gc2tpcCINCiAgICBpZiAoJGFuczIgLW1hdGNo
>> "%B64FILE%" echo ICdeW1l5XScpIHsNCiAgICAgICAgZm9yZWFjaCAoJGcgaW4gJGdob3N0cykgew0KICAgICAgICAg
>> "%B64FILE%" echo ICAgJG9rID0gJGZhbHNlOyAkdmlhID0gJyc7ICRtc2cgPSAnJw0KDQogICAgICAgICAgICAjIFtv
>> "%B64FILE%" echo cmRlciBmaXhdIFJlbW92ZS1QbnBEZXZpY2UgZmlyc3QgKERJRl9SRU1PVkUgaGFuZGxlcyBhYnNl
>> "%B64FILE%" echo bnQgZGV2aWNlcykNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgUmVtb3ZlLVBu
>> "%B64FILE%" echo cERldmljZSAtSW5zdGFuY2VJZCAkZy5JbnN0YW5jZUlkIC1Db25maXJtOiRmYWxzZSAtRXJyb3JB
>> "%B64FILE%" echo Y3Rpb24gU3RvcA0KICAgICAgICAgICAgICAgICRvayA9ICR0cnVlOyAkdmlhID0gJ1JlbW92ZS1Q
>> "%B64FILE%" echo bnBEZXZpY2UnDQogICAgICAgICAgICB9IGNhdGNoIHsNCiAgICAgICAgICAgICAgICAkbXNnID0g
>> "%B64FILE%" echo JF8uRXhjZXB0aW9uLk1lc3NhZ2UNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgICMgdGhlbiBm
>> "%B64FILE%" echo YWxsIGJhY2sgdG8gcG5wdXRpbA0KICAgICAgICAgICAgaWYgKC1ub3QgJG9rKSB7DQogICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgJG8gPSAoJiBwbnB1dGlsIC9yZW1vdmUtZGV2aWNlICRnLkluc3RhbmNlSWQgMj4m
>> "%B64FILE%" echo MSB8IE91dC1TdHJpbmcpDQogICAgICAgICAgICAgICAgaWYgKCRMQVNURVhJVENPREUgLWVxIDAp
>> "%B64FILE%" echo IHsgJG9rID0gJHRydWU7ICR2aWEgPSAncG5wdXRpbCcgfQ0KICAgICAgICAgICAgICAgIGVsc2Ug
>> "%B64FILE%" echo eyBpZiAoLW5vdCAkbXNnKSB7ICRtc2cgPSAoJG8gLXJlcGxhY2UgJ1xzKycsICcgJykuVHJpbSgp
>> "%B64FILE%" echo IH0gfQ0KICAgICAgICAgICAgfQ0KDQogICAgICAgICAgICAjIFttdXN0IHJlLWNoZWNrXSB0aGUg
>> "%B64FILE%" echo Y29tbWFuZCBzYXlpbmcgc3VjY2VzcyBkb2VzIG5vdCBtZWFuIGl0IHdhcyBkZWxldGVkDQogICAg
>> "%B64FILE%" echo ICAgICAgICAkc3RpbGwgPSAkbnVsbA0KICAgICAgICAgICAgdHJ5IHsgJHN0aWxsID0gR2V0LVBu
>> "%B64FILE%" echo cERldmljZSAtSW5zdGFuY2VJZCAkZy5JbnN0YW5jZUlkIC1FcnJvckFjdGlvbiBTdG9wIH0gY2F0
>> "%B64FILE%" echo Y2gge30NCiAgICAgICAgICAgICRnb25lID0gKCRudWxsIC1lcSAkc3RpbGwpDQoNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIGlmICgkZ29uZSkgew0KICAgICAgICAgICAgICAgIFNheSAoIiAgICBnb25lOiAiICsgJGcu
>> "%B64FILE%" echo TmFtZSkgJ0dyZWVuJw0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICgiZ2hvc3QgZGVsZXRlZCAo
>> "%B64FILE%" echo IiArICR2aWEgKyAiKTogIiArICRnLkluc3RhbmNlSWQpDQogICAgICAgICAgICB9IGVsc2Ugew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgIFNheSAoIiAgICBzdGlsbCBwcmVzZW50OiAiICsgJGcuTmFtZSkgJ1ll
>> "%B64FILE%" echo bGxvdycNCiAgICAgICAgICAgICAgICBBZGQtTGluZSAoImdob3N0IG5vdCBkZWxldGVkOiAiICsg
>> "%B64FILE%" echo JGcuSW5zdGFuY2VJZCArICIgfCBhdHRlbXB0ZWQgdmlhPSIgKyAkdmlhICsgIiB8IGNvbW1hbmQg
>> "%B64FILE%" echo cmVzdWx0PSIgKyAkKGlmICgkb2spIHsgJ3JlcG9ydGVkIHN1Y2Nlc3MnIH0gZWxzZSB7ICdmYWls
>> "%B64FILE%" echo ZWQnIH0pICsgIiB8IGVycm9yPSIgKyAkbXNnKQ0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICIg
>> "%B64FILE%" echo ICAgbm90ZTogdGhlIHJlY29yZCBzdGlsbCBvY2N1cGllcyBhIHNsb3QgaW4gdGhlIHJlZ2lzdHJ5
>> "%B64FILE%" echo IEVudW0gaGl2ZSBhbmQgbmVlZHMgbWFudWFsIGhhbmRsaW5nIChzZWUgYmVsb3cpIg0KICAgICAg
>> "%B64FILE%" echo ICAgICAgfQ0KICAgICAgICB9DQogICAgICAgICRkaWRTb21ldGhpbmcgPSAkdHJ1ZQ0KICAgIH0g
>> "%B64FILE%" echo ZWxzZSB7DQogICAgICAgIEFkZC1MaW5lICJ1c2VyIHNraXBwZWQgZ2hvc3QgY2xlYW51cCINCiAg
>> "%B64FILE%" echo ICAgICAgU2F5ICIgICAgICBTa2lwcGVkLiIgJ0RhcmtHcmF5Jw0KICAgIH0NCn0NCg0KIyAtLS0t
>> "%B64FILE%" echo LS0tLS0tIFs1LzVdIFJlLWNoZWNrIC0tLS0tLS0tLS0NCmlmICgkZGlkU29tZXRoaW5nKSB7DQog
>> "%B64FILE%" echo ICAgU2F5ICIiDQogICAgU2F5ICJbNS81XSBSZS1jaGVja2luZyB0aGUgY3VycmVudCBzdGF0ZS4u
>> "%B64FILE%" echo LiIgJ1doaXRlJw0KICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgNTAwDQogICAgJGFmdGVy
>> "%B64FILE%" echo ID0gQChHZXQtUG5wRGV2aWNlIC1DbGFzcyBEaXNwbGF5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
>> "%B64FILE%" echo bnRpbnVlKQ0KICAgICRzdGlsbEdob3N0ID0gMA0KICAgICRzdGlsbElkZE9uID0gMA0KICAgIGZv
>> "%B64FILE%" echo cmVhY2ggKCRkIGluICRhZnRlcikgew0KICAgICAgICBpZiAoLW5vdCAkZCkgeyBjb250aW51ZSB9
>> "%B64FILE%" echo DQogICAgICAgICRwcmVzID0gJGZhbHNlDQogICAgICAgIHRyeSB7ICRwID0gKEdldC1QbnBEZXZp
>> "%B64FILE%" echo Y2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZC5JbnN0YW5jZUlkIC1LZXlOYW1lICdERVZQS0VZX0Rl
>> "%B64FILE%" echo dmljZV9Jc1ByZXNlbnQnIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRhOyBpZiAoJHAgLWVxICR0cnVl
>> "%B64FILE%" echo KSB7ICRwcmVzID0gJHRydWUgfSB9IGNhdGNoIHt9DQogICAgICAgICRwciA9IDANCiAgICAgICAg
>> "%B64FILE%" echo aWYgKCRkLlByb2JsZW0gLW5lICRudWxsKSB7ICRwciA9IFtpbnRdJGQuUHJvYmxlbSB9DQogICAg
>> "%B64FILE%" echo ICAgIGlmICgtbm90ICRwcmVzKSB7ICRzdGlsbEdob3N0KysgfQ0KICAgICAgICBlbHNlaWYgKCRk
>> "%B64FILE%" echo Lkluc3RhbmNlSWQgLWxpa2UgJ1JPT1RcKicgLWFuZCAkcHIgLW5lIDIyKSB7ICRzdGlsbElkZE9u
>> "%B64FILE%" echo KysgfQ0KICAgIH0NCiAgICBBZGQtTGluZSAiIg0KICAgIEFkZC1MaW5lICItLS0tLS0tLS0tIFJl
>> "%B64FILE%" echo LWNoZWNrIHJlc3VsdCAtLS0tLS0tLS0tIg0KICAgIEFkZC1MaW5lICgiZ2hvc3QgcmVjb3JkcyBs
>> "%B64FILE%" echo ZWZ0OiAiICsgJHN0aWxsR2hvc3QpDQogICAgQWRkLUxpbmUgKCJ2aXJ0dWFsIGRpc3BsYXlzIHN0
>> "%B64FILE%" echo aWxsIGVuYWJsZWQ6ICIgKyAkc3RpbGxJZGRPbikNCiAgICBTYXkgKCIgIHJlLWNoZWNrOiB7MH0g
>> "%B64FILE%" echo Z2hvc3QgcmVjb3JkcyBsZWZ0LCB7MX0gdmlydHVhbCBkaXNwbGF5cyBzdGlsbCBlbmFibGVkIiAt
>> "%B64FILE%" echo ZiAkc3RpbGxHaG9zdCwgJHN0aWxsSWRkT24pICdDeWFuJw0KfSBlbHNlIHsNCiAgICBBZGQtTGlu
>> "%B64FILE%" echo ZSAiIg0KICAgIEFkZC1MaW5lICJ0aGlzIHJ1biBvbmx5IGRpYWdub3NlZCwgbm8gZGV2aWNlIHdh
>> "%B64FILE%" echo cyBtb2RpZmllZCINCn0NCg0KIyAtLS0tLS0tLS0tIFdyaXRlIHRoZSByZXBvcnQgLS0tLS0tLS0t
>> "%B64FILE%" echo LQ0KQWRkLUxpbmUgIiINCkFkZC1MaW5lICI9PT09PT09PT09PT09PT09PT09PSBEaWFnbm9zdGlj
>> "%B64FILE%" echo cyBmaW5pc2hlZCA9PT09PT09PT09PT09PT09PT09PSINCg0KIyBbdjEuMjldIFRoZSByZXBvcnQg
>> "%B64FILE%" echo aXMgbm8gbG9uZ2VyIGRyb3BwZWQgaW4gdGhlIGRyaXZlIHJvb3Q7IGV2ZXJ5dGhpbmcgZ29lcyB0
>> "%B64FILE%" echo byA8ZHJpdmU+Olw8UHJvZHVjdE5hbWU+LWxvZ3NcDQokc2F2ZWQgPSBAKCkNCmZvcmVhY2ggKCR2
>> "%B64FILE%" echo IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICBp
>> "%B64FILE%" echo ZiAoLW5vdCAkdi5Ecml2ZUxldHRlcikgeyBjb250aW51ZSB9DQogICAgaWYgKCR2LkRyaXZlVHlw
>> "%B64FILE%" echo ZSAtbmUgJ0ZpeGVkJykgeyBjb250aW51ZSB9DQogICAgJGRpciA9ICJ7MH06XFZpcnR1YWwgSGFy
>> "%B64FILE%" echo ZCBEaXNrIFN5c3RlbS1sb2dzIiAtZiAkdi5Ecml2ZUxldHRlcg0KICAgIHRyeSB7DQogICAgICAg
>> "%B64FILE%" echo IGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRkaXIpKSB7DQogICAgICAgICAgICBO
>> "%B64FILE%" echo ZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRkaXIgLUZvcmNlIC1FcnJvckFjdGlv
>> "%B64FILE%" echo biBTdG9wIHwgT3V0LU51bGwNCiAgICAgICAgfQ0KICAgICAgICAkcCA9IEpvaW4tUGF0aCAkZGly
>> "%B64FILE%" echo ICdncHUtcmVwb3J0LnR4dCcNCiAgICAgICAgJHJlcG9ydCAtam9pbiAiYHJgbiIgfCBTZXQtQ29u
>> "%B64FILE%" echo dGVudCAtTGl0ZXJhbFBhdGggJHAgLUVuY29kaW5nIFVURjggLUVycm9yQWN0aW9uIFN0b3ANCiAg
>> "%B64FILE%" echo ICAgICAgJHNhdmVkICs9ICRwDQogICAgfSBjYXRjaCB7fQ0KfQ0KDQpTYXkgIiINClNheSAiICAt
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0iICdEYXJrR3JheScNCmZvcmVhY2ggKCRwIGluICRzYXZlZCkgeyBTYXkgKCIgIHJlcG9ydCBz
>> "%B64FILE%" echo YXZlZDogIiArICRwKSAnR3JlZW4nIH0NCg0KaWYgKCRzdGlsbEdob3N0IC1ndCAwKSB7DQogICAg
>> "%B64FILE%" echo U2F5ICIiDQogICAgU2F5ICIgIE1hbnVhbCBzdGVwcyB3aGVuIGdob3N0IHJlY29yZHMgc3RpbGwg
>> "%B64FILE%" echo Y2Fubm90IGJlIGRlbGV0ZWQ6IiAnWWVsbG93Jw0KICAgIFNheSAiICAgIERldmljZSBNYW5hZ2Vy
>> "%B64FILE%" echo IC0+IFZpZXcgLT4gU2hvdyBoaWRkZW4gZGV2aWNlcyAtPiBEaXNwbGF5IGFkYXB0ZXJzIC0+IiAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgU2F5ICIgICAgcmlnaHQtY2xpY2sgdGhlIGdyZXkgZW50cmllcyAtPiBV
>> "%B64FILE%" echo bmluc3RhbGwgZGV2aWNlIC0+IHJlYm9vdC4iICdEYXJrR3JheScNCn0NClNheSAiIg0KU2F5ICIg
>> "%B64FILE%" echo IEFmdGVyIGRpc2FibGluZyBhIHZpcnR1YWwgZGlzcGxheSwgcmVib290IG9uY2UgZm9yIHRoZSBU
>> "%B64FILE%" echo YXNrIE1hbmFnZXIgR1BVIGxpc3QgdG8gcmVmcmVzaC4iICdDeWFuJw0KU2F5ICIiDQpSZWFkLUhv
>> "%B64FILE%" echo c3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=18040"
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
