@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 注入网卡驱动
cd /d "%~dp0"

rem ---------------------------------------------------------------- 管理员权限
rem 提权只在这里做一次，作用在 bat 自身。
rem 绝对不要再用 powershell -Command "... Start-Process -ArgumentList '\"...\"' ..."
rem 这种嵌套引号：它只在部分环境成立，一旦被 -Command 提前截断，powershell 解析失败
rem 直接退出，而下面紧跟 exit /b，窗口一闪就没 —— 没有提示，也不写日志，看起来就像闪退。
rem （2026-11-05 实测：整个英文版都因为这个原因打不开。）
rem 改成先提权、再用普通 -File 运行脚本，任何错误都留在窗口里。
fltmc >nul 2>&1
if errorlevel 1 (
    echo   正在申请管理员权限，请在弹窗中选「是」...
    set "ELEV_ARGS=%*"
    if defined ELEV_ARGS (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList $env:ELEV_ARGS } catch { exit 9 }"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
    )
    if errorlevel 9 (
        echo.
        echo   [错误] 没能获得管理员权限。
        echo          请右键本文件，选择「以管理员身份运行」。
        echo.
        pause
    )
    exit /b
)

rem ---------------------------------------------------------------- 解包
rem 每次用一个全新的随机工作目录。
rem 不能复用固定目录：上一次残留的 ps1 会导致 certutil 拒绝覆盖，
rem 而 "if not exist" 检查又能通过（旧文件在），于是静默跑旧代码 —— 表现为
rem 「明明改了程序，双击还是报同一个错」。
set "WORKDIR=%TEMP%\OneKeyInstall_%RANDOM%%RANDOM%"
mkdir "%WORKDIR%" >nul 2>&1
if not exist "%WORKDIR%" (
    echo.
    echo   [错误] 无法创建临时目录，请检查 %%TEMP%% 是否可写。
    echo.
    pause
    exit /b 1
)

set "B64FILE=%WORKDIR%\payload.b64"
set "RAW=%WORKDIR%\payload.dat"
set "PS1FILE=%WORKDIR%\注入网卡驱动-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oDQogICAgW3N0cmluZ10kT3JpZ2luRGlyID0gJycNCikNCg0KIyA9PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMg5rOo
>> "%B64FILE%" echo 5YWl572R5Y2h6amx5YqoICB2MS4yDQojIOS9nOiAhTogY29ubmVjdHNlZ2Fib3QNCiMNCiMg55So
>> "%B64FILE%" echo 6YCU77ya5bey57uP6KOF5aW955qE6Jma5ouf57O757uf6L+b5LiN5Y67572R77yI6K6+5aSH566h
>> "%B64FILE%" echo 55CG5Zmo6YeM572R5Y2h5bim5oSf5Y+55Y+3IC8g572R57uc5Zu+5qCH5omT57qi5Y+J77yJ77yM
>> "%B64FILE%" echo DQojICAg55So5a6D5oqK44CM5b2T5YmN6L+Z5Y+w5py65Zmo5q2j5Zyo55So55qE572R5Y2h6amx
>> "%B64FILE%" echo 5Yqo44CN5rOo5YWl5Yiw6YKj5Liq57O757uf6YeM44CCDQojDQojIOmpseWKqOaYr+S7juacrOac
>> "%B64FILE%" echo uueOsOWPlueahO+8jOehrOS7tiBJRCDlv4XnhLbljLnphY3vvIzms6jlhaXlrozogZTnvZHljbPp
>> "%B64FILE%" echo gJrjgIINCiMg5Y+q5Yqo55uu5qCH57O757uf55qE6amx5Yqo5bqT77yIRHJpdmVyU3RvcmXvvInv
>> "%B64FILE%" echo vIzkuI3norDns7vnu5/mlofku7blkozlvJXlr7zjgIINCiMNCiMgdjEuMSDkv67mraPvvIgyMDI2
>> "%B64FILE%" echo LTExLTA077yJ77yaDQojICAgdjEuMCDnmoTnm67moIfor4bliKvmnInoh7Tlkb3nvLrpmbcg4oCU
>> "%B64FILE%" echo 4oCUIOWug+WPquaJvuOAjOW4piBudG9za3JubC5leGUg55qE5Y2344CN77yMDQojICAg6ICM5q2j
>> "%B64FILE%" echo 5Zyo6L+Q6KGM55qEIEM6IOacrOi6q+WwseW4puWGheaguO+8jOiZmuaLn+ejgeebmOayoeaMgui9
>> "%B64FILE%" echo veaXtiBDOiDmmK/llK/kuIDlgJnpgInvvIwNCiMgICDkuo7mmK/ohJrmnKzkuIDot6/lvoAgQzog
>> "%B64FILE%" echo 6YeM5rOo5YWl77yMRElTTSDnm7TmjqXmiqXvvJoNCiMgICAgICAgRXJyb3I6IDg3ICBUaGUgL0lt
>> "%B64FILE%" echo YWdlIG9wdGlvbiB0aGF0IGlzIHNwZWNpZmllZCBwb2ludHMgdG8gYQ0KIyAgICAgICBydW5uaW5n
>> "%B64FILE%" echo IFdpbmRvd3MgaW5zdGFsbGF0aW9uLg0KIyAgIO+8iERJU00g5ouS57ud5omn6KGM77yM5omA5Lul
>> "%B64FILE%" echo 5LuA5LmI6YO95rKh5YaZ6L+b5Y6777yM5Y6f57O757uf5rKh5pyJ6KKr5pS55Yqo44CC77yJDQoj
>> "%B64FILE%" echo ICAgdjEuMSDotbfvvJrmjpLpmaTlvZPliY3ov5DooYznmoTns7vnu5/nm5jjgIHkvJjlhYjorqTo
>> "%B64FILE%" echo mZrmi5/no4Hnm5jjgIHmsqHmjILovb3lsLHoh6rliqjmjILovb3jgIINCiMNCiMgdjEuMiDkv67m
>> "%B64FILE%" echo raPvvIgyMDI2LTExLTA177yJ77yaDQojICAgdjEuMSDlj6rlr7zlh7ogcG5wdXRpbCAvZW51bS1k
>> "%B64FILE%" echo cml2ZXJzIOmHjOeahOesrOS4ieaWuSBvZW0qLmluZuOAgueJqeeQhuacuue9keWNoeWkmuWNiueU
>> "%B64FILE%" echo qA0KIyAgIOezu+e7n+WGhee9ru+8iGluLWJveO+8iempseWKqOWMhe+8jOagueacrOS4jeWcqCBv
>> "%B64FILE%" echo ZW0g5YiX6KGo6YeMIOKGkiDkuIDkuKrpg73lr7zkuI3lh7rmnaXvvIzms6jlhaUNCiMgICDnjq/o
>> "%B64FILE%" echo ioLnm7TmjqXliKTjgIzmsqHmnInlj6/lr7zlh7rnmoTnvZHljaHpqbHliqjjgI3pgIDlh7rvvIzn
>> "%B64FILE%" echo nIvnjrDosaHlsLHmmK/jgIzov5nkuKrlt6XlhbfmsqHmlYjmnpzjgI3jgIINCiMgICDvvIjku6Xl
>> "%B64FILE%" echo iY3lnKjomZrmi5/mnLrph4zor5XmgLvmmK/lpb3nmoTvvIzlm6DkuLrpgqPph4znmoTomZrmi5/n
>> "%B64FILE%" echo vZHljaHpqbHliqjmgbDlpb3mmK8gb2VtIOWMheOAgu+8iQ0KIyAgIHYxLjIg6LW377ya6aKd5aSW
>> "%B64FILE%" echo 5p6a5Li+55yf5a6e5a2Y5Zyo55qEIFBDSS9VU0Ig54mp55CG572R5Y2h77yM5Y+W5YW25q2j5Zyo
>> "%B64FILE%" echo 5L2/55So55qEIElORu+8jA0KIyAgIOWGhee9ruWMheS7jiBEcml2ZXJTdG9yZVxGaWxlUmVwb3Np
>> "%B64FILE%" echo dG9yeSDmlbTljIXlpI3liLblkI7kuIDotbfms6jlhaXjgIINCiMgPT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQoNCiRFcnJvckFjdGlv
>> "%B64FILE%" echo blByZWZlcmVuY2UgPSAnQ29udGludWUnDQokU2NyaXB0OlZlcnNpb24gPSAnMS4zNCcNCiRTY3Jp
>> "%B64FILE%" echo cHQ6T3JpZ2luRGlyID0gJE9yaWdpbkRpcg0KdHJ5IHsgJEhvc3QuVUkuUmF3VUkuV2luZG93VGl0
>> "%B64FILE%" echo bGUgPSAi5rOo5YWl572R5Y2h6amx5YqoIHYkKCRTY3JpcHQ6VmVyc2lvbikgLSBjb25uZWN0c2Vn
>> "%B64FILE%" echo YWJvdCIgfSBjYXRjaCB7fQ0KDQojIFt2MS4zMl0g5YWx5Lqr5qih5Z2X44CC5omT5YyF5pe255Sx
>> "%B64FILE%" echo IHNyYy9idWlsZC9pbmxpbmVfc2hhcmVkLnB5IOWGheiBlOacrOaWh+S7tu+8jA0KIyAuYmF0IOi9
>> "%B64FILE%" echo veiNt+S7jeaYr+iHquWMheWQq+WNleaWh+S7tuOAgg0KIyA9PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMg5YWx5Lqr5pel5b+X5Ye9
>> "%B64FILE%" echo 5pWwICAgdjEuMzINCiMNCiMg5pys5paH5Lu25LiN5piv5Y+R5biD54mp44CC5omT5YyFIC5iYXQg
>> "%B64FILE%" echo 6L296I235pe277yMc3JjL2J1aWxkL2lubGluZV9zaGFyZWQucHkg5Lya5oqK6L+Z6YeM55qEDQoj
>> "%B64FILE%" echo IOWGheWuueWGheiBlOi/m+avj+S4quWFpeWPo+iEmuacrO+8jOS/neivgeWPkeW4g+WHuuWOu+ea
>> "%B64FILE%" echo hOWQr+WKqOWZqOS7jeaYr+iHquWMheWQq+WNleaWh+S7tg0KIyDvvIjoh6rop6PljosgYmF0IOWc
>> "%B64FILE%" echo qOi/kOihjOacn+ayoeWKnuazleW8leeUqOWklumDqOaooeWdl++8ieOAgg0KIw0KIyDop4Tnn6nv
>> "%B64FILE%" echo vJrlj6rmlLnov5nph4zvvIzkuI3opoHlho3miorov5nkupvlh73mlbDlpI3liLblm57lhaXlj6Po
>> "%B64FILE%" echo hJrmnKzjgIINCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09DQoNCmZ1bmN0aW9uIFNheSB7DQogICAgcGFyYW0oW3N0cmluZ10kVGV4
>> "%B64FILE%" echo dCwgW3N0cmluZ10kQ29sb3IgPSAnR3JheScpDQogICAgV3JpdGUtSG9zdCAkVGV4dCAtRm9yZWdy
>> "%B64FILE%" echo b3VuZENvbG9yICRDb2xvcg0KfQ0KDQpTYXkgIiINClNheSAiICDms6jlhaXnvZHljaHpqbHliqgg
>> "%B64FILE%" echo IHYkKCRTY3JpcHQ6VmVyc2lvbikiICdDeWFuJw0KU2F5ICIgIOS9nOiAhTogY29ubmVjdHNlZ2Fi
>> "%B64FILE%" echo b3QiICdEYXJrR3JheScNClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNClNheSAiIg0KDQokYWRtaW4g
>> "%B64FILE%" echo PSAoW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzUHJpbmNpcGFsXVtTZWN1cml0eS5QcmluY2lw
>> "%B64FILE%" echo YWwuV2luZG93c0lkZW50aXR5XTo6R2V0Q3VycmVudCgpKS5Jc0luUm9sZShbU2VjdXJpdHkuUHJp
>> "%B64FILE%" echo bmNpcGFsLldpbmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpDQppZiAoLW5vdCAkYWRt
>> "%B64FILE%" echo aW4pIHsNCiAgICBTYXkgIiAgW+mUmeivr10g6ZyA6KaB566h55CG5ZGY5p2D6ZmQ44CC6K+35YWz
>> "%B64FILE%" echo 5o6J5pys56qX5Y+j77yM5Y+z6ZSu5pys5paH5Lu2IC0+IOS7peeuoeeQhuWRmOi6q+S7vei/kOih
>> "%B64FILE%" echo jOOAgiIgJ1JlZCcNCiAgICBTYXkgIiINCiAgICBSZWFkLUhvc3QgIiAg5oyJ5Zue6L2m6YCA5Ye6
>> "%B64FILE%" echo Ig0KICAgIGV4aXQgMQ0KfQ0KDQojIC0tLS0tLS0tLS0g6K+G5Yir44CM5b2T5YmN5q2j5Zyo6L+Q
>> "%B64FILE%" echo 6KGM55qE57O757uf44CN77yM5b+F6aG75o6S6ZmkIC0tLS0tLS0tLS0NCiRzeXNMZXR0ZXIgPSAo
>> "%B64FILE%" echo W3N0cmluZ10kZW52OlN5c3RlbURyaXZlKS5UcmltRW5kKCc6JykuVG9VcHBlcigpDQokc3lzVm9s
>> "%B64FILE%" echo SWQgPSAnJw0KdHJ5IHsgJHN5c1ZvbElkID0gW3N0cmluZ10oR2V0LVZvbHVtZSAtRHJpdmVMZXR0
>> "%B64FILE%" echo ZXIgJHN5c0xldHRlciAtRXJyb3JBY3Rpb24gU3RvcCkuVW5pcXVlSWQgfSBjYXRjaCB7fQ0KDQpm
>> "%B64FILE%" echo dW5jdGlvbiBUZXN0LUlzUnVubmluZ1N5c3RlbSB7DQogICAgcGFyYW0oJFZvbCkNCiAgICBpZiAo
>> "%B64FILE%" echo KFtzdHJpbmddJFZvbC5Ecml2ZUxldHRlcikuVG9VcHBlcigpIC1lcSAkc3lzTGV0dGVyKSB7IHJl
>> "%B64FILE%" echo dHVybiAkdHJ1ZSB9DQogICAgIyDlkIzkuIDkuKrljbfooqvmjILliLDlj6bkuIDkuKrnm5jnrKbm
>> "%B64FILE%" echo l7YgVW5pcXVlSWQg55u45ZCM77yM5Lmf6KaB5o6S6Zmk77yMDQogICAgIyDlkKbliJkgRElTTSDl
>> "%B64FILE%" echo kIzmoLfmiqUgRXJyb3IgODfjgIINCiAgICBpZiAoJHN5c1ZvbElkIC1hbmQgKFtzdHJpbmddJFZv
>> "%B64FILE%" echo bC5VbmlxdWVJZCAtZXEgJHN5c1ZvbElkKSkgeyByZXR1cm4gJHRydWUgfQ0KICAgIHJldHVybiAk
>> "%B64FILE%" echo ZmFsc2UNCn0NCg0KIyAtLS0tLS0tLS0tIOWAmemAieWNtyAtLS0tLS0tLS0tDQpmdW5jdGlvbiBH
>> "%B64FILE%" echo ZXQtVGFyZ2V0Q2FuZGlkYXRlcyB7DQogICAgJGxpc3QgPSBAKCkNCg0KICAgICR2aGREaXNrcyA9
>> "%B64FILE%" echo IEB7fQ0KICAgIGZvcmVhY2ggKCRkIGluIEAoR2V0LURpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpKSB7DQogICAgICAgIGlmIChbc3RyaW5nXSRkLkJ1c1R5cGUgLWVxICdGaWxlIEJh
>> "%B64FILE%" echo Y2tlZCBWaXJ0dWFsJykgeyAkdmhkRGlza3NbW2ludF0kZC5OdW1iZXJdID0gJHRydWUgfQ0KICAg
>> "%B64FILE%" echo IH0NCg0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24gU2lsZW50
>> "%B64FILE%" echo bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsgY29udGlu
>> "%B64FILE%" echo dWUgfQ0KICAgICAgICAkcm9vdCA9ICJ7MH06XCIgLWYgJHYuRHJpdmVMZXR0ZXINCiAgICAgICAg
>> "%B64FILE%" echo aWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggKCRyb290ICsgJ1dpbmRvd3NcU3lzdGVt
>> "%B64FILE%" echo MzJcbnRvc2tybmwuZXhlJykpKSB7IGNvbnRpbnVlIH0NCg0KICAgICAgICAkZGlza051bSA9IC0x
>> "%B64FILE%" echo DQogICAgICAgIHRyeSB7ICRkaXNrTnVtID0gW2ludF0oR2V0LVBhcnRpdGlvbiAtRHJpdmVMZXR0
>> "%B64FILE%" echo ZXIgJHYuRHJpdmVMZXR0ZXIgLUVycm9yQWN0aW9uIFN0b3ApLkRpc2tOdW1iZXIgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KDQogICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1Aew0KICAgICAgICAgICAgTGV0
>> "%B64FILE%" echo dGVyICA9IFtzdHJpbmddJHYuRHJpdmVMZXR0ZXINCiAgICAgICAgICAgIExhYmVsICAgPSBbc3Ry
>> "%B64FILE%" echo aW5nXSR2LkZpbGVTeXN0ZW1MYWJlbA0KICAgICAgICAgICAgUnVubmluZyA9IChUZXN0LUlzUnVu
>> "%B64FILE%" echo bmluZ1N5c3RlbSAkdikNCiAgICAgICAgICAgIElzVmhkICAgPSAoJGRpc2tOdW0gLWdlIDAgLWFu
>> "%B64FILE%" echo ZCAkdmhkRGlza3MuQ29udGFpbnNLZXkoJGRpc2tOdW0pKQ0KICAgICAgICAgICAgRGlzayAgICA9
>> "%B64FILE%" echo ICRkaXNrTnVtDQogICAgICAgICAgICBTaXplR0IgID0gW21hdGhdOjpSb3VuZCgkdi5TaXplIC8g
>> "%B64FILE%" echo MUdCLCAxKQ0KICAgICAgICB9DQogICAgfQ0KICAgIHJldHVybiAkbGlzdA0KfQ0KDQojIC0tLS0t
>> "%B64FILE%" echo LS0tLS0g5om+5Y+v5oyC6L2955qEIHZoZHggLS0tLS0tLS0tLQ0KZnVuY3Rpb24gRmluZC1WaGR4
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
>> "%B64FILE%" echo TVAgKCJhdHRhY2hfdmhkX3swfS50eHQiIC1mICRQSUQpDQogICAgQCgNCiAgICAgICAgInNlbGVj
>> "%B64FILE%" echo dCB2ZGlzayBmaWxlPWAiJFBhdGhgIiIsDQogICAgICAgICdhdHRhY2ggdmRpc2snLA0KICAgICAg
>> "%B64FILE%" echo ICAnZXhpdCcNCiAgICApIHwgU2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRkcEZpbGUgLUVuY29k
>> "%B64FILE%" echo aW5nIERlZmF1bHQNCiAgICAkciA9ICcnDQogICAgdHJ5IHsgJHIgPSAoJiBkaXNrcGFydCAvcyAk
>> "%B64FILE%" echo ZHBGaWxlIDI+JjEgfCBPdXQtU3RyaW5nKSB9IGNhdGNoIHsgJHIgPSAkXy5FeGNlcHRpb24uTWVz
>> "%B64FILE%" echo c2FnZSB9DQogICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUgLUZvcmNlIC1FcnJv
>> "%B64FILE%" echo ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQogICAgaWYgKCRyIC1tYXRjaCAnc3VjY2Vzc2Z1bGx5
>> "%B64FILE%" echo fOaIkOWKnycpIHsgcmV0dXJuICR0cnVlIH0NCiAgICBTYXkgKCIgICAgICDmjILovb3ov5Tlm546
>> "%B64FILE%" echo ICIgKyAoKCRyIC1yZXBsYWNlICJccysiLCAnICcpLlRyaW0oKSkpICdZZWxsb3cnDQogICAgcmV0
>> "%B64FILE%" echo dXJuICRmYWxzZQ0KfQ0KDQpmdW5jdGlvbiBEaXNtb3VudC1WaGR4IHsNCiAgICBwYXJhbShbc3Ry
>> "%B64FILE%" echo aW5nXSRQYXRoKQ0KICAgICRkcEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICgiZGV0YWNoX3Zo
>> "%B64FILE%" echo ZF97MH0udHh0IiAtZiAkUElEKQ0KICAgIEAoDQogICAgICAgICJzZWxlY3QgdmRpc2sgZmlsZT1g
>> "%B64FILE%" echo IiRQYXRoYCIiLA0KICAgICAgICAnZGV0YWNoIHZkaXNrJywNCiAgICAgICAgJ2V4aXQnDQogICAg
>> "%B64FILE%" echo KSB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0DQog
>> "%B64FILE%" echo ICAgdHJ5IHsgJiBkaXNrcGFydCAvcyAkZHBGaWxlIDI+JjEgfCBPdXQtTnVsbCB9IGNhdGNoIHt9
>> "%B64FILE%" echo DQogICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUgLUZvcmNlIC1FcnJvckFjdGlv
>> "%B64FILE%" echo biBTaWxlbnRseUNvbnRpbnVlDQp9DQoNCiMgLS0tLS0tLS0tLSBbMS80XSDlrprkvY3nm67moIfn
>> "%B64FILE%" echo s7vnu58gLS0tLS0tLS0tLQ0KU2F5ICJbMS80XSDlrprkvY3nm67moIfns7vnu58gLi4uIiAnV2hp
>> "%B64FILE%" echo dGUnDQoNCiRhdHRhY2hlZFZoZHggPSAnJw0KJHRhcmdldHMgPSBAKEdldC1UYXJnZXRDYW5kaWRh
>> "%B64FILE%" echo dGVzKQ0KJHVzYWJsZSA9IEAoJHRhcmdldHMgfCBXaGVyZS1PYmplY3QgeyAtbm90ICRfLlJ1bm5p
>> "%B64FILE%" echo bmcgfSkNCg0KIyDkvJjlhYjnlKjomZrmi5/no4Hnm5jph4znmoTns7vnu5/vvIjmnKzlt6Xlhbfn
>> "%B64FILE%" echo moTmnKzogYzlnLrmma/vvIkNCiR2aGRUYXJnZXRzID0gQCgkdXNhYmxlIHwgV2hlcmUtT2JqZWN0
>> "%B64FILE%" echo IHsgJF8uSXNWaGQgfSkNCg0KaWYgKCR2aGRUYXJnZXRzLkNvdW50IC1lcSAwKSB7DQogICAgJHZo
>> "%B64FILE%" echo ZHhGaWxlcyA9IEAoRmluZC1WaGR4RmlsZXMpDQogICAgaWYgKCR2aGR4RmlsZXMuQ291bnQgLWd0
>> "%B64FILE%" echo IDApIHsNCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJHZoZHhGaWxlcykgew0KICAgICAgICAgICAg
>> "%B64FILE%" echo U2F5ICgiICAgICAg5Y+R546w6Jma5ouf56OB55uYIHswfe+8jOato+WcqOaMgui9vSAuLi4iIC1m
>> "%B64FILE%" echo ICRmKSAnRGFya0dyYXknDQogICAgICAgICAgICBpZiAoTW91bnQtVmhkeCAtUGF0aCAkZikgew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICRhdHRhY2hlZFZoZHggPSAkZg0KICAgICAgICAgICAgICAgIFNheSAi
>> "%B64FILE%" echo ICAgICAg5bey5oyC6L29IiAnR3JlZW4nDQogICAgICAgICAgICAgICAgYnJlYWsNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIH0NCiAgICAgICAgfQ0KICAgICAgICBpZiAoJGF0dGFjaGVkVmhkeCkgew0KICAgICAgICAg
>> "%B64FILE%" echo ICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgMg0KICAgICAgICAgICAgJHRhcmdldHMgPSBAKEdldC1U
>> "%B64FILE%" echo YXJnZXRDYW5kaWRhdGVzKQ0KICAgICAgICAgICAgJHVzYWJsZSA9IEAoJHRhcmdldHMgfCBXaGVy
>> "%B64FILE%" echo ZS1PYmplY3QgeyAtbm90ICRfLlJ1bm5pbmcgfSkNCiAgICAgICAgICAgICR2aGRUYXJnZXRzID0g
>> "%B64FILE%" echo QCgkdXNhYmxlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSXNWaGQgfSkNCiAgICAgICAgfQ0KICAgIH0N
>> "%B64FILE%" echo Cn0NCg0KaWYgKCR2aGRUYXJnZXRzLkNvdW50IC1lcSAxKSB7DQogICAgJHRhcmdldCA9ICR2aGRU
>> "%B64FILE%" echo YXJnZXRzWzBdDQogICAgU2F5ICgiICAgICAg55uu5qCH77yaezB9OiAg77yI6Jma5ouf56OB55uY
>> "%B64FILE%" echo 6YeM55qE57O757uf77yMezF9IEdC77yJIiAtZiAkdGFyZ2V0LkxldHRlciwgJHRhcmdldC5TaXpl
>> "%B64FILE%" echo R0IpICdHcmVlbicNCn0NCmVsc2VpZiAoJHVzYWJsZS5Db3VudCAtZXEgMCkgew0KICAgIFNheSAi
>> "%B64FILE%" echo Ig0KICAgIFNheSAiICBb6ZSZ6K+vXSDmsqHmib7liLDlj6/ms6jlhaXnmoTns7vnu5/jgIIiICdS
>> "%B64FILE%" echo ZWQnDQogICAgU2F5ICgiICAgICAgICAg5b2T5YmN5q2j5Zyo6L+Q6KGM55qE5pivIHswfTrvvIzl
>> "%B64FILE%" echo roPkuI3og73kvZzkuLrnm67moIfvvIhESVNNIOS4jeWFgeiuuO+8ieOAgiIgLWYgJHN5c0xldHRl
>> "%B64FILE%" echo cikgJ1llbGxvdycNCiAgICBTYXkgIiAgICAgICAgIOS5n+ayoeacieaJvuWIsOW3suaMgui9veaI
>> "%B64FILE%" echo luWPr+aMgui9veeahCBOZXdTeXN0ZW1EaXNrLnZoZHjjgIIiICdZZWxsb3cnDQogICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICAgICDor7fnoa7orqTomZrmi5/ns7vnu5/oo4XlnKjlk6rkuKogdmhkeCDmlofku7bph4zj
>> "%B64FILE%" echo gIHmlofku7blkI3mmK/lkKblj6sgTmV3U3lzdGVtRGlzay52aGR444CCIiAnWWVsbG93Jw0KICAg
>> "%B64FILE%" echo IFNheSAiIg0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERpc21vdW50LVZoZHggLVBhdGggJGF0
>> "%B64FILE%" echo dGFjaGVkVmhkeCB9DQogICAgUmVhZC1Ib3N0ICIgIOaMieWbnui9pumAgOWHuiINCiAgICBleGl0
>> "%B64FILE%" echo IDENCn0NCmVsc2Ugew0KICAgIFNheSAiICAgICAg5om+5Yiw5aSa5Liq5Y+v5rOo5YWl55qE57O7
>> "%B64FILE%" echo 57uf77yM6K+36YCJ5oup77yaIiAnV2hpdGUnDQogICAgZm9yICgkaSA9IDA7ICRpIC1sdCAkdXNh
>> "%B64FILE%" echo YmxlLkNvdW50OyAkaSsrKSB7DQogICAgICAgICR0ID0gJHVzYWJsZVskaV0NCiAgICAgICAgJGtp
>> "%B64FILE%" echo bmQgPSBpZiAoJHQuSXNWaGQpIHsgJ+iZmuaLn+ejgeebmCcgfSBlbHNlIHsgJ+eJqeeQhuWIhuWM
>> "%B64FILE%" echo uicgfQ0KICAgICAgICBTYXkgKCIgICAgICBbezB9XSB7MX06ICB7Mn0gIHszfSBHQiAg5Y235qCH
>> "%B64FILE%" echo PXs0fSIgLWYgKCRpICsgMSksICR0LkxldHRlciwgJGtpbmQsICR0LlNpemVHQiwgJHQuTGFiZWwp
>> "%B64FILE%" echo DQogICAgfQ0KICAgICRzZWwgPSBSZWFkLUhvc3QgIiAgICAgIOi+k+WFpeW6j+WPt++8iOm7mOiu
>> "%B64FILE%" echo pCAx77yJIg0KICAgICRpZHggPSAxDQogICAgW2ludF06OlRyeVBhcnNlKCRzZWwsIFtyZWZdJGlk
>> "%B64FILE%" echo eCkgfCBPdXQtTnVsbA0KICAgIGlmICgkaWR4IC1sdCAxIC1vciAkaWR4IC1ndCAkdXNhYmxlLkNv
>> "%B64FILE%" echo dW50KSB7ICRpZHggPSAxIH0NCiAgICAkdGFyZ2V0ID0gJHVzYWJsZVskaWR4IC0gMV0NCiAgICBT
>> "%B64FILE%" echo YXkgKCIgICAgICDnm67moIfvvJp7MH06IiAtZiAkdGFyZ2V0LkxldHRlcikgJ0dyZWVuJw0KfQ0K
>> "%B64FILE%" echo DQojIOWPjOS/nemZqe+8mue7neS4jeW+gOi/kOihjOS4reeahOezu+e7n+WGmQ0KaWYgKCR0YXJn
>> "%B64FILE%" echo ZXQuUnVubmluZykgew0KICAgIFNheSAiIg0KICAgIFNheSAiICBb6ZSZ6K+vXSDpgInkuK3nmoTm
>> "%B64FILE%" echo mK/lvZPliY3mraPlnKjov5DooYznmoTns7vnu5/vvIxESVNNIOS4jeWFgeiuuO+8iEVycm9yIDg3
>> "%B64FILE%" echo 77yJ44CC5bey5Lit5q2i44CCIiAnUmVkJw0KICAgIFNheSAiIg0KICAgIGlmICgkYXR0YWNoZWRW
>> "%B64FILE%" echo aGR4KSB7IERpc21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhkeCB9DQogICAgUmVhZC1Ib3N0
>> "%B64FILE%" echo ICIgIOaMieWbnui9pumAgOWHuiINCiAgICBleGl0IDENCn0NCg0KIyAtLS0tLS0tLS0tIFsyLzRd
>> "%B64FILE%" echo IOWvvOWHuuacrOacuue9keWNoempseWKqCAtLS0tLS0tLS0tDQpTYXkgIlsyLzRdIOS7juacrOac
>> "%B64FILE%" echo uuWvvOWHuue9keWNoempseWKqCAuLi4iICdXaGl0ZScNCiRuZXRDbGFzc0d1aWQgPSAnNGQzNmU5
>> "%B64FILE%" echo NzItZTMyNS0xMWNlLWJmYzEtMDgwMDJiZTEwMzE4JyAgICMg572R57uc6YCC6YWN5Zmo77yI5LiO
>> "%B64FILE%" echo 6K+t6KiA5peg5YWz77yJDQokZHJ2RGlyID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImluamVjdG5l
>> "%B64FILE%" echo dF97MH0iIC1mICRQSUQpDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZHJ2RGly
>> "%B64FILE%" echo KSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30NCk5ldy1JdGVtIC1JdGVtVHlw
>> "%B64FILE%" echo ZSBEaXJlY3RvcnkgLVBhdGggJGRydkRpciAtRm9yY2UgfCBPdXQtTnVsbA0KDQokZW51bVRleHQg
>> "%B64FILE%" echo PSAnJw0KdHJ5IHsgJGVudW1UZXh0ID0gKCYgcG5wdXRpbCAvZW51bS1kcml2ZXJzIDI+JjEgfCBP
>> "%B64FILE%" echo dXQtU3RyaW5nKSB9IGNhdGNoIHt9DQokbmV0T2VtcyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxl
>> "%B64FILE%" echo Y3Rpb25zLkFycmF5TGlzdA0KZm9yZWFjaCAoJGJsayBpbiAoJGVudW1UZXh0IC1zcGxpdCAiKD86
>> "%B64FILE%" echo XHI/XG4pezIsfSIpKSB7DQogICAgaWYgKCRibGsgLW5vdG1hdGNoICRuZXRDbGFzc0d1aWQpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICRtID0gW3JlZ2V4XTo6TWF0Y2goJGJsaywgJyg/aSlcYihvZW1cZCtc
>> "%B64FILE%" echo LmluZilcYicpDQogICAgaWYgKC1ub3QgJG0uU3VjY2VzcykgeyBjb250aW51ZSB9DQogICAgJG5t
>> "%B64FILE%" echo ID0gJG0uR3JvdXBzWzFdLlZhbHVlLlRvTG93ZXIoKQ0KICAgIGlmICgtbm90ICRuZXRPZW1zLkNv
>> "%B64FILE%" echo bnRhaW5zKCRubSkpIHsgW3ZvaWRdJG5ldE9lbXMuQWRkKCRubSkgfQ0KfQ0KU2F5ICgiICAgICAg
>> "%B64FILE%" echo 5pys5py656ys5LiJ5pa5572R57uc6amx5Yqo5YyFOiB7MH0g5LiqIiAtZiAkbmV0T2Vtcy5Db3Vu
>> "%B64FILE%" echo dCkgJ0RhcmtHcmF5Jw0KZm9yZWFjaCAoJG9lbSBpbiAkbmV0T2Vtcykgew0KICAgICRlciA9ICgm
>> "%B64FILE%" echo IHBucHV0aWwgL2V4cG9ydC1kcml2ZXIgJG9lbSAkZHJ2RGlyIDI+JjEgfCBPdXQtU3RyaW5nKQ0K
>> "%B64FILE%" echo ICAgIGlmICgkZXIgLW1hdGNoICdzdWNjZXNzZnVsbHl85oiQ5YqfJykgeyBTYXkgKCIgICAgICBb
>> "%B64FILE%" echo b2tdIHswfSIgLWYgJG9lbSkgJ0RhcmtHcmF5JyB9DQogICAgZWxzZSB7IFNheSAoIiAgICAgIFsh
>> "%B64FILE%" echo IV0gezB9ICB7MX0iIC1mICRvZW0sICgoJGVyIC1yZXBsYWNlICJccysiLCAnICcpLlRyaW0oKSkp
>> "%B64FILE%" echo ICdZZWxsb3cnIH0NCn0NCg0KIyDjgJB2MS4y44CRcG5wdXRpbCAvZW51bS1kcml2ZXJzIOWPquWI
>> "%B64FILE%" echo l+esrOS4ieaWuSBvZW0qLmluZu+8jOS8mua8j+aOieWGhee9ru+8iGluLWJveO+8iee9keWNoQ0K
>> "%B64FILE%" echo IyDpqbHliqjvvJrniannkIbmnLrnvZHljaHluLjnlKjns7vnu5/oh6rluKbljIXvvIjkuI3lnKgg
>> "%B64FILE%" echo b2VtIOWIl+ihqOmHjO+8ie+8jOS4iumdouS4gOS4qumDveWvvOS4jeWHuu+8jOS6juaYrw0KIyDn
>> "%B64FILE%" echo m67moIfns7vnu5/nhafmoLfmsqHnvZHigJTigJTnnIvotbfmnaXlsLHmmK/jgIzov5nkuKrlt6Xl
>> "%B64FILE%" echo hbfmsqHmlYjmnpzjgI3jgILov5nph4zmiorjgIzlvZPliY3nnJ/lrp7lrZjlnKjnmoQNCiMg54mp
>> "%B64FILE%" echo 55CG572R5Y2h44CN5q2j5Zyo55So55qEIElORiDooaXlr7zlh7rvvJrnrKzkuInmlrkgb2VtIOW3
>> "%B64FILE%" echo suWvvOi/h++8iOi3s+i/h++8ie+8jGluLWJveCDnmoTku44NCiMgRHJpdmVyU3RvcmVcRmlsZVJl
>> "%B64FILE%" echo cG9zaXRvcnkg5pW05YyF5aSN5Yi244CCDQpTYXkgIiAgICAgIOihpeWvvOWHuueJqeeQhue9keWN
>> "%B64FILE%" echo oeato+WcqOS9v+eUqOeahOmpseWKqO+8iOWQq+ezu+e7n+WGhee9ru+8iS4uLiIgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KdHJ5IHsNCiAgICAkcGh5c05ldHMgPSBAKEdldC1QbnBEZXZpY2UgLUNsYXNzIE5ldCAtUHJl
>> "%B64FILE%" echo c2VudE9ubHkgLUVBIFNpbGVudGx5Q29udGludWUgfA0KICAgICAgICBXaGVyZS1PYmplY3QgeyAk
>> "%B64FILE%" echo Xy5JbnN0YW5jZUlkIC1tYXRjaCAnXihQQ0l8VVNCKScgfSkNCiAgICBmb3JlYWNoICgkZGV2IGlu
>> "%B64FILE%" echo ICRwaHlzTmV0cykgew0KICAgICAgICB0cnkgew0KICAgICAgICAgICAgJGRydkluZiA9ICcnDQog
>> "%B64FILE%" echo ICAgICAgICAgICB0cnkgeyAkZHJ2SW5mID0gW3N0cmluZ10oR2V0LVBucERldmljZVByb3BlcnR5
>> "%B64FILE%" echo IC1JbnN0YW5jZUlkICRkZXYuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZpY2VfRHJp
>> "%B64FILE%" echo dmVySW5mUGF0aCcgLUVBIFN0b3ApLkRhdGEgfSBjYXRjaCB7fQ0KICAgICAgICAgICAgaWYgKC1u
>> "%B64FILE%" echo b3QgJGRydkluZikgeyBjb250aW51ZSB9DQogICAgICAgICAgICAkZHJ2SW5mID0gJGRydkluZi5U
>> "%B64FILE%" echo b0xvd2VyKCkNCiAgICAgICAgICAgIFNheSAoIiAgICAgIOe9keWNoSB7MH0g5q2j5Zyo5L2/55So
>> "%B64FILE%" echo IHsxfSIgLWYgJGRldi5GcmllbmRseU5hbWUsICRkcnZJbmYpICdEYXJrR3JheScNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIGlmICgkZHJ2SW5mIC1tYXRjaCAnXm9lbVxkK1wuaW5mJCcpIHsgY29udGludWUgfQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgIyBGaWxlUmVwb3NpdG9yeSDnmoTljIXnm67lvZXlkI3mmK8gPGluZuaWh+S7tuWQ
>> "%B64FILE%" echo jT5fPOaetuaehD5fPOWTiOW4jD7vvIzkvovlpoINCiAgICAgICAgICAgICMgcnQ2NDB4NjQuaW5m
>> "%B64FILE%" echo X2FtZDY0X2NiZjRlMjM5ODFjM2M4YTPjgILlv4XpobvnlKjluKYgLmluZiDnmoTlrozmlbTmlofk
>> "%B64FILE%" echo u7blkI3ljrvljLnphY3vvJsNCiAgICAgICAgICAgICMg5pep5YmN6K+v55So44CM5Y675o6J5omp
>> "%B64FILE%" echo 5bGV5ZCN44CN55qE5ZCN5a2X77yIcnQ2NDB4NjRfKu+8ie+8jOawuOi/nOWMuemFjeS4jeS4iu+8
>> "%B64FILE%" echo jOWGhee9rumpseWKqOS4gOS4qumDvQ0KICAgICAgICAgICAgIyDlpI3liLbkuI3lh7rmnaUg4oCU
>> "%B64FILE%" echo 4oCUIOihqOeOsOWwseaYr+OAjOazqOWFpeS6huS9hue9keWNoei/mOaYr+ayoempseWKqOOAjeOA
>> "%B64FILE%" echo gg0KICAgICAgICAgICAgJGZyUm9vdCA9ICIkZW52OlN5c3RlbVJvb3RcU3lzdGVtMzJcRHJpdmVy
>> "%B64FILE%" echo U3RvcmVcRmlsZVJlcG9zaXRvcnkiDQogICAgICAgICAgICAkcGtnRGlycyA9IEAoR2V0LUNoaWxk
>> "%B64FILE%" echo SXRlbSAkZnJSb290IC1EaXJlY3RvcnkgLUZpbHRlciAoJGRydkluZiArICdfKicpIC1FQSBTaWxl
>> "%B64FILE%" echo bnRseUNvbnRpbnVlKQ0KICAgICAgICAgICAgaWYgKCRwa2dEaXJzLkNvdW50IC1lcSAwKSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgJHBrZ0RpcnMgPSBAKEdldC1DaGlsZEl0ZW0gJGZyUm9vdCAtRGlyZWN0
>> "%B64FILE%" echo b3J5IC1FQSBTaWxlbnRseUNvbnRpbnVlIHwNCiAgICAgICAgICAgICAgICAgICAgV2hlcmUtT2Jq
>> "%B64FILE%" echo ZWN0IHsgJF8uTmFtZS5Ub0xvd2VyKCkuU3RhcnRzV2l0aCgkZHJ2SW5mICsgJ18nKSB9KQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgfQ0KICAgICAgICAgICAgaWYgKCRwa2dEaXJzLkNvdW50IC1lcSAwKSB7DQogICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgU2F5ICgiICDmnKrmib7liLAgezB9IOeahOmpseWKqOWMheebruW9le+8iOWP
>> "%B64FILE%" echo r+iDvempseWKqOWQjeS4juebruW9leWQjeS4jeS4gOiHtO+8iSIgLWYgJGRydkluZikgJ1llbGxv
>> "%B64FILE%" echo dycNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGZvcmVhY2ggKCRwZCBpbiAkcGtnRGlycykg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgICAgIENvcHktSXRlbSAtTGl0ZXJhbFBhdGggJHBkLkZ1bGxOYW1lIC1E
>> "%B64FILE%" echo ZXN0aW5hdGlvbiAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZQ0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgIFNheSAoIiAg5bey5aSN5Yi25YaF572u572R5Y2h6amx5Yqo5YyFOiAi
>> "%B64FILE%" echo ICsgJHBkLk5hbWUpICdEYXJrR3JheScNCiAgICAgICAgICAgIH0NCiAgICAgICAgfSBjYXRjaCB7
>> "%B64FILE%" echo IFNheSAoIiAgICAgIFshIV0g5YaF572u6amx5Yqo5a+85Ye65aSx6LSlOiB7MH0iIC1mICRfLkV4
>> "%B64FILE%" echo Y2VwdGlvbi5NZXNzYWdlKSAnWWVsbG93JyB9DQogICAgfQ0KfSBjYXRjaCB7IFNheSAoIiAgICAg
>> "%B64FILE%" echo IFshIV0g5YaF572u6amx5Yqo5a+85Ye65byC5bi4OiB7MH0iIC1mICRfLkV4Y2VwdGlvbi5NZXNz
>> "%B64FILE%" echo YWdlKSAnWWVsbG93JyB9DQoNCiRpbmZGaWxlcyA9IEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBh
>> "%B64FILE%" echo dGggJGRydkRpciAtUmVjdXJzZSAtRmlsdGVyICouaW5mIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
>> "%B64FILE%" echo bnRpbnVlKQ0KaWYgKCRpbmZGaWxlcy5Db3VudCAtZXEgMCkgew0KICAgIFNheSAiIg0KICAgIFNh
>> "%B64FILE%" echo eSAiICDmnKzmnLrmsqHmnInlj6/lr7zlh7rnmoTnvZHljaHpqbHliqjvvIjnrKzkuInmlrnlkozn
>> "%B64FILE%" echo s7vnu5/lhoXnva7pg73msqHmib7liLDvvInjgIIiICdZZWxsb3cnDQogICAgU2F5ICIgIOi/meen
>> "%B64FILE%" echo jeaDheWGtemAmuW4uOS4jeaYr+e8uumpseWKqO+8jOivt+WcqOebruagh+ezu+e7n+mHjOi3keOA
>> "%B64FILE%" echo jOaWsOezu+e7ny3or4rmlq3lubboo4XpqbHliqjjgI3nnIvlhbfkvZPmiqXplJnjgIIiICdZZWxs
>> "%B64FILE%" echo b3cnDQogICAgU2F5ICIiDQogICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcnZE
>> "%B64FILE%" echo aXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30NCiAgICBp
>> "%B64FILE%" echo ZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRhY2hlZFZoZHggfQ0K
>> "%B64FILE%" echo ICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhpdCAxDQp9DQokbWIgPSAw
>> "%B64FILE%" echo DQp0cnkgeyAkbWIgPSBbbWF0aF06OlJvdW5kKCgoR2V0LUNoaWxkSXRlbSAkZHJ2RGlyIC1SZWN1
>> "%B64FILE%" echo cnNlIC1GaWxlIHwgTWVhc3VyZS1PYmplY3QgTGVuZ3RoIC1TdW0pLlN1bSkgLyAxTUIsIDEpIH0g
>> "%B64FILE%" echo Y2F0Y2gge30NClNheSAoIiAgICAgIOWvvOWHuuWujOaIkO+8mnswfSDkuKogSU5G77yMezF9IE1C
>> "%B64FILE%" echo IiAtZiAkaW5mRmlsZXMuQ291bnQsICRtYikgJ0dyZWVuJw0KDQojIC0tLS0tLS0tLS0gWzMvNF0g
>> "%B64FILE%" echo 5rOo5YWlIC0tLS0tLS0tLS0NClNheSAiWzMvNF0g5rOo5YWl5Yiw55uu5qCH57O757uf77yI5Y+v
>> "%B64FILE%" echo 6IO96KaB5LiA5Lik5YiG6ZKf77yJLi4uIiAnV2hpdGUnDQokbG9nRmlsZSA9IEpvaW4tUGF0aCAk
>> "%B64FILE%" echo ZW52OlRFTVAgKCJpbmplY3RuZXRfezB9LmxvZyIgLWYgJFBJRCkNCiRlcnJGaWxlID0gJGxvZ0Zp
>> "%B64FILE%" echo bGUgKyAnLmVycicNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRsb2dGaWxlKSB7
>> "%B64FILE%" echo IFJlbW92ZS1JdGVtICRsb2dGaWxlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IH0gY2F0
>> "%B64FILE%" echo Y2gge30NCg0KIyAvSW1hZ2Ug5ZCO6Z2i5LiN5Yqg5byV5Y+377ya5YaZ5oiQICIvSW1hZ2U6RTpc
>> "%B64FILE%" echo IiDml7bnu5PlsL7nmoQgXCIg5Lya6KKr5b2T5oiQ6L2s5LmJ5byV5Y+377yMDQojIOWPguaVsOS8
>> "%B64FILE%" echo muWPmOaIkCBJbWFnZTpFOiIg6ICM5oql6ZSZ44CC55uY56ym6Lev5b6E5LiN5ZCr56m65qC877yM
>> "%B64FILE%" echo 5LiN5Yqg5byV5Y+35pyA56iz44CCDQokZGlzbUFyZ3MgPSAnL0VuZ2xpc2ggL0ltYWdlOnswfTpc
>> "%B64FILE%" echo IC9BZGQtRHJpdmVyIC9Ecml2ZXI6InsxfSIgL1JlY3Vyc2UnIC1mICR0YXJnZXQuTGV0dGVyLCAk
>> "%B64FILE%" echo ZHJ2RGlyDQpTYXkgKCIgICAgICBkaXNtIHswfSIgLWYgJGRpc21BcmdzKSAnRGFya0dyYXknDQoN
>> "%B64FILE%" echo CiRwcm9jID0gU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggJ2Rpc20uZXhlJyAtQXJndW1lbnRMaXN0
>> "%B64FILE%" echo ICRkaXNtQXJncyBgDQogICAgICAgICAgICAtUmVkaXJlY3RTdGFuZGFyZE91dHB1dCAkbG9nRmls
>> "%B64FILE%" echo ZSAtUmVkaXJlY3RTdGFuZGFyZEVycm9yICRlcnJGaWxlIGANCiAgICAgICAgICAgIC1Ob05ld1dp
>> "%B64FILE%" echo bmRvdyAtUGFzc1RocnUgLUVycm9yQWN0aW9uIFN0b3ANCg0KJHN3ID0gW1N5c3RlbS5EaWFnbm9z
>> "%B64FILE%" echo dGljcy5TdG9wd2F0Y2hdOjpTdGFydE5ldygpDQokbGFzdEJlYXQgPSAwDQp3aGlsZSAoLW5vdCAk
>> "%B64FILE%" echo cHJvYy5IYXNFeGl0ZWQpIHsNCiAgICBTdGFydC1TbGVlcCAtTWlsbGlzZWNvbmRzIDcwMA0KICAg
>> "%B64FILE%" echo IGlmICgoJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgLSAkbGFzdEJlYXQpIC1nZSAzMDAwKSB7DQog
>> "%B64FILE%" echo ICAgICAgICRsYXN0QmVhdCA9ICRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzDQogICAgICAgIFNheSAo
>> "%B64FILE%" echo IiAgICAgIOW3sueUqCB7MH0g56eSLi4uIiAtZiBbaW50XSRzdy5FbGFwc2VkLlRvdGFsU2Vjb25k
>> "%B64FILE%" echo cykgJ0RhcmtHcmF5Jw0KICAgIH0NCiAgICBpZiAoJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgLWd0
>> "%B64FILE%" echo IDkwMDAwMCkgew0KICAgICAgICB0cnkgeyBTdG9wLVByb2Nlc3MgLUlkICRwcm9jLklkIC1Gb3Jj
>> "%B64FILE%" echo ZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9DQogICAgICAgIFNheSAiICAgICAg6LaF
>> "%B64FILE%" echo 6L+HIDE1IOWIhumSn++8jOW3suaUvuW8gyIgJ1JlZCcNCiAgICAgICAgYnJlYWsNCiAgICB9DQp9
>> "%B64FILE%" echo DQp0cnkgeyAkcHJvYy5XYWl0Rm9yRXhpdCgpIH0gY2F0Y2gge30NCg0KIyAtLS0tLS0tLS0tIFs0
>> "%B64FILE%" echo LzRdIOe7k+aenCAtLS0tLS0tLS0tDQpTYXkgIiINCiR0eHQgPSAnJw0KdHJ5IHsgaWYgKFRlc3Qt
>> "%B64FILE%" echo UGF0aCAtTGl0ZXJhbFBhdGggJGxvZ0ZpbGUpIHsgJHR4dCA9IFtJTy5GaWxlXTo6UmVhZEFsbFRl
>> "%B64FILE%" echo eHQoJGxvZ0ZpbGUsIFtUZXh0LkVuY29kaW5nXTo6RGVmYXVsdCkgfSB9IGNhdGNoIHt9DQokZXJy
>> "%B64FILE%" echo VHh0ID0gJycNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRlcnJGaWxlKSB7ICRl
>> "%B64FILE%" echo cnJUeHQgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRlcnJGaWxlLCBbVGV4dC5FbmNvZGluZ106
>> "%B64FILE%" echo OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0KDQpTYXkgIls0LzRdIOe7k+aenO+8miIgJ1doaXRlJw0K
>> "%B64FILE%" echo JGluc3RhbGxlZCA9IEAoW3JlZ2V4XTo6TWF0Y2hlcygkdHh0LCAnKD9pKWRyaXZlciBwYWNrYWdl
>> "%B64FILE%" echo ICg/OndhcyApPyg/OnN1Y2Nlc3NmdWxseSApP2luc3RhbGxlZHzpqbHliqjljIUuKj/lt7LmiJDl
>> "%B64FILE%" echo ip/lronoo4UnKSkuQ291bnQNCmZvcmVhY2ggKCRsIGluIEAoJHR4dCAtc3BsaXQgIltgcmBuXSsi
>> "%B64FILE%" echo IHwgV2hlcmUtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBTZWxlY3QtT2JqZWN0IC1MYXN0IDEwKSkg
>> "%B64FILE%" echo eyBTYXkgKCIgICAgICAiICsgJGwpICdEYXJrR3JheScgfQ0KaWYgKCRlcnJUeHQuVHJpbSgpKSB7
>> "%B64FILE%" echo DQogICAgU2F5ICIgICAgICAtLS0gc3RkZXJyIC0tLSIgJ0RhcmtHcmF5Jw0KICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRsIGluIEAoJGVyclR4dCAtc3BsaXQgIltgcmBuXSsiIHwgV2hlcmUtT2JqZWN0IHsgJF8uVHJp
>> "%B64FILE%" echo bSgpIH0gfCBTZWxlY3QtT2JqZWN0IC1MYXN0IDYpKSB7IFNheSAoIiAgICAgICIgKyAkbCkgJ1ll
>> "%B64FILE%" echo bGxvdycgfQ0KfQ0KDQpTYXkgIiINCmlmICgkdHh0IC1tYXRjaCAnY29tcGxldGVkIHN1Y2Nlc3Nm
>> "%B64FILE%" echo dWxseXzmk43kvZzmiJDlip/lrozmiJAnKSB7DQogICAgaWYgKCRpbnN0YWxsZWQgLWd0IDApIHsg
>> "%B64FILE%" echo U2F5ICgiICDms6jlhaXlrozmiJDvvIx7MH0g5Liq6amx5Yqo5YyF5bey6KOF5YWlIHsxfTog44CC
>> "%B64FILE%" echo IiAtZiAkaW5zdGFsbGVkLCAkdGFyZ2V0LkxldHRlcikgJ0dyZWVuJyB9DQogICAgZWxzZSB7IFNh
>> "%B64FILE%" echo eSAoIiAg5rOo5YWl5a6M5oiQ77yIRElTTSDmnKrmiqXlkYrmlrDlop7pqbHliqjljIXvvIzlj6/o
>> "%B64FILE%" echo g73nm67moIfns7vnu5/ph4zlt7LmnInlkIzmoLfnmoTpqbHliqjvvInjgIIiKSAnR3JlZW4nIH0N
>> "%B64FILE%" echo CiAgICBTYXkgKCIgIOmHjeWQr+i/m+aWsOezu+e7n+WQju+8jOe9keWNoeW6lOivpeWwseiDveiu
>> "%B64FILE%" echo pOWHuuadpeS6huOAguaXpeW/l++8mnswfSIgLWYgJGxvZ0ZpbGUpICdHcmF5Jw0KfQ0KZWxzZWlm
>> "%B64FILE%" echo ICgkdHh0IC1tYXRjaCAnODcnIC1vciAkZXJyVHh0IC1tYXRjaCAncnVubmluZyBXaW5kb3dzIGlu
>> "%B64FILE%" echo c3RhbGxhdGlvbnzmraPlnKjov5DooYznmoQnKSB7DQogICAgU2F5ICIgIOWksei0pe+8muebruag
>> "%B64FILE%" echo h+iiqyBESVNNIOWIpOWumuS4uuato+WcqOi/kOihjOeahOezu+e7n++8iEVycm9yIDg377yJ44CC
>> "%B64FILE%" echo IiAnUmVkJw0KICAgIFNheSAiICDov5nor7TmmI7lrprkvY3liLDnmoTov5jkuI3mmK/omZrmi5/n
>> "%B64FILE%" echo s7vnu5/vvIzor7fmioogVGFyZ2V0RGlyIOaMh+WIsCB2aGR4IOaJgOWcqOebruW9leWQjuWGjeiv
>> "%B64FILE%" echo leOAgiIgJ1llbGxvdycNCn0NCmVsc2Ugew0KICAgIFNheSAiICDms6jlhaXnu5PmnpzkuI3noa7l
>> "%B64FILE%" echo rprvvIzor7fnnIvkuIrpnaLnmoTovpPlh7rjgIIiICdZZWxsb3cnDQogICAgU2F5ICgiICDlrozm
>> "%B64FILE%" echo lbTml6Xlv5fvvJp7MH0iIC1mICRsb2dGaWxlKSAnR3JheScNCiAgICBTYXkgIiAg5aaC5p6c5o+Q
>> "%B64FILE%" echo 56S644CM6K+l6amx5Yqo5LiO5omA6YCJ5pig5YOP5LiN5YW85a6544CN77yM6K+05piO5pys5py6
>> "%B64FILE%" echo 6amx5Yqo6KaB5rGC5pu06auY55qE57O757uf54mI5pys77yMIiAnR3JheScNCiAgICBTYXkgIiAg
>> "%B64FILE%" echo 6ZyA6KaB5Y67572R5Y2h5a6Y572R5LiL6L29IFdpbjEwIOeJiOmpseWKqO+8jOWGjeaJi+WKqOWc
>> "%B64FILE%" echo qOebruagh+ezu+e7n+mHjOWuieijheOAgiIgJ0dyYXknDQp9DQoNCiMgLS0tLS0tLS0tLSDmlLbl
>> "%B64FILE%" echo sL4gLS0tLS0tLS0tLQ0KdHJ5IHsgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGRydkRpcikg
>> "%B64FILE%" echo eyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRydkRpciAtUmVjdXJzZSAtRm9yY2UgLUVBIFNp
>> "%B64FILE%" echo bGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9DQppZiAoJGF0dGFjaGVkVmhkeCkgew0KICAgIFNh
>> "%B64FILE%" echo eSAiIg0KICAgIFNheSAoIiAg5Y246L295Li05pe25oyC6L2955qE6Jma5ouf56OB55uY77yaezB9
>> "%B64FILE%" echo IiAtZiAkYXR0YWNoZWRWaGR4KSAnRGFya0dyYXknDQogICAgRGlzbW91bnQtVmhkeCAtUGF0aCAk
>> "%B64FILE%" echo YXR0YWNoZWRWaGR4DQogICAgU2F5ICIgIOW3suWNuOi9ve+8iOS4jeS8mueVmeWcqOOAjOaIkeea
>> "%B64FILE%" echo hOeUteiEkeOAjemHjO+8iSIgJ0RhcmtHcmF5Jw0KfQ0KU2F5ICIiDQpSZWFkLUhvc3QgIiAg5oyJ
>> "%B64FILE%" echo 5Zue6L2m6YCA5Ye6Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=17970"
set "GOT=0"
for %%A in ("%PS1FILE%") do if exist "%%A" set "GOT=%%~zA"
if not "%GOT%"=="%NEED%" (
    echo.
    rem Keep the FULL-WIDTH parens on this line. cmd treats a half-width ) as the
    rem end of the enclosing block even inside echo text, and the batch dies with
    rem ". was unexpected at this time." without printing anything - that bug
    rem killed every English launcher in v1.x. The Chinese build was spared only
    rem because （ and ） are not syntax to cmd.
    echo   [错误] 自解压失败（期望 %NEED% 字节，实际 %GOT% 字节）。
    echo          请重新复制本文件，或临时关闭杀毒软件后重试。
    echo.
    pause
    exit /b 1
)
del "%B64FILE%" "%RAW%" >nul 2>&1

echo.
echo   正在启动，请稍候...
echo.

rem %~dp0 结尾带反斜杠，补一个 . 就没有了，避免写 if "%X:~-1%"=="\" 这种易错的判断。
rem 下面一行里不要出现任何嵌套引号。
set "ORIGIN=%~dp0."

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo   [错误] 脚本退出码 %RC%。
    echo          解压出的脚本留在这里，方便排查：
    echo             %PS1FILE%
    echo          想看纯文本报告（不开窗口）：
    echo             powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ConsoleMode
    echo.
    pause
    exit /b %RC%
)

rem [审计 P3-17] 成功结束后清理。以前只删 payload.b64 / payload.dat，
rem   于是 TEMP 里每跑一次就多一个文件夹和一个 ps1，越积越多。
rem   ps1 在脚本退出之后才删，运行期间不碰它。
del "%PS1FILE%" >nul 2>&1
rmdir "%WORKDIR%" >nul 2>&1
echo.
pause
exit /b 0
