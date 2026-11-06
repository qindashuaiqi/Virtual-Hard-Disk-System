@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 新系统清理幽灵显卡
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
set "PS1FILE=%WORKDIR%\新系统-清理幽灵显卡.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oKQ0KDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PQ0KIyDmlrDns7vnu58g5pi+5Y2h5L2T5qOA5LiO5pW055CGICAg
>> "%B64FILE%" echo djIuMA0KIyDkvZzogIU6IGNvbm5lY3RzZWdhYm90DQojDQojIOWcqOWTqui/kOihjO+8mioq5paw
>> "%B64FILE%" echo 6KOF55qE6YKj5Liq6Jma5ouf57O757uf6YeMKirvvIjkuI3mmK/ljp/mnaXnmoTns7vnu5/vvInj
>> "%B64FILE%" echo gIINCiMNCiMgdjEuMCDnmoTplJnor6/vvIjnlKjmiLflrp7pmYXlj43ppojjgIzmoLnmnKzmsqHl
>> "%B64FILE%" echo iKDmjonlub3ngbXmmL7ljaHjgI3vvInvvJoNCiMgICAxLiDmiorku7vliqHnrqHnkIblmajph4zn
>> "%B64FILE%" echo moTjgIznqbogR1BV44CN5b2T5oiQ5bm954G15Y2h44CC5YW25a6e5Lu75Yqh566h55CG5Zmo55qE
>> "%B64FILE%" echo IEdQVSDliJfooajlj6rmnprkuL4NCiMgICAgICAqKuato+WcqOa0u+WKqOeahOmAgumFjeWZqCoq
>> "%B64FILE%" echo 77yM5bm954G16K6+5aSH77yI6K6+5aSH5bey5LiN5Zyo5pys5py677yJ5LuO5p2l5LiN5Lya5Ye6
>> "%B64FILE%" echo 546w5Zyo6YKj6YeM44CCDQojICAgICAg55yf5q2j5Y2g552A5L2N572u55qE5pivIFJPT1RcRElT
>> "%B64FILE%" echo UExBWSDmnprkuL7nmoQgKipJREQg6Jma5ouf5pi+56S65ZmoKioNCiMgICAgICDvvIjov5znqIvk
>> "%B64FILE%" echo uLLmtYEgLyDmqKHmi5/lmajpgqPnsbvova/ku7boo4XnmoTvvIxTZXJ2aWNlPVdVREZSZO+8jOay
>> "%B64FILE%" echo oeacieecn+WuniBEWCDlvJXmk47vvIwNCiMgICAgICDmiYDku6XmmL7lrZjjgIEzROOAgVZpZGVv
>> "%B64FILE%" echo IOWFqOaYr+epuueahO+8ieOAgg0KIyAgIDIuIOWPquS/oSBwbnB1dGlsIOeahOmAgOWHuueggeOA
>> "%B64FILE%" echo gnBucHV0aWwgL3JlbW92ZS1kZXZpY2Ug5a+5IG5vbi1wcmVzZW50IOiuvuWkhw0KIyAgICAgIOS8
>> "%B64FILE%" echo mui/lOWbniAweDAg5L2G5YW25a6e5LuA5LmI6YO95rKh5Yig77yM5oql5ZGK5YaZ44CM5Yig6Zmk
>> "%B64FILE%" echo 5oiQ5YqfIDMg5Liq44CN6ICM6K6w5b2V6L+Y5Zyo44CCDQojICAgICAgdjIuMCDliKDlrozlv4Xp
>> "%B64FILE%" echo obvph43mlrDmnprkuL7lpI3moLjvvIzmiqXlkYrph4znm7TmjqXlhpnjgIzlt7LmtojlpLEgLyDk
>> "%B64FILE%" echo u43lnKjjgI3jgIINCiMgICAzLiDliKDpmaTpobrluo/lj43kuobjgIJSZW1vdmUtUG5wRGV2aWNl
>> "%B64FILE%" echo IOi1sCBESUZfUkVNT1ZF77yM6IO95aSE55CG5LiN5Zyo5L2N55qE6K6+5aSH77ybDQojICAgICAg
>> "%B64FILE%" echo cG5wdXRpbCDlj6rmmK/lroPnmoTooaXlhYXjgIJ2MS4wIOWFiOivlSBwbnB1dGlsIOS4lOWIpOaI
>> "%B64FILE%" echo kOWKn+Wwsei3s+i/h++8jOetieS6juawuOi/nOS4jeS/ruOAgg0KIw0KIyDnu5Pmnpzmlofku7bv
>> "%B64FILE%" echo vJo85p+Q5Liq55uYPjpc5pi+5Y2h6K+K5patLnR4dA0KIyA9PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KJEVycm9yQWN0aW9uUHJl
>> "%B64FILE%" echo ZmVyZW5jZSA9ICdDb250aW51ZScNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjM0Jw0KdHJ5IHsgJEhv
>> "%B64FILE%" echo c3QuVUkuUmF3VUkuV2luZG93VGl0bGUgPSAi5paw57O757ufIOaYvuWNoeS9k+ajgCB2JCgkU2Ny
>> "%B64FILE%" echo aXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3QiIH0gY2F0Y2gge30NCg0KIyBbdjEuMzJdIOWF
>> "%B64FILE%" echo seS6q+aooeWdl+OAguaJk+WMheaXtueUsSBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSDlhoXo
>> "%B64FILE%" echo gZTmnKzmlofku7bvvIwNCiMgLmJhdCDovb3ojbfku43mmK/oh6rljIXlkKvljZXmlofku7bjgIIN
>> "%B64FILE%" echo CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09DQojIOWFseS6q+aXpeW/l+WHveaVsCAgIHYxLjMyDQojDQojIOacrOaWh+S7tuS4jeaY
>> "%B64FILE%" echo r+WPkeW4g+eJqeOAguaJk+WMhSAuYmF0IOi9veiNt+aXtu+8jHNyYy9idWlsZC9pbmxpbmVfc2hh
>> "%B64FILE%" echo cmVkLnB5IOS8muaKiui/memHjOeahA0KIyDlhoXlrrnlhoXogZTov5vmr4/kuKrlhaXlj6PohJrm
>> "%B64FILE%" echo nKzvvIzkv53or4Hlj5HluIPlh7rljrvnmoTlkK/liqjlmajku43mmK/oh6rljIXlkKvljZXmlofk
>> "%B64FILE%" echo u7YNCiMg77yI6Ieq6Kej5Y6LIGJhdCDlnKjov5DooYzmnJ/msqHlip7ms5XlvJXnlKjlpJbpg6jm
>> "%B64FILE%" echo qKHlnZfvvInjgIINCiMNCiMg6KeE55+p77ya5Y+q5pS56L+Z6YeM77yM5LiN6KaB5YaN5oqK6L+Z
>> "%B64FILE%" echo 5Lqb5Ye95pWw5aSN5Yi25Zue5YWl5Y+j6ISa5pys44CCDQojID09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQpmdW5jdGlvbiBTYXkg
>> "%B64FILE%" echo ew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtzdHJpbmddJENvbG9yID0gJ0dyYXknKQ0KICAg
>> "%B64FILE%" echo IFdyaXRlLUhvc3QgJFRleHQgLUZvcmVncm91bmRDb2xvciAkQ29sb3INCn0NCg0KU2F5ICIiDQpT
>> "%B64FILE%" echo YXkgIiAg5paw57O757ufIOaYvuWNoeS9k+ajgOS4juaVtOeQhiAgdiQoJFNjcmlwdDpWZXJzaW9u
>> "%B64FILE%" echo KSIgJ0N5YW4nDQpTYXkgIiAg5L2c6ICFOiBjb25uZWN0c2VnYWJvdCIgJ0RhcmtHcmF5Jw0KU2F5
>> "%B64FILE%" echo ICIgIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLSIgJ0RhcmtHcmF5Jw0KU2F5ICIiDQoNCiRhZG1pbiA9IChbU2VjdXJpdHkuUHJpbmNp
>> "%B64FILE%" echo cGFsLldpbmRvd3NQcmluY2lwYWxdW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzSWRlbnRpdHld
>> "%B64FILE%" echo OjpHZXRDdXJyZW50KCkpLklzSW5Sb2xlKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0
>> "%B64FILE%" echo SW5Sb2xlXTo6QWRtaW5pc3RyYXRvcikNCmlmICgtbm90ICRhZG1pbikgew0KICAgIFNheSAiICBb
>> "%B64FILE%" echo 6ZSZ6K+vXSDpnIDopoHnrqHnkIblkZjmnYPpmZDjgILor7flj7PplK4gLT4g5Lul566h55CG5ZGY
>> "%B64FILE%" echo 6Lqr5Lu96L+Q6KGM44CCIiAnUmVkJw0KICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oi
>> "%B64FILE%" echo DQogICAgZXhpdCAxDQp9DQoNCiRyZXBvcnQgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9u
>> "%B64FILE%" echo cy5BcnJheUxpc3QNCmZ1bmN0aW9uIEFkZC1MaW5lIHsgcGFyYW0oW3N0cmluZ10kVCA9ICcnKSBb
>> "%B64FILE%" echo dm9pZF0kcmVwb3J0LkFkZCgkVCkgfQ0KDQokb3MgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3Bl
>> "%B64FILE%" echo cmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQpBZGQtTGluZSAiPT09
>> "%B64FILE%" echo PT09PT09PT09PT09IOaYvuWNoeiviuaWrSB2JCgkU2NyaXB0OlZlcnNpb24pID09PT09PT09PT09
>> "%B64FILE%" echo PT09PSINCkFkZC1MaW5lICgi6K6h566X5py65ZCNIDogIiArICRlbnY6Q09NUFVURVJOQU1FKQ0K
>> "%B64FILE%" echo QWRkLUxpbmUgKCLns7vnu58gICAgIDogIiArICRvcy5DYXB0aW9uICsgIiAgQnVpbGQgIiArICRv
>> "%B64FILE%" echo cy5CdWlsZE51bWJlcikNCkFkZC1MaW5lICgi57O757uf55uYICAgOiAiICsgJGVudjpTeXN0ZW1E
>> "%B64FILE%" echo cml2ZSkNCkFkZC1MaW5lICIiDQoNCmZ1bmN0aW9uIEdldC1Qcm9ibGVtVGV4dCB7DQogICAgcGFy
>> "%B64FILE%" echo YW0oW2ludF0kQ29kZSkNCiAgICBzd2l0Y2ggKCRDb2RlKSB7DQogICAgICAgIDAgIHsgcmV0dXJu
>> "%B64FILE%" echo ICfmraPluLgnIH0NCiAgICAgICAgMyAgeyByZXR1cm4gJ+mpseWKqOW3suaNn+WdjycgfQ0KICAg
>> "%B64FILE%" echo ICAgICAxMCB7IHJldHVybiAn6K6+5aSH5peg5rOV5ZCv5YqoJyB9DQogICAgICAgIDE4IHsgcmV0
>> "%B64FILE%" echo dXJuICfpnIDopoHph43mlrDlronoo4XpqbHliqgnIH0NCiAgICAgICAgMjIgeyByZXR1cm4gJ+W3
>> "%B64FILE%" echo suiiq+emgeeUqCcgfQ0KICAgICAgICAyOCB7IHJldHVybiAn6amx5Yqo5pyq5a6J6KOFJyB9DQog
>> "%B64FILE%" echo ICAgICAgIDMxIHsgcmV0dXJuICfpqbHliqjml6Dms5XliqDovb0nIH0NCiAgICAgICAgNDMgeyBy
>> "%B64FILE%" echo ZXR1cm4gJ+iuvuWkh+aKpeWRiuaVhemanOWQjuW3suWBnOatoicgfQ0KICAgICAgICA0NSB7IHJl
>> "%B64FILE%" echo dHVybiAn5bm954G16K6w5b2V77yI6K6+5aSH5LiN5Zyo5pys5py677yJJyB9DQogICAgICAgIGRl
>> "%B64FILE%" echo ZmF1bHQgeyByZXR1cm4gKCLpl67popjnoIEgIiArICRDb2RlKSB9DQogICAgfQ0KfQ0KDQojIC0t
>> "%B64FILE%" echo LS0tLS0tLS0gWzEvNV0g6YeH6ZuGIC0tLS0tLS0tLS0NClNheSAiWzEvNV0g6K+75Y+W5pi+56S6
>> "%B64FILE%" echo 6YCC6YWN5ZmoLi4uIiAnV2hpdGUnDQoNCiMg5ou/5Yiw5Lu75Yqh566h55CG5Zmo55yf5q2j5Lya
>> "%B64FILE%" echo 5p6a5Li+55qE6YKj5om577yI5rS75Yqo6YCC6YWN5Zmo77yJDQokYWN0aXZlTmFtZXMgPSBAKCkN
>> "%B64FILE%" echo CnRyeSB7DQogICAgZm9yZWFjaCAoJHZjIGluIEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1ZpZGVv
>> "%B64FILE%" echo Q29udHJvbGxlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYg
>> "%B64FILE%" echo KCR2Yy5OYW1lKSB7ICRhY3RpdmVOYW1lcyArPSBbc3RyaW5nXSR2Yy5OYW1lIH0NCiAgICB9DQp9
>> "%B64FILE%" echo IGNhdGNoIHt9DQoNCiRhZGFwdGVycyA9IEAoKQ0KZm9yZWFjaCAoJGQgaW4gQChHZXQtUG5wRGV2
>> "%B64FILE%" echo aWNlIC1DbGFzcyBEaXNwbGF5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAg
>> "%B64FILE%" echo IGlmICgtbm90ICRkKSB7IGNvbnRpbnVlIH0NCg0KICAgICRwcmVzZW50ID0gJGZhbHNlDQogICAg
>> "%B64FILE%" echo dHJ5IHsNCiAgICAgICAgJHYgPSAoR2V0LVBucERldmljZVByb3BlcnR5IC1JbnN0YW5jZUlkICRk
>> "%B64FILE%" echo Lkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0lzUHJlc2VudCcgLUVycm9yQWN0
>> "%B64FILE%" echo aW9uIFN0b3ApLkRhdGENCiAgICAgICAgaWYgKCR2IC1lcSAkdHJ1ZSkgeyAkcHJlc2VudCA9ICR0
>> "%B64FILE%" echo cnVlIH0NCiAgICB9IGNhdGNoIHt9DQoNCiAgICAkcHJvdiA9ICcnOyAkdmVyID0gJyc7ICRpbmYg
>> "%B64FILE%" echo PSAnJzsgJHN2YyA9ICcnDQogICAgdHJ5IHsgJHByb3YgPSBbc3RyaW5nXShHZXQtUG5wRGV2aWNl
>> "%B64FILE%" echo UHJvcGVydHkgLUluc3RhbmNlSWQgJGQuSW5zdGFuY2VJZCAtS2V5TmFtZSAnREVWUEtFWV9EZXZp
>> "%B64FILE%" echo Y2VfRHJpdmVyUHJvdmlkZXInIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRhIH0gY2F0Y2gge30NCiAg
>> "%B64FILE%" echo ICB0cnkgeyAkdmVyID0gW3N0cmluZ10oR2V0LVBucERldmljZVByb3BlcnR5IC1JbnN0YW5jZUlk
>> "%B64FILE%" echo ICRkLkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0RyaXZlclZlcnNpb24nIC1F
>> "%B64FILE%" echo cnJvckFjdGlvbiBTdG9wKS5EYXRhIH0gY2F0Y2gge30NCiAgICB0cnkgeyAkaW5mID0gW3N0cmlu
>> "%B64FILE%" echo Z10oR2V0LVBucERldmljZVByb3BlcnR5IC1JbnN0YW5jZUlkICRkLkluc3RhbmNlSWQgLUtleU5h
>> "%B64FILE%" echo bWUgJ0RFVlBLRVlfRGV2aWNlX0RyaXZlckluZlBhdGgnIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRh
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCiAgICB0cnkgeyAkc3ZjID0gW3N0cmluZ10oR2V0LVBucERldmljZVByb3Bl
>> "%B64FILE%" echo cnR5IC1JbnN0YW5jZUlkICRkLkluc3RhbmNlSWQgLUtleU5hbWUgJ0RFVlBLRVlfRGV2aWNlX1Nl
>> "%B64FILE%" echo cnZpY2UnIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRhIH0gY2F0Y2gge30NCg0KICAgICRodyA9IEAo
>> "%B64FILE%" echo KQ0KICAgIHRyeSB7DQogICAgICAgICRoID0gKEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFu
>> "%B64FILE%" echo Y2VJZCAkZC5JbnN0YW5jZUlkIC1LZXlOYW1lICdERVZQS0VZX0RldmljZV9IYXJkd2FyZUlkcycg
>> "%B64FILE%" echo LUVycm9yQWN0aW9uIFN0b3ApLkRhdGENCiAgICAgICAgaWYgKCRoKSB7ICRodyA9IEAoJGgpIH0N
>> "%B64FILE%" echo CiAgICB9IGNhdGNoIHt9DQoNCiAgICAkcHJvYiA9IDANCiAgICBpZiAoJGQuUHJvYmxlbSAtbmUg
>> "%B64FILE%" echo JG51bGwpIHsgJHByb2IgPSBbaW50XSRkLlByb2JsZW0gfQ0KDQogICAgIyDjgJDlhbPplK7jgJFJ
>> "%B64FILE%" echo REQg6Jma5ouf5pi+56S65Zmo55qE6K+G5Yir77yaUk9PVCDmnprkuL4gKyDnsbvmmK8gRGlzcGxh
>> "%B64FILE%" echo eSArIOeUqOaIt+aooeW8j+mpseWKqOahhuaetuOAgg0KICAgICMg6L+Z57G76K6+5aSH5piv6L2v
>> "%B64FILE%" echo 5Lu26YCg5Ye65p2l55qE5YGH5pi+5Y2h77yM5Lu75Yqh566h55CG5Zmo5Lya57uZ5a6D5LiA5Liq
>> "%B64FILE%" echo IEdQVSDkvY3vvIwNCiAgICAjIOS9humHjOmdouayoeacieS7u+S9leW8leaTji/mmL7lrZjmlbDm
>> "%B64FILE%" echo ja4g4oCU4oCUIOi/meWwseaYr+eUqOaIt+ivtOeahOOAjOepuiBHUFXjgI3jgIINCiAgICAkaXNS
>> "%B64FILE%" echo b290ID0gJGQuSW5zdGFuY2VJZCAtbGlrZSAnUk9PVFwqJw0KICAgICRpc0lkZCA9ICRmYWxzZQ0K
>> "%B64FILE%" echo ICAgIGlmICgkaXNSb290KSB7DQogICAgICAgIGlmICgkc3ZjIC1lcSAnV1VERlJkJyAtb3IgJHN2
>> "%B64FILE%" echo YyAtbGlrZSAnKklkZConIC1vciAkZC5GcmllbmRseU5hbWUgLWxpa2UgJypWaXJ0dWFsKicpIHsg
>> "%B64FILE%" echo JGlzSWRkID0gJHRydWUgfQ0KICAgICAgICBlbHNlIHsgJGlzSWRkID0gJHRydWUgfSAgICMgUk9P
>> "%B64FILE%" echo VFxESVNQTEFZIOWHuuadpeeahOmDveaYr+i9r+S7tumAgumFjeWZqA0KICAgIH0NCg0KICAgICRr
>> "%B64FILE%" echo aW5kID0gJycNCiAgICBpZiAoLW5vdCAkcHJlc2VudCkgeyAka2luZCA9ICflub3ngbUnIH0NCiAg
>> "%B64FILE%" echo ICBlbHNlaWYgKCRpc0lkZCkgeyAka2luZCA9ICfomZrmi5/mmL7npLrlmagnIH0NCiAgICBlbHNl
>> "%B64FILE%" echo aWYgKCRwcm9iIC1uZSAwKSB7ICRraW5kID0gJ+aVhemanCcgfQ0KICAgIGVsc2UgeyAka2luZCA9
>> "%B64FILE%" echo ICflnKjnlKgnIH0NCg0KICAgICRhZGFwdGVycyArPSBbcHNjdXN0b21vYmplY3RdQHsNCiAgICAg
>> "%B64FILE%" echo ICAgTmFtZSAgICAgICA9ICRkLkZyaWVuZGx5TmFtZQ0KICAgICAgICBJbnN0YW5jZUlkID0gJGQu
>> "%B64FILE%" echo SW5zdGFuY2VJZA0KICAgICAgICBTdGF0dXMgICAgID0gW3N0cmluZ10kZC5TdGF0dXMNCiAgICAg
>> "%B64FILE%" echo ICAgUHJlc2VudCAgICA9ICRwcmVzZW50DQogICAgICAgIFByb2JsZW0gICAgPSAkcHJvYg0KICAg
>> "%B64FILE%" echo ICAgICBLaW5kICAgICAgID0gJGtpbmQNCiAgICAgICAgSXNJZGQgICAgICA9ICRpc0lkZA0KICAg
>> "%B64FILE%" echo ICAgICBQcm92aWRlciAgID0gJHByb3YNCiAgICAgICAgVmVyc2lvbiAgICA9ICR2ZXINCiAgICAg
>> "%B64FILE%" echo ICAgSW5mICAgICAgICA9ICRpbmYNCiAgICAgICAgU2VydmljZSAgICA9ICRzdmMNCiAgICAgICAg
>> "%B64FILE%" echo SHdJZHMgICAgICA9ICRodw0KICAgIH0NCn0NCg0KJHJlYWxHcHUgPSBAKCRhZGFwdGVycyB8IFdo
>> "%B64FILE%" echo ZXJlLU9iamVjdCB7ICRfLktpbmQgLWVxICflnKjnlKgnIH0pDQokaWRkcyAgICA9IEAoJGFkYXB0
>> "%B64FILE%" echo ZXJzIHwgV2hlcmUtT2JqZWN0IHsgJF8uS2luZCAtZXEgJ+iZmuaLn+aYvuekuuWZqCcgfSkNCiRn
>> "%B64FILE%" echo aG9zdHMgID0gQCgkYWRhcHRlcnMgfCBXaGVyZS1PYmplY3QgeyAkXy5LaW5kIC1lcSAn5bm954G1
>> "%B64FILE%" echo JyB9KQ0KJGZhdWx0cyAgPSBAKCRhZGFwdGVycyB8IFdoZXJlLU9iamVjdCB7ICRfLktpbmQgLWVx
>> "%B64FILE%" echo ICfmlYXpmpwnIH0pDQokZGlzYWJsZWQgPSBAKCRhZGFwdGVycyB8IFdoZXJlLU9iamVjdCB7ICRf
>> "%B64FILE%" echo LlN0YXR1cyAtZXEgJ0Vycm9yJyAtYW5kICRfLlByb2JsZW0gLWVxIDIyIH0pDQoNCiMgLS0tLS0t
>> "%B64FILE%" echo LS0tLSBbMi81XSDmkYrlvIAgLS0tLS0tLS0tLQ0KU2F5ICJbMi81XSDliIbnsbvnu5PmnpwuLi4i
>> "%B64FILE%" echo DQpBZGQtTGluZSAiLS0tLS0tLS0tLSDmmL7npLrpgILphY3lmaggLS0tLS0tLS0tLSINCkFkZC1M
>> "%B64FILE%" echo aW5lICgi5YWxIHswfSDkuKrvvJrnnJ/lrp7lnKjnlKggezF9IC8g6Jma5ouf5pi+56S65ZmoIHsy
>> "%B64FILE%" echo fSAvIOW5veeBtSB7M30gLyDmlYXpmpwgezR9IiAtZiBgDQogICAgJGFkYXB0ZXJzLkNvdW50LCAk
>> "%B64FILE%" echo cmVhbEdwdS5Db3VudCwgJGlkZHMuQ291bnQsICRnaG9zdHMuQ291bnQsICRmYXVsdHMuQ291bnQp
>> "%B64FILE%" echo DQpBZGQtTGluZSAiIg0KU2F5ICgiICDlhbEgezB9IOS4qu+8muecn+WunuWcqOeUqCB7MX0gLyDo
>> "%B64FILE%" echo mZrmi5/mmL7npLrlmaggezJ9IC8g5bm954G1IHszfSAvIOaVhemanCB7NH0iIC1mIGANCiAgICAk
>> "%B64FILE%" echo YWRhcHRlcnMuQ291bnQsICRyZWFsR3B1LkNvdW50LCAkaWRkcy5Db3VudCwgJGdob3N0cy5Db3Vu
>> "%B64FILE%" echo dCwgJGZhdWx0cy5Db3VudCkgJ0N5YW4nDQpTYXkgIiINCg0KZm9yZWFjaCAoJGEgaW4gJGFkYXB0
>> "%B64FILE%" echo ZXJzKSB7DQogICAgJGNvbCA9ICdHcmF5Jw0KICAgIGlmICgkYS5LaW5kIC1lcSAn5Zyo55SoJykg
>> "%B64FILE%" echo ICAgICAgeyAkY29sID0gJ0dyZWVuJyB9DQogICAgaWYgKCRhLktpbmQgLWVxICfmlYXpmpwnKSAg
>> "%B64FILE%" echo ICAgICB7ICRjb2wgPSAnWWVsbG93JyB9DQogICAgaWYgKCRhLktpbmQgLWVxICfomZrmi5/mmL7n
>> "%B64FILE%" echo pLrlmagnKSB7ICRjb2wgPSAnTWFnZW50YScgfQ0KICAgIGlmICgkYS5LaW5kIC1lcSAn5bm954G1
>> "%B64FILE%" echo JykgICAgICAgeyAkY29sID0gJ0RhcmtHcmF5JyB9DQoNCiAgICBTYXkgKCIgIFt7MH1dIHsxfSIg
>> "%B64FILE%" echo LWYgJGEuS2luZCwgJGEuTmFtZSkgJGNvbA0KICAgIFNheSAoIiAgICAgICAg54q25oCBPXswfSAg
>> "%B64FILE%" echo 6amx5YqoPXsxfSB7Mn0gIElORj17M30iIC1mIChHZXQtUHJvYmxlbVRleHQgJGEuUHJvYmxlbSks
>> "%B64FILE%" echo ICRhLlByb3ZpZGVyLCAkYS5WZXJzaW9uLCAkYS5JbmYpICdEYXJrR3JheScNCiAgICBTYXkgKCIg
>> "%B64FILE%" echo ICAgICAgIOWunuS+iz17MH0iIC1mICRhLkluc3RhbmNlSWQpICdEYXJrR3JheScNCg0KICAgIEFk
>> "%B64FILE%" echo ZC1MaW5lICgiW3swfV0gezF9IiAtZiAkYS5LaW5kLCAkYS5OYW1lKQ0KICAgIEFkZC1MaW5lICgi
>> "%B64FILE%" echo ICAgIOeKtuaAgTogIiArIChHZXQtUHJvYmxlbVRleHQgJGEuUHJvYmxlbSkgKyAiICAoU3RhdHVz
>> "%B64FILE%" echo PSIgKyAkYS5TdGF0dXMgKyAiLCBQcmVzZW50PSIgKyAkYS5QcmVzZW50ICsgIikiKQ0KICAgIEFk
>> "%B64FILE%" echo ZC1MaW5lICgiICAgIOmpseWKqDogIiArICRhLlByb3ZpZGVyICsgIiAiICsgJGEuVmVyc2lvbiAr
>> "%B64FILE%" echo ICIgIElORj0iICsgJGEuSW5mICsgIiAgU2VydmljZT0iICsgJGEuU2VydmljZSkNCiAgICBBZGQt
>> "%B64FILE%" echo TGluZSAoIiAgICDlrp7kvos6ICIgKyAkYS5JbnN0YW5jZUlkKQ0KICAgIGlmICgkYS5Id0lkcy5D
>> "%B64FILE%" echo b3VudCAtZ3QgMCkgeyBBZGQtTGluZSAoIiAgICDnoazku7Y6ICIgKyAoJGEuSHdJZHMgLWpvaW4g
>> "%B64FILE%" echo JyA7ICcpKSB9DQogICAgQWRkLUxpbmUgIiINCn0NCg0KIyAtLS0tLS0tLS0tIFszLzVdIOe7k+iu
>> "%B64FILE%" echo uu+8muepuiBHUFUg5Yiw5bqV5piv6LCBIC0tLS0tLS0tLS0NClNheSAiWzMvNV0g5Yik5pat5Lu7
>> "%B64FILE%" echo 5Yqh566h55CG5Zmo6YeM6YKj5byg56m65Y2hLi4uIiAnV2hpdGUnDQpBZGQtTGluZSAiLS0tLS0t
>> "%B64FILE%" echo LS0tLSDnqbogR1BVIOeahOaIkOWboCAtLS0tLS0tLS0tIg0KDQppZiAoJGlkZHMuQ291bnQgLWd0
>> "%B64FILE%" echo IDApIHsNCiAgICBBZGQtTGluZSAoIuS7u+WKoeeuoeeQhuWZqOOAjOaAp+iDveOAjemhteWPquae
>> "%B64FILE%" echo muS4vioq5q2j5Zyo5rS75Yqo55qEKirmmL7npLrpgILphY3lmajvvIzkuI3kvJrkuLrlub3ngbXo
>> "%B64FILE%" echo rr7lpIfnlZnkvY3nva7jgIIiKQ0KICAgIEFkZC1MaW5lICgi5omA5Lul6YKj5byg5rKh5pyJ5pWw
>> "%B64FILE%" echo 5o2u55qE56m6IEdQVe+8jOecn+i6q+aYr+S4i+mdoui/meS6m+iZmuaLn+aYvuekuuWZqO+8iElE
>> "%B64FILE%" echo RO+8ie+8miIpDQogICAgZm9yZWFjaCAoJGkgaW4gJGlkZHMpIHsNCiAgICAgICAgQWRkLUxpbmUg
>> "%B64FILE%" echo KCIgICAgIiArICRpLk5hbWUgKyAiICAg5a6e5L6LPSIgKyAkaS5JbnN0YW5jZUlkICsgIiAgIElO
>> "%B64FILE%" echo Rj0iICsgJGkuSW5mKQ0KICAgIH0NCiAgICBBZGQtTGluZSAiIg0KICAgIEFkZC1MaW5lICLlroPk
>> "%B64FILE%" echo u6znlLHov5znqIvkuLLmtYEgLyDmqKHmi5/lmajov5nnsbvova/ku7blronoo4XvvIzmsqHmnInn
>> "%B64FILE%" echo nJ/lrp4gRFgg5byV5pOO77yM5pi+5a2Y5ZKMIDNEIOS9v+eUqOeOh+awuOi/nOaYr+epuueahOOA
>> "%B64FILE%" echo giINCiAgICBTYXkgKCIgIOepuiBHUFUgPSDomZrmi5/mmL7npLrlmajvvIh7MH0g5Liq77yJ77yM
>> "%B64FILE%" echo 5LiN5piv5bm954G15Y2hIiAtZiAkaWRkcy5Db3VudCkgJ1llbGxvdycNCn0NCmlmICgkZ2hvc3Rz
>> "%B64FILE%" echo LkNvdW50IC1ndCAwKSB7DQogICAgQWRkLUxpbmUgKCLlj6blpJbov5jmnIkgezB9IOS4quW5veeB
>> "%B64FILE%" echo teaYvuekuumAgumFjeWZqO+8iOWFi+mahumVnOWDj+W4puadpeeahOWOhuWPsuiusOW9le+8ie+8
>> "%B64FILE%" echo miIgLWYgJGdob3N0cy5Db3VudCkNCiAgICBmb3JlYWNoICgkZyBpbiAkZ2hvc3RzKSB7IEFkZC1M
>> "%B64FILE%" echo aW5lICgiICAgICIgKyAkZy5OYW1lICsgIiAgICIgKyAkZy5JbnN0YW5jZUlkKSB9DQogICAgQWRk
>> "%B64FILE%" echo LUxpbmUgIuW5veeBteiuvuWkh+S4jeS8muWHuueOsOWcqOS7u+WKoeeuoeeQhuWZqO+8jOWPquS8
>> "%B64FILE%" echo muWcqOOAjOaYvuekuumakOiXj+eahOiuvuWkh+OAjeaXtueci+WIsO+8jOWxnuS6juaXoOWus+au
>> "%B64FILE%" echo i+eVmeOAgiINCiAgICBTYXkgKCIgIOWPpuaciSB7MH0g5Liq5bm954G16K6w5b2V77yI5peg5a6z
>> "%B64FILE%" echo 77yM5Y+q5b2x5ZON6K6+5aSH566h55CG5Zmo6KeC5oSf77yJIiAtZiAkZ2hvc3RzLkNvdW50KSAn
>> "%B64FILE%" echo RGFya0dyYXknDQp9DQppZiAoJGZhdWx0cy5Db3VudCAtZ3QgMCkgew0KICAgIGZvcmVhY2ggKCRm
>> "%B64FILE%" echo IGluICRmYXVsdHMpIHsgQWRkLUxpbmUgKCLmlYXpmpzpgILphY3lmag6ICIgKyAkZi5OYW1lICsg
>> "%B64FILE%" echo IiB8ICIgKyAoR2V0LVByb2JsZW1UZXh0ICRmLlByb2JsZW0pICsgIiB8ICIgKyAkZi5JbnN0YW5j
>> "%B64FILE%" echo ZUlkKSB9DQogICAgU2F5ICgiICDmnIkgezB9IOS4qumAgumFjeWZqOWkhOS6juaVhemanOeKtuaA
>> "%B64FILE%" echo ge+8iOWkmuS4uue8uuWOguWVhumpseWKqO+8iSIgLWYgJGZhdWx0cy5Db3VudCkgJ1llbGxvdycN
>> "%B64FILE%" echo Cn0NCmlmICgkZGlzYWJsZWQuQ291bnQgLWd0IDApIHsNCiAgICBmb3JlYWNoICgkeCBpbiAkZGlz
>> "%B64FILE%" echo YWJsZWQpIHsgQWRkLUxpbmUgKCLlt7LnpoHnlKjpgILphY3lmag6ICIgKyAkeC5OYW1lICsgIiB8
>> "%B64FILE%" echo ICIgKyAkeC5JbnN0YW5jZUlkKSB9DQp9DQpBZGQtTGluZSAiIg0KDQojIC0tLS0tLS0tLS0gWzQv
>> "%B64FILE%" echo NV0g5pON5L2cIC0tLS0tLS0tLS0NCkFkZC1MaW5lICItLS0tLS0tLS0tIOWkhOeQhiAtLS0tLS0t
>> "%B64FILE%" echo LS0tIg0KJGRpZFNvbWV0aGluZyA9ICRmYWxzZQ0KJHN0aWxsR2hvc3QgPSAwDQokc3RpbGxJZGRP
>> "%B64FILE%" echo biA9IDANCg0KIyA0YS4g6Jma5ouf5pi+56S65ZmoIOKAlOKAlCDov5nmiY3mmK/nqbogR1BVIOea
>> "%B64FILE%" echo hOinow0KaWYgKCRpZGRzLkNvdW50IC1ndCAwKSB7DQogICAgU2F5ICJbNC81XSDmtojpmaTnqbog
>> "%B64FILE%" echo R1BVLi4uIiAnV2hpdGUnDQogICAgU2F5ICIgICAgICDnpoHnlKjomZrmi5/mmL7npLrlmajlkI7v
>> "%B64FILE%" echo vIzku7vliqHnrqHnkIblmajph4zpgqPlvKDnqbrljaHkvJrmtojlpLHvvJsiICdEYXJrR3JheScN
>> "%B64FILE%" echo CiAgICBTYXkgIiAgICAgIOmcgOimgeeUqOS4sua1gS/mqKHmi5/lmajml7blho3lkK/nlKjlm57m
>> "%B64FILE%" echo naXvvIzpmo/ml7blj6/mgaLlpI3jgIIiICdEYXJrR3JheScNCiAgICBTYXkgIiINCiAgICBmb3Jl
>> "%B64FILE%" echo YWNoICgkaSBpbiAkaWRkcykgeyBTYXkgKCIgICAgICAtICIgKyAkaS5OYW1lKSAnTWFnZW50YScg
>> "%B64FILE%" echo fQ0KICAgIFNheSAiIg0KICAgICRhbnMgPSBSZWFkLUhvc3QgIiAg56aB55So6L+Z5Lqb6Jma5ouf
>> "%B64FILE%" echo 5pi+56S65Zmo5ZCX77yf6L6T5YWlIFkg5Zue6L2m5omn6KGM77yM5YW25LuW6ZSu6Lez6L+HIg0K
>> "%B64FILE%" echo ICAgIGlmICgkYW5zIC1tYXRjaCAnXltZeV0nKSB7DQogICAgICAgIGZvcmVhY2ggKCRpIGluICRp
>> "%B64FILE%" echo ZGRzKSB7DQogICAgICAgICAgICAkb2sgPSAkZmFsc2UNCiAgICAgICAgICAgICRtc2cgPSAnJw0K
>> "%B64FILE%" echo ICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICBEaXNhYmxlLVBucERldmljZSAtSW5z
>> "%B64FILE%" echo dGFuY2VJZCAkaS5JbnN0YW5jZUlkIC1Db25maXJtOiRmYWxzZSAtRXJyb3JBY3Rpb24gU3RvcA0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICRvayA9ICR0cnVlDQogICAgICAgICAgICB9IGNhdGNoIHsNCiAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAkbXNnID0gJF8uRXhjZXB0aW9uLk1lc3NhZ2UNCiAgICAgICAgICAgICAgICAk
>> "%B64FILE%" echo byA9ICgmIHBucHV0aWwgL2Rpc2FibGUtZGV2aWNlICRpLkluc3RhbmNlSWQgMj4mMSB8IE91dC1T
>> "%B64FILE%" echo dHJpbmcpDQogICAgICAgICAgICAgICAgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJG9rID0g
>> "%B64FILE%" echo JHRydWU7ICRtc2cgPSAnJyB9DQogICAgICAgICAgICAgICAgZWxzZWlmICgtbm90ICRtc2cpIHsg
>> "%B64FILE%" echo JG1zZyA9ICgkbyAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkgfQ0KICAgICAgICAgICAgfQ0K
>> "%B64FILE%" echo ICAgICAgICAgICAgIyDlpI3moLjvvJrpl67popjnoIHlj5jmiJAgMjLvvIjlt7LnpoHnlKjvvInm
>> "%B64FILE%" echo iY3nrpfnnJ/nmoTnlJ/mlYgNCiAgICAgICAgICAgICRub3cgPSAkbnVsbA0KICAgICAgICAgICAg
>> "%B64FILE%" echo dHJ5IHsgJG5vdyA9IEdldC1QbnBEZXZpY2UgLUluc3RhbmNlSWQgJGkuSW5zdGFuY2VJZCAtRXJy
>> "%B64FILE%" echo b3JBY3Rpb24gU3RvcCB9IGNhdGNoIHt9DQogICAgICAgICAgICAkcmVhbGx5ID0gJGZhbHNlDQog
>> "%B64FILE%" echo ICAgICAgICAgICBpZiAoJG5vdyAtbmUgJG51bGwgLWFuZCAkbm93LlByb2JsZW0gLW5lICRudWxs
>> "%B64FILE%" echo KSB7DQogICAgICAgICAgICAgICAgaWYgKFtpbnRdJG5vdy5Qcm9ibGVtIC1lcSAyMikgeyAkcmVh
>> "%B64FILE%" echo bGx5ID0gJHRydWUgfQ0KICAgICAgICAgICAgfQ0KICAgICAgICAgICAgaWYgKCRvayAtYW5kICRy
>> "%B64FILE%" echo ZWFsbHkpIHsNCiAgICAgICAgICAgICAgICBTYXkgKCIgICAg5bey56aB55SoOiAiICsgJGkuTmFt
>> "%B64FILE%" echo ZSkgJ0dyZWVuJw0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICgi56aB55So5oiQ5YqfOiAiICsg
>> "%B64FILE%" echo JGkuTmFtZSArICIgfCAiICsgJGkuSW5zdGFuY2VJZCkNCiAgICAgICAgICAgIH0gZWxzZWlmICgk
>> "%B64FILE%" echo b2sgLWFuZCAtbm90ICRyZWFsbHkpIHsNCiAgICAgICAgICAgICAgICBTYXkgKCIgICAg5ZG95Luk
>> "%B64FILE%" echo 5oql5oiQ5Yqf5L2G54q25oCB5rKh5Y+YOiAiICsgJGkuTmFtZSkgJ1llbGxvdycNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICBBZGQtTGluZSAoIuemgeeUqOe7k+aenOS4jeehruWumjogIiArICRpLk5hbWUgKyAi
>> "%B64FILE%" echo IHwg5ZG95Luk6L+U5Zue5oiQ5Yqf5L2G5aSN5qC4IFN0YXR1cz0iICsgJChpZiAoJG5vdykgeyAk
>> "%B64FILE%" echo bm93LlN0YXR1cyB9IGVsc2UgeyAn5pegJyB9KSArICIgUHJvYmxlbT0iICsgJChpZiAoJG5vdykg
>> "%B64FILE%" echo eyAkbm93LlByb2JsZW0gfSBlbHNlIHsgJ+aXoCcgfSkpDQogICAgICAgICAgICB9IGVsc2Ugew0K
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgIFNheSAoIiAgICDnpoHnlKjlpLHotKU6ICIgKyAkaS5OYW1lKSAnUmVk
>> "%B64FILE%" echo Jw0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICgi56aB55So5aSx6LSlOiAiICsgJGkuTmFtZSAr
>> "%B64FILE%" echo ICIgfCAiICsgJG1zZykNCiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KICAgICAgICAkZGlkU29t
>> "%B64FILE%" echo ZXRoaW5nID0gJHRydWUNCiAgICAgICAgU2F5ICIiDQogICAgfSBlbHNlIHsNCiAgICAgICAgQWRk
>> "%B64FILE%" echo LUxpbmUgIueUqOaIt+i3s+i/h+emgeeUqOiZmuaLn+aYvuekuuWZqCINCiAgICAgICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICDlt7Lot7Pov4fjgIIiICdEYXJrR3JheScNCiAgICAgICAgU2F5ICIgICAgICDmg7PmiYvl
>> "%B64FILE%" echo iqjlpITnkIbvvJrorr7lpIfnrqHnkIblmaggLT4g5pi+56S66YCC6YWN5ZmoIC0+IOWPs+mUruiv
>> "%B64FILE%" echo pemhuSAtPiDnpoHnlKjorr7lpIciICdEYXJrR3JheScNCiAgICAgICAgU2F5ICIiDQogICAgfQ0K
>> "%B64FILE%" echo fSBlbHNlIHsNCiAgICBBZGQtTGluZSAi5rKh5pyJ6Jma5ouf5pi+56S65Zmo77yIUk9PVFxESVNQ
>> "%B64FILE%" echo TEFZ77yJ4oCU4oCUIOepuiBHUFUg6Iul5LuN5a2Y5Zyo77yM6K+36K+05piO5piv56ys5Yeg5Y+3
>> "%B64FILE%" echo 44CCIg0KfQ0KDQojIDRiLiDlub3ngbXorrDlvZUNCmlmICgkZ2hvc3RzLkNvdW50IC1lcSAwKSB7
>> "%B64FILE%" echo DQogICAgU2F5ICIgIOayoeacieW5veeBteiusOW9lemcgOimgea4heeQhuOAgiIgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KfSBlbHNlIHsNCiAgICBTYXkgIiAg5Y+m5Y+R546wICQoJGdob3N0cy5Db3VudCkg5Liq5bm9
>> "%B64FILE%" echo 54G16K6w5b2V77yI6ZWc5YOP5q6L55WZ77yM5LiN5Zyo5pys5py677yM5LiN5b2x5ZON5L2/55So
>> "%B64FILE%" echo 77yJ44CCIiAnV2hpdGUnDQogICAgU2F5ICIgICAgICDmuIXmjonlj6rmmK/orqnjgIzmmL7npLrp
>> "%B64FILE%" echo mpDol4/nmoTorr7lpIfjgI3ml7bliJfooajmm7TlubLlh4DjgIIiICdEYXJrR3JheScNCiAgICBT
>> "%B64FILE%" echo YXkgIiINCiAgICAkYW5zMiA9IFJlYWQtSG9zdCAiICDmuIXnkIbov5nkupvlub3ngbXorrDlvZXl
>> "%B64FILE%" echo kJfvvJ/ovpPlhaUgWSDlm57ovabmiafooYzvvIzlhbbku5bplK7ot7Pov4ciDQogICAgaWYgKCRh
>> "%B64FILE%" echo bnMyIC1tYXRjaCAnXltZeV0nKSB7DQogICAgICAgIGZvcmVhY2ggKCRnIGluICRnaG9zdHMpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICRvayA9ICRmYWxzZTsgJHZpYSA9ICcnOyAkbXNnID0gJycNCg0KICAgICAg
>> "%B64FILE%" echo ICAgICAgIyDjgJDpobrluo/kv67mraPjgJHlhYggUmVtb3ZlLVBucERldmljZe+8iERJRl9SRU1P
>> "%B64FILE%" echo VkUg6IO95aSE55CG5LiN5Zyo5L2N6K6+5aSH77yJDQogICAgICAgICAgICB0cnkgew0KICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgIFJlbW92ZS1QbnBEZXZpY2UgLUluc3RhbmNlSWQgJGcuSW5zdGFuY2VJZCAtQ29u
>> "%B64FILE%" echo ZmlybTokZmFsc2UgLUVycm9yQWN0aW9uIFN0b3ANCiAgICAgICAgICAgICAgICAkb2sgPSAkdHJ1
>> "%B64FILE%" echo ZTsgJHZpYSA9ICdSZW1vdmUtUG5wRGV2aWNlJw0KICAgICAgICAgICAgfSBjYXRjaCB7DQogICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgJG1zZyA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlDQogICAgICAgICAgICB9DQog
>> "%B64FILE%" echo ICAgICAgICAgICAjIOWGjemAgOWIsCBwbnB1dGlsDQogICAgICAgICAgICBpZiAoLW5vdCAkb2sp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgICAgICAkbyA9ICgmIHBucHV0aWwgL3JlbW92ZS1kZXZpY2UgJGcuSW5z
>> "%B64FILE%" echo dGFuY2VJZCAyPiYxIHwgT3V0LVN0cmluZykNCiAgICAgICAgICAgICAgICBpZiAoJExBU1RFWElU
>> "%B64FILE%" echo Q09ERSAtZXEgMCkgeyAkb2sgPSAkdHJ1ZTsgJHZpYSA9ICdwbnB1dGlsJyB9DQogICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgZWxzZSB7IGlmICgtbm90ICRtc2cpIHsgJG1zZyA9ICgkbyAtcmVwbGFjZSAnXHMrJywg
>> "%B64FILE%" echo JyAnKS5UcmltKCkgfSB9DQogICAgICAgICAgICB9DQoNCiAgICAgICAgICAgICMg44CQ5b+F6aG7
>> "%B64FILE%" echo 5aSN5qC444CR5ZG95Luk6K+05oiQ5Yqf5LiN5Luj6KGo55yf5Yig5LqGDQogICAgICAgICAgICAk
>> "%B64FILE%" echo c3RpbGwgPSAkbnVsbA0KICAgICAgICAgICAgdHJ5IHsgJHN0aWxsID0gR2V0LVBucERldmljZSAt
>> "%B64FILE%" echo SW5zdGFuY2VJZCAkZy5JbnN0YW5jZUlkIC1FcnJvckFjdGlvbiBTdG9wIH0gY2F0Y2gge30NCiAg
>> "%B64FILE%" echo ICAgICAgICAgICRnb25lID0gKCRudWxsIC1lcSAkc3RpbGwpDQoNCiAgICAgICAgICAgIGlmICgk
>> "%B64FILE%" echo Z29uZSkgew0KICAgICAgICAgICAgICAgIFNheSAoIiAgICDlt7LmtojlpLE6ICIgKyAkZy5OYW1l
>> "%B64FILE%" echo KSAnR3JlZW4nDQogICAgICAgICAgICAgICAgQWRkLUxpbmUgKCLlub3ngbXlt7LliKDpmaQoIiAr
>> "%B64FILE%" echo ICR2aWEgKyAiKTogIiArICRnLkluc3RhbmNlSWQpDQogICAgICAgICAgICB9IGVsc2Ugew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgIFNheSAoIiAgICDku43nhLblrZjlnKg6ICIgKyAkZy5OYW1lKSAnWWVsbG93
>> "%B64FILE%" echo Jw0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICgi5bm954G15pyq5Yig6ZmkOiAiICsgJGcuSW5z
>> "%B64FILE%" echo dGFuY2VJZCArICIgfCDlsJ3or5XmlrnlvI89IiArICR2aWEgKyAiIHwg5ZG95Luk57uT5p6cPSIg
>> "%B64FILE%" echo KyAkKGlmICgkb2spIHsgJ+aKpeaIkOWKnycgfSBlbHNlIHsgJ+Wksei0pScgfSkgKyAiIHwg6ZSZ
>> "%B64FILE%" echo 6K+vPSIgKyAkbXNnKQ0KICAgICAgICAgICAgICAgIEFkZC1MaW5lICIgICAg6K+05piOOiDor6Xo
>> "%B64FILE%" echo rrDlvZXlnKjms6jlhozooaggRW51bSDph4zku43ljaDkvY3vvIzpnIDopoHmiYvliqjlpITnkIbv
>> "%B64FILE%" echo vIjop4HkuIvvvIkiDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICAgICAgJGRpZFNvbWV0
>> "%B64FILE%" echo aGluZyA9ICR0cnVlDQogICAgfSBlbHNlIHsNCiAgICAgICAgQWRkLUxpbmUgIueUqOaIt+i3s+i/
>> "%B64FILE%" echo h+a4heeQhuW5veeBtSINCiAgICAgICAgU2F5ICIgICAgICDlt7Lot7Pov4fjgIIiICdEYXJrR3Jh
>> "%B64FILE%" echo eScNCiAgICB9DQp9DQoNCiMgLS0tLS0tLS0tLSBbNS81XSDlpI3moLggLS0tLS0tLS0tLQ0KaWYg
>> "%B64FILE%" echo KCRkaWRTb21ldGhpbmcpIHsNCiAgICBTYXkgIiINCiAgICBTYXkgIls1LzVdIOWkjeaguOW9k+WJ
>> "%B64FILE%" echo jeeKtuaAgS4uLiIgJ1doaXRlJw0KICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgNTAwDQog
>> "%B64FILE%" echo ICAgJGFmdGVyID0gQChHZXQtUG5wRGV2aWNlIC1DbGFzcyBEaXNwbGF5IC1FcnJvckFjdGlvbiBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlKQ0KICAgICRzdGlsbEdob3N0ID0gMA0KICAgICRzdGlsbElkZE9uID0g
>> "%B64FILE%" echo MA0KICAgIGZvcmVhY2ggKCRkIGluICRhZnRlcikgew0KICAgICAgICBpZiAoLW5vdCAkZCkgeyBj
>> "%B64FILE%" echo b250aW51ZSB9DQogICAgICAgICRwcmVzID0gJGZhbHNlDQogICAgICAgIHRyeSB7ICRwID0gKEdl
>> "%B64FILE%" echo dC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZC5JbnN0YW5jZUlkIC1LZXlOYW1lICdE
>> "%B64FILE%" echo RVZQS0VZX0RldmljZV9Jc1ByZXNlbnQnIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRhOyBpZiAoJHAg
>> "%B64FILE%" echo LWVxICR0cnVlKSB7ICRwcmVzID0gJHRydWUgfSB9IGNhdGNoIHt9DQogICAgICAgICRwciA9IDAN
>> "%B64FILE%" echo CiAgICAgICAgaWYgKCRkLlByb2JsZW0gLW5lICRudWxsKSB7ICRwciA9IFtpbnRdJGQuUHJvYmxl
>> "%B64FILE%" echo bSB9DQogICAgICAgIGlmICgtbm90ICRwcmVzKSB7ICRzdGlsbEdob3N0KysgfQ0KICAgICAgICBl
>> "%B64FILE%" echo bHNlaWYgKCRkLkluc3RhbmNlSWQgLWxpa2UgJ1JPT1RcKicgLWFuZCAkcHIgLW5lIDIyKSB7ICRz
>> "%B64FILE%" echo dGlsbElkZE9uKysgfQ0KICAgIH0NCiAgICBBZGQtTGluZSAiIg0KICAgIEFkZC1MaW5lICItLS0t
>> "%B64FILE%" echo LS0tLS0tIOWkjeaguOe7k+aenCAtLS0tLS0tLS0tIg0KICAgIEFkZC1MaW5lICgi5Ymp5L2Z5bm9
>> "%B64FILE%" echo 54G16K6w5b2VOiAiICsgJHN0aWxsR2hvc3QpDQogICAgQWRkLUxpbmUgKCLku43lkK/nlKjnmoTo
>> "%B64FILE%" echo mZrmi5/mmL7npLrlmag6ICIgKyAkc3RpbGxJZGRPbikNCiAgICBTYXkgKCIgIOWkjeaguO+8muW5
>> "%B64FILE%" echo veeBtei/mOWJqSB7MH0g5Liq77yM5LuN5ZCv55So55qE6Jma5ouf5pi+56S65ZmoIHsxfSDkuKoi
>> "%B64FILE%" echo IC1mICRzdGlsbEdob3N0LCAkc3RpbGxJZGRPbikgJ0N5YW4nDQp9IGVsc2Ugew0KICAgIEFkZC1M
>> "%B64FILE%" echo aW5lICIiDQogICAgQWRkLUxpbmUgIuacrOasoeWPquWBmuiviuaWre+8jOayoeacieS/ruaUueS7
>> "%B64FILE%" echo u+S9leiuvuWkh+OAgiINCn0NCg0KIyAtLS0tLS0tLS0tIOWGmeaKpeWRiiAtLS0tLS0tLS0tDQpB
>> "%B64FILE%" echo ZGQtTGluZSAiIg0KQWRkLUxpbmUgIj09PT09PT09PT09PT09PT09PT09IOiviuaWree7k+adnyA9
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PSINCg0KIyDjgJB2MS4yOeOAkeaKpeWRiuS4jeWGjeebtOaOpeS4
>> "%B64FILE%" echo ouWcqOebmOague+8jOe7n+S4gOi/myA855uYPjpc6Jma5ouf56Gs55uY57O757ufLeaXpeW/l1wN
>> "%B64FILE%" echo CiRzYXZlZCA9IEAoKQ0KZm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FcnJvckFjdGlvbiBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlKSkgew0KICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7IGNvbnRp
>> "%B64FILE%" echo bnVlIH0NCiAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7IGNvbnRpbnVlIH0NCiAg
>> "%B64FILE%" echo ICAkZGlyID0gInswfTpc6Jma5ouf56Gs55uY57O757ufLeaXpeW/lyIgLWYgJHYuRHJpdmVMZXR0
>> "%B64FILE%" echo ZXINCiAgICB0cnkgew0KICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAk
>> "%B64FILE%" echo ZGlyKSkgew0KICAgICAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAk
>> "%B64FILE%" echo ZGlyIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcCB8IE91dC1OdWxsDQogICAgICAgIH0NCiAgICAg
>> "%B64FILE%" echo ICAgJHAgPSBKb2luLVBhdGggJGRpciAn5pi+5Y2h6K+K5patLnR4dCcNCiAgICAgICAgJHJlcG9y
>> "%B64FILE%" echo dCAtam9pbiAiYHJgbiIgfCBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJHAgLUVuY29kaW5nIFVU
>> "%B64FILE%" echo RjggLUVycm9yQWN0aW9uIFN0b3ANCiAgICAgICAgJHNhdmVkICs9ICRwDQogICAgfSBjYXRjaCB7
>> "%B64FILE%" echo fQ0KfQ0KDQpTYXkgIiINClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNCmZvcmVhY2ggKCRwIGluICRz
>> "%B64FILE%" echo YXZlZCkgeyBTYXkgKCIgIOaKpeWRiuW3suS/neWtmDogIiArICRwKSAnR3JlZW4nIH0NCg0KaWYg
>> "%B64FILE%" echo KCRzdGlsbEdob3N0IC1ndCAwKSB7DQogICAgU2F5ICIiDQogICAgU2F5ICIgIOS7jeacieW5veeB
>> "%B64FILE%" echo teiusOW9leWIoOS4jeaOieaXtueahOaJi+WKqOWKnuazle+8miIgJ1llbGxvdycNCiAgICBTYXkg
>> "%B64FILE%" echo IiAgICDorr7lpIfnrqHnkIblmaggLT4g5p+l55yLIC0+IOaYvuekuumakOiXj+eahOiuvuWkhyAt
>> "%B64FILE%" echo PiDmmL7npLrpgILphY3lmaggLT4iICdEYXJrR3JheScNCiAgICBTYXkgIiAgICDngbDoibLpgqPl
>> "%B64FILE%" echo h6Dpobnlj7PplK7jgIzljbjovb3orr7lpIfjgI0tPiDph43lkK/jgIIiICdEYXJrR3JheScNCn0N
>> "%B64FILE%" echo ClNheSAiIg0KU2F5ICIgIOemgeeUqOiZmuaLn+aYvuekuuWZqOWQjuimgemHjeWQr+S4gOasoe+8
>> "%B64FILE%" echo jOS7u+WKoeeuoeeQhuWZqCBHUFUg5YiX6KGo5omN5Yi35paw44CCIiAnQ3lhbicNClNheSAiIg0K
>> "%B64FILE%" echo UmVhZC1Ib3N0ICIgIOaMieWbnui9pumAgOWHuiINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=17587"
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
