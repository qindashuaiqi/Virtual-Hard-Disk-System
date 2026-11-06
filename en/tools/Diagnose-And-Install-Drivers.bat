@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Diagnose and Install Drivers
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
set "PS1FILE=%WORKDIR%\Diagnose-And-Install-Drivers.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oKQ0KDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PQ0KIyBOZXcgU3lzdGVtOiBkaWFnbm9zZSBhbmQgaW5zdGFsbCBk
>> "%B64FILE%" echo cml2ZXJzICB2MS4xDQojIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QNCiMNCiMgV2hlcmUgdG8gcnVu
>> "%B64FILE%" echo OiAqKmluc2lkZSB0aGUgbmV3bHkgaW5zdGFsbGVkIHZpcnR1YWwgc3lzdGVtKiogKG5vdCB0aGUg
>> "%B64FILE%" echo b3JpZ2luYWwgb25lKS4NCiMNCiMgV2hhdCB2MS4xIGZpeGVkOg0KIyAgMSkgdjEuMCBjb3VudGVk
>> "%B64FILE%" echo IGV2ZXJ5IGRldmljZSB3aXRoIFByb2JsZW3iiaAwIGFzICJmYXVsdHkiLCBzbyA1NTMgQ01fUFJP
>> "%B64FILE%" echo Ql9QSEFOVE9NIGVudHJpZXMNCiMgICAgIChoaXN0b3JpY2FsIGRldmljZSByZWNvcmRzIGEgY2xv
>> "%B64FILE%" echo bmVkIGltYWdlIGxlYXZlcyBpbiB0aGUgcmVnaXN0cnkpIGRyb3duZWQgb3V0IHRoZSAzIHJlYWwg
>> "%B64FILE%" echo ZmF1bHRzLg0KIyAgICAgQSBwaGFudG9tIGlzIG5vdCBhIGZhdWx0IC0gdGhlIGhhcmR3YXJlIGxl
>> "%B64FILE%" echo ZnQgdGhlIG1hY2hpbmUgbG9uZyBhZ28sIG9ubHkgdGhlIHJlY29yZCB3YXMgbmV2ZXIgY2xlYW5l
>> "%B64FILE%" echo ZC4NCiMgIDIpIHYxLjAgcmFuIHBucHV0aWwgL2FkZC1kcml2ZXIgPGZvbGRlcj4gL3N1YmRpcnMg
>> "%B64FILE%" echo aW4gb25lIHNob3QsIGFuZCB3aXRoIDE1NCBJTkYgZmlsZXMgaW4gdGhhdCBmb2xkZXINCiMgICAg
>> "%B64FILE%" echo IGl0IHN0aWxsIHJlcG9ydGVkICJ0b3RhbCBkcml2ZXIgcGFja2FnZXM6IDAiLg0KIyAgICAgdjEu
>> "%B64FILE%" echo MSBmaXJzdCBtYXRjaGVzIHRoZSBoYXJkd2FyZSBJRHMgb2YgdGhlIGZhdWx0eSBkZXZpY2VzIGFn
>> "%B64FILE%" echo YWluc3QgdGhlIElORiBmaWxlcywgdGhlbiBpbnN0YWxscyBJTkYgYnkgSU5GLg0KIyAgICAgVGhh
>> "%B64FILE%" echo dCBhdm9pZHMgL3N1YmRpcnMgYW5kIGRvZXMgbm90IGhhdmUgdG8gd2FsayBhbGwgMTU0IHBhY2th
>> "%B64FILE%" echo Z2VzLg0KIw0KIyBSZXBvcnQgZmlsZTogPHNvbWUgZHJpdmU+Olw8UHJvZHVjdE5hbWU+LWxvZ3Nc
>> "%B64FILE%" echo bmV3LXN5c3RlbS1yZXBvcnQudHh0DQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0g
>> "%B64FILE%" echo J0NvbnRpbnVlJw0KJFNjcmlwdDpWZXJzaW9uID0gJzEuMzQnDQp0cnkgeyAkSG9zdC5VSS5SYXdV
>> "%B64FILE%" echo SS5XaW5kb3dUaXRsZSA9ICJOZXcgU3lzdGVtIERpYWdub3NlIGFuZCBJbnN0YWxsIERyaXZlcnMg
>> "%B64FILE%" echo diQoJFNjcmlwdDpWZXJzaW9uKSAtIGNvbm5lY3RzZWdhYm90IiB9IGNhdGNoIHt9DQoNCiMgW3Yx
>> "%B64FILE%" echo LjMyXSBTaGFyZWQgbW9kdWxlLiBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSBpbmxpbmVzIHRo
>> "%B64FILE%" echo aXMgZmlsZSBhdA0KIyBidWlsZCB0aW1lLCBhbmQgdGhlIC5iYXQgcGF5bG9hZCBpcyBzdGlsbCBh
>> "%B64FILE%" echo IHNlbGYtY29udGFpbmVkIHNpbmdsZSBmaWxlLg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMgU2hhcmVkIGxvZ2dpbmcgaGVs
>> "%B64FILE%" echo cGVycyAgIHYxLjMyDQojDQojIFRoaXMgZmlsZSBpcyBOT1Qgd2hhdCBnZXRzIHNoaXBwZWQuIHNy
>> "%B64FILE%" echo Yy9idWlsZC9pbmxpbmVfc2hhcmVkLnB5IGlubGluZXMgaXRzDQojIGNvbnRlbnQgaW50byBldmVy
>> "%B64FILE%" echo eSBlbnRyeSBzY3JpcHQgd2hpbGUgdGhlIC5iYXQgcGF5bG9hZHMgYXJlIGJ1aWx0LCBzbyB0aGUN
>> "%B64FILE%" echo CiMgcmVsZWFzZWQgbGF1bmNoZXJzIHN0YXkgc2VsZi1jb250YWluZWQgc2luZ2xlIGZpbGVzICh0
>> "%B64FILE%" echo aGUgc2VsZi1leHRyYWN0aW5nIGJhdA0KIyBoYXMgbm8gd2F5IHRvIHJlZmVyZW5jZSBhbiBleHRl
>> "%B64FILE%" echo cm5hbCBtb2R1bGUgYXQgcnVuIHRpbWUpLg0KIw0KIyBSdWxlOiBlZGl0IGhlcmUsIG5ldmVyIGNv
>> "%B64FILE%" echo cHktcGFzdGUgdGhlc2UgZnVuY3Rpb25zIGJhY2sgaW50byBhbiBlbnRyeSBzY3JpcHQuDQojID09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PQ0KDQpmdW5jdGlvbiBTYXkgew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtzdHJpbmddJENv
>> "%B64FILE%" echo bG9yID0gJ0dyYXknKQ0KICAgIFdyaXRlLUhvc3QgJFRleHQgLUZvcmVncm91bmRDb2xvciAkQ29s
>> "%B64FILE%" echo b3INCn0NCg0KU2F5ICIiDQpTYXkgIiAgTmV3IFN5c3RlbSBEaWFnbm9zZSBhbmQgSW5zdGFsbCBE
>> "%B64FILE%" echo cml2ZXJzICB2JCgkU2NyaXB0OlZlcnNpb24pIiAnQ3lhbicNClNheSAiICBBdXRob3I6IGNvbm5l
>> "%B64FILE%" echo Y3RzZWdhYm90IiAnRGFya0dyYXknDQpTYXkgIiAgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiAnRGFya0dyYXknDQpTYXkgIiINCg0K
>> "%B64FILE%" echo JGFkbWluID0gKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbF1bU2VjdXJpdHku
>> "%B64FILE%" echo UHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKSkuSXNJblJvbGUoW1NlY3Vy
>> "%B64FILE%" echo aXR5LlByaW5jaXBhbC5XaW5kb3dzQnVpbHRJblJvbGVdOjpBZG1pbmlzdHJhdG9yKQ0KaWYgKC1u
>> "%B64FILE%" echo b3QgJGFkbWluKSB7DQogICAgU2F5ICIgIFtFUlJPUl0gQWRtaW5pc3RyYXRvciByaWdodHMgYXJl
>> "%B64FILE%" echo IHJlcXVpcmVkLiBSaWdodC1jbGljayAtPiBSdW4gYXMgYWRtaW5pc3RyYXRvci4iICdSZWQnDQog
>> "%B64FILE%" echo ICAgUmVhZC1Ib3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQiDQogICAgZXhpdCAxDQp9DQoNCiRy
>> "%B64FILE%" echo ZXBvcnQgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QNCmZ1bmN0aW9u
>> "%B64FILE%" echo IEFkZC1MaW5lIHsgcGFyYW0oW3N0cmluZ10kVCA9ICcnKSBbdm9pZF0kcmVwb3J0LkFkZCgkVCkg
>> "%B64FILE%" echo fQ0KDQokb3MgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFj
>> "%B64FILE%" echo dGlvbiBTaWxlbnRseUNvbnRpbnVlDQpBZGQtTGluZSAiPT09PT09PT09PT09PT09PT09PT0gTmV3
>> "%B64FILE%" echo IHN5c3RlbSBkaWFnbm9zdGljcyB2JCgkU2NyaXB0OlZlcnNpb24pID09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09Ig0KQWRkLUxpbmUgKCJDb21wdXRlciAgICAgOiAiICsgJGVudjpDT01QVVRFUk5BTUUpDQpB
>> "%B64FILE%" echo ZGQtTGluZSAoIlN5c3RlbSAgICAgICA6ICIgKyAkb3MuQ2FwdGlvbiArICIgIEJ1aWxkICIgKyAk
>> "%B64FILE%" echo b3MuQnVpbGROdW1iZXIpDQpBZGQtTGluZSAoIkJvb3QgdGltZSAgICA6ICIgKyAkb3MuTGFzdEJv
>> "%B64FILE%" echo b3RVcFRpbWUpDQpBZGQtTGluZSAoIlVwdGltZSAgICAgICA6ICIgKyBbc3RyaW5nXShbZGF0ZXRp
>> "%B64FILE%" echo bWVdOjpOb3cgLSAkb3MuTGFzdEJvb3RVcFRpbWUpKQ0KQWRkLUxpbmUgKCJTeXN0ZW0gZHJpdmUg
>> "%B64FILE%" echo OiAiICsgJGVudjpTeXN0ZW1Ecml2ZSkNCkFkZC1MaW5lICIiDQoNCiMgLS0tLS0tLS0tLSBSZWFs
>> "%B64FILE%" echo IGZhdWx0cyBvbmx5LCBubyBwaGFudG9tcyAtLS0tLS0tLS0tDQojICAgMjIgPSBDTV9QUk9CX0RJ
>> "%B64FILE%" echo U0FCTEVEIChkaXNhYmxlZCwgdXN1YWxseSBvbiBwdXJwb3NlKQ0KIyAgIDQ1ID0gQ01fUFJPQl9Q
>> "%B64FILE%" echo SEFOVE9NIChoaXN0b3JpY2FsIHJlY29yZCwgZGV2aWNlIG5vdCBwcmVzZW50KQ0KJGlnbm9yZVBy
>> "%B64FILE%" echo b2JsZW0gPSBAKDAsIDIyLCA0NSkNCmZ1bmN0aW9uIEdldC1SZWFsUHJvYmxlbXMgew0KICAgICRs
>> "%B64FILE%" echo aXN0ID0gQCgpDQogICAgJHNlZW4gPSBAe30NCiAgICBmb3JlYWNoICgkZCBpbiBAKEdldC1QbnBE
>> "%B64FILE%" echo ZXZpY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgtbm90
>> "%B64FILE%" echo ICRkKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgJHAgPSAkZC5Qcm9ibGVtDQogICAgICAgIGlmICgk
>> "%B64FILE%" echo cCAtZXEgJG51bGwpIHsgJHAgPSAwIH0NCiAgICAgICAgaWYgKCRpZ25vcmVQcm9ibGVtIC1jb250
>> "%B64FILE%" echo YWlucyBbaW50XSRwKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgaWYgKCRkLlN0YXR1cyAtZXEgJ1Vu
>> "%B64FILE%" echo a25vd24nKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgaWYgKCRzZWVuLkNvbnRhaW5zS2V5KCRkLklu
>> "%B64FILE%" echo c3RhbmNlSWQpKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgJHNlZW5bJGQuSW5zdGFuY2VJZF0gPSAx
>> "%B64FILE%" echo DQogICAgICAgICRsaXN0ICs9ICRkDQogICAgfQ0KICAgIHJldHVybiAkbGlzdA0KfQ0KDQpTYXkg
>> "%B64FILE%" echo IlsxLzRdIENvbGxlY3RpbmcgZ2VudWluZWx5IGZhdWx0eSBkZXZpY2VzIChwaGFudG9tcyBza2lw
>> "%B64FILE%" echo cGVkKS4uLiIgJ1doaXRlJw0KJHByb2JsZW1zID0gQChHZXQtUmVhbFByb2JsZW1zKQ0KQWRkLUxp
>> "%B64FILE%" echo bmUgIi0tLS0tLS0tLS0gR2VudWluZWx5IGZhdWx0eSBkZXZpY2VzIC0tLS0tLS0tLS0iDQpBZGQt
>> "%B64FILE%" echo TGluZSAoInswfSBpbiB0b3RhbCIgLWYgJHByb2JsZW1zLkNvdW50KQ0KQWRkLUxpbmUgIiINCmZv
>> "%B64FILE%" echo cmVhY2ggKCRkIGluICRwcm9ibGVtcykgew0KICAgICRodyA9IEAoKQ0KICAgIHRyeSB7ICRodyA9
>> "%B64FILE%" echo IEAoKEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZC5JbnN0YW5jZUlkIC1LZXlO
>> "%B64FILE%" echo YW1lICdERVZQS0VZX0RldmljZV9IYXJkd2FyZUlkcycgLUVycm9yQWN0aW9uIFN0b3ApLkRhdGEp
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCiAgICBBZGQtTGluZSAoIlt7MH1dIHsxfSIgLWYgJGQuU3RhdHVzLCAkZC5G
>> "%B64FILE%" echo cmllbmRseU5hbWUpDQogICAgQWRkLUxpbmUgKCIgICAgcHJvYmxlbSBjb2RlOiB7MH0gICBjbGFz
>> "%B64FILE%" echo czogezF9IiAtZiAkZC5Qcm9ibGVtLCAkZC5DbGFzcykNCiAgICBBZGQtTGluZSAoIiAgICBpbnN0
>> "%B64FILE%" echo YW5jZSBJRDogezB9IiAtZiAkZC5JbnN0YW5jZUlkKQ0KICAgIGlmICgkaHcuQ291bnQgLWd0IDAp
>> "%B64FILE%" echo IHsgQWRkLUxpbmUgKCIgICAgaGFyZHdhcmUgSUQ6ICIgKyAoJGh3IC1qb2luICcgOyAnKSkgfQ0K
>> "%B64FILE%" echo ICAgIEFkZC1MaW5lICIiDQp9DQpTYXkgKCIgICAgICB7MH0gZ2VudWluZSBmYXVsdHMiIC1mICRw
>> "%B64FILE%" echo cm9ibGVtcy5Db3VudCkgJ0RhcmtHcmF5Jw0KDQojIC0tLS0tLS0tLS0gRmluZCB0aGUgZHJpdmVy
>> "%B64FILE%" echo IGZvbGRlcnMgLS0tLS0tLS0tLQ0KJGRydkRpcnMgPSBAKCkNCmZvcmVhY2ggKCR2IGluIEAoR2V0
>> "%B64FILE%" echo LVZvbHVtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICBpZiAoLW5vdCAk
>> "%B64FILE%" echo di5Ecml2ZUxldHRlcikgeyBjb250aW51ZSB9DQogICAgaWYgKChbc3RyaW5nXSR2LkRyaXZlTGV0
>> "%B64FILE%" echo dGVyKS5Ub1VwcGVyKCkgLWVxICgoW3N0cmluZ10kZW52OlN5c3RlbURyaXZlKS5UcmltRW5kKCc6
>> "%B64FILE%" echo JykuVG9VcHBlcigpKSkgeyBjb250aW51ZSB9DQogICAgZm9yZWFjaCAoJG5tIGluIEAoJ05ld1N5
>> "%B64FILE%" echo c3RlbURyaXZlcicsICfmlrDns7vnu5/pqbHliqgnKSkgew0KICAgICAgICAkYyA9ICJ7MH06XHsx
>> "%B64FILE%" echo fSIgLWYgJHYuRHJpdmVMZXR0ZXIsICRubQ0KICAgICAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFs
>> "%B64FILE%" echo UGF0aCAkYykgeyAkZHJ2RGlycyArPSAkYyB9DQogICAgfQ0KfQ0KZm9yZWFjaCAoJGMgaW4gQCgn
>> "%B64FILE%" echo QzpcTmV3U3lzdGVtRHJpdmVyJywgJ0M6XOaWsOezu+e7n+mpseWKqCcpKSB7DQogICAgaWYgKFRl
>> "%B64FILE%" echo c3QtUGF0aCAtTGl0ZXJhbFBhdGggJGMpIHsgJGRydkRpcnMgKz0gJGMgfQ0KfQ0KJGRydkRpcnMg
>> "%B64FILE%" echo PSBAKCRkcnZEaXJzIHwgU2VsZWN0LU9iamVjdCAtVW5pcXVlKQ0KJGFsbEluZiA9IEAoKQ0KZm9y
>> "%B64FILE%" echo ZWFjaCAoJGRkIGluICRkcnZEaXJzKSB7ICRhbGxJbmYgKz0gQChHZXQtQ2hpbGRJdGVtIC1MaXRl
>> "%B64FILE%" echo cmFsUGF0aCAkZGQgLVJlY3Vyc2UgLUZpbHRlciAqLmluZiAtRUEgU2lsZW50bHlDb250aW51ZSkg
>> "%B64FILE%" echo fQ0KQWRkLUxpbmUgIi0tLS0tLS0tLS0gRHJpdmVyIGxpYnJhcnkgLS0tLS0tLS0tLSINCmlmICgk
>> "%B64FILE%" echo YWxsSW5mLkNvdW50IC1lcSAwKSB7IEFkZC1MaW5lICJubyBJTkYgZm91bmQgYXQgYWxsIiB9DQpm
>> "%B64FILE%" echo b3JlYWNoICgkZGQgaW4gJGRydkRpcnMpIHsgQWRkLUxpbmUgKCJmb2xkZXI6ICIgKyAkZGQpIH0N
>> "%B64FILE%" echo CkFkZC1MaW5lICgiSU5GIGZpbGVzIGluIHRvdGFsOiB7MH0iIC1mICRhbGxJbmYuQ291bnQpDQpB
>> "%B64FILE%" echo ZGQtTGluZSAiIg0KU2F5ICgiICAgICAgezB9IGRyaXZlciBmb2xkZXJzLCB7MX0gSU5GIGZpbGVz
>> "%B64FILE%" echo IiAtZiAkZHJ2RGlycy5Db3VudCwgJGFsbEluZi5Db3VudCkgJ0RhcmtHcmF5Jw0KDQojIC0tLS0t
>> "%B64FILE%" echo LS0tLS0gTWF0Y2ggSU5GIGZpbGVzIGJ5IGhhcmR3YXJlIElEIC0tLS0tLS0tLS0NClNheSAiWzIv
>> "%B64FILE%" echo NF0gTWF0Y2hpbmcgSU5GIGZpbGVzIGJ5IGhhcmR3YXJlIElEIC4uLiIgJ1doaXRlJw0KZnVuY3Rp
>> "%B64FILE%" echo b24gR2V0LU1hdGNoS2V5cyB7DQogICAgcGFyYW0oW3N0cmluZ10kaW5zdCwgJGh3TGlzdCkNCiAg
>> "%B64FILE%" echo ICAka2V5cyA9IEAoKQ0KICAgIGZvcmVhY2ggKCRoIGluIEAoJGh3TGlzdCkpIHsNCiAgICAgICAg
>> "%B64FILE%" echo aWYgKC1ub3QgJGgpIHsgY29udGludWUgfQ0KICAgICAgICAka2V5cyArPSAkaA0KICAgICAgICAk
>> "%B64FILE%" echo a2V5cyArPSAoJGggLXJlcGxhY2UgJyZSRVZfWzAtOUEtRmEtZl0rJywgJycpDQogICAgfQ0KICAg
>> "%B64FILE%" echo ICRtID0gW3JlZ2V4XTo6TWF0Y2goJGluc3QsICcoP2kpKCg/OlBDSXxVU0IpXFxWRU5fWzAtOUEt
>> "%B64FILE%" echo Rl17NH0mREVWX1swLTlBLUZdezR9JlNVQlNZU19bMC05QS1GXXs4fSknKQ0KICAgIGlmICgkbS5T
>> "%B64FILE%" echo dWNjZXNzKSB7ICRrZXlzICs9ICRtLkdyb3Vwc1sxXS5WYWx1ZSB9DQogICAgJG0yID0gW3JlZ2V4
>> "%B64FILE%" echo XTo6TWF0Y2goJGluc3QsICcoP2kpKCg/OlBDSXxVU0IpXFxWRU5fWzAtOUEtRl17NH0mREVWX1sw
>> "%B64FILE%" echo LTlBLUZdezR9KScpDQogICAgaWYgKCRtMi5TdWNjZXNzKSB7ICRrZXlzICs9ICRtMi5Hcm91cHNb
>> "%B64FILE%" echo MV0uVmFsdWUgfQ0KICAgIHJldHVybiBAKCRrZXlzIHwgV2hlcmUtT2JqZWN0IHsgJF8gfSB8IFNl
>> "%B64FILE%" echo bGVjdC1PYmplY3QgLVVuaXF1ZSkNCn0NCg0KJGluZlRleHQgPSBAe30NCmZvcmVhY2ggKCRmIGlu
>> "%B64FILE%" echo ICRhbGxJbmYpIHsNCiAgICB0cnkgew0KICAgICAgICAkdCA9ICcnDQogICAgICAgIHRyeSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAkdCA9IFtJTy5GaWxlXTo6UmVhZEFsbFRleHQoJGYuRnVsbE5hbWUsIFtUZXh0
>> "%B64FILE%" echo LkVuY29kaW5nXTo6VW5pY29kZSkNCiAgICAgICAgICAgIGlmICgkdCAtbm90bWF0Y2ggJ1xbVmVy
>> "%B64FILE%" echo c2lvblxdJykgeyAkdCA9IFtJTy5GaWxlXTo6UmVhZEFsbFRleHQoJGYuRnVsbE5hbWUsIFtUZXh0
>> "%B64FILE%" echo LkVuY29kaW5nXTo6RGVmYXVsdCkgfQ0KICAgICAgICB9IGNhdGNoIHsgJHQgPSAnJyB9DQogICAg
>> "%B64FILE%" echo ICAgIGlmICgkdCkgeyAkaW5mVGV4dFskZi5GdWxsTmFtZV0gPSAkdCB9DQogICAgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KfQ0KU2F5ICgiICAgICAgcmVhZCB0aGUgY29udGVudHMgb2YgezB9IElORiBmaWxlcyIgLWYg
>> "%B64FILE%" echo JGluZlRleHQuQ291bnQpICdEYXJrR3JheScNCg0KJGluc3RhbGxRdWV1ZSA9IE5ldy1PYmplY3Qg
>> "%B64FILE%" echo U3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KZm9yZWFjaCAoJGQgaW4gJHByb2JsZW1zKSB7
>> "%B64FILE%" echo DQogICAgJGh3ID0gQCgpDQogICAgdHJ5IHsgJGh3ID0gQCgoR2V0LVBucERldmljZVByb3BlcnR5
>> "%B64FILE%" echo IC1JbnN0YW5jZUlkICRkLkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0hhcmR3
>> "%B64FILE%" echo YXJlSWRzJyAtRXJyb3JBY3Rpb24gU3RvcCkuRGF0YSkgfSBjYXRjaCB7fQ0KICAgICRrZXlzID0g
>> "%B64FILE%" echo R2V0LU1hdGNoS2V5cyAtaW5zdCAkZC5JbnN0YW5jZUlkIC1od0xpc3QgJGh3DQogICAgJG1hdGNo
>> "%B64FILE%" echo ZWQgPSBAKCkNCiAgICBmb3JlYWNoICgka3YgaW4gJGluZlRleHQuR2V0RW51bWVyYXRvcigpKSB7
>> "%B64FILE%" echo DQogICAgICAgIGZvcmVhY2ggKCRrIGluICRrZXlzKSB7DQogICAgICAgICAgICBpZiAoJGt2LlZh
>> "%B64FILE%" echo bHVlLkluZGV4T2YoJGssIFtTdHJpbmdDb21wYXJpc29uXTo6T3JkaW5hbElnbm9yZUNhc2UpIC1n
>> "%B64FILE%" echo ZSAwKSB7DQogICAgICAgICAgICAgICAgJG1hdGNoZWQgKz0gJGt2LktleQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgIGJyZWFrDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQogICAgJG1hdGNoZWQg
>> "%B64FILE%" echo PSBAKCRtYXRjaGVkIHwgU2VsZWN0LU9iamVjdCAtVW5pcXVlKQ0KICAgIFt2b2lkXSRpbnN0YWxs
>> "%B64FILE%" echo UXVldWUuQWRkKFtwc2N1c3RvbW9iamVjdF1AeyBEZXYgPSAkZDsgS2V5cyA9ICRrZXlzOyBJbmZz
>> "%B64FILE%" echo ID0gJG1hdGNoZWQgfSkNCiAgICBTYXkgKCIgICAgICB7MH0gIC0+IHsxfSBtYXRjaGluZyBJTkYg
>> "%B64FILE%" echo ZmlsZXMiIC1mICRkLkZyaWVuZGx5TmFtZSwgJG1hdGNoZWQuQ291bnQpICdEYXJrR3JheScNCiAg
>> "%B64FILE%" echo ICBBZGQtTGluZSAoIm1hdGNoOiB7MH0gICh7MX0gSU5GIGZpbGVzKSIgLWYgJGQuRnJpZW5kbHlO
>> "%B64FILE%" echo YW1lLCAkbWF0Y2hlZC5Db3VudCkNCiAgICBmb3JlYWNoICgkbWkgaW4gJG1hdGNoZWQpIHsgQWRk
>> "%B64FILE%" echo LUxpbmUgKCIgICAgIiArICRtaSkgfQ0KfQ0KDQojIC0tLS0tLS0tLS0gSW5zdGFsbCBvbiB0aGUg
>> "%B64FILE%" echo c3BvdCAtLS0tLS0tLS0tDQpTYXkgIlszLzRdIEluc3RhbGxpbmcgb24gdGhlIHNwb3QgKGZvcmNl
>> "%B64FILE%" echo IGEgZGV2aWNlIHJlc2NhbiBmaXJzdCkuLi4iICdXaGl0ZScNCkFkZC1MaW5lICIiDQpBZGQtTGlu
>> "%B64FILE%" echo ZSAiLS0tLS0tLS0tLSBPbi10aGUtc3BvdCBpbnN0YWxsYXRpb24gcmVzdWx0IC0tLS0tLS0tLS0i
>> "%B64FILE%" echo DQokc2NhbiA9ICcnDQp0cnkgeyAkc2NhbiA9ICgmIHBucHV0aWwgL3NjYW4tZGV2aWNlcyAyPiYx
>> "%B64FILE%" echo IHwgT3V0LVN0cmluZykgfSBjYXRjaCB7fQ0KJHNjYW5UeHQgPSAoJHNjYW4gLXJlcGxhY2UgIlxz
>> "%B64FILE%" echo KyIsICcgJykuVHJpbSgpDQpTYXkgKCIgICAgICBkZXZpY2UgcmVzY2FuOiAiICsgJHNjYW5UeHQp
>> "%B64FILE%" echo ICdEYXJrR3JheScNCkFkZC1MaW5lICgiZGV2aWNlIHJlc2NhbjogIiArICRzY2FuVHh0KQ0KU3Rh
>> "%B64FILE%" echo cnQtU2xlZXAgLVNlY29uZHMgMw0KDQokbG9nID0gSm9pbi1QYXRoICRlbnY6VEVNUCAncG5wdXRp
>> "%B64FILE%" echo bF9vbmUubG9nJw0KZm9yZWFjaCAoJGl0ZW0gaW4gJGluc3RhbGxRdWV1ZSkgew0KICAgIGlmICgk
>> "%B64FILE%" echo aXRlbS5JbmZzLkNvdW50IC1lcSAwKSB7IGNvbnRpbnVlIH0NCiAgICBmb3JlYWNoICgkaW5mIGlu
>> "%B64FILE%" echo ICRpdGVtLkluZnMpIHsNCiAgICAgICAgdHJ5IHsgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGgg
>> "%B64FILE%" echo JGxvZykgeyBSZW1vdmUtSXRlbSAkbG9nIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IH0g
>> "%B64FILE%" echo Y2F0Y2gge30NCiAgICAgICAgdHJ5IHsgaWYgKFRlc3QtUGF0aCAoJGxvZyArICcuZXJyJykpIHsg
>> "%B64FILE%" echo UmVtb3ZlLUl0ZW0gKCRsb2cgKyAnLmVycicpIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCiAgICAgICAgJHAgPSBTdGFydC1Qcm9jZXNzIC1GaWxlUGF0aCAncG5wdXRp
>> "%B64FILE%" echo bC5leGUnIC1Bcmd1bWVudExpc3QgQCgnL2FkZC1kcml2ZXInLCAiYCIkaW5mYCIiLCAnL2luc3Rh
>> "%B64FILE%" echo bGwnKSBgDQogICAgICAgICAgICAgICAgLVJlZGlyZWN0U3RhbmRhcmRPdXRwdXQgJGxvZyAtUmVk
>> "%B64FILE%" echo aXJlY3RTdGFuZGFyZEVycm9yICgkbG9nICsgJy5lcnInKSBgDQogICAgICAgICAgICAgICAgLU5v
>> "%B64FILE%" echo TmV3V2luZG93IC1QYXNzVGhydSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICAkc3cgPSBbU3lz
>> "%B64FILE%" echo dGVtLkRpYWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0TmV3KCkNCiAgICAgICAgd2hpbGUgKC1u
>> "%B64FILE%" echo b3QgJHAuSGFzRXhpdGVkKSB7DQogICAgICAgICAgICBTdGFydC1TbGVlcCAtTWlsbGlzZWNvbmRz
>> "%B64FILE%" echo IDUwMA0KICAgICAgICAgICAgaWYgKCRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIC1ndCAxODAwMDAp
>> "%B64FILE%" echo IHsgdHJ5IHsgU3RvcC1Qcm9jZXNzIC1JZCAkcC5JZCAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGlu
>> "%B64FILE%" echo dWUgfSBjYXRjaCB7fTsgYnJlYWsgfQ0KICAgICAgICB9DQogICAgICAgICR0ID0gJycNCiAgICAg
>> "%B64FILE%" echo ICAgdHJ5IHsgJHQgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRsb2csIFtUZXh0LkVuY29kaW5n
>> "%B64FILE%" echo XTo6RGVmYXVsdCkgfSBjYXRjaCB7fQ0KICAgICAgICAkZSA9ICcnDQogICAgICAgIHRyeSB7IGlm
>> "%B64FILE%" echo IChUZXN0LVBhdGggKCRsb2cgKyAnLmVycicpKSB7ICRlID0gW0lPLkZpbGVdOjpSZWFkQWxsVGV4
>> "%B64FILE%" echo dCgkbG9nICsgJy5lcnInLCBbVGV4dC5FbmNvZGluZ106OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0K
>> "%B64FILE%" echo ICAgICAgICAkbGVhZiA9IFNwbGl0LVBhdGggLUxlYWYgJGluZg0KICAgICAgICAjIFt2MS4zMl0g
>> "%B64FILE%" echo RW5nbGlzaCBwbnB1dGlsIHNheXMgIkRyaXZlciBwYWNrYWdlIGFkZGVkIHN1Y2Nlc3NmdWxseSIg
>> "%B64FILE%" echo KGFkZGVkIEJFRk9SRQ0KICAgICAgICAjIHN1Y2Nlc3NmdWxseSkgLSB0aGUgb2xkIHBhdHRlcm4g
>> "%B64FILE%" echo J3N1Y2Nlc3NmdWxseSBhZGRlZCcgbmV2ZXIgbWF0Y2hlZCwgc28gZXZlcnkNCiAgICAgICAgIyBp
>> "%B64FILE%" echo bnN0YWxsIHdhcyByZXBvcnRlZCBhcyAibm90IGFkZGVkIiBldmVuIHdoZW4gaXQgd29ya2VkLiBB
>> "%B64FILE%" echo bHNvIGZhbGwgYmFjayB0bw0KICAgICAgICAjIGNoZWNraW5nIHRoZSBkcml2ZXIgc3RvcmUsIHNv
>> "%B64FILE%" echo IGEgdmVyZGljdCBubyBsb25nZXIgZGVwZW5kcyBvbiBsb2NhbGl6ZWQgdGV4dC4NCiAgICAgICAg
>> "%B64FILE%" echo JG9rQWRkID0gKCR0IC1tYXRjaCAn5bey5oiQ5Yqf5re75YqgfOW3suaIkOWKn+WvvOWFpXxhZGRl
>> "%B64FILE%" echo ZCBzdWNjZXNzZnVsbHl8c3VjY2Vzc2Z1bGx5IGFkZGVkJykNCiAgICAgICAgaWYgKC1ub3QgJG9r
>> "%B64FILE%" echo QWRkKSB7DQogICAgICAgICAgICB0cnkgeyAkZW51bVR4dCA9ICgmIHBucHV0aWwuZXhlIC9lbnVt
>> "%B64FILE%" echo LWRyaXZlcnMgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2ggeyAkZW51bVR4dCA9ICcnIH0NCiAg
>> "%B64FILE%" echo ICAgICAgICAgIGlmICgkZW51bVR4dCAtYW5kICRlbnVtVHh0LkluZGV4T2YoJGxlYWYsIFtTdHJp
>> "%B64FILE%" echo bmdDb21wYXJpc29uXTo6T3JkaW5hbElnbm9yZUNhc2UpIC1nZSAwKSB7ICRva0FkZCA9ICR0cnVl
>> "%B64FILE%" echo IH0NCiAgICAgICAgfQ0KICAgICAgICBpZiAoJG9rQWRkKSB7IFNheSAoIiAgICAgIHswfSA9PiBh
>> "%B64FILE%" echo ZGRlZCIgLWYgJGxlYWYpICdHcmVlbicgfSBlbHNlIHsgU2F5ICgiICAgICAgezB9ID0+IG5vdCBh
>> "%B64FILE%" echo ZGRlZCIgLWYgJGxlYWYpICdZZWxsb3cnIH0NCiAgICAgICAgQWRkLUxpbmUgKCItLS0gezB9IiAt
>> "%B64FILE%" echo ZiAkaW5mKQ0KICAgICAgICBBZGQtTGluZSAoIiAgICByZXN1bHQ6ICIgKyAkKGlmICgkb2tBZGQp
>> "%B64FILE%" echo IHsgJ2FkZGVkJyB9IGVsc2UgeyAnbm90IGFkZGVkJyB9KSkNCiAgICAgICAgZm9yZWFjaCAoJGwg
>> "%B64FILE%" echo aW4gQCgkdCAtc3BsaXQgIltgcmBuXSsiIHwgV2hlcmUtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBT
>> "%B64FILE%" echo ZWxlY3QtT2JqZWN0IC1MYXN0IDYpKSB7IEFkZC1MaW5lICgiICAgICIgKyAkbCkgfQ0KICAgICAg
>> "%B64FILE%" echo ICBpZiAoJGUuVHJpbSgpKSB7IGZvcmVhY2ggKCRsIGluIEAoJGUgLXNwbGl0ICJbYHJgbl0rIiB8
>> "%B64FILE%" echo IFdoZXJlLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgU2VsZWN0LU9iamVjdCAtTGFzdCA0KSkgeyBB
>> "%B64FILE%" echo ZGQtTGluZSAoIiAgICBbZXJyXSAiICsgJGwpIH0gfQ0KICAgIH0NCn0NCg0KIyAtLS0tLS0tLS0t
>> "%B64FILE%" echo IFJlLWNoZWNrIC0tLS0tLS0tLS0NClNheSAiWzQvNF0gUmUtY2hlY2tpbmcgLi4uIiAnV2hpdGUn
>> "%B64FILE%" echo DQpTdGFydC1TbGVlcCAtU2Vjb25kcyA1DQp0cnkgeyAmIHBucHV0aWwgL3NjYW4tZGV2aWNlcyAy
>> "%B64FILE%" echo PiYxIHwgT3V0LU51bGwgfSBjYXRjaCB7fQ0KU3RhcnQtU2xlZXAgLVNlY29uZHMgNQ0KJGFmdGVy
>> "%B64FILE%" echo ID0gQChHZXQtUmVhbFByb2JsZW1zKQ0KQWRkLUxpbmUgIiINCkFkZC1MaW5lICItLS0tLS0tLS0t
>> "%B64FILE%" echo IFN0aWxsIGZhdWx0eSBhZnRlciBpbnN0YWxsYXRpb24gLS0tLS0tLS0tLSINCkFkZC1MaW5lICgi
>> "%B64FILE%" echo ezB9IGluIHRvdGFsIiAtZiAkYWZ0ZXIuQ291bnQpDQpmb3JlYWNoICgkZCBpbiAkYWZ0ZXIpIHsN
>> "%B64FILE%" echo CiAgICBBZGQtTGluZSAoIlt7MH1dIHsxfSAgIHByb2JsZW0gY29kZSB7Mn0iIC1mICRkLlN0YXR1
>> "%B64FILE%" echo cywgJGQuRnJpZW5kbHlOYW1lLCAkZC5Qcm9ibGVtKQ0KICAgIEFkZC1MaW5lICgiICAgIGluc3Rh
>> "%B64FILE%" echo bmNlIElEOiB7MH0iIC1mICRkLkluc3RhbmNlSWQpDQp9DQoNCiRuZXRBbGwgPSBAKEdldC1OZXRB
>> "%B64FILE%" echo ZGFwdGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQ0KJG5ldFVwID0gQCgkbmV0QWxs
>> "%B64FILE%" echo IHwgV2hlcmUtT2JqZWN0IHsgJF8uU3RhdHVzIC1lcSAnVXAnIH0pDQpBZGQtTGluZSAiIg0KQWRk
>> "%B64FILE%" echo LUxpbmUgIi0tLS0tLS0tLS0gTmV0d29yayBhZGFwdGVycyAtLS0tLS0tLS0tIg0KZm9yZWFjaCAo
>> "%B64FILE%" echo JGEgaW4gJG5ldEFsbCkgeyBBZGQtTGluZSAoInswfSB8IHsxfSB8IHsyfSIgLWYgJGEuTmFtZSwg
>> "%B64FILE%" echo JGEuSW50ZXJmYWNlRGVzY3JpcHRpb24sICRhLlN0YXR1cykgfQ0KQWRkLUxpbmUgKCJhZGFwdGVy
>> "%B64FILE%" echo cyB3aXRoIHN0YXR1cyBVcDogezB9IiAtZiAkbmV0VXAuQ291bnQpDQpBZGQtTGluZSAiIg0KQWRk
>> "%B64FILE%" echo LUxpbmUgIj09PT09PT09PT09PT09PT09PT09IERpYWdub3N0aWNzIGZpbmlzaGVkID09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09Ig0KDQojIC0tLS0tLS0tLS0gV3JpdGUgdGhlIHJlcG9ydCAtLS0tLS0tLS0t
>> "%B64FILE%" echo DQojIFt2MS4yOV0gVGhlIHJlcG9ydCBpcyBubyBsb25nZXIgZHJvcHBlZCBpbiB0aGUgZHJpdmUg
>> "%B64FILE%" echo cm9vdDsgZXZlcnl0aGluZyBnb2VzIHRvIDxkcml2ZT46XDxQcm9kdWN0TmFtZT4tbG9nc1wNCiMg
>> "%B64FILE%" echo KHByZXZpb3VzbHkgZXZlcnkgZHJpdmUgcm9vdCBnYWluZWQgYSAibmV3LXN5c3RlbS1yZXBvcnQu
>> "%B64FILE%" echo dHh0IiwgYW5kIGEgZmV3IGluc3RhbGxzIG1hZGUgYSBtZXNzKQ0KJHNhdmVkID0gQCgpDQpmb3Jl
>> "%B64FILE%" echo YWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7
>> "%B64FILE%" echo DQogICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgIGlmICgkdi5E
>> "%B64FILE%" echo cml2ZVR5cGUgLW5lICdGaXhlZCcpIHsgY29udGludWUgfQ0KICAgICRkaXIgPSAiezB9OlxWaXJ0
>> "%B64FILE%" echo dWFsIEhhcmQgRGlzayBTeXN0ZW0tbG9ncyIgLWYgJHYuRHJpdmVMZXR0ZXINCiAgICB0cnkgew0K
>> "%B64FILE%" echo ICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZGlyKSkgew0KICAgICAg
>> "%B64FILE%" echo ICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkZGlyIC1Gb3JjZSAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU3RvcCB8IE91dC1OdWxsDQogICAgICAgIH0NCiAgICAgICAgJG91dEZpbGUgPSBK
>> "%B64FILE%" echo b2luLVBhdGggJGRpciAnbmV3LXN5c3RlbS1yZXBvcnQudHh0Jw0KICAgICAgICAkcmVwb3J0IC1q
>> "%B64FILE%" echo b2luICJgcmBuIiB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkb3V0RmlsZSAtRW5jb2Rpbmcg
>> "%B64FILE%" echo VVRGOCAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICAkc2F2ZWQgKz0gJG91dEZpbGUNCiAgICB9
>> "%B64FILE%" echo IGNhdGNoIHt9DQp9DQoNClNheSAiIg0KU2F5ICgiICBnZW51aW5lIGZhdWx0czogezB9IGJlZm9y
>> "%B64FILE%" echo ZSAtPiB7MX0gYWZ0ZXIiIC1mICRwcm9ibGVtcy5Db3VudCwgJGFmdGVyLkNvdW50KSAnQ3lhbicN
>> "%B64FILE%" echo ClNheSAoIiAgYWRhcHRlcnMgVXA6IHswfSIgLWYgJG5ldFVwLkNvdW50KSAnQ3lhbicNCmlmICgk
>> "%B64FILE%" echo c2F2ZWQuQ291bnQgLWd0IDApIHsNCiAgICBTYXkgIiAgUmVwb3J0IHdyaXR0ZW4gdG86IiAnR3Jl
>> "%B64FILE%" echo ZW4nDQogICAgZm9yZWFjaCAoJHMgaW4gJHNhdmVkKSB7IFNheSAoIiAgICAgICIgKyAkcykgJ0dy
>> "%B64FILE%" echo ZWVuJyB9DQp9DQpTYXkgIiINClJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=12993"
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
