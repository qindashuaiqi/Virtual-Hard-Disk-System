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
>> "%B64FILE%" echo J0NvbnRpbnVlJw0KJFNjcmlwdDpWZXJzaW9uID0gJzEuMzEnDQp0cnkgeyAkSG9zdC5VSS5SYXdV
>> "%B64FILE%" echo SS5XaW5kb3dUaXRsZSA9ICJOZXcgU3lzdGVtIERpYWdub3NlIGFuZCBJbnN0YWxsIERyaXZlcnMg
>> "%B64FILE%" echo diQoJFNjcmlwdDpWZXJzaW9uKSAtIGNvbm5lY3RzZWdhYm90IiB9IGNhdGNoIHt9DQoNCmZ1bmN0
>> "%B64FILE%" echo aW9uIFNheSB7DQogICAgcGFyYW0oW3N0cmluZ10kVGV4dCwgW3N0cmluZ10kQ29sb3IgPSAnR3Jh
>> "%B64FILE%" echo eScpDQogICAgV3JpdGUtSG9zdCAkVGV4dCAtRm9yZWdyb3VuZENvbG9yICRDb2xvcg0KfQ0KDQpT
>> "%B64FILE%" echo YXkgIiINClNheSAiICBOZXcgU3lzdGVtIERpYWdub3NlIGFuZCBJbnN0YWxsIERyaXZlcnMgIHYk
>> "%B64FILE%" echo KCRTY3JpcHQ6VmVyc2lvbikiICdDeWFuJw0KU2F5ICIgIEF1dGhvcjogY29ubmVjdHNlZ2Fib3Qi
>> "%B64FILE%" echo ICdEYXJrR3JheScNClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNClNheSAiIg0KDQokYWRtaW4gPSAo
>> "%B64FILE%" echo W1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzUHJpbmNpcGFsXVtTZWN1cml0eS5QcmluY2lwYWwu
>> "%B64FILE%" echo V2luZG93c0lkZW50aXR5XTo6R2V0Q3VycmVudCgpKS5Jc0luUm9sZShbU2VjdXJpdHkuUHJpbmNp
>> "%B64FILE%" echo cGFsLldpbmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpDQppZiAoLW5vdCAkYWRtaW4p
>> "%B64FILE%" echo IHsNCiAgICBTYXkgIiAgW0VSUk9SXSBBZG1pbmlzdHJhdG9yIHJpZ2h0cyBhcmUgcmVxdWlyZWQu
>> "%B64FILE%" echo IFJpZ2h0LWNsaWNrIC0+IFJ1biBhcyBhZG1pbmlzdHJhdG9yLiIgJ1JlZCcNCiAgICBSZWFkLUhv
>> "%B64FILE%" echo c3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCiAgICBleGl0IDENCn0NCg0KJHJlcG9ydCA9IE5l
>> "%B64FILE%" echo dy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KZnVuY3Rpb24gQWRkLUxpbmUg
>> "%B64FILE%" echo eyBwYXJhbShbc3RyaW5nXSRUID0gJycpIFt2b2lkXSRyZXBvcnQuQWRkKCRUKSB9DQoNCiRvcyA9
>> "%B64FILE%" echo IEdldC1DaW1JbnN0YW5jZSBXaW4zMl9PcGVyYXRpbmdTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVu
>> "%B64FILE%" echo dGx5Q29udGludWUNCkFkZC1MaW5lICI9PT09PT09PT09PT09PT09PT09PSBOZXcgc3lzdGVtIGRp
>> "%B64FILE%" echo YWdub3N0aWNzIHYkKCRTY3JpcHQ6VmVyc2lvbikgPT09PT09PT09PT09PT09PT09PT0iDQpBZGQt
>> "%B64FILE%" echo TGluZSAoIkNvbXB1dGVyICAgICA6ICIgKyAkZW52OkNPTVBVVEVSTkFNRSkNCkFkZC1MaW5lICgi
>> "%B64FILE%" echo U3lzdGVtICAgICAgIDogIiArICRvcy5DYXB0aW9uICsgIiAgQnVpbGQgIiArICRvcy5CdWlsZE51
>> "%B64FILE%" echo bWJlcikNCkFkZC1MaW5lICgiQm9vdCB0aW1lICAgIDogIiArICRvcy5MYXN0Qm9vdFVwVGltZSkN
>> "%B64FILE%" echo CkFkZC1MaW5lICgiVXB0aW1lICAgICAgIDogIiArIFtzdHJpbmddKFtkYXRldGltZV06Ok5vdyAt
>> "%B64FILE%" echo ICRvcy5MYXN0Qm9vdFVwVGltZSkpDQpBZGQtTGluZSAoIlN5c3RlbSBkcml2ZSA6ICIgKyAkZW52
>> "%B64FILE%" echo OlN5c3RlbURyaXZlKQ0KQWRkLUxpbmUgIiINCg0KIyAtLS0tLS0tLS0tIFJlYWwgZmF1bHRzIG9u
>> "%B64FILE%" echo bHksIG5vIHBoYW50b21zIC0tLS0tLS0tLS0NCiMgICAyMiA9IENNX1BST0JfRElTQUJMRUQgKGRp
>> "%B64FILE%" echo c2FibGVkLCB1c3VhbGx5IG9uIHB1cnBvc2UpDQojICAgNDUgPSBDTV9QUk9CX1BIQU5UT00gKGhp
>> "%B64FILE%" echo c3RvcmljYWwgcmVjb3JkLCBkZXZpY2Ugbm90IHByZXNlbnQpDQokaWdub3JlUHJvYmxlbSA9IEAo
>> "%B64FILE%" echo MCwgMjIsIDQ1KQ0KZnVuY3Rpb24gR2V0LVJlYWxQcm9ibGVtcyB7DQogICAgJGxpc3QgPSBAKCkN
>> "%B64FILE%" echo CiAgICAkc2VlbiA9IEB7fQ0KICAgIGZvcmVhY2ggKCRkIGluIEAoR2V0LVBucERldmljZSAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJGQpIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICAgICAkcCA9ICRkLlByb2JsZW0NCiAgICAgICAgaWYgKCRwIC1lcSAkbnVs
>> "%B64FILE%" echo bCkgeyAkcCA9IDAgfQ0KICAgICAgICBpZiAoJGlnbm9yZVByb2JsZW0gLWNvbnRhaW5zIFtpbnRd
>> "%B64FILE%" echo JHApIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJGQuU3RhdHVzIC1lcSAnVW5rbm93bicpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICBpZiAoJHNlZW4uQ29udGFpbnNLZXkoJGQuSW5zdGFuY2VJZCkp
>> "%B64FILE%" echo IHsgY29udGludWUgfQ0KICAgICAgICAkc2VlblskZC5JbnN0YW5jZUlkXSA9IDENCiAgICAgICAg
>> "%B64FILE%" echo JGxpc3QgKz0gJGQNCiAgICB9DQogICAgcmV0dXJuICRsaXN0DQp9DQoNClNheSAiWzEvNF0gQ29s
>> "%B64FILE%" echo bGVjdGluZyBnZW51aW5lbHkgZmF1bHR5IGRldmljZXMgKHBoYW50b21zIHNraXBwZWQpLi4uIiAn
>> "%B64FILE%" echo V2hpdGUnDQokcHJvYmxlbXMgPSBAKEdldC1SZWFsUHJvYmxlbXMpDQpBZGQtTGluZSAiLS0tLS0t
>> "%B64FILE%" echo LS0tLSBHZW51aW5lbHkgZmF1bHR5IGRldmljZXMgLS0tLS0tLS0tLSINCkFkZC1MaW5lICgiezB9
>> "%B64FILE%" echo IGluIHRvdGFsIiAtZiAkcHJvYmxlbXMuQ291bnQpDQpBZGQtTGluZSAiIg0KZm9yZWFjaCAoJGQg
>> "%B64FILE%" echo aW4gJHByb2JsZW1zKSB7DQogICAgJGh3ID0gQCgpDQogICAgdHJ5IHsgJGh3ID0gQCgoR2V0LVBu
>> "%B64FILE%" echo cERldmljZVByb3BlcnR5IC1JbnN0YW5jZUlkICRkLkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBL
>> "%B64FILE%" echo RVlfRGV2aWNlX0hhcmR3YXJlSWRzJyAtRXJyb3JBY3Rpb24gU3RvcCkuRGF0YSkgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KICAgIEFkZC1MaW5lICgiW3swfV0gezF9IiAtZiAkZC5TdGF0dXMsICRkLkZyaWVuZGx5TmFt
>> "%B64FILE%" echo ZSkNCiAgICBBZGQtTGluZSAoIiAgICBwcm9ibGVtIGNvZGU6IHswfSAgIGNsYXNzOiB7MX0iIC1m
>> "%B64FILE%" echo ICRkLlByb2JsZW0sICRkLkNsYXNzKQ0KICAgIEFkZC1MaW5lICgiICAgIGluc3RhbmNlIElEOiB7
>> "%B64FILE%" echo MH0iIC1mICRkLkluc3RhbmNlSWQpDQogICAgaWYgKCRody5Db3VudCAtZ3QgMCkgeyBBZGQtTGlu
>> "%B64FILE%" echo ZSAoIiAgICBoYXJkd2FyZSBJRDogIiArICgkaHcgLWpvaW4gJyA7ICcpKSB9DQogICAgQWRkLUxp
>> "%B64FILE%" echo bmUgIiINCn0NClNheSAoIiAgICAgIHswfSBnZW51aW5lIGZhdWx0cyIgLWYgJHByb2JsZW1zLkNv
>> "%B64FILE%" echo dW50KSAnRGFya0dyYXknDQoNCiMgLS0tLS0tLS0tLSBGaW5kIHRoZSBkcml2ZXIgZm9sZGVycyAt
>> "%B64FILE%" echo LS0tLS0tLS0tDQokZHJ2RGlycyA9IEAoKQ0KZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1F
>> "%B64FILE%" echo cnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgIGlmICgtbm90ICR2LkRyaXZlTGV0
>> "%B64FILE%" echo dGVyKSB7IGNvbnRpbnVlIH0NCiAgICBpZiAoKFtzdHJpbmddJHYuRHJpdmVMZXR0ZXIpLlRvVXBw
>> "%B64FILE%" echo ZXIoKSAtZXEgKChbc3RyaW5nXSRlbnY6U3lzdGVtRHJpdmUpLlRyaW1FbmQoJzonKS5Ub1VwcGVy
>> "%B64FILE%" echo KCkpKSB7IGNvbnRpbnVlIH0NCiAgICBmb3JlYWNoICgkbm0gaW4gQCgnTmV3U3lzdGVtRHJpdmVy
>> "%B64FILE%" echo JywgJ+aWsOezu+e7n+mpseWKqCcpKSB7DQogICAgICAgICRjID0gInswfTpcezF9IiAtZiAkdi5E
>> "%B64FILE%" echo cml2ZUxldHRlciwgJG5tDQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjKSB7
>> "%B64FILE%" echo ICRkcnZEaXJzICs9ICRjIH0NCiAgICB9DQp9DQpmb3JlYWNoICgkYyBpbiBAKCdDOlxOZXdTeXN0
>> "%B64FILE%" echo ZW1Ecml2ZXInLCAnQzpc5paw57O757uf6amx5YqoJykpIHsNCiAgICBpZiAoVGVzdC1QYXRoIC1M
>> "%B64FILE%" echo aXRlcmFsUGF0aCAkYykgeyAkZHJ2RGlycyArPSAkYyB9DQp9DQokZHJ2RGlycyA9IEAoJGRydkRp
>> "%B64FILE%" echo cnMgfCBTZWxlY3QtT2JqZWN0IC1VbmlxdWUpDQokYWxsSW5mID0gQCgpDQpmb3JlYWNoICgkZGQg
>> "%B64FILE%" echo aW4gJGRydkRpcnMpIHsgJGFsbEluZiArPSBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRk
>> "%B64FILE%" echo ZCAtUmVjdXJzZSAtRmlsdGVyICouaW5mIC1FQSBTaWxlbnRseUNvbnRpbnVlKSB9DQpBZGQtTGlu
>> "%B64FILE%" echo ZSAiLS0tLS0tLS0tLSBEcml2ZXIgbGlicmFyeSAtLS0tLS0tLS0tIg0KaWYgKCRhbGxJbmYuQ291
>> "%B64FILE%" echo bnQgLWVxIDApIHsgQWRkLUxpbmUgIm5vIElORiBmb3VuZCBhdCBhbGwiIH0NCmZvcmVhY2ggKCRk
>> "%B64FILE%" echo ZCBpbiAkZHJ2RGlycykgeyBBZGQtTGluZSAoImZvbGRlcjogIiArICRkZCkgfQ0KQWRkLUxpbmUg
>> "%B64FILE%" echo KCJJTkYgZmlsZXMgaW4gdG90YWw6IHswfSIgLWYgJGFsbEluZi5Db3VudCkNCkFkZC1MaW5lICIi
>> "%B64FILE%" echo DQpTYXkgKCIgICAgICB7MH0gZHJpdmVyIGZvbGRlcnMsIHsxfSBJTkYgZmlsZXMiIC1mICRkcnZE
>> "%B64FILE%" echo aXJzLkNvdW50LCAkYWxsSW5mLkNvdW50KSAnRGFya0dyYXknDQoNCiMgLS0tLS0tLS0tLSBNYXRj
>> "%B64FILE%" echo aCBJTkYgZmlsZXMgYnkgaGFyZHdhcmUgSUQgLS0tLS0tLS0tLQ0KU2F5ICJbMi80XSBNYXRjaGlu
>> "%B64FILE%" echo ZyBJTkYgZmlsZXMgYnkgaGFyZHdhcmUgSUQgLi4uIiAnV2hpdGUnDQpmdW5jdGlvbiBHZXQtTWF0
>> "%B64FILE%" echo Y2hLZXlzIHsNCiAgICBwYXJhbShbc3RyaW5nXSRpbnN0LCAkaHdMaXN0KQ0KICAgICRrZXlzID0g
>> "%B64FILE%" echo QCgpDQogICAgZm9yZWFjaCAoJGggaW4gQCgkaHdMaXN0KSkgew0KICAgICAgICBpZiAoLW5vdCAk
>> "%B64FILE%" echo aCkgeyBjb250aW51ZSB9DQogICAgICAgICRrZXlzICs9ICRoDQogICAgICAgICRrZXlzICs9ICgk
>> "%B64FILE%" echo aCAtcmVwbGFjZSAnJlJFVl9bMC05QS1GYS1mXSsnLCAnJykNCiAgICB9DQogICAgJG0gPSBbcmVn
>> "%B64FILE%" echo ZXhdOjpNYXRjaCgkaW5zdCwgJyg/aSkoKD86UENJfFVTQilcXFZFTl9bMC05QS1GXXs0fSZERVZf
>> "%B64FILE%" echo WzAtOUEtRl17NH0mU1VCU1lTX1swLTlBLUZdezh9KScpDQogICAgaWYgKCRtLlN1Y2Nlc3MpIHsg
>> "%B64FILE%" echo JGtleXMgKz0gJG0uR3JvdXBzWzFdLlZhbHVlIH0NCiAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgk
>> "%B64FILE%" echo aW5zdCwgJyg/aSkoKD86UENJfFVTQilcXFZFTl9bMC05QS1GXXs0fSZERVZfWzAtOUEtRl17NH0p
>> "%B64FILE%" echo JykNCiAgICBpZiAoJG0yLlN1Y2Nlc3MpIHsgJGtleXMgKz0gJG0yLkdyb3Vwc1sxXS5WYWx1ZSB9
>> "%B64FILE%" echo DQogICAgcmV0dXJuIEAoJGtleXMgfCBXaGVyZS1PYmplY3QgeyAkXyB9IHwgU2VsZWN0LU9iamVj
>> "%B64FILE%" echo dCAtVW5pcXVlKQ0KfQ0KDQokaW5mVGV4dCA9IEB7fQ0KZm9yZWFjaCAoJGYgaW4gJGFsbEluZikg
>> "%B64FILE%" echo ew0KICAgIHRyeSB7DQogICAgICAgICR0ID0gJycNCiAgICAgICAgdHJ5IHsNCiAgICAgICAgICAg
>> "%B64FILE%" echo ICR0ID0gW0lPLkZpbGVdOjpSZWFkQWxsVGV4dCgkZi5GdWxsTmFtZSwgW1RleHQuRW5jb2Rpbmdd
>> "%B64FILE%" echo OjpVbmljb2RlKQ0KICAgICAgICAgICAgaWYgKCR0IC1ub3RtYXRjaCAnXFtWZXJzaW9uXF0nKSB7
>> "%B64FILE%" echo ICR0ID0gW0lPLkZpbGVdOjpSZWFkQWxsVGV4dCgkZi5GdWxsTmFtZSwgW1RleHQuRW5jb2Rpbmdd
>> "%B64FILE%" echo OjpEZWZhdWx0KSB9DQogICAgICAgIH0gY2F0Y2ggeyAkdCA9ICcnIH0NCiAgICAgICAgaWYgKCR0
>> "%B64FILE%" echo KSB7ICRpbmZUZXh0WyRmLkZ1bGxOYW1lXSA9ICR0IH0NCiAgICB9IGNhdGNoIHt9DQp9DQpTYXkg
>> "%B64FILE%" echo KCIgICAgICByZWFkIHRoZSBjb250ZW50cyBvZiB7MH0gSU5GIGZpbGVzIiAtZiAkaW5mVGV4dC5D
>> "%B64FILE%" echo b3VudCkgJ0RhcmtHcmF5Jw0KDQokaW5zdGFsbFF1ZXVlID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29s
>> "%B64FILE%" echo bGVjdGlvbnMuQXJyYXlMaXN0DQpmb3JlYWNoICgkZCBpbiAkcHJvYmxlbXMpIHsNCiAgICAkaHcg
>> "%B64FILE%" echo PSBAKCkNCiAgICB0cnkgeyAkaHcgPSBAKChHZXQtUG5wRGV2aWNlUHJvcGVydHkgLUluc3RhbmNl
>> "%B64FILE%" echo SWQgJGQuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZpY2VfSGFyZHdhcmVJZHMnIC1F
>> "%B64FILE%" echo cnJvckFjdGlvbiBTdG9wKS5EYXRhKSB9IGNhdGNoIHt9DQogICAgJGtleXMgPSBHZXQtTWF0Y2hL
>> "%B64FILE%" echo ZXlzIC1pbnN0ICRkLkluc3RhbmNlSWQgLWh3TGlzdCAkaHcNCiAgICAkbWF0Y2hlZCA9IEAoKQ0K
>> "%B64FILE%" echo ICAgIGZvcmVhY2ggKCRrdiBpbiAkaW5mVGV4dC5HZXRFbnVtZXJhdG9yKCkpIHsNCiAgICAgICAg
>> "%B64FILE%" echo Zm9yZWFjaCAoJGsgaW4gJGtleXMpIHsNCiAgICAgICAgICAgIGlmICgka3YuVmFsdWUuSW5kZXhP
>> "%B64FILE%" echo ZigkaywgW1N0cmluZ0NvbXBhcmlzb25dOjpPcmRpbmFsSWdub3JlQ2FzZSkgLWdlIDApIHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAkbWF0Y2hlZCArPSAka3YuS2V5DQogICAgICAgICAgICAgICAgYnJlYWsN
>> "%B64FILE%" echo CiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KICAgIH0NCiAgICAkbWF0Y2hlZCA9IEAoJG1hdGNo
>> "%B64FILE%" echo ZWQgfCBTZWxlY3QtT2JqZWN0IC1VbmlxdWUpDQogICAgW3ZvaWRdJGluc3RhbGxRdWV1ZS5BZGQo
>> "%B64FILE%" echo W3BzY3VzdG9tb2JqZWN0XUB7IERldiA9ICRkOyBLZXlzID0gJGtleXM7IEluZnMgPSAkbWF0Y2hl
>> "%B64FILE%" echo ZCB9KQ0KICAgIFNheSAoIiAgICAgIHswfSAgLT4gezF9IG1hdGNoaW5nIElORiBmaWxlcyIgLWYg
>> "%B64FILE%" echo JGQuRnJpZW5kbHlOYW1lLCAkbWF0Y2hlZC5Db3VudCkgJ0RhcmtHcmF5Jw0KICAgIEFkZC1MaW5l
>> "%B64FILE%" echo ICgibWF0Y2g6IHswfSAgKHsxfSBJTkYgZmlsZXMpIiAtZiAkZC5GcmllbmRseU5hbWUsICRtYXRj
>> "%B64FILE%" echo aGVkLkNvdW50KQ0KICAgIGZvcmVhY2ggKCRtaSBpbiAkbWF0Y2hlZCkgeyBBZGQtTGluZSAoIiAg
>> "%B64FILE%" echo ICAiICsgJG1pKSB9DQp9DQoNCiMgLS0tLS0tLS0tLSBJbnN0YWxsIG9uIHRoZSBzcG90IC0tLS0t
>> "%B64FILE%" echo LS0tLS0NClNheSAiWzMvNF0gSW5zdGFsbGluZyBvbiB0aGUgc3BvdCAoZm9yY2UgYSBkZXZpY2Ug
>> "%B64FILE%" echo cmVzY2FuIGZpcnN0KS4uLiIgJ1doaXRlJw0KQWRkLUxpbmUgIiINCkFkZC1MaW5lICItLS0tLS0t
>> "%B64FILE%" echo LS0tIE9uLXRoZS1zcG90IGluc3RhbGxhdGlvbiByZXN1bHQgLS0tLS0tLS0tLSINCiRzY2FuID0g
>> "%B64FILE%" echo JycNCnRyeSB7ICRzY2FuID0gKCYgcG5wdXRpbCAvc2Nhbi1kZXZpY2VzIDI+JjEgfCBPdXQtU3Ry
>> "%B64FILE%" echo aW5nKSB9IGNhdGNoIHt9DQokc2NhblR4dCA9ICgkc2NhbiAtcmVwbGFjZSAiXHMrIiwgJyAnKS5U
>> "%B64FILE%" echo cmltKCkNClNheSAoIiAgICAgIGRldmljZSByZXNjYW46ICIgKyAkc2NhblR4dCkgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KQWRkLUxpbmUgKCJkZXZpY2UgcmVzY2FuOiAiICsgJHNjYW5UeHQpDQpTdGFydC1TbGVlcCAt
>> "%B64FILE%" echo U2Vjb25kcyAzDQoNCiRsb2cgPSBKb2luLVBhdGggJGVudjpURU1QICdwbnB1dGlsX29uZS5sb2cn
>> "%B64FILE%" echo DQpmb3JlYWNoICgkaXRlbSBpbiAkaW5zdGFsbFF1ZXVlKSB7DQogICAgaWYgKCRpdGVtLkluZnMu
>> "%B64FILE%" echo Q291bnQgLWVxIDApIHsgY29udGludWUgfQ0KICAgIGZvcmVhY2ggKCRpbmYgaW4gJGl0ZW0uSW5m
>> "%B64FILE%" echo cykgew0KICAgICAgICB0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbG9nKSB7IFJl
>> "%B64FILE%" echo bW92ZS1JdGVtICRsb2cgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQ0K
>> "%B64FILE%" echo ICAgICAgICB0cnkgeyBpZiAoVGVzdC1QYXRoICgkbG9nICsgJy5lcnInKSkgeyBSZW1vdmUtSXRl
>> "%B64FILE%" echo bSAoJGxvZyArICcuZXJyJykgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KICAgICAgICAkcCA9IFN0YXJ0LVByb2Nlc3MgLUZpbGVQYXRoICdwbnB1dGlsLmV4ZScgLUFy
>> "%B64FILE%" echo Z3VtZW50TGlzdCBAKCcvYWRkLWRyaXZlcicsICJgIiRpbmZgIiIsICcvaW5zdGFsbCcpIGANCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAtUmVkaXJlY3RTdGFuZGFyZE91dHB1dCAkbG9nIC1SZWRpcmVjdFN0YW5k
>> "%B64FILE%" echo YXJkRXJyb3IgKCRsb2cgKyAnLmVycicpIGANCiAgICAgICAgICAgICAgICAtTm9OZXdXaW5kb3cg
>> "%B64FILE%" echo LVBhc3NUaHJ1IC1FcnJvckFjdGlvbiBTdG9wDQogICAgICAgICRzdyA9IFtTeXN0ZW0uRGlhZ25v
>> "%B64FILE%" echo c3RpY3MuU3RvcHdhdGNoXTo6U3RhcnROZXcoKQ0KICAgICAgICB3aGlsZSAoLW5vdCAkcC5IYXNF
>> "%B64FILE%" echo eGl0ZWQpIHsNCiAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgNTAwDQogICAg
>> "%B64FILE%" echo ICAgICAgICBpZiAoJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgLWd0IDE4MDAwMCkgeyB0cnkgeyBT
>> "%B64FILE%" echo dG9wLVByb2Nlc3MgLUlkICRwLklkIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IGNhdGNo
>> "%B64FILE%" echo IHt9OyBicmVhayB9DQogICAgICAgIH0NCiAgICAgICAgJHQgPSAnJw0KICAgICAgICB0cnkgeyAk
>> "%B64FILE%" echo dCA9IFtJTy5GaWxlXTo6UmVhZEFsbFRleHQoJGxvZywgW1RleHQuRW5jb2RpbmddOjpEZWZhdWx0
>> "%B64FILE%" echo KSB9IGNhdGNoIHt9DQogICAgICAgICRlID0gJycNCiAgICAgICAgdHJ5IHsgaWYgKFRlc3QtUGF0
>> "%B64FILE%" echo aCAoJGxvZyArICcuZXJyJykpIHsgJGUgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRsb2cgKyAn
>> "%B64FILE%" echo LmVycicsIFtUZXh0LkVuY29kaW5nXTo6RGVmYXVsdCkgfSB9IGNhdGNoIHt9DQogICAgICAgICRv
>> "%B64FILE%" echo a0FkZCA9ICgkdCAtbWF0Y2ggJ+W3suaIkOWKn+a3u+WKoHxzdWNjZXNzZnVsbHkgYWRkZWR85bey
>> "%B64FILE%" echo 5oiQ5Yqf5a+85YWlJykNCiAgICAgICAgJGxlYWYgPSBTcGxpdC1QYXRoIC1MZWFmICRpbmYNCiAg
>> "%B64FILE%" echo ICAgICAgaWYgKCRva0FkZCkgeyBTYXkgKCIgICAgICB7MH0gPT4gYWRkZWQiIC1mICRsZWFmKSAn
>> "%B64FILE%" echo R3JlZW4nIH0gZWxzZSB7IFNheSAoIiAgICAgIHswfSA9PiBub3QgYWRkZWQiIC1mICRsZWFmKSAn
>> "%B64FILE%" echo WWVsbG93JyB9DQogICAgICAgIEFkZC1MaW5lICgiLS0tIHswfSIgLWYgJGluZikNCiAgICAgICAg
>> "%B64FILE%" echo QWRkLUxpbmUgKCIgICAgcmVzdWx0OiAiICsgJChpZiAoJG9rQWRkKSB7ICdhZGRlZCcgfSBlbHNl
>> "%B64FILE%" echo IHsgJ25vdCBhZGRlZCcgfSkpDQogICAgICAgIGZvcmVhY2ggKCRsIGluIEAoJHQgLXNwbGl0ICJb
>> "%B64FILE%" echo YHJgbl0rIiB8IFdoZXJlLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgU2VsZWN0LU9iamVjdCAtTGFz
>> "%B64FILE%" echo dCA2KSkgeyBBZGQtTGluZSAoIiAgICAiICsgJGwpIH0NCiAgICAgICAgaWYgKCRlLlRyaW0oKSkg
>> "%B64FILE%" echo eyBmb3JlYWNoICgkbCBpbiBAKCRlIC1zcGxpdCAiW2ByYG5dKyIgfCBXaGVyZS1PYmplY3QgeyAk
>> "%B64FILE%" echo Xy5UcmltKCkgfSB8IFNlbGVjdC1PYmplY3QgLUxhc3QgNCkpIHsgQWRkLUxpbmUgKCIgICAgW2Vy
>> "%B64FILE%" echo cl0gIiArICRsKSB9IH0NCiAgICB9DQp9DQoNCiMgLS0tLS0tLS0tLSBSZS1jaGVjayAtLS0tLS0t
>> "%B64FILE%" echo LS0tDQpTYXkgIls0LzRdIFJlLWNoZWNraW5nIC4uLiIgJ1doaXRlJw0KU3RhcnQtU2xlZXAgLVNl
>> "%B64FILE%" echo Y29uZHMgNQ0KdHJ5IHsgJiBwbnB1dGlsIC9zY2FuLWRldmljZXMgMj4mMSB8IE91dC1OdWxsIH0g
>> "%B64FILE%" echo Y2F0Y2gge30NClN0YXJ0LVNsZWVwIC1TZWNvbmRzIDUNCiRhZnRlciA9IEAoR2V0LVJlYWxQcm9i
>> "%B64FILE%" echo bGVtcykNCkFkZC1MaW5lICIiDQpBZGQtTGluZSAiLS0tLS0tLS0tLSBTdGlsbCBmYXVsdHkgYWZ0
>> "%B64FILE%" echo ZXIgaW5zdGFsbGF0aW9uIC0tLS0tLS0tLS0iDQpBZGQtTGluZSAoInswfSBpbiB0b3RhbCIgLWYg
>> "%B64FILE%" echo JGFmdGVyLkNvdW50KQ0KZm9yZWFjaCAoJGQgaW4gJGFmdGVyKSB7DQogICAgQWRkLUxpbmUgKCJb
>> "%B64FILE%" echo ezB9XSB7MX0gICBwcm9ibGVtIGNvZGUgezJ9IiAtZiAkZC5TdGF0dXMsICRkLkZyaWVuZGx5TmFt
>> "%B64FILE%" echo ZSwgJGQuUHJvYmxlbSkNCiAgICBBZGQtTGluZSAoIiAgICBpbnN0YW5jZSBJRDogezB9IiAtZiAk
>> "%B64FILE%" echo ZC5JbnN0YW5jZUlkKQ0KfQ0KDQokbmV0QWxsID0gQChHZXQtTmV0QWRhcHRlciAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU2lsZW50bHlDb250aW51ZSkNCiRuZXRVcCA9IEAoJG5ldEFsbCB8IFdoZXJlLU9iamVjdCB7
>> "%B64FILE%" echo ICRfLlN0YXR1cyAtZXEgJ1VwJyB9KQ0KQWRkLUxpbmUgIiINCkFkZC1MaW5lICItLS0tLS0tLS0t
>> "%B64FILE%" echo IE5ldHdvcmsgYWRhcHRlcnMgLS0tLS0tLS0tLSINCmZvcmVhY2ggKCRhIGluICRuZXRBbGwpIHsg
>> "%B64FILE%" echo QWRkLUxpbmUgKCJ7MH0gfCB7MX0gfCB7Mn0iIC1mICRhLk5hbWUsICRhLkludGVyZmFjZURlc2Ny
>> "%B64FILE%" echo aXB0aW9uLCAkYS5TdGF0dXMpIH0NCkFkZC1MaW5lICgiYWRhcHRlcnMgd2l0aCBzdGF0dXMgVXA6
>> "%B64FILE%" echo IHswfSIgLWYgJG5ldFVwLkNvdW50KQ0KQWRkLUxpbmUgIiINCkFkZC1MaW5lICI9PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PSBEaWFnbm9zdGljcyBmaW5pc2hlZCA9PT09PT09PT09PT09PT09PT09PSINCg0K
>> "%B64FILE%" echo IyAtLS0tLS0tLS0tIFdyaXRlIHRoZSByZXBvcnQgLS0tLS0tLS0tLQ0KIyBbdjEuMjldIFRoZSBy
>> "%B64FILE%" echo ZXBvcnQgaXMgbm8gbG9uZ2VyIGRyb3BwZWQgaW4gdGhlIGRyaXZlIHJvb3Q7IGV2ZXJ5dGhpbmcg
>> "%B64FILE%" echo Z29lcyB0byA8ZHJpdmU+Olw8UHJvZHVjdE5hbWU+LWxvZ3NcDQojIChwcmV2aW91c2x5IGV2ZXJ5
>> "%B64FILE%" echo IGRyaXZlIHJvb3QgZ2FpbmVkIGEgIm5ldy1zeXN0ZW0tcmVwb3J0LnR4dCIsIGFuZCBhIGZldyBp
>> "%B64FILE%" echo bnN0YWxscyBtYWRlIGEgbWVzcykNCiRzYXZlZCA9IEAoKQ0KZm9yZWFjaCAoJHYgaW4gQChHZXQt
>> "%B64FILE%" echo Vm9sdW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgIGlmICgtbm90ICR2
>> "%B64FILE%" echo LkRyaXZlTGV0dGVyKSB7IGNvbnRpbnVlIH0NCiAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4
>> "%B64FILE%" echo ZWQnKSB7IGNvbnRpbnVlIH0NCiAgICAkZGlyID0gInswfTpcVmlydHVhbCBIYXJkIERpc2sgU3lz
>> "%B64FILE%" echo dGVtLWxvZ3MiIC1mICR2LkRyaXZlTGV0dGVyDQogICAgdHJ5IHsNCiAgICAgICAgaWYgKC1ub3Qg
>> "%B64FILE%" echo KFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGRpcikpIHsNCiAgICAgICAgICAgIE5ldy1JdGVtIC1J
>> "%B64FILE%" echo dGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJGRpciAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AgfCBP
>> "%B64FILE%" echo dXQtTnVsbA0KICAgICAgICB9DQogICAgICAgICRvdXRGaWxlID0gSm9pbi1QYXRoICRkaXIgJ25l
>> "%B64FILE%" echo dy1zeXN0ZW0tcmVwb3J0LnR4dCcNCiAgICAgICAgJHJlcG9ydCAtam9pbiAiYHJgbiIgfCBTZXQt
>> "%B64FILE%" echo Q29udGVudCAtTGl0ZXJhbFBhdGggJG91dEZpbGUgLUVuY29kaW5nIFVURjggLUVycm9yQWN0aW9u
>> "%B64FILE%" echo IFN0b3ANCiAgICAgICAgJHNhdmVkICs9ICRvdXRGaWxlDQogICAgfSBjYXRjaCB7fQ0KfQ0KDQpT
>> "%B64FILE%" echo YXkgIiINClNheSAoIiAgZ2VudWluZSBmYXVsdHM6IHswfSBiZWZvcmUgLT4gezF9IGFmdGVyIiAt
>> "%B64FILE%" echo ZiAkcHJvYmxlbXMuQ291bnQsICRhZnRlci5Db3VudCkgJ0N5YW4nDQpTYXkgKCIgIGFkYXB0ZXJz
>> "%B64FILE%" echo IFVwOiB7MH0iIC1mICRuZXRVcC5Db3VudCkgJ0N5YW4nDQppZiAoJHNhdmVkLkNvdW50IC1ndCAw
>> "%B64FILE%" echo KSB7DQogICAgU2F5ICIgIFJlcG9ydCB3cml0dGVuIHRvOiIgJ0dyZWVuJw0KICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRzIGluICRzYXZlZCkgeyBTYXkgKCIgICAgICAiICsgJHMpICdHcmVlbicgfQ0KfQ0KU2F5ICIi
>> "%B64FILE%" echo DQpSZWFkLUhvc3QgIiAgUHJlc3MgRW50ZXIgdG8gZXhpdCINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=11665"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%"
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
