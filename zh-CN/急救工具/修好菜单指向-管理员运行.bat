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
>> "%B64FILE%" echo cnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjM2Jw0K
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
>> "%B64FILE%" echo ZSA9ICRjb2RlOyBUZXh0ID0gJGNsZWFuOyBSYXcgPSAkdHh0IH0NCn0NCiMg44CQdjEuMzbjgJFU
>> "%B64FILE%" echo ZXN0LUJjZFRleHRTYW1lIOaQrOi/m+WFseS6q+aooeWdl+S6hu+8muWOn+adpeWbm+S4quiEmuac
>> "%B64FILE%" echo rOWQhOeVmeS4gOS7veWQjOagt+eahOavlOi+g+mAu+i+ke+8jA0KIyDmlLnkuIDlpITlvpfmlLnl
>> "%B64FILE%" echo m5vlpITvvIzogIzkuJTlh6Dku73kvJrmgoTmgoTot5HlgY/jgIINCiMgPT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQojIEJDRCDnm7jl
>> "%B64FILE%" echo hbPlt6Xlhbflh73mlbDvvIzlronoo4XlmaggLyDljbjovb3lmaggLyDkv67lpI3lt6XlhbcgLyDj
>> "%B64FILE%" echo gIzkv67lpb3oj5zljZXmjIflkJHjgI3lhbHnlKjjgIINCiMNCiMg5omT5YyF5pe255SxIHNyYy9i
>> "%B64FILE%" echo dWlsZC9pbmxpbmVfc2hhcmVkLnB5IOWGheiBlOi/m+avj+S4quiEmuacrO+8iOWPkeW4g+W9ouaA
>> "%B64FILE%" echo geaYr+WNleS4quiHquino+WOiyBiYXTvvIwNCiMg6L296I235Y+q5pyJ5LiA5LiqIHBzMe+8ie+8
>> "%B64FILE%" echo jOaJgOS7peW8leeUqOWug+eahOiEmuacrOWQhOiHquW4puS4gOS7ve+8m+a6kOeggemHjOWni+e7
>> "%B64FILE%" echo iOWPquaciei/meS4gOS7veOAgg0KIw0KIyDlnKjohJrmnKzph4zov5nmoLflvJXnlKjvvJoNCiMg
>> "%B64FILE%" echo ICAgIC4gIiRQU1NjcmlwdFJvb3RcLi5cc2hhcmVkXHpoLUNOXEJjZFZlcmlmeS5wczEiDQojID09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PQ0KDQojIOmAkOWtl+avlOWvueOAjOimgeWGmeWFpeeahOiuvuWkh+i3r+W+hOOAjeWSjCBiY2Rl
>> "%B64FILE%" echo ZGl0IOWbnuaYvueahOe7k+aenOOAgg0KIw0KIyDmjqfliLblj7Dku6PnoIHpobXmmL7npLrkuI3k
>> "%B64FILE%" echo uobnmoTlrZfkvJrlj5jmiJAgIj8i77ya5Lit5paH55uu5b2V5ZCN5Zue6K+75oiQICI/IiDml7bp
>> "%B64FILE%" echo gJDlrZfoioLmr5Tlr7nlv4XnhLbkuI3nm7jnrYnvvIwNCiMg5L2GIEJDRCDph4zlrZjnmoTmmK/l
>> "%B64FILE%" echo r7nnmoTjgILov5nph4zlj6rlnKjjgIzmnJ/mnJvlrZfnrKbmnKzouqvpnZ4gQVNDSUnjgI3nmoTk
>> "%B64FILE%" echo vY3nva7mjqXlj5cgIj8i77yM5YW25L2Z5LiA5b6L6KaB5rGC55u45ZCM77yaDQojIOmVv+W6puW/
>> "%B64FILE%" echo hemhu+S4gOiHtO+8jOaJgOaciSBBU0NJSSDlrZfnrKblv4XpobvlrozlhajkuIDoh7TjgIINCmZ1
>> "%B64FILE%" echo bmN0aW9uIFRlc3QtQmNkVGV4dFNhbWUgew0KICAgIHBhcmFtKFtzdHJpbmddJFdhbnQsIFtzdHJp
>> "%B64FILE%" echo bmddJEdvdCkNCiAgICBpZiAoJG51bGwgLWVxICRHb3QpIHsgcmV0dXJuICRmYWxzZSB9DQogICAg
>> "%B64FILE%" echo aWYgKCRHb3QgLWVxICRXYW50KSB7IHJldHVybiAkdHJ1ZSB9DQogICAgaWYgKCRHb3QuTGVuZ3Ro
>> "%B64FILE%" echo IC1uZSAkV2FudC5MZW5ndGgpIHsgcmV0dXJuICRmYWxzZSB9DQogICAgZm9yICgkaSA9IDA7ICRp
>> "%B64FILE%" echo IC1sdCAkV2FudC5MZW5ndGg7ICRpKyspIHsNCiAgICAgICAgaWYgKCRHb3RbJGldIC1lcSAkV2Fu
>> "%B64FILE%" echo dFskaV0pIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJEdvdFskaV0gLWVxICc/JyAtYW5kIFtp
>> "%B64FILE%" echo bnRdW2NoYXJdJFdhbnRbJGldIC1ndCAxMjcpIHsgY29udGludWUgfQ0KICAgICAgICByZXR1cm4g
>> "%B64FILE%" echo JGZhbHNlDQogICAgfQ0KICAgIHJldHVybiAkdHJ1ZQ0KfQ0KDQojIOW4piB2aGQ9IOeahOWPquac
>> "%B64FILE%" echo iSBkZXZpY2Ug6YKj5LiA6KGM44CC5YmN6Z2i55qE5a2X5q615ZCN6ZqP57O757uf6K+t6KiA5Y+Y
>> "%B64FILE%" echo 77yIZGV2aWNlIC8gR2Vyw6R0IC8g44OH44OQ44Kk44K5IC8g6K6+5aSH77yJ77yMDQojIOaJgOS7
>> "%B64FILE%" echo peawuOi/nOS4jeavlOWvueWtl+auteWQje+8jOWPquWPluWAvOOAgg0KZnVuY3Rpb24gR2V0LUJj
>> "%B64FILE%" echo ZERldmljZUZyb21PdXRwdXQgew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQpDQogICAgJG0gPSBb
>> "%B64FILE%" echo cmVnZXhdOjpNYXRjaChbc3RyaW5nXSRUZXh0LCAnKD9pbSleW15cclxuXSo/KHZoZD1cW1teXHJc
>> "%B64FILE%" echo bl0rKScpDQogICAgaWYgKC1ub3QgJG0uU3VjY2VzcykgeyByZXR1cm4gJycgfQ0KICAgIHJldHVy
>> "%B64FILE%" echo biAkbS5Hcm91cHNbMV0uVmFsdWUuVHJpbSgpDQp9DQoNCiMg44CQdjEuMzbjgJHov5nkuIDlnZfm
>> "%B64FILE%" echo mK/kuI3mmK/nnJ/nmoTmk43kvZzns7vnu5/liqDovb3pobnvvIjogIzkuI3mmK/mgaLlpI3njq/l
>> "%B64FILE%" echo ooMgLyDlhoXlrZjor4rmlq0gLyBXaW5SRSDmoanvvInvvJ8NCiMNCiMg5YC85ZKM5qCH562+5LmL
>> "%B64FILE%" echo 6Ze055qE6YKj5Liq6K+N5piv5pys5Zyw5YyW55qEIOKAlOKAlCBkZXZpY2UgLyDorr7lpIcgLyBH
>> "%B64FILE%" echo ZXLDpHQgLyDjg4fjg5DjgqTjgrkg4oCU4oCUIOaJgOS7peawuOi/nOS4jeavlOWvueagh+etvu+8
>> "%B64FILE%" echo jA0KIyDlj6rlj5blgLzjgILogIHlhpnms5XopoHmsYLlv4Xpobvlh7rnjrDoi7HmlocgImRldmlj
>> "%B64FILE%" echo ZSLvvIzlnKjmiorlroPmnKzlnLDljJbnmoTns7vnu5/kuIrkvJrot7Pov4fmiYDmnInmnaHnm67v
>> "%B64FILE%" echo vIwNCiMg5LqO5piv44CM5Yig5a6M6Ieq5qOA44CN5Lul5Li65LiA5Liq5Y+v5ZCv5Yqo57O757uf
>> "%B64FILE%" echo 6YO95LiN5Ymp77yM5oqK5YGl5bq355qEIEJDRCDnlKjlpIfku73opobnm5bkuobjgIINCmZ1bmN0
>> "%B64FILE%" echo aW9uIFRlc3QtQmNkQmxvY2tJc0xvYWRlciB7DQogICAgcGFyYW0oW3N0cmluZ10kVGV4dCkNCiAg
>> "%B64FILE%" echo ICBpZiAoR2V0LUJjZERldmljZUZyb21PdXRwdXQgLVRleHQgJFRleHQpIHsgcmV0dXJuICR0cnVl
>> "%B64FILE%" echo IH0gICAgICAgICMg5Lu75L2VIHZoZD0g5p2h55uuDQogICAgcmV0dXJuIFtib29sXShbcmVnZXhd
>> "%B64FILE%" echo OjpJc01hdGNoKFtzdHJpbmddJFRleHQsICcoP2ltKV5bXlxyXG5dKj9cYnBhcnRpdGlvbj1bXlxz
>> "%B64FILE%" echo XHJcbl0rJykpDQp9DQoNCiMg44CQdjEuMzbjgJHliKDmjonkuIDkuKrlkK/liqjpobnvvIzlubbo
>> "%B64FILE%" echo r7TmmI7lroPliLDlupXmnInmsqHmnInooqvliKDmjonjgIINCiMNCiMg6ICB5YaZ5rOV6Z2g44CM
>> "%B64FILE%" echo 6L6T5Ye66YeM5pyJ5rKh5pyJ44CO5om+5LiN5Yiw44CPL+OAjm5vdCBmb3VuZOOAjy/jgI5pbnZh
>> "%B64FILE%" echo bGlk44CP44CN5Yik5pat5oiQ6LSl44CCDQojIOiLseaWh+WQr+WKqOWZqOW8gOWktCBjaGNwIDQz
>> "%B64FILE%" echo N++8jOS4reaWhyBiY2RlZGl0IOeahOmUmeivr+S/oeaBr+S8muWPmOaIkOS5seegge+8jOS4gOS4
>> "%B64FILE%" echo quWFs+mUruivjemDveWMuemFjeS4jeS4iu+8jA0KIyDkuo7mmK8qKuWIoOmZpOWksei0peS5n+ii
>> "%B64FILE%" echo q+iusOaIkOaIkOWKnyoqIOKAlOKAlCDljbjovb3lmajmjqXnnYDmioogdmhkeCDliKDkuobvvIzo
>> "%B64FILE%" echo j5zljZXph4znlZnkuIvkuIDmnaHmjIflkJENCiMg5LiN5a2Y5Zyo5paH5Lu255qE5p2h55uu77yM
>> "%B64FILE%" echo 5LiL5qyh5byA5py66YCJ5Lit5bCx5oqlIDB4YzAwMDAwMGbjgIINCiMNCiMg6YCA5Ye656CB5LiN
>> "%B64FILE%" echo 5Y+X57O757uf6K+t6KiA5b2x5ZON77yaMCA9IOWIoOaOieS6hu+8jOmdniAwID0g5rKh5Yig5o6J
>> "%B64FILE%" echo 44CCDQpmdW5jdGlvbiBSZW1vdmUtQmNkRW50cnkgew0KICAgIHBhcmFtKA0KICAgICAgICBbUGFy
>> "%B64FILE%" echo YW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRHdWlkLA0KICAgICAgICAjIOWPquac
>> "%B64FILE%" echo ieWNleWFg+a1i+ivleS8muS8oOWIq+eahO+8iOS4gOS4quaVheaEj+i/lOWbnumdniAwIOeahOah
>> "%B64FILE%" echo qe+8ieOAgg0KICAgICAgICBbc3RyaW5nXSRCY2RFeGUgPSAnYmNkZWRpdC5leGUnDQogICAgKQ0K
>> "%B64FILE%" echo ICAgICRyZXMgPSBbUFNDdXN0b21PYmplY3RdQHsgT2sgPSAkZmFsc2U7IENvZGUgPSAtMTsgVGV4
>> "%B64FILE%" echo dCA9ICcnIH0NCiAgICB0cnkgew0KICAgICAgICAkb3V0ID0gKCYgJEJjZEV4ZSAvZGVsZXRlICIk
>> "%B64FILE%" echo R3VpZCIgL2YgMj4mMSB8IE91dC1TdHJpbmcpDQogICAgICAgICRyZXMuQ29kZSA9ICRMQVNURVhJ
>> "%B64FILE%" echo VENPREUNCiAgICAgICAgJHJlcy5UZXh0ID0gKCgkb3V0IC1yZXBsYWNlICdccysnLCAnICcpLlRy
>> "%B64FILE%" echo aW0oKSkNCiAgICAgICAgJHJlcy5PayA9ICgkcmVzLkNvZGUgLWVxIDApDQogICAgfSBjYXRjaCB7
>> "%B64FILE%" echo DQogICAgICAgICRyZXMuVGV4dCA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlDQogICAgfQ0KICAgIHJl
>> "%B64FILE%" echo dHVybiAkcmVzDQp9DQoNCiMg44CQdjEuMzbjgJHlkK/liqjpobnlpITnkIblrozkuYvlkI7vvIzo
>> "%B64FILE%" echo v5nlnZcgdmhkeCDliLDlupXog73kuI3og73liKDvvJ8NCiMNCiMgdjEuMzUg5piv5peg5p2h5Lu2
>> "%B64FILE%" echo 5Yig44CC5Y+v5LiA5pem5LiK6Z2i5Yia5Yik6L+H44CM6K+B5LiN5LqG5ZOq5p2h5bGe5LqO6L+Z
>> "%B64FILE%" echo 5Z2X55uY77yM5bey6Lez6L+H5LiN5Yig44CN77yMDQojIOe7k+aenOWwseaYr+aWh+S7tuayoeS6
>> "%B64FILE%" echo huOAgeiPnOWNleadoeebrui/mOWcqCDigJTigJQg5LiL5qyh5byA5py66YCJ5Lit5bCx5oqlIDB4
>> "%B64FILE%" echo YzAwMDAwMGbjgIINCiMNCiMg6KeE5YiZ77ya5Y+q5pyJ44CM5LuA5LmI6YO95rKh5Yy56YWN5Yiw
>> "%B64FILE%" echo 44CN5oiW44CM56Gu5a6e5Yig5o6J5LqG5p2h55uu44CN5omN5YWB6K645Yig5paH5Lu244CCDQoj
>> "%B64FILE%" echo IOOAjOWMuemFjeWIsOS9huWIoOS4jeaOieOAjeOAjOWkmuS4quWQjOWQjeWAmemAieOAjeOAjOiu
>> "%B64FILE%" echo sOW9lemHjOeahOadoeebruWvueS4jeS4iuS6huOAjemDveaEj+WRs+edgO+8muWBnOS4i++8jOaK
>> "%B64FILE%" echo iuebmOeVmeS4i+OAgg0KZnVuY3Rpb24gR2V0LVVuaW5zdGFsbERlbGV0ZVZlcmRpY3Qgew0KICAg
>> "%B64FILE%" echo IHBhcmFtKA0KICAgICAgICBbaW50XSRSZW1vdmVkID0gMCwNCiAgICAgICAgW2ludF0kSGl0Q291
>> "%B64FILE%" echo bnQgPSAwLA0KICAgICAgICBbaW50XSRDYW5kaWRhdGVDb3VudCA9IDAsDQogICAgICAgIFtib29s
>> "%B64FILE%" echo XSRTdGF0ZVJlZnVzZWQgPSAkZmFsc2UNCiAgICApDQogICAgaWYgKCRSZW1vdmVkIC1ndCAwKSB7
>> "%B64FILE%" echo DQogICAgICAgIHJldHVybiBbUFNDdXN0b21PYmplY3RdQHsgQWxsb3cgPSAkdHJ1ZTsgUmVhc29u
>> "%B64FILE%" echo ID0gJycgfQ0KICAgIH0NCiAgICBpZiAoJEhpdENvdW50IC1ndCAwKSB7DQogICAgICAgIHJldHVy
>> "%B64FILE%" echo biBbUFNDdXN0b21PYmplY3RdQHsgQWxsb3cgPSAkZmFsc2U7IFJlYXNvbiA9ICLlkb3kuK3kuoYg
>> "%B64FILE%" echo JEhpdENvdW50IOS4quWQr+WKqOmhue+8jOS9huS4gOS4qumDveayoeWIoOaOiSIgfQ0KICAgIH0N
>> "%B64FILE%" echo CiAgICBpZiAoJENhbmRpZGF0ZUNvdW50IC1ndCAwKSB7DQogICAgICAgIHJldHVybiBbUFNDdXN0
>> "%B64FILE%" echo b21PYmplY3RdQHsgQWxsb3cgPSAkZmFsc2U7IFJlYXNvbiA9ICLmnIkgJENhbmRpZGF0ZUNvdW50
>> "%B64FILE%" echo IOS4quWQr+WKqOmhueW4puWQjOWQjeaWh+S7tu+8jOS9huS4gOS4qumDveaXoOazleivgeaYjuWx
>> "%B64FILE%" echo nuS6jui/meS4qiB2aGR4IiB9DQogICAgfQ0KICAgIGlmICgkU3RhdGVSZWZ1c2VkKSB7DQogICAg
>> "%B64FILE%" echo ICAgIHJldHVybiBbUFNDdXN0b21PYmplY3RdQHsgQWxsb3cgPSAkZmFsc2U7IFJlYXNvbiA9ICfn
>> "%B64FILE%" echo irbmgIHmlofku7bph4zorrDnmoTmnaHnm67lt7Lnu4/kuI3lho3mjIflkJHov5nkuKogdmhkeCcg
>> "%B64FILE%" echo fQ0KICAgIH0NCiAgICByZXR1cm4gW1BTQ3VzdG9tT2JqZWN0XUB7IEFsbG93ID0gJHRydWU7IFJl
>> "%B64FILE%" echo YXNvbiA9ICfmsqHmnInku7vkvZXlkK/liqjpobnmjIflkJHov5nkuKrmlofku7YnIH0NCn0NCg0K
>> "%B64FILE%" echo IyDjgJB2MS4zNuOAkeiuqSBiY2RlZGl0IOeahOi+k+WHuuWOn+agt+S/neeVmemdniBBU0NJSSDl
>> "%B64FILE%" echo rZfnrKbjgIINCiMNCiMgMjAyNi0xMS0xMyDlnKggV2luZG93cyAxMCAyMkgyIOeugOS9k+S4reaW
>> "%B64FILE%" echo hyArIFdpbmRvd3MgUG93ZXJTaGVsbCA1LjEg5LiK5a6e5rWL77yaDQojICAgKiDmjqfliLblj7Dn
>> "%B64FILE%" echo qIvluo/nmoQgc3Rkb3V0IOiiq+mHjeWumuWQkeaXtuWGmeWHuueahOaYryBBTlNJIOWtl+iKgu+8
>> "%B64FILE%" echo iOi/memHjOaYryBHQkvvvInvvIwNCiMgICAgIOiAjCBQb3dlclNoZWxsIOeUqCBbQ29uc29sZV06
>> "%B64FILE%" echo Ok91dHB1dEVuY29kaW5nIOWOu+ino+egge+8mw0KIyAgICog6Iux5paH5ZCv5Yqo5Zmo5byA5aS0
>> "%B64FILE%" echo 5omn6KGMIGNoY3AgNDM377yM5Lik6L655a+55LiN5LiK77yM5LqO5piv5q+P5Liq5rGJ5a2X5Zue
>> "%B64FILE%" echo 6K+75oiQICI/Iu+8jA0KIyAgICAg5oiW6ICF5LiA5Liq5rGJ5a2X5Y+Y5oiQ5Lik5Liq5Lmx56CB
>> "%B64FILE%" echo 5a2X56ym77ybDQojICAgKiDnu5kgW0NvbnNvbGVdOjpPdXRwdXRFbmNvZGluZyDotYvlgLzkvJro
>> "%B64FILE%" echo v57luKbliIfmjaLmjqfliLblj7Dku6PnoIHpobXvvIguTkVUIOeahCBzZXR0ZXIg5Lya6LCDDQoj
>> "%B64FILE%" echo ICAgICBTZXRDb25zb2xlT3V0cHV0Q1DvvInvvIzmiYDku6XmiorlroPorr7miJAgQU5TSSDku6Pn
>> "%B64FILE%" echo oIHpobXvvIzlhpnnmoTkuIDkvqflkozor7vnmoTkuIDkvqflsLHnu5/kuIDkuobjgIINCiMNCiMg
>> "%B64FILE%" echo 6L+U5ZueIEB7IE9rOyBUZXh0OyBDb2RlUGFnZSB944CCT2s9JGZhbHNlIOihqOekuiBiY2RlZGl0
>> "%B64FILE%" echo IOi1t+S4jeadpeaIluayoeaciei+k+WHuu+8jA0KIyDosIPnlKjmlrnlv4XpobvpgIDlm57ljp/m
>> "%B64FILE%" echo naXnmoTnm7TmjqXosIPnlKjvvIznu53kuI3og73miorlroPlvZPmiJDjgIzot6/lvoTlhpnplJnk
>> "%B64FILE%" echo uobjgI3jgIINCmZ1bmN0aW9uIEdldC1CY2RPdXRwdXRFeGFjdCB7DQogICAgcGFyYW0oDQogICAg
>> "%B64FILE%" echo ICAgIFtzdHJpbmdbXV0kQmNkQXJncywNCiAgICAgICAgIyDlj6rmnInljZXlhYPmtYvor5XkvJrk
>> "%B64FILE%" echo vKDliKvnmoTjgIINCiAgICAgICAgW3N0cmluZ10kQmNkRXhlID0gJ2JjZGVkaXQuZXhlJw0KICAg
>> "%B64FILE%" echo ICkNCiAgICAkb3V0ID0gQHsgT2sgPSAkZmFsc2U7IFRleHQgPSAnJzsgQ29kZVBhZ2UgPSAwIH0N
>> "%B64FILE%" echo CiAgICAkY3AgPSAwDQogICAgdHJ5IHsgJGNwID0gW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6RGVm
>> "%B64FILE%" echo YXVsdC5Db2RlUGFnZSB9IGNhdGNoIHt9DQogICAgaWYgKCRjcCAtbGUgMCkgeyAkY3AgPSA0Mzcg
>> "%B64FILE%" echo fQ0KICAgICRvbGRFbmMgPSAkbnVsbA0KICAgIHRyeSB7DQogICAgICAgIHRyeSB7ICRvbGRFbmMg
>> "%B64FILE%" echo PSBbQ29uc29sZV06Ok91dHB1dEVuY29kaW5nIH0gY2F0Y2gge30NCiAgICAgICAgaWYgKCRvbGRF
>> "%B64FILE%" echo bmMpIHsNCiAgICAgICAgICAgIHRyeSB7IFtDb25zb2xlXTo6T3V0cHV0RW5jb2RpbmcgPSBbU3lz
>> "%B64FILE%" echo dGVtLlRleHQuRW5jb2RpbmddOjpHZXRFbmNvZGluZygkY3ApIH0NCiAgICAgICAgICAgIGNhdGNo
>> "%B64FILE%" echo IHsgJGNwID0gJG9sZEVuYy5Db2RlUGFnZSB9DQogICAgICAgIH0NCiAgICAgICAgJHR4dCA9ICgm
>> "%B64FILE%" echo ICRCY2RFeGUgQEJjZEFyZ3MgMj4mMSB8IE91dC1TdHJpbmcpDQogICAgICAgIGlmICgkdHh0IC1h
>> "%B64FILE%" echo bmQgJHR4dC5MZW5ndGggLWd0IDApIHsgJG91dC5PayA9ICR0cnVlOyAkb3V0LlRleHQgPSAkdHh0
>> "%B64FILE%" echo IH0NCiAgICB9IGNhdGNoIHsNCiAgICAgICAgJG91dC5PayA9ICRmYWxzZQ0KICAgIH0gZmluYWxs
>> "%B64FILE%" echo eSB7DQogICAgICAgIGlmICgkb2xkRW5jKSB7IHRyeSB7IFtDb25zb2xlXTo6T3V0cHV0RW5jb2Rp
>> "%B64FILE%" echo bmcgPSAkb2xkRW5jIH0gY2F0Y2gge30gfQ0KICAgIH0NCiAgICAkb3V0LkNvZGVQYWdlID0gJGNw
>> "%B64FILE%" echo DQogICAgcmV0dXJuICRvdXQNCn0NCg0KIyDlrozmlbTot6/lvoQgLT4gQkNEIOeahCB2aGQ9IOWG
>> "%B64FILE%" echo meazleOAguW/hemhu+S/neeVmeS4remXtOWtkOebruW9le+8mg0KIyAgIEQ6XOiZmuaLn+ejgeeb
>> "%B64FILE%" echo mFxtYWltYWkudmhkeCAgLT4gIHZoZD1bRDpdXOiZmuaLn+ejgeebmFxtYWltYWkudmhkeA0KZnVu
>> "%B64FILE%" echo Y3Rpb24gR2V0LVZoZEJjZERldmljZSB7DQogICAgcGFyYW0oW3N0cmluZ10kRnVsbFBhdGgpDQog
>> "%B64FILE%" echo ICAgJGZ1bGwgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGdWxsUGF0aCgkRnVsbFBhdGgpDQogICAg
>> "%B64FILE%" echo JHJvb3QgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRQYXRoUm9vdCgkZnVsbCkNCiAgICBpZiAoLW5v
>> "%B64FILE%" echo dCAkcm9vdCAtb3IgJHJvb3QuTGVuZ3RoIC1sdCAzKSB7IHRocm93ICLot6/lvoTml6DmlYjvvJok
>> "%B64FILE%" echo RnVsbFBhdGgiIH0NCiAgICAkbGV0dGVyID0gJHJvb3QuU3Vic3RyaW5nKDAsIDEpLlRvVXBwZXIo
>> "%B64FILE%" echo KQ0KICAgICRyZWwgPSAkZnVsbC5TdWJzdHJpbmcoJHJvb3QuTGVuZ3RoKS5UcmltU3RhcnQoJ1wn
>> "%B64FILE%" echo KQ0KICAgIGlmICgtbm90ICRyZWwpIHsgdGhyb3cgIui3r+W+hOaXoOaViO+8miRGdWxsUGF0aCIg
>> "%B64FILE%" echo fQ0KICAgIHJldHVybiAidmhkPVskKCRsZXR0ZXIpOl1cJHJlbCINCn0NCg0KIyDlj43lkJHop6Pm
>> "%B64FILE%" echo npDvvIznlKjmnaXot5/nnJ/lrp7ot6/lvoTpgJDlrZfmr5Tlr7kNCmZ1bmN0aW9uIEdldC1GdWxs
>> "%B64FILE%" echo UGF0aEZyb21CY2REZXZpY2Ugew0KICAgIHBhcmFtKFtzdHJpbmddJERldikNCiAgICBpZiAoLW5v
>> "%B64FILE%" echo dCAkRGV2KSB7IHJldHVybiAnJyB9DQogICAgJG0gPSBbcmVnZXhdOjpNYXRjaCgkRGV2LCAnXnZo
>> "%B64FILE%" echo ZD1cWyhbQS1aYS16XSk6XF1cXCguKykkJykNCiAgICBpZiAoLW5vdCAkbS5TdWNjZXNzKSB7IHJl
>> "%B64FILE%" echo dHVybiAnJyB9DQogICAgcmV0dXJuICgiezB9Olx7MX0iIC1mICRtLkdyb3Vwc1sxXS5WYWx1ZS5U
>> "%B64FILE%" echo b1VwcGVyKCksICRtLkdyb3Vwc1syXS5WYWx1ZSkNCn0NCg0KIyDmiavmiYDmnInlm7rlrpogTlRG
>> "%B64FILE%" echo UyDnm5jph4znmoQgdmhkeOOAguW5v+W6puS8mOWFiCArIOaMieebruW9leWQjeWJquaene+8jA0K
>> "%B64FILE%" echo IyDkuI3ov5sgV2luZG93cyAvIFVzZXJzIC8g5Zue5pS256uZ77yM5omA5Lul5rex5bqm5byA5Yiw
>> "%B64FILE%" echo IDYg5Lmf5LiN5oWi44CCDQpmdW5jdGlvbiBHZXQtQWxsVmhkeEZpbGUgew0KICAgIHBhcmFtKFtp
>> "%B64FILE%" echo bnRdJE1heERlcHRoID0gNikNCiAgICAkc2tpcCA9IEAoJyRSRUNZQ0xFLkJJTicsICdTeXN0ZW0g
>> "%B64FILE%" echo Vm9sdW1lIEluZm9ybWF0aW9uJywgJ1dpbmRvd3MnLCAnUHJvZ3JhbSBGaWxlcycsDQogICAgICAg
>> "%B64FILE%" echo ICAgICAgICdQcm9ncmFtIEZpbGVzICh4ODYpJywgJ1Byb2dyYW1EYXRhJywgJ1VzZXJzJywgJyRX
>> "%B64FILE%" echo aW5SRUFnZW50JywgJ1JlY292ZXJ5JywNCiAgICAgICAgICAgICAgJ25vZGVfbW9kdWxlcycsICcu
>> "%B64FILE%" echo Z2l0JywgJ1dpblN4UycpDQogICAgJGZvdW5kID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlv
>> "%B64FILE%" echo bnMuQXJyYXlMaXN0DQogICAgZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FQSBTaWxlbnRs
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
>> "%B64FILE%" echo ZXR1cm4gJGZvdW5kLlRvQXJyYXkoKQ0KfQ0KDQpXcml0ZS1Ib3N0ICcnDQpXcml0ZS1Ib3N0ICfk
>> "%B64FILE%" echo v67lpb3lkK/liqjoj5zljZXmjIflkJEgLSDkvZzogIXvvJpjb25uZWN0c2VnYWJvdCcNCldyaXRl
>> "%B64FILE%" echo LUhvc3QgJz09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09Jw0KV3JpdGUtSG9z
>> "%B64FILE%" echo dCAnJw0KDQppZiAoLW5vdCAoVGVzdC1BZG1pbikpIHsNCiAgICBXcml0ZS1Ib3N0ICfpnIDopoHn
>> "%B64FILE%" echo rqHnkIblkZjmnYPpmZDjgIInIC1Gb3JlZ3JvdW5kQ29sb3IgUmVkDQogICAgV3JpdGUtSG9zdCAn
>> "%B64FILE%" echo 6K+35YWz5o6J6L+Z5Liq56qX5Y+j77yM55u05o6l5Y+M5Ye744CM5L+u5aW96I+c5Y2V5oyH5ZCR
>> "%B64FILE%" echo LeeuoeeQhuWRmOi/kOihjC5iYXTjgI3vvIzlroPkvJroh6rlt7HnlLPor7fmnYPpmZDjgIInDQog
>> "%B64FILE%" echo ICAgV3JpdGUtSG9zdCAnJw0KICAgIFdyaXRlLUhvc3QgJ+aMieS7u+aEj+mUrumAgOWHui4uLicN
>> "%B64FILE%" echo CiAgICAkbnVsbCA9ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXkoJ05vRWNobyxJbmNsdWRlS2V5RG93
>> "%B64FILE%" echo bicpDQogICAgcmV0dXJuDQp9DQoNCldyaXRlLUxvZyAi5pel5b+XOiAkKCRTY3JpcHQ6TG9nRmls
>> "%B64FILE%" echo ZSkiDQoNCiMgLS0tLS0tLS0tLSDlhYjlpIfku73mtLvliqggQkNEIC0tLS0tLS0tLS0NCiRzdGFt
>> "%B64FILE%" echo cCA9IEdldC1EYXRlIC1Gb3JtYXQgJ3l5eXlNTWRkLUhIbW1zcycNCiRiayA9IEpvaW4tUGF0aCAk
>> "%B64FILE%" echo ZW52OlRFTVAgImJjZC1iYWNrdXAtJHN0YW1wLmJjZCINCiRyYiA9IEludm9rZS1CY2QgLUJjZEFy
>> "%B64FILE%" echo Z3MgQCgnL2V4cG9ydCcsICRiaykgLVRhZyAnZXhwb3J0Jw0KaWYgKCRyYi5PayAtYW5kIChUZXN0
>> "%B64FILE%" echo LVBhdGggLUxpdGVyYWxQYXRoICRiaykpIHsNCiAgICBXcml0ZS1Mb2cgIkJDRCDlt7LlpIfku706
>> "%B64FILE%" echo ICRiayIgJ09LJw0KfSBlbHNlIHsNCiAgICBXcml0ZS1Mb2cgJ0JDRCDlpIfku73lpLHotKXvvIzn
>> "%B64FILE%" echo u6fnu63vvIjkuIvpnaLlj6rmlLnorr7lpIfot6/lvoTlkozoj5zljZXpobrluo/vvIzpo47pmanl
>> "%B64FILE%" echo vojkvY7vvIknICdXQVJOJw0KfQ0KDQojIC0tLS0tLS0tLS0g5om+55uu5qCHIC0tLS0tLS0tLS0N
>> "%B64FILE%" echo CldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgJ+ato+WcqOafpeaJvuijheWlveeahOiZmuaLn+ez
>> "%B64FILE%" echo u+e7ny4uLicNCiRpdGVtcyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlz
>> "%B64FILE%" echo dA0KZm9yZWFjaCAoJGYgaW4gQChHZXQtQWxsVmhkeEZpbGUpKSB7DQogICAgJHN0ID0gW1N5c3Rl
>> "%B64FILE%" echo bS5JTy5QYXRoXTo6Q2hhbmdlRXh0ZW5zaW9uKCRmLkZ1bGxOYW1lLCAnLmJvb3QudHh0JykNCiAg
>> "%B64FILE%" echo ICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkc3QpKSB7IGNvbnRpbnVlIH0NCiAg
>> "%B64FILE%" echo ICAkc2QgPSBAe30NCiAgICBmb3JlYWNoICgkbG4gaW4gKEdldC1Db250ZW50IC1MaXRlcmFsUGF0
>> "%B64FILE%" echo aCAkc3QgLUVuY29kaW5nIFVURjggLUVBIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlm
>> "%B64FILE%" echo ICgkbG4gLW1hdGNoICdeXHMqKFteIz1dKyk9KC4qKSQnKSB7ICRzZFskbWF0Y2hlc1sxXS5Ucmlt
>> "%B64FILE%" echo KCldID0gJG1hdGNoZXNbMl0uVHJpbSgpIH0NCiAgICB9DQogICAgJGcgPSBbc3RyaW5nXSRzZFsn
>> "%B64FILE%" echo R3VpZCddDQogICAgaWYgKCRnIC1ub3RtYXRjaCAnXlx7WzAtOWEtZkEtRi1dezM2fVx9JCcpIHsg
>> "%B64FILE%" echo Y29udGludWUgfQ0KICAgIFt2b2lkXSRpdGVtcy5BZGQoW1BTQ3VzdG9tT2JqZWN0XUB7DQogICAg
>> "%B64FILE%" echo ICAgIFBhdGggID0gJGYuRnVsbE5hbWUNCiAgICAgICAgR3VpZCAgPSAkZw0KICAgICAgICBOYW1l
>> "%B64FILE%" echo ICA9IFtzdHJpbmddJHNkWydOYW1lJ10NCiAgICAgICAgRGVzYyAgPSBbc3RyaW5nXSRzZFsnRGVz
>> "%B64FILE%" echo YyddDQogICAgICAgIFN0YXRlID0gJHN0DQogICAgfSkNCn0NCg0KaWYgKCRpdGVtcy5Db3VudCAt
>> "%B64FILE%" echo ZXEgMCkgew0KICAgIFdyaXRlLUhvc3QgJycNCiAgICBXcml0ZS1Ib3N0ICfmsqHmib7liLDmnKzl
>> "%B64FILE%" echo t6Xlhbfoo4Xov4fnmoTomZrmi5/ns7vnu5/jgIInIC1Gb3JlZ3JvdW5kQ29sb3IgWWVsbG93DQog
>> "%B64FILE%" echo ICAgV3JpdGUtSG9zdCAn77yI6ZyA6KaB6Jma5ouf56OB55uY5peB6L655pyJ5a6J6KOF5pe25YaZ
>> "%B64FILE%" echo 55qEIHh4eC5ib290LnR4dO+8iScNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9zdCAn
>> "%B64FILE%" echo 5aaC5p6c56Gu5a6e6KOF6L+H77yM5Y+v5Lul55So44CM5L+u5aSN5ZCv5Yqo6I+c5Y2VLeeuoeeQ
>> "%B64FILE%" echo huWRmOi/kOihjC5iYXTjgI3ph43lu7rkuIDkuKrlkK/liqjpobnjgIInDQogICAgV3JpdGUtSG9z
>> "%B64FILE%" echo dCAnJw0KICAgIFdyaXRlLUhvc3QgJ+aMieS7u+aEj+mUrumAgOWHui4uLicNCiAgICAkbnVsbCA9
>> "%B64FILE%" echo ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXkoJ05vRWNobyxJbmNsdWRlS2V5RG93bicpDQogICAgcmV0
>> "%B64FILE%" echo dXJuDQp9DQoNCldyaXRlLUhvc3QgKCLmib7liLAgezB9IOS4qu+8miIgLWYgJGl0ZW1zLkNvdW50
>> "%B64FILE%" echo KQ0KZm9yZWFjaCAoJHggaW4gJGl0ZW1zKSB7IFdyaXRlLUhvc3QgKCIgICAgezB9IiAtZiAkeC5Q
>> "%B64FILE%" echo YXRoKSB9DQoNCiMgLS0tLS0tLS0tLSDpgJDkuKrmoLjlr7kgLS0tLS0tLS0tLQ0KJGZpeGVkQ291
>> "%B64FILE%" echo bnQgPSAwDQokb2tDb3VudCA9IDANCiRmYWlsQ291bnQgPSAwDQoNCmZvcmVhY2ggKCRpdCBpbiAk
>> "%B64FILE%" echo aXRlbXMpIHsNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9zdCAoIsK3IHswfSIgLWYg
>> "%B64FILE%" echo JGl0LlBhdGgpIC1Gb3JlZ3JvdW5kQ29sb3IgQ3lhbg0KDQogICAgJHdhbnREZXYgPSAnJw0KICAg
>> "%B64FILE%" echo IHRyeSB7ICR3YW50RGV2ID0gR2V0LVZoZEJjZERldmljZSAkaXQuUGF0aCB9DQogICAgY2F0Y2gg
>> "%B64FILE%" echo eyBXcml0ZS1Mb2cgIui3r+W+hOaXoOaViDogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiICdFUlIn
>> "%B64FILE%" echo OyAkZmFpbENvdW50Kys7IGNvbnRpbnVlIH0NCiAgICAkd2FudEZ1bGwgPSBbU3lzdGVtLklPLlBh
>> "%B64FILE%" echo dGhdOjpHZXRGdWxsUGF0aCgkaXQuUGF0aCkNCg0KICAgICRlbiA9IEludm9rZS1CY2QgLUJjZEFy
>> "%B64FILE%" echo Z3MgQCgnL2VudW0nLCAkaXQuR3VpZCkgLVRhZyAnZW51bScNCiAgICAkZ3VpZCA9ICRpdC5HdWlk
>> "%B64FILE%" echo DQoNCiAgICAjIOadoeebruS4jeWtmOWcqCDihpIg6KGl5LiA5p2hDQogICAgaWYgKC1ub3QgJGVu
>> "%B64FILE%" echo Lk9rKSB7DQogICAgICAgIFdyaXRlLUxvZyAi6I+c5Y2V6YeM5rKh5pyJ6L+Z5Liq5p2h55uu77yI
>> "%B64FILE%" echo JGd1aWTvvInvvIzooaXkuIDmnaEiICdXQVJOJw0KICAgICAgICAkZGVzYyA9ICRpdC5EZXNjDQog
>> "%B64FILE%" echo ICAgICAgIGlmICgtbm90ICRkZXNjKSB7ICRkZXNjID0gJGl0Lk5hbWUgfQ0KICAgICAgICBpZiAo
>> "%B64FILE%" echo LW5vdCAkZGVzYykgeyAkZGVzYyA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lV2l0aG91
>> "%B64FILE%" echo dEV4dGVuc2lvbigkaXQuUGF0aCkgfQ0KDQogICAgICAgICRjcCA9IEludm9rZS1CY2QgLUJjZEFy
>> "%B64FILE%" echo Z3MgQCgnL2NvcHknLCAne2N1cnJlbnR9JywgJy9kJywgJGRlc2MpIC1UYWcgJ2NvcHknDQogICAg
>> "%B64FILE%" echo ICAgIGlmICgtbm90ICRjcC5PaykgeyAkY3AgPSBJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9jb3B5
>> "%B64FILE%" echo JywgJ3tkZWZhdWx0fScsICcvZCcsICRkZXNjKSAtVGFnICdjb3B5LWRlZmF1bHQnIH0NCiAgICAg
>> "%B64FILE%" echo ICAgJGdtID0gW3JlZ2V4XTo6TWF0Y2goJGNwLlJhdywgJ1x7WzAtOWEtZkEtRl17OH0tWzAtOWEt
>> "%B64FILE%" echo ZkEtRl17NH0tWzAtOWEtZkEtRl17NH0tWzAtOWEtZkEtRl17NH0tWzAtOWEtZkEtRl17MTJ9XH0n
>> "%B64FILE%" echo KQ0KICAgICAgICBpZiAoLW5vdCAkZ20uU3VjY2Vzcykgew0KICAgICAgICAgICAgV3JpdGUtTG9n
>> "%B64FILE%" echo ICLooaXmnaHnm67lpLHotKXvvJokKCRjcC5UZXh0KSIgJ0VSUicNCiAgICAgICAgICAgICRmYWls
>> "%B64FILE%" echo Q291bnQrKw0KICAgICAgICAgICAgY29udGludWUNCiAgICAgICAgfQ0KICAgICAgICAkZ3VpZCA9
>> "%B64FILE%" echo ICRnbS5WYWx1ZQ0KICAgICAgICBbdm9pZF0oSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvc2V0Jywg
>> "%B64FILE%" echo JGd1aWQsICdkZXZpY2UnLCAgICR3YW50RGV2KSAtVGFnICdzZXQtZGV2aWNlJykNCiAgICAgICAg
>> "%B64FILE%" echo W3ZvaWRdKEludm9rZS1CY2QgLUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAnb3NkZXZpY2UnLCAk
>> "%B64FILE%" echo d2FudERldikgLVRhZyAnc2V0LW9zZGV2aWNlJykNCiAgICAgICAgW3ZvaWRdKEludm9rZS1CY2Qg
>> "%B64FILE%" echo LUJjZEFyZ3MgQCgnL3NldCcsICRndWlkLCAncGF0aCcsICdcV2luZG93c1xzeXN0ZW0zMlx3aW5s
>> "%B64FILE%" echo b2FkLmVmaScpIC1UYWcgJ3NldC1wYXRoJykNCg0KICAgICAgICAjIOeKtuaAgeaWh+S7tumHjOea
>> "%B64FILE%" echo hCBHVUlEIOaNouaIkOaWsOeahO+8jOWNuOi9veaXtuaJjeaJvuW+l+WIsA0KICAgICAgICB0cnkg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgJHR4dCA9IFtTeXN0ZW0uSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRpdC5T
>> "%B64FILE%" echo dGF0ZSwgW1N5c3RlbS5UZXh0LkVuY29kaW5nXTo6VVRGOCkNCiAgICAgICAgICAgICR0eHQgPSBb
>> "%B64FILE%" echo cmVnZXhdOjpSZXBsYWNlKCR0eHQsICcoP20pXkd1aWQ9LionLCAiR3VpZD0kZ3VpZCIpDQogICAg
>> "%B64FILE%" echo ICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJGl0LlN0YXRlLCAkdHh0LCAo
>> "%B64FILE%" echo TmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJHRydWUpKSkNCiAgICAgICAgICAg
>> "%B64FILE%" echo IFdyaXRlLUxvZyAi54q25oCB5paH5Lu25bey5pu05paw5Li65pawIEdVSUQiICdPSycNCiAgICAg
>> "%B64FILE%" echo ICAgfSBjYXRjaCB7IFdyaXRlLUxvZyAi5YaZ54q25oCB5paH5Lu25aSx6LSl77yI5LiN5b2x5ZON
>> "%B64FILE%" echo 5byA5py677yJ77yaJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiICdXQVJOJyB9DQoNCiAgICAgICAg
>> "%B64FILE%" echo JGVuID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZW51bScsICRndWlkKSAtVGFnICd2ZXJpZnkn
>> "%B64FILE%" echo DQogICAgICAgICRmaXhlZENvdW50KysNCiAgICB9DQoNCiAgICAjIOaguOWvuSBkZXZpY2Ug5oyH
>> "%B64FILE%" echo 5ZCR55qE6Lev5b6EDQogICAgIyDkuI3kvp3otZblrZfmrrXlkI3vvIjlvrfor60gR2Vyw6R044CB
>> "%B64FILE%" echo 5pel6K+tIOODh+ODkOOCpOOCueOAgeS4reaWhyDorr7lpIfvvInvvJrluKYgdmhkPSDnmoTlj6rm
>> "%B64FILE%" echo nIkgZGV2aWNlIOmCo+S4gOihjA0KICAgICRkbSA9IFtyZWdleF06Ok1hdGNoKCRlbi5SYXcsICco
>> "%B64FILE%" echo P2ltKV5bXlxyXG5dKj8odmhkPVxbW15cclxuXSspJykNCiAgICAkY3VyRGV2ID0gJycNCiAgICBp
>> "%B64FILE%" echo ZiAoJGRtLlN1Y2Nlc3MpIHsgJGN1ckRldiA9ICRkbS5Hcm91cHNbMV0uVmFsdWUuVHJpbSgpIH0N
>> "%B64FILE%" echo CiAgICAkY3VyRnVsbCA9IEdldC1GdWxsUGF0aEZyb21CY2REZXZpY2UgJGN1ckRldg0KDQogICAg
>> "%B64FILE%" echo aWYgKFRlc3QtQmNkVGV4dFNhbWUgJHdhbnRGdWxsICRjdXJGdWxsKSB7DQogICAgICAgIFdyaXRl
>> "%B64FILE%" echo LUxvZyAi5oyH5ZCR5q2j56Gu77yaJGN1ckRldiIgJ09LJw0KICAgICAgICAkb2tDb3VudCsrDQog
>> "%B64FILE%" echo ICAgfSBlbHNlIHsNCiAgICAgICAgV3JpdGUtTG9nICgi5oyH5ZCR5LiN5a+544CC546w5Zyo5piv
>> "%B64FILE%" echo IFt7MH1d77yM5bqU6K+l5pivIFt7MX1dIiAtZiAkY3VyRGV2LCAkd2FudERldikgJ1dBUk4nDQog
>> "%B64FILE%" echo ICAgICAgIFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9zZXQnLCAkZ3VpZCwgJ2Rldmlj
>> "%B64FILE%" echo ZScsICAgJHdhbnREZXYpIC1UYWcgJ2ZpeC1kZXZpY2UnKQ0KICAgICAgICBbdm9pZF0oSW52b2tl
>> "%B64FILE%" echo LUJjZCAtQmNkQXJncyBAKCcvc2V0JywgJGd1aWQsICdvc2RldmljZScsICR3YW50RGV2KSAtVGFn
>> "%B64FILE%" echo ICdmaXgtb3NkZXZpY2UnKQ0KICAgICAgICAkY2hrID0gSW52b2tlLUJjZCAtQmNkQXJncyBAKCcv
>> "%B64FILE%" echo ZW51bScsICRndWlkKSAtVGFnICdyZWNoZWNrJw0KICAgICAgICAkZG0yID0gW3JlZ2V4XTo6TWF0
>> "%B64FILE%" echo Y2goJGNoay5SYXcsICcoP2ltKV5bXlxyXG5dKj8odmhkPVxbW15cclxuXSspJykNCiAgICAgICAg
>> "%B64FILE%" echo JG5vd0RldiA9ICcnDQogICAgICAgIGlmICgkZG0yLlN1Y2Nlc3MpIHsgJG5vd0RldiA9ICRkbTIu
>> "%B64FILE%" echo R3JvdXBzWzFdLlZhbHVlLlRyaW0oKSB9DQogICAgICAgICRub3dGdWxsID0gR2V0LUZ1bGxQYXRo
>> "%B64FILE%" echo RnJvbUJjZERldmljZSAkbm93RGV2DQogICAgICAgIGlmIChUZXN0LUJjZFRleHRTYW1lICR3YW50
>> "%B64FILE%" echo RnVsbCAkbm93RnVsbCkgew0KICAgICAgICAgICAgV3JpdGUtTG9nICLlt7LmlLnmraPvvJokbm93
>> "%B64FILE%" echo RGV2IiAnT0snDQogICAgICAgICAgICAkZml4ZWRDb3VudCsrDQogICAgICAgIH0gZWxzZSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICBXcml0ZS1Mb2cgKCLmlLnlrozov5jmmK/kuI3lr7nvvIznjrDlnKggW3swfV0i
>> "%B64FILE%" echo IC1mICRub3dEZXYpICdFUlInDQogICAgICAgICAgICBXcml0ZS1Mb2cgJ+WmguaenOmCo+mHjOaY
>> "%B64FILE%" echo r+OAjD/jgI3ogIzot6/lvoTmnKzmnaXmnInkuK3mlofvvIzlj6rmmK/mjqfliLblj7Dku6PnoIHp
>> "%B64FILE%" echo obXnmoTmmL7npLrpl67popjvvJrlhYggY2hjcCA5MzYg5YaNIGJjZGVkaXQgL2VudW0g55yL5LiA
>> "%B64FILE%" echo 55y844CCJyAnRVJSJw0KICAgICAgICAgICAgV3JpdGUtTG9nICflpoLmnpznoa7lrp7mjIfliLDl
>> "%B64FILE%" echo iKvlpITvvIzmioromZrmi5/no4Hnm5jmjKrliLDnuq/oi7Hmlofnm67lvZXvvIjlpoIgRDpcVkhE
>> "%B64FILE%" echo 77yJ5YaN6YeN5paw6KOF5LiA5qyh5pyA56iz44CCJyAnRVJSJw0KICAgICAgICAgICAgJGZhaWxD
>> "%B64FILE%" echo b3VudCsrDQogICAgICAgICAgICBjb250aW51ZQ0KICAgICAgICB9DQogICAgfQ0KDQogICAgIyDn
>> "%B64FILE%" echo oa7kv53lroPov5vkuoblvIDmnLroj5zljZXnmoTmmL7npLrpobrluo8NCiAgICAkYm0gPSBJbnZv
>> "%B64FILE%" echo a2UtQmNkIC1CY2RBcmdzIEAoJy9lbnVtJywgJ3tib290bWdyfScpIC1UYWcgJ2Jvb3RtZ3InDQog
>> "%B64FILE%" echo ICAgJG9tID0gW3JlZ2V4XTo6TWF0Y2goJGJtLlJhdywgJyg/aW0pXlxzKig/OmRpc3BsYXlvcmRl
>> "%B64FILE%" echo cnzmmL7npLrpobrluo8pXHMrKC4rPylccyokJykNCiAgICAkb3JkZXIgPSAnJw0KICAgIGlmICgk
>> "%B64FILE%" echo b20uU3VjY2VzcykgeyAkb3JkZXIgPSAkb20uR3JvdXBzWzFdLlZhbHVlIH0NCg0KICAgIGlmICgk
>> "%B64FILE%" echo b3JkZXIgLW5vdG1hdGNoIFtyZWdleF06OkVzY2FwZSgkZ3VpZCkpIHsNCiAgICAgICAgJGFkID0g
>> "%B64FILE%" echo SW52b2tlLUJjZCAtQmNkQXJncyBAKCcvZGlzcGxheW9yZGVyJywgJGd1aWQsICcvYWRkbGFzdCcp
>> "%B64FILE%" echo IC1UYWcgJ2Rpc3BsYXlvcmRlcicNCiAgICAgICAgaWYgKCRhZC5Paykgew0KICAgICAgICAgICAg
>> "%B64FILE%" echo V3JpdGUtTG9nICflt7LliqDlm57lvIDmnLroj5zljZXvvIjmjpLlnKjmnIDlkI7vvIknICdPSycN
>> "%B64FILE%" echo CiAgICAgICAgICAgICRmaXhlZENvdW50KysNCiAgICAgICAgfSBlbHNlIHsNCiAgICAgICAgICAg
>> "%B64FILE%" echo IFdyaXRlLUxvZyAi5Yqg5Zue5pi+56S66aG65bqP5aSx6LSl77yaJCgkYWQuVGV4dCkiICdFUlIn
>> "%B64FILE%" echo DQogICAgICAgICAgICAkZmFpbENvdW50KysNCiAgICAgICAgfQ0KICAgICAgICAkYm0gPSBJbnZv
>> "%B64FILE%" echo a2UtQmNkIC1CY2RBcmdzIEAoJy9lbnVtJywgJ3tib290bWdyfScpIC1UYWcgJ2Jvb3RtZ3IyJw0K
>> "%B64FILE%" echo ICAgICAgICAkb20gPSBbcmVnZXhdOjpNYXRjaCgkYm0uUmF3LCAnKD9pbSleXHMqKD86ZGlzcGxh
>> "%B64FILE%" echo eW9yZGVyfOaYvuekuumhuuW6jylccysoLis/KVxzKiQnKQ0KICAgICAgICBpZiAoJG9tLlN1Y2Nl
>> "%B64FILE%" echo c3MpIHsgJG9yZGVyID0gJG9tLkdyb3Vwc1sxXS5WYWx1ZSB9DQogICAgfSBlbHNlIHsNCiAgICAg
>> "%B64FILE%" echo ICAgV3JpdGUtTG9nICfmmL7npLrpobrluo/ph4zmnInlroMnICdPSycNCiAgICB9DQoNCiAgICAj
>> "%B64FILE%" echo IOiPnOWNleW+l+aYr+aJk+W8gOeahO+8jOWQpuWImeW8gOacuuebtOaOpei/m+m7mOiupOezu+e7
>> "%B64FILE%" echo n++8jOeci+S4jeWIsOi/meS6m+mAiemhuQ0KICAgICRlbnRyeUNvdW50ID0gKFtyZWdleF06Ok1h
>> "%B64FILE%" echo dGNoZXMoJG9yZGVyLCAnXHsnKSkuQ291bnQNCiAgICBpZiAoJGVudHJ5Q291bnQgLWdlIDIpIHsN
>> "%B64FILE%" echo CiAgICAgICAgJGRibSA9IFtyZWdleF06Ok1hdGNoKCRibS5SYXcsICcoP2ltKV5ccyooPzpkaXNw
>> "%B64FILE%" echo bGF5Ym9vdG1lbnV85pi+56S65ZCv5Yqo6I+c5Y2VKVxzKyhcUyspJykNCiAgICAgICAgJHRtbyA9
>> "%B64FILE%" echo IFtyZWdleF06Ok1hdGNoKCRibS5SYXcsICcoP2ltKV5ccyp0aW1lb3V0XHMrKFxkKyknKQ0KICAg
>> "%B64FILE%" echo ICAgICAkbmVlZE1lbnUgPSAkZmFsc2UNCiAgICAgICAgaWYgKC1ub3QgJGRibS5TdWNjZXNzKSB7
>> "%B64FILE%" echo ICRuZWVkTWVudSA9ICR0cnVlIH0NCiAgICAgICAgZWxzZWlmICgkZGJtLkdyb3Vwc1sxXS5WYWx1
>> "%B64FILE%" echo ZSAtbm90bWF0Y2ggJ14oP2k6eWVzKSQnKSB7ICRuZWVkTWVudSA9ICR0cnVlIH0NCiAgICAgICAg
>> "%B64FILE%" echo JG5lZWRUaW1lb3V0ID0gKCR0bW8uU3VjY2VzcyAtYW5kIChbaW50XSR0bW8uR3JvdXBzWzFdLlZh
>> "%B64FILE%" echo bHVlIC1lcSAwKSkNCg0KICAgICAgICBpZiAoJG5lZWRNZW51IC1vciAkbmVlZFRpbWVvdXQpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgIFt2b2lkXShJbnZva2UtQmNkIC1CY2RBcmdzIEAoJy9zZXQnLCAne2Jvb3Rt
>> "%B64FILE%" echo Z3J9JywgJ2Rpc3BsYXlib290bWVudScsICdZZXMnKSAtVGFnICdtZW51LW9uJykNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIGlmICgkbmVlZFRpbWVvdXQpIHsNCiAgICAgICAgICAgICAgICBbdm9pZF0oSW52b2tlLUJj
>> "%B64FILE%" echo ZCAtQmNkQXJncyBAKCcvc2V0JywgJ3tib290bWdyfScsICd0aW1lb3V0JywgJzEwJykgLVRhZyAn
>> "%B64FILE%" echo dGltZW91dC0xMCcpDQogICAgICAgICAgICB9DQogICAgICAgICAgICBXcml0ZS1Mb2cgJ+W8gOac
>> "%B64FILE%" echo uuiPnOWNleW3suaJk+W8gO+8iOS4jeeEtuagueacrOeci+S4jeWIsOmAiemhue+8iScgJ09LJw0K
>> "%B64FILE%" echo ICAgICAgICAgICAgJGZpeGVkQ291bnQrKw0KICAgICAgICB9DQogICAgfQ0KfQ0KDQojIC0tLS0t
>> "%B64FILE%" echo LS0tLS0g57uT6K66IC0tLS0tLS0tLS0NCldyaXRlLUhvc3QgJycNCldyaXRlLUhvc3QgJz09PT09
>> "%B64FILE%" echo PT09PT09PT09PT0g57uT5p6cID09PT09PT09PT09PT09PT0nDQpXcml0ZS1Ib3N0ICgiICDmnKzm
>> "%B64FILE%" echo naXlsLHlr7nvvJp7MH0g5LiqIiAtZiAkb2tDb3VudCkNCldyaXRlLUhvc3QgKCIgIOW3suS/ruWl
>> "%B64FILE%" echo vSAg77yaezB9IOWkhCIgLWYgJGZpeGVkQ291bnQpIC1Gb3JlZ3JvdW5kQ29sb3IgR3JlZW4NCldy
>> "%B64FILE%" echo aXRlLUhvc3QgKCIgIOayoeS/ruWlvSAg77yaezB9IOS4qiIgLWYgJGZhaWxDb3VudCkgLUZvcmVn
>> "%B64FILE%" echo cm91bmRDb2xvciAkKGlmICgkZmFpbENvdW50IC1ndCAwKSB7ICdSZWQnIH0gZWxzZSB7ICdHcmF5
>> "%B64FILE%" echo JyB9KQ0KV3JpdGUtSG9zdCAnJw0KaWYgKCRmaXhlZENvdW50IC1ndCAwKSB7DQogICAgV3JpdGUt
>> "%B64FILE%" echo SG9zdCAn6YeN5ZCv55S16ISR77yM5byA5py66I+c5Y2V6YeM5bqU6K+l5bCx6IO955yL5Yiw5bm2
>> "%B64FILE%" echo 6L+b5YWl6L+Z5Lqb57O757uf5LqG44CCJyAtRm9yZWdyb3VuZENvbG9yIEdyZWVuDQp9IGVsc2Vp
>> "%B64FILE%" echo ZiAoJGZhaWxDb3VudCAtZXEgMCAtYW5kICRva0NvdW50IC1ndCAwKSB7DQogICAgV3JpdGUtSG9z
>> "%B64FILE%" echo dCAn6I+c5Y2V5oyH5ZCR6YO95piv5a+555qE77yM5LiN55So5L+u44CC5aaC5p6c5byA5py66L+Y
>> "%B64FILE%" echo 5piv55yL5LiN5Yiw6I+c5Y2V77yMJw0KICAgIFdyaXRlLUhvc3QgJ+WPr+iDveaYr+WbuuS7tuay
>> "%B64FILE%" echo oeS7jui/meWdl+ebmOeahCBFU1Ag5ZCv5Yqo77yM5oiW5piv6I+c5Y2V6LaF5pe25aSq55+t77yM
>> "%B64FILE%" echo 6L+e5oyJ5pa55ZCR6ZSu6K+V6K+V44CCJw0KfSBlbHNlIHsNCiAgICBXcml0ZS1Ib3N0ICfmnInm
>> "%B64FILE%" echo sqHkv67lpb3nmoTpobnvvIzmiorkuIvpnaLnmoTml6Xlv5flj5Hnu5nmiJHnnIvnnIvjgIInIC1G
>> "%B64FILE%" echo b3JlZ3JvdW5kQ29sb3IgWWVsbG93DQp9DQpXcml0ZS1Ib3N0ICcnDQpXcml0ZS1Ib3N0ICgi5pel
>> "%B64FILE%" echo 5b+X77yaezB9IiAtZiAkU2NyaXB0OkxvZ0ZpbGUpDQpXcml0ZS1Ib3N0ICcnDQpXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICfmjInku7vmhI/plK7pgIDlh7ouLi4nDQokbnVsbCA9ICRIb3N0LlVJLlJhd1VJLlJlYWRLZXko
>> "%B64FILE%" echo J05vRWNobyxJbmNsdWRlS2V5RG93bicpDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=21116"
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
