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
>> "%B64FILE%" echo Y3JpcHQ6VmVyc2lvbiA9ICcxLjMxJw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQoN
>> "%B64FILE%" echo CnRyeSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIkNsZWFuIEluc3RhbGwgUmVzaWR1
>> "%B64FILE%" echo ZSB2JCgkU2NyaXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3QiIH0gY2F0Y2gge30NCg0KZnVu
>> "%B64FILE%" echo Y3Rpb24gU2F5IHsNCiAgICBwYXJhbShbc3RyaW5nXSRUZXh0LCBbc3RyaW5nXSRDb2xvciA9ICdH
>> "%B64FILE%" echo cmF5JykNCiAgICBXcml0ZS1Ib3N0ICRUZXh0IC1Gb3JlZ3JvdW5kQ29sb3IgJENvbG9yDQp9DQoN
>> "%B64FILE%" echo ClNheSAiIg0KU2F5ICIgIENsZWFuIEluc3RhbGwgUmVzaWR1ZSAgdiQoJFNjcmlwdDpWZXJzaW9u
>> "%B64FILE%" echo KSIgJ0N5YW4nDQpTYXkgIiAgQXV0aG9yOiBjb25uZWN0c2VnYWJvdCIgJ0RhcmtHcmF5Jw0KU2F5
>> "%B64FILE%" echo ICIgIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLSIgJ0RhcmtHcmF5Jw0KU2F5ICIiDQoNCiRhZG1pbiA9IChbU2VjdXJpdHkuUHJpbmNp
>> "%B64FILE%" echo cGFsLldpbmRvd3NQcmluY2lwYWxdW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzSWRlbnRpdHld
>> "%B64FILE%" echo OjpHZXRDdXJyZW50KCkpLklzSW5Sb2xlKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0
>> "%B64FILE%" echo SW5Sb2xlXTo6QWRtaW5pc3RyYXRvcikNCmlmICgtbm90ICRhZG1pbikgew0KICAgIFNheSAiICBb
>> "%B64FILE%" echo RVJST1JdIEFkbWluaXN0cmF0b3IgcmlnaHRzIGFyZSByZXF1aXJlZC4gQ2xvc2UgdGhpcyB3aW5k
>> "%B64FILE%" echo b3csIHJpZ2h0LWNsaWNrIHRoaXMgZmlsZSAtPiBSdW4gYXMgYWRtaW5pc3RyYXRvci4iICdSZWQn
>> "%B64FILE%" echo DQogICAgU2F5ICIiDQogICAgUmVhZC1Ib3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQiDQogICAg
>> "%B64FILE%" echo ZXhpdCAxDQp9DQoNCiMgLS0tLS0tLS0tLSAxLiBLaWxsIGxlZnRvdmVyIGRpc20gLS0tLS0tLS0t
>> "%B64FILE%" echo LQ0KU2F5ICJbMS8zXSBLaWxsaW5nIGxlZnRvdmVyIGRpc20uZXhlIC4uLiINCiRraWxsZWQgPSAw
>> "%B64FILE%" echo DQpmb3JlYWNoICgkcCBpbiBAKEdldC1Qcm9jZXNzIC1OYW1lIGRpc20sIERpc21Ib3N0IC1FcnJv
>> "%B64FILE%" echo ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgIHRyeSB7DQogICAgICAgIFN0b3AtUHJv
>> "%B64FILE%" echo Y2VzcyAtSWQgJHAuSWQgLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wDQogICAgICAgICRraWxsZWQr
>> "%B64FILE%" echo Kw0KICAgICAgICBTYXkgKCIgICAgICBraWxsZWQgezB9IChQSUQgezF9KSIgLWYgJHAuUHJvY2Vz
>> "%B64FILE%" echo c05hbWUsICRwLklkKSAnRGFya0dyYXknDQogICAgfSBjYXRjaCB7DQogICAgICAgIFNheSAoIiAg
>> "%B64FILE%" echo ICAgIGZhaWxlZCB0byBraWxsIHswfSAoUElEIHsxfSk6IHsyfSIgLWYgJHAuUHJvY2Vzc05hbWUs
>> "%B64FILE%" echo ICRwLklkLCAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1llbGxvdycNCiAgICB9DQp9DQppZiAoJGtp
>> "%B64FILE%" echo bGxlZCAtZXEgMCkgeyBTYXkgIiAgICAgIG5vIHByb2Nlc3MgbmVlZGVkIGtpbGxpbmciICdEYXJr
>> "%B64FILE%" echo R3JheScgfQ0KU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA4MDANCg0KIyAtLS0tLS0tLS0tIDIu
>> "%B64FILE%" echo IERpc21vdW50IGV2ZXJ5IHZpcnR1YWwgZGlzayAtLS0tLS0tLS0tDQpTYXkgIlsyLzNdIERpc21v
>> "%B64FILE%" echo dW50aW5nIG1vdW50ZWQgdmlydHVhbCBkaXNrcyAuLi4iDQokdmRzID0gQChHZXQtRGlzayAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7IFtzdHJpbmddJF8uQnVz
>> "%B64FILE%" echo VHlwZSAtZXEgJ0ZpbGUgQmFja2VkIFZpcnR1YWwnIH0pDQppZiAoJHZkcy5Db3VudCAtZXEgMCkg
>> "%B64FILE%" echo ew0KICAgIFNheSAiICAgICAgbm8gbW91bnRlZCB2aXJ0dWFsIGRpc2siICdEYXJrR3JheScNCn0g
>> "%B64FILE%" echo ZWxzZSB7DQogICAgZm9yZWFjaCAoJGQgaW4gJHZkcykgew0KICAgICAgICAkbG9jID0gW3N0cmlu
>> "%B64FILE%" echo Z10kZC5Mb2NhdGlvbg0KICAgICAgICBTYXkgKCIgICAgICBEaXNrIHswfTogezF9IiAtZiAkZC5O
>> "%B64FILE%" echo dW1iZXIsICRsb2MpICdEYXJrR3JheScNCiAgICAgICAgaWYgKC1ub3QgJGxvYykgeyBjb250aW51
>> "%B64FILE%" echo ZSB9DQogICAgICAgICRkcEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICgiZGV0YWNoX3swfS50
>> "%B64FILE%" echo eHQiIC1mICRkLk51bWJlcikNCiAgICAgICAgQCgNCiAgICAgICAgICAgICJzZWxlY3QgdmRpc2sg
>> "%B64FILE%" echo ZmlsZT1gIiRsb2NgIiIsDQogICAgICAgICAgICAnZGV0YWNoIHZkaXNrIG5vZXJyJywNCiAgICAg
>> "%B64FILE%" echo ICAgICAgICdleGl0Jw0KICAgICAgICApIHwgU2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRkcEZp
>> "%B64FILE%" echo bGUgLUVuY29kaW5nIERlZmF1bHQNCiAgICAgICAgJHIgPSAmIGRpc2twYXJ0IC9zICRkcEZpbGUg
>> "%B64FILE%" echo Mj4mMSB8IE91dC1TdHJpbmcNCiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZp
>> "%B64FILE%" echo bGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQogICAgICAgIGlmICgkciAt
>> "%B64FILE%" echo bWF0Y2ggJ3N1Y2Nlc3NmdWxseXzmiJDlip8nKSB7IFNheSAiICAgICAgZGlzbW91bnRlZCIgJ0dy
>> "%B64FILE%" echo ZWVuJyB9DQogICAgICAgIGVsc2UgeyBTYXkgKCIgICAgICBkaXNtb3VudCByZXN1bHQ6ICIgKyAo
>> "%B64FILE%" echo JHIgLXJlcGxhY2UgIlxzKyIsICcgJykuVHJpbSgpKSAnWWVsbG93JyB9DQogICAgfQ0KfQ0KU3Rh
>> "%B64FILE%" echo cnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA4MDANCg0KIyAtLS0tLS0tLS0tIDMuIEhhbmRsZSB2aGR4
>> "%B64FILE%" echo IGZpbGVzIHdpdGhvdXQgYSBib290IGVudHJ5IC0tLS0tLS0tLS0NCiMgdjEuMCBvbmx5IGtuZXcg
>> "%B64FILE%" echo dGhlIGhhcmQtY29kZWQgTmV3U3lzdGVtRGlzay52aGR4LiBTaW5jZSB2MS4xMSB0aGUgaW5zdGFs
>> "%B64FILE%" echo bGVyIGFsbG93cyBjdXN0b20gbmFtZXMgYW5kIGZvbGRlcnMsDQojIHNvIGEgaGFuZyBhdCBFOlxW
>> "%B64FILE%" echo SERcbWFpbWFpLnZoZHggd2FzIGludmlzaWJsZSBoZXJlIGFuZCB0aG9zZSAyMEdCIHN0YXllZCBv
>> "%B64FILE%" echo Y2N1cGllZCBmb3JldmVyLg0KIw0KIyBCdXQgIm5vIGJvb3QgZW50cnkiIGRvZXMgbm90IG1lYW4g
>> "%B64FILE%" echo Imp1bmsgZnJvbSB0aGlzIHRvb2xraXQiLiBIeXBlci1WIGRpc2tzLCBvdGhlciBpbnN0YWxsIHRv
>> "%B64FILE%" echo b2xzIGFuZCB2aGR4IGZpbGVzDQojIHlvdSBwbGFjZWQgeW91cnNlbGYgYWxzbyBoYXZlIG5vIC5i
>> "%B64FILE%" echo b290LnR4dC4gdjEuMSBsaXN0ZWQgdGhlbSBhbGwgYW5kIGFza2VkICJkZWxldGU/IiwgdG9nZXRo
>> "%B64FILE%" echo ZXIgd2l0aA0KIyBhIGhpbnQgdGhhdCAiZGVsZXRpbmcgZnJlZXMgMjBHQiIgLSB0aGF0IHdhcyBl
>> "%B64FILE%" echo bmNvdXJhZ2luZyB1c2VycyB0byBwcmVzcyB5IGFuZCBkZWxldGUgb3RoZXIgcGVvcGxlJ3MgZGF0
>> "%B64FILE%" echo YSwNCiMgYW5kICJqdXN0IHByZXNzIEVudGVyIHRvIHNraXAiIHdhcyBsdWNrLCBub3QgZGVzaWdu
>> "%B64FILE%" echo Lg0KIw0KIyBTaW5jZSB2MS4yIHRoZXkgYXJlIGhhbmRsZWQgaW4gdGhyZWUgY2F0ZWdvcmllcywg
>> "%B64FILE%" echo c2VlIHRoZSBmaWxlIGhlYWRlci4NClNheSAiWzMvM10gQ2hlY2tpbmcgdmlydHVhbCBkaXNrcyB3
>> "%B64FILE%" echo aXRoIG5vIGJvb3QgZW50cnkgLi4uIg0KDQojIFNjYW4gYWxsIGRpc2tzIGZvciAqLnZoZHg6IHBy
>> "%B64FILE%" echo dW5lIGJ5IGZvbGRlciBuYW1lIG9ubHksIG5ldmVyIGVudGVyaW5nIHN5c3RlbSBmb2xkZXJzIG9y
>> "%B64FILE%" echo IHRoZSByZWN5Y2xlIGJpbg0KIyA+Pj4gQ09NTU9OOkdldC1BbGxWaGR4RmlsZQ0KIyBJbmplY3Rl
>> "%B64FILE%" echo ZCBieSB0aGUgYnVpbGQgc2NyaXB0IGZyb20gdGhlIHNoYXJlZCBjb21tb24vR2V0LUFsbFZoZHhG
>> "%B64FILE%" echo aWxlLnBzMS4gRWRpdGluZyBpdCBoZXJlIGhhcyBubyBlZmZlY3QuDQpmdW5jdGlvbiBHZXQtQWxs
>> "%B64FILE%" echo VmhkeEZpbGUgew0KICAgIHBhcmFtKFtpbnRdJE1heERlcHRoID0gNikNCiAgICAjIFBydW5pbmcg
>> "%B64FILE%" echo aXMgYnkgZm9sZGVyIG5hbWUgb25seSwgbmV2ZXIgZW50ZXJpbmcgc3lzdGVtIGZvbGRlcnMsIHRo
>> "%B64FILE%" echo ZSByZWN5Y2xlIGJpbiBvciBkZXBlbmRlbmN5IGNhY2hlcywgc28gZGVwdGggNiBzdGF5cyBmYXN0
>> "%B64FILE%" echo Lg0KICAgICMgVXNlIC5ORVQgZGlyZWN0b3J5IGVudW1lcmF0aW9uIGluc3RlYWQgb2YgR2V0LUNo
>> "%B64FILE%" echo aWxkSXRlbTogdGhlIGxhdHRlciBjcmVhdGVzIGEgUFNPYmplY3QgcGVyIGVudHJ5LA0KICAgICMg
>> "%B64FILE%" echo bWVhc3VyZWQgMTA3NCBtcyB2cyA4MyBtcyBvbiB0aGUgc2FtZSB0cmVlLCBhIDEyeCBkaWZmZXJl
>> "%B64FILE%" echo bmNlICh0aGUgd2luZG93IHJlc2NhbnMgb24gZXZlcnkgcmVmcmVzaCwgc28gaXQgaXMgdmVyeSB2
>> "%B64FILE%" echo aXNpYmxlKS4NCiAgICAkc2tpcCA9IEAoJyRSRUNZQ0xFLkJJTicsICdTeXN0ZW0gVm9sdW1lIElu
>> "%B64FILE%" echo Zm9ybWF0aW9uJywgJ1dpbmRvd3MnLCAnUHJvZ3JhbSBGaWxlcycsDQogICAgICAgICAgICAgICdQ
>> "%B64FILE%" echo cm9ncmFtIEZpbGVzICh4ODYpJywgJ1Byb2dyYW1EYXRhJywgJ1VzZXJzJywgJyRXaW5SRUFnZW50
>> "%B64FILE%" echo JywgJ1JlY292ZXJ5JywNCiAgICAgICAgICAgICAgJ25vZGVfbW9kdWxlcycsICcuZ2l0JywgJ1dp
>> "%B64FILE%" echo blN4UycpDQogICAgJGZvdW5kID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlM
>> "%B64FILE%" echo aXN0DQogICAgZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FcnJvckFjdGlvbiBTaWxlbnRs
>> "%B64FILE%" echo eUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoLW5vdCAkdi5Ecml2ZUxldHRlcikgeyBjb250aW51
>> "%B64FILE%" echo ZSB9DQogICAgICAgIGlmICgkdi5GaWxlU3lzdGVtIC1uZSAnTlRGUycpIHsgY29udGludWUgfQ0K
>> "%B64FILE%" echo ICAgICAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7IGNvbnRpbnVlIH0NCiAgICAg
>> "%B64FILE%" echo ICAgJHF1ZXVlID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuUXVldWUNCiAgICAgICAg
>> "%B64FILE%" echo JHF1ZXVlLkVucXVldWUoQCgiJCgkdi5Ecml2ZUxldHRlcik6XCIsIDApKQ0KICAgICAgICB3aGls
>> "%B64FILE%" echo ZSAoJHF1ZXVlLkNvdW50IC1ndCAwKSB7DQogICAgICAgICAgICAkY3VyID0gJHF1ZXVlLkRlcXVl
>> "%B64FILE%" echo dWUoKQ0KICAgICAgICAgICAgJGRpciA9IFtzdHJpbmddJGN1clswXQ0KICAgICAgICAgICAgJGQg
>> "%B64FILE%" echo PSBbaW50XSRjdXJbMV0NCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFj
>> "%B64FILE%" echo aCAoJGYgaW4gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRGaWxlcygkZGlyLCAnKi52aGR4Jykp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgICAgICAgICAgW3ZvaWRdJGZvdW5kLkFkZCgoTmV3LU9iamVjdCBTeXN0
>> "%B64FILE%" echo ZW0uSU8uRmlsZUluZm8gJGYpKQ0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgIH0gY2F0
>> "%B64FILE%" echo Y2gge30NCiAgICAgICAgICAgIGlmICgkZCAtZ2UgJE1heERlcHRoKSB7IGNvbnRpbnVlIH0NCiAg
>> "%B64FILE%" echo ICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHN1YiBpbiBbU3lzdGVt
>> "%B64FILE%" echo LklPLkRpcmVjdG9yeV06OkVudW1lcmF0ZURpcmVjdG9yaWVzKCRkaXIpKSB7DQogICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgIGlmICgkc2tpcCAtY29udGFpbnMgW1N5c3RlbS5JTy5QYXRoXTo6R2V0RmlsZU5h
>> "%B64FILE%" echo bWUoJHN1YikpIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB0cnkgew0KICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICAgaWYgKFtTeXN0ZW0uSU8uRmlsZV06OkdldEF0dHJpYnV0ZXMoJHN1
>> "%B64FILE%" echo YikgLWJhbmQgW1N5c3RlbS5JTy5GaWxlQXR0cmlidXRlc106OlJlcGFyc2VQb2ludCkgeyBjb250
>> "%B64FILE%" echo aW51ZSB9DQogICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBjb250aW51ZSB9DQogICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoJHN1YiwgKCRkICsgMSkpKQ0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIH0NCiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAgICAgICAgfQ0KICAgIH0NCiAgICBy
>> "%B64FILE%" echo ZXR1cm4gJGZvdW5kLlRvQXJyYXkoKQ0KfQ0KIyA8PDwgQ09NTU9OOkdldC1BbGxWaGR4RmlsZQ0K
>> "%B64FILE%" echo DQpmdW5jdGlvbiBHZXQtVmhkU3RhdGVHdWlkIHsNCiAgICBwYXJhbShbc3RyaW5nXSRQYXRoKQ0K
>> "%B64FILE%" echo ICAgICRzdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVuc2lvbigkUGF0aCwgJy5ib290
>> "%B64FILE%" echo LnR4dCcpDQogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSkgeyByZXR1
>> "%B64FILE%" echo cm4gJycgfQ0KICAgIGZvcmVhY2ggKCRsbiBpbiAoR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRz
>> "%B64FILE%" echo dCAtRW5jb2RpbmcgVVRGOCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAg
>> "%B64FILE%" echo ICAgaWYgKCRsbiAtbWF0Y2ggJ15ccypHdWlkXHMqPVxzKihce1swLTlhLWZBLUYtXXszNn1cfSlc
>> "%B64FILE%" echo cyokJykgeyByZXR1cm4gJG1hdGNoZXNbMV0gfQ0KICAgIH0NCiAgICByZXR1cm4gJycNCn0NCg0K
>> "%B64FILE%" echo IyBJcyB0aGlzIGJvb3QgZW50cnkgc3RpbGwgaW4gdGhlIEJDRCAoZXhpc3RlbmNlIG9ubHksIHRo
>> "%B64FILE%" echo ZSB0YXJnZXQgaXMgbm90IGNoZWNrZWQpDQpmdW5jdGlvbiBUZXN0LUJjZEVudHJ5UHJlc2VudCB7
>> "%B64FILE%" echo DQogICAgcGFyYW0oW3N0cmluZ10kR3VpZCkNCiAgICBpZiAoLW5vdCAkR3VpZCkgeyByZXR1cm4g
>> "%B64FILE%" echo JGZhbHNlIH0NCiAgICAkdHh0ID0gJycNCiAgICB0cnkgeyAkdHh0ID0gKCYgYmNkZWRpdCAvZW51
>> "%B64FILE%" echo bSAkR3VpZCAyPiYxIHwgT3V0LVN0cmluZykgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQ0KICAg
>> "%B64FILE%" echo IGlmICgkTEFTVEVYSVRDT0RFIC1uZSAwKSB7IHJldHVybiAkZmFsc2UgfQ0KICAgIGlmICgkdHh0
>> "%B64FILE%" echo IC1tYXRjaCAn5om+5LiN5YiwfG5vdCBmb3VuZHzml6DmlYh8aW52YWxpZHzmi5Lnu518ZGVuaWVk
>> "%B64FILE%" echo JykgeyByZXR1cm4gJGZhbHNlIH0NCiAgICByZXR1cm4gKCR0eHQgLW1hdGNoICcoP2kpaWRlbnRp
>> "%B64FILE%" echo ZmllcnzmoIfor4bnrKYnKQ0KfQ0KDQojIERlbGV0ZSB0aGUgLmJvb3QudHh0IG5leHQgdG8gdGhl
>> "%B64FILE%" echo IHZoZHggYWxvbmcgd2l0aCBpdC4NCiMgRGVsZXRpbmcgb25seSB0aGUgdmhkeCB3b3VsZCBtYWtl
>> "%B64FILE%" echo IHRoZSBuZXh0IHNjYW4gY2xhc3NpZnkgdGhlIGVtcHR5IHNoZWxsIGFzIEIgYW5kIGFzayBhZ2Fp
>> "%B64FILE%" echo biwNCiMgYW5kIGEgLmJvb3QudHh0IHBvaW50aW5nIGF0IGEgdmhkeCB0aGF0IG5vIGxvbmdlciBl
>> "%B64FILE%" echo eGlzdHMgYWxzbyBtaXNsZWFkcyBvdGhlciB0b29scy4NCmZ1bmN0aW9uIFJlbW92ZS1WaGRTYWZl
>> "%B64FILE%" echo bHkgew0KICAgIHBhcmFtKCRJdGVtKQ0KICAgIHRyeSB7DQogICAgICAgIFJlbW92ZS1JdGVtIC1M
>> "%B64FILE%" echo aXRlcmFsUGF0aCAkSXRlbS5QYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICBT
>> "%B64FILE%" echo YXkgIiAgICAgICAgICAgICBkZWxldGVkIiAnR3JlZW4nDQogICAgICAgICRzdCA9IFtTeXN0ZW0u
>> "%B64FILE%" echo SU8uUGF0aF06OkNoYW5nZUV4dGVuc2lvbigkSXRlbS5QYXRoLCAnLmJvb3QudHh0JykNCiAgICAg
>> "%B64FILE%" echo ICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSB7DQogICAgICAgICAgICBSZW1vdmUt
>> "%B64FILE%" echo SXRlbSAtTGl0ZXJhbFBhdGggJHN0IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51
>> "%B64FILE%" echo ZQ0KICAgICAgICB9DQogICAgfSBjYXRjaCB7DQogICAgICAgIFNheSAoIiAgICAgICAgICAgICBk
>> "%B64FILE%" echo ZWxldGlvbiBmYWlsZWQ6ICIgKyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1JlZCcNCiAgICAgICAg
>> "%B64FILE%" echo U2F5ICIgICAgICAgICAgICAgdXN1YWxseSBhIHByb2Nlc3Mgc3RpbGwgaG9sZHMgaXQgLSByZWJv
>> "%B64FILE%" echo b3QgYW5kIHJ1biB0aGlzIHRvb2wgYWdhaW4uIiAnWWVsbG93Jw0KICAgIH0NCn0NCg0KJGNhdEEg
>> "%B64FILE%" echo PSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgICAjIGluc3RhbGxlZCAo
>> "%B64FILE%" echo ZW50cnkgcHJlc2VudCkNCiRjYXRCID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJy
>> "%B64FILE%" echo YXlMaXN0ICAgIyBpbnN0YWxsZWQgYnkgdGhpcyB0b29sa2l0LCBlbnRyeSBnb25lDQokY2F0QyA9
>> "%B64FILE%" echo IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdCAgICMgbm90IGNyZWF0ZWQg
>> "%B64FILE%" echo YnkgdGhpcyB0b29sa2l0DQoNCmZvcmVhY2ggKCRmIGluIEAoR2V0LUFsbFZoZHhGaWxlKSkgew0K
>> "%B64FILE%" echo ICAgICRzeiA9IDANCiAgICB0cnkgeyAkc3ogPSBbbWF0aF06OlJvdW5kKCRmLkxlbmd0aCAvIDFH
>> "%B64FILE%" echo QiwgMikgfSBjYXRjaCB7fQ0KICAgICRzdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVu
>> "%B64FILE%" echo c2lvbigkZi5GdWxsTmFtZSwgJy5ib290LnR4dCcpDQogICAgJGhhc1N0YXRlID0gVGVzdC1QYXRo
>> "%B64FILE%" echo IC1MaXRlcmFsUGF0aCAkc3QNCiAgICAkZ3VpZCA9ICcnDQogICAgaWYgKCRoYXNTdGF0ZSkgeyAk
>> "%B64FILE%" echo Z3VpZCA9IEdldC1WaGRTdGF0ZUd1aWQgLVBhdGggJGYuRnVsbE5hbWUgfQ0KICAgICRpdGVtID0g
>> "%B64FILE%" echo W1BTQ3VzdG9tT2JqZWN0XUB7IFBhdGggPSAkZi5GdWxsTmFtZTsgU2l6ZUdCID0gJHN6OyBIYXNT
>> "%B64FILE%" echo dGF0ZSA9ICRoYXNTdGF0ZSB9DQogICAgaWYgKFRlc3QtQmNkRW50cnlQcmVzZW50IC1HdWlkICRn
>> "%B64FILE%" echo dWlkKSB7DQogICAgICAgIFt2b2lkXSRjYXRBLkFkZCgkaXRlbSkNCiAgICB9IGVsc2VpZiAoJGhh
>> "%B64FILE%" echo c1N0YXRlKSB7DQogICAgICAgIFt2b2lkXSRjYXRCLkFkZCgkaXRlbSkNCiAgICB9IGVsc2Ugew0K
>> "%B64FILE%" echo ICAgICAgICBbdm9pZF0kY2F0Qy5BZGQoJGl0ZW0pDQogICAgfQ0KfQ0KDQppZiAoJGNhdEEuQ291
>> "%B64FILE%" echo bnQgLWd0IDApIHsNCiAgICBTYXkgIiAgICAgIFRoZXNlIGFyZSBpbnN0YWxsZWQgd2l0aCB0aGVp
>> "%B64FILE%" echo ciBib290IGVudHJ5IGludGFjdDsgdGhpcyB0b29sIG5ldmVyIHRvdWNoZXMgdGhlbToiICdEYXJr
>> "%B64FILE%" echo R3JheScNCiAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEEpIHsNCiAgICAgICAgU2F5ICgoJyAgICAg
>> "%B64FILE%" echo ICAgezB9ICAgKHsxfSBHQiknIC1mICRpdC5QYXRoLCAkaXQuU2l6ZUdCKSkgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo ICAgIH0NCiAgICBTYXkgIiAgICAgICh0byBkZWxldGUgdGhlbSB1c2UgVW5pbnN0YWxsLVN5c3Rl
>> "%B64FILE%" echo bS5iYXQsIGl0IGFsc28gY2xlYW5zIHRoZSBib290IG1lbnUpIiAnRGFya0dyYXknDQp9DQoNCmlm
>> "%B64FILE%" echo ICgoJGNhdEIuQ291bnQgKyAkY2F0Qy5Db3VudCkgLWVxIDApIHsNCiAgICBTYXkgIiAgICAgIE5v
>> "%B64FILE%" echo dGhpbmcgdG8gaGFuZGxlLCB0aGUgZW52aXJvbm1lbnQgaXMgYWxyZWFkeSBjbGVhbiIgJ0RhcmtH
>> "%B64FILE%" echo cmF5Jw0KfSBlbHNlIHsNCiAgICBpZiAoJGNhdEIuQ291bnQgLWd0IDApIHsNCiAgICAgICAgU2F5
>> "%B64FILE%" echo ICIiDQogICAgICAgIFNheSAoIiAgICAgIFtCXSBpbnN0YWxsZWQgYnkgdGhpcyB0b29sa2l0IGJ1
>> "%B64FILE%" echo dCB0aGUgYm9vdCBlbnRyeSBpcyBnb25lICh7MH0pIiAtZiAkY2F0Qi5Db3VudCkgJ1doaXRlJw0K
>> "%B64FILE%" echo ICAgICAgICBTYXkgIiAgICAgICAgICBUaGUgLmJvb3QudHh0IGxlZnQgYnkgdGhpcyB0b29sa2l0
>> "%B64FILE%" echo IHNpdHMgbmV4dCB0byB0aGVtOyBkZWxldGluZyB0aGVzZSBjYW5ub3QgYWZmZWN0IGFueSBib290
>> "%B64FILE%" echo YWJsZSBzeXN0ZW0uIiAnRGFya0dyYXknDQogICAgICAgIGZvcmVhY2ggKCRpdCBpbiAkY2F0Qikg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgU2F5ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBh
>> "%B64FILE%" echo dGgsICRpdC5TaXplR0IpKSAnV2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICIg
>> "%B64FILE%" echo ICAgICAgICAgICAgRGVsZXRlIHRoZW0/IFR5cGUgeSB0byBkZWxldGUsIG9yIHByZXNzIEVudGVy
>> "%B64FILE%" echo IHRvIHNraXAiDQogICAgICAgICAgICBpZiAoJGFucyAtYW5kICgkYW5zLlRyaW0oKSAtaWVxICd5
>> "%B64FILE%" echo JykpIHsNCiAgICAgICAgICAgICAgICBSZW1vdmUtVmhkU2FmZWx5IC1JdGVtICRpdA0KICAgICAg
>> "%B64FILE%" echo ICAgICAgfSBlbHNlIHsNCiAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICBza2lwcGVk
>> "%B64FILE%" echo IiAnRGFya0dyYXknDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQogICAgaWYgKCRj
>> "%B64FILE%" echo YXRDLkNvdW50IC1ndCAwKSB7DQogICAgICAgIFNheSAiIg0KICAgICAgICBTYXkgKCIgICAgICBb
>> "%B64FILE%" echo Q10gbm90IGNyZWF0ZWQgYnkgdGhpcyB0b29sa2l0ICh7MH0pIiAtZiAkY2F0Qy5Db3VudCkgJ1do
>> "%B64FILE%" echo aXRlJw0KICAgICAgICBTYXkgIiAgICAgICAgICBObyAuYm9vdC50eHQgZnJvbSB0aGlzIHRvb2xr
>> "%B64FILE%" echo aXQuIFRoZXkgbWF5IGJlIEh5cGVyLVYgdmlydHVhbCBkaXNrcywgYW5vdGhlciBpbnN0YWxsIiAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgIFNheSAiICAgICAgICAgIHRvb2wsIG9yIGEgYmFja3VwIG9mIHlv
>> "%B64FILE%" echo dXIgb3duLiBOb3QgZGVsZXRlZCBieSBkZWZhdWx0LCBhbmQgbm90IHJlY29tbWVuZGVkLiIgJ0Rh
>> "%B64FILE%" echo cmtHcmF5Jw0KICAgICAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEMpIHsNCiAgICAgICAgICAgICRm
>> "%B64FILE%" echo biA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRpdC5QYXRoKQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo U2F5ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBhdGgsICRpdC5TaXplR0Ip
>> "%B64FILE%" echo KSAnV2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICgiICAgICAgICAgICAgIFRv
>> "%B64FILE%" echo IHJlYWxseSBkZWxldGUgb25lLCB0eXBlIGl0cyBmaWxlIG5hbWUgezB9IChvciBwcmVzcyBFbnRl
>> "%B64FILE%" echo ciB0byBza2lwKSIgLWYgJGZuKQ0KICAgICAgICAgICAgaWYgKC1ub3QgJGFucykgew0KICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgIFNheSAiICAgICAgICAgICAgIHNraXBwZWQiICdEYXJrR3JheScNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIH0gZWxzZWlmICgkYW5zLlRyaW0oKSAtaWVxICRmbikgew0KICAgICAgICAgICAgICAgIFJl
>> "%B64FILE%" echo bW92ZS1WaGRTYWZlbHkgLUl0ZW0gJGl0DQogICAgICAgICAgICB9IGVsc2Ugew0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICMgRG8gbm90IHNheSAid3JvbmcgZmlsZSBuYW1lIiBpbiB5ZWxsb3cgLSBtYW55IHBl
>> "%B64FILE%" echo b3BsZSB0cnkgeSAvIHllcyBmaXJzdCBiZWNhdXNlIHRoZXkgZG8gd2FudCBpdCBkZWxldGVkLA0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICMgdGhleSBqdXN0IGRvIG5vdCBrbm93IHRoYXQgdGhpcyBwcm9tcHQg
>> "%B64FILE%" echo ZG9lcyBub3QgdGFrZSB5LiBFeHBsYWluIGNhbG1seSBob3cgdG8gZGVsZXRlLCBuZXZlciBzY29s
>> "%B64FILE%" echo ZC4NCiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICAgICAgICAgc2tpcHBlZC4gVG8gZGVsZXRl
>> "%B64FILE%" echo IHRoaXMgb25lLCB0eXBlIGl0cyBmdWxsIGZpbGUgbmFtZTogezB9IiAtZiAkZm4pICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICAgICAgICAgICAgICBpZiAoJGFucy5UcmltKCkgLWltYXRjaCAnXih5fHllc3zmmK98
>> "%B64FILE%" echo 5YigfOWIoOmZpHxvaykkJykgew0KICAgICAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAg
>> "%B64FILE%" echo ICAodGhpcyBwcm9tcHQgZGVsaWJlcmF0ZWx5IGRvZXMgbm90IGFjY2VwdCB5IC0gaXQgZ3VhcmRz
>> "%B64FILE%" echo IGFnYWluc3QgZGVsZXRpbmcgc29tZWJvZHkgZWxzZSdzIHZpcnR1YWwgZGlzaykiICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQp9
>> "%B64FILE%" echo DQoNCiMgLS0tLS0tLS0tLSBTdGVwIDQgKHYxLjI5KTogY2xlYW4gdGhlIGNvbXBhbmlvbiBsb2dz
>> "%B64FILE%" echo IGJjZGVkaXQgbGVhdmVzIHdoZW4gZXhwb3J0aW5nIHRoZSBCQ0QgLS0tLS0tLS0tLQ0KIw0KIyBi
>> "%B64FILE%" echo Y2RlZGl0IC9leHBvcnQgd3JpdGVzIGEgcmVnaXN0cnkgaGl2ZSwgYW5kIFdpbmRvd3MgZHJvcHMg
>> "%B64FILE%" echo Y29tcGFuaW9uIHRyYW5zYWN0aW9uIGxvZ3MgbmV4dCB0byBpdDoNCiMgICB4eHguYmNkLkxPRyAg
>> "%B64FILE%" echo eHh4LmJjZC5MT0cxICB4eHguYmNkLkxPRzINCiMgTWVhc3VyZWQgb24gcmVhbCBoYXJkd2FyZTog
>> "%B64FILE%" echo MzEgLmJjZC5MT0cqIGZpbGVzIHBpbGVkIHVwIGluIHRoZSByb290IG9mIEQ6XCBhbmQgYW5vdGhl
>> "%B64FILE%" echo ciAxOCBpbiBEOlxWaXJ0dWFsRGlza3NcLg0KIyBUaGVzZSBjb21wYW5pb24gZmlsZXMgY2Fycnkg
>> "%B64FILE%" echo dGhlIEhpZGRlbiArIFN5c3RlbSBhdHRyaWJ1dGVzLCBzbyBHZXQtQ2hpbGRJdGVtIG11c3QgYmUg
>> "%B64FILE%" echo Y2FsbGVkIHdpdGggLUZvcmNlLA0KIyBvdGhlcndpc2Ugbm90IGEgc2luZ2xlIG9uZSBpcyBmb3Vu
>> "%B64FILE%" echo ZCAoZXhhY3RseSB3aGF0IHYxLjI5IG1pc3NlZCwgbWFraW5nIHRoZSBmZWF0dXJlIHNpbGVudGx5
>> "%B64FILE%" echo IGRvIG5vdGhpbmcpLg0KIyBUaGV5IGFyZSBpbnRlcm1lZGlhdGUgZmlsZXMgb2YgdGhlIGV4cG9y
>> "%B64FILE%" echo dCwgdXNlbGVzcyBmb3IgcmVzdG9yaW5nIHRoZSBCQ0QsIGFuZCBkZWxldGluZyB0aGVtIGRvZXMg
>> "%B64FILE%" echo bm90IGFmZmVjdCB0aGUgLmJjZCBiYWNrdXAuDQojIFNpbmNlIHYxLjI5IHRoZSBpbnN0YWxsZXIv
>> "%B64FILE%" echo cmVwYWlyIHRvb2wgZXhwb3J0IHRvIGEgdGVtcCBmb2xkZXIgZmlyc3QgYW5kIHRoZW4gY29weSwg
>> "%B64FILE%" echo c28gbm8gbmV3IG9uZXMgYXBwZWFyOw0KIyB0aGlzIHNlY3Rpb24gaXMgdGhlIGNsZWFuLXVwIGZv
>> "%B64FILE%" echo ciB3aGF0IGhhcyBhbHJlYWR5IHBpbGVkIHVwLg0KJHN0cmF5TG9ncyA9IE5ldy1PYmplY3QgU3lz
>> "%B64FILE%" echo dGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KIw0KIyBbdjEuMzEgaGFyZGVuaW5nXSBUaGlzIHVz
>> "%B64FILE%" echo ZWQgdG8gc2NhbiB0aGUgcm9vdCBhbmQgZmlyc3QtbGV2ZWwgc3ViZm9sZGVycyBvZiA2IGRyaXZl
>> "%B64FILE%" echo cyB3aXRoIHRoZSAnKi5iY2QuTE9HKicgd2lsZGNhcmQNCiMgYW5kIHRoZW4gUmVtb3ZlLUl0ZW0g
>> "%B64FILE%" echo ZXZlcnl0aGluZy4gSW4gcHJhY3RpY2Ugbm8gc3lzdGVtIGZpbGUgd2FzIGV2ZXIgaGl0IC0gYnV0
>> "%B64FILE%" echo IHRoYXQgd2FzIGx1Y2sgZnJvbSBhIC1GaWx0ZXIgOC4zDQojIHNob3J0LW5hbWUgcXVpcmsgdGhh
>> "%B64FILE%" echo dCBoYXBwZW5lZCBub3QgdG8gbWF0Y2ggIkJDRC5MT0ciLCBub3QgcHJvdGVjdGlvbiBpbiB0aGUg
>> "%B64FILE%" echo Y29kZS4gTWVhbndoaWxlDQojIEM6XEJvb3RcQkNELkxPRyAvIEJDRC5MT0cxIC8gQkNELkxPRzIg
>> "%B64FILE%" echo YXJlIHRoZSAqKnRyYW5zYWN0aW9uIGxvZ3Mgb2YgdGhlIGFjdGl2ZSBCQ0QqKiwgdHdvIGxldHRl
>> "%B64FILE%" echo cnMgYXdheSwNCiMgc28gYW5vdGhlciBzcGVsbGluZyBvciBhbm90aGVyIG1hY2hpbmUgY291bGQg
>> "%B64FILE%" echo aGl0IHRoZW0sIGFuZCBkZWxldGluZyB0aGVtIHJpc2tzIGEgY29ycnVwdGVkIGJvb3QgY29uZmln
>> "%B64FILE%" echo dXJhdGlvbi4NCiMNCiMgSXQgaXMgYSB3aGl0ZWxpc3Qgbm93OiBvbmx5IHRoZSBleGFjdCBmb3Jt
>> "%B64FILE%" echo YXQgdGhpcyB0b29sa2l0IGhhcyBleHBvcnRlZCBvdmVyIHRoZSB2ZXJzaW9ucyBpcyBtYXRjaGVk
>> "%B64FILE%" echo LCBub3RoaW5nIGVsc2UuDQojICAgYmNkLWJhY2t1cC08eXl5eU1NZGQ+LTxISG1tc3M+LmJjZC5M
>> "%B64FILE%" echo T0cgLyAuTE9HMSAvIC5MT0cyDQojICAgYmNkLWJhY2t1cC1maXgtPHl5eXlNTWRkPi08SEhtbXNz
>> "%B64FILE%" echo Pi5iY2QuTE9HIC4uLg0KIyAgIGJjZC1yZXNjdWUtPHl5eXlNTWRkPi08SEhtbXNzPi5iY2QuTE9H
>> "%B64FILE%" echo IC4uLiAgIChlYXJseSB2ZXJzaW9ucyB1c2VkIHRoaXMgcHJlZml4KQ0KIyBUaGUga2V5IHBvaW50
>> "%B64FILE%" echo OiBpdCBtdXN0IHN0YXJ0IHdpdGggYmNkLSwgY2FycnkgYW4gOC1kaWdpdCBkYXRlIHBsdXMgYSA2
>> "%B64FILE%" echo LWRpZ2l0IHRpbWUsIGFuZCBlbmQgaW4gLmJjZC4NCiMgTm9uZSBvZiB0aGUgdGhyZWUgc3lzdGVt
>> "%B64FILE%" echo IG5hbWVzIEM6XEJvb3RcQkNELkxPRyBtYXRjaGVzIGFueSBvZiB0aGF0LCBzbyBpdCBpcyBzdHJ1
>> "%B64FILE%" echo Y3R1cmFsbHkgaW1wb3NzaWJsZSB0byBzZWxlY3QgdGhlbS4NCiMgVGhlIHN5c3RlbSBmb2xkZXJz
>> "%B64FILE%" echo IGFyZSBleGNsdWRlZCBhZ2FpbiBhdCBkaXJlY3RvcnkgbGV2ZWwsIGFzIGEgc2Vjb25kIGxpbmUg
>> "%B64FILE%" echo b2YgZGVmZW5jZS4NCiRpc1N0cmF5QmNkTG9nID0gew0KICAgIHBhcmFtKFtzdHJpbmddJG4pDQog
>> "%B64FILE%" echo ICAgcmV0dXJuICgkbiAtbWF0Y2ggJ15iY2QtW2Etel0rKD86LVthLXpdKykqLVxkezh9LVxkezZ9
>> "%B64FILE%" echo XC5iY2RcLkxPR1swLTldPyQnKQ0KfQ0KJHNraXBTdWJEaXJzID0gJ14oV2luZG93c3xQcm9ncmFt
>> "%B64FILE%" echo IEZpbGVzLip8XCRSZWN5Y2xlXC5CaW58U3lzdGVtIFZvbHVtZSBJbmZvcm1hdGlvbnxVc2Vyc3xC
>> "%B64FILE%" echo b290fFJlY292ZXJ5fEVGSXxQZXJmTG9ncykkJw0KZm9yZWFjaCAoJHJ0IGluIEAoJ0M6XCcsICdE
>> "%B64FILE%" echo OlwnLCAnRTpcJywgJ0Y6XCcsICdHOlwnLCAnSDpcJykpIHsNCiAgICBpZiAoLW5vdCAoVGVzdC1Q
>> "%B64FILE%" echo YXRoIC1MaXRlcmFsUGF0aCAkcnQpKSB7IGNvbnRpbnVlIH0NCiAgICBmb3JlYWNoICgkZiBpbiBA
>> "%B64FILE%" echo KEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRydCAtRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpKSB7DQogICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRmLk5hbWUpIHsgW3Zv
>> "%B64FILE%" echo aWRdJHN0cmF5TG9ncy5BZGQoJGYpIH0NCiAgICB9DQogICAgZm9yZWFjaCAoJGQgaW4gQChHZXQt
>> "%B64FILE%" echo Q2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkcnQgLURpcmVjdG9yeSAtRm9yY2UgLUVBIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpKSB7DQogICAgICAgIGlmICgkZC5OYW1lIC1tYXRjaCAkc2tpcFN1YkRpcnMpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICBmb3JlYWNoICgkZiBpbiBAKEdldC1DaGlsZEl0ZW0gLUxpdGVy
>> "%B64FILE%" echo YWxQYXRoICRkLkZ1bGxOYW1lIC1GaWxlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSkpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRmLk5hbWUpIHsgW3ZvaWRdJHN0cmF5
>> "%B64FILE%" echo TG9ncy5BZGQoJGYpIH0NCiAgICAgICAgfQ0KICAgIH0NCn0NCg0KaWYgKCRzdHJheUxvZ3MuQ291
>> "%B64FILE%" echo bnQgLWd0IDApIHsNCiAgICAkc3ogPSAoJHN0cmF5TG9ncyB8IE1lYXN1cmUtT2JqZWN0IC1Qcm9w
>> "%B64FILE%" echo ZXJ0eSBMZW5ndGggLVN1bSkuU3VtDQogICAgU2F5ICIiDQogICAgU2F5ICgiICAgICAgW2V4dHJh
>> "%B64FILE%" echo XSBjb21wYW5pb24gbG9ncyBsZWZ0IGJ5IGJjZGVkaXQgd2hlbiBleHBvcnRpbmcgdGhlIEJDRCAo
>> "%B64FILE%" echo ezB9IGZpbGVzLCB7MTpOMX0gTUIgaW4gdG90YWwpIiAtZiAkc3RyYXlMb2dzLkNvdW50LCAoJHN6
>> "%B64FILE%" echo IC8gMU1CKSkgJ1doaXRlJw0KICAgIFNheSAiICAgICAgICAgIFRoZXNlIGFyZSB0aGUgLkxPRyAv
>> "%B64FILE%" echo IC5MT0cxIC8gLkxPRzIgZmlsZXMgbmV4dCB0byBiY2QtYmFja3VwLSouYmNkLiIgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KICAgIFNheSAiICAgICAgICAgIFRoZXkgYXJlIGludGVybWVkaWF0ZSBmaWxlcyBvZiB0aGUg
>> "%B64FILE%" echo ZXhwb3J0OyBkZWxldGluZyB0aGVtIGFmZmVjdHMgbmVpdGhlciB0aGUgLmJjZCBiYWNrdXAgbm9y
>> "%B64FILE%" echo IGJvb3RpbmcuIiAnRGFya0dyYXknDQogICAgU2F5ICIgICAgICAgICAgT25seSBiYWNrdXAgbmFt
>> "%B64FILE%" echo ZXMgZXhwb3J0ZWQgYnkgdGhpcyB0b29sa2l0IG1hdGNoOyB0aGUgc3lzdGVtJ3Mgb3duIEM6XEJv
>> "%B64FILE%" echo b3RcQkNELkxPRyBpcyBvdXQgb2Ygc2NvcGUgYW5kIG5ldmVyIHRvdWNoZWQuIiAnRGFya0dyYXkn
>> "%B64FILE%" echo DQogICAgZm9yZWFjaCAoJGYgaW4gQCgkc3RyYXlMb2dzIHwgU29ydC1PYmplY3QgRnVsbE5hbWUg
>> "%B64FILE%" echo fCBTZWxlY3QtT2JqZWN0IC1GaXJzdCA4KSkgew0KICAgICAgICBTYXkgKCIgICAgICAgICAgIiAr
>> "%B64FILE%" echo ICRmLkZ1bGxOYW1lKSAnRGFya0dyYXknDQogICAgfQ0KICAgIGlmICgkc3RyYXlMb2dzLkNvdW50
>> "%B64FILE%" echo IC1ndCA4KSB7IFNheSAoIiAgICAgICAgICAuLi4gYW5kIHswfSBtb3JlIiAtZiAoJHN0cmF5TG9n
>> "%B64FILE%" echo cy5Db3VudCAtIDgpKSAnRGFya0dyYXknIH0NCiAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAgICAg
>> "%B64FILE%" echo ICAgICAgRGVsZXRlIHRoZW0gYWxsPyBUeXBlIHkgdG8gZGVsZXRlLCBvciBwcmVzcyBFbnRlciB0
>> "%B64FILE%" echo byBza2lwIg0KICAgIGlmICgkYW5zIC1hbmQgKCRhbnMuVHJpbSgpIC1pZXEgJ3knKSkgew0KICAg
>> "%B64FILE%" echo ICAgICAkb2tOID0gMA0KICAgICAgICBmb3JlYWNoICgkZiBpbiAkc3RyYXlMb2dzKSB7DQogICAg
>> "%B64FILE%" echo ICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGYuRnVsbE5hbWUgLUZvcmNl
>> "%B64FILE%" echo IC1FQSBTdG9wOyAkb2tOKysgfSBjYXRjaCB7fQ0KICAgICAgICB9DQogICAgICAgIFNheSAoIiAg
>> "%B64FILE%" echo ICAgICAgICAgICBkZWxldGVkIHswfSAvIHsxfSIgLWYgJG9rTiwgJHN0cmF5TG9ncy5Db3VudCkg
>> "%B64FILE%" echo J0dyZWVuJw0KICAgICAgICBpZiAoJG9rTiAtbHQgJHN0cmF5TG9ncy5Db3VudCkgeyBTYXkgIiAg
>> "%B64FILE%" echo ICAgICAgICAgICB0aGUgb25lcyB0aGF0IGNhbm5vdCBiZSBkZWxldGVkIGFyZSB1c3VhbGx5IGhl
>> "%B64FILE%" echo bGQgYnkgYW5vdGhlciBwcm9ncmFtOyByZWJvb3QgYW5kIHJlcnVuIiAnRGFya0dyYXknIH0NCiAg
>> "%B64FILE%" echo ICB9IGVsc2Ugew0KICAgICAgICBTYXkgIiAgICAgICAgICAgICBza2lwcGVkIChub3RoaW5nIGRl
>> "%B64FILE%" echo bGV0ZWQpIiAnRGFya0dyYXknDQogICAgfQ0KfQ0KDQpTYXkgIiINClNheSAiICAtLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJr
>> "%B64FILE%" echo R3JheScNClNheSAiICBDbGVhbnVwIGNvbXBsZXRlLiIgJ0dyZWVuJw0KU2F5ICIiDQpTYXkgIiAg
>> "%B64FILE%" echo SG93IHRvIHJlaW5zdGFsbCBwcm9wZXJseToiICdXaGl0ZScNClNheSAiICAgIDEuIERvdWJsZS1j
>> "%B64FILE%" echo bGljayBJbnN0YWxsLVN5c3RlbS5iYXQgYWdhaW4iICdEYXJrR3JheScNClNheSAiICAgICAgIHRo
>> "%B64FILE%" echo ZSBwcm9ncmVzcyBiYXIgc2hvd3MgaG93IG1hbnkgR0IgaGF2ZSBiZWVuIHdyaXR0ZW47IGFzIGxv
>> "%B64FILE%" echo bmcgYXMgdGhlIG51bWJlciBncm93cyBpdCBpcyB3b3JraW5nLCBkbyBub3QgY2xvc2UgaXQiICdE
>> "%B64FILE%" echo YXJrR3JheScNClNheSAiICAgIDIuIFJlYm9vdCBhZnRlciBpdCBmaW5pc2hlcyBhbmQgY2hvb3Nl
>> "%B64FILE%" echo IHRoZSBuZXcgc3lzdGVtIGluIHRoZSBib290IG1lbnUiICdEYXJrR3JheScNClNheSAiIg0KUmVh
>> "%B64FILE%" echo ZC1Ib3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQiDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=17075"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" -OriginDir "%ORIGIN%"
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
