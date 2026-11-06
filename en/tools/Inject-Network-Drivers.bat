@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Inject Network Drivers
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
set "PS1FILE=%WORKDIR%\Inject-Network-Drivers.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oDQogICAgW3N0cmluZ10kT3JpZ2luRGlyID0gJycNCikNCg0KIyA9PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMgSW5q
>> "%B64FILE%" echo ZWN0IE5ldHdvcmsgRHJpdmVycyAgdjEuMg0KIyBBdXRob3I6IGNvbm5lY3RzZWdhYm90DQojDQoj
>> "%B64FILE%" echo IFB1cnBvc2U6IGFuIGluc3RhbGxlZCB2aXJ0dWFsIHN5c3RlbSBoYXMgbm8gbmV0d29yayAodGhl
>> "%B64FILE%" echo IGFkYXB0ZXIgc2hvd3MgYW4gZXhjbGFtYXRpb24gbWFyayBpbiBEZXZpY2UgTWFuYWdlciwNCiMg
>> "%B64FILE%" echo ICBvciB0aGUgbmV0d29yayBpY29uIGhhcyBhIHJlZCBjcm9zcykuIFRoaXMgdG9vbCBpbmplY3Rz
>> "%B64FILE%" echo ICJ0aGUgbmV0d29yayBkcml2ZXIgdGhpcyBtYWNoaW5lIGlzIGN1cnJlbnRseSB1c2luZyIgaW50
>> "%B64FILE%" echo byB0aGF0IHN5c3RlbS4NCiMNCiMgVGhlIGRyaXZlciBpcyB0YWtlbiBmcm9tIHRoaXMgbWFjaGlu
>> "%B64FILE%" echo ZSwgc28gdGhlIGhhcmR3YXJlIElEcyBtYXRjaCBieSBkZWZpbml0aW9uOyBvbmNlIGluamVjdGVk
>> "%B64FILE%" echo IHRoZSBuZXR3b3JrIHdvcmtzLg0KIyBPbmx5IHRoZSBkcml2ZXIgc3RvcmUgb2YgdGhlIHRhcmdl
>> "%B64FILE%" echo dCBzeXN0ZW0gaXMgdG91Y2hlZCwgbmV2ZXIgaXRzIHN5c3RlbSBmaWxlcyBvciBib290IGNvbmZp
>> "%B64FILE%" echo Z3VyYXRpb24uDQojDQojIHYxLjEgZml4ICgyMDI2LTExLTA0KToNCiMgICB2MS4wIGhhZCBhIGZh
>> "%B64FILE%" echo dGFsIGZsYXcgaW4gdGFyZ2V0IGRldGVjdGlvbiAtIGl0IG9ubHkgbG9va2VkIGZvciAiYSB2b2x1
>> "%B64FILE%" echo bWUgY29udGFpbmluZyBudG9za3JubC5leGUiLA0KIyAgIGFuZCB0aGUgcnVubmluZyBDOiBpdHNl
>> "%B64FILE%" echo bGYgY29udGFpbnMgYSBrZXJuZWwsIHNvIHdpdGggbm8gdmlydHVhbCBkaXNrIG1vdW50ZWQgQzog
>> "%B64FILE%" echo d2FzIHRoZSBvbmx5IGNhbmRpZGF0ZSwNCiMgICBhbmQgdGhlIHNjcmlwdCBoYXBwaWx5IGluamVj
>> "%B64FILE%" echo dGVkIGludG8gQzouIERJU00gdGhlbiByZXBvcnRlZDoNCiMgICAgICAgRXJyb3I6IDg3ICBUaGUg
>> "%B64FILE%" echo L0ltYWdlIG9wdGlvbiB0aGF0IGlzIHNwZWNpZmllZCBwb2ludHMgdG8gYQ0KIyAgICAgICBydW5u
>> "%B64FILE%" echo aW5nIFdpbmRvd3MgaW5zdGFsbGF0aW9uLg0KIyAgIChESVNNIHJlZnVzZWQsIHNvIG5vdGhpbmcg
>> "%B64FILE%" echo d2FzIHdyaXR0ZW4gYW5kIHRoZSBleGlzdGluZyBzeXN0ZW0gd2FzIG5vdCBtb2RpZmllZC4pDQoj
>> "%B64FILE%" echo ICAgU2luY2UgdjEuMTogZXhjbHVkZSB0aGUgcnVubmluZyBzeXN0ZW0gZHJpdmUsIHByZWZlciBh
>> "%B64FILE%" echo IHZpcnR1YWwgZGlzaywgYW5kIG1vdW50IGl0IGF1dG9tYXRpY2FsbHkgd2hlbiBuZWVkZWQuDQoj
>> "%B64FILE%" echo DQojIHYxLjIgZml4ICgyMDI2LTExLTA1KToNCiMgICB2MS4xIG9ubHkgZXhwb3J0ZWQgdGhpcmQt
>> "%B64FILE%" echo cGFydHkgb2VtKi5pbmYgcGFja2FnZXMgZnJvbSBwbnB1dGlsIC9lbnVtLWRyaXZlcnMuIE5ldHdv
>> "%B64FILE%" echo cmsgYWRhcHRlcnMgb24gcGh5c2ljYWwNCiMgICBtYWNoaW5lcyB1c3VhbGx5IHJlbHkgb24gaW4t
>> "%B64FILE%" echo Ym94IGRyaXZlcnMgdGhhdCBuZXZlciBhcHBlYXIgaW4gdGhlIG9lbSBsaXN0IC0+IG5vdGhpbmcg
>> "%B64FILE%" echo d2FzIGV4cG9ydGVkLCB0aGUgaW5qZWN0aW9uDQojICAgc3RlcCByZXBvcnRlZCAibm8gbmV0d29y
>> "%B64FILE%" echo ayBkcml2ZXIgdG8gZXhwb3J0IiBhbmQgZXhpdGVkLCB3aGljaCBsb29rcyBsaWtlICJ0aGlzIHRv
>> "%B64FILE%" echo b2wgZG9lcyBub3RoaW5nIi4NCiMgICAoSXQgYWx3YXlzIHdvcmtlZCBpbiBhIFZNIGJlY2F1c2Ug
>> "%B64FILE%" echo dGhlIHZpcnR1YWwgTklDIGRyaXZlciB0aGVyZSBoYXBwZW5zIHRvIGJlIGFuIG9lbSBwYWNrYWdl
>> "%B64FILE%" echo LikNCiMgICBTaW5jZSB2MS4yOiBhZGRpdGlvbmFsbHkgZW51bWVyYXRlIHRoZSByZWFsIFBDSS9V
>> "%B64FILE%" echo U0IgbmV0d29yayBhZGFwdGVycywgdGFrZSB0aGUgSU5GIHRoZXkgYWN0dWFsbHkgdXNlLA0KIyAg
>> "%B64FILE%" echo IGNvcHkgaW4tYm94IHBhY2thZ2VzIHdob2xlIGZyb20gRHJpdmVyU3RvcmVcRmlsZVJlcG9zaXRv
>> "%B64FILE%" echo cnkgYW5kIGluamVjdCB0aG9zZSBhcyB3ZWxsLg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KJEVycm9yQWN0aW9uUHJlZmVy
>> "%B64FILE%" echo ZW5jZSA9ICdDb250aW51ZScNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjM0Jw0KJFNjcmlwdDpPcmln
>> "%B64FILE%" echo aW5EaXIgPSAkT3JpZ2luRGlyDQp0cnkgeyAkSG9zdC5VSS5SYXdVSS5XaW5kb3dUaXRsZSA9ICJJ
>> "%B64FILE%" echo bmplY3QgTmV0d29yayBEcml2ZXJzIHYkKCRTY3JpcHQ6VmVyc2lvbikgLSBjb25uZWN0c2VnYWJv
>> "%B64FILE%" echo dCIgfSBjYXRjaCB7fQ0KDQojIFt2MS4zMl0gU2hhcmVkIG1vZHVsZS4gc3JjL2J1aWxkL2lubGlu
>> "%B64FILE%" echo ZV9zaGFyZWQucHkgaW5saW5lcyB0aGlzIGZpbGUgYXQNCiMgYnVpbGQgdGltZSwgYW5kIHRoZSAu
>> "%B64FILE%" echo YmF0IHBheWxvYWQgaXMgc3RpbGwgYSBzZWxmLWNvbnRhaW5lZCBzaW5nbGUgZmlsZS4NCiMgPT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo DQojIFNoYXJlZCBsb2dnaW5nIGhlbHBlcnMgICB2MS4zMg0KIw0KIyBUaGlzIGZpbGUgaXMgTk9U
>> "%B64FILE%" echo IHdoYXQgZ2V0cyBzaGlwcGVkLiBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSBpbmxpbmVzIGl0
>> "%B64FILE%" echo cw0KIyBjb250ZW50IGludG8gZXZlcnkgZW50cnkgc2NyaXB0IHdoaWxlIHRoZSAuYmF0IHBheWxv
>> "%B64FILE%" echo YWRzIGFyZSBidWlsdCwgc28gdGhlDQojIHJlbGVhc2VkIGxhdW5jaGVycyBzdGF5IHNlbGYtY29u
>> "%B64FILE%" echo dGFpbmVkIHNpbmdsZSBmaWxlcyAodGhlIHNlbGYtZXh0cmFjdGluZyBiYXQNCiMgaGFzIG5vIHdh
>> "%B64FILE%" echo eSB0byByZWZlcmVuY2UgYW4gZXh0ZXJuYWwgbW9kdWxlIGF0IHJ1biB0aW1lKS4NCiMNCiMgUnVs
>> "%B64FILE%" echo ZTogZWRpdCBoZXJlLCBuZXZlciBjb3B5LXBhc3RlIHRoZXNlIGZ1bmN0aW9ucyBiYWNrIGludG8g
>> "%B64FILE%" echo YW4gZW50cnkgc2NyaXB0Lg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT0NCg0KZnVuY3Rpb24gU2F5IHsNCiAgICBwYXJhbShbc3Ry
>> "%B64FILE%" echo aW5nXSRUZXh0LCBbc3RyaW5nXSRDb2xvciA9ICdHcmF5JykNCiAgICBXcml0ZS1Ib3N0ICRUZXh0
>> "%B64FILE%" echo IC1Gb3JlZ3JvdW5kQ29sb3IgJENvbG9yDQp9DQoNClNheSAiIg0KU2F5ICIgIEluamVjdCBOZXR3
>> "%B64FILE%" echo b3JrIERyaXZlcnMgIHYkKCRTY3JpcHQ6VmVyc2lvbikiICdDeWFuJw0KU2F5ICIgIEF1dGhvcjog
>> "%B64FILE%" echo Y29ubmVjdHNlZ2Fib3QiICdEYXJrR3JheScNClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNClNheSAi
>> "%B64FILE%" echo Ig0KDQokYWRtaW4gPSAoW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzUHJpbmNpcGFsXVtTZWN1
>> "%B64FILE%" echo cml0eS5QcmluY2lwYWwuV2luZG93c0lkZW50aXR5XTo6R2V0Q3VycmVudCgpKS5Jc0luUm9sZShb
>> "%B64FILE%" echo U2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpDQpp
>> "%B64FILE%" echo ZiAoLW5vdCAkYWRtaW4pIHsNCiAgICBTYXkgIiAgW0VSUk9SXSBBZG1pbmlzdHJhdG9yIHJpZ2h0
>> "%B64FILE%" echo cyBhcmUgcmVxdWlyZWQuIENsb3NlIHRoaXMgd2luZG93LCByaWdodC1jbGljayB0aGlzIGZpbGUg
>> "%B64FILE%" echo LT4gUnVuIGFzIGFkbWluaXN0cmF0b3IuIiAnUmVkJw0KICAgIFNheSAiIg0KICAgIFJlYWQtSG9z
>> "%B64FILE%" echo dCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0KICAgIGV4aXQgMQ0KfQ0KDQojIC0tLS0tLS0tLS0g
>> "%B64FILE%" echo SWRlbnRpZnkgInRoZSBzeXN0ZW0gcnVubmluZyByaWdodCBub3ciLCB3aGljaCBtdXN0IGJlIGV4
>> "%B64FILE%" echo Y2x1ZGVkIC0tLS0tLS0tLS0NCiRzeXNMZXR0ZXIgPSAoW3N0cmluZ10kZW52OlN5c3RlbURyaXZl
>> "%B64FILE%" echo KS5UcmltRW5kKCc6JykuVG9VcHBlcigpDQokc3lzVm9sSWQgPSAnJw0KdHJ5IHsgJHN5c1ZvbElk
>> "%B64FILE%" echo ID0gW3N0cmluZ10oR2V0LVZvbHVtZSAtRHJpdmVMZXR0ZXIgJHN5c0xldHRlciAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU3RvcCkuVW5pcXVlSWQgfSBjYXRjaCB7fQ0KDQpmdW5jdGlvbiBUZXN0LUlzUnVubmluZ1N5
>> "%B64FILE%" echo c3RlbSB7DQogICAgcGFyYW0oJFZvbCkNCiAgICBpZiAoKFtzdHJpbmddJFZvbC5Ecml2ZUxldHRl
>> "%B64FILE%" echo cikuVG9VcHBlcigpIC1lcSAkc3lzTGV0dGVyKSB7IHJldHVybiAkdHJ1ZSB9DQogICAgIyBUaGUg
>> "%B64FILE%" echo c2FtZSB2b2x1bWUgbW91bnRlZCB1bmRlciBhbm90aGVyIGRyaXZlIGxldHRlciBoYXMgdGhlIHNh
>> "%B64FILE%" echo bWUgVW5pcXVlSWQsIHNvIGV4Y2x1ZGUgaXQgdG9vLA0KICAgICMgb3RoZXJ3aXNlIERJU00gYWxz
>> "%B64FILE%" echo byByZXBvcnRzIEVycm9yIDg3Lg0KICAgIGlmICgkc3lzVm9sSWQgLWFuZCAoW3N0cmluZ10kVm9s
>> "%B64FILE%" echo LlVuaXF1ZUlkIC1lcSAkc3lzVm9sSWQpKSB7IHJldHVybiAkdHJ1ZSB9DQogICAgcmV0dXJuICRm
>> "%B64FILE%" echo YWxzZQ0KfQ0KDQojIC0tLS0tLS0tLS0gQ2FuZGlkYXRlIHZvbHVtZXMgLS0tLS0tLS0tLQ0KZnVu
>> "%B64FILE%" echo Y3Rpb24gR2V0LVRhcmdldENhbmRpZGF0ZXMgew0KICAgICRsaXN0ID0gQCgpDQoNCiAgICAkdmhk
>> "%B64FILE%" echo RGlza3MgPSBAe30NCiAgICBmb3JlYWNoICgkZCBpbiBAKEdldC1EaXNrIC1FcnJvckFjdGlvbiBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoW3N0cmluZ10kZC5CdXNUeXBlIC1lcSAn
>> "%B64FILE%" echo RmlsZSBCYWNrZWQgVmlydHVhbCcpIHsgJHZoZERpc2tzW1tpbnRdJGQuTnVtYmVyXSA9ICR0cnVl
>> "%B64FILE%" echo IH0NCiAgICB9DQoNCiAgICBmb3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9u
>> "%B64FILE%" echo IFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7
>> "%B64FILE%" echo IGNvbnRpbnVlIH0NCiAgICAgICAgJHJvb3QgPSAiezB9OlwiIC1mICR2LkRyaXZlTGV0dGVyDQog
>> "%B64FILE%" echo ICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICgkcm9vdCArICdXaW5kb3dz
>> "%B64FILE%" echo XFN5c3RlbTMyXG50b3Nrcm5sLmV4ZScpKSkgeyBjb250aW51ZSB9DQoNCiAgICAgICAgJGRpc2tO
>> "%B64FILE%" echo dW0gPSAtMQ0KICAgICAgICB0cnkgeyAkZGlza051bSA9IFtpbnRdKEdldC1QYXJ0aXRpb24gLURy
>> "%B64FILE%" echo aXZlTGV0dGVyICR2LkRyaXZlTGV0dGVyIC1FcnJvckFjdGlvbiBTdG9wKS5EaXNrTnVtYmVyIH0g
>> "%B64FILE%" echo Y2F0Y2gge30NCg0KICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIExldHRlciAgPSBbc3RyaW5nXSR2LkRyaXZlTGV0dGVyDQogICAgICAgICAgICBMYWJlbCAg
>> "%B64FILE%" echo ID0gW3N0cmluZ10kdi5GaWxlU3lzdGVtTGFiZWwNCiAgICAgICAgICAgIFJ1bm5pbmcgPSAoVGVz
>> "%B64FILE%" echo dC1Jc1J1bm5pbmdTeXN0ZW0gJHYpDQogICAgICAgICAgICBJc1ZoZCAgID0gKCRkaXNrTnVtIC1n
>> "%B64FILE%" echo ZSAwIC1hbmQgJHZoZERpc2tzLkNvbnRhaW5zS2V5KCRkaXNrTnVtKSkNCiAgICAgICAgICAgIERp
>> "%B64FILE%" echo c2sgICAgPSAkZGlza051bQ0KICAgICAgICAgICAgU2l6ZUdCICA9IFttYXRoXTo6Um91bmQoJHYu
>> "%B64FILE%" echo U2l6ZSAvIDFHQiwgMSkNCiAgICAgICAgfQ0KICAgIH0NCiAgICByZXR1cm4gJGxpc3QNCn0NCg0K
>> "%B64FILE%" echo IyAtLS0tLS0tLS0tIEZpbmQgYSBtb3VudGFibGUgdmhkeCAtLS0tLS0tLS0tDQpmdW5jdGlvbiBG
>> "%B64FILE%" echo aW5kLVZoZHhGaWxlcyB7DQogICAgJGZvdW5kID0gQCgpDQogICAgaWYgKCRTY3JpcHQ6T3JpZ2lu
>> "%B64FILE%" echo RGlyIC1hbmQgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJFNjcmlwdDpPcmlnaW5EaXIpKSB7DQog
>> "%B64FILE%" echo ICAgICAgICRjID0gSm9pbi1QYXRoICRTY3JpcHQ6T3JpZ2luRGlyICdOZXdTeXN0ZW1EaXNrLnZo
>> "%B64FILE%" echo ZHgnDQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjKSB7ICRmb3VuZCArPSAk
>> "%B64FILE%" echo YyB9DQogICAgfQ0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24g
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7IGNvbnRp
>> "%B64FILE%" echo bnVlIH0NCiAgICAgICAgJGMgPSAiezB9OlxOZXdTeXN0ZW1EaXNrLnZoZHgiIC1mICR2LkRyaXZl
>> "%B64FILE%" echo TGV0dGVyDQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjKSB7DQogICAgICAg
>> "%B64FILE%" echo ICAgICAkZnVsbCA9IChHZXQtSXRlbSAtTGl0ZXJhbFBhdGggJGMpLkZ1bGxOYW1lDQogICAgICAg
>> "%B64FILE%" echo ICAgICBpZiAoJGZvdW5kIC1ub3Rjb250YWlucyAkZnVsbCkgeyAkZm91bmQgKz0gJGZ1bGwgfQ0K
>> "%B64FILE%" echo ICAgICAgICB9DQogICAgfQ0KICAgIHJldHVybiAkZm91bmQNCn0NCg0KZnVuY3Rpb24gTW91bnQt
>> "%B64FILE%" echo VmhkeCB7DQogICAgcGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkZHBGaWxlID0gSm9pbi1QYXRo
>> "%B64FILE%" echo ICRlbnY6VEVNUCAoImF0dGFjaF92aGRfezB9LnR4dCIgLWYgJFBJRCkNCiAgICBAKA0KICAgICAg
>> "%B64FILE%" echo ICAic2VsZWN0IHZkaXNrIGZpbGU9YCIkUGF0aGAiIiwNCiAgICAgICAgJ2F0dGFjaCB2ZGlzaycs
>> "%B64FILE%" echo DQogICAgICAgICdleGl0Jw0KICAgICkgfCBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGRwRmls
>> "%B64FILE%" echo ZSAtRW5jb2RpbmcgRGVmYXVsdA0KICAgICRyID0gJycNCiAgICB0cnkgeyAkciA9ICgmIGRpc2tw
>> "%B64FILE%" echo YXJ0IC9zICRkcEZpbGUgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2ggeyAkciA9ICRfLkV4Y2Vw
>> "%B64FILE%" echo dGlvbi5NZXNzYWdlIH0NCiAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRwRmlsZSAtRm9y
>> "%B64FILE%" echo Y2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUNCiAgICBpZiAoJHIgLW1hdGNoICdzdWNj
>> "%B64FILE%" echo ZXNzZnVsbHl85oiQ5YqfJykgeyByZXR1cm4gJHRydWUgfQ0KICAgIFNheSAoIiAgICAgIG1vdW50
>> "%B64FILE%" echo IHJldHVybmVkOiAiICsgKCgkciAtcmVwbGFjZSAiXHMrIiwgJyAnKS5UcmltKCkpKSAnWWVsbG93
>> "%B64FILE%" echo Jw0KICAgIHJldHVybiAkZmFsc2UNCn0NCg0KZnVuY3Rpb24gRGlzbW91bnQtVmhkeCB7DQogICAg
>> "%B64FILE%" echo cGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkZHBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAo
>> "%B64FILE%" echo ImRldGFjaF92aGRfezB9LnR4dCIgLWYgJFBJRCkNCiAgICBAKA0KICAgICAgICAic2VsZWN0IHZk
>> "%B64FILE%" echo aXNrIGZpbGU9YCIkUGF0aGAiIiwNCiAgICAgICAgJ2RldGFjaCB2ZGlzaycsDQogICAgICAgICdl
>> "%B64FILE%" echo eGl0Jw0KICAgICkgfCBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGRwRmlsZSAtRW5jb2Rpbmcg
>> "%B64FILE%" echo RGVmYXVsdA0KICAgIHRyeSB7ICYgZGlza3BhcnQgL3MgJGRwRmlsZSAyPiYxIHwgT3V0LU51bGwg
>> "%B64FILE%" echo fSBjYXRjaCB7fQ0KICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1Gb3JjZSAt
>> "%B64FILE%" echo RXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0KfQ0KDQojIC0tLS0tLS0tLS0gWzEvNF0gTG9j
>> "%B64FILE%" echo YXRlIHRoZSB0YXJnZXQgc3lzdGVtIC0tLS0tLS0tLS0NClNheSAiWzEvNF0gTG9jYXRpbmcgdGhl
>> "%B64FILE%" echo IHRhcmdldCBzeXN0ZW0gLi4uIiAnV2hpdGUnDQoNCiRhdHRhY2hlZFZoZHggPSAnJw0KJHRhcmdl
>> "%B64FILE%" echo dHMgPSBAKEdldC1UYXJnZXRDYW5kaWRhdGVzKQ0KJHVzYWJsZSA9IEAoJHRhcmdldHMgfCBXaGVy
>> "%B64FILE%" echo ZS1PYmplY3QgeyAtbm90ICRfLlJ1bm5pbmcgfSkNCg0KIyBQcmVmZXIgYSBzeXN0ZW0gaW5zaWRl
>> "%B64FILE%" echo IGEgdmlydHVhbCBkaXNrICh0aGUgbm9ybWFsIGNhc2UgZm9yIHRoaXMgdG9vbCkNCiR2aGRUYXJn
>> "%B64FILE%" echo ZXRzID0gQCgkdXNhYmxlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSXNWaGQgfSkNCg0KaWYgKCR2aGRU
>> "%B64FILE%" echo YXJnZXRzLkNvdW50IC1lcSAwKSB7DQogICAgJHZoZHhGaWxlcyA9IEAoRmluZC1WaGR4RmlsZXMp
>> "%B64FILE%" echo DQogICAgaWYgKCR2aGR4RmlsZXMuQ291bnQgLWd0IDApIHsNCiAgICAgICAgZm9yZWFjaCAoJGYg
>> "%B64FILE%" echo aW4gJHZoZHhGaWxlcykgew0KICAgICAgICAgICAgU2F5ICgiICAgICAgZm91bmQgdmlydHVhbCBk
>> "%B64FILE%" echo aXNrIHswfSwgbW91bnRpbmcgLi4uIiAtZiAkZikgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgaWYg
>> "%B64FILE%" echo KE1vdW50LVZoZHggLVBhdGggJGYpIHsNCiAgICAgICAgICAgICAgICAkYXR0YWNoZWRWaGR4ID0g
>> "%B64FILE%" echo JGYNCiAgICAgICAgICAgICAgICBTYXkgIiAgICAgIG1vdW50ZWQiICdHcmVlbicNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICBicmVhaw0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQogICAgICAgIGlmICgkYXR0
>> "%B64FILE%" echo YWNoZWRWaGR4KSB7DQogICAgICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAyDQogICAgICAg
>> "%B64FILE%" echo ICAgICAkdGFyZ2V0cyA9IEAoR2V0LVRhcmdldENhbmRpZGF0ZXMpDQogICAgICAgICAgICAkdXNh
>> "%B64FILE%" echo YmxlID0gQCgkdGFyZ2V0cyB8IFdoZXJlLU9iamVjdCB7IC1ub3QgJF8uUnVubmluZyB9KQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgJHZoZFRhcmdldHMgPSBAKCR1c2FibGUgfCBXaGVyZS1PYmplY3QgeyAkXy5Jc1Zo
>> "%B64FILE%" echo ZCB9KQ0KICAgICAgICB9DQogICAgfQ0KfQ0KDQppZiAoJHZoZFRhcmdldHMuQ291bnQgLWVxIDEp
>> "%B64FILE%" echo IHsNCiAgICAkdGFyZ2V0ID0gJHZoZFRhcmdldHNbMF0NCiAgICBTYXkgKCIgICAgICB0YXJnZXQ6
>> "%B64FILE%" echo IHswfTogIChzeXN0ZW0gaW5zaWRlIGEgdmlydHVhbCBkaXNrLCB7MX0gR0IpIiAtZiAkdGFyZ2V0
>> "%B64FILE%" echo LkxldHRlciwgJHRhcmdldC5TaXplR0IpICdHcmVlbicNCn0NCmVsc2VpZiAoJHVzYWJsZS5Db3Vu
>> "%B64FILE%" echo dCAtZXEgMCkgew0KICAgIFNheSAiIg0KICAgIFNheSAiICBbRVJST1JdIE5vIGluamVjdGFibGUg
>> "%B64FILE%" echo c3lzdGVtIGZvdW5kLiIgJ1JlZCcNCiAgICBTYXkgKCIgICAgICAgICBUaGUgcnVubmluZyBzeXN0
>> "%B64FILE%" echo ZW0gaXMgezB9OiBhbmQgY2Fubm90IGJlIHRoZSB0YXJnZXQgKERJU00gZm9yYmlkcyBpdCkuIiAt
>> "%B64FILE%" echo ZiAkc3lzTGV0dGVyKSAnWWVsbG93Jw0KICAgIFNheSAiICAgICAgICAgQW5kIG5vIG1vdW50ZWQg
>> "%B64FILE%" echo b3IgbW91bnRhYmxlIE5ld1N5c3RlbURpc2sudmhkeCB3YXMgZm91bmQuIiAnWWVsbG93Jw0KICAg
>> "%B64FILE%" echo IFNheSAiICAgICAgICAgQ2hlY2sgd2hpY2ggdmhkeCBmaWxlIGhvbGRzIHRoZSB2aXJ0dWFsIHN5
>> "%B64FILE%" echo c3RlbSBhbmQgd2hldGhlciBpdCBpcyBuYW1lZCBOZXdTeXN0ZW1EaXNrLnZoZHguIiAnWWVsbG93
>> "%B64FILE%" echo Jw0KICAgIFNheSAiIg0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERpc21vdW50LVZoZHggLVBh
>> "%B64FILE%" echo dGggJGF0dGFjaGVkVmhkeCB9DQogICAgUmVhZC1Ib3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQi
>> "%B64FILE%" echo DQogICAgZXhpdCAxDQp9DQplbHNlIHsNCiAgICBTYXkgIiAgICAgIFNldmVyYWwgaW5qZWN0YWJs
>> "%B64FILE%" echo ZSBzeXN0ZW1zIGZvdW5kLCBjaG9vc2Ugb25lOiIgJ1doaXRlJw0KICAgIGZvciAoJGkgPSAwOyAk
>> "%B64FILE%" echo aSAtbHQgJHVzYWJsZS5Db3VudDsgJGkrKykgew0KICAgICAgICAkdCA9ICR1c2FibGVbJGldDQog
>> "%B64FILE%" echo ICAgICAgICRraW5kID0gaWYgKCR0LklzVmhkKSB7ICd2aXJ0dWFsIGRpc2snIH0gZWxzZSB7ICdw
>> "%B64FILE%" echo aHlzaWNhbCBwYXJ0aXRpb24nIH0NCiAgICAgICAgU2F5ICgiICAgICAgW3swfV0gezF9OiAgezJ9
>> "%B64FILE%" echo ICB7M30gR0IgIGxhYmVsPXs0fSIgLWYgKCRpICsgMSksICR0LkxldHRlciwgJGtpbmQsICR0LlNp
>> "%B64FILE%" echo emVHQiwgJHQuTGFiZWwpDQogICAgfQ0KICAgICRzZWwgPSBSZWFkLUhvc3QgIiAgICAgIEVudGVy
>> "%B64FILE%" echo IGEgbnVtYmVyIChkZWZhdWx0IDEpIg0KICAgICRpZHggPSAxDQogICAgW2ludF06OlRyeVBhcnNl
>> "%B64FILE%" echo KCRzZWwsIFtyZWZdJGlkeCkgfCBPdXQtTnVsbA0KICAgIGlmICgkaWR4IC1sdCAxIC1vciAkaWR4
>> "%B64FILE%" echo IC1ndCAkdXNhYmxlLkNvdW50KSB7ICRpZHggPSAxIH0NCiAgICAkdGFyZ2V0ID0gJHVzYWJsZVsk
>> "%B64FILE%" echo aWR4IC0gMV0NCiAgICBTYXkgKCIgICAgICB0YXJnZXQ6IHswfToiIC1mICR0YXJnZXQuTGV0dGVy
>> "%B64FILE%" echo KSAnR3JlZW4nDQp9DQoNCiMgRG91YmxlIHNhZmV0eTogbmV2ZXIgd3JpdGUgaW50byB0aGUgcnVu
>> "%B64FILE%" echo bmluZyBzeXN0ZW0NCmlmICgkdGFyZ2V0LlJ1bm5pbmcpIHsNCiAgICBTYXkgIiINCiAgICBTYXkg
>> "%B64FILE%" echo IiAgW0VSUk9SXSBUaGUgc2VsZWN0ZWQgdm9sdW1lIGlzIHRoZSBydW5uaW5nIHN5c3RlbSwgd2hp
>> "%B64FILE%" echo Y2ggRElTTSBmb3JiaWRzIChFcnJvciA4NykuIEFib3J0ZWQuIiAnUmVkJw0KICAgIFNheSAiIg0K
>> "%B64FILE%" echo ICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERpc21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhk
>> "%B64FILE%" echo eCB9DQogICAgUmVhZC1Ib3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQiDQogICAgZXhpdCAxDQp9
>> "%B64FILE%" echo DQoNCiMgLS0tLS0tLS0tLSBbMi80XSBFeHBvcnQgdGhpcyBtYWNoaW5lJ3MgbmV0d29yayBkcml2
>> "%B64FILE%" echo ZXJzIC0tLS0tLS0tLS0NClNheSAiWzIvNF0gRXhwb3J0aW5nIG5ldHdvcmsgZHJpdmVycyBmcm9t
>> "%B64FILE%" echo IHRoaXMgbWFjaGluZSAuLi4iICdXaGl0ZScNCiRuZXRDbGFzc0d1aWQgPSAnNGQzNmU5NzItZTMy
>> "%B64FILE%" echo NS0xMWNlLWJmYzEtMDgwMDJiZTEwMzE4JyAgICMgbmV0d29yayBhZGFwdGVycyAobGFuZ3VhZ2Ug
>> "%B64FILE%" echo aW5kZXBlbmRlbnQpDQokZHJ2RGlyID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImluamVjdG5ldF97
>> "%B64FILE%" echo MH0iIC1mICRQSUQpDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZHJ2RGlyKSB7
>> "%B64FILE%" echo IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JB
>> "%B64FILE%" echo Y3Rpb24gU2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30NCk5ldy1JdGVtIC1JdGVtVHlwZSBE
>> "%B64FILE%" echo aXJlY3RvcnkgLVBhdGggJGRydkRpciAtRm9yY2UgfCBPdXQtTnVsbA0KDQokZW51bVRleHQgPSAn
>> "%B64FILE%" echo Jw0KdHJ5IHsgJGVudW1UZXh0ID0gKCYgcG5wdXRpbCAvZW51bS1kcml2ZXJzIDI+JjEgfCBPdXQt
>> "%B64FILE%" echo U3RyaW5nKSB9IGNhdGNoIHt9DQokbmV0T2VtcyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rp
>> "%B64FILE%" echo b25zLkFycmF5TGlzdA0KZm9yZWFjaCAoJGJsayBpbiAoJGVudW1UZXh0IC1zcGxpdCAiKD86XHI/
>> "%B64FILE%" echo XG4pezIsfSIpKSB7DQogICAgaWYgKCRibGsgLW5vdG1hdGNoICRuZXRDbGFzc0d1aWQpIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICRtID0gW3JlZ2V4XTo6TWF0Y2goJGJsaywgJyg/aSlcYihvZW1cZCtcLmlu
>> "%B64FILE%" echo ZilcYicpDQogICAgaWYgKC1ub3QgJG0uU3VjY2VzcykgeyBjb250aW51ZSB9DQogICAgJG5tID0g
>> "%B64FILE%" echo JG0uR3JvdXBzWzFdLlZhbHVlLlRvTG93ZXIoKQ0KICAgIGlmICgtbm90ICRuZXRPZW1zLkNvbnRh
>> "%B64FILE%" echo aW5zKCRubSkpIHsgW3ZvaWRdJG5ldE9lbXMuQWRkKCRubSkgfQ0KfQ0KU2F5ICgiICAgICAgdGhp
>> "%B64FILE%" echo cmQtcGFydHkgbmV0d29yayBkcml2ZXIgcGFja2FnZXMgb24gdGhpcyBtYWNoaW5lOiB7MH0iIC1m
>> "%B64FILE%" echo ICRuZXRPZW1zLkNvdW50KSAnRGFya0dyYXknDQpmb3JlYWNoICgkb2VtIGluICRuZXRPZW1zKSB7
>> "%B64FILE%" echo DQogICAgJGVyID0gKCYgcG5wdXRpbCAvZXhwb3J0LWRyaXZlciAkb2VtICRkcnZEaXIgMj4mMSB8
>> "%B64FILE%" echo IE91dC1TdHJpbmcpDQogICAgaWYgKCRlciAtbWF0Y2ggJ3N1Y2Nlc3NmdWxseXxzdWNjZWVkZWQn
>> "%B64FILE%" echo KSB7IFNheSAoIiAgICAgIFtva10gezB9IiAtZiAkb2VtKSAnRGFya0dyYXknIH0NCiAgICBlbHNl
>> "%B64FILE%" echo IHsgU2F5ICgiICAgICAgWyEhXSB7MH0gIHsxfSIgLWYgJG9lbSwgKCgkZXIgLXJlcGxhY2UgIlxz
>> "%B64FILE%" echo KyIsICcgJykuVHJpbSgpKSkgJ1llbGxvdycgfQ0KfQ0KDQojIFt2MS4yXSBwbnB1dGlsIC9lbnVt
>> "%B64FILE%" echo LWRyaXZlcnMgbGlzdHMgb25seSB0aGlyZC1wYXJ0eSBvZW0qLmluZiBmaWxlcywgbWlzc2luZyBp
>> "%B64FILE%" echo bi1ib3ggbmV0d29yaw0KIyBkcml2ZXJzOiBwaHlzaWNhbCBtYWNoaW5lcyB1c3VhbGx5IHVzZSB0
>> "%B64FILE%" echo aGUgb25lcyBzaGlwcGVkIHdpdGggV2luZG93cyAobm90IGluIHRoZSBvZW0gbGlzdCksIHNvIG5v
>> "%B64FILE%" echo dGhpbmcgd2FzDQojIGV4cG9ydGVkIGFib3ZlIGFuZCB0aGUgdGFyZ2V0IHN5c3RlbSBzdGlsbCBo
>> "%B64FILE%" echo YWQgbm8gbmV0d29yayAtIHdoaWNoIGxvb2tzIGxpa2UgInRoaXMgdG9vbCBkb2VzIG5vdGhpbmci
>> "%B64FILE%" echo LiBTbyB0aGUgSU5GDQojIGN1cnJlbnRseSB1c2VkIGJ5ICJ0aGUgcGh5c2ljYWwgYWRhcHRlcnMg
>> "%B64FILE%" echo dGhhdCByZWFsbHkgZXhpc3QiIGlzIGV4cG9ydGVkIGFzIHdlbGw6IHRoaXJkLXBhcnR5IG9lbSBv
>> "%B64FILE%" echo bmVzIGFyZSBhbHJlYWR5DQojIGRvbmUgKHNraXBwZWQpLCBpbi1ib3ggb25lcyBhcmUgY29waWVk
>> "%B64FILE%" echo IHdob2xlIGZyb20gRHJpdmVyU3RvcmVcRmlsZVJlcG9zaXRvcnkuDQpTYXkgIiAgICAgIEV4cG9y
>> "%B64FILE%" echo dGluZyB0aGUgZHJpdmVycyB1c2VkIGJ5IHRoZSBwaHlzaWNhbCBhZGFwdGVycyAoaW5jbHVkaW5n
>> "%B64FILE%" echo IGluLWJveCkuLi4iICdEYXJrR3JheScNCnRyeSB7DQogICAgJHBoeXNOZXRzID0gQChHZXQtUG5w
>> "%B64FILE%" echo RGV2aWNlIC1DbGFzcyBOZXQgLVByZXNlbnRPbmx5IC1FQSBTaWxlbnRseUNvbnRpbnVlIHwNCiAg
>> "%B64FILE%" echo ICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uSW5zdGFuY2VJZCAtbWF0Y2ggJ14oUENJfFVTQiknIH0p
>> "%B64FILE%" echo DQogICAgZm9yZWFjaCAoJGRldiBpbiAkcGh5c05ldHMpIHsNCiAgICAgICAgdHJ5IHsNCiAgICAg
>> "%B64FILE%" echo ICAgICAgICRkcnZJbmYgPSAnJw0KICAgICAgICAgICAgdHJ5IHsgJGRydkluZiA9IFtzdHJpbmdd
>> "%B64FILE%" echo KEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZGV2Lkluc3RhbmNlSWQgLUtleU5h
>> "%B64FILE%" echo bWUgJ0RFVlBLRVlfRGV2aWNlX0RyaXZlckluZlBhdGgnIC1FQSBTdG9wKS5EYXRhIH0gY2F0Y2gg
>> "%B64FILE%" echo e30NCiAgICAgICAgICAgIGlmICgtbm90ICRkcnZJbmYpIHsgY29udGludWUgfQ0KICAgICAgICAg
>> "%B64FILE%" echo ICAgJGRydkluZiA9ICRkcnZJbmYuVG9Mb3dlcigpDQogICAgICAgICAgICBTYXkgKCIgICAgICBh
>> "%B64FILE%" echo ZGFwdGVyIHswfSBpcyB1c2luZyB7MX0iIC1mICRkZXYuRnJpZW5kbHlOYW1lLCAkZHJ2SW5mKSAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgICAgICBpZiAoJGRydkluZiAtbWF0Y2ggJ15vZW1cZCtcLmluZiQn
>> "%B64FILE%" echo KSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgICMgVGhlIEZpbGVSZXBvc2l0b3J5IHBhY2thZ2Ug
>> "%B64FILE%" echo Zm9sZGVyIGlzIG5hbWVkIDxpbmYgZmlsZSBuYW1lPl88YXJjaGl0ZWN0dXJlPl88aGFzaD4sIGZv
>> "%B64FILE%" echo ciBleGFtcGxlDQogICAgICAgICAgICAjIHJ0NjQweDY0LmluZl9hbWQ2NF9jYmY0ZTIzOTgxYzNj
>> "%B64FILE%" echo OGEzLiBJdCBtdXN0IGJlIG1hdGNoZWQgd2l0aCB0aGUgZnVsbCBmaWxlIG5hbWUgaW5jbHVkaW5n
>> "%B64FILE%" echo IC5pbmY7DQogICAgICAgICAgICAjIGFuIGVhcmxpZXIgdmVyc2lvbiB1c2VkIHRoZSBuYW1lIHdp
>> "%B64FILE%" echo dGhvdXQgdGhlIGV4dGVuc2lvbiAocnQ2NDB4NjRfKiksIHdoaWNoIG5ldmVyIG1hdGNoZXMsIHNv
>> "%B64FILE%" echo IG5vdCBhIHNpbmdsZQ0KICAgICAgICAgICAgIyBpbi1ib3ggZHJpdmVyIHdhcyBjb3BpZWQgLSB0
>> "%B64FILE%" echo aGUgc3ltcHRvbSBiZWluZyAiaW5qZWN0ZWQsIGJ1dCB0aGUgYWRhcHRlciBzdGlsbCBoYXMgbm8g
>> "%B64FILE%" echo ZHJpdmVyIi4NCiAgICAgICAgICAgICRmclJvb3QgPSAiJGVudjpTeXN0ZW1Sb290XFN5c3RlbTMy
>> "%B64FILE%" echo XERyaXZlclN0b3JlXEZpbGVSZXBvc2l0b3J5Ig0KICAgICAgICAgICAgJHBrZ0RpcnMgPSBAKEdl
>> "%B64FILE%" echo dC1DaGlsZEl0ZW0gJGZyUm9vdCAtRGlyZWN0b3J5IC1GaWx0ZXIgKCRkcnZJbmYgKyAnXyonKSAt
>> "%B64FILE%" echo RUEgU2lsZW50bHlDb250aW51ZSkNCiAgICAgICAgICAgIGlmICgkcGtnRGlycy5Db3VudCAtZXEg
>> "%B64FILE%" echo MCkgew0KICAgICAgICAgICAgICAgICRwa2dEaXJzID0gQChHZXQtQ2hpbGRJdGVtICRmclJvb3Qg
>> "%B64FILE%" echo LURpcmVjdG9yeSAtRUEgU2lsZW50bHlDb250aW51ZSB8DQogICAgICAgICAgICAgICAgICAgIFdo
>> "%B64FILE%" echo ZXJlLU9iamVjdCB7ICRfLk5hbWUuVG9Mb3dlcigpLlN0YXJ0c1dpdGgoJGRydkluZiArICdfJykg
>> "%B64FILE%" echo fSkNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGlmICgkcGtnRGlycy5Db3VudCAtZXEgMCkg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgICAgIFNheSAoIiAgTm8gZHJpdmVyIHBhY2thZ2UgZm9sZGVyIGZvdW5k
>> "%B64FILE%" echo IGZvciB7MH0gKHRoZSBkcml2ZXIgbmFtZSBtYXkgZGlmZmVyIGZyb20gdGhlIGZvbGRlciBuYW1l
>> "%B64FILE%" echo KSIgLWYgJGRydkluZikgJ1llbGxvdycNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGZvcmVh
>> "%B64FILE%" echo Y2ggKCRwZCBpbiAkcGtnRGlycykgew0KICAgICAgICAgICAgICAgIENvcHktSXRlbSAtTGl0ZXJh
>> "%B64FILE%" echo bFBhdGggJHBkLkZ1bGxOYW1lIC1EZXN0aW5hdGlvbiAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAt
>> "%B64FILE%" echo RUEgU2lsZW50bHlDb250aW51ZQ0KICAgICAgICAgICAgICAgIFNheSAoIiAgQ29waWVkIHRoZSBp
>> "%B64FILE%" echo bi1ib3ggbmV0d29yayBkcml2ZXIgcGFja2FnZTogIiArICRwZC5OYW1lKSAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgICAgICAgICB9DQogICAgICAgIH0gY2F0Y2ggeyBTYXkgKCIgICAgICBbISFdIGluLWJveCBk
>> "%B64FILE%" echo cml2ZXIgZXhwb3J0IGZhaWxlZDogezB9IiAtZiAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1llbGxv
>> "%B64FILE%" echo dycgfQ0KICAgIH0NCn0gY2F0Y2ggeyBTYXkgKCIgICAgICBbISFdIGluLWJveCBkcml2ZXIgZXhw
>> "%B64FILE%" echo b3J0IHRocmV3OiB7MH0iIC1mICRfLkV4Y2VwdGlvbi5NZXNzYWdlKSAnWWVsbG93JyB9DQoNCiRp
>> "%B64FILE%" echo bmZGaWxlcyA9IEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJGRydkRpciAtUmVjdXJzZSAt
>> "%B64FILE%" echo RmlsdGVyICouaW5mIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQ0KaWYgKCRpbmZGaWxl
>> "%B64FILE%" echo cy5Db3VudCAtZXEgMCkgew0KICAgIFNheSAiIg0KICAgIFNheSAiICBObyBuZXR3b3JrIGRyaXZl
>> "%B64FILE%" echo ciBhdmFpbGFibGUgdG8gZXhwb3J0IChuZWl0aGVyIHRoaXJkLXBhcnR5IG5vciBpbi1ib3gpLiIg
>> "%B64FILE%" echo J1llbGxvdycNCiAgICBTYXkgIiAgVGhpcyB1c3VhbGx5IG1lYW5zIHRoZSBkcml2ZXIgaXMgbm90
>> "%B64FILE%" echo IG1pc3NpbmcuIFJ1biBEaWFnbm9zZS1BbmQtSW5zdGFsbC1Ecml2ZXJzIGluc2lkZSB0aGUgdGFy
>> "%B64FILE%" echo Z2V0IHN5c3RlbSB0byBzZWUgdGhlIHJlYWwgZXJyb3IuIiAnWWVsbG93Jw0KICAgIFNheSAiIg0K
>> "%B64FILE%" echo ICAgIHRyeSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3Jj
>> "%B64FILE%" echo ZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9DQogICAgaWYgKCRhdHRhY2hlZFZoZHgp
>> "%B64FILE%" echo IHsgRGlzbW91bnQtVmhkeCAtUGF0aCAkYXR0YWNoZWRWaGR4IH0NCiAgICBSZWFkLUhvc3QgIiAg
>> "%B64FILE%" echo UHJlc3MgRW50ZXIgdG8gZXhpdCINCiAgICBleGl0IDENCn0NCiRtYiA9IDANCnRyeSB7ICRtYiA9
>> "%B64FILE%" echo IFttYXRoXTo6Um91bmQoKChHZXQtQ2hpbGRJdGVtICRkcnZEaXIgLVJlY3Vyc2UgLUZpbGUgfCBN
>> "%B64FILE%" echo ZWFzdXJlLU9iamVjdCBMZW5ndGggLVN1bSkuU3VtKSAvIDFNQiwgMSkgfSBjYXRjaCB7fQ0KU2F5
>> "%B64FILE%" echo ICgiICAgICAgZXhwb3J0IGNvbXBsZXRlOiB7MH0gSU5GIGZpbGVzLCB7MX0gTUIiIC1mICRpbmZG
>> "%B64FILE%" echo aWxlcy5Db3VudCwgJG1iKSAnR3JlZW4nDQoNCiMgLS0tLS0tLS0tLSBbMy80XSBJbmplY3QgLS0t
>> "%B64FILE%" echo LS0tLS0tLQ0KU2F5ICJbMy80XSBJbmplY3RpbmcgaW50byB0aGUgdGFyZ2V0IHN5c3RlbSAobWF5
>> "%B64FILE%" echo IHRha2UgYSBtaW51dGUgb3IgdHdvKS4uLiIgJ1doaXRlJw0KJGxvZ0ZpbGUgPSBKb2luLVBhdGgg
>> "%B64FILE%" echo JGVudjpURU1QICgiaW5qZWN0bmV0X3swfS5sb2ciIC1mICRQSUQpDQokZXJyRmlsZSA9ICRsb2dG
>> "%B64FILE%" echo aWxlICsgJy5lcnInDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbG9nRmlsZSkg
>> "%B64FILE%" echo eyBSZW1vdmUtSXRlbSAkbG9nRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUgfSB9IGNh
>> "%B64FILE%" echo dGNoIHt9DQoNCiMgRG8gbm90IHF1b3RlIHRoZSB2YWx1ZSBhZnRlciAvSW1hZ2U6IHdyaXRpbmcg
>> "%B64FILE%" echo Ii9JbWFnZTpFOlwiIG1ha2VzIHRoZSB0cmFpbGluZyBcIiBhbiBlc2NhcGVkIHF1b3RlLA0KIyB0
>> "%B64FILE%" echo aGUgYXJndW1lbnQgYmVjb21lcyBJbWFnZTpFOiIgYW5kIGZhaWxzLiBBIGRyaXZlIHBhdGggY29u
>> "%B64FILE%" echo dGFpbnMgbm8gc3BhY2VzLCBzbyBubyBxdW90ZXMgaXMgdGhlIHNhZmVzdCBmb3JtLg0KJGRpc21B
>> "%B64FILE%" echo cmdzID0gJy9FbmdsaXNoIC9JbWFnZTp7MH06XCAvQWRkLURyaXZlciAvRHJpdmVyOiJ7MX0iIC9S
>> "%B64FILE%" echo ZWN1cnNlJyAtZiAkdGFyZ2V0LkxldHRlciwgJGRydkRpcg0KU2F5ICgiICAgICAgZGlzbSB7MH0i
>> "%B64FILE%" echo IC1mICRkaXNtQXJncykgJ0RhcmtHcmF5Jw0KDQokcHJvYyA9IFN0YXJ0LVByb2Nlc3MgLUZpbGVQ
>> "%B64FILE%" echo YXRoICdkaXNtLmV4ZScgLUFyZ3VtZW50TGlzdCAkZGlzbUFyZ3MgYA0KICAgICAgICAgICAgLVJl
>> "%B64FILE%" echo ZGlyZWN0U3RhbmRhcmRPdXRwdXQgJGxvZ0ZpbGUgLVJlZGlyZWN0U3RhbmRhcmRFcnJvciAkZXJy
>> "%B64FILE%" echo RmlsZSBgDQogICAgICAgICAgICAtTm9OZXdXaW5kb3cgLVBhc3NUaHJ1IC1FcnJvckFjdGlvbiBT
>> "%B64FILE%" echo dG9wDQoNCiRzdyA9IFtTeXN0ZW0uRGlhZ25vc3RpY3MuU3RvcHdhdGNoXTo6U3RhcnROZXcoKQ0K
>> "%B64FILE%" echo JGxhc3RCZWF0ID0gMA0Kd2hpbGUgKC1ub3QgJHByb2MuSGFzRXhpdGVkKSB7DQogICAgU3RhcnQt
>> "%B64FILE%" echo U2xlZXAgLU1pbGxpc2Vjb25kcyA3MDANCiAgICBpZiAoKCRzdy5FbGFwc2VkTWlsbGlzZWNvbmRz
>> "%B64FILE%" echo IC0gJGxhc3RCZWF0KSAtZ2UgMzAwMCkgew0KICAgICAgICAkbGFzdEJlYXQgPSAkc3cuRWxhcHNl
>> "%B64FILE%" echo ZE1pbGxpc2Vjb25kcw0KICAgICAgICBTYXkgKCIgICAgICB7MH0gc2Vjb25kcyBlbGFwc2VkLi4u
>> "%B64FILE%" echo IiAtZiBbaW50XSRzdy5FbGFwc2VkLlRvdGFsU2Vjb25kcykgJ0RhcmtHcmF5Jw0KICAgIH0NCiAg
>> "%B64FILE%" echo ICBpZiAoJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgLWd0IDkwMDAwMCkgew0KICAgICAgICB0cnkg
>> "%B64FILE%" echo eyBTdG9wLVByb2Nlc3MgLUlkICRwcm9jLklkIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9
>> "%B64FILE%" echo IGNhdGNoIHt9DQogICAgICAgIFNheSAiICAgICAgT3ZlciAxNSBtaW51dGVzLCBnaXZpbmcgdXAi
>> "%B64FILE%" echo ICdSZWQnDQogICAgICAgIGJyZWFrDQogICAgfQ0KfQ0KdHJ5IHsgJHByb2MuV2FpdEZvckV4aXQo
>> "%B64FILE%" echo KSB9IGNhdGNoIHt9DQoNCiMgLS0tLS0tLS0tLSBbNC80XSBSZXN1bHQgLS0tLS0tLS0tLQ0KU2F5
>> "%B64FILE%" echo ICIiDQokdHh0ID0gJycNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRsb2dGaWxl
>> "%B64FILE%" echo KSB7ICR0eHQgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRsb2dGaWxlLCBbVGV4dC5FbmNvZGlu
>> "%B64FILE%" echo Z106OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0KJGVyclR4dCA9ICcnDQp0cnkgeyBpZiAoVGVzdC1Q
>> "%B64FILE%" echo YXRoIC1MaXRlcmFsUGF0aCAkZXJyRmlsZSkgeyAkZXJyVHh0ID0gW0lPLkZpbGVdOjpSZWFkQWxs
>> "%B64FILE%" echo VGV4dCgkZXJyRmlsZSwgW1RleHQuRW5jb2RpbmddOjpEZWZhdWx0KSB9IH0gY2F0Y2gge30NCg0K
>> "%B64FILE%" echo U2F5ICJbNC80XSBSZXN1bHQ6IiAnV2hpdGUnDQokaW5zdGFsbGVkID0gQChbcmVnZXhdOjpNYXRj
>> "%B64FILE%" echo aGVzKCR0eHQsICcoP2kpZHJpdmVyIHBhY2thZ2UgKD86d2FzICk/KD86c3VjY2Vzc2Z1bGx5ICk/
>> "%B64FILE%" echo aW5zdGFsbGVkfOmpseWKqOWMhS4qP+W3suaIkOWKn+WuieijhScpKS5Db3VudA0KZm9yZWFjaCAo
>> "%B64FILE%" echo JGwgaW4gQCgkdHh0IC1zcGxpdCAiW2ByYG5dKyIgfCBXaGVyZS1PYmplY3QgeyAkXy5UcmltKCkg
>> "%B64FILE%" echo fSB8IFNlbGVjdC1PYmplY3QgLUxhc3QgMTApKSB7IFNheSAoIiAgICAgICIgKyAkbCkgJ0RhcmtH
>> "%B64FILE%" echo cmF5JyB9DQppZiAoJGVyclR4dC5UcmltKCkpIHsNCiAgICBTYXkgIiAgICAgIC0tLSBzdGRlcnIg
>> "%B64FILE%" echo LS0tIiAnRGFya0dyYXknDQogICAgZm9yZWFjaCAoJGwgaW4gQCgkZXJyVHh0IC1zcGxpdCAiW2By
>> "%B64FILE%" echo YG5dKyIgfCBXaGVyZS1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFNlbGVjdC1PYmplY3QgLUxhc3Qg
>> "%B64FILE%" echo NikpIHsgU2F5ICgiICAgICAgIiArICRsKSAnWWVsbG93JyB9DQp9DQoNClNheSAiIg0KaWYgKCR0
>> "%B64FILE%" echo eHQgLW1hdGNoICdjb21wbGV0ZWQgc3VjY2Vzc2Z1bGx5fOaTjeS9nOaIkOWKn+WujOaIkCcpIHsN
>> "%B64FILE%" echo CiAgICBpZiAoJGluc3RhbGxlZCAtZ3QgMCkgeyBTYXkgKCIgIEluamVjdGlvbiBjb21wbGV0ZSwg
>> "%B64FILE%" echo ezB9IGRyaXZlciBwYWNrYWdlcyBpbnN0YWxsZWQgaW50byB7MX06IC4iIC1mICRpbnN0YWxsZWQs
>> "%B64FILE%" echo ICR0YXJnZXQuTGV0dGVyKSAnR3JlZW4nIH0NCiAgICBlbHNlIHsgU2F5ICgiICBJbmplY3Rpb24g
>> "%B64FILE%" echo Y29tcGxldGUgKERJU00gcmVwb3J0ZWQgbm8gbmV3IGRyaXZlciBwYWNrYWdlOyB0aGUgdGFyZ2V0
>> "%B64FILE%" echo IG1heSBhbHJlYWR5IGhhdmUgdGhlbSkuIikgJ0dyZWVuJyB9DQogICAgU2F5ICgiICBBZnRlciBy
>> "%B64FILE%" echo ZWJvb3RpbmcgaW50byB0aGUgbmV3IHN5c3RlbSB0aGUgYWRhcHRlciBzaG91bGQgYmUgcmVjb2du
>> "%B64FILE%" echo aXNlZC4gTG9nOiB7MH0iIC1mICRsb2dGaWxlKSAnR3JheScNCn0NCmVsc2VpZiAoJHR4dCAtbWF0
>> "%B64FILE%" echo Y2ggJzg3JyAtb3IgJGVyclR4dCAtbWF0Y2ggJ3J1bm5pbmcgV2luZG93cyBpbnN0YWxsYXRpb258
>> "%B64FILE%" echo 5q2j5Zyo6L+Q6KGM55qEJykgew0KICAgIFNheSAiICBGYWlsZWQ6IERJU00gY29uc2lkZXJzIHRo
>> "%B64FILE%" echo ZSB0YXJnZXQgYSBydW5uaW5nIFdpbmRvd3MgaW5zdGFsbGF0aW9uIChFcnJvciA4NykuIiAnUmVk
>> "%B64FILE%" echo Jw0KICAgIFNheSAiICBUaGF0IG1lYW5zIHRoZSBsb2NhdGVkIHZvbHVtZSBpcyBub3QgdGhlIHZp
>> "%B64FILE%" echo cnR1YWwgc3lzdGVtOyBwb2ludCBUYXJnZXREaXIgYXQgdGhlIGZvbGRlciBob2xkaW5nIHRoZSB2
>> "%B64FILE%" echo aGR4IGFuZCByZXRyeS4iICdZZWxsb3cnDQp9DQplbHNlIHsNCiAgICBTYXkgIiAgSW5qZWN0aW9u
>> "%B64FILE%" echo IHJlc3VsdCB1bmNlcnRhaW4sIHNlZSB0aGUgb3V0cHV0IGFib3ZlLiIgJ1llbGxvdycNCiAgICBT
>> "%B64FILE%" echo YXkgKCIgIEZ1bGwgbG9nOiB7MH0iIC1mICRsb2dGaWxlKSAnR3JheScNCiAgICBTYXkgIiAgSWYg
>> "%B64FILE%" echo aXQgc2F5cyB0aGUgZHJpdmVyIGlzIG5vdCBjb21wYXRpYmxlIHdpdGggdGhlIGltYWdlLCB0aGUg
>> "%B64FILE%" echo bG9jYWwgZHJpdmVyIHJlcXVpcmVzIGEgbmV3ZXIgV2luZG93cyB2ZXJzaW9uOyIgJ0dyYXknDQog
>> "%B64FILE%" echo ICAgU2F5ICIgIGRvd25sb2FkIHRoZSBXaW4xMCBidWlsZCBmcm9tIHRoZSB2ZW5kb3IgYW5kIGlu
>> "%B64FILE%" echo c3RhbGwgaXQgbWFudWFsbHkgaW5zaWRlIHRoZSB0YXJnZXQgc3lzdGVtLiIgJ0dyYXknDQp9DQoN
>> "%B64FILE%" echo CiMgLS0tLS0tLS0tLSBXcmFwLXVwIC0tLS0tLS0tLS0NCnRyeSB7IGlmIChUZXN0LVBhdGggLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRkcnZEaXIpIHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcnZEaXIgLVJl
>> "%B64FILE%" echo Y3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQ0KaWYgKCRhdHRh
>> "%B64FILE%" echo Y2hlZFZoZHgpIHsNCiAgICBTYXkgIiINCiAgICBTYXkgKCIgIERpc21vdW50aW5nIHRoZSB0ZW1w
>> "%B64FILE%" echo b3JhcmlseSBtb3VudGVkIHZpcnR1YWwgZGlzazogezB9IiAtZiAkYXR0YWNoZWRWaGR4KSAnRGFy
>> "%B64FILE%" echo a0dyYXknDQogICAgRGlzbW91bnQtVmhkeCAtUGF0aCAkYXR0YWNoZWRWaGR4DQogICAgU2F5ICIg
>> "%B64FILE%" echo IERpc21vdW50ZWQgKGl0IHdpbGwgbm90IGxpbmdlciBpbiBUaGlzIFBDKSIgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo fQ0KU2F5ICIiDQpSZWFkLUhvc3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=18571"
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
