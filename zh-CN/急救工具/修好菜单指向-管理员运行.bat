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
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '%*' } catch { exit 9 }"
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
>> "%B64FILE%" echo cnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjMyJw0K
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
>> "%B64FILE%" echo ZSA9ICRjb2RlOyBUZXh0ID0gJGNsZWFuOyBSYXcgPSAkdHh0IH0NCn0NCg0KIyBiY2RlZGl0IOea
>> "%B64FILE%" echo hOi+k+WHuui1sOaOp+WItuWPsOS7o+eggemhte+8jOaJk+S4jeWHuuadpeeahOWtl+S8muWPmOaI
>> "%B64FILE%" echo kCAiPyLjgILoi7HmloflkK/liqjlmajlvIDlpLTmmK8gY2hjcCA0MzfvvIwNCiMg5Lit5paH6Lev
>> "%B64FILE%" echo 5b6E5LqO5piv5pW05Liq5Y+Y5oiQICI/Iu+8jOWGmeWvueS6huS5n+iiq+WIpOaIkOWGmemUmeOA
>> "%B64FILE%" echo gg0KZnVuY3Rpb24gVGVzdC1CY2RUZXh0U2FtZSB7DQogICAgcGFyYW0oW3N0cmluZ10kV2FudCwg
>> "%B64FILE%" echo W3N0cmluZ10kR290KQ0KICAgIGlmICgkbnVsbCAtZXEgJEdvdCkgeyByZXR1cm4gJGZhbHNlIH0N
>> "%B64FILE%" echo CiAgICBpZiAoJEdvdCAtZXEgJFdhbnQpIHsgcmV0dXJuICR0cnVlIH0NCiAgICBpZiAoJEdvdC5M
>> "%B64FILE%" echo ZW5ndGggLW5lICRXYW50Lkxlbmd0aCkgeyByZXR1cm4gJGZhbHNlIH0NCiAgICBmb3IgKCRpID0g
>> "%B64FILE%" echo MDsgJGkgLWx0ICRXYW50Lkxlbmd0aDsgJGkrKykgew0KICAgICAgICBpZiAoJEdvdFskaV0gLWVx
>> "%B64FILE%" echo ICRXYW50WyRpXSkgeyBjb250aW51ZSB9DQogICAgICAgIGlmICgkR290WyRpXSAtZXEgJz8nIC1h
>> "%B64FILE%" echo bmQgW2ludF1bY2hhcl0kV2FudFskaV0gLWd0IDEyNykgeyBjb250aW51ZSB9DQogICAgICAgIHJl
>> "%B64FILE%" echo dHVybiAkZmFsc2UNCiAgICB9DQogICAgcmV0dXJuICR0cnVlDQp9DQoNCiMg5a6M5pW06Lev5b6E
>> "%B64FILE%" echo IC0+IEJDRCDnmoQgdmhkPSDlhpnms5XjgILlv4Xpobvkv53nlZnkuK3pl7TlrZDnm67lvZXvvJoN
>> "%B64FILE%" echo CiMgICBEOlzomZrmi5/no4Hnm5hcbWFpbWFpLnZoZHggIC0+ICB2aGQ9W0Q6XVzomZrmi5/no4Hn
>> "%B64FILE%" echo m5hcbWFpbWFpLnZoZHgNCmZ1bmN0aW9uIEdldC1WaGRCY2REZXZpY2Ugew0KICAgIHBhcmFtKFtz
>> "%B64FILE%" echo dHJpbmddJEZ1bGxQYXRoKQ0KICAgICRmdWxsID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0RnVsbFBh
>> "%B64FILE%" echo dGgoJEZ1bGxQYXRoKQ0KICAgICRyb290ID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0UGF0aFJvb3Qo
>> "%B64FILE%" echo JGZ1bGwpDQogICAgaWYgKC1ub3QgJHJvb3QgLW9yICRyb290Lkxlbmd0aCAtbHQgMykgeyB0aHJv
>> "%B64FILE%" echo dyAi6Lev5b6E5peg5pWI77yaJEZ1bGxQYXRoIiB9DQogICAgJGxldHRlciA9ICRyb290LlN1YnN0
>> "%B64FILE%" echo cmluZygwLCAxKS5Ub1VwcGVyKCkNCiAgICAkcmVsID0gJGZ1bGwuU3Vic3RyaW5nKCRyb290Lkxl
>> "%B64FILE%" echo bmd0aCkuVHJpbVN0YXJ0KCdcJykNCiAgICBpZiAoLW5vdCAkcmVsKSB7IHRocm93ICLot6/lvoTm
>> "%B64FILE%" echo l6DmlYjvvJokRnVsbFBhdGgiIH0NCiAgICByZXR1cm4gInZoZD1bJCgkbGV0dGVyKTpdXCRyZWwi
>> "%B64FILE%" echo DQp9DQoNCiMg5Y+N5ZCR6Kej5p6Q77yM55So5p2l6Lef55yf5a6e6Lev5b6E6YCQ5a2X5q+U5a+5
>> "%B64FILE%" echo DQpmdW5jdGlvbiBHZXQtRnVsbFBhdGhGcm9tQmNkRGV2aWNlIHsNCiAgICBwYXJhbShbc3RyaW5n
>> "%B64FILE%" echo XSREZXYpDQogICAgaWYgKC1ub3QgJERldikgeyByZXR1cm4gJycgfQ0KICAgICRtID0gW3JlZ2V4
>> "%B64FILE%" echo XTo6TWF0Y2goJERldiwgJ152aGQ9XFsoW0EtWmEtel0pOlxdXFwoLispJCcpDQogICAgaWYgKC1u
>> "%B64FILE%" echo b3QgJG0uU3VjY2VzcykgeyByZXR1cm4gJycgfQ0KICAgIHJldHVybiAoInswfTpcezF9IiAtZiAk
>> "%B64FILE%" echo bS5Hcm91cHNbMV0uVmFsdWUuVG9VcHBlcigpLCAkbS5Hcm91cHNbMl0uVmFsdWUpDQp9DQoNCiMg
>> "%B64FILE%" echo 5omr5omA5pyJ5Zu65a6aIE5URlMg55uY6YeM55qEIHZoZHjjgILlub/luqbkvJjlhYggKyDmjInn
>> "%B64FILE%" echo m67lvZXlkI3liarmnp3vvIwNCiMg5LiN6L+bIFdpbmRvd3MgLyBVc2VycyAvIOWbnuaUtuerme+8
>> "%B64FILE%" echo jOaJgOS7pea3seW6puW8gOWIsCA2IOS5n+S4jeaFouOAgg0KZnVuY3Rpb24gR2V0LUFsbFZoZHhG
>> "%B64FILE%" echo aWxlIHsNCiAgICBwYXJhbShbaW50XSRNYXhEZXB0aCA9IDYpDQogICAgJHNraXAgPSBAKCckUkVD
>> "%B64FILE%" echo WUNMRS5CSU4nLCAnU3lzdGVtIFZvbHVtZSBJbmZvcm1hdGlvbicsICdXaW5kb3dzJywgJ1Byb2dy
>> "%B64FILE%" echo YW0gRmlsZXMnLA0KICAgICAgICAgICAgICAnUHJvZ3JhbSBGaWxlcyAoeDg2KScsICdQcm9ncmFt
>> "%B64FILE%" echo RGF0YScsICdVc2VycycsICckV2luUkVBZ2VudCcsICdSZWNvdmVyeScsDQogICAgICAgICAgICAg
>> "%B64FILE%" echo ICdub2RlX21vZHVsZXMnLCAnLmdpdCcsICdXaW5TeFMnKQ0KICAgICRmb3VuZCA9IE5ldy1PYmpl
>> "%B64FILE%" echo Y3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0
>> "%B64FILE%" echo LVZvbHVtZSAtRUEgU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJp
>> "%B64FILE%" echo dmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRmlsZVN5c3RlbSAtbmUgJ05U
>> "%B64FILE%" echo RlMnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgaWYgKCR2LkRyaXZlVHlwZSAtbmUgJ0ZpeGVkJykg
>> "%B64FILE%" echo eyBjb250aW51ZSB9DQogICAgICAgICRxdWV1ZSA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rp
>> "%B64FILE%" echo b25zLlF1ZXVlDQogICAgICAgICRxdWV1ZS5FbnF1ZXVlKEAoIiQoJHYuRHJpdmVMZXR0ZXIpOlwi
>> "%B64FILE%" echo LCAwKSkNCiAgICAgICAgd2hpbGUgKCRxdWV1ZS5Db3VudCAtZ3QgMCkgew0KICAgICAgICAgICAg
>> "%B64FILE%" echo JGN1ciA9ICRxdWV1ZS5EZXF1ZXVlKCkNCiAgICAgICAgICAgICRkaXIgPSBbc3RyaW5nXSRjdXJb
>> "%B64FILE%" echo MF0NCiAgICAgICAgICAgICRkID0gW2ludF0kY3VyWzFdDQogICAgICAgICAgICB0cnkgew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgIGZvcmVhY2ggKCRmIGluIFtTeXN0ZW0uSU8uRGlyZWN0b3J5XTo6R2V0Rmls
>> "%B64FILE%" echo ZXMoJGRpciwgJyoudmhkeCcpKSB7DQogICAgICAgICAgICAgICAgICAgIFt2b2lkXSRmb3VuZC5B
>> "%B64FILE%" echo ZGQoKE5ldy1PYmplY3QgU3lzdGVtLklPLkZpbGVJbmZvICRmKSkNCiAgICAgICAgICAgICAgICB9
>> "%B64FILE%" echo DQogICAgICAgICAgICB9IGNhdGNoIHt9DQogICAgICAgICAgICBpZiAoJGQgLWdlICRNYXhEZXB0
>> "%B64FILE%" echo aCkgeyBjb250aW51ZSB9DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgIGZvcmVh
>> "%B64FILE%" echo Y2ggKCRzdWIgaW4gW1N5c3RlbS5JTy5EaXJlY3RvcnldOjpFbnVtZXJhdGVEaXJlY3Rvcmllcygk
>> "%B64FILE%" echo ZGlyKSkgew0KICAgICAgICAgICAgICAgICAgICBpZiAoJHNraXAgLWNvbnRhaW5zIFtTeXN0ZW0u
>> "%B64FILE%" echo SU8uUGF0aF06OkdldEZpbGVOYW1lKCRzdWIpKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICAgICAgICAgIGlmIChbU3lzdGVtLklPLkZpbGVd
>> "%B64FILE%" echo OjpHZXRBdHRyaWJ1dGVzKCRzdWIpIC1iYW5kIFtTeXN0ZW0uSU8uRmlsZUF0dHJpYnV0ZXNdOjpS
>> "%B64FILE%" echo ZXBhcnNlUG9pbnQpIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB9IGNhdGNoIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICAkcXVldWUuRW5xdWV1ZShAKCRzdWIsICgk
>> "%B64FILE%" echo ZCArIDEpKSkNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9IGNhdGNoIHt9DQogICAg
>> "%B64FILE%" echo ICAgIH0NCiAgICB9DQogICAgcmV0dXJuICRmb3VuZC5Ub0FycmF5KCkNCn0NCg0KV3JpdGUtSG9z
>> "%B64FILE%" echo dCAnJw0KV3JpdGUtSG9zdCAn5L+u5aW95ZCv5Yqo6I+c5Y2V5oyH5ZCRIC0g5L2c6ICF77yaY29u
>> "%B64FILE%" echo bmVjdHNlZ2Fib3QnDQpXcml0ZS1Ib3N0ICc9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PScNCldyaXRlLUhvc3QgJycNCg0KaWYgKC1ub3QgKFRlc3QtQWRtaW4pKSB7DQogICAg
>> "%B64FILE%" echo V3JpdGUtSG9zdCAn6ZyA6KaB566h55CG5ZGY5p2D6ZmQ44CCJyAtRm9yZWdyb3VuZENvbG9yIFJl
>> "%B64FILE%" echo ZA0KICAgIFdyaXRlLUhvc3QgJ+ivt+WFs+aOiei/meS4queql+WPo++8jOebtOaOpeWPjOWHu+OA
>> "%B64FILE%" echo jOS/ruWlveiPnOWNleaMh+WQkS3nrqHnkIblkZjov5DooYwuYmF044CN77yM5a6D5Lya6Ieq5bex
>> "%B64FILE%" echo 55Sz6K+35p2D6ZmQ44CCJw0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0ICfmjInk
>> "%B64FILE%" echo u7vmhI/plK7pgIDlh7ouLi4nDQogICAgJG51bGwgPSAkSG9zdC5VSS5SYXdVSS5SZWFkS2V5KCdO
>> "%B64FILE%" echo b0VjaG8sSW5jbHVkZUtleURvd24nKQ0KICAgIHJldHVybg0KfQ0KDQpXcml0ZS1Mb2cgIuaXpeW/
>> "%B64FILE%" echo lzogJCgkU2NyaXB0OkxvZ0ZpbGUpIg0KDQojIC0tLS0tLS0tLS0g5YWI5aSH5Lu95rS75YqoIEJD
>> "%B64FILE%" echo RCAtLS0tLS0tLS0tDQokc3RhbXAgPSBHZXQtRGF0ZSAtRm9ybWF0ICd5eXl5TU1kZC1ISG1tc3Mn
>> "%B64FILE%" echo DQokYmsgPSBKb2luLVBhdGggJGVudjpURU1QICJiY2QtYmFja3VwLSRzdGFtcC5iY2QiDQokcmIg
>> "%B64FILE%" echo PSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9leHBvcnQnLCAkYmspIC1UYWcgJ2V4cG9ydCcNCmlm
>> "%B64FILE%" echo ICgkcmIuT2sgLWFuZCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkYmspKSB7DQogICAgV3JpdGUt
>> "%B64FILE%" echo TG9nICJCQ0Qg5bey5aSH5Lu9OiAkYmsiICdPSycNCn0gZWxzZSB7DQogICAgV3JpdGUtTG9nICdC
>> "%B64FILE%" echo Q0Qg5aSH5Lu95aSx6LSl77yM57un57ut77yI5LiL6Z2i5Y+q5pS56K6+5aSH6Lev5b6E5ZKM6I+c
>> "%B64FILE%" echo 5Y2V6aG65bqP77yM6aOO6Zmp5b6I5L2O77yJJyAnV0FSTicNCn0NCg0KIyAtLS0tLS0tLS0tIOaJ
>> "%B64FILE%" echo vuebruaghyAtLS0tLS0tLS0tDQpXcml0ZS1Ib3N0ICcnDQpXcml0ZS1Ib3N0ICfmraPlnKjmn6Xm
>> "%B64FILE%" echo ib7oo4Xlpb3nmoTomZrmi5/ns7vnu58uLi4nDQokaXRlbXMgPSBOZXctT2JqZWN0IFN5c3RlbS5D
>> "%B64FILE%" echo b2xsZWN0aW9ucy5BcnJheUxpc3QNCmZvcmVhY2ggKCRmIGluIEAoR2V0LUFsbFZoZHhGaWxlKSkg
>> "%B64FILE%" echo ew0KICAgICRzdCA9IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVuc2lvbigkZi5GdWxsTmFt
>> "%B64FILE%" echo ZSwgJy5ib290LnR4dCcpDQogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0
>> "%B64FILE%" echo KSkgeyBjb250aW51ZSB9DQogICAgJHNkID0gQHt9DQogICAgZm9yZWFjaCAoJGxuIGluIChHZXQt
>> "%B64FILE%" echo Q29udGVudCAtTGl0ZXJhbFBhdGggJHN0IC1FbmNvZGluZyBVVEY4IC1FQSBTaWxlbnRseUNvbnRp
>> "%B64FILE%" echo bnVlKSkgew0KICAgICAgICBpZiAoJGxuIC1tYXRjaCAnXlxzKihbXiM9XSspPSguKikkJykgeyAk
>> "%B64FILE%" echo c2RbJG1hdGNoZXNbMV0uVHJpbSgpXSA9ICRtYXRjaGVzWzJdLlRyaW0oKSB9DQogICAgfQ0KICAg
>> "%B64FILE%" echo ICRnID0gW3N0cmluZ10kc2RbJ0d1aWQnXQ0KICAgIGlmICgkZyAtbm90bWF0Y2ggJ15ce1swLTlh
>> "%B64FILE%" echo LWZBLUYtXXszNn1cfSQnKSB7IGNvbnRpbnVlIH0NCiAgICBbdm9pZF0kaXRlbXMuQWRkKFtQU0N1
>> "%B64FILE%" echo c3RvbU9iamVjdF1Aew0KICAgICAgICBQYXRoICA9ICRmLkZ1bGxOYW1lDQogICAgICAgIEd1aWQg
>> "%B64FILE%" echo ID0gJGcNCiAgICAgICAgTmFtZSAgPSBbc3RyaW5nXSRzZFsnTmFtZSddDQogICAgICAgIERlc2Mg
>> "%B64FILE%" echo ID0gW3N0cmluZ10kc2RbJ0Rlc2MnXQ0KICAgICAgICBTdGF0ZSA9ICRzdA0KICAgIH0pDQp9DQoN
>> "%B64FILE%" echo CmlmICgkaXRlbXMuQ291bnQgLWVxIDApIHsNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUt
>> "%B64FILE%" echo SG9zdCAn5rKh5om+5Yiw5pys5bel5YW36KOF6L+H55qE6Jma5ouf57O757uf44CCJyAtRm9yZWdy
>> "%B64FILE%" echo b3VuZENvbG9yIFllbGxvdw0KICAgIFdyaXRlLUhvc3QgJ++8iOmcgOimgeiZmuaLn+ejgeebmOaX
>> "%B64FILE%" echo gei+ueacieWuieijheaXtuWGmeeahCB4eHguYm9vdC50eHTvvIknDQogICAgV3JpdGUtSG9zdCAn
>> "%B64FILE%" echo Jw0KICAgIFdyaXRlLUhvc3QgJ+WmguaenOehruWunuijhei/h++8jOWPr+S7peeUqOOAjOS/ruWk
>> "%B64FILE%" echo jeWQr+WKqOiPnOWNlS3nrqHnkIblkZjov5DooYwuYmF044CN6YeN5bu65LiA5Liq5ZCv5Yqo6aG5
>> "%B64FILE%" echo 44CCJw0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0ICfmjInku7vmhI/plK7pgIDl
>> "%B64FILE%" echo h7ouLi4nDQogICAgJG51bGwgPSAkSG9zdC5VSS5SYXdVSS5SZWFkS2V5KCdOb0VjaG8sSW5jbHVk
>> "%B64FILE%" echo ZUtleURvd24nKQ0KICAgIHJldHVybg0KfQ0KDQpXcml0ZS1Ib3N0ICgi5om+5YiwIHswfSDkuKrv
>> "%B64FILE%" echo vJoiIC1mICRpdGVtcy5Db3VudCkNCmZvcmVhY2ggKCR4IGluICRpdGVtcykgeyBXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICgiICAgIHswfSIgLWYgJHguUGF0aCkgfQ0KDQojIC0tLS0tLS0tLS0g6YCQ5Liq5qC45a+5IC0t
>> "%B64FILE%" echo LS0tLS0tLS0NCiRmaXhlZENvdW50ID0gMA0KJG9rQ291bnQgPSAwDQokZmFpbENvdW50ID0gMA0K
>> "%B64FILE%" echo DQpmb3JlYWNoICgkaXQgaW4gJGl0ZW1zKSB7DQogICAgV3JpdGUtSG9zdCAnJw0KICAgIFdyaXRl
>> "%B64FILE%" echo LUhvc3QgKCLCtyB7MH0iIC1mICRpdC5QYXRoKSAtRm9yZWdyb3VuZENvbG9yIEN5YW4NCg0KICAg
>> "%B64FILE%" echo ICR3YW50RGV2ID0gJycNCiAgICB0cnkgeyAkd2FudERldiA9IEdldC1WaGRCY2REZXZpY2UgJGl0
>> "%B64FILE%" echo LlBhdGggfQ0KICAgIGNhdGNoIHsgV3JpdGUtTG9nICLot6/lvoTml6DmlYg6ICQoJF8uRXhjZXB0
>> "%B64FILE%" echo aW9uLk1lc3NhZ2UpIiAnRVJSJzsgJGZhaWxDb3VudCsrOyBjb250aW51ZSB9DQogICAgJHdhbnRG
>> "%B64FILE%" echo dWxsID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0RnVsbFBhdGgoJGl0LlBhdGgpDQoNCiAgICAkZW4g
>> "%B64FILE%" echo PSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9lbnVtJywgJGl0Lkd1aWQpIC1UYWcgJ2VudW0nDQog
>> "%B64FILE%" echo ICAgJGd1aWQgPSAkaXQuR3VpZA0KDQogICAgIyDmnaHnm67kuI3lrZjlnKgg4oaSIOihpeS4gOad
>> "%B64FILE%" echo oQ0KICAgIGlmICgtbm90ICRlbi5Paykgew0KICAgICAgICBXcml0ZS1Mb2cgIuiPnOWNlemHjOay
>> "%B64FILE%" echo oeaciei/meS4quadoeebru+8iCRndWlk77yJ77yM6KGl5LiA5p2hIiAnV0FSTicNCiAgICAgICAg
>> "%B64FILE%" echo JGRlc2MgPSAkaXQuRGVzYw0KICAgICAgICBpZiAoLW5vdCAkZGVzYykgeyAkZGVzYyA9ICRpdC5O
>> "%B64FILE%" echo YW1lIH0NCiAgICAgICAgaWYgKC1ub3QgJGRlc2MpIHsgJGRlc2MgPSBbU3lzdGVtLklPLlBhdGhd
>> "%B64FILE%" echo OjpHZXRGaWxlTmFtZVdpdGhvdXRFeHRlbnNpb24oJGl0LlBhdGgpIH0NCg0KICAgICAgICAkY3Ag
>> "%B64FILE%" echo PSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9jb3B5JywgJ3tjdXJyZW50fScsICcvZCcsICRkZXNj
>> "%B64FILE%" echo KSAtVGFnICdjb3B5Jw0KICAgICAgICBpZiAoLW5vdCAkY3AuT2spIHsgJGNwID0gSW52b2tlLUJj
>> "%B64FILE%" echo ZCAtQmNkQXJncyBAKCcvY29weScsICd7ZGVmYXVsdH0nLCAnL2QnLCAkZGVzYykgLVRhZyAnY29w
>> "%B64FILE%" echo eS1kZWZhdWx0JyB9DQogICAgICAgICRnbSA9IFtyZWdleF06Ok1hdGNoKCRjcC5SYXcsICdce1sw
>> "%B64FILE%" echo LTlhLWZBLUZdezh9LVswLTlhLWZBLUZdezR9LVswLTlhLWZBLUZdezR9LVswLTlhLWZBLUZdezR9
>> "%B64FILE%" echo LVswLTlhLWZBLUZdezEyfVx9JykNCiAgICAgICAgaWYgKC1ub3QgJGdtLlN1Y2Nlc3MpIHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIFdyaXRlLUxvZyAi6KGl5p2h55uu5aSx6LSl77yaJCgkY3AuVGV4dCkiICdFUlIn
>> "%B64FILE%" echo DQogICAgICAgICAgICAkZmFpbENvdW50KysNCiAgICAgICAgICAgIGNvbnRpbnVlDQogICAgICAg
>> "%B64FILE%" echo IH0NCiAgICAgICAgJGd1aWQgPSAkZ20uVmFsdWUNCiAgICAgICAgW3ZvaWRdKEludm9rZS1CY2Qg
>> "%B64FILE%" echo LUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAnZGV2aWNlJywgICAkd2FudERldikgLVRhZyAnc2V0
>> "%B64FILE%" echo LWRldmljZScpDQogICAgICAgIFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9zZXQnLCAk
>> "%B64FILE%" echo Z3VpZCwgJ29zZGV2aWNlJywgJHdhbnREZXYpIC1UYWcgJ3NldC1vc2RldmljZScpDQogICAgICAg
>> "%B64FILE%" echo IFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9zZXQnLCAkZ3VpZCwgJ3BhdGgnLCAnXFdp
>> "%B64FILE%" echo bmRvd3Ncc3lzdGVtMzJcd2lubG9hZC5lZmknKSAtVGFnICdzZXQtcGF0aCcpDQoNCiAgICAgICAg
>> "%B64FILE%" echo IyDnirbmgIHmlofku7bph4znmoQgR1VJRCDmjaLmiJDmlrDnmoTvvIzljbjovb3ml7bmiY3mib7l
>> "%B64FILE%" echo vpfliLANCiAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICR0eHQgPSBbU3lzdGVtLklPLkZpbGVd
>> "%B64FILE%" echo OjpSZWFkQWxsVGV4dCgkaXQuU3RhdGUsIFtTeXN0ZW0uVGV4dC5FbmNvZGluZ106OlVURjgpDQog
>> "%B64FILE%" echo ICAgICAgICAgICAkdHh0ID0gW3JlZ2V4XTo6UmVwbGFjZSgkdHh0LCAnKD9tKV5HdWlkPS4qJywg
>> "%B64FILE%" echo Ikd1aWQ9JGd1aWQiKQ0KICAgICAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0
>> "%B64FILE%" echo KCRpdC5TdGF0ZSwgJHR4dCwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCR0
>> "%B64FILE%" echo cnVlKSkpDQogICAgICAgICAgICBXcml0ZS1Mb2cgIueKtuaAgeaWh+S7tuW3suabtOaWsOS4uuaW
>> "%B64FILE%" echo sCBHVUlEIiAnT0snDQogICAgICAgIH0gY2F0Y2ggeyBXcml0ZS1Mb2cgIuWGmeeKtuaAgeaWh+S7
>> "%B64FILE%" echo tuWksei0pe+8iOS4jeW9seWTjeW8gOacuu+8ie+8miQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIiAn
>> "%B64FILE%" echo V0FSTicgfQ0KDQogICAgICAgICRlbiA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2VudW0nLCAk
>> "%B64FILE%" echo Z3VpZCkgLVRhZyAndmVyaWZ5Jw0KICAgICAgICAkZml4ZWRDb3VudCsrDQogICAgfQ0KDQogICAg
>> "%B64FILE%" echo IyDmoLjlr7kgZGV2aWNlIOaMh+WQkeeahOi3r+W+hA0KICAgICMg5LiN5L6d6LWW5a2X5q615ZCN
>> "%B64FILE%" echo 77yI5b636K+tIEdlcsOkdOOAgeaXpeivrSDjg4fjg5DjgqTjgrnjgIHkuK3mlocg6K6+5aSH77yJ
>> "%B64FILE%" echo 77ya5bimIHZoZD0g55qE5Y+q5pyJIGRldmljZSDpgqPkuIDooYwNCiAgICAkZG0gPSBbcmVnZXhd
>> "%B64FILE%" echo OjpNYXRjaCgkZW4uUmF3LCAnKD9pbSleW15cclxuXSo/KHZoZD1cW1teXHJcbl0rKScpDQogICAg
>> "%B64FILE%" echo JGN1ckRldiA9ICcnDQogICAgaWYgKCRkbS5TdWNjZXNzKSB7ICRjdXJEZXYgPSAkZG0uR3JvdXBz
>> "%B64FILE%" echo WzFdLlZhbHVlLlRyaW0oKSB9DQogICAgJGN1ckZ1bGwgPSBHZXQtRnVsbFBhdGhGcm9tQmNkRGV2
>> "%B64FILE%" echo aWNlICRjdXJEZXYNCg0KICAgIGlmIChUZXN0LUJjZFRleHRTYW1lICR3YW50RnVsbCAkY3VyRnVs
>> "%B64FILE%" echo bCkgew0KICAgICAgICBXcml0ZS1Mb2cgIuaMh+WQkeato+ehru+8miRjdXJEZXYiICdPSycNCiAg
>> "%B64FILE%" echo ICAgICAgJG9rQ291bnQrKw0KICAgIH0gZWxzZSB7DQogICAgICAgIFdyaXRlLUxvZyAoIuaMh+WQ
>> "%B64FILE%" echo keS4jeWvueOAgueOsOWcqOaYryBbezB9Xe+8jOW6lOivpeaYryBbezF9XSIgLWYgJGN1ckRldiwg
>> "%B64FILE%" echo JHdhbnREZXYpICdXQVJOJw0KICAgICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcv
>> "%B64FILE%" echo c2V0JywgJGd1aWQsICdkZXZpY2UnLCAgICR3YW50RGV2KSAtVGFnICdmaXgtZGV2aWNlJykNCiAg
>> "%B64FILE%" echo ICAgICAgW3ZvaWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAnb3NkZXZp
>> "%B64FILE%" echo Y2UnLCAkd2FudERldikgLVRhZyAnZml4LW9zZGV2aWNlJykNCiAgICAgICAgJGNoayA9IEludm9r
>> "%B64FILE%" echo ZS1CY2QgLUJjZEFyZ3MgQCgnL2VudW0nLCAkZ3VpZCkgLVRhZyAncmVjaGVjaycNCiAgICAgICAg
>> "%B64FILE%" echo JGRtMiA9IFtyZWdleF06Ok1hdGNoKCRjaGsuUmF3LCAnKD9pbSleW15cclxuXSo/KHZoZD1cW1te
>> "%B64FILE%" echo XHJcbl0rKScpDQogICAgICAgICRub3dEZXYgPSAnJw0KICAgICAgICBpZiAoJGRtMi5TdWNjZXNz
>> "%B64FILE%" echo KSB7ICRub3dEZXYgPSAkZG0yLkdyb3Vwc1sxXS5WYWx1ZS5UcmltKCkgfQ0KICAgICAgICAkbm93
>> "%B64FILE%" echo RnVsbCA9IEdldC1GdWxsUGF0aEZyb21CY2REZXZpY2UgJG5vd0Rldg0KICAgICAgICBpZiAoVGVz
>> "%B64FILE%" echo dC1CY2RUZXh0U2FtZSAkd2FudEZ1bGwgJG5vd0Z1bGwpIHsNCiAgICAgICAgICAgIFdyaXRlLUxv
>> "%B64FILE%" echo ZyAi5bey5pS55q2j77yaJG5vd0RldiIgJ09LJw0KICAgICAgICAgICAgJGZpeGVkQ291bnQrKw0K
>> "%B64FILE%" echo ICAgICAgICB9IGVsc2Ugew0KICAgICAgICAgICAgV3JpdGUtTG9nICgi5pS55a6M6L+Y5piv5LiN
>> "%B64FILE%" echo 5a+577yM546w5ZyoIFt7MH1dIiAtZiAkbm93RGV2KSAnRVJSJw0KICAgICAgICAgICAgV3JpdGUt
>> "%B64FILE%" echo TG9nICflpoLmnpzpgqPph4zmmK/jgIw/44CN6ICM6Lev5b6E5pys5p2l5pyJ5Lit5paH77yM5Y+q
>> "%B64FILE%" echo 5piv5o6n5Yi25Y+w5Luj56CB6aG155qE5pi+56S66Zeu6aKY77ya5YWIIGNoY3AgOTM2IOWGjSBi
>> "%B64FILE%" echo Y2RlZGl0IC9lbnVtIOeci+S4gOecvOOAgicgJ0VSUicNCiAgICAgICAgICAgIFdyaXRlLUxvZyAn
>> "%B64FILE%" echo 5aaC5p6c56Gu5a6e5oyH5Yiw5Yir5aSE77yM5oqK6Jma5ouf56OB55uY5oyq5Yiw57qv6Iux5paH
>> "%B64FILE%" echo 55uu5b2V77yI5aaCIEQ6XFZIRO+8ieWGjemHjeaWsOijheS4gOasoeacgOeos+OAgicgJ0VSUicN
>> "%B64FILE%" echo CiAgICAgICAgICAgICRmYWlsQ291bnQrKw0KICAgICAgICAgICAgY29udGludWUNCiAgICAgICAg
>> "%B64FILE%" echo fQ0KICAgIH0NCg0KICAgICMg56Gu5L+d5a6D6L+b5LqG5byA5py66I+c5Y2V55qE5pi+56S66aG6
>> "%B64FILE%" echo 5bqPDQogICAgJGJtID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZW51bScsICd7Ym9vdG1ncn0n
>> "%B64FILE%" echo KSAtVGFnICdib290bWdyJw0KICAgICRvbSA9IFtyZWdleF06Ok1hdGNoKCRibS5SYXcsICcoP2lt
>> "%B64FILE%" echo KV5ccyooPzpkaXNwbGF5b3JkZXJ85pi+56S66aG65bqPKVxzKyguKz8pXHMqJCcpDQogICAgJG9y
>> "%B64FILE%" echo ZGVyID0gJycNCiAgICBpZiAoJG9tLlN1Y2Nlc3MpIHsgJG9yZGVyID0gJG9tLkdyb3Vwc1sxXS5W
>> "%B64FILE%" echo YWx1ZSB9DQoNCiAgICBpZiAoJG9yZGVyIC1ub3RtYXRjaCBbcmVnZXhdOjpFc2NhcGUoJGd1aWQp
>> "%B64FILE%" echo KSB7DQogICAgICAgICRhZCA9IEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL2Rpc3BsYXlvcmRlcics
>> "%B64FILE%" echo ICRndWlkLCAnL2FkZGxhc3QnKSAtVGFnICdkaXNwbGF5b3JkZXInDQogICAgICAgIGlmICgkYWQu
>> "%B64FILE%" echo T2spIHsNCiAgICAgICAgICAgIFdyaXRlLUxvZyAn5bey5Yqg5Zue5byA5py66I+c5Y2V77yI5o6S
>> "%B64FILE%" echo 5Zyo5pyA5ZCO77yJJyAnT0snDQogICAgICAgICAgICAkZml4ZWRDb3VudCsrDQogICAgICAgIH0g
>> "%B64FILE%" echo ZWxzZSB7DQogICAgICAgICAgICBXcml0ZS1Mb2cgIuWKoOWbnuaYvuekuumhuuW6j+Wksei0pe+8
>> "%B64FILE%" echo miQoJGFkLlRleHQpIiAnRVJSJw0KICAgICAgICAgICAgJGZhaWxDb3VudCsrDQogICAgICAgIH0N
>> "%B64FILE%" echo CiAgICAgICAgJGJtID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZW51bScsICd7Ym9vdG1ncn0n
>> "%B64FILE%" echo KSAtVGFnICdib290bWdyMicNCiAgICAgICAgJG9tID0gW3JlZ2V4XTo6TWF0Y2goJGJtLlJhdywg
>> "%B64FILE%" echo Jyg/aW0pXlxzKig/OmRpc3BsYXlvcmRlcnzmmL7npLrpobrluo8pXHMrKC4rPylccyokJykNCiAg
>> "%B64FILE%" echo ICAgICAgaWYgKCRvbS5TdWNjZXNzKSB7ICRvcmRlciA9ICRvbS5Hcm91cHNbMV0uVmFsdWUgfQ0K
>> "%B64FILE%" echo ICAgIH0gZWxzZSB7DQogICAgICAgIFdyaXRlLUxvZyAn5pi+56S66aG65bqP6YeM5pyJ5a6DJyAn
>> "%B64FILE%" echo T0snDQogICAgfQ0KDQogICAgIyDoj5zljZXlvpfmmK/miZPlvIDnmoTvvIzlkKbliJnlvIDmnLrn
>> "%B64FILE%" echo m7TmjqXov5vpu5jorqTns7vnu5/vvIznnIvkuI3liLDov5nkupvpgInpobkNCiAgICAkZW50cnlD
>> "%B64FILE%" echo b3VudCA9IChbcmVnZXhdOjpNYXRjaGVzKCRvcmRlciwgJ1x7JykpLkNvdW50DQogICAgaWYgKCRl
>> "%B64FILE%" echo bnRyeUNvdW50IC1nZSAyKSB7DQogICAgICAgICRkYm0gPSBbcmVnZXhdOjpNYXRjaCgkYm0uUmF3
>> "%B64FILE%" echo LCAnKD9pbSleXHMqKD86ZGlzcGxheWJvb3RtZW51fOaYvuekuuWQr+WKqOiPnOWNlSlccysoXFMr
>> "%B64FILE%" echo KScpDQogICAgICAgICR0bW8gPSBbcmVnZXhdOjpNYXRjaCgkYm0uUmF3LCAnKD9pbSleXHMqdGlt
>> "%B64FILE%" echo ZW91dFxzKyhcZCspJykNCiAgICAgICAgJG5lZWRNZW51ID0gJGZhbHNlDQogICAgICAgIGlmICgt
>> "%B64FILE%" echo bm90ICRkYm0uU3VjY2VzcykgeyAkbmVlZE1lbnUgPSAkdHJ1ZSB9DQogICAgICAgIGVsc2VpZiAo
>> "%B64FILE%" echo JGRibS5Hcm91cHNbMV0uVmFsdWUgLW5vdG1hdGNoICdeKD9pOnllcykkJykgeyAkbmVlZE1lbnUg
>> "%B64FILE%" echo PSAkdHJ1ZSB9DQogICAgICAgICRuZWVkVGltZW91dCA9ICgkdG1vLlN1Y2Nlc3MgLWFuZCAoW2lu
>> "%B64FILE%" echo dF0kdG1vLkdyb3Vwc1sxXS5WYWx1ZSAtZXEgMCkpDQoNCiAgICAgICAgaWYgKCRuZWVkTWVudSAt
>> "%B64FILE%" echo b3IgJG5lZWRUaW1lb3V0KSB7DQogICAgICAgICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJn
>> "%B64FILE%" echo cyBAKCcvc2V0JywgJ3tib290bWdyfScsICdkaXNwbGF5Ym9vdG1lbnUnLCAnWWVzJykgLVRhZyAn
>> "%B64FILE%" echo bWVudS1vbicpDQogICAgICAgICAgICBpZiAoJG5lZWRUaW1lb3V0KSB7DQogICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgW3ZvaWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICd7Ym9vdG1ncn0nLCAndGlt
>> "%B64FILE%" echo ZW91dCcsICcxMCcpIC1UYWcgJ3RpbWVvdXQtMTAnKQ0KICAgICAgICAgICAgfQ0KICAgICAgICAg
>> "%B64FILE%" echo ICAgV3JpdGUtTG9nICflvIDmnLroj5zljZXlt7LmiZPlvIDvvIjkuI3nhLbmoLnmnKznnIvkuI3l
>> "%B64FILE%" echo iLDpgInpobnvvIknICdPSycNCiAgICAgICAgICAgICRmaXhlZENvdW50KysNCiAgICAgICAgfQ0K
>> "%B64FILE%" echo ICAgIH0NCn0NCg0KIyAtLS0tLS0tLS0tIOe7k+iuuiAtLS0tLS0tLS0tDQpXcml0ZS1Ib3N0ICcn
>> "%B64FILE%" echo DQpXcml0ZS1Ib3N0ICc9PT09PT09PT09PT09PT09IOe7k+aenCA9PT09PT09PT09PT09PT09Jw0K
>> "%B64FILE%" echo V3JpdGUtSG9zdCAoIiAg5pys5p2l5bCx5a+577yaezB9IOS4qiIgLWYgJG9rQ291bnQpDQpXcml0
>> "%B64FILE%" echo ZS1Ib3N0ICgiICDlt7Lkv67lpb0gIO+8mnswfSDlpIQiIC1mICRmaXhlZENvdW50KSAtRm9yZWdy
>> "%B64FILE%" echo b3VuZENvbG9yIEdyZWVuDQpXcml0ZS1Ib3N0ICgiICDmsqHkv67lpb0gIO+8mnswfSDkuKoiIC1m
>> "%B64FILE%" echo ICRmYWlsQ291bnQpIC1Gb3JlZ3JvdW5kQ29sb3IgJChpZiAoJGZhaWxDb3VudCAtZ3QgMCkgeyAn
>> "%B64FILE%" echo UmVkJyB9IGVsc2UgeyAnR3JheScgfSkNCldyaXRlLUhvc3QgJycNCmlmICgkZml4ZWRDb3VudCAt
>> "%B64FILE%" echo Z3QgMCkgew0KICAgIFdyaXRlLUhvc3QgJ+mHjeWQr+eUteiEke+8jOW8gOacuuiPnOWNlemHjOW6
>> "%B64FILE%" echo lOivpeWwseiDveeci+WIsOW5tui/m+WFpei/meS6m+ezu+e7n+S6huOAgicgLUZvcmVncm91bmRD
>> "%B64FILE%" echo b2xvciBHcmVlbg0KfSBlbHNlaWYgKCRmYWlsQ291bnQgLWVxIDAgLWFuZCAkb2tDb3VudCAtZ3Qg
>> "%B64FILE%" echo MCkgew0KICAgIFdyaXRlLUhvc3QgJ+iPnOWNleaMh+WQkemDveaYr+WvueeahO+8jOS4jeeUqOS/
>> "%B64FILE%" echo ruOAguWmguaenOW8gOacuui/mOaYr+eci+S4jeWIsOiPnOWNle+8jCcNCiAgICBXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICflj6/og73mmK/lm7rku7bmsqHku47ov5nlnZfnm5jnmoQgRVNQIOWQr+WKqO+8jOaIluaYr+iP
>> "%B64FILE%" echo nOWNlei2heaXtuWkquefre+8jOi/nuaMieaWueWQkemUruivleivleOAgicNCn0gZWxzZSB7DQog
>> "%B64FILE%" echo ICAgV3JpdGUtSG9zdCAn5pyJ5rKh5L+u5aW955qE6aG577yM5oqK5LiL6Z2i55qE5pel5b+X5Y+R
>> "%B64FILE%" echo 57uZ5oiR55yL55yL44CCJyAtRm9yZWdyb3VuZENvbG9yIFllbGxvdw0KfQ0KV3JpdGUtSG9zdCAn
>> "%B64FILE%" echo Jw0KV3JpdGUtSG9zdCAoIuaXpeW/l++8mnswfSIgLWYgJFNjcmlwdDpMb2dGaWxlKQ0KV3JpdGUt
>> "%B64FILE%" echo SG9zdCAnJw0KV3JpdGUtSG9zdCAn5oyJ5Lu75oSP6ZSu6YCA5Ye6Li4uJw0KJG51bGwgPSAkSG9z
>> "%B64FILE%" echo dC5VSS5SYXdVSS5SZWFkS2V5KCdOb0VjaG8sSW5jbHVkZUtleURvd24nKQ0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=14751"
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
