@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 修好菜单指向
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
set "PS1FILE=%WORKDIR%\修好菜单指向-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/PCMNCiAg5L+u5aW95ZCv5Yqo6I+c5Y2V5oyH5ZCR77yI6Jma5ouf56Gs55uY57O757uf77yJ
>> "%B64FILE%" echo DQogIOS9nOiAhe+8mmNvbm5lY3RzZWdhYm90DQoNCiAg55So6YCU77ya6KOF5aW96Jma5ouf57O7
>> "%B64FILE%" echo 57uf5ZCO77yM5byA5py66I+c5Y2V6YeM5Y+v6IO9DQogICAgwrcg5pyJ6L+Z5LiA6aG577yM5L2G
>> "%B64FILE%" echo 5LiA6YCJ5bCx5oqlIDB4YzAwMDAwMGYgLyDmib7kuI3liLDmlofku7YNCiAgICDCtyDmiJbogIXl
>> "%B64FILE%" echo jovmoLnmsqHov5nkuIDpobkNCiAg5Y6f5Zug5piv6I+c5Y2V5p2h55uu5oyH5ZCR55qEIC52aGR4
>> "%B64FILE%" echo IOi3r+W+hOS4jeWvue+8iOaIluayoei/m+aYvuekuumhuuW6j++8ieOAguacrOW3peWFt+S8mu+8
>> "%B64FILE%" echo mg0KDQogICAgMS4g5om+5Ye65pys5bel5YW36KOF6L+H55qE5omA5pyJ6Jma5ouf57O757uf77yI
>> "%B64FILE%" echo 5pyJIHh4eC5ib290LnR4dCDnmoTpgqPkupvvvIkNCiAgICAyLiDmoLjlr7nlvIDmnLroj5zljZXp
>> "%B64FILE%" echo h4zlr7nlupTmnaHnm67mjIflkJHnmoTot6/lvoTvvIzot5/nnJ/lrp7mlofku7bot6/lvoTpgJDl
>> "%B64FILE%" echo rZfmr5Tlr7kNCiAgICAzLiDkuI3lr7nlsLHmlLnlm57mnaXvvJvmnaHnm67kuKLkuoblsLHmjIno
>> "%B64FILE%" echo rrDlvZXooaXkuIDmnaHvvJvmsqHov5voj5zljZXlsLHliqDlm57ljrsNCg0KICDkuI3liqjomZrm
>> "%B64FILE%" echo i5/no4Hnm5jph4znmoTns7vnu5/lhoXlrrnvvIzkuI3liqjljp/ns7vnu5/jgIINCiM+DQoNCiRF
>> "%B64FILE%" echo cnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjMxJw0K
>> "%B64FILE%" echo JFNjcmlwdDpMb2dGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoIuS/ruWlveiPnOWNleaMh+WQ
>> "%B64FILE%" echo kS17MH0ubG9nIiAtZiAoR2V0LURhdGUgLUZvcm1hdCAneXl5eU1NZGQnKSkNCg0KZnVuY3Rpb24g
>> "%B64FILE%" echo V3JpdGUtTG9nIHsNCiAgICBwYXJhbShbc3RyaW5nXSRNc2csIFtzdHJpbmddJExldmVsID0gJ0lO
>> "%B64FILE%" echo Rk8nKQ0KICAgICRsaW5lID0gIlt7MH1dIFt7MX1dIHsyfSIgLWYgKEdldC1EYXRlIC1Gb3JtYXQg
>> "%B64FILE%" echo J0hIOm1tOnNzJyksICRMZXZlbCwgJE1zZw0KICAgIHRyeSB7IEFkZC1Db250ZW50IC1MaXRlcmFs
>> "%B64FILE%" echo UGF0aCAkU2NyaXB0OkxvZ0ZpbGUgLVZhbHVlICRsaW5lIC1FbmNvZGluZyBVVEY4IH0gY2F0Y2gg
>> "%B64FILE%" echo e30NCiAgICAkYyA9ICdHcmF5Jw0KICAgIGlmICgkTGV2ZWwgLWVxICdPSycpIHsgJGMgPSAnR3Jl
>> "%B64FILE%" echo ZW4nIH0NCiAgICBpZiAoJExldmVsIC1lcSAnV0FSTicpIHsgJGMgPSAnWWVsbG93JyB9DQogICAg
>> "%B64FILE%" echo aWYgKCRMZXZlbCAtZXEgJ0VSUicpIHsgJGMgPSAnUmVkJyB9DQogICAgV3JpdGUtSG9zdCAkbGlu
>> "%B64FILE%" echo ZSAtRm9yZWdyb3VuZENvbG9yICRjDQp9DQoNCmZ1bmN0aW9uIFRlc3QtQWRtaW4gew0KICAgICRp
>> "%B64FILE%" echo ZCA9IFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0lkZW50aXR5XTo6R2V0Q3VycmVudCgpDQog
>> "%B64FILE%" echo ICAgJHAgPSBOZXctT2JqZWN0IFNlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzUHJpbmNpcGFsKCRp
>> "%B64FILE%" echo ZCkNCiAgICByZXR1cm4gJHAuSXNJblJvbGUoW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzQnVp
>> "%B64FILE%" echo bHRJblJvbGVdOjpBZG1pbmlzdHJhdG9yKQ0KfQ0KDQpmdW5jdGlvbiBJbnZva2UtQmNkIHsNCiAg
>> "%B64FILE%" echo ICBwYXJhbShbc3RyaW5nW11dJEJjZEFyZ3MsIFtzdHJpbmddJFRhZyA9ICcnKQ0KICAgICR0eHQg
>> "%B64FILE%" echo PSAnJw0KICAgIHRyeSB7ICR0eHQgPSAoJiBiY2RlZGl0IEBCY2RBcmdzIDI+JjEgfCBPdXQtU3Ry
>> "%B64FILE%" echo aW5nKSB9IGNhdGNoIHsgJHR4dCA9ICLosIPnlKjlvILluLg6ICQoJF8uRXhjZXB0aW9uLk1lc3Nh
>> "%B64FILE%" echo Z2UpIiB9DQogICAgJGNvZGUgPSAkTEFTVEVYSVRDT0RFDQogICAgJGNsZWFuID0gKCR0eHQgLXJl
>> "%B64FILE%" echo cGxhY2UgJ1xzKycsICcgJykuVHJpbSgpDQogICAgV3JpdGUtTG9nICgiYmNkZWRpdCB7MH0gW3sx
>> "%B64FILE%" echo fV0gPT4gZXhpdD17Mn0gIHszfSIgLWYgJFRhZywgKCRCY2RBcmdzIC1qb2luICcgJyksICRjb2Rl
>> "%B64FILE%" echo LCAkY2xlYW4pDQogICAgJGJhZCA9ICgkdHh0IC1tYXRjaCAn5om+5LiN5YiwfG5vdCBmb3VuZHzm
>> "%B64FILE%" echo l6DmlYh8aW52YWxpZHzmi5Lnu518ZGVuaWVkfOWksei0pXxmYWlsZWR86ZSZ6K+vfGVycm9yJykN
>> "%B64FILE%" echo CiAgICByZXR1cm4gQHsgT2sgPSAoKCRjb2RlIC1lcSAwKSAtYW5kICgtbm90ICRiYWQpKTsgQ29k
>> "%B64FILE%" echo ZSA9ICRjb2RlOyBUZXh0ID0gJGNsZWFuOyBSYXcgPSAkdHh0IH0NCn0NCg0KIyDlrozmlbTot6/l
>> "%B64FILE%" echo voQgLT4gQkNEIOeahCB2aGQ9IOWGmeazleOAguW/hemhu+S/neeVmeS4remXtOWtkOebruW9le+8
>> "%B64FILE%" echo mg0KIyAgIEQ6XOiZmuaLn+ejgeebmFxtYWltYWkudmhkeCAgLT4gIHZoZD1bRDpdXOiZmuaLn+ej
>> "%B64FILE%" echo geebmFxtYWltYWkudmhkeA0KZnVuY3Rpb24gR2V0LVZoZEJjZERldmljZSB7DQogICAgcGFyYW0o
>> "%B64FILE%" echo W3N0cmluZ10kRnVsbFBhdGgpDQogICAgJGZ1bGwgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGdWxs
>> "%B64FILE%" echo UGF0aCgkRnVsbFBhdGgpDQogICAgJHJvb3QgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRQYXRoUm9v
>> "%B64FILE%" echo dCgkZnVsbCkNCiAgICBpZiAoLW5vdCAkcm9vdCAtb3IgJHJvb3QuTGVuZ3RoIC1sdCAzKSB7IHRo
>> "%B64FILE%" echo cm93ICLot6/lvoTml6DmlYjvvJokRnVsbFBhdGgiIH0NCiAgICAkbGV0dGVyID0gJHJvb3QuU3Vi
>> "%B64FILE%" echo c3RyaW5nKDAsIDEpLlRvVXBwZXIoKQ0KICAgICRyZWwgPSAkZnVsbC5TdWJzdHJpbmcoJHJvb3Qu
>> "%B64FILE%" echo TGVuZ3RoKS5UcmltU3RhcnQoJ1wnKQ0KICAgIGlmICgtbm90ICRyZWwpIHsgdGhyb3cgIui3r+W+
>> "%B64FILE%" echo hOaXoOaViO+8miRGdWxsUGF0aCIgfQ0KICAgIHJldHVybiAidmhkPVskKCRsZXR0ZXIpOl1cJHJl
>> "%B64FILE%" echo bCINCn0NCg0KIyDlj43lkJHop6PmnpDvvIznlKjmnaXot5/nnJ/lrp7ot6/lvoTpgJDlrZfmr5Tl
>> "%B64FILE%" echo r7kNCmZ1bmN0aW9uIEdldC1GdWxsUGF0aEZyb21CY2REZXZpY2Ugew0KICAgIHBhcmFtKFtzdHJp
>> "%B64FILE%" echo bmddJERldikNCiAgICBpZiAoLW5vdCAkRGV2KSB7IHJldHVybiAnJyB9DQogICAgJG0gPSBbcmVn
>> "%B64FILE%" echo ZXhdOjpNYXRjaCgkRGV2LCAnXnZoZD1cWyhbQS1aYS16XSk6XF1cXCguKykkJykNCiAgICBpZiAo
>> "%B64FILE%" echo LW5vdCAkbS5TdWNjZXNzKSB7IHJldHVybiAnJyB9DQogICAgcmV0dXJuICgiezB9Olx7MX0iIC1m
>> "%B64FILE%" echo ICRtLkdyb3Vwc1sxXS5WYWx1ZS5Ub1VwcGVyKCksICRtLkdyb3Vwc1syXS5WYWx1ZSkNCn0NCg0K
>> "%B64FILE%" echo IyDmiavmiYDmnInlm7rlrpogTlRGUyDnm5jph4znmoQgdmhkeOOAguW5v+W6puS8mOWFiCArIOaM
>> "%B64FILE%" echo ieebruW9leWQjeWJquaene+8jA0KIyDkuI3ov5sgV2luZG93cyAvIFVzZXJzIC8g5Zue5pS256uZ
>> "%B64FILE%" echo 77yM5omA5Lul5rex5bqm5byA5YiwIDYg5Lmf5LiN5oWi44CCDQpmdW5jdGlvbiBHZXQtQWxsVmhk
>> "%B64FILE%" echo eEZpbGUgew0KICAgIHBhcmFtKFtpbnRdJE1heERlcHRoID0gNikNCiAgICAkc2tpcCA9IEAoJyRS
>> "%B64FILE%" echo RUNZQ0xFLkJJTicsICdTeXN0ZW0gVm9sdW1lIEluZm9ybWF0aW9uJywgJ1dpbmRvd3MnLCAnUHJv
>> "%B64FILE%" echo Z3JhbSBGaWxlcycsDQogICAgICAgICAgICAgICdQcm9ncmFtIEZpbGVzICh4ODYpJywgJ1Byb2dy
>> "%B64FILE%" echo YW1EYXRhJywgJ1VzZXJzJywgJyRXaW5SRUFnZW50JywgJ1JlY292ZXJ5JywNCiAgICAgICAgICAg
>> "%B64FILE%" echo ICAgJ25vZGVfbW9kdWxlcycsICcuZ2l0JywgJ1dpblN4UycpDQogICAgJGZvdW5kID0gTmV3LU9i
>> "%B64FILE%" echo amVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQogICAgZm9yZWFjaCAoJHYgaW4gQChH
>> "%B64FILE%" echo ZXQtVm9sdW1lIC1FQSBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoLW5vdCAkdi5E
>> "%B64FILE%" echo cml2ZUxldHRlcikgeyBjb250aW51ZSB9DQogICAgICAgIGlmICgkdi5GaWxlU3lzdGVtIC1uZSAn
>> "%B64FILE%" echo TlRGUycpIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQn
>> "%B64FILE%" echo KSB7IGNvbnRpbnVlIH0NCiAgICAgICAgJHF1ZXVlID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVj
>> "%B64FILE%" echo dGlvbnMuUXVldWUNCiAgICAgICAgJHF1ZXVlLkVucXVldWUoQCgiJCgkdi5Ecml2ZUxldHRlcik6
>> "%B64FILE%" echo XCIsIDApKQ0KICAgICAgICB3aGlsZSAoJHF1ZXVlLkNvdW50IC1ndCAwKSB7DQogICAgICAgICAg
>> "%B64FILE%" echo ICAkY3VyID0gJHF1ZXVlLkRlcXVldWUoKQ0KICAgICAgICAgICAgJGRpciA9IFtzdHJpbmddJGN1
>> "%B64FILE%" echo clswXQ0KICAgICAgICAgICAgJGQgPSBbaW50XSRjdXJbMV0NCiAgICAgICAgICAgIHRyeSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgZm9yZWFjaCAoJGYgaW4gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRG
>> "%B64FILE%" echo aWxlcygkZGlyLCAnKi52aGR4JykpIHsNCiAgICAgICAgICAgICAgICAgICAgW3ZvaWRdJGZvdW5k
>> "%B64FILE%" echo LkFkZCgoTmV3LU9iamVjdCBTeXN0ZW0uSU8uRmlsZUluZm8gJGYpKQ0KICAgICAgICAgICAgICAg
>> "%B64FILE%" echo IH0NCiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAgICAgICAgICAgIGlmICgkZCAtZ2UgJE1heERl
>> "%B64FILE%" echo cHRoKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9y
>> "%B64FILE%" echo ZWFjaCAoJHN1YiBpbiBbU3lzdGVtLklPLkRpcmVjdG9yeV06OkVudW1lcmF0ZURpcmVjdG9yaWVz
>> "%B64FILE%" echo KCRkaXIpKSB7DQogICAgICAgICAgICAgICAgICAgIGlmICgkc2tpcCAtY29udGFpbnMgW1N5c3Rl
>> "%B64FILE%" echo bS5JTy5QYXRoXTo6R2V0RmlsZU5hbWUoJHN1YikpIHsgY29udGludWUgfQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgICAgICAgICAgaWYgKFtTeXN0ZW0uSU8uRmls
>> "%B64FILE%" echo ZV06OkdldEF0dHJpYnV0ZXMoJHN1YikgLWJhbmQgW1N5c3RlbS5JTy5GaWxlQXR0cmlidXRlc106
>> "%B64FILE%" echo OlJlcGFyc2VQb2ludCkgeyBjb250aW51ZSB9DQogICAgICAgICAgICAgICAgICAgIH0gY2F0Y2gg
>> "%B64FILE%" echo eyBjb250aW51ZSB9DQogICAgICAgICAgICAgICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoJHN1Yiwg
>> "%B64FILE%" echo KCRkICsgMSkpKQ0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAg
>> "%B64FILE%" echo ICAgICAgfQ0KICAgIH0NCiAgICByZXR1cm4gJGZvdW5kLlRvQXJyYXkoKQ0KfQ0KDQpXcml0ZS1I
>> "%B64FILE%" echo b3N0ICcnDQpXcml0ZS1Ib3N0ICfkv67lpb3lkK/liqjoj5zljZXmjIflkJEgLSDkvZzogIXvvJpj
>> "%B64FILE%" echo b25uZWN0c2VnYWJvdCcNCldyaXRlLUhvc3QgJz09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09Jw0KV3JpdGUtSG9zdCAnJw0KDQppZiAoLW5vdCAoVGVzdC1BZG1pbikpIHsNCiAg
>> "%B64FILE%" echo ICBXcml0ZS1Ib3N0ICfpnIDopoHnrqHnkIblkZjmnYPpmZDjgIInIC1Gb3JlZ3JvdW5kQ29sb3Ig
>> "%B64FILE%" echo UmVkDQogICAgV3JpdGUtSG9zdCAn6K+35YWz5o6J6L+Z5Liq56qX5Y+j77yM55u05o6l5Y+M5Ye7
>> "%B64FILE%" echo 44CM5L+u5aW96I+c5Y2V5oyH5ZCRLeeuoeeQhuWRmOi/kOihjC5iYXTjgI3vvIzlroPkvJroh6rl
>> "%B64FILE%" echo t7HnlLPor7fmnYPpmZDjgIInDQogICAgV3JpdGUtSG9zdCAnJw0KICAgIFdyaXRlLUhvc3QgJ+aM
>> "%B64FILE%" echo ieS7u+aEj+mUrumAgOWHui4uLicNCiAgICAkbnVsbCA9ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXko
>> "%B64FILE%" echo J05vRWNobyxJbmNsdWRlS2V5RG93bicpDQogICAgcmV0dXJuDQp9DQoNCldyaXRlLUxvZyAi5pel
>> "%B64FILE%" echo 5b+XOiAkKCRTY3JpcHQ6TG9nRmlsZSkiDQoNCiMgLS0tLS0tLS0tLSDlhYjlpIfku73mtLvliqgg
>> "%B64FILE%" echo QkNEIC0tLS0tLS0tLS0NCiRzdGFtcCA9IEdldC1EYXRlIC1Gb3JtYXQgJ3l5eXlNTWRkLUhIbW1z
>> "%B64FILE%" echo cycNCiRiayA9IEpvaW4tUGF0aCAkZW52OlRFTVAgImJjZC1iYWNrdXAtJHN0YW1wLmJjZCINCiRy
>> "%B64FILE%" echo YiA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2V4cG9ydCcsICRiaykgLVRhZyAnZXhwb3J0Jw0K
>> "%B64FILE%" echo aWYgKCRyYi5PayAtYW5kIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRiaykpIHsNCiAgICBXcml0
>> "%B64FILE%" echo ZS1Mb2cgIkJDRCDlt7LlpIfku706ICRiayIgJ09LJw0KfSBlbHNlIHsNCiAgICBXcml0ZS1Mb2cg
>> "%B64FILE%" echo J0JDRCDlpIfku73lpLHotKXvvIznu6fnu63vvIjkuIvpnaLlj6rmlLnorr7lpIfot6/lvoTlkozo
>> "%B64FILE%" echo j5zljZXpobrluo/vvIzpo47pmanlvojkvY7vvIknICdXQVJOJw0KfQ0KDQojIC0tLS0tLS0tLS0g
>> "%B64FILE%" echo 5om+55uu5qCHIC0tLS0tLS0tLS0NCldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgJ+ato+WcqOaf
>> "%B64FILE%" echo peaJvuijheWlveeahOiZmuaLn+ezu+e7ny4uLicNCiRpdGVtcyA9IE5ldy1PYmplY3QgU3lzdGVt
>> "%B64FILE%" echo LkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KZm9yZWFjaCAoJGYgaW4gQChHZXQtQWxsVmhkeEZpbGUp
>> "%B64FILE%" echo KSB7DQogICAgJHN0ID0gW1N5c3RlbS5JTy5QYXRoXTo6Q2hhbmdlRXh0ZW5zaW9uKCRmLkZ1bGxO
>> "%B64FILE%" echo YW1lLCAnLmJvb3QudHh0JykNCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAk
>> "%B64FILE%" echo c3QpKSB7IGNvbnRpbnVlIH0NCiAgICAkc2QgPSBAe30NCiAgICBmb3JlYWNoICgkbG4gaW4gKEdl
>> "%B64FILE%" echo dC1Db250ZW50IC1MaXRlcmFsUGF0aCAkc3QgLUVuY29kaW5nIFVURjggLUVBIFNpbGVudGx5Q29u
>> "%B64FILE%" echo dGludWUpKSB7DQogICAgICAgIGlmICgkbG4gLW1hdGNoICdeXHMqKFteIz1dKyk9KC4qKSQnKSB7
>> "%B64FILE%" echo ICRzZFskbWF0Y2hlc1sxXS5UcmltKCldID0gJG1hdGNoZXNbMl0uVHJpbSgpIH0NCiAgICB9DQog
>> "%B64FILE%" echo ICAgJGcgPSBbc3RyaW5nXSRzZFsnR3VpZCddDQogICAgaWYgKCRnIC1ub3RtYXRjaCAnXlx7WzAt
>> "%B64FILE%" echo OWEtZkEtRi1dezM2fVx9JCcpIHsgY29udGludWUgfQ0KICAgIFt2b2lkXSRpdGVtcy5BZGQoW1BT
>> "%B64FILE%" echo Q3VzdG9tT2JqZWN0XUB7DQogICAgICAgIFBhdGggID0gJGYuRnVsbE5hbWUNCiAgICAgICAgR3Vp
>> "%B64FILE%" echo ZCAgPSAkZw0KICAgICAgICBOYW1lICA9IFtzdHJpbmddJHNkWydOYW1lJ10NCiAgICAgICAgRGVz
>> "%B64FILE%" echo YyAgPSBbc3RyaW5nXSRzZFsnRGVzYyddDQogICAgICAgIFN0YXRlID0gJHN0DQogICAgfSkNCn0N
>> "%B64FILE%" echo Cg0KaWYgKCRpdGVtcy5Db3VudCAtZXEgMCkgew0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0
>> "%B64FILE%" echo ZS1Ib3N0ICfmsqHmib7liLDmnKzlt6Xlhbfoo4Xov4fnmoTomZrmi5/ns7vnu5/jgIInIC1Gb3Jl
>> "%B64FILE%" echo Z3JvdW5kQ29sb3IgWWVsbG93DQogICAgV3JpdGUtSG9zdCAn77yI6ZyA6KaB6Jma5ouf56OB55uY
>> "%B64FILE%" echo 5peB6L655pyJ5a6J6KOF5pe25YaZ55qEIHh4eC5ib290LnR4dO+8iScNCiAgICBXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICcnDQogICAgV3JpdGUtSG9zdCAn5aaC5p6c56Gu5a6e6KOF6L+H77yM5Y+v5Lul55So44CM5L+u
>> "%B64FILE%" echo 5aSN5ZCv5Yqo6I+c5Y2VLeeuoeeQhuWRmOi/kOihjC5iYXTjgI3ph43lu7rkuIDkuKrlkK/liqjp
>> "%B64FILE%" echo obnjgIInDQogICAgV3JpdGUtSG9zdCAnJw0KICAgIFdyaXRlLUhvc3QgJ+aMieS7u+aEj+mUrumA
>> "%B64FILE%" echo gOWHui4uLicNCiAgICAkbnVsbCA9ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXkoJ05vRWNobyxJbmNs
>> "%B64FILE%" echo dWRlS2V5RG93bicpDQogICAgcmV0dXJuDQp9DQoNCldyaXRlLUhvc3QgKCLmib7liLAgezB9IOS4
>> "%B64FILE%" echo qu+8miIgLWYgJGl0ZW1zLkNvdW50KQ0KZm9yZWFjaCAoJHggaW4gJGl0ZW1zKSB7IFdyaXRlLUhv
>> "%B64FILE%" echo c3QgKCIgICAgezB9IiAtZiAkeC5QYXRoKSB9DQoNCiMgLS0tLS0tLS0tLSDpgJDkuKrmoLjlr7kg
>> "%B64FILE%" echo LS0tLS0tLS0tLQ0KJGZpeGVkQ291bnQgPSAwDQokb2tDb3VudCA9IDANCiRmYWlsQ291bnQgPSAw
>> "%B64FILE%" echo DQoNCmZvcmVhY2ggKCRpdCBpbiAkaXRlbXMpIHsNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3Jp
>> "%B64FILE%" echo dGUtSG9zdCAoIsK3IHswfSIgLWYgJGl0LlBhdGgpIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbg0KDQog
>> "%B64FILE%" echo ICAgJHdhbnREZXYgPSAnJw0KICAgIHRyeSB7ICR3YW50RGV2ID0gR2V0LVZoZEJjZERldmljZSAk
>> "%B64FILE%" echo aXQuUGF0aCB9DQogICAgY2F0Y2ggeyBXcml0ZS1Mb2cgIui3r+W+hOaXoOaViDogJCgkXy5FeGNl
>> "%B64FILE%" echo cHRpb24uTWVzc2FnZSkiICdFUlInOyAkZmFpbENvdW50Kys7IGNvbnRpbnVlIH0NCiAgICAkd2Fu
>> "%B64FILE%" echo dEZ1bGwgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGdWxsUGF0aCgkaXQuUGF0aCkNCg0KICAgICRl
>> "%B64FILE%" echo biA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2VudW0nLCAkaXQuR3VpZCkgLVRhZyAnZW51bScN
>> "%B64FILE%" echo CiAgICAkZ3VpZCA9ICRpdC5HdWlkDQoNCiAgICAjIOadoeebruS4jeWtmOWcqCDihpIg6KGl5LiA
>> "%B64FILE%" echo 5p2hDQogICAgaWYgKC1ub3QgJGVuLk9rKSB7DQogICAgICAgIFdyaXRlLUxvZyAi6I+c5Y2V6YeM
>> "%B64FILE%" echo 5rKh5pyJ6L+Z5Liq5p2h55uu77yIJGd1aWTvvInvvIzooaXkuIDmnaEiICdXQVJOJw0KICAgICAg
>> "%B64FILE%" echo ICAkZGVzYyA9ICRpdC5EZXNjDQogICAgICAgIGlmICgtbm90ICRkZXNjKSB7ICRkZXNjID0gJGl0
>> "%B64FILE%" echo Lk5hbWUgfQ0KICAgICAgICBpZiAoLW5vdCAkZGVzYykgeyAkZGVzYyA9IFtTeXN0ZW0uSU8uUGF0
>> "%B64FILE%" echo aF06OkdldEZpbGVOYW1lV2l0aG91dEV4dGVuc2lvbigkaXQuUGF0aCkgfQ0KDQogICAgICAgICRj
>> "%B64FILE%" echo cCA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2NvcHknLCAne2N1cnJlbnR9JywgJy9kJywgJGRl
>> "%B64FILE%" echo c2MpIC1UYWcgJ2NvcHknDQogICAgICAgIGlmICgtbm90ICRjcC5PaykgeyAkY3AgPSBJbnZva2Ut
>> "%B64FILE%" echo QmNkIC1CY2RBcmdzIEAoJy9jb3B5JywgJ3tkZWZhdWx0fScsICcvZCcsICRkZXNjKSAtVGFnICdj
>> "%B64FILE%" echo b3B5LWRlZmF1bHQnIH0NCiAgICAgICAgJGdtID0gW3JlZ2V4XTo6TWF0Y2goJGNwLlJhdywgJ1x7
>> "%B64FILE%" echo WzAtOWEtZkEtRl17OH0tWzAtOWEtZkEtRl17NH0tWzAtOWEtZkEtRl17NH0tWzAtOWEtZkEtRl17
>> "%B64FILE%" echo NH0tWzAtOWEtZkEtRl17MTJ9XH0nKQ0KICAgICAgICBpZiAoLW5vdCAkZ20uU3VjY2Vzcykgew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgV3JpdGUtTG9nICLooaXmnaHnm67lpLHotKXvvJokKCRjcC5UZXh0KSIgJ0VS
>> "%B64FILE%" echo UicNCiAgICAgICAgICAgICRmYWlsQ291bnQrKw0KICAgICAgICAgICAgY29udGludWUNCiAgICAg
>> "%B64FILE%" echo ICAgfQ0KICAgICAgICAkZ3VpZCA9ICRnbS5WYWx1ZQ0KICAgICAgICBbdm9pZF0oSW52b2tlLUJj
>> "%B64FILE%" echo ZCAtQmNkQXJncyBAKCcvc2V0JywgJGd1aWQsICdkZXZpY2UnLCAgICR3YW50RGV2KSAtVGFnICdz
>> "%B64FILE%" echo ZXQtZGV2aWNlJykNCiAgICAgICAgW3ZvaWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcs
>> "%B64FILE%" echo ICRndWlkLCAnb3NkZXZpY2UnLCAkd2FudERldikgLVRhZyAnc2V0LW9zZGV2aWNlJykNCiAgICAg
>> "%B64FILE%" echo ICAgW3ZvaWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAncGF0aCcsICdc
>> "%B64FILE%" echo V2luZG93c1xzeXN0ZW0zMlx3aW5sb2FkLmVmaScpIC1UYWcgJ3NldC1wYXRoJykNCg0KICAgICAg
>> "%B64FILE%" echo ICAjIOeKtuaAgeaWh+S7tumHjOeahCBHVUlEIOaNouaIkOaWsOeahO+8jOWNuOi9veaXtuaJjeaJ
>> "%B64FILE%" echo vuW+l+WIsA0KICAgICAgICB0cnkgew0KICAgICAgICAgICAgJHR4dCA9IFtTeXN0ZW0uSU8uRmls
>> "%B64FILE%" echo ZV06OlJlYWRBbGxUZXh0KCRpdC5TdGF0ZSwgW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6VVRGOCkN
>> "%B64FILE%" echo CiAgICAgICAgICAgICR0eHQgPSBbcmVnZXhdOjpSZXBsYWNlKCR0eHQsICcoP20pXkd1aWQ9Lion
>> "%B64FILE%" echo LCAiR3VpZD0kZ3VpZCIpDQogICAgICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRl
>> "%B64FILE%" echo eHQoJGl0LlN0YXRlLCAkdHh0LCAoTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2Rpbmco
>> "%B64FILE%" echo JHRydWUpKSkNCiAgICAgICAgICAgIFdyaXRlLUxvZyAi54q25oCB5paH5Lu25bey5pu05paw5Li6
>> "%B64FILE%" echo 5pawIEdVSUQiICdPSycNCiAgICAgICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAi5YaZ54q25oCB5paH
>> "%B64FILE%" echo 5Lu25aSx6LSl77yI5LiN5b2x5ZON5byA5py677yJ77yaJCgkXy5FeGNlcHRpb24uTWVzc2FnZSki
>> "%B64FILE%" echo ICdXQVJOJyB9DQoNCiAgICAgICAgJGVuID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZW51bScs
>> "%B64FILE%" echo ICRndWlkKSAtVGFnICd2ZXJpZnknDQogICAgICAgICRmaXhlZENvdW50KysNCiAgICB9DQoNCiAg
>> "%B64FILE%" echo ICAjIOaguOWvuSBkZXZpY2Ug5oyH5ZCR55qE6Lev5b6EDQogICAgJGRtID0gW3JlZ2V4XTo6TWF0
>> "%B64FILE%" echo Y2goJGVuLlJhdywgJyg/aW0pXlxzKig/OmRldmljZXzorr7lpIcpXHMrKFxTLio/KVxzKiQnKQ0K
>> "%B64FILE%" echo ICAgICRjdXJEZXYgPSAnJw0KICAgIGlmICgkZG0uU3VjY2VzcykgeyAkY3VyRGV2ID0gJGRtLkdy
>> "%B64FILE%" echo b3Vwc1sxXS5WYWx1ZS5UcmltKCkgfQ0KICAgICRjdXJGdWxsID0gR2V0LUZ1bGxQYXRoRnJvbUJj
>> "%B64FILE%" echo ZERldmljZSAkY3VyRGV2DQoNCiAgICBpZiAoJGN1ckZ1bGwgLWVxICR3YW50RnVsbCkgew0KICAg
>> "%B64FILE%" echo ICAgICBXcml0ZS1Mb2cgIuaMh+WQkeato+ehru+8miRjdXJEZXYiICdPSycNCiAgICAgICAgJG9r
>> "%B64FILE%" echo Q291bnQrKw0KICAgIH0gZWxzZSB7DQogICAgICAgIFdyaXRlLUxvZyAoIuaMh+WQkeS4jeWvueOA
>> "%B64FILE%" echo gueOsOWcqOaYryBbezB9Xe+8jOW6lOivpeaYryBbezF9XSIgLWYgJGN1ckRldiwgJHdhbnREZXYp
>> "%B64FILE%" echo ICdXQVJOJw0KICAgICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0JywgJGd1
>> "%B64FILE%" echo aWQsICdkZXZpY2UnLCAgICR3YW50RGV2KSAtVGFnICdmaXgtZGV2aWNlJykNCiAgICAgICAgW3Zv
>> "%B64FILE%" echo aWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAnb3NkZXZpY2UnLCAkd2Fu
>> "%B64FILE%" echo dERldikgLVRhZyAnZml4LW9zZGV2aWNlJykNCiAgICAgICAgJGNoayA9IEludm9rZS1CY2QgLUJj
>> "%B64FILE%" echo ZEFyZ3MgQCgnL2VudW0nLCAkZ3VpZCkgLVRhZyAncmVjaGVjaycNCiAgICAgICAgJGRtMiA9IFty
>> "%B64FILE%" echo ZWdleF06Ok1hdGNoKCRjaGsuUmF3LCAnKD9pbSleXHMqKD86ZGV2aWNlfOiuvuWkhylccysoXFMu
>> "%B64FILE%" echo Kj8pXHMqJCcpDQogICAgICAgICRub3dEZXYgPSAnJw0KICAgICAgICBpZiAoJGRtMi5TdWNjZXNz
>> "%B64FILE%" echo KSB7ICRub3dEZXYgPSAkZG0yLkdyb3Vwc1sxXS5WYWx1ZS5UcmltKCkgfQ0KICAgICAgICAkbm93
>> "%B64FILE%" echo RnVsbCA9IEdldC1GdWxsUGF0aEZyb21CY2REZXZpY2UgJG5vd0Rldg0KICAgICAgICBpZiAoJG5v
>> "%B64FILE%" echo d0Z1bGwgLWVxICR3YW50RnVsbCkgew0KICAgICAgICAgICAgV3JpdGUtTG9nICLlt7LmlLnmraPv
>> "%B64FILE%" echo vJokbm93RGV2IiAnT0snDQogICAgICAgICAgICAkZml4ZWRDb3VudCsrDQogICAgICAgIH0gZWxz
>> "%B64FILE%" echo ZSB7DQogICAgICAgICAgICBXcml0ZS1Mb2cgKCLmlLnlrozov5jmmK/kuI3lr7nvvIznjrDlnKgg
>> "%B64FILE%" echo W3swfV0iIC1mICRub3dEZXYpICdFUlInDQogICAgICAgICAgICBXcml0ZS1Mb2cgJ+WkmuWNiuaY
>> "%B64FILE%" echo ryBiY2RlZGl0IOWkhOeQhuS4jeS6hui3r+W+hOmHjOeahOS4reaWh+OAguaKiuiZmuaLn+ejgeeb
>> "%B64FILE%" echo mOaMquWIsOe6r+iLseaWh+ebruW9le+8iOWmgiBEOlxWSETvvInlho3ph43mlrDoo4XkuIDmrKHm
>> "%B64FILE%" echo nIDnqLPjgIInICdFUlInDQogICAgICAgICAgICAkZmFpbENvdW50KysNCiAgICAgICAgICAgIGNv
>> "%B64FILE%" echo bnRpbnVlDQogICAgICAgIH0NCiAgICB9DQoNCiAgICAjIOehruS/neWug+i/m+S6huW8gOacuuiP
>> "%B64FILE%" echo nOWNleeahOaYvuekuumhuuW6jw0KICAgICRibSA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2Vu
>> "%B64FILE%" echo dW0nLCAne2Jvb3RtZ3J9JykgLVRhZyAnYm9vdG1ncicNCiAgICAkb20gPSBbcmVnZXhdOjpNYXRj
>> "%B64FILE%" echo aCgkYm0uUmF3LCAnKD9pbSleXHMqKD86ZGlzcGxheW9yZGVyfOaYvuekuumhuuW6jylccysoLis/
>> "%B64FILE%" echo KVxzKiQnKQ0KICAgICRvcmRlciA9ICcnDQogICAgaWYgKCRvbS5TdWNjZXNzKSB7ICRvcmRlciA9
>> "%B64FILE%" echo ICRvbS5Hcm91cHNbMV0uVmFsdWUgfQ0KDQogICAgaWYgKCRvcmRlciAtbm90bWF0Y2ggW3JlZ2V4
>> "%B64FILE%" echo XTo6RXNjYXBlKCRndWlkKSkgew0KICAgICAgICAkYWQgPSBJbnZva2UtQmNkIC1CY2RBcmdzIEAo
>> "%B64FILE%" echo Jy9kaXNwbGF5b3JkZXInLCAkZ3VpZCwgJy9hZGRsYXN0JykgLVRhZyAnZGlzcGxheW9yZGVyJw0K
>> "%B64FILE%" echo ICAgICAgICBpZiAoJGFkLk9rKSB7DQogICAgICAgICAgICBXcml0ZS1Mb2cgJ+W3suWKoOWbnuW8
>> "%B64FILE%" echo gOacuuiPnOWNle+8iOaOkuWcqOacgOWQju+8iScgJ09LJw0KICAgICAgICAgICAgJGZpeGVkQ291
>> "%B64FILE%" echo bnQrKw0KICAgICAgICB9IGVsc2Ugew0KICAgICAgICAgICAgV3JpdGUtTG9nICLliqDlm57mmL7n
>> "%B64FILE%" echo pLrpobrluo/lpLHotKXvvJokKCRhZC5UZXh0KSIgJ0VSUicNCiAgICAgICAgICAgICRmYWlsQ291
>> "%B64FILE%" echo bnQrKw0KICAgICAgICB9DQogICAgICAgICRibSA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2Vu
>> "%B64FILE%" echo dW0nLCAne2Jvb3RtZ3J9JykgLVRhZyAnYm9vdG1ncjInDQogICAgICAgICRvbSA9IFtyZWdleF06
>> "%B64FILE%" echo Ok1hdGNoKCRibS5SYXcsICcoP2ltKV5ccyooPzpkaXNwbGF5b3JkZXJ85pi+56S66aG65bqPKVxz
>> "%B64FILE%" echo KyguKz8pXHMqJCcpDQogICAgICAgIGlmICgkb20uU3VjY2VzcykgeyAkb3JkZXIgPSAkb20uR3Jv
>> "%B64FILE%" echo dXBzWzFdLlZhbHVlIH0NCiAgICB9IGVsc2Ugew0KICAgICAgICBXcml0ZS1Mb2cgJ+aYvuekuumh
>> "%B64FILE%" echo uuW6j+mHjOacieWugycgJ09LJw0KICAgIH0NCg0KICAgICMg6I+c5Y2V5b6X5piv5omT5byA55qE
>> "%B64FILE%" echo 77yM5ZCm5YiZ5byA5py655u05o6l6L+b6buY6K6k57O757uf77yM55yL5LiN5Yiw6L+Z5Lqb6YCJ
>> "%B64FILE%" echo 6aG5DQogICAgJGVudHJ5Q291bnQgPSAoW3JlZ2V4XTo6TWF0Y2hlcygkb3JkZXIsICdceycpKS5D
>> "%B64FILE%" echo b3VudA0KICAgIGlmICgkZW50cnlDb3VudCAtZ2UgMikgew0KICAgICAgICAkZGJtID0gW3JlZ2V4
>> "%B64FILE%" echo XTo6TWF0Y2goJGJtLlJhdywgJyg/aW0pXlxzKig/OmRpc3BsYXlib290bWVudXzmmL7npLrlkK/l
>> "%B64FILE%" echo iqjoj5zljZUpXHMrKFxTKyknKQ0KICAgICAgICAkdG1vID0gW3JlZ2V4XTo6TWF0Y2goJGJtLlJh
>> "%B64FILE%" echo dywgJyg/aW0pXlxzKnRpbWVvdXRccysoXGQrKScpDQogICAgICAgICRuZWVkTWVudSA9ICRmYWxz
>> "%B64FILE%" echo ZQ0KICAgICAgICBpZiAoLW5vdCAkZGJtLlN1Y2Nlc3MpIHsgJG5lZWRNZW51ID0gJHRydWUgfQ0K
>> "%B64FILE%" echo ICAgICAgICBlbHNlaWYgKCRkYm0uR3JvdXBzWzFdLlZhbHVlIC1ub3RtYXRjaCAnXig/aTp5ZXMp
>> "%B64FILE%" echo JCcpIHsgJG5lZWRNZW51ID0gJHRydWUgfQ0KICAgICAgICAkbmVlZFRpbWVvdXQgPSAoJHRtby5T
>> "%B64FILE%" echo dWNjZXNzIC1hbmQgKFtpbnRdJHRtby5Hcm91cHNbMV0uVmFsdWUgLWVxIDApKQ0KDQogICAgICAg
>> "%B64FILE%" echo IGlmICgkbmVlZE1lbnUgLW9yICRuZWVkVGltZW91dCkgew0KICAgICAgICAgICAgW3ZvaWRdKElu
>> "%B64FILE%" echo dm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICd7Ym9vdG1ncn0nLCAnZGlzcGxheWJvb3RtZW51
>> "%B64FILE%" echo JywgJ1llcycpIC1UYWcgJ21lbnUtb24nKQ0KICAgICAgICAgICAgaWYgKCRuZWVkVGltZW91dCkg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgICAgIFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9zZXQnLCAn
>> "%B64FILE%" echo e2Jvb3RtZ3J9JywgJ3RpbWVvdXQnLCAnMTAnKSAtVGFnICd0aW1lb3V0LTEwJykNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIH0NCiAgICAgICAgICAgIFdyaXRlLUxvZyAn5byA5py66I+c5Y2V5bey5omT5byA77yI5LiN
>> "%B64FILE%" echo 54S25qC55pys55yL5LiN5Yiw6YCJ6aG577yJJyAnT0snDQogICAgICAgICAgICAkZml4ZWRDb3Vu
>> "%B64FILE%" echo dCsrDQogICAgICAgIH0NCiAgICB9DQp9DQoNCiMgLS0tLS0tLS0tLSDnu5PorrogLS0tLS0tLS0t
>> "%B64FILE%" echo LQ0KV3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAnPT09PT09PT09PT09PT09PSDnu5PmnpwgPT09
>> "%B64FILE%" echo PT09PT09PT09PT09PScNCldyaXRlLUhvc3QgKCIgIOacrOadpeWwseWvue+8mnswfSDkuKoiIC1m
>> "%B64FILE%" echo ICRva0NvdW50KQ0KV3JpdGUtSG9zdCAoIiAg5bey5L+u5aW9ICDvvJp7MH0g5aSEIiAtZiAkZml4
>> "%B64FILE%" echo ZWRDb3VudCkgLUZvcmVncm91bmRDb2xvciBHcmVlbg0KV3JpdGUtSG9zdCAoIiAg5rKh5L+u5aW9
>> "%B64FILE%" echo ICDvvJp7MH0g5LiqIiAtZiAkZmFpbENvdW50KSAtRm9yZWdyb3VuZENvbG9yICQoaWYgKCRmYWls
>> "%B64FILE%" echo Q291bnQgLWd0IDApIHsgJ1JlZCcgfSBlbHNlIHsgJ0dyYXknIH0pDQpXcml0ZS1Ib3N0ICcnDQpp
>> "%B64FILE%" echo ZiAoJGZpeGVkQ291bnQgLWd0IDApIHsNCiAgICBXcml0ZS1Ib3N0ICfph43lkK/nlLXohJHvvIzl
>> "%B64FILE%" echo vIDmnLroj5zljZXph4zlupTor6XlsLHog73nnIvliLDlubbov5vlhaXov5nkupvns7vnu5/kuobj
>> "%B64FILE%" echo gIInIC1Gb3JlZ3JvdW5kQ29sb3IgR3JlZW4NCn0gZWxzZWlmICgkZmFpbENvdW50IC1lcSAwIC1h
>> "%B64FILE%" echo bmQgJG9rQ291bnQgLWd0IDApIHsNCiAgICBXcml0ZS1Ib3N0ICfoj5zljZXmjIflkJHpg73mmK/l
>> "%B64FILE%" echo r7nnmoTvvIzkuI3nlKjkv67jgILlpoLmnpzlvIDmnLrov5jmmK/nnIvkuI3liLDoj5zljZXvvIwn
>> "%B64FILE%" echo DQogICAgV3JpdGUtSG9zdCAn5Y+v6IO95piv5Zu65Lu25rKh5LuO6L+Z5Z2X55uY55qEIEVTUCDl
>> "%B64FILE%" echo kK/liqjvvIzmiJbmmK/oj5zljZXotoXml7blpKrnn63vvIzov57mjInmlrnlkJHplK7or5Xor5Xj
>> "%B64FILE%" echo gIInDQp9IGVsc2Ugew0KICAgIFdyaXRlLUhvc3QgJ+acieayoeS/ruWlveeahOmhue+8jOaKiuS4
>> "%B64FILE%" echo i+mdoueahOaXpeW/l+WPkee7meaIkeeci+eci+OAgicgLUZvcmVncm91bmRDb2xvciBZZWxsb3cN
>> "%B64FILE%" echo Cn0NCldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgKCLml6Xlv5fvvJp7MH0iIC1mICRTY3JpcHQ6
>> "%B64FILE%" echo TG9nRmlsZSkNCldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgJ+aMieS7u+aEj+mUrumAgOWHui4u
>> "%B64FILE%" echo LicNCiRudWxsID0gJEhvc3QuVUkuUmF3VUkuUmVhZEtleSgnTm9FY2hvLEluY2x1ZGVLZXlEb3du
>> "%B64FILE%" echo JykNCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=13855"
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
