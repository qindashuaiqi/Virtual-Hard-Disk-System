@echo off
setlocal enabledelayedexpansion
chcp 437 >nul 2>&1
title Clean Install Residue
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
set "PS1FILE=%WORKDIR%\Clean-Install-Residue.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/I3JlcXVpcmVzIC1WZXJzaW9uIDUuMQ0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMgQ2xlYW4gSW5zdGFsbCBSZXNpZHVl
>> "%B64FILE%" echo ICB2MS4zDQojIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QNCiMNCiMgUHVycG9zZTogYWZ0ZXIgYW4g
>> "%B64FILE%" echo aW5zdGFsbCBoYW5ncyBvciB0aGUgd2luZG93IGlzIGNsb3NlZCBtaWR3YXksIHRoZSBtYWNoaW5l
>> "%B64FILE%" echo IGlzIGxlZnQgd2l0aA0KIyAgIDEpIGEgZGlzbS5leGUgdGhhdCBuZXZlciBmaW5pc2hlZCAoc3Rp
>> "%B64FILE%" echo bGwgaG9sZGluZyB0aGUgdmhkeCBmaWxlKQ0KIyAgIDIpIGEgbW91bnRlZCB2aXJ0dWFsIGRpc2sg
>> "%B64FILE%" echo KGhvbGRpbmcgYSBkcml2ZSBsZXR0ZXIsIGUuZy4gRTopDQojICAgMykgYSBoYWxmLWJ1aWx0IHZo
>> "%B64FILE%" echo ZHggKG9sZGVyIHZlcnNpb25zIGFsd2F5cyBjYWxsZWQgaXQgTmV3U3lzdGVtRGlzay52aGR4LCBu
>> "%B64FILE%" echo b3cgYW55IG5hbWUgaXMgcG9zc2libGUpDQojIFRoaXMgc2NyaXB0IGNsZWFucyB0aGVtIHVwIGlu
>> "%B64FILE%" echo IG9yZGVyIHNvIEluc3RhbGwtU3lzdGVtLmJhdCBjYW4gYmUgcmVydW4gY2xlYW5seS4NCiMNCiMg
>> "%B64FILE%" echo U3RlcCAzIG9ubHkgaGFuZGxlcyB2aGR4IGZpbGVzIHdpdGhvdXQgYSBib290IGVudHJ5LCBpbiB0
>> "%B64FILE%" echo aHJlZSBjYXRlZ29yaWVzOg0KIyAgIEEgaW5zdGFsbGVkLCBib290IGVudHJ5IHN0aWxsIHByZXNl
>> "%B64FILE%" echo bnQgIC0+IG5ldmVyIHRvdWNoZWQgKHVzZSBVbmluc3RhbGwtU3lzdGVtLmJhdCB0byBkZWxldGUg
>> "%B64FILE%" echo aXQpDQojICAgQiBpbnN0YWxsZWQgYnkgdGhpcyB0b29sa2l0LCBlbnRyeSBnb25lIC0+IHRoZSAu
>> "%B64FILE%" echo Ym9vdC50eHQgcHJvdmVzIGl0OyBhbnN3ZXIgeSB0byBkZWxldGUNCiMgICBDIG5vdCBjcmVhdGVk
>> "%B64FILE%" echo IGJ5IHRoaXMgdG9vbGtpdCAgICAgICAgICAtPiBtYXkgYmUgSHlwZXItViwgYW5vdGhlciB0b29s
>> "%B64FILE%" echo LCBvciB5b3VyIG93biBiYWNrdXA7DQojICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICBuZXZlciBkZWxldGVkIGJ5IGRlZmF1bHQsIGFuZCBkZWxldGluZyByZXF1aXJl
>> "%B64FILE%" echo cyB0eXBpbmcgdGhlIGZpbGUgbmFtZQ0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KcGFyYW0oDQogICAgW3N0cmluZ10kT3Jp
>> "%B64FILE%" echo Z2luRGlyID0gJycNCikNCg0KJEVycm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdDb250aW51ZScNCiRT
>> "%B64FILE%" echo Y3JpcHQ6VmVyc2lvbiA9ICcxLjM0Jw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQoN
>> "%B64FILE%" echo CnRyeSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIkNsZWFuIEluc3RhbGwgUmVzaWR1
>> "%B64FILE%" echo ZSB2JCgkU2NyaXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3QiIH0gY2F0Y2gge30NCg0KIyBb
>> "%B64FILE%" echo djEuMzJdIFNoYXJlZCBtb2R1bGUuIHNyYy9idWlsZC9pbmxpbmVfc2hhcmVkLnB5IGlubGluZXMg
>> "%B64FILE%" echo dGhpcyBmaWxlIGF0DQojIGJ1aWxkIHRpbWUsIGFuZCB0aGUgLmJhdCBwYXlsb2FkIGlzIHN0aWxs
>> "%B64FILE%" echo IGEgc2VsZi1jb250YWluZWQgc2luZ2xlIGZpbGUuDQojID09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIyBTaGFyZWQgbG9nZ2luZyBo
>> "%B64FILE%" echo ZWxwZXJzICAgdjEuMzINCiMNCiMgVGhpcyBmaWxlIGlzIE5PVCB3aGF0IGdldHMgc2hpcHBlZC4g
>> "%B64FILE%" echo c3JjL2J1aWxkL2lubGluZV9zaGFyZWQucHkgaW5saW5lcyBpdHMNCiMgY29udGVudCBpbnRvIGV2
>> "%B64FILE%" echo ZXJ5IGVudHJ5IHNjcmlwdCB3aGlsZSB0aGUgLmJhdCBwYXlsb2FkcyBhcmUgYnVpbHQsIHNvIHRo
>> "%B64FILE%" echo ZQ0KIyByZWxlYXNlZCBsYXVuY2hlcnMgc3RheSBzZWxmLWNvbnRhaW5lZCBzaW5nbGUgZmlsZXMg
>> "%B64FILE%" echo KHRoZSBzZWxmLWV4dHJhY3RpbmcgYmF0DQojIGhhcyBubyB3YXkgdG8gcmVmZXJlbmNlIGFuIGV4
>> "%B64FILE%" echo dGVybmFsIG1vZHVsZSBhdCBydW4gdGltZSkuDQojDQojIFJ1bGU6IGVkaXQgaGVyZSwgbmV2ZXIg
>> "%B64FILE%" echo Y29weS1wYXN0ZSB0aGVzZSBmdW5jdGlvbnMgYmFjayBpbnRvIGFuIGVudHJ5IHNjcmlwdC4NCiMg
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09DQoNCmZ1bmN0aW9uIFNheSB7DQogICAgcGFyYW0oW3N0cmluZ10kVGV4dCwgW3N0cmluZ10k
>> "%B64FILE%" echo Q29sb3IgPSAnR3JheScpDQogICAgV3JpdGUtSG9zdCAkVGV4dCAtRm9yZWdyb3VuZENvbG9yICRD
>> "%B64FILE%" echo b2xvcg0KfQ0KDQpTYXkgIiINClNheSAiICBDbGVhbiBJbnN0YWxsIFJlc2lkdWUgIHYkKCRTY3Jp
>> "%B64FILE%" echo cHQ6VmVyc2lvbikiICdDeWFuJw0KU2F5ICIgIEF1dGhvcjogY29ubmVjdHNlZ2Fib3QiICdEYXJr
>> "%B64FILE%" echo R3JheScNClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNClNheSAiIg0KDQokYWRtaW4gPSAoW1NlY3Vy
>> "%B64FILE%" echo aXR5LlByaW5jaXBhbC5XaW5kb3dzUHJpbmNpcGFsXVtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93
>> "%B64FILE%" echo c0lkZW50aXR5XTo6R2V0Q3VycmVudCgpKS5Jc0luUm9sZShbU2VjdXJpdHkuUHJpbmNpcGFsLldp
>> "%B64FILE%" echo bmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpDQppZiAoLW5vdCAkYWRtaW4pIHsNCiAg
>> "%B64FILE%" echo ICBTYXkgIiAgW0VSUk9SXSBBZG1pbmlzdHJhdG9yIHJpZ2h0cyBhcmUgcmVxdWlyZWQuIENsb3Nl
>> "%B64FILE%" echo IHRoaXMgd2luZG93LCByaWdodC1jbGljayB0aGlzIGZpbGUgLT4gUnVuIGFzIGFkbWluaXN0cmF0
>> "%B64FILE%" echo b3IuIiAnUmVkJw0KICAgIFNheSAiIg0KICAgIFJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBl
>> "%B64FILE%" echo eGl0Ig0KICAgIGV4aXQgMQ0KfQ0KDQojIC0tLS0tLS0tLS0gMS4gS2lsbCBsZWZ0b3ZlciBkaXNt
>> "%B64FILE%" echo IC0tLS0tLS0tLS0NCiMNCiMgW2F1ZGl0IFAzLTE2XSBUaGlzIHVzZWQgdG8ga2lsbCBldmVyeSBk
>> "%B64FILE%" echo aXNtLmV4ZSAvIERpc21Ib3N0IG9uIHRoZSBtYWNoaW5lIHdpdGhvdXQgYXNraW5nLg0KIyBBIHVz
>> "%B64FILE%" echo ZXIgcnVubmluZyBESVNNIC9SZXN0b3JlSGVhbHRoIChvciBhbnkgb3RoZXIgbG9uZyBESVNNIGpv
>> "%B64FILE%" echo YikgaGFkIGl0IHRlcm1pbmF0ZWQgbWlkLXdheS4NCiMgSXQgaXMgc3RpbGwgd29ydGggb2ZmZXJp
>> "%B64FILE%" echo bmcgLSBhIHN0dWNrIERpc21Ib3N0IGlzIGV4YWN0bHkgd2hhdCBibG9ja3MgYSByZWluc3RhbGwg
>> "%B64FILE%" echo LSBidXQgdGhlDQojIHVzZXIgZ2V0cyB0byBzZWUgd2hhdCBpcyBydW5uaW5nIGFuZCBkZWNpZGUu
>> "%B64FILE%" echo DQpTYXkgIlsxLzNdIExvb2tpbmcgZm9yIGxlZnRvdmVyIGRpc20uZXhlIC4uLiINCiRkaXNtcyA9
>> "%B64FILE%" echo IEAoR2V0LVByb2Nlc3MgLU5hbWUgZGlzbSwgRGlzbUhvc3QgLUVycm9yQWN0aW9uIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpDQoka2lsbGVkID0gMA0KaWYgKCRkaXNtcy5Db3VudCAtZXEgMCkgew0KICAgIFNh
>> "%B64FILE%" echo eSAiICAgICAgbm9uZSBydW5uaW5nIiAnRGFya0dyYXknDQp9IGVsc2Ugew0KICAgIFNheSAoIiAg
>> "%B64FILE%" echo ICAgIHswfSBwcm9jZXNzKGVzKTogezF9IiAtZiAkZGlzbXMuQ291bnQsICgoJGRpc21zIHwgRm9y
>> "%B64FILE%" echo RWFjaC1PYmplY3QgeyAiJCgkXy5Qcm9jZXNzTmFtZSkoUElEICQoJF8uSWQpKSIgfSkgLWpvaW4g
>> "%B64FILE%" echo JywgJykpICdZZWxsb3cnDQogICAgU2F5ICIgICAgICBLaWxsaW5nIHRoZW0gYWxzbyBpbnRlcnJ1
>> "%B64FILE%" echo cHRzIGEgRElTTSBqb2IgeW91IHN0YXJ0ZWQgeW91cnNlbGYgKGZvciBleGFtcGxlIC9SZXN0b3Jl
>> "%B64FILE%" echo SGVhbHRoKS4iICdEYXJrR3JheScNCiAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAgICBLaWxsIHRo
>> "%B64FILE%" echo ZW0/IFt5L05dIg0KICAgIGlmICgkYW5zIC1tYXRjaCAnXig/aSl5KGVzKT8kJykgew0KICAgICAg
>> "%B64FILE%" echo ICBmb3JlYWNoICgkcCBpbiAkZGlzbXMpIHsNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgU3RvcC1Qcm9jZXNzIC1JZCAkcC5JZCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3ANCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAka2lsbGVkKysNCiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICBraWxs
>> "%B64FILE%" echo ZWQgezB9IChQSUQgezF9KSIgLWYgJHAuUHJvY2Vzc05hbWUsICRwLklkKSAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgICAgICAgICB9IGNhdGNoIHsNCiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICBmYWlsZWQg
>> "%B64FILE%" echo dG8ga2lsbCB7MH0gKFBJRCB7MX0pOiB7Mn0iIC1mICRwLlByb2Nlc3NOYW1lLCAkcC5JZCwgJF8u
>> "%B64FILE%" echo RXhjZXB0aW9uLk1lc3NhZ2UpICdZZWxsb3cnDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAg
>> "%B64FILE%" echo ICB9IGVsc2Ugew0KICAgICAgICBTYXkgIiAgICAgIHNraXBwZWQiICdEYXJrR3JheScNCiAgICB9
>> "%B64FILE%" echo DQp9DQpTdGFydC1TbGVlcCAtTWlsbGlzZWNvbmRzIDgwMA0KDQojIC0tLS0tLS0tLS0gMi4gRGlz
>> "%B64FILE%" echo bW91bnQgdmlydHVhbCBkaXNrcyAtLS0tLS0tLS0tDQojDQojIFthdWRpdCBQMy0xNl0gU2FtZSBw
>> "%B64FILE%" echo cm9ibGVtOiBldmVyeSBGaWxlIEJhY2tlZCBWaXJ0dWFsIGRpc2sgd2FzIGRldGFjaGVkLCBpbmNs
>> "%B64FILE%" echo dWRpbmcgYSBIeXBlci1WDQojIG1hY2hpbmUgZGlzayBvciBhIFZIRCB0aGUgdXNlciBpcyB3b3Jr
>> "%B64FILE%" echo aW5nIHdpdGguIE5vdGhpbmcgaXMgbG9zdCBieSBkZXRhY2hpbmcsIGJ1dCB0aGUgb3RoZXINCiMg
>> "%B64FILE%" echo am9iIGJyZWFrcy4gQXNrIHBlciBkaXNrLCBhbmQgbmV2ZXIgdG91Y2ggYW55dGhpbmcgdGhhdCBp
>> "%B64FILE%" echo cyBub3QgdGhlIG9uZSB3ZSBhcmUgaGVyZSBmb3IuDQpTYXkgIlsyLzNdIE1vdW50ZWQgdmlydHVh
>> "%B64FILE%" echo bCBkaXNrcyAuLi4iDQokdmRzID0gQChHZXQtRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
>> "%B64FILE%" echo aW51ZSB8IFdoZXJlLU9iamVjdCB7IFtzdHJpbmddJF8uQnVzVHlwZSAtZXEgJ0ZpbGUgQmFja2Vk
>> "%B64FILE%" echo IFZpcnR1YWwnIH0pDQppZiAoJHZkcy5Db3VudCAtZXEgMCkgew0KICAgIFNheSAiICAgICAgbm9u
>> "%B64FILE%" echo ZSBtb3VudGVkIiAnRGFya0dyYXknDQp9IGVsc2Ugew0KICAgIGZvcmVhY2ggKCRkIGluICR2ZHMp
>> "%B64FILE%" echo IHsNCiAgICAgICAgJGxvYyA9IFtzdHJpbmddJGQuTG9jYXRpb24NCiAgICAgICAgU2F5ICgiICAg
>> "%B64FILE%" echo ICAgRGlzayB7MH06IHsxfSIgLWYgJGQuTnVtYmVyLCAkbG9jKSAnRGFya0dyYXknDQogICAgICAg
>> "%B64FILE%" echo IGlmICgtbm90ICRsb2MpIHsgY29udGludWUgfQ0KICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICgi
>> "%B64FILE%" echo ICAgICAgRGV0YWNoIHRoaXMgb25lPyBbeS9OXSIpDQogICAgICAgIGlmICgkYW5zIC1ub3RtYXRj
>> "%B64FILE%" echo aCAnXig/aSl5KGVzKT8kJykgeyBTYXkgIiAgICAgIGtlcHQgbW91bnRlZCIgJ0RhcmtHcmF5Jzsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICAkZHBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImRldGFj
>> "%B64FILE%" echo aF97MH0udHh0IiAtZiAkZC5OdW1iZXIpDQogICAgICAgIEAoDQogICAgICAgICAgICAic2VsZWN0
>> "%B64FILE%" echo IHZkaXNrIGZpbGU9YCIkbG9jYCIiLA0KICAgICAgICAgICAgJ2RldGFjaCB2ZGlzayBub2Vycics
>> "%B64FILE%" echo DQogICAgICAgICAgICAnZXhpdCcNCiAgICAgICAgKSB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0
>> "%B64FILE%" echo aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0DQogICAgICAgICRyID0gJiBkaXNrcGFydCAvcyAk
>> "%B64FILE%" echo ZHBGaWxlIDI+JjEgfCBPdXQtU3RyaW5nDQogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0
>> "%B64FILE%" echo aCAkZHBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoJHIgLW1hdGNoICdzdWNjZXNzZnVsbHl85oiQ5YqfJykgeyBTYXkgIiAgICAgIGRpc21vdW50
>> "%B64FILE%" echo ZWQiICdHcmVlbicgfQ0KICAgICAgICBlbHNlIHsgU2F5ICgiICAgICAgZGlzbW91bnQgcmVzdWx0
>> "%B64FILE%" echo OiAiICsgKCRyIC1yZXBsYWNlICJccysiLCAnICcpLlRyaW0oKSkgJ1llbGxvdycgfQ0KICAgIH0N
>> "%B64FILE%" echo Cn0NClN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgODAwDQoNCiMgLS0tLS0tLS0tLSAzLiBIYW5k
>> "%B64FILE%" echo bGUgdmhkeCBmaWxlcyB3aXRob3V0IGEgYm9vdCBlbnRyeSAtLS0tLS0tLS0tDQojIHYxLjAgb25s
>> "%B64FILE%" echo eSBrbmV3IHRoZSBoYXJkLWNvZGVkIE5ld1N5c3RlbURpc2sudmhkeC4gU2luY2UgdjEuMTEgdGhl
>> "%B64FILE%" echo IGluc3RhbGxlciBhbGxvd3MgY3VzdG9tIG5hbWVzIGFuZCBmb2xkZXJzLA0KIyBzbyBhIGhhbmcg
>> "%B64FILE%" echo YXQgRTpcVkhEXG1haW1haS52aGR4IHdhcyBpbnZpc2libGUgaGVyZSBhbmQgdGhvc2UgMjBHQiBz
>> "%B64FILE%" echo dGF5ZWQgb2NjdXBpZWQgZm9yZXZlci4NCiMNCiMgQnV0ICJubyBib290IGVudHJ5IiBkb2VzIG5v
>> "%B64FILE%" echo dCBtZWFuICJqdW5rIGZyb20gdGhpcyB0b29sa2l0Ii4gSHlwZXItViBkaXNrcywgb3RoZXIgaW5z
>> "%B64FILE%" echo dGFsbCB0b29scyBhbmQgdmhkeCBmaWxlcw0KIyB5b3UgcGxhY2VkIHlvdXJzZWxmIGFsc28gaGF2
>> "%B64FILE%" echo ZSBubyAuYm9vdC50eHQuIHYxLjEgbGlzdGVkIHRoZW0gYWxsIGFuZCBhc2tlZCAiZGVsZXRlPyIs
>> "%B64FILE%" echo IHRvZ2V0aGVyIHdpdGgNCiMgYSBoaW50IHRoYXQgImRlbGV0aW5nIGZyZWVzIDIwR0IiIC0gdGhh
>> "%B64FILE%" echo dCB3YXMgZW5jb3VyYWdpbmcgdXNlcnMgdG8gcHJlc3MgeSBhbmQgZGVsZXRlIG90aGVyIHBlb3Bs
>> "%B64FILE%" echo ZSdzIGRhdGEsDQojIGFuZCAianVzdCBwcmVzcyBFbnRlciB0byBza2lwIiB3YXMgbHVjaywgbm90
>> "%B64FILE%" echo IGRlc2lnbi4NCiMNCiMgU2luY2UgdjEuMiB0aGV5IGFyZSBoYW5kbGVkIGluIHRocmVlIGNhdGVn
>> "%B64FILE%" echo b3JpZXMsIHNlZSB0aGUgZmlsZSBoZWFkZXIuDQpTYXkgIlszLzNdIENoZWNraW5nIHZpcnR1YWwg
>> "%B64FILE%" echo ZGlza3Mgd2l0aCBubyBib290IGVudHJ5IC4uLiINCg0KIyBTY2FuIGFsbCBkaXNrcyBmb3IgKi52
>> "%B64FILE%" echo aGR4OiBwcnVuZSBieSBmb2xkZXIgbmFtZSBvbmx5LCBuZXZlciBlbnRlcmluZyBzeXN0ZW0gZm9s
>> "%B64FILE%" echo ZGVycyBvciB0aGUgcmVjeWNsZSBiaW4NCiMgPj4+IENPTU1PTjpHZXQtQWxsVmhkeEZpbGUNCiMg
>> "%B64FILE%" echo SW5qZWN0ZWQgYnkgdGhlIGJ1aWxkIHNjcmlwdCBmcm9tIHRoZSBzaGFyZWQgY29tbW9uL0dldC1B
>> "%B64FILE%" echo bGxWaGR4RmlsZS5wczEuIEVkaXRpbmcgaXQgaGVyZSBoYXMgbm8gZWZmZWN0Lg0KZnVuY3Rpb24g
>> "%B64FILE%" echo R2V0LUFsbFZoZHhGaWxlIHsNCiAgICBwYXJhbShbaW50XSRNYXhEZXB0aCA9IDYpDQogICAgIyBQ
>> "%B64FILE%" echo cnVuaW5nIGlzIGJ5IGZvbGRlciBuYW1lIG9ubHksIG5ldmVyIGVudGVyaW5nIHN5c3RlbSBmb2xk
>> "%B64FILE%" echo ZXJzLCB0aGUgcmVjeWNsZSBiaW4gb3IgZGVwZW5kZW5jeSBjYWNoZXMsIHNvIGRlcHRoIDYgc3Rh
>> "%B64FILE%" echo eXMgZmFzdC4NCiAgICAjIFVzZSAuTkVUIGRpcmVjdG9yeSBlbnVtZXJhdGlvbiBpbnN0ZWFkIG9m
>> "%B64FILE%" echo IEdldC1DaGlsZEl0ZW06IHRoZSBsYXR0ZXIgY3JlYXRlcyBhIFBTT2JqZWN0IHBlciBlbnRyeSwN
>> "%B64FILE%" echo CiAgICAjIG1lYXN1cmVkIDEwNzQgbXMgdnMgODMgbXMgb24gdGhlIHNhbWUgdHJlZSwgYSAxMngg
>> "%B64FILE%" echo ZGlmZmVyZW5jZSAodGhlIHdpbmRvdyByZXNjYW5zIG9uIGV2ZXJ5IHJlZnJlc2gsIHNvIGl0IGlz
>> "%B64FILE%" echo IHZlcnkgdmlzaWJsZSkuDQogICAgJHNraXAgPSBAKCckUkVDWUNMRS5CSU4nLCAnU3lzdGVtIFZv
>> "%B64FILE%" echo bHVtZSBJbmZvcm1hdGlvbicsICdXaW5kb3dzJywgJ1Byb2dyYW0gRmlsZXMnLA0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAnUHJvZ3JhbSBGaWxlcyAoeDg2KScsICdQcm9ncmFtRGF0YScsICdVc2VycycsICckV2lu
>> "%B64FILE%" echo UkVBZ2VudCcsICdSZWNvdmVyeScsDQogICAgICAgICAgICAgICdub2RlX21vZHVsZXMnLCAnLmdp
>> "%B64FILE%" echo dCcsICdXaW5TeFMnKQ0KICAgICRmb3VuZCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25z
>> "%B64FILE%" echo LkFycmF5TGlzdA0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24g
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRmlsZVN5c3RlbSAtbmUgJ05URlMnKSB7IGNvbnRp
>> "%B64FILE%" echo bnVlIH0NCiAgICAgICAgaWYgKCR2LkRyaXZlVHlwZSAtbmUgJ0ZpeGVkJykgeyBjb250aW51ZSB9
>> "%B64FILE%" echo DQogICAgICAgICRxdWV1ZSA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLlF1ZXVlDQog
>> "%B64FILE%" echo ICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoIiQoJHYuRHJpdmVMZXR0ZXIpOlwiLCAwKSkNCiAgICAg
>> "%B64FILE%" echo ICAgd2hpbGUgKCRxdWV1ZS5Db3VudCAtZ3QgMCkgew0KICAgICAgICAgICAgJGN1ciA9ICRxdWV1
>> "%B64FILE%" echo ZS5EZXF1ZXVlKCkNCiAgICAgICAgICAgICRkaXIgPSBbc3RyaW5nXSRjdXJbMF0NCiAgICAgICAg
>> "%B64FILE%" echo ICAgICRkID0gW2ludF0kY3VyWzFdDQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAg
>> "%B64FILE%" echo IGZvcmVhY2ggKCRmIGluIFtTeXN0ZW0uSU8uRGlyZWN0b3J5XTo6R2V0RmlsZXMoJGRpciwgJyou
>> "%B64FILE%" echo dmhkeCcpKSB7DQogICAgICAgICAgICAgICAgICAgIFt2b2lkXSRmb3VuZC5BZGQoKE5ldy1PYmpl
>> "%B64FILE%" echo Y3QgU3lzdGVtLklPLkZpbGVJbmZvICRmKSkNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAg
>> "%B64FILE%" echo ICB9IGNhdGNoIHt9DQogICAgICAgICAgICBpZiAoJGQgLWdlICRNYXhEZXB0aCkgeyBjb250aW51
>> "%B64FILE%" echo ZSB9DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRzdWIgaW4g
>> "%B64FILE%" echo W1N5c3RlbS5JTy5EaXJlY3RvcnldOjpFbnVtZXJhdGVEaXJlY3RvcmllcygkZGlyKSkgew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICBpZiAoJHNraXAgLWNvbnRhaW5zIFtTeXN0ZW0uSU8uUGF0aF06Okdl
>> "%B64FILE%" echo dEZpbGVOYW1lKCRzdWIpKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgICAgICAgICAgdHJ5IHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICAgICAgICAgIGlmIChbU3lzdGVtLklPLkZpbGVdOjpHZXRBdHRyaWJ1
>> "%B64FILE%" echo dGVzKCRzdWIpIC1iYW5kIFtTeXN0ZW0uSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQp
>> "%B64FILE%" echo IHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB9IGNhdGNoIHsgY29udGludWUgfQ0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICAgICAkcXVldWUuRW5xdWV1ZShAKCRzdWIsICgkZCArIDEpKSkNCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9IGNhdGNoIHt9DQogICAgICAgIH0NCiAgICB9
>> "%B64FILE%" echo DQogICAgcmV0dXJuICRmb3VuZC5Ub0FycmF5KCkNCn0NCiMgPDw8IENPTU1PTjpHZXQtQWxsVmhk
>> "%B64FILE%" echo eEZpbGUNCg0KZnVuY3Rpb24gR2V0LVZoZFN0YXRlR3VpZCB7DQogICAgcGFyYW0oW3N0cmluZ10k
>> "%B64FILE%" echo UGF0aCkNCiAgICAkc3QgPSBbU3lzdGVtLklPLlBhdGhdOjpDaGFuZ2VFeHRlbnNpb24oJFBhdGgs
>> "%B64FILE%" echo ICcuYm9vdC50eHQnKQ0KICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdCkp
>> "%B64FILE%" echo IHsgcmV0dXJuICcnIH0NCiAgICBmb3JlYWNoICgkbG4gaW4gKEdldC1Db250ZW50IC1MaXRlcmFs
>> "%B64FILE%" echo UGF0aCAkc3QgLUVuY29kaW5nIFVURjggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7
>> "%B64FILE%" echo DQogICAgICAgIGlmICgkbG4gLW1hdGNoICdeXHMqR3VpZFxzKj1ccyooXHtbMC05YS1mQS1GLV17
>> "%B64FILE%" echo MzZ9XH0pXHMqJCcpIHsgcmV0dXJuICRtYXRjaGVzWzFdIH0NCiAgICB9DQogICAgcmV0dXJuICcn
>> "%B64FILE%" echo DQp9DQoNCiMgSXMgdGhpcyBib290IGVudHJ5IHN0aWxsIGluIHRoZSBCQ0QgKGV4aXN0ZW5jZSBv
>> "%B64FILE%" echo bmx5LCB0aGUgdGFyZ2V0IGlzIG5vdCBjaGVja2VkKQ0KZnVuY3Rpb24gVGVzdC1CY2RFbnRyeVBy
>> "%B64FILE%" echo ZXNlbnQgew0KICAgIHBhcmFtKFtzdHJpbmddJEd1aWQpDQogICAgaWYgKC1ub3QgJEd1aWQpIHsg
>> "%B64FILE%" echo cmV0dXJuICRmYWxzZSB9DQogICAgJHR4dCA9ICcnDQogICAgdHJ5IHsgJHR4dCA9ICgmIGJjZGVk
>> "%B64FILE%" echo aXQgL2VudW0gJEd1aWQgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNl
>> "%B64FILE%" echo IH0NCiAgICBpZiAoJExBU1RFWElUQ09ERSAtbmUgMCkgeyByZXR1cm4gJGZhbHNlIH0NCiAgICBp
>> "%B64FILE%" echo ZiAoJHR4dCAtbWF0Y2ggJ+aJvuS4jeWIsHxub3QgZm91bmR85peg5pWIfGludmFsaWR85ouS57ud
>> "%B64FILE%" echo fGRlbmllZCcpIHsgcmV0dXJuICRmYWxzZSB9DQogICAgcmV0dXJuICgkdHh0IC1tYXRjaCAnKD9p
>> "%B64FILE%" echo KWlkZW50aWZpZXJ85qCH6K+G56ymJykNCn0NCg0KIyBEZWxldGUgdGhlIC5ib290LnR4dCBuZXh0
>> "%B64FILE%" echo IHRvIHRoZSB2aGR4IGFsb25nIHdpdGggaXQuDQojIERlbGV0aW5nIG9ubHkgdGhlIHZoZHggd291
>> "%B64FILE%" echo bGQgbWFrZSB0aGUgbmV4dCBzY2FuIGNsYXNzaWZ5IHRoZSBlbXB0eSBzaGVsbCBhcyBCIGFuZCBh
>> "%B64FILE%" echo c2sgYWdhaW4sDQojIGFuZCBhIC5ib290LnR4dCBwb2ludGluZyBhdCBhIHZoZHggdGhhdCBubyBs
>> "%B64FILE%" echo b25nZXIgZXhpc3RzIGFsc28gbWlzbGVhZHMgb3RoZXIgdG9vbHMuDQpmdW5jdGlvbiBSZW1vdmUt
>> "%B64FILE%" echo VmhkU2FmZWx5IHsNCiAgICBwYXJhbSgkSXRlbSkNCiAgICB0cnkgew0KICAgICAgICBSZW1vdmUt
>> "%B64FILE%" echo SXRlbSAtTGl0ZXJhbFBhdGggJEl0ZW0uUGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3ANCiAg
>> "%B64FILE%" echo ICAgICAgU2F5ICIgICAgICAgICAgICAgZGVsZXRlZCIgJ0dyZWVuJw0KICAgICAgICAkc3QgPSBb
>> "%B64FILE%" echo U3lzdGVtLklPLlBhdGhdOjpDaGFuZ2VFeHRlbnNpb24oJEl0ZW0uUGF0aCwgJy5ib290LnR4dCcp
>> "%B64FILE%" echo DQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdCkgew0KICAgICAgICAgICAg
>> "%B64FILE%" echo UmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRzdCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUNCiAgICAgICAgfQ0KICAgIH0gY2F0Y2ggew0KICAgICAgICBTYXkgKCIgICAgICAg
>> "%B64FILE%" echo ICAgICAgZGVsZXRpb24gZmFpbGVkOiAiICsgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpICdSZWQnDQog
>> "%B64FILE%" echo ICAgICAgIFNheSAiICAgICAgICAgICAgIHVzdWFsbHkgYSBwcm9jZXNzIHN0aWxsIGhvbGRzIGl0
>> "%B64FILE%" echo IC0gcmVib290IGFuZCBydW4gdGhpcyB0b29sIGFnYWluLiIgJ1llbGxvdycNCiAgICB9DQp9DQoN
>> "%B64FILE%" echo CiRjYXRBID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0ICAgIyBpbnN0
>> "%B64FILE%" echo YWxsZWQgKGVudHJ5IHByZXNlbnQpDQokY2F0QiA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rp
>> "%B64FILE%" echo b25zLkFycmF5TGlzdCAgICMgaW5zdGFsbGVkIGJ5IHRoaXMgdG9vbGtpdCwgZW50cnkgZ29uZQ0K
>> "%B64FILE%" echo JGNhdEMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgICAjIG5vdCBj
>> "%B64FILE%" echo cmVhdGVkIGJ5IHRoaXMgdG9vbGtpdA0KDQpmb3JlYWNoICgkZiBpbiBAKEdldC1BbGxWaGR4Rmls
>> "%B64FILE%" echo ZSkpIHsNCiAgICAkc3ogPSAwDQogICAgdHJ5IHsgJHN6ID0gW21hdGhdOjpSb3VuZCgkZi5MZW5n
>> "%B64FILE%" echo dGggLyAxR0IsIDIpIH0gY2F0Y2gge30NCiAgICAkc3QgPSBbU3lzdGVtLklPLlBhdGhdOjpDaGFu
>> "%B64FILE%" echo Z2VFeHRlbnNpb24oJGYuRnVsbE5hbWUsICcuYm9vdC50eHQnKQ0KICAgICRoYXNTdGF0ZSA9IFRl
>> "%B64FILE%" echo c3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0DQogICAgJGd1aWQgPSAnJw0KICAgIGlmICgkaGFzU3Rh
>> "%B64FILE%" echo dGUpIHsgJGd1aWQgPSBHZXQtVmhkU3RhdGVHdWlkIC1QYXRoICRmLkZ1bGxOYW1lIH0NCiAgICAk
>> "%B64FILE%" echo aXRlbSA9IFtQU0N1c3RvbU9iamVjdF1AeyBQYXRoID0gJGYuRnVsbE5hbWU7IFNpemVHQiA9ICRz
>> "%B64FILE%" echo ejsgSGFzU3RhdGUgPSAkaGFzU3RhdGUgfQ0KICAgIGlmIChUZXN0LUJjZEVudHJ5UHJlc2VudCAt
>> "%B64FILE%" echo R3VpZCAkZ3VpZCkgew0KICAgICAgICBbdm9pZF0kY2F0QS5BZGQoJGl0ZW0pDQogICAgfSBlbHNl
>> "%B64FILE%" echo aWYgKCRoYXNTdGF0ZSkgew0KICAgICAgICBbdm9pZF0kY2F0Qi5BZGQoJGl0ZW0pDQogICAgfSBl
>> "%B64FILE%" echo bHNlIHsNCiAgICAgICAgW3ZvaWRdJGNhdEMuQWRkKCRpdGVtKQ0KICAgIH0NCn0NCg0KaWYgKCRj
>> "%B64FILE%" echo YXRBLkNvdW50IC1ndCAwKSB7DQogICAgU2F5ICIgICAgICBUaGVzZSBhcmUgaW5zdGFsbGVkIHdp
>> "%B64FILE%" echo dGggdGhlaXIgYm9vdCBlbnRyeSBpbnRhY3Q7IHRoaXMgdG9vbCBuZXZlciB0b3VjaGVzIHRoZW06
>> "%B64FILE%" echo IiAnRGFya0dyYXknDQogICAgZm9yZWFjaCAoJGl0IGluICRjYXRBKSB7DQogICAgICAgIFNheSAo
>> "%B64FILE%" echo KCcgICAgICAgIHswfSAgICh7MX0gR0IpJyAtZiAkaXQuUGF0aCwgJGl0LlNpemVHQikpICdEYXJr
>> "%B64FILE%" echo R3JheScNCiAgICB9DQogICAgU2F5ICIgICAgICAodG8gZGVsZXRlIHRoZW0gdXNlIFVuaW5zdGFs
>> "%B64FILE%" echo bC1TeXN0ZW0uYmF0LCBpdCBhbHNvIGNsZWFucyB0aGUgYm9vdCBtZW51KSIgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo fQ0KDQppZiAoKCRjYXRCLkNvdW50ICsgJGNhdEMuQ291bnQpIC1lcSAwKSB7DQogICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICBOb3RoaW5nIHRvIGhhbmRsZSwgdGhlIGVudmlyb25tZW50IGlzIGFscmVhZHkgY2xlYW4i
>> "%B64FILE%" echo ICdEYXJrR3JheScNCn0gZWxzZSB7DQogICAgaWYgKCRjYXRCLkNvdW50IC1ndCAwKSB7DQogICAg
>> "%B64FILE%" echo ICAgIFNheSAiIg0KICAgICAgICBTYXkgKCIgICAgICBbQl0gaW5zdGFsbGVkIGJ5IHRoaXMgdG9v
>> "%B64FILE%" echo bGtpdCBidXQgdGhlIGJvb3QgZW50cnkgaXMgZ29uZSAoezB9KSIgLWYgJGNhdEIuQ291bnQpICdX
>> "%B64FILE%" echo aGl0ZScNCiAgICAgICAgU2F5ICIgICAgICAgICAgVGhlIC5ib290LnR4dCBsZWZ0IGJ5IHRoaXMg
>> "%B64FILE%" echo dG9vbGtpdCBzaXRzIG5leHQgdG8gdGhlbTsgZGVsZXRpbmcgdGhlc2UgY2Fubm90IGFmZmVjdCBh
>> "%B64FILE%" echo bnkgYm9vdGFibGUgc3lzdGVtLiIgJ0RhcmtHcmF5Jw0KICAgICAgICBmb3JlYWNoICgkaXQgaW4g
>> "%B64FILE%" echo JGNhdEIpIHsNCiAgICAgICAgICAgIFNheSAoKCcgICAgICAgICAgezB9ICAgKHsxfSBHQiknIC1m
>> "%B64FILE%" echo ICRpdC5QYXRoLCAkaXQuU2l6ZUdCKSkgJ1doaXRlJw0KICAgICAgICAgICAgJGFucyA9IFJlYWQt
>> "%B64FILE%" echo SG9zdCAiICAgICAgICAgICAgIERlbGV0ZSB0aGVtPyBUeXBlIHkgdG8gZGVsZXRlLCBvciBwcmVz
>> "%B64FILE%" echo cyBFbnRlciB0byBza2lwIg0KICAgICAgICAgICAgaWYgKCRhbnMgLWFuZCAoJGFucy5UcmltKCkg
>> "%B64FILE%" echo LWllcSAneScpKSB7DQogICAgICAgICAgICAgICAgUmVtb3ZlLVZoZFNhZmVseSAtSXRlbSAkaXQN
>> "%B64FILE%" echo CiAgICAgICAgICAgIH0gZWxzZSB7DQogICAgICAgICAgICAgICAgU2F5ICIgICAgICAgICAgICAg
>> "%B64FILE%" echo c2tpcHBlZCIgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQogICAgfQ0KICAg
>> "%B64FILE%" echo IGlmICgkY2F0Qy5Db3VudCAtZ3QgMCkgew0KICAgICAgICBTYXkgIiINCiAgICAgICAgU2F5ICgi
>> "%B64FILE%" echo ICAgICAgW0NdIG5vdCBjcmVhdGVkIGJ5IHRoaXMgdG9vbGtpdCAoezB9KSIgLWYgJGNhdEMuQ291
>> "%B64FILE%" echo bnQpICdXaGl0ZScNCiAgICAgICAgU2F5ICIgICAgICAgICAgTm8gLmJvb3QudHh0IGZyb20gdGhp
>> "%B64FILE%" echo cyB0b29sa2l0LiBUaGV5IG1heSBiZSBIeXBlci1WIHZpcnR1YWwgZGlza3MsIGFub3RoZXIgaW5z
>> "%B64FILE%" echo dGFsbCIgJ0RhcmtHcmF5Jw0KICAgICAgICBTYXkgIiAgICAgICAgICB0b29sLCBvciBhIGJhY2t1
>> "%B64FILE%" echo cCBvZiB5b3VyIG93bi4gTm90IGRlbGV0ZWQgYnkgZGVmYXVsdCwgYW5kIG5vdCByZWNvbW1lbmRl
>> "%B64FILE%" echo ZC4iICdEYXJrR3JheScNCiAgICAgICAgZm9yZWFjaCAoJGl0IGluICRjYXRDKSB7DQogICAgICAg
>> "%B64FILE%" echo ICAgICAkZm4gPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGaWxlTmFtZSgkaXQuUGF0aCkNCiAgICAg
>> "%B64FILE%" echo ICAgICAgIFNheSAoKCcgICAgICAgICAgezB9ICAgKHsxfSBHQiknIC1mICRpdC5QYXRoLCAkaXQu
>> "%B64FILE%" echo U2l6ZUdCKSkgJ1doaXRlJw0KICAgICAgICAgICAgJGFucyA9IFJlYWQtSG9zdCAoIiAgICAgICAg
>> "%B64FILE%" echo ICAgICBUbyByZWFsbHkgZGVsZXRlIG9uZSwgdHlwZSBpdHMgZmlsZSBuYW1lIHswfSAob3IgcHJl
>> "%B64FILE%" echo c3MgRW50ZXIgdG8gc2tpcCkiIC1mICRmbikNCiAgICAgICAgICAgIGlmICgtbm90ICRhbnMpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICBza2lwcGVkIiAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgICAgICAgICB9IGVsc2VpZiAoJGFucy5UcmltKCkgLWllcSAkZm4pIHsNCiAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICBSZW1vdmUtVmhkU2FmZWx5IC1JdGVtICRpdA0KICAgICAgICAgICAgfSBlbHNlIHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAjIERvIG5vdCBzYXkgIndyb25nIGZpbGUgbmFtZSIgaW4geWVsbG93IC0g
>> "%B64FILE%" echo bWFueSBwZW9wbGUgdHJ5IHkgLyB5ZXMgZmlyc3QgYmVjYXVzZSB0aGV5IGRvIHdhbnQgaXQgZGVs
>> "%B64FILE%" echo ZXRlZCwNCiAgICAgICAgICAgICAgICAjIHRoZXkganVzdCBkbyBub3Qga25vdyB0aGF0IHRoaXMg
>> "%B64FILE%" echo cHJvbXB0IGRvZXMgbm90IHRha2UgeS4gRXhwbGFpbiBjYWxtbHkgaG93IHRvIGRlbGV0ZSwgbmV2
>> "%B64FILE%" echo ZXIgc2NvbGQuDQogICAgICAgICAgICAgICAgU2F5ICgiICAgICAgICAgICAgIHNraXBwZWQuIFRv
>> "%B64FILE%" echo IGRlbGV0ZSB0aGlzIG9uZSwgdHlwZSBpdHMgZnVsbCBmaWxlIG5hbWU6IHswfSIgLWYgJGZuKSAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgICAgICAgICAgaWYgKCRhbnMuVHJpbSgpIC1pbWF0Y2ggJ14oeXx5
>> "%B64FILE%" echo ZXN85pivfOWIoHzliKDpmaR8b2spJCcpIHsNCiAgICAgICAgICAgICAgICAgICAgU2F5ICIgICAg
>> "%B64FILE%" echo ICAgICAgICAgKHRoaXMgcHJvbXB0IGRlbGliZXJhdGVseSBkb2VzIG5vdCBhY2NlcHQgeSAtIGl0
>> "%B64FILE%" echo IGd1YXJkcyBhZ2FpbnN0IGRlbGV0aW5nIHNvbWVib2R5IGVsc2UncyB2aXJ0dWFsIGRpc2spIiAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQog
>> "%B64FILE%" echo ICAgfQ0KfQ0KDQojIC0tLS0tLS0tLS0gU3RlcCA0ICh2MS4yOSk6IGNsZWFuIHRoZSBjb21wYW5p
>> "%B64FILE%" echo b24gbG9ncyBiY2RlZGl0IGxlYXZlcyB3aGVuIGV4cG9ydGluZyB0aGUgQkNEIC0tLS0tLS0tLS0N
>> "%B64FILE%" echo CiMNCiMgYmNkZWRpdCAvZXhwb3J0IHdyaXRlcyBhIHJlZ2lzdHJ5IGhpdmUsIGFuZCBXaW5kb3dz
>> "%B64FILE%" echo IGRyb3BzIGNvbXBhbmlvbiB0cmFuc2FjdGlvbiBsb2dzIG5leHQgdG8gaXQ6DQojICAgeHh4LmJj
>> "%B64FILE%" echo ZC5MT0cgIHh4eC5iY2QuTE9HMSAgeHh4LmJjZC5MT0cyDQojIE1lYXN1cmVkIG9uIHJlYWwgaGFy
>> "%B64FILE%" echo ZHdhcmU6IDMxIC5iY2QuTE9HKiBmaWxlcyBwaWxlZCB1cCBpbiB0aGUgcm9vdCBvZiBEOlwgYW5k
>> "%B64FILE%" echo IGFub3RoZXIgMTggaW4gRDpcVmlydHVhbERpc2tzXC4NCiMgVGhlc2UgY29tcGFuaW9uIGZpbGVz
>> "%B64FILE%" echo IGNhcnJ5IHRoZSBIaWRkZW4gKyBTeXN0ZW0gYXR0cmlidXRlcywgc28gR2V0LUNoaWxkSXRlbSBt
>> "%B64FILE%" echo dXN0IGJlIGNhbGxlZCB3aXRoIC1Gb3JjZSwNCiMgb3RoZXJ3aXNlIG5vdCBhIHNpbmdsZSBvbmUg
>> "%B64FILE%" echo aXMgZm91bmQgKGV4YWN0bHkgd2hhdCB2MS4yOSBtaXNzZWQsIG1ha2luZyB0aGUgZmVhdHVyZSBz
>> "%B64FILE%" echo aWxlbnRseSBkbyBub3RoaW5nKS4NCiMgVGhleSBhcmUgaW50ZXJtZWRpYXRlIGZpbGVzIG9mIHRo
>> "%B64FILE%" echo ZSBleHBvcnQsIHVzZWxlc3MgZm9yIHJlc3RvcmluZyB0aGUgQkNELCBhbmQgZGVsZXRpbmcgdGhl
>> "%B64FILE%" echo bSBkb2VzIG5vdCBhZmZlY3QgdGhlIC5iY2QgYmFja3VwLg0KIyBTaW5jZSB2MS4yOSB0aGUgaW5z
>> "%B64FILE%" echo dGFsbGVyL3JlcGFpciB0b29sIGV4cG9ydCB0byBhIHRlbXAgZm9sZGVyIGZpcnN0IGFuZCB0aGVu
>> "%B64FILE%" echo IGNvcHksIHNvIG5vIG5ldyBvbmVzIGFwcGVhcjsNCiMgdGhpcyBzZWN0aW9uIGlzIHRoZSBjbGVh
>> "%B64FILE%" echo bi11cCBmb3Igd2hhdCBoYXMgYWxyZWFkeSBwaWxlZCB1cC4NCiRzdHJheUxvZ3MgPSBOZXctT2Jq
>> "%B64FILE%" echo ZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QNCiMNCiMgW3YxLjMxIGhhcmRlbmluZ10g
>> "%B64FILE%" echo VGhpcyB1c2VkIHRvIHNjYW4gdGhlIHJvb3QgYW5kIGZpcnN0LWxldmVsIHN1YmZvbGRlcnMgb2Yg
>> "%B64FILE%" echo NiBkcml2ZXMgd2l0aCB0aGUgJyouYmNkLkxPRyonIHdpbGRjYXJkDQojIGFuZCB0aGVuIFJlbW92
>> "%B64FILE%" echo ZS1JdGVtIGV2ZXJ5dGhpbmcuIEluIHByYWN0aWNlIG5vIHN5c3RlbSBmaWxlIHdhcyBldmVyIGhp
>> "%B64FILE%" echo dCAtIGJ1dCB0aGF0IHdhcyBsdWNrIGZyb20gYSAtRmlsdGVyIDguMw0KIyBzaG9ydC1uYW1lIHF1
>> "%B64FILE%" echo aXJrIHRoYXQgaGFwcGVuZWQgbm90IHRvIG1hdGNoICJCQ0QuTE9HIiwgbm90IHByb3RlY3Rpb24g
>> "%B64FILE%" echo aW4gdGhlIGNvZGUuIE1lYW53aGlsZQ0KIyBDOlxCb290XEJDRC5MT0cgLyBCQ0QuTE9HMSAvIEJD
>> "%B64FILE%" echo RC5MT0cyIGFyZSB0aGUgKip0cmFuc2FjdGlvbiBsb2dzIG9mIHRoZSBhY3RpdmUgQkNEKiosIHR3
>> "%B64FILE%" echo byBsZXR0ZXJzIGF3YXksDQojIHNvIGFub3RoZXIgc3BlbGxpbmcgb3IgYW5vdGhlciBtYWNoaW5l
>> "%B64FILE%" echo IGNvdWxkIGhpdCB0aGVtLCBhbmQgZGVsZXRpbmcgdGhlbSByaXNrcyBhIGNvcnJ1cHRlZCBib290
>> "%B64FILE%" echo IGNvbmZpZ3VyYXRpb24uDQojDQojIEl0IGlzIGEgd2hpdGVsaXN0IG5vdzogb25seSB0aGUgZXhh
>> "%B64FILE%" echo Y3QgZm9ybWF0IHRoaXMgdG9vbGtpdCBoYXMgZXhwb3J0ZWQgb3ZlciB0aGUgdmVyc2lvbnMgaXMg
>> "%B64FILE%" echo bWF0Y2hlZCwgbm90aGluZyBlbHNlLg0KIyAgIGJjZC1iYWNrdXAtPHl5eXlNTWRkPi08SEhtbXNz
>> "%B64FILE%" echo Pi5iY2QuTE9HIC8gLkxPRzEgLyAuTE9HMg0KIyAgIGJjZC1iYWNrdXAtZml4LTx5eXl5TU1kZD4t
>> "%B64FILE%" echo PEhIbW1zcz4uYmNkLkxPRyAuLi4NCiMgICBiY2QtcmVzY3VlLTx5eXl5TU1kZD4tPEhIbW1zcz4u
>> "%B64FILE%" echo YmNkLkxPRyAuLi4gICAoZWFybHkgdmVyc2lvbnMgdXNlZCB0aGlzIHByZWZpeCkNCiMgVGhlIGtl
>> "%B64FILE%" echo eSBwb2ludDogaXQgbXVzdCBzdGFydCB3aXRoIGJjZC0sIGNhcnJ5IGFuIDgtZGlnaXQgZGF0ZSBw
>> "%B64FILE%" echo bHVzIGEgNi1kaWdpdCB0aW1lLCBhbmQgZW5kIGluIC5iY2QuDQojIE5vbmUgb2YgdGhlIHRocmVl
>> "%B64FILE%" echo IHN5c3RlbSBuYW1lcyBDOlxCb290XEJDRC5MT0cgbWF0Y2hlcyBhbnkgb2YgdGhhdCwgc28gaXQg
>> "%B64FILE%" echo aXMgc3RydWN0dXJhbGx5IGltcG9zc2libGUgdG8gc2VsZWN0IHRoZW0uDQojIFRoZSBzeXN0ZW0g
>> "%B64FILE%" echo Zm9sZGVycyBhcmUgZXhjbHVkZWQgYWdhaW4gYXQgZGlyZWN0b3J5IGxldmVsLCBhcyBhIHNlY29u
>> "%B64FILE%" echo ZCBsaW5lIG9mIGRlZmVuY2UuDQokaXNTdHJheUJjZExvZyA9IHsNCiAgICBwYXJhbShbc3RyaW5n
>> "%B64FILE%" echo XSRuKQ0KICAgIHJldHVybiAoJG4gLW1hdGNoICdeYmNkLVthLXpdKyg/Oi1bYS16XSspKi1cZHs4
>> "%B64FILE%" echo fS1cZHs2fVwuYmNkXC5MT0dbMC05XT8kJykNCn0NCiRza2lwU3ViRGlycyA9ICdeKFdpbmRvd3N8
>> "%B64FILE%" echo UHJvZ3JhbSBGaWxlcy4qfFwkUmVjeWNsZVwuQmlufFN5c3RlbSBWb2x1bWUgSW5mb3JtYXRpb258
>> "%B64FILE%" echo VXNlcnN8Qm9vdHxSZWNvdmVyeXxFRkl8UGVyZkxvZ3MpJCcNCmZvcmVhY2ggKCRydCBpbiBAKCdD
>> "%B64FILE%" echo OlwnLCAnRDpcJywgJ0U6XCcsICdGOlwnLCAnRzpcJywgJ0g6XCcpKSB7DQogICAgaWYgKC1ub3Qg
>> "%B64FILE%" echo KFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHJ0KSkgeyBjb250aW51ZSB9DQogICAgZm9yZWFjaCAo
>> "%B64FILE%" echo JGYgaW4gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkcnQgLUZpbGUgLUZvcmNlIC1FQSBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJiAkaXNTdHJheUJjZExvZyAkZi5OYW1l
>> "%B64FILE%" echo KSB7IFt2b2lkXSRzdHJheUxvZ3MuQWRkKCRmKSB9DQogICAgfQ0KICAgIGZvcmVhY2ggKCRkIGlu
>> "%B64FILE%" echo IEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJHJ0IC1EaXJlY3RvcnkgLUZvcmNlIC1FQSBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJGQuTmFtZSAtbWF0Y2ggJHNraXBTdWJE
>> "%B64FILE%" echo aXJzKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gQChHZXQtQ2hpbGRJdGVt
>> "%B64FILE%" echo IC1MaXRlcmFsUGF0aCAkZC5GdWxsTmFtZSAtRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGlu
>> "%B64FILE%" echo dWUpKSB7DQogICAgICAgICAgICBpZiAoJiAkaXNTdHJheUJjZExvZyAkZi5OYW1lKSB7IFt2b2lk
>> "%B64FILE%" echo XSRzdHJheUxvZ3MuQWRkKCRmKSB9DQogICAgICAgIH0NCiAgICB9DQp9DQoNCmlmICgkc3RyYXlM
>> "%B64FILE%" echo b2dzLkNvdW50IC1ndCAwKSB7DQogICAgJHN6ID0gKCRzdHJheUxvZ3MgfCBNZWFzdXJlLU9iamVj
>> "%B64FILE%" echo dCAtUHJvcGVydHkgTGVuZ3RoIC1TdW0pLlN1bQ0KICAgIFNheSAiIg0KICAgIFNheSAoIiAgICAg
>> "%B64FILE%" echo IFtleHRyYV0gY29tcGFuaW9uIGxvZ3MgbGVmdCBieSBiY2RlZGl0IHdoZW4gZXhwb3J0aW5nIHRo
>> "%B64FILE%" echo ZSBCQ0QgKHswfSBmaWxlcywgezE6TjF9IE1CIGluIHRvdGFsKSIgLWYgJHN0cmF5TG9ncy5Db3Vu
>> "%B64FILE%" echo dCwgKCRzeiAvIDFNQikpICdXaGl0ZScNCiAgICBTYXkgIiAgICAgICAgICBUaGVzZSBhcmUgdGhl
>> "%B64FILE%" echo IC5MT0cgLyAuTE9HMSAvIC5MT0cyIGZpbGVzIG5leHQgdG8gYmNkLWJhY2t1cC0qLmJjZC4iICdE
>> "%B64FILE%" echo YXJrR3JheScNCiAgICBTYXkgIiAgICAgICAgICBUaGV5IGFyZSBpbnRlcm1lZGlhdGUgZmlsZXMg
>> "%B64FILE%" echo b2YgdGhlIGV4cG9ydDsgZGVsZXRpbmcgdGhlbSBhZmZlY3RzIG5laXRoZXIgdGhlIC5iY2QgYmFj
>> "%B64FILE%" echo a3VwIG5vciBib290aW5nLiIgJ0RhcmtHcmF5Jw0KICAgIFNheSAiICAgICAgICAgIE9ubHkgYmFj
>> "%B64FILE%" echo a3VwIG5hbWVzIGV4cG9ydGVkIGJ5IHRoaXMgdG9vbGtpdCBtYXRjaDsgdGhlIHN5c3RlbSdzIG93
>> "%B64FILE%" echo biBDOlxCb290XEJDRC5MT0cgaXMgb3V0IG9mIHNjb3BlIGFuZCBuZXZlciB0b3VjaGVkLiIgJ0Rh
>> "%B64FILE%" echo cmtHcmF5Jw0KICAgIGZvcmVhY2ggKCRmIGluIEAoJHN0cmF5TG9ncyB8IFNvcnQtT2JqZWN0IEZ1
>> "%B64FILE%" echo bGxOYW1lIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgOCkpIHsNCiAgICAgICAgU2F5ICgiICAgICAg
>> "%B64FILE%" echo ICAgICIgKyAkZi5GdWxsTmFtZSkgJ0RhcmtHcmF5Jw0KICAgIH0NCiAgICBpZiAoJHN0cmF5TG9n
>> "%B64FILE%" echo cy5Db3VudCAtZ3QgOCkgeyBTYXkgKCIgICAgICAgICAgLi4uIGFuZCB7MH0gbW9yZSIgLWYgKCRz
>> "%B64FILE%" echo dHJheUxvZ3MuQ291bnQgLSA4KSkgJ0RhcmtHcmF5JyB9DQogICAgJGFucyA9IFJlYWQtSG9zdCAi
>> "%B64FILE%" echo ICAgICAgICAgICAgIERlbGV0ZSB0aGVtIGFsbD8gVHlwZSB5IHRvIGRlbGV0ZSwgb3IgcHJlc3Mg
>> "%B64FILE%" echo RW50ZXIgdG8gc2tpcCINCiAgICBpZiAoJGFucyAtYW5kICgkYW5zLlRyaW0oKSAtaWVxICd5Jykp
>> "%B64FILE%" echo IHsNCiAgICAgICAgJG9rTiA9IDANCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJHN0cmF5TG9ncykg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRmLkZ1bGxOYW1l
>> "%B64FILE%" echo IC1Gb3JjZSAtRUEgU3RvcDsgJG9rTisrIH0gY2F0Y2gge30NCiAgICAgICAgfQ0KICAgICAgICBT
>> "%B64FILE%" echo YXkgKCIgICAgICAgICAgICAgZGVsZXRlZCB7MH0gLyB7MX0iIC1mICRva04sICRzdHJheUxvZ3Mu
>> "%B64FILE%" echo Q291bnQpICdHcmVlbicNCiAgICAgICAgaWYgKCRva04gLWx0ICRzdHJheUxvZ3MuQ291bnQpIHsg
>> "%B64FILE%" echo U2F5ICIgICAgICAgICAgICAgdGhlIG9uZXMgdGhhdCBjYW5ub3QgYmUgZGVsZXRlZCBhcmUgdXN1
>> "%B64FILE%" echo YWxseSBoZWxkIGJ5IGFub3RoZXIgcHJvZ3JhbTsgcmVib290IGFuZCByZXJ1biIgJ0RhcmtHcmF5
>> "%B64FILE%" echo JyB9DQogICAgfSBlbHNlIHsNCiAgICAgICAgU2F5ICIgICAgICAgICAgICAgc2tpcHBlZCAobm90
>> "%B64FILE%" echo aGluZyBkZWxldGVkKSIgJ0RhcmtHcmF5Jw0KICAgIH0NCn0NCg0KU2F5ICIiDQpTYXkgIiAgLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo IiAnRGFya0dyYXknDQpTYXkgIiAgQ2xlYW51cCBjb21wbGV0ZS4iICdHcmVlbicNClNheSAiIg0K
>> "%B64FILE%" echo U2F5ICIgIEhvdyB0byByZWluc3RhbGwgcHJvcGVybHk6IiAnV2hpdGUnDQpTYXkgIiAgICAxLiBE
>> "%B64FILE%" echo b3VibGUtY2xpY2sgSW5zdGFsbC1TeXN0ZW0uYmF0IGFnYWluIiAnRGFya0dyYXknDQpTYXkgIiAg
>> "%B64FILE%" echo ICAgICB0aGUgcHJvZ3Jlc3MgYmFyIHNob3dzIGhvdyBtYW55IEdCIGhhdmUgYmVlbiB3cml0dGVu
>> "%B64FILE%" echo OyBhcyBsb25nIGFzIHRoZSBudW1iZXIgZ3Jvd3MgaXQgaXMgd29ya2luZywgZG8gbm90IGNsb3Nl
>> "%B64FILE%" echo IGl0IiAnRGFya0dyYXknDQpTYXkgIiAgICAyLiBSZWJvb3QgYWZ0ZXIgaXQgZmluaXNoZXMgYW5k
>> "%B64FILE%" echo IGNob29zZSB0aGUgbmV3IHN5c3RlbSBpbiB0aGUgYm9vdCBtZW51IiAnRGFya0dyYXknDQpTYXkg
>> "%B64FILE%" echo IiINClJlYWQtSG9zdCAiICBQcmVzcyBFbnRlciB0byBleGl0Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=19020"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" -OriginDir "%ORIGIN%" %*
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
