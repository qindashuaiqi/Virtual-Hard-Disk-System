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
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs } catch { exit 9 }"
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
>> "%B64FILE%" echo blByZWZlcmVuY2UgPSAnQ29udGludWUnDQokU2NyaXB0OlZlcnNpb24gPSAnMS4zMScNCiRTY3Jp
>> "%B64FILE%" echo cHQ6T3JpZ2luRGlyID0gJE9yaWdpbkRpcg0KdHJ5IHsgJEhvc3QuVUkuUmF3VUkuV2luZG93VGl0
>> "%B64FILE%" echo bGUgPSAi5rOo5YWl572R5Y2h6amx5YqoIHYkKCRTY3JpcHQ6VmVyc2lvbikgLSBjb25uZWN0c2Vn
>> "%B64FILE%" echo YWJvdCIgfSBjYXRjaCB7fQ0KDQpmdW5jdGlvbiBTYXkgew0KICAgIHBhcmFtKFtzdHJpbmddJFRl
>> "%B64FILE%" echo eHQsIFtzdHJpbmddJENvbG9yID0gJ0dyYXknKQ0KICAgIFdyaXRlLUhvc3QgJFRleHQgLUZvcmVn
>> "%B64FILE%" echo cm91bmRDb2xvciAkQ29sb3INCn0NCg0KU2F5ICIiDQpTYXkgIiAg5rOo5YWl572R5Y2h6amx5Yqo
>> "%B64FILE%" echo ICB2JCgkU2NyaXB0OlZlcnNpb24pIiAnQ3lhbicNClNheSAiICDkvZzogIU6IGNvbm5lY3RzZWdh
>> "%B64FILE%" echo Ym90IiAnRGFya0dyYXknDQpTYXkgIiAgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiAnRGFya0dyYXknDQpTYXkgIiINCg0KJGFkbWlu
>> "%B64FILE%" echo ID0gKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbF1bU2VjdXJpdHkuUHJpbmNp
>> "%B64FILE%" echo cGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKSkuSXNJblJvbGUoW1NlY3VyaXR5LlBy
>> "%B64FILE%" echo aW5jaXBhbC5XaW5kb3dzQnVpbHRJblJvbGVdOjpBZG1pbmlzdHJhdG9yKQ0KaWYgKC1ub3QgJGFk
>> "%B64FILE%" echo bWluKSB7DQogICAgU2F5ICIgIFvplJnor69dIOmcgOimgeeuoeeQhuWRmOadg+mZkOOAguivt+WF
>> "%B64FILE%" echo s+aOieacrOeql+WPo++8jOWPs+mUruacrOaWh+S7tiAtPiDku6XnrqHnkIblkZjouqvku73ov5Do
>> "%B64FILE%" echo oYzjgIIiICdSZWQnDQogICAgU2F5ICIiDQogICAgUmVhZC1Ib3N0ICIgIOaMieWbnui9pumAgOWH
>> "%B64FILE%" echo uiINCiAgICBleGl0IDENCn0NCg0KIyAtLS0tLS0tLS0tIOivhuWIq+OAjOW9k+WJjeato+WcqOi/
>> "%B64FILE%" echo kOihjOeahOezu+e7n+OAje+8jOW/hemhu+aOkumZpCAtLS0tLS0tLS0tDQokc3lzTGV0dGVyID0g
>> "%B64FILE%" echo KFtzdHJpbmddJGVudjpTeXN0ZW1Ecml2ZSkuVHJpbUVuZCgnOicpLlRvVXBwZXIoKQ0KJHN5c1Zv
>> "%B64FILE%" echo bElkID0gJycNCnRyeSB7ICRzeXNWb2xJZCA9IFtzdHJpbmddKEdldC1Wb2x1bWUgLURyaXZlTGV0
>> "%B64FILE%" echo dGVyICRzeXNMZXR0ZXIgLUVycm9yQWN0aW9uIFN0b3ApLlVuaXF1ZUlkIH0gY2F0Y2gge30NCg0K
>> "%B64FILE%" echo ZnVuY3Rpb24gVGVzdC1Jc1J1bm5pbmdTeXN0ZW0gew0KICAgIHBhcmFtKCRWb2wpDQogICAgaWYg
>> "%B64FILE%" echo KChbc3RyaW5nXSRWb2wuRHJpdmVMZXR0ZXIpLlRvVXBwZXIoKSAtZXEgJHN5c0xldHRlcikgeyBy
>> "%B64FILE%" echo ZXR1cm4gJHRydWUgfQ0KICAgICMg5ZCM5LiA5Liq5Y236KKr5oyC5Yiw5Y+m5LiA5Liq55uY56ym
>> "%B64FILE%" echo 5pe2IFVuaXF1ZUlkIOebuOWQjO+8jOS5n+imgeaOkumZpO+8jA0KICAgICMg5ZCm5YiZIERJU00g
>> "%B64FILE%" echo 5ZCM5qC35oqlIEVycm9yIDg344CCDQogICAgaWYgKCRzeXNWb2xJZCAtYW5kIChbc3RyaW5nXSRW
>> "%B64FILE%" echo b2wuVW5pcXVlSWQgLWVxICRzeXNWb2xJZCkpIHsgcmV0dXJuICR0cnVlIH0NCiAgICByZXR1cm4g
>> "%B64FILE%" echo JGZhbHNlDQp9DQoNCiMgLS0tLS0tLS0tLSDlgJnpgInljbcgLS0tLS0tLS0tLQ0KZnVuY3Rpb24g
>> "%B64FILE%" echo R2V0LVRhcmdldENhbmRpZGF0ZXMgew0KICAgICRsaXN0ID0gQCgpDQoNCiAgICAkdmhkRGlza3Mg
>> "%B64FILE%" echo PSBAe30NCiAgICBmb3JlYWNoICgkZCBpbiBAKEdldC1EaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRs
>> "%B64FILE%" echo eUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoW3N0cmluZ10kZC5CdXNUeXBlIC1lcSAnRmlsZSBC
>> "%B64FILE%" echo YWNrZWQgVmlydHVhbCcpIHsgJHZoZERpc2tzW1tpbnRdJGQuTnVtYmVyXSA9ICR0cnVlIH0NCiAg
>> "%B64FILE%" echo ICB9DQoNCiAgICBmb3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9uIFNpbGVu
>> "%B64FILE%" echo dGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7IGNvbnRp
>> "%B64FILE%" echo bnVlIH0NCiAgICAgICAgJHJvb3QgPSAiezB9OlwiIC1mICR2LkRyaXZlTGV0dGVyDQogICAgICAg
>> "%B64FILE%" echo IGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICgkcm9vdCArICdXaW5kb3dzXFN5c3Rl
>> "%B64FILE%" echo bTMyXG50b3Nrcm5sLmV4ZScpKSkgeyBjb250aW51ZSB9DQoNCiAgICAgICAgJGRpc2tOdW0gPSAt
>> "%B64FILE%" echo MQ0KICAgICAgICB0cnkgeyAkZGlza051bSA9IFtpbnRdKEdldC1QYXJ0aXRpb24gLURyaXZlTGV0
>> "%B64FILE%" echo dGVyICR2LkRyaXZlTGV0dGVyIC1FcnJvckFjdGlvbiBTdG9wKS5EaXNrTnVtYmVyIH0gY2F0Y2gg
>> "%B64FILE%" echo e30NCg0KICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsNCiAgICAgICAgICAgIExl
>> "%B64FILE%" echo dHRlciAgPSBbc3RyaW5nXSR2LkRyaXZlTGV0dGVyDQogICAgICAgICAgICBMYWJlbCAgID0gW3N0
>> "%B64FILE%" echo cmluZ10kdi5GaWxlU3lzdGVtTGFiZWwNCiAgICAgICAgICAgIFJ1bm5pbmcgPSAoVGVzdC1Jc1J1
>> "%B64FILE%" echo bm5pbmdTeXN0ZW0gJHYpDQogICAgICAgICAgICBJc1ZoZCAgID0gKCRkaXNrTnVtIC1nZSAwIC1h
>> "%B64FILE%" echo bmQgJHZoZERpc2tzLkNvbnRhaW5zS2V5KCRkaXNrTnVtKSkNCiAgICAgICAgICAgIERpc2sgICAg
>> "%B64FILE%" echo PSAkZGlza051bQ0KICAgICAgICAgICAgU2l6ZUdCICA9IFttYXRoXTo6Um91bmQoJHYuU2l6ZSAv
>> "%B64FILE%" echo IDFHQiwgMSkNCiAgICAgICAgfQ0KICAgIH0NCiAgICByZXR1cm4gJGxpc3QNCn0NCg0KIyAtLS0t
>> "%B64FILE%" echo LS0tLS0tIOaJvuWPr+aMgui9veeahCB2aGR4IC0tLS0tLS0tLS0NCmZ1bmN0aW9uIEZpbmQtVmhk
>> "%B64FILE%" echo eEZpbGVzIHsNCiAgICAkZm91bmQgPSBAKCkNCiAgICBpZiAoJFNjcmlwdDpPcmlnaW5EaXIgLWFu
>> "%B64FILE%" echo ZCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkU2NyaXB0Ok9yaWdpbkRpcikpIHsNCiAgICAgICAg
>> "%B64FILE%" echo JGMgPSBKb2luLVBhdGggJFNjcmlwdDpPcmlnaW5EaXIgJ05ld1N5c3RlbURpc2sudmhkeCcNCiAg
>> "%B64FILE%" echo ICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGMpIHsgJGZvdW5kICs9ICRjIH0NCiAg
>> "%B64FILE%" echo ICB9DQogICAgZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FcnJvckFjdGlvbiBTaWxlbnRs
>> "%B64FILE%" echo eUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoLW5vdCAkdi5Ecml2ZUxldHRlcikgeyBjb250aW51
>> "%B64FILE%" echo ZSB9DQogICAgICAgIGlmICgkdi5Ecml2ZVR5cGUgLW5lICdGaXhlZCcpIHsgY29udGludWUgfQ0K
>> "%B64FILE%" echo ICAgICAgICAkYyA9ICJ7MH06XE5ld1N5c3RlbURpc2sudmhkeCIgLWYgJHYuRHJpdmVMZXR0ZXIN
>> "%B64FILE%" echo CiAgICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGMpIHsNCiAgICAgICAgICAgICRm
>> "%B64FILE%" echo dWxsID0gKEdldC1JdGVtIC1MaXRlcmFsUGF0aCAkYykuRnVsbE5hbWUNCiAgICAgICAgICAgIGlm
>> "%B64FILE%" echo ICgkZm91bmQgLW5vdGNvbnRhaW5zICRmdWxsKSB7ICRmb3VuZCArPSAkZnVsbCB9DQogICAgICAg
>> "%B64FILE%" echo IH0NCiAgICB9DQogICAgcmV0dXJuICRmb3VuZA0KfQ0KDQpmdW5jdGlvbiBNb3VudC1WaGR4IHsN
>> "%B64FILE%" echo CiAgICBwYXJhbShbc3RyaW5nXSRQYXRoKQ0KICAgICRkcEZpbGUgPSBKb2luLVBhdGggJGVudjpU
>> "%B64FILE%" echo RU1QICgiYXR0YWNoX3ZoZF97MH0udHh0IiAtZiAkUElEKQ0KICAgIEAoDQogICAgICAgICJzZWxl
>> "%B64FILE%" echo Y3QgdmRpc2sgZmlsZT1gIiRQYXRoYCIiLA0KICAgICAgICAnYXR0YWNoIHZkaXNrJywNCiAgICAg
>> "%B64FILE%" echo ICAgJ2V4aXQnDQogICAgKSB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNv
>> "%B64FILE%" echo ZGluZyBEZWZhdWx0DQogICAgJHIgPSAnJw0KICAgIHRyeSB7ICRyID0gKCYgZGlza3BhcnQgL3Mg
>> "%B64FILE%" echo JGRwRmlsZSAyPiYxIHwgT3V0LVN0cmluZykgfSBjYXRjaCB7ICRyID0gJF8uRXhjZXB0aW9uLk1l
>> "%B64FILE%" echo c3NhZ2UgfQ0KICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1Gb3JjZSAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0KICAgIGlmICgkciAtbWF0Y2ggJ3N1Y2Nlc3NmdWxs
>> "%B64FILE%" echo eXzmiJDlip8nKSB7IHJldHVybiAkdHJ1ZSB9DQogICAgU2F5ICgiICAgICAg5oyC6L296L+U5Zue
>> "%B64FILE%" echo OiAiICsgKCgkciAtcmVwbGFjZSAiXHMrIiwgJyAnKS5UcmltKCkpKSAnWWVsbG93Jw0KICAgIHJl
>> "%B64FILE%" echo dHVybiAkZmFsc2UNCn0NCg0KZnVuY3Rpb24gRGlzbW91bnQtVmhkeCB7DQogICAgcGFyYW0oW3N0
>> "%B64FILE%" echo cmluZ10kUGF0aCkNCiAgICAkZHBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImRldGFjaF92
>> "%B64FILE%" echo aGRfezB9LnR4dCIgLWYgJFBJRCkNCiAgICBAKA0KICAgICAgICAic2VsZWN0IHZkaXNrIGZpbGU9
>> "%B64FILE%" echo YCIkUGF0aGAiIiwNCiAgICAgICAgJ2RldGFjaCB2ZGlzaycsDQogICAgICAgICdleGl0Jw0KICAg
>> "%B64FILE%" echo ICkgfCBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGRwRmlsZSAtRW5jb2RpbmcgRGVmYXVsdA0K
>> "%B64FILE%" echo ICAgIHRyeSB7ICYgZGlza3BhcnQgL3MgJGRwRmlsZSAyPiYxIHwgT3V0LU51bGwgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU2lsZW50bHlDb250aW51ZQ0KfQ0KDQojIC0tLS0tLS0tLS0gWzEvNF0g5a6a5L2N55uu5qCH
>> "%B64FILE%" echo 57O757ufIC0tLS0tLS0tLS0NClNheSAiWzEvNF0g5a6a5L2N55uu5qCH57O757ufIC4uLiIgJ1do
>> "%B64FILE%" echo aXRlJw0KDQokYXR0YWNoZWRWaGR4ID0gJycNCiR0YXJnZXRzID0gQChHZXQtVGFyZ2V0Q2FuZGlk
>> "%B64FILE%" echo YXRlcykNCiR1c2FibGUgPSBAKCR0YXJnZXRzIHwgV2hlcmUtT2JqZWN0IHsgLW5vdCAkXy5SdW5u
>> "%B64FILE%" echo aW5nIH0pDQoNCiMg5LyY5YWI55So6Jma5ouf56OB55uY6YeM55qE57O757uf77yI5pys5bel5YW3
>> "%B64FILE%" echo 55qE5pys6IGM5Zy65pmv77yJDQokdmhkVGFyZ2V0cyA9IEAoJHVzYWJsZSB8IFdoZXJlLU9iamVj
>> "%B64FILE%" echo dCB7ICRfLklzVmhkIH0pDQoNCmlmICgkdmhkVGFyZ2V0cy5Db3VudCAtZXEgMCkgew0KICAgICR2
>> "%B64FILE%" echo aGR4RmlsZXMgPSBAKEZpbmQtVmhkeEZpbGVzKQ0KICAgIGlmICgkdmhkeEZpbGVzLkNvdW50IC1n
>> "%B64FILE%" echo dCAwKSB7DQogICAgICAgIGZvcmVhY2ggKCRmIGluICR2aGR4RmlsZXMpIHsNCiAgICAgICAgICAg
>> "%B64FILE%" echo IFNheSAoIiAgICAgIOWPkeeOsOiZmuaLn+ejgeebmCB7MH3vvIzmraPlnKjmjILovb0gLi4uIiAt
>> "%B64FILE%" echo ZiAkZikgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgaWYgKE1vdW50LVZoZHggLVBhdGggJGYpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICAkYXR0YWNoZWRWaGR4ID0gJGYNCiAgICAgICAgICAgICAgICBTYXkg
>> "%B64FILE%" echo IiAgICAgIOW3suaMgui9vSIgJ0dyZWVuJw0KICAgICAgICAgICAgICAgIGJyZWFrDQogICAgICAg
>> "%B64FILE%" echo ICAgICB9DQogICAgICAgIH0NCiAgICAgICAgaWYgKCRhdHRhY2hlZFZoZHgpIHsNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIFN0YXJ0LVNsZWVwIC1TZWNvbmRzIDINCiAgICAgICAgICAgICR0YXJnZXRzID0gQChHZXQt
>> "%B64FILE%" echo VGFyZ2V0Q2FuZGlkYXRlcykNCiAgICAgICAgICAgICR1c2FibGUgPSBAKCR0YXJnZXRzIHwgV2hl
>> "%B64FILE%" echo cmUtT2JqZWN0IHsgLW5vdCAkXy5SdW5uaW5nIH0pDQogICAgICAgICAgICAkdmhkVGFyZ2V0cyA9
>> "%B64FILE%" echo IEAoJHVzYWJsZSB8IFdoZXJlLU9iamVjdCB7ICRfLklzVmhkIH0pDQogICAgICAgIH0NCiAgICB9
>> "%B64FILE%" echo DQp9DQoNCmlmICgkdmhkVGFyZ2V0cy5Db3VudCAtZXEgMSkgew0KICAgICR0YXJnZXQgPSAkdmhk
>> "%B64FILE%" echo VGFyZ2V0c1swXQ0KICAgIFNheSAoIiAgICAgIOebruagh++8mnswfTogIO+8iOiZmuaLn+ejgeeb
>> "%B64FILE%" echo mOmHjOeahOezu+e7n++8jHsxfSBHQu+8iSIgLWYgJHRhcmdldC5MZXR0ZXIsICR0YXJnZXQuU2l6
>> "%B64FILE%" echo ZUdCKSAnR3JlZW4nDQp9DQplbHNlaWYgKCR1c2FibGUuQ291bnQgLWVxIDApIHsNCiAgICBTYXkg
>> "%B64FILE%" echo IiINCiAgICBTYXkgIiAgW+mUmeivr10g5rKh5om+5Yiw5Y+v5rOo5YWl55qE57O757uf44CCIiAn
>> "%B64FILE%" echo UmVkJw0KICAgIFNheSAoIiAgICAgICAgIOW9k+WJjeato+WcqOi/kOihjOeahOaYryB7MH0677yM
>> "%B64FILE%" echo 5a6D5LiN6IO95L2c5Li655uu5qCH77yIRElTTSDkuI3lhYHorrjvvInjgIIiIC1mICRzeXNMZXR0
>> "%B64FILE%" echo ZXIpICdZZWxsb3cnDQogICAgU2F5ICIgICAgICAgICDkuZ/msqHmnInmib7liLDlt7LmjILovb3m
>> "%B64FILE%" echo iJblj6/mjILovb3nmoQgTmV3U3lzdGVtRGlzay52aGR444CCIiAnWWVsbG93Jw0KICAgIFNheSAi
>> "%B64FILE%" echo ICAgICAgICAg6K+356Gu6K6k6Jma5ouf57O757uf6KOF5Zyo5ZOq5LiqIHZoZHgg5paH5Lu26YeM
>> "%B64FILE%" echo 44CB5paH5Lu25ZCN5piv5ZCm5Y+rIE5ld1N5c3RlbURpc2sudmhkeOOAgiIgJ1llbGxvdycNCiAg
>> "%B64FILE%" echo ICBTYXkgIiINCiAgICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRh
>> "%B64FILE%" echo dHRhY2hlZFZoZHggfQ0KICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhp
>> "%B64FILE%" echo dCAxDQp9DQplbHNlIHsNCiAgICBTYXkgIiAgICAgIOaJvuWIsOWkmuS4quWPr+azqOWFpeeahOez
>> "%B64FILE%" echo u+e7n++8jOivt+mAieaLqe+8miIgJ1doaXRlJw0KICAgIGZvciAoJGkgPSAwOyAkaSAtbHQgJHVz
>> "%B64FILE%" echo YWJsZS5Db3VudDsgJGkrKykgew0KICAgICAgICAkdCA9ICR1c2FibGVbJGldDQogICAgICAgICRr
>> "%B64FILE%" echo aW5kID0gaWYgKCR0LklzVmhkKSB7ICfomZrmi5/no4Hnm5gnIH0gZWxzZSB7ICfniannkIbliIbl
>> "%B64FILE%" echo jLonIH0NCiAgICAgICAgU2F5ICgiICAgICAgW3swfV0gezF9OiAgezJ9ICB7M30gR0IgIOWNt+ag
>> "%B64FILE%" echo hz17NH0iIC1mICgkaSArIDEpLCAkdC5MZXR0ZXIsICRraW5kLCAkdC5TaXplR0IsICR0LkxhYmVs
>> "%B64FILE%" echo KQ0KICAgIH0NCiAgICAkc2VsID0gUmVhZC1Ib3N0ICIgICAgICDovpPlhaXluo/lj7fvvIjpu5jo
>> "%B64FILE%" echo rqQgMe+8iSINCiAgICAkaWR4ID0gMQ0KICAgIFtpbnRdOjpUcnlQYXJzZSgkc2VsLCBbcmVmXSRp
>> "%B64FILE%" echo ZHgpIHwgT3V0LU51bGwNCiAgICBpZiAoJGlkeCAtbHQgMSAtb3IgJGlkeCAtZ3QgJHVzYWJsZS5D
>> "%B64FILE%" echo b3VudCkgeyAkaWR4ID0gMSB9DQogICAgJHRhcmdldCA9ICR1c2FibGVbJGlkeCAtIDFdDQogICAg
>> "%B64FILE%" echo U2F5ICgiICAgICAg55uu5qCH77yaezB9OiIgLWYgJHRhcmdldC5MZXR0ZXIpICdHcmVlbicNCn0N
>> "%B64FILE%" echo Cg0KIyDlj4zkv53pmanvvJrnu53kuI3lvoDov5DooYzkuK3nmoTns7vnu5/lhpkNCmlmICgkdGFy
>> "%B64FILE%" echo Z2V0LlJ1bm5pbmcpIHsNCiAgICBTYXkgIiINCiAgICBTYXkgIiAgW+mUmeivr10g6YCJ5Lit55qE
>> "%B64FILE%" echo 5piv5b2T5YmN5q2j5Zyo6L+Q6KGM55qE57O757uf77yMRElTTSDkuI3lhYHorrjvvIhFcnJvciA4
>> "%B64FILE%" echo N++8ieOAguW3suS4reatouOAgiIgJ1JlZCcNCiAgICBTYXkgIiINCiAgICBpZiAoJGF0dGFjaGVk
>> "%B64FILE%" echo VmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRhY2hlZFZoZHggfQ0KICAgIFJlYWQtSG9z
>> "%B64FILE%" echo dCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhpdCAxDQp9DQoNCiMgLS0tLS0tLS0tLSBbMi80
>> "%B64FILE%" echo XSDlr7zlh7rmnKzmnLrnvZHljaHpqbHliqggLS0tLS0tLS0tLQ0KU2F5ICJbMi80XSDku47mnKzm
>> "%B64FILE%" echo nLrlr7zlh7rnvZHljaHpqbHliqggLi4uIiAnV2hpdGUnDQokbmV0Q2xhc3NHdWlkID0gJzRkMzZl
>> "%B64FILE%" echo OTcyLWUzMjUtMTFjZS1iZmMxLTA4MDAyYmUxMDMxOCcgICAjIOe9kee7nOmAgumFjeWZqO+8iOS4
>> "%B64FILE%" echo juivreiogOaXoOWFs++8iQ0KJGRydkRpciA9IEpvaW4tUGF0aCAkZW52OlRFTVAgKCJpbmplY3Ru
>> "%B64FILE%" echo ZXRfezB9IiAtZiAkUElEKQ0KdHJ5IHsgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGRydkRp
>> "%B64FILE%" echo cikgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRydkRpciAtUmVjdXJzZSAtRm9yY2UgLUVy
>> "%B64FILE%" echo cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9DQpOZXctSXRlbSAtSXRlbVR5
>> "%B64FILE%" echo cGUgRGlyZWN0b3J5IC1QYXRoICRkcnZEaXIgLUZvcmNlIHwgT3V0LU51bGwNCg0KJGVudW1UZXh0
>> "%B64FILE%" echo ID0gJycNCnRyeSB7ICRlbnVtVGV4dCA9ICgmIHBucHV0aWwgL2VudW0tZHJpdmVycyAyPiYxIHwg
>> "%B64FILE%" echo T3V0LVN0cmluZykgfSBjYXRjaCB7fQ0KJG5ldE9lbXMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xs
>> "%B64FILE%" echo ZWN0aW9ucy5BcnJheUxpc3QNCmZvcmVhY2ggKCRibGsgaW4gKCRlbnVtVGV4dCAtc3BsaXQgIig/
>> "%B64FILE%" echo OlxyP1xuKXsyLH0iKSkgew0KICAgIGlmICgkYmxrIC1ub3RtYXRjaCAkbmV0Q2xhc3NHdWlkKSB7
>> "%B64FILE%" echo IGNvbnRpbnVlIH0NCiAgICAkbSA9IFtyZWdleF06Ok1hdGNoKCRibGssICcoP2kpXGIob2VtXGQr
>> "%B64FILE%" echo XC5pbmYpXGInKQ0KICAgIGlmICgtbm90ICRtLlN1Y2Nlc3MpIHsgY29udGludWUgfQ0KICAgICRu
>> "%B64FILE%" echo bSA9ICRtLkdyb3Vwc1sxXS5WYWx1ZS5Ub0xvd2VyKCkNCiAgICBpZiAoLW5vdCAkbmV0T2Vtcy5D
>> "%B64FILE%" echo b250YWlucygkbm0pKSB7IFt2b2lkXSRuZXRPZW1zLkFkZCgkbm0pIH0NCn0NClNheSAoIiAgICAg
>> "%B64FILE%" echo IOacrOacuuesrOS4ieaWuee9kee7nOmpseWKqOWMhTogezB9IOS4qiIgLWYgJG5ldE9lbXMuQ291
>> "%B64FILE%" echo bnQpICdEYXJrR3JheScNCmZvcmVhY2ggKCRvZW0gaW4gJG5ldE9lbXMpIHsNCiAgICAkZXIgPSAo
>> "%B64FILE%" echo JiBwbnB1dGlsIC9leHBvcnQtZHJpdmVyICRvZW0gJGRydkRpciAyPiYxIHwgT3V0LVN0cmluZykN
>> "%B64FILE%" echo CiAgICBpZiAoJGVyIC1tYXRjaCAnc3VjY2Vzc2Z1bGx5fOaIkOWKnycpIHsgU2F5ICgiICAgICAg
>> "%B64FILE%" echo W29rXSB7MH0iIC1mICRvZW0pICdEYXJrR3JheScgfQ0KICAgIGVsc2UgeyBTYXkgKCIgICAgICBb
>> "%B64FILE%" echo ISFdIHswfSAgezF9IiAtZiAkb2VtLCAoKCRlciAtcmVwbGFjZSAiXHMrIiwgJyAnKS5UcmltKCkp
>> "%B64FILE%" echo KSAnWWVsbG93JyB9DQp9DQoNCiMg44CQdjEuMuOAkXBucHV0aWwgL2VudW0tZHJpdmVycyDlj6rl
>> "%B64FILE%" echo iJfnrKzkuInmlrkgb2VtKi5pbmbvvIzkvJrmvI/mjonlhoXnva7vvIhpbi1ib3jvvInnvZHljaEN
>> "%B64FILE%" echo CiMg6amx5Yqo77ya54mp55CG5py6572R5Y2h5bi455So57O757uf6Ieq5bim5YyF77yI5LiN5Zyo
>> "%B64FILE%" echo IG9lbSDliJfooajph4zvvInvvIzkuIrpnaLkuIDkuKrpg73lr7zkuI3lh7rvvIzkuo7mmK8NCiMg
>> "%B64FILE%" echo 55uu5qCH57O757uf54Wn5qC35rKh572R4oCU4oCU55yL6LW35p2l5bCx5piv44CM6L+Z5Liq5bel
>> "%B64FILE%" echo 5YW35rKh5pWI5p6c44CN44CC6L+Z6YeM5oqK44CM5b2T5YmN55yf5a6e5a2Y5Zyo55qEDQojIOeJ
>> "%B64FILE%" echo qeeQhue9keWNoeOAjeato+WcqOeUqOeahCBJTkYg6KGl5a+85Ye677ya56ys5LiJ5pa5IG9lbSDl
>> "%B64FILE%" echo t7Llr7zov4fvvIjot7Pov4fvvInvvIxpbi1ib3gg55qE5LuODQojIERyaXZlclN0b3JlXEZpbGVS
>> "%B64FILE%" echo ZXBvc2l0b3J5IOaVtOWMheWkjeWItuOAgg0KU2F5ICIgICAgICDooaXlr7zlh7rniannkIbnvZHl
>> "%B64FILE%" echo jaHmraPlnKjkvb/nlKjnmoTpqbHliqjvvIjlkKvns7vnu5/lhoXnva7vvIkuLi4iICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCnRyeSB7DQogICAgJHBoeXNOZXRzID0gQChHZXQtUG5wRGV2aWNlIC1DbGFzcyBOZXQgLVBy
>> "%B64FILE%" echo ZXNlbnRPbmx5IC1FQSBTaWxlbnRseUNvbnRpbnVlIHwNCiAgICAgICAgV2hlcmUtT2JqZWN0IHsg
>> "%B64FILE%" echo JF8uSW5zdGFuY2VJZCAtbWF0Y2ggJ14oUENJfFVTQiknIH0pDQogICAgZm9yZWFjaCAoJGRldiBp
>> "%B64FILE%" echo biAkcGh5c05ldHMpIHsNCiAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICRkcnZJbmYgPSAnJw0K
>> "%B64FILE%" echo ICAgICAgICAgICAgdHJ5IHsgJGRydkluZiA9IFtzdHJpbmddKEdldC1QbnBEZXZpY2VQcm9wZXJ0
>> "%B64FILE%" echo eSAtSW5zdGFuY2VJZCAkZGV2Lkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0Ry
>> "%B64FILE%" echo aXZlckluZlBhdGgnIC1FQSBTdG9wKS5EYXRhIH0gY2F0Y2gge30NCiAgICAgICAgICAgIGlmICgt
>> "%B64FILE%" echo bm90ICRkcnZJbmYpIHsgY29udGludWUgfQ0KICAgICAgICAgICAgJGRydkluZiA9ICRkcnZJbmYu
>> "%B64FILE%" echo VG9Mb3dlcigpDQogICAgICAgICAgICBTYXkgKCIgICAgICDnvZHljaEgezB9IOato+WcqOS9v+eU
>> "%B64FILE%" echo qCB7MX0iIC1mICRkZXYuRnJpZW5kbHlOYW1lLCAkZHJ2SW5mKSAnRGFya0dyYXknDQogICAgICAg
>> "%B64FILE%" echo ICAgICBpZiAoJGRydkluZiAtbWF0Y2ggJ15vZW1cZCtcLmluZiQnKSB7IGNvbnRpbnVlIH0NCiAg
>> "%B64FILE%" echo ICAgICAgICAgICMgRmlsZVJlcG9zaXRvcnkg55qE5YyF55uu5b2V5ZCN5pivIDxpbmbmlofku7bl
>> "%B64FILE%" echo kI0+XzzmnrbmnoQ+Xzzlk4jluIw+77yM5L6L5aaCDQogICAgICAgICAgICAjIHJ0NjQweDY0Lmlu
>> "%B64FILE%" echo Zl9hbWQ2NF9jYmY0ZTIzOTgxYzNjOGEz44CC5b+F6aG755So5bimIC5pbmYg55qE5a6M5pW05paH
>> "%B64FILE%" echo 5Lu25ZCN5Y675Yy56YWN77ybDQogICAgICAgICAgICAjIOaXqeWJjeivr+eUqOOAjOWOu+aOieaJ
>> "%B64FILE%" echo qeWxleWQjeOAjeeahOWQjeWtl++8iHJ0NjQweDY0XyrvvInvvIzmsLjov5zljLnphY3kuI3kuIrv
>> "%B64FILE%" echo vIzlhoXnva7pqbHliqjkuIDkuKrpg70NCiAgICAgICAgICAgICMg5aSN5Yi25LiN5Ye65p2lIOKA
>> "%B64FILE%" echo lOKAlCDooajnjrDlsLHmmK/jgIzms6jlhaXkuobkvYbnvZHljaHov5jmmK/msqHpqbHliqjjgI3j
>> "%B64FILE%" echo gIINCiAgICAgICAgICAgICRmclJvb3QgPSAiJGVudjpTeXN0ZW1Sb290XFN5c3RlbTMyXERyaXZl
>> "%B64FILE%" echo clN0b3JlXEZpbGVSZXBvc2l0b3J5Ig0KICAgICAgICAgICAgJHBrZ0RpcnMgPSBAKEdldC1DaGls
>> "%B64FILE%" echo ZEl0ZW0gJGZyUm9vdCAtRGlyZWN0b3J5IC1GaWx0ZXIgKCRkcnZJbmYgKyAnXyonKSAtRUEgU2ls
>> "%B64FILE%" echo ZW50bHlDb250aW51ZSkNCiAgICAgICAgICAgIGlmICgkcGtnRGlycy5Db3VudCAtZXEgMCkgew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICRwa2dEaXJzID0gQChHZXQtQ2hpbGRJdGVtICRmclJvb3QgLURpcmVj
>> "%B64FILE%" echo dG9yeSAtRUEgU2lsZW50bHlDb250aW51ZSB8DQogICAgICAgICAgICAgICAgICAgIFdoZXJlLU9i
>> "%B64FILE%" echo amVjdCB7ICRfLk5hbWUuVG9Mb3dlcigpLlN0YXJ0c1dpdGgoJGRydkluZiArICdfJykgfSkNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIH0NCiAgICAgICAgICAgIGlmICgkcGtnRGlycy5Db3VudCAtZXEgMCkgew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgIFNheSAoIiAg5pyq5om+5YiwIHswfSDnmoTpqbHliqjljIXnm67lvZXvvIjl
>> "%B64FILE%" echo j6/og73pqbHliqjlkI3kuI7nm67lvZXlkI3kuI3kuIDoh7TvvIkiIC1mICRkcnZJbmYpICdZZWxs
>> "%B64FILE%" echo b3cnDQogICAgICAgICAgICB9DQogICAgICAgICAgICBmb3JlYWNoICgkcGQgaW4gJHBrZ0RpcnMp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgICAgICBDb3B5LUl0ZW0gLUxpdGVyYWxQYXRoICRwZC5GdWxsTmFtZSAt
>> "%B64FILE%" echo RGVzdGluYXRpb24gJGRydkRpciAtUmVjdXJzZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgKCIgIOW3suWkjeWItuWGhee9rue9keWNoempseWKqOWMhTog
>> "%B64FILE%" echo IiArICRwZC5OYW1lKSAnRGFya0dyYXknDQogICAgICAgICAgICB9DQogICAgICAgIH0gY2F0Y2gg
>> "%B64FILE%" echo eyBTYXkgKCIgICAgICBbISFdIOWGhee9rumpseWKqOWvvOWHuuWksei0pTogezB9IiAtZiAkXy5F
>> "%B64FILE%" echo eGNlcHRpb24uTWVzc2FnZSkgJ1llbGxvdycgfQ0KICAgIH0NCn0gY2F0Y2ggeyBTYXkgKCIgICAg
>> "%B64FILE%" echo ICBbISFdIOWGhee9rumpseWKqOWvvOWHuuW8guW4uDogezB9IiAtZiAkXy5FeGNlcHRpb24uTWVz
>> "%B64FILE%" echo c2FnZSkgJ1llbGxvdycgfQ0KDQokaW5mRmlsZXMgPSBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQ
>> "%B64FILE%" echo YXRoICRkcnZEaXIgLVJlY3Vyc2UgLUZpbHRlciAqLmluZiAtRXJyb3JBY3Rpb24gU2lsZW50bHlD
>> "%B64FILE%" echo b250aW51ZSkNCmlmICgkaW5mRmlsZXMuQ291bnQgLWVxIDApIHsNCiAgICBTYXkgIiINCiAgICBT
>> "%B64FILE%" echo YXkgIiAg5pys5py65rKh5pyJ5Y+v5a+85Ye655qE572R5Y2h6amx5Yqo77yI56ys5LiJ5pa55ZKM
>> "%B64FILE%" echo 57O757uf5YaF572u6YO95rKh5om+5Yiw77yJ44CCIiAnWWVsbG93Jw0KICAgIFNheSAiICDov5nn
>> "%B64FILE%" echo p43mg4XlhrXpgJrluLjkuI3mmK/nvLrpqbHliqjvvIzor7flnKjnm67moIfns7vnu5/ph4zot5Hj
>> "%B64FILE%" echo gIzmlrDns7vnu58t6K+K5pat5bm26KOF6amx5Yqo44CN55yL5YW35L2T5oql6ZSZ44CCIiAnWWVs
>> "%B64FILE%" echo bG93Jw0KICAgIFNheSAiIg0KICAgIHRyeSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2
>> "%B64FILE%" echo RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9DQogICAg
>> "%B64FILE%" echo aWYgKCRhdHRhY2hlZFZoZHgpIHsgRGlzbW91bnQtVmhkeCAtUGF0aCAkYXR0YWNoZWRWaGR4IH0N
>> "%B64FILE%" echo CiAgICBSZWFkLUhvc3QgIiAg5oyJ5Zue6L2m6YCA5Ye6Ig0KICAgIGV4aXQgMQ0KfQ0KJG1iID0g
>> "%B64FILE%" echo MA0KdHJ5IHsgJG1iID0gW21hdGhdOjpSb3VuZCgoKEdldC1DaGlsZEl0ZW0gJGRydkRpciAtUmVj
>> "%B64FILE%" echo dXJzZSAtRmlsZSB8IE1lYXN1cmUtT2JqZWN0IExlbmd0aCAtU3VtKS5TdW0pIC8gMU1CLCAxKSB9
>> "%B64FILE%" echo IGNhdGNoIHt9DQpTYXkgKCIgICAgICDlr7zlh7rlrozmiJDvvJp7MH0g5LiqIElORu+8jHsxfSBN
>> "%B64FILE%" echo QiIgLWYgJGluZkZpbGVzLkNvdW50LCAkbWIpICdHcmVlbicNCg0KIyAtLS0tLS0tLS0tIFszLzRd
>> "%B64FILE%" echo IOazqOWFpSAtLS0tLS0tLS0tDQpTYXkgIlszLzRdIOazqOWFpeWIsOebruagh+ezu+e7n++8iOWP
>> "%B64FILE%" echo r+iDveimgeS4gOS4pOWIhumSn++8iS4uLiIgJ1doaXRlJw0KJGxvZ0ZpbGUgPSBKb2luLVBhdGgg
>> "%B64FILE%" echo JGVudjpURU1QICgiaW5qZWN0bmV0X3swfS5sb2ciIC1mICRQSUQpDQokZXJyRmlsZSA9ICRsb2dG
>> "%B64FILE%" echo aWxlICsgJy5lcnInDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbG9nRmlsZSkg
>> "%B64FILE%" echo eyBSZW1vdmUtSXRlbSAkbG9nRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUgfSB9IGNh
>> "%B64FILE%" echo dGNoIHt9DQoNCiMgL0ltYWdlIOWQjumdouS4jeWKoOW8leWPt++8muWGmeaIkCAiL0ltYWdlOkU6
>> "%B64FILE%" echo XCIg5pe257uT5bC+55qEIFwiIOS8muiiq+W9k+aIkOi9rOS5ieW8leWPt++8jA0KIyDlj4LmlbDk
>> "%B64FILE%" echo vJrlj5jmiJAgSW1hZ2U6RToiIOiAjOaKpemUmeOAguebmOespui3r+W+hOS4jeWQq+epuuagvO+8
>> "%B64FILE%" echo jOS4jeWKoOW8leWPt+acgOeos+OAgg0KJGRpc21BcmdzID0gJy9FbmdsaXNoIC9JbWFnZTp7MH06
>> "%B64FILE%" echo XCAvQWRkLURyaXZlciAvRHJpdmVyOiJ7MX0iIC9SZWN1cnNlJyAtZiAkdGFyZ2V0LkxldHRlciwg
>> "%B64FILE%" echo JGRydkRpcg0KU2F5ICgiICAgICAgZGlzbSB7MH0iIC1mICRkaXNtQXJncykgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo DQokcHJvYyA9IFN0YXJ0LVByb2Nlc3MgLUZpbGVQYXRoICdkaXNtLmV4ZScgLUFyZ3VtZW50TGlz
>> "%B64FILE%" echo dCAkZGlzbUFyZ3MgYA0KICAgICAgICAgICAgLVJlZGlyZWN0U3RhbmRhcmRPdXRwdXQgJGxvZ0Zp
>> "%B64FILE%" echo bGUgLVJlZGlyZWN0U3RhbmRhcmRFcnJvciAkZXJyRmlsZSBgDQogICAgICAgICAgICAtTm9OZXdX
>> "%B64FILE%" echo aW5kb3cgLVBhc3NUaHJ1IC1FcnJvckFjdGlvbiBTdG9wDQoNCiRzdyA9IFtTeXN0ZW0uRGlhZ25v
>> "%B64FILE%" echo c3RpY3MuU3RvcHdhdGNoXTo6U3RhcnROZXcoKQ0KJGxhc3RCZWF0ID0gMA0Kd2hpbGUgKC1ub3Qg
>> "%B64FILE%" echo JHByb2MuSGFzRXhpdGVkKSB7DQogICAgU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA3MDANCiAg
>> "%B64FILE%" echo ICBpZiAoKCRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIC0gJGxhc3RCZWF0KSAtZ2UgMzAwMCkgew0K
>> "%B64FILE%" echo ICAgICAgICAkbGFzdEJlYXQgPSAkc3cuRWxhcHNlZE1pbGxpc2Vjb25kcw0KICAgICAgICBTYXkg
>> "%B64FILE%" echo KCIgICAgICDlt7LnlKggezB9IOenki4uLiIgLWYgW2ludF0kc3cuRWxhcHNlZC5Ub3RhbFNlY29u
>> "%B64FILE%" echo ZHMpICdEYXJrR3JheScNCiAgICB9DQogICAgaWYgKCRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIC1n
>> "%B64FILE%" echo dCA5MDAwMDApIHsNCiAgICAgICAgdHJ5IHsgU3RvcC1Qcm9jZXNzIC1JZCAkcHJvYy5JZCAtRm9y
>> "%B64FILE%" echo Y2UgLUVBIFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fQ0KICAgICAgICBTYXkgIiAgICAgIOi2
>> "%B64FILE%" echo hei/hyAxNSDliIbpkp/vvIzlt7LmlL7lvIMiICdSZWQnDQogICAgICAgIGJyZWFrDQogICAgfQ0K
>> "%B64FILE%" echo fQ0KdHJ5IHsgJHByb2MuV2FpdEZvckV4aXQoKSB9IGNhdGNoIHt9DQoNCiMgLS0tLS0tLS0tLSBb
>> "%B64FILE%" echo NC80XSDnu5PmnpwgLS0tLS0tLS0tLQ0KU2F5ICIiDQokdHh0ID0gJycNCnRyeSB7IGlmIChUZXN0
>> "%B64FILE%" echo LVBhdGggLUxpdGVyYWxQYXRoICRsb2dGaWxlKSB7ICR0eHQgPSBbSU8uRmlsZV06OlJlYWRBbGxU
>> "%B64FILE%" echo ZXh0KCRsb2dGaWxlLCBbVGV4dC5FbmNvZGluZ106OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0KJGVy
>> "%B64FILE%" echo clR4dCA9ICcnDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZXJyRmlsZSkgeyAk
>> "%B64FILE%" echo ZXJyVHh0ID0gW0lPLkZpbGVdOjpSZWFkQWxsVGV4dCgkZXJyRmlsZSwgW1RleHQuRW5jb2Rpbmdd
>> "%B64FILE%" echo OjpEZWZhdWx0KSB9IH0gY2F0Y2gge30NCg0KU2F5ICJbNC80XSDnu5PmnpzvvJoiICdXaGl0ZScN
>> "%B64FILE%" echo CiRpbnN0YWxsZWQgPSBAKFtyZWdleF06Ok1hdGNoZXMoJHR4dCwgJyg/aSlkcml2ZXIgcGFja2Fn
>> "%B64FILE%" echo ZSAoPzp3YXMgKT8oPzpzdWNjZXNzZnVsbHkgKT9pbnN0YWxsZWR86amx5Yqo5YyFLio/5bey5oiQ
>> "%B64FILE%" echo 5Yqf5a6J6KOFJykpLkNvdW50DQpmb3JlYWNoICgkbCBpbiBAKCR0eHQgLXNwbGl0ICJbYHJgbl0r
>> "%B64FILE%" echo IiB8IFdoZXJlLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgU2VsZWN0LU9iamVjdCAtTGFzdCAxMCkp
>> "%B64FILE%" echo IHsgU2F5ICgiICAgICAgIiArICRsKSAnRGFya0dyYXknIH0NCmlmICgkZXJyVHh0LlRyaW0oKSkg
>> "%B64FILE%" echo ew0KICAgIFNheSAiICAgICAgLS0tIHN0ZGVyciAtLS0iICdEYXJrR3JheScNCiAgICBmb3JlYWNo
>> "%B64FILE%" echo ICgkbCBpbiBAKCRlcnJUeHQgLXNwbGl0ICJbYHJgbl0rIiB8IFdoZXJlLU9iamVjdCB7ICRfLlRy
>> "%B64FILE%" echo aW0oKSB9IHwgU2VsZWN0LU9iamVjdCAtTGFzdCA2KSkgeyBTYXkgKCIgICAgICAiICsgJGwpICdZ
>> "%B64FILE%" echo ZWxsb3cnIH0NCn0NCg0KU2F5ICIiDQppZiAoJHR4dCAtbWF0Y2ggJ2NvbXBsZXRlZCBzdWNjZXNz
>> "%B64FILE%" echo ZnVsbHl85pON5L2c5oiQ5Yqf5a6M5oiQJykgew0KICAgIGlmICgkaW5zdGFsbGVkIC1ndCAwKSB7
>> "%B64FILE%" echo IFNheSAoIiAg5rOo5YWl5a6M5oiQ77yMezB9IOS4qumpseWKqOWMheW3suijheWFpSB7MX06IOOA
>> "%B64FILE%" echo giIgLWYgJGluc3RhbGxlZCwgJHRhcmdldC5MZXR0ZXIpICdHcmVlbicgfQ0KICAgIGVsc2UgeyBT
>> "%B64FILE%" echo YXkgKCIgIOazqOWFpeWujOaIkO+8iERJU00g5pyq5oql5ZGK5paw5aKe6amx5Yqo5YyF77yM5Y+v
>> "%B64FILE%" echo 6IO955uu5qCH57O757uf6YeM5bey5pyJ5ZCM5qC355qE6amx5Yqo77yJ44CCIikgJ0dyZWVuJyB9
>> "%B64FILE%" echo DQogICAgU2F5ICgiICDph43lkK/ov5vmlrDns7vnu5/lkI7vvIznvZHljaHlupTor6XlsLHog73o
>> "%B64FILE%" echo rqTlh7rmnaXkuobjgILml6Xlv5fvvJp7MH0iIC1mICRsb2dGaWxlKSAnR3JheScNCn0NCmVsc2Vp
>> "%B64FILE%" echo ZiAoJHR4dCAtbWF0Y2ggJzg3JyAtb3IgJGVyclR4dCAtbWF0Y2ggJ3J1bm5pbmcgV2luZG93cyBp
>> "%B64FILE%" echo bnN0YWxsYXRpb2585q2j5Zyo6L+Q6KGM55qEJykgew0KICAgIFNheSAiICDlpLHotKXvvJrnm67m
>> "%B64FILE%" echo oIfooqsgRElTTSDliKTlrprkuLrmraPlnKjov5DooYznmoTns7vnu5/vvIhFcnJvciA4N++8ieOA
>> "%B64FILE%" echo giIgJ1JlZCcNCiAgICBTYXkgIiAg6L+Z6K+05piO5a6a5L2N5Yiw55qE6L+Y5LiN5piv6Jma5ouf
>> "%B64FILE%" echo 57O757uf77yM6K+35oqKIFRhcmdldERpciDmjIfliLAgdmhkeCDmiYDlnKjnm67lvZXlkI7lho3o
>> "%B64FILE%" echo r5XjgIIiICdZZWxsb3cnDQp9DQplbHNlIHsNCiAgICBTYXkgIiAg5rOo5YWl57uT5p6c5LiN56Gu
>> "%B64FILE%" echo 5a6a77yM6K+355yL5LiK6Z2i55qE6L6T5Ye644CCIiAnWWVsbG93Jw0KICAgIFNheSAoIiAg5a6M
>> "%B64FILE%" echo 5pW05pel5b+X77yaezB9IiAtZiAkbG9nRmlsZSkgJ0dyYXknDQogICAgU2F5ICIgIOWmguaenOaP
>> "%B64FILE%" echo kOekuuOAjOivpempseWKqOS4juaJgOmAieaYoOWDj+S4jeWFvOWuueOAje+8jOivtOaYjuacrOac
>> "%B64FILE%" echo uumpseWKqOimgeaxguabtOmrmOeahOezu+e7n+eJiOacrO+8jCIgJ0dyYXknDQogICAgU2F5ICIg
>> "%B64FILE%" echo IOmcgOimgeWOu+e9keWNoeWumOe9keS4i+i9vSBXaW4xMCDniYjpqbHliqjvvIzlho3miYvliqjl
>> "%B64FILE%" echo nKjnm67moIfns7vnu5/ph4zlronoo4XjgIIiICdHcmF5Jw0KfQ0KDQojIC0tLS0tLS0tLS0g5pS2
>> "%B64FILE%" echo 5bC+IC0tLS0tLS0tLS0NCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRkcnZEaXIp
>> "%B64FILE%" echo IHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcnZEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQ0KaWYgKCRhdHRhY2hlZFZoZHgpIHsNCiAgICBT
>> "%B64FILE%" echo YXkgIiINCiAgICBTYXkgKCIgIOWNuOi9veS4tOaXtuaMgui9veeahOiZmuaLn+ejgeebmO+8mnsw
>> "%B64FILE%" echo fSIgLWYgJGF0dGFjaGVkVmhkeCkgJ0RhcmtHcmF5Jw0KICAgIERpc21vdW50LVZoZHggLVBhdGgg
>> "%B64FILE%" echo JGF0dGFjaGVkVmhkeA0KICAgIFNheSAiICDlt7Lljbjovb3vvIjkuI3kvJrnlZnlnKjjgIzmiJHn
>> "%B64FILE%" echo moTnlLXohJHjgI3ph4zvvIkiICdEYXJrR3JheScNCn0NClNheSAiIg0KUmVhZC1Ib3N0ICIgIOaM
>> "%B64FILE%" echo ieWbnui9pumAgOWHuiINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=17344"
set "GOT=0"
for %%A in ("%PS1FILE%") do if exist "%%A" set "GOT=%%~zA"
if not "%GOT%"=="%NEED%" (
    echo.
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo   [错误] 脚本退出码 %RC%。
    echo          想看纯文本报告（不开窗口）：
    echo             powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ConsoleMode
    echo.
    pause
    exit /b %RC%
)
echo.
pause
exit /b 0
