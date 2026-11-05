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
>> "%B64FILE%" echo Y3JpcHQ6VmVyc2lvbiA9ICcxLjMyJw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQoN
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
>> "%B64FILE%" echo LQ0KIw0KIyBbYXVkaXQgUDMtMTZdIFRoaXMgdXNlZCB0byBraWxsIGV2ZXJ5IGRpc20uZXhlIC8g
>> "%B64FILE%" echo RGlzbUhvc3Qgb24gdGhlIG1hY2hpbmUgd2l0aG91dCBhc2tpbmcuDQojIEEgdXNlciBydW5uaW5n
>> "%B64FILE%" echo IERJU00gL1Jlc3RvcmVIZWFsdGggKG9yIGFueSBvdGhlciBsb25nIERJU00gam9iKSBoYWQgaXQg
>> "%B64FILE%" echo dGVybWluYXRlZCBtaWQtd2F5Lg0KIyBJdCBpcyBzdGlsbCB3b3J0aCBvZmZlcmluZyAtIGEgc3R1
>> "%B64FILE%" echo Y2sgRGlzbUhvc3QgaXMgZXhhY3RseSB3aGF0IGJsb2NrcyBhIHJlaW5zdGFsbCAtIGJ1dCB0aGUN
>> "%B64FILE%" echo CiMgdXNlciBnZXRzIHRvIHNlZSB3aGF0IGlzIHJ1bm5pbmcgYW5kIGRlY2lkZS4NClNheSAiWzEv
>> "%B64FILE%" echo M10gTG9va2luZyBmb3IgbGVmdG92ZXIgZGlzbS5leGUgLi4uIg0KJGRpc21zID0gQChHZXQtUHJv
>> "%B64FILE%" echo Y2VzcyAtTmFtZSBkaXNtLCBEaXNtSG9zdCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkN
>> "%B64FILE%" echo CiRraWxsZWQgPSAwDQppZiAoJGRpc21zLkNvdW50IC1lcSAwKSB7DQogICAgU2F5ICIgICAgICBu
>> "%B64FILE%" echo b25lIHJ1bm5pbmciICdEYXJrR3JheScNCn0gZWxzZSB7DQogICAgU2F5ICgiICAgICAgezB9IHBy
>> "%B64FILE%" echo b2Nlc3MoZXMpOiB7MX0iIC1mICRkaXNtcy5Db3VudCwgKCgkZGlzbXMgfCBGb3JFYWNoLU9iamVj
>> "%B64FILE%" echo dCB7ICIkKCRfLlByb2Nlc3NOYW1lKShQSUQgJCgkXy5JZCkpIiB9KSAtam9pbiAnLCAnKSkgJ1ll
>> "%B64FILE%" echo bGxvdycNCiAgICBTYXkgIiAgICAgIEtpbGxpbmcgdGhlbSBhbHNvIGludGVycnVwdHMgYSBESVNN
>> "%B64FILE%" echo IGpvYiB5b3Ugc3RhcnRlZCB5b3Vyc2VsZiAoZm9yIGV4YW1wbGUgL1Jlc3RvcmVIZWFsdGgpLiIg
>> "%B64FILE%" echo J0RhcmtHcmF5Jw0KICAgICRhbnMgPSBSZWFkLUhvc3QgIiAgICAgIEtpbGwgdGhlbT8gW3kvTl0i
>> "%B64FILE%" echo DQogICAgaWYgKCRhbnMgLW1hdGNoICdeKD9pKXkoZXMpPyQnKSB7DQogICAgICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRwIGluICRkaXNtcykgew0KICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICBTdG9w
>> "%B64FILE%" echo LVByb2Nlc3MgLUlkICRwLklkIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICRraWxsZWQrKw0KICAgICAgICAgICAgICAgIFNheSAoIiAgICAgIGtpbGxlZCB7MH0gKFBJ
>> "%B64FILE%" echo RCB7MX0pIiAtZiAkcC5Qcm9jZXNzTmFtZSwgJHAuSWQpICdEYXJrR3JheScNCiAgICAgICAgICAg
>> "%B64FILE%" echo IH0gY2F0Y2ggew0KICAgICAgICAgICAgICAgIFNheSAoIiAgICAgIGZhaWxlZCB0byBraWxsIHsw
>> "%B64FILE%" echo fSAoUElEIHsxfSk6IHsyfSIgLWYgJHAuUHJvY2Vzc05hbWUsICRwLklkLCAkXy5FeGNlcHRpb24u
>> "%B64FILE%" echo TWVzc2FnZSkgJ1llbGxvdycNCiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KICAgIH0gZWxzZSB7
>> "%B64FILE%" echo DQogICAgICAgIFNheSAiICAgICAgc2tpcHBlZCIgJ0RhcmtHcmF5Jw0KICAgIH0NCn0NClN0YXJ0
>> "%B64FILE%" echo LVNsZWVwIC1NaWxsaXNlY29uZHMgODAwDQoNCiMgLS0tLS0tLS0tLSAyLiBEaXNtb3VudCB2aXJ0
>> "%B64FILE%" echo dWFsIGRpc2tzIC0tLS0tLS0tLS0NCiMNCiMgW2F1ZGl0IFAzLTE2XSBTYW1lIHByb2JsZW06IGV2
>> "%B64FILE%" echo ZXJ5IEZpbGUgQmFja2VkIFZpcnR1YWwgZGlzayB3YXMgZGV0YWNoZWQsIGluY2x1ZGluZyBhIEh5
>> "%B64FILE%" echo cGVyLVYNCiMgbWFjaGluZSBkaXNrIG9yIGEgVkhEIHRoZSB1c2VyIGlzIHdvcmtpbmcgd2l0aC4g
>> "%B64FILE%" echo Tm90aGluZyBpcyBsb3N0IGJ5IGRldGFjaGluZywgYnV0IHRoZSBvdGhlcg0KIyBqb2IgYnJlYWtz
>> "%B64FILE%" echo LiBBc2sgcGVyIGRpc2ssIGFuZCBuZXZlciB0b3VjaCBhbnl0aGluZyB0aGF0IGlzIG5vdCB0aGUg
>> "%B64FILE%" echo b25lIHdlIGFyZSBoZXJlIGZvci4NClNheSAiWzIvM10gTW91bnRlZCB2aXJ0dWFsIGRpc2tzIC4u
>> "%B64FILE%" echo LiINCiR2ZHMgPSBAKEdldC1EaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hl
>> "%B64FILE%" echo cmUtT2JqZWN0IHsgW3N0cmluZ10kXy5CdXNUeXBlIC1lcSAnRmlsZSBCYWNrZWQgVmlydHVhbCcg
>> "%B64FILE%" echo fSkNCmlmICgkdmRzLkNvdW50IC1lcSAwKSB7DQogICAgU2F5ICIgICAgICBub25lIG1vdW50ZWQi
>> "%B64FILE%" echo ICdEYXJrR3JheScNCn0gZWxzZSB7DQogICAgZm9yZWFjaCAoJGQgaW4gJHZkcykgew0KICAgICAg
>> "%B64FILE%" echo ICAkbG9jID0gW3N0cmluZ10kZC5Mb2NhdGlvbg0KICAgICAgICBTYXkgKCIgICAgICBEaXNrIHsw
>> "%B64FILE%" echo fTogezF9IiAtZiAkZC5OdW1iZXIsICRsb2MpICdEYXJrR3JheScNCiAgICAgICAgaWYgKC1ub3Qg
>> "%B64FILE%" echo JGxvYykgeyBjb250aW51ZSB9DQogICAgICAgICRhbnMgPSBSZWFkLUhvc3QgKCIgICAgICBEZXRh
>> "%B64FILE%" echo Y2ggdGhpcyBvbmU/IFt5L05dIikNCiAgICAgICAgaWYgKCRhbnMgLW5vdG1hdGNoICdeKD9pKXko
>> "%B64FILE%" echo ZXMpPyQnKSB7IFNheSAiICAgICAga2VwdCBtb3VudGVkIiAnRGFya0dyYXknOyBjb250aW51ZSB9
>> "%B64FILE%" echo DQogICAgICAgICRkcEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICgiZGV0YWNoX3swfS50eHQi
>> "%B64FILE%" echo IC1mICRkLk51bWJlcikNCiAgICAgICAgQCgNCiAgICAgICAgICAgICJzZWxlY3QgdmRpc2sgZmls
>> "%B64FILE%" echo ZT1gIiRsb2NgIiIsDQogICAgICAgICAgICAnZGV0YWNoIHZkaXNrIG5vZXJyJywNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICdleGl0Jw0KICAgICAgICApIHwgU2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRkcEZpbGUg
>> "%B64FILE%" echo LUVuY29kaW5nIERlZmF1bHQNCiAgICAgICAgJHIgPSAmIGRpc2twYXJ0IC9zICRkcEZpbGUgMj4m
>> "%B64FILE%" echo MSB8IE91dC1TdHJpbmcNCiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUg
>> "%B64FILE%" echo LUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQogICAgICAgIGlmICgkciAtbWF0
>> "%B64FILE%" echo Y2ggJ3N1Y2Nlc3NmdWxseXzmiJDlip8nKSB7IFNheSAiICAgICAgZGlzbW91bnRlZCIgJ0dyZWVu
>> "%B64FILE%" echo JyB9DQogICAgICAgIGVsc2UgeyBTYXkgKCIgICAgICBkaXNtb3VudCByZXN1bHQ6ICIgKyAoJHIg
>> "%B64FILE%" echo LXJlcGxhY2UgIlxzKyIsICcgJykuVHJpbSgpKSAnWWVsbG93JyB9DQogICAgfQ0KfQ0KU3RhcnQt
>> "%B64FILE%" echo U2xlZXAgLU1pbGxpc2Vjb25kcyA4MDANCg0KIyAtLS0tLS0tLS0tIDMuIEhhbmRsZSB2aGR4IGZp
>> "%B64FILE%" echo bGVzIHdpdGhvdXQgYSBib290IGVudHJ5IC0tLS0tLS0tLS0NCiMgdjEuMCBvbmx5IGtuZXcgdGhl
>> "%B64FILE%" echo IGhhcmQtY29kZWQgTmV3U3lzdGVtRGlzay52aGR4LiBTaW5jZSB2MS4xMSB0aGUgaW5zdGFsbGVy
>> "%B64FILE%" echo IGFsbG93cyBjdXN0b20gbmFtZXMgYW5kIGZvbGRlcnMsDQojIHNvIGEgaGFuZyBhdCBFOlxWSERc
>> "%B64FILE%" echo bWFpbWFpLnZoZHggd2FzIGludmlzaWJsZSBoZXJlIGFuZCB0aG9zZSAyMEdCIHN0YXllZCBvY2N1
>> "%B64FILE%" echo cGllZCBmb3JldmVyLg0KIw0KIyBCdXQgIm5vIGJvb3QgZW50cnkiIGRvZXMgbm90IG1lYW4gImp1
>> "%B64FILE%" echo bmsgZnJvbSB0aGlzIHRvb2xraXQiLiBIeXBlci1WIGRpc2tzLCBvdGhlciBpbnN0YWxsIHRvb2xz
>> "%B64FILE%" echo IGFuZCB2aGR4IGZpbGVzDQojIHlvdSBwbGFjZWQgeW91cnNlbGYgYWxzbyBoYXZlIG5vIC5ib290
>> "%B64FILE%" echo LnR4dC4gdjEuMSBsaXN0ZWQgdGhlbSBhbGwgYW5kIGFza2VkICJkZWxldGU/IiwgdG9nZXRoZXIg
>> "%B64FILE%" echo d2l0aA0KIyBhIGhpbnQgdGhhdCAiZGVsZXRpbmcgZnJlZXMgMjBHQiIgLSB0aGF0IHdhcyBlbmNv
>> "%B64FILE%" echo dXJhZ2luZyB1c2VycyB0byBwcmVzcyB5IGFuZCBkZWxldGUgb3RoZXIgcGVvcGxlJ3MgZGF0YSwN
>> "%B64FILE%" echo CiMgYW5kICJqdXN0IHByZXNzIEVudGVyIHRvIHNraXAiIHdhcyBsdWNrLCBub3QgZGVzaWduLg0K
>> "%B64FILE%" echo Iw0KIyBTaW5jZSB2MS4yIHRoZXkgYXJlIGhhbmRsZWQgaW4gdGhyZWUgY2F0ZWdvcmllcywgc2Vl
>> "%B64FILE%" echo IHRoZSBmaWxlIGhlYWRlci4NClNheSAiWzMvM10gQ2hlY2tpbmcgdmlydHVhbCBkaXNrcyB3aXRo
>> "%B64FILE%" echo IG5vIGJvb3QgZW50cnkgLi4uIg0KDQojIFNjYW4gYWxsIGRpc2tzIGZvciAqLnZoZHg6IHBydW5l
>> "%B64FILE%" echo IGJ5IGZvbGRlciBuYW1lIG9ubHksIG5ldmVyIGVudGVyaW5nIHN5c3RlbSBmb2xkZXJzIG9yIHRo
>> "%B64FILE%" echo ZSByZWN5Y2xlIGJpbg0KIyA+Pj4gQ09NTU9OOkdldC1BbGxWaGR4RmlsZQ0KIyBJbmplY3RlZCBi
>> "%B64FILE%" echo eSB0aGUgYnVpbGQgc2NyaXB0IGZyb20gdGhlIHNoYXJlZCBjb21tb24vR2V0LUFsbFZoZHhGaWxl
>> "%B64FILE%" echo LnBzMS4gRWRpdGluZyBpdCBoZXJlIGhhcyBubyBlZmZlY3QuDQpmdW5jdGlvbiBHZXQtQWxsVmhk
>> "%B64FILE%" echo eEZpbGUgew0KICAgIHBhcmFtKFtpbnRdJE1heERlcHRoID0gNikNCiAgICAjIFBydW5pbmcgaXMg
>> "%B64FILE%" echo YnkgZm9sZGVyIG5hbWUgb25seSwgbmV2ZXIgZW50ZXJpbmcgc3lzdGVtIGZvbGRlcnMsIHRoZSBy
>> "%B64FILE%" echo ZWN5Y2xlIGJpbiBvciBkZXBlbmRlbmN5IGNhY2hlcywgc28gZGVwdGggNiBzdGF5cyBmYXN0Lg0K
>> "%B64FILE%" echo ICAgICMgVXNlIC5ORVQgZGlyZWN0b3J5IGVudW1lcmF0aW9uIGluc3RlYWQgb2YgR2V0LUNoaWxk
>> "%B64FILE%" echo SXRlbTogdGhlIGxhdHRlciBjcmVhdGVzIGEgUFNPYmplY3QgcGVyIGVudHJ5LA0KICAgICMgbWVh
>> "%B64FILE%" echo c3VyZWQgMTA3NCBtcyB2cyA4MyBtcyBvbiB0aGUgc2FtZSB0cmVlLCBhIDEyeCBkaWZmZXJlbmNl
>> "%B64FILE%" echo ICh0aGUgd2luZG93IHJlc2NhbnMgb24gZXZlcnkgcmVmcmVzaCwgc28gaXQgaXMgdmVyeSB2aXNp
>> "%B64FILE%" echo YmxlKS4NCiAgICAkc2tpcCA9IEAoJyRSRUNZQ0xFLkJJTicsICdTeXN0ZW0gVm9sdW1lIEluZm9y
>> "%B64FILE%" echo bWF0aW9uJywgJ1dpbmRvd3MnLCAnUHJvZ3JhbSBGaWxlcycsDQogICAgICAgICAgICAgICdQcm9n
>> "%B64FILE%" echo cmFtIEZpbGVzICh4ODYpJywgJ1Byb2dyYW1EYXRhJywgJ1VzZXJzJywgJyRXaW5SRUFnZW50Jywg
>> "%B64FILE%" echo J1JlY292ZXJ5JywNCiAgICAgICAgICAgICAgJ25vZGVfbW9kdWxlcycsICcuZ2l0JywgJ1dpblN4
>> "%B64FILE%" echo UycpDQogICAgJGZvdW5kID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0
>> "%B64FILE%" echo DQogICAgZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
>> "%B64FILE%" echo bnRpbnVlKSkgew0KICAgICAgICBpZiAoLW5vdCAkdi5Ecml2ZUxldHRlcikgeyBjb250aW51ZSB9
>> "%B64FILE%" echo DQogICAgICAgIGlmICgkdi5GaWxlU3lzdGVtIC1uZSAnTlRGUycpIHsgY29udGludWUgfQ0KICAg
>> "%B64FILE%" echo ICAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAg
>> "%B64FILE%" echo JHF1ZXVlID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuUXVldWUNCiAgICAgICAgJHF1
>> "%B64FILE%" echo ZXVlLkVucXVldWUoQCgiJCgkdi5Ecml2ZUxldHRlcik6XCIsIDApKQ0KICAgICAgICB3aGlsZSAo
>> "%B64FILE%" echo JHF1ZXVlLkNvdW50IC1ndCAwKSB7DQogICAgICAgICAgICAkY3VyID0gJHF1ZXVlLkRlcXVldWUo
>> "%B64FILE%" echo KQ0KICAgICAgICAgICAgJGRpciA9IFtzdHJpbmddJGN1clswXQ0KICAgICAgICAgICAgJGQgPSBb
>> "%B64FILE%" echo aW50XSRjdXJbMV0NCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFjaCAo
>> "%B64FILE%" echo JGYgaW4gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRGaWxlcygkZGlyLCAnKi52aGR4JykpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICAgICAgW3ZvaWRdJGZvdW5kLkFkZCgoTmV3LU9iamVjdCBTeXN0ZW0u
>> "%B64FILE%" echo SU8uRmlsZUluZm8gJGYpKQ0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgIH0gY2F0Y2gg
>> "%B64FILE%" echo e30NCiAgICAgICAgICAgIGlmICgkZCAtZ2UgJE1heERlcHRoKSB7IGNvbnRpbnVlIH0NCiAgICAg
>> "%B64FILE%" echo ICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHN1YiBpbiBbU3lzdGVtLklP
>> "%B64FILE%" echo LkRpcmVjdG9yeV06OkVudW1lcmF0ZURpcmVjdG9yaWVzKCRkaXIpKSB7DQogICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIGlmICgkc2tpcCAtY29udGFpbnMgW1N5c3RlbS5JTy5QYXRoXTo6R2V0RmlsZU5hbWUo
>> "%B64FILE%" echo JHN1YikpIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB0cnkgew0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgaWYgKFtTeXN0ZW0uSU8uRmlsZV06OkdldEF0dHJpYnV0ZXMoJHN1Yikg
>> "%B64FILE%" echo LWJhbmQgW1N5c3RlbS5JTy5GaWxlQXR0cmlidXRlc106OlJlcGFyc2VQb2ludCkgeyBjb250aW51
>> "%B64FILE%" echo ZSB9DQogICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBjb250aW51ZSB9DQogICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoJHN1YiwgKCRkICsgMSkpKQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgIH0NCiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAgICAgICAgfQ0KICAgIH0NCiAgICByZXR1
>> "%B64FILE%" echo cm4gJGZvdW5kLlRvQXJyYXkoKQ0KfQ0KIyA8PDwgQ09NTU9OOkdldC1BbGxWaGR4RmlsZQ0KDQpm
>> "%B64FILE%" echo dW5jdGlvbiBHZXQtVmhkU3RhdGVHdWlkIHsNCiAgICBwYXJhbShbc3RyaW5nXSRQYXRoKQ0KICAg
>> "%B64FILE%" echo ICRzdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVuc2lvbigkUGF0aCwgJy5ib290LnR4
>> "%B64FILE%" echo dCcpDQogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSkgeyByZXR1cm4g
>> "%B64FILE%" echo JycgfQ0KICAgIGZvcmVhY2ggKCRsbiBpbiAoR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRzdCAt
>> "%B64FILE%" echo RW5jb2RpbmcgVVRGOCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAg
>> "%B64FILE%" echo aWYgKCRsbiAtbWF0Y2ggJ15ccypHdWlkXHMqPVxzKihce1swLTlhLWZBLUYtXXszNn1cfSlccyok
>> "%B64FILE%" echo JykgeyByZXR1cm4gJG1hdGNoZXNbMV0gfQ0KICAgIH0NCiAgICByZXR1cm4gJycNCn0NCg0KIyBJ
>> "%B64FILE%" echo cyB0aGlzIGJvb3QgZW50cnkgc3RpbGwgaW4gdGhlIEJDRCAoZXhpc3RlbmNlIG9ubHksIHRoZSB0
>> "%B64FILE%" echo YXJnZXQgaXMgbm90IGNoZWNrZWQpDQpmdW5jdGlvbiBUZXN0LUJjZEVudHJ5UHJlc2VudCB7DQog
>> "%B64FILE%" echo ICAgcGFyYW0oW3N0cmluZ10kR3VpZCkNCiAgICBpZiAoLW5vdCAkR3VpZCkgeyByZXR1cm4gJGZh
>> "%B64FILE%" echo bHNlIH0NCiAgICAkdHh0ID0gJycNCiAgICB0cnkgeyAkdHh0ID0gKCYgYmNkZWRpdCAvZW51bSAk
>> "%B64FILE%" echo R3VpZCAyPiYxIHwgT3V0LVN0cmluZykgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQ0KICAgIGlm
>> "%B64FILE%" echo ICgkTEFTVEVYSVRDT0RFIC1uZSAwKSB7IHJldHVybiAkZmFsc2UgfQ0KICAgIGlmICgkdHh0IC1t
>> "%B64FILE%" echo YXRjaCAn5om+5LiN5YiwfG5vdCBmb3VuZHzml6DmlYh8aW52YWxpZHzmi5Lnu518ZGVuaWVkJykg
>> "%B64FILE%" echo eyByZXR1cm4gJGZhbHNlIH0NCiAgICByZXR1cm4gKCR0eHQgLW1hdGNoICcoP2kpaWRlbnRpZmll
>> "%B64FILE%" echo cnzmoIfor4bnrKYnKQ0KfQ0KDQojIERlbGV0ZSB0aGUgLmJvb3QudHh0IG5leHQgdG8gdGhlIHZo
>> "%B64FILE%" echo ZHggYWxvbmcgd2l0aCBpdC4NCiMgRGVsZXRpbmcgb25seSB0aGUgdmhkeCB3b3VsZCBtYWtlIHRo
>> "%B64FILE%" echo ZSBuZXh0IHNjYW4gY2xhc3NpZnkgdGhlIGVtcHR5IHNoZWxsIGFzIEIgYW5kIGFzayBhZ2FpbiwN
>> "%B64FILE%" echo CiMgYW5kIGEgLmJvb3QudHh0IHBvaW50aW5nIGF0IGEgdmhkeCB0aGF0IG5vIGxvbmdlciBleGlz
>> "%B64FILE%" echo dHMgYWxzbyBtaXNsZWFkcyBvdGhlciB0b29scy4NCmZ1bmN0aW9uIFJlbW92ZS1WaGRTYWZlbHkg
>> "%B64FILE%" echo ew0KICAgIHBhcmFtKCRJdGVtKQ0KICAgIHRyeSB7DQogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRl
>> "%B64FILE%" echo cmFsUGF0aCAkSXRlbS5QYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICBTYXkg
>> "%B64FILE%" echo IiAgICAgICAgICAgICBkZWxldGVkIiAnR3JlZW4nDQogICAgICAgICRzdCA9IFtTeXN0ZW0uSU8u
>> "%B64FILE%" echo UGF0aF06OkNoYW5nZUV4dGVuc2lvbigkSXRlbS5QYXRoLCAnLmJvb3QudHh0JykNCiAgICAgICAg
>> "%B64FILE%" echo aWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSB7DQogICAgICAgICAgICBSZW1vdmUtSXRl
>> "%B64FILE%" echo bSAtTGl0ZXJhbFBhdGggJHN0IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0K
>> "%B64FILE%" echo ICAgICAgICB9DQogICAgfSBjYXRjaCB7DQogICAgICAgIFNheSAoIiAgICAgICAgICAgICBkZWxl
>> "%B64FILE%" echo dGlvbiBmYWlsZWQ6ICIgKyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1JlZCcNCiAgICAgICAgU2F5
>> "%B64FILE%" echo ICIgICAgICAgICAgICAgdXN1YWxseSBhIHByb2Nlc3Mgc3RpbGwgaG9sZHMgaXQgLSByZWJvb3Qg
>> "%B64FILE%" echo YW5kIHJ1biB0aGlzIHRvb2wgYWdhaW4uIiAnWWVsbG93Jw0KICAgIH0NCn0NCg0KJGNhdEEgPSBO
>> "%B64FILE%" echo ZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgICAjIGluc3RhbGxlZCAoZW50
>> "%B64FILE%" echo cnkgcHJlc2VudCkNCiRjYXRCID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlM
>> "%B64FILE%" echo aXN0ICAgIyBpbnN0YWxsZWQgYnkgdGhpcyB0b29sa2l0LCBlbnRyeSBnb25lDQokY2F0QyA9IE5l
>> "%B64FILE%" echo dy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdCAgICMgbm90IGNyZWF0ZWQgYnkg
>> "%B64FILE%" echo dGhpcyB0b29sa2l0DQoNCmZvcmVhY2ggKCRmIGluIEAoR2V0LUFsbFZoZHhGaWxlKSkgew0KICAg
>> "%B64FILE%" echo ICRzeiA9IDANCiAgICB0cnkgeyAkc3ogPSBbbWF0aF06OlJvdW5kKCRmLkxlbmd0aCAvIDFHQiwg
>> "%B64FILE%" echo MikgfSBjYXRjaCB7fQ0KICAgICRzdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVuc2lv
>> "%B64FILE%" echo bigkZi5GdWxsTmFtZSwgJy5ib290LnR4dCcpDQogICAgJGhhc1N0YXRlID0gVGVzdC1QYXRoIC1M
>> "%B64FILE%" echo aXRlcmFsUGF0aCAkc3QNCiAgICAkZ3VpZCA9ICcnDQogICAgaWYgKCRoYXNTdGF0ZSkgeyAkZ3Vp
>> "%B64FILE%" echo ZCA9IEdldC1WaGRTdGF0ZUd1aWQgLVBhdGggJGYuRnVsbE5hbWUgfQ0KICAgICRpdGVtID0gW1BT
>> "%B64FILE%" echo Q3VzdG9tT2JqZWN0XUB7IFBhdGggPSAkZi5GdWxsTmFtZTsgU2l6ZUdCID0gJHN6OyBIYXNTdGF0
>> "%B64FILE%" echo ZSA9ICRoYXNTdGF0ZSB9DQogICAgaWYgKFRlc3QtQmNkRW50cnlQcmVzZW50IC1HdWlkICRndWlk
>> "%B64FILE%" echo KSB7DQogICAgICAgIFt2b2lkXSRjYXRBLkFkZCgkaXRlbSkNCiAgICB9IGVsc2VpZiAoJGhhc1N0
>> "%B64FILE%" echo YXRlKSB7DQogICAgICAgIFt2b2lkXSRjYXRCLkFkZCgkaXRlbSkNCiAgICB9IGVsc2Ugew0KICAg
>> "%B64FILE%" echo ICAgICBbdm9pZF0kY2F0Qy5BZGQoJGl0ZW0pDQogICAgfQ0KfQ0KDQppZiAoJGNhdEEuQ291bnQg
>> "%B64FILE%" echo LWd0IDApIHsNCiAgICBTYXkgIiAgICAgIFRoZXNlIGFyZSBpbnN0YWxsZWQgd2l0aCB0aGVpciBi
>> "%B64FILE%" echo b290IGVudHJ5IGludGFjdDsgdGhpcyB0b29sIG5ldmVyIHRvdWNoZXMgdGhlbToiICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEEpIHsNCiAgICAgICAgU2F5ICgoJyAgICAgICAg
>> "%B64FILE%" echo ezB9ICAgKHsxfSBHQiknIC1mICRpdC5QYXRoLCAkaXQuU2l6ZUdCKSkgJ0RhcmtHcmF5Jw0KICAg
>> "%B64FILE%" echo IH0NCiAgICBTYXkgIiAgICAgICh0byBkZWxldGUgdGhlbSB1c2UgVW5pbnN0YWxsLVN5c3RlbS5i
>> "%B64FILE%" echo YXQsIGl0IGFsc28gY2xlYW5zIHRoZSBib290IG1lbnUpIiAnRGFya0dyYXknDQp9DQoNCmlmICgo
>> "%B64FILE%" echo JGNhdEIuQ291bnQgKyAkY2F0Qy5Db3VudCkgLWVxIDApIHsNCiAgICBTYXkgIiAgICAgIE5vdGhp
>> "%B64FILE%" echo bmcgdG8gaGFuZGxlLCB0aGUgZW52aXJvbm1lbnQgaXMgYWxyZWFkeSBjbGVhbiIgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KfSBlbHNlIHsNCiAgICBpZiAoJGNhdEIuQ291bnQgLWd0IDApIHsNCiAgICAgICAgU2F5ICIi
>> "%B64FILE%" echo DQogICAgICAgIFNheSAoIiAgICAgIFtCXSBpbnN0YWxsZWQgYnkgdGhpcyB0b29sa2l0IGJ1dCB0
>> "%B64FILE%" echo aGUgYm9vdCBlbnRyeSBpcyBnb25lICh7MH0pIiAtZiAkY2F0Qi5Db3VudCkgJ1doaXRlJw0KICAg
>> "%B64FILE%" echo ICAgICBTYXkgIiAgICAgICAgICBUaGUgLmJvb3QudHh0IGxlZnQgYnkgdGhpcyB0b29sa2l0IHNp
>> "%B64FILE%" echo dHMgbmV4dCB0byB0aGVtOyBkZWxldGluZyB0aGVzZSBjYW5ub3QgYWZmZWN0IGFueSBib290YWJs
>> "%B64FILE%" echo ZSBzeXN0ZW0uIiAnRGFya0dyYXknDQogICAgICAgIGZvcmVhY2ggKCRpdCBpbiAkY2F0Qikgew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgU2F5ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBhdGgs
>> "%B64FILE%" echo ICRpdC5TaXplR0IpKSAnV2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAg
>> "%B64FILE%" echo ICAgICAgICAgRGVsZXRlIHRoZW0/IFR5cGUgeSB0byBkZWxldGUsIG9yIHByZXNzIEVudGVyIHRv
>> "%B64FILE%" echo IHNraXAiDQogICAgICAgICAgICBpZiAoJGFucyAtYW5kICgkYW5zLlRyaW0oKSAtaWVxICd5Jykp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgICAgICBSZW1vdmUtVmhkU2FmZWx5IC1JdGVtICRpdA0KICAgICAgICAg
>> "%B64FILE%" echo ICAgfSBlbHNlIHsNCiAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICBza2lwcGVkIiAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQogICAgaWYgKCRjYXRD
>> "%B64FILE%" echo LkNvdW50IC1ndCAwKSB7DQogICAgICAgIFNheSAiIg0KICAgICAgICBTYXkgKCIgICAgICBbQ10g
>> "%B64FILE%" echo bm90IGNyZWF0ZWQgYnkgdGhpcyB0b29sa2l0ICh7MH0pIiAtZiAkY2F0Qy5Db3VudCkgJ1doaXRl
>> "%B64FILE%" echo Jw0KICAgICAgICBTYXkgIiAgICAgICAgICBObyAuYm9vdC50eHQgZnJvbSB0aGlzIHRvb2xraXQu
>> "%B64FILE%" echo IFRoZXkgbWF5IGJlIEh5cGVyLVYgdmlydHVhbCBkaXNrcywgYW5vdGhlciBpbnN0YWxsIiAnRGFy
>> "%B64FILE%" echo a0dyYXknDQogICAgICAgIFNheSAiICAgICAgICAgIHRvb2wsIG9yIGEgYmFja3VwIG9mIHlvdXIg
>> "%B64FILE%" echo b3duLiBOb3QgZGVsZXRlZCBieSBkZWZhdWx0LCBhbmQgbm90IHJlY29tbWVuZGVkLiIgJ0RhcmtH
>> "%B64FILE%" echo cmF5Jw0KICAgICAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEMpIHsNCiAgICAgICAgICAgICRmbiA9
>> "%B64FILE%" echo IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRpdC5QYXRoKQ0KICAgICAgICAgICAgU2F5
>> "%B64FILE%" echo ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBhdGgsICRpdC5TaXplR0IpKSAn
>> "%B64FILE%" echo V2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICgiICAgICAgICAgICAgIFRvIHJl
>> "%B64FILE%" echo YWxseSBkZWxldGUgb25lLCB0eXBlIGl0cyBmaWxlIG5hbWUgezB9IChvciBwcmVzcyBFbnRlciB0
>> "%B64FILE%" echo byBza2lwKSIgLWYgJGZuKQ0KICAgICAgICAgICAgaWYgKC1ub3QgJGFucykgew0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIFNheSAiICAgICAgICAgICAgIHNraXBwZWQiICdEYXJrR3JheScNCiAgICAgICAgICAg
>> "%B64FILE%" echo IH0gZWxzZWlmICgkYW5zLlRyaW0oKSAtaWVxICRmbikgew0KICAgICAgICAgICAgICAgIFJlbW92
>> "%B64FILE%" echo ZS1WaGRTYWZlbHkgLUl0ZW0gJGl0DQogICAgICAgICAgICB9IGVsc2Ugew0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICMgRG8gbm90IHNheSAid3JvbmcgZmlsZSBuYW1lIiBpbiB5ZWxsb3cgLSBtYW55IHBlb3Bs
>> "%B64FILE%" echo ZSB0cnkgeSAvIHllcyBmaXJzdCBiZWNhdXNlIHRoZXkgZG8gd2FudCBpdCBkZWxldGVkLA0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICMgdGhleSBqdXN0IGRvIG5vdCBrbm93IHRoYXQgdGhpcyBwcm9tcHQgZG9l
>> "%B64FILE%" echo cyBub3QgdGFrZSB5LiBFeHBsYWluIGNhbG1seSBob3cgdG8gZGVsZXRlLCBuZXZlciBzY29sZC4N
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICAgICAgICAgc2tpcHBlZC4gVG8gZGVsZXRlIHRo
>> "%B64FILE%" echo aXMgb25lLCB0eXBlIGl0cyBmdWxsIGZpbGUgbmFtZTogezB9IiAtZiAkZm4pICdEYXJrR3JheScN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBpZiAoJGFucy5UcmltKCkgLWltYXRjaCAnXih5fHllc3zmmK985Yig
>> "%B64FILE%" echo fOWIoOmZpHxvaykkJykgew0KICAgICAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICAo
>> "%B64FILE%" echo dGhpcyBwcm9tcHQgZGVsaWJlcmF0ZWx5IGRvZXMgbm90IGFjY2VwdCB5IC0gaXQgZ3VhcmRzIGFn
>> "%B64FILE%" echo YWluc3QgZGVsZXRpbmcgc29tZWJvZHkgZWxzZSdzIHZpcnR1YWwgZGlzaykiICdEYXJrR3JheScN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQp9DQoN
>> "%B64FILE%" echo CiMgLS0tLS0tLS0tLSBTdGVwIDQgKHYxLjI5KTogY2xlYW4gdGhlIGNvbXBhbmlvbiBsb2dzIGJj
>> "%B64FILE%" echo ZGVkaXQgbGVhdmVzIHdoZW4gZXhwb3J0aW5nIHRoZSBCQ0QgLS0tLS0tLS0tLQ0KIw0KIyBiY2Rl
>> "%B64FILE%" echo ZGl0IC9leHBvcnQgd3JpdGVzIGEgcmVnaXN0cnkgaGl2ZSwgYW5kIFdpbmRvd3MgZHJvcHMgY29t
>> "%B64FILE%" echo cGFuaW9uIHRyYW5zYWN0aW9uIGxvZ3MgbmV4dCB0byBpdDoNCiMgICB4eHguYmNkLkxPRyAgeHh4
>> "%B64FILE%" echo LmJjZC5MT0cxICB4eHguYmNkLkxPRzINCiMgTWVhc3VyZWQgb24gcmVhbCBoYXJkd2FyZTogMzEg
>> "%B64FILE%" echo LmJjZC5MT0cqIGZpbGVzIHBpbGVkIHVwIGluIHRoZSByb290IG9mIEQ6XCBhbmQgYW5vdGhlciAx
>> "%B64FILE%" echo OCBpbiBEOlxWaXJ0dWFsRGlza3NcLg0KIyBUaGVzZSBjb21wYW5pb24gZmlsZXMgY2FycnkgdGhl
>> "%B64FILE%" echo IEhpZGRlbiArIFN5c3RlbSBhdHRyaWJ1dGVzLCBzbyBHZXQtQ2hpbGRJdGVtIG11c3QgYmUgY2Fs
>> "%B64FILE%" echo bGVkIHdpdGggLUZvcmNlLA0KIyBvdGhlcndpc2Ugbm90IGEgc2luZ2xlIG9uZSBpcyBmb3VuZCAo
>> "%B64FILE%" echo ZXhhY3RseSB3aGF0IHYxLjI5IG1pc3NlZCwgbWFraW5nIHRoZSBmZWF0dXJlIHNpbGVudGx5IGRv
>> "%B64FILE%" echo IG5vdGhpbmcpLg0KIyBUaGV5IGFyZSBpbnRlcm1lZGlhdGUgZmlsZXMgb2YgdGhlIGV4cG9ydCwg
>> "%B64FILE%" echo dXNlbGVzcyBmb3IgcmVzdG9yaW5nIHRoZSBCQ0QsIGFuZCBkZWxldGluZyB0aGVtIGRvZXMgbm90
>> "%B64FILE%" echo IGFmZmVjdCB0aGUgLmJjZCBiYWNrdXAuDQojIFNpbmNlIHYxLjI5IHRoZSBpbnN0YWxsZXIvcmVw
>> "%B64FILE%" echo YWlyIHRvb2wgZXhwb3J0IHRvIGEgdGVtcCBmb2xkZXIgZmlyc3QgYW5kIHRoZW4gY29weSwgc28g
>> "%B64FILE%" echo bm8gbmV3IG9uZXMgYXBwZWFyOw0KIyB0aGlzIHNlY3Rpb24gaXMgdGhlIGNsZWFuLXVwIGZvciB3
>> "%B64FILE%" echo aGF0IGhhcyBhbHJlYWR5IHBpbGVkIHVwLg0KJHN0cmF5TG9ncyA9IE5ldy1PYmplY3QgU3lzdGVt
>> "%B64FILE%" echo LkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KIw0KIyBbdjEuMzEgaGFyZGVuaW5nXSBUaGlzIHVzZWQg
>> "%B64FILE%" echo dG8gc2NhbiB0aGUgcm9vdCBhbmQgZmlyc3QtbGV2ZWwgc3ViZm9sZGVycyBvZiA2IGRyaXZlcyB3
>> "%B64FILE%" echo aXRoIHRoZSAnKi5iY2QuTE9HKicgd2lsZGNhcmQNCiMgYW5kIHRoZW4gUmVtb3ZlLUl0ZW0gZXZl
>> "%B64FILE%" echo cnl0aGluZy4gSW4gcHJhY3RpY2Ugbm8gc3lzdGVtIGZpbGUgd2FzIGV2ZXIgaGl0IC0gYnV0IHRo
>> "%B64FILE%" echo YXQgd2FzIGx1Y2sgZnJvbSBhIC1GaWx0ZXIgOC4zDQojIHNob3J0LW5hbWUgcXVpcmsgdGhhdCBo
>> "%B64FILE%" echo YXBwZW5lZCBub3QgdG8gbWF0Y2ggIkJDRC5MT0ciLCBub3QgcHJvdGVjdGlvbiBpbiB0aGUgY29k
>> "%B64FILE%" echo ZS4gTWVhbndoaWxlDQojIEM6XEJvb3RcQkNELkxPRyAvIEJDRC5MT0cxIC8gQkNELkxPRzIgYXJl
>> "%B64FILE%" echo IHRoZSAqKnRyYW5zYWN0aW9uIGxvZ3Mgb2YgdGhlIGFjdGl2ZSBCQ0QqKiwgdHdvIGxldHRlcnMg
>> "%B64FILE%" echo YXdheSwNCiMgc28gYW5vdGhlciBzcGVsbGluZyBvciBhbm90aGVyIG1hY2hpbmUgY291bGQgaGl0
>> "%B64FILE%" echo IHRoZW0sIGFuZCBkZWxldGluZyB0aGVtIHJpc2tzIGEgY29ycnVwdGVkIGJvb3QgY29uZmlndXJh
>> "%B64FILE%" echo dGlvbi4NCiMNCiMgSXQgaXMgYSB3aGl0ZWxpc3Qgbm93OiBvbmx5IHRoZSBleGFjdCBmb3JtYXQg
>> "%B64FILE%" echo dGhpcyB0b29sa2l0IGhhcyBleHBvcnRlZCBvdmVyIHRoZSB2ZXJzaW9ucyBpcyBtYXRjaGVkLCBu
>> "%B64FILE%" echo b3RoaW5nIGVsc2UuDQojICAgYmNkLWJhY2t1cC08eXl5eU1NZGQ+LTxISG1tc3M+LmJjZC5MT0cg
>> "%B64FILE%" echo LyAuTE9HMSAvIC5MT0cyDQojICAgYmNkLWJhY2t1cC1maXgtPHl5eXlNTWRkPi08SEhtbXNzPi5i
>> "%B64FILE%" echo Y2QuTE9HIC4uLg0KIyAgIGJjZC1yZXNjdWUtPHl5eXlNTWRkPi08SEhtbXNzPi5iY2QuTE9HIC4u
>> "%B64FILE%" echo LiAgIChlYXJseSB2ZXJzaW9ucyB1c2VkIHRoaXMgcHJlZml4KQ0KIyBUaGUga2V5IHBvaW50OiBp
>> "%B64FILE%" echo dCBtdXN0IHN0YXJ0IHdpdGggYmNkLSwgY2FycnkgYW4gOC1kaWdpdCBkYXRlIHBsdXMgYSA2LWRp
>> "%B64FILE%" echo Z2l0IHRpbWUsIGFuZCBlbmQgaW4gLmJjZC4NCiMgTm9uZSBvZiB0aGUgdGhyZWUgc3lzdGVtIG5h
>> "%B64FILE%" echo bWVzIEM6XEJvb3RcQkNELkxPRyBtYXRjaGVzIGFueSBvZiB0aGF0LCBzbyBpdCBpcyBzdHJ1Y3R1
>> "%B64FILE%" echo cmFsbHkgaW1wb3NzaWJsZSB0byBzZWxlY3QgdGhlbS4NCiMgVGhlIHN5c3RlbSBmb2xkZXJzIGFy
>> "%B64FILE%" echo ZSBleGNsdWRlZCBhZ2FpbiBhdCBkaXJlY3RvcnkgbGV2ZWwsIGFzIGEgc2Vjb25kIGxpbmUgb2Yg
>> "%B64FILE%" echo ZGVmZW5jZS4NCiRpc1N0cmF5QmNkTG9nID0gew0KICAgIHBhcmFtKFtzdHJpbmddJG4pDQogICAg
>> "%B64FILE%" echo cmV0dXJuICgkbiAtbWF0Y2ggJ15iY2QtW2Etel0rKD86LVthLXpdKykqLVxkezh9LVxkezZ9XC5i
>> "%B64FILE%" echo Y2RcLkxPR1swLTldPyQnKQ0KfQ0KJHNraXBTdWJEaXJzID0gJ14oV2luZG93c3xQcm9ncmFtIEZp
>> "%B64FILE%" echo bGVzLip8XCRSZWN5Y2xlXC5CaW58U3lzdGVtIFZvbHVtZSBJbmZvcm1hdGlvbnxVc2Vyc3xCb290
>> "%B64FILE%" echo fFJlY292ZXJ5fEVGSXxQZXJmTG9ncykkJw0KZm9yZWFjaCAoJHJ0IGluIEAoJ0M6XCcsICdEOlwn
>> "%B64FILE%" echo LCAnRTpcJywgJ0Y6XCcsICdHOlwnLCAnSDpcJykpIHsNCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRo
>> "%B64FILE%" echo IC1MaXRlcmFsUGF0aCAkcnQpKSB7IGNvbnRpbnVlIH0NCiAgICBmb3JlYWNoICgkZiBpbiBAKEdl
>> "%B64FILE%" echo dC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRydCAtRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29u
>> "%B64FILE%" echo dGludWUpKSB7DQogICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRmLk5hbWUpIHsgW3ZvaWRd
>> "%B64FILE%" echo JHN0cmF5TG9ncy5BZGQoJGYpIH0NCiAgICB9DQogICAgZm9yZWFjaCAoJGQgaW4gQChHZXQtQ2hp
>> "%B64FILE%" echo bGRJdGVtIC1MaXRlcmFsUGF0aCAkcnQgLURpcmVjdG9yeSAtRm9yY2UgLUVBIFNpbGVudGx5Q29u
>> "%B64FILE%" echo dGludWUpKSB7DQogICAgICAgIGlmICgkZC5OYW1lIC1tYXRjaCAkc2tpcFN1YkRpcnMpIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICAgICBmb3JlYWNoICgkZiBpbiBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQ
>> "%B64FILE%" echo YXRoICRkLkZ1bGxOYW1lIC1GaWxlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSkpIHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRmLk5hbWUpIHsgW3ZvaWRdJHN0cmF5TG9n
>> "%B64FILE%" echo cy5BZGQoJGYpIH0NCiAgICAgICAgfQ0KICAgIH0NCn0NCg0KaWYgKCRzdHJheUxvZ3MuQ291bnQg
>> "%B64FILE%" echo LWd0IDApIHsNCiAgICAkc3ogPSAoJHN0cmF5TG9ncyB8IE1lYXN1cmUtT2JqZWN0IC1Qcm9wZXJ0
>> "%B64FILE%" echo eSBMZW5ndGggLVN1bSkuU3VtDQogICAgU2F5ICIiDQogICAgU2F5ICgiICAgICAgW2V4dHJhXSBj
>> "%B64FILE%" echo b21wYW5pb24gbG9ncyBsZWZ0IGJ5IGJjZGVkaXQgd2hlbiBleHBvcnRpbmcgdGhlIEJDRCAoezB9
>> "%B64FILE%" echo IGZpbGVzLCB7MTpOMX0gTUIgaW4gdG90YWwpIiAtZiAkc3RyYXlMb2dzLkNvdW50LCAoJHN6IC8g
>> "%B64FILE%" echo MU1CKSkgJ1doaXRlJw0KICAgIFNheSAiICAgICAgICAgIFRoZXNlIGFyZSB0aGUgLkxPRyAvIC5M
>> "%B64FILE%" echo T0cxIC8gLkxPRzIgZmlsZXMgbmV4dCB0byBiY2QtYmFja3VwLSouYmNkLiIgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo ICAgIFNheSAiICAgICAgICAgIFRoZXkgYXJlIGludGVybWVkaWF0ZSBmaWxlcyBvZiB0aGUgZXhw
>> "%B64FILE%" echo b3J0OyBkZWxldGluZyB0aGVtIGFmZmVjdHMgbmVpdGhlciB0aGUgLmJjZCBiYWNrdXAgbm9yIGJv
>> "%B64FILE%" echo b3RpbmcuIiAnRGFya0dyYXknDQogICAgU2F5ICIgICAgICAgICAgT25seSBiYWNrdXAgbmFtZXMg
>> "%B64FILE%" echo ZXhwb3J0ZWQgYnkgdGhpcyB0b29sa2l0IG1hdGNoOyB0aGUgc3lzdGVtJ3Mgb3duIEM6XEJvb3Rc
>> "%B64FILE%" echo QkNELkxPRyBpcyBvdXQgb2Ygc2NvcGUgYW5kIG5ldmVyIHRvdWNoZWQuIiAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgZm9yZWFjaCAoJGYgaW4gQCgkc3RyYXlMb2dzIHwgU29ydC1PYmplY3QgRnVsbE5hbWUgfCBT
>> "%B64FILE%" echo ZWxlY3QtT2JqZWN0IC1GaXJzdCA4KSkgew0KICAgICAgICBTYXkgKCIgICAgICAgICAgIiArICRm
>> "%B64FILE%" echo LkZ1bGxOYW1lKSAnRGFya0dyYXknDQogICAgfQ0KICAgIGlmICgkc3RyYXlMb2dzLkNvdW50IC1n
>> "%B64FILE%" echo dCA4KSB7IFNheSAoIiAgICAgICAgICAuLi4gYW5kIHswfSBtb3JlIiAtZiAoJHN0cmF5TG9ncy5D
>> "%B64FILE%" echo b3VudCAtIDgpKSAnRGFya0dyYXknIH0NCiAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAgICAgICAg
>> "%B64FILE%" echo ICAgRGVsZXRlIHRoZW0gYWxsPyBUeXBlIHkgdG8gZGVsZXRlLCBvciBwcmVzcyBFbnRlciB0byBz
>> "%B64FILE%" echo a2lwIg0KICAgIGlmICgkYW5zIC1hbmQgKCRhbnMuVHJpbSgpIC1pZXEgJ3knKSkgew0KICAgICAg
>> "%B64FILE%" echo ICAkb2tOID0gMA0KICAgICAgICBmb3JlYWNoICgkZiBpbiAkc3RyYXlMb2dzKSB7DQogICAgICAg
>> "%B64FILE%" echo ICAgICB0cnkgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGYuRnVsbE5hbWUgLUZvcmNlIC1F
>> "%B64FILE%" echo QSBTdG9wOyAkb2tOKysgfSBjYXRjaCB7fQ0KICAgICAgICB9DQogICAgICAgIFNheSAoIiAgICAg
>> "%B64FILE%" echo ICAgICAgICBkZWxldGVkIHswfSAvIHsxfSIgLWYgJG9rTiwgJHN0cmF5TG9ncy5Db3VudCkgJ0dy
>> "%B64FILE%" echo ZWVuJw0KICAgICAgICBpZiAoJG9rTiAtbHQgJHN0cmF5TG9ncy5Db3VudCkgeyBTYXkgIiAgICAg
>> "%B64FILE%" echo ICAgICAgICB0aGUgb25lcyB0aGF0IGNhbm5vdCBiZSBkZWxldGVkIGFyZSB1c3VhbGx5IGhlbGQg
>> "%B64FILE%" echo YnkgYW5vdGhlciBwcm9ncmFtOyByZWJvb3QgYW5kIHJlcnVuIiAnRGFya0dyYXknIH0NCiAgICB9
>> "%B64FILE%" echo IGVsc2Ugew0KICAgICAgICBTYXkgIiAgICAgICAgICAgICBza2lwcGVkIChub3RoaW5nIGRlbGV0
>> "%B64FILE%" echo ZWQpIiAnRGFya0dyYXknDQogICAgfQ0KfQ0KDQpTYXkgIiINClNheSAiICAtLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3Jh
>> "%B64FILE%" echo eScNClNheSAiICBDbGVhbnVwIGNvbXBsZXRlLiIgJ0dyZWVuJw0KU2F5ICIiDQpTYXkgIiAgSG93
>> "%B64FILE%" echo IHRvIHJlaW5zdGFsbCBwcm9wZXJseToiICdXaGl0ZScNClNheSAiICAgIDEuIERvdWJsZS1jbGlj
>> "%B64FILE%" echo ayBJbnN0YWxsLVN5c3RlbS5iYXQgYWdhaW4iICdEYXJrR3JheScNClNheSAiICAgICAgIHRoZSBw
>> "%B64FILE%" echo cm9ncmVzcyBiYXIgc2hvd3MgaG93IG1hbnkgR0IgaGF2ZSBiZWVuIHdyaXR0ZW47IGFzIGxvbmcg
>> "%B64FILE%" echo YXMgdGhlIG51bWJlciBncm93cyBpdCBpcyB3b3JraW5nLCBkbyBub3QgY2xvc2UgaXQiICdEYXJr
>> "%B64FILE%" echo R3JheScNClNheSAiICAgIDIuIFJlYm9vdCBhZnRlciBpdCBmaW5pc2hlcyBhbmQgY2hvb3NlIHRo
>> "%B64FILE%" echo ZSBuZXcgc3lzdGVtIGluIHRoZSBib290IG1lbnUiICdEYXJrR3JheScNClNheSAiIg0KUmVhZC1I
>> "%B64FILE%" echo b3N0ICIgIFByZXNzIEVudGVyIHRvIGV4aXQiDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem The byte count must be verified: certutil does not return a reliable error code,
rem and the file may exist as 0 bytes or half written, so an existence check is not enough.
set "NEED=18326"
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
