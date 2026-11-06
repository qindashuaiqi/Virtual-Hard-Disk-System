@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 新系统诊断并装驱动
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
set "PS1FILE=%WORKDIR%\新系统-诊断并装驱动.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oKQ0KDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PQ0KIyDmlrDns7vnu5/or4rmlq3lubboo4XpqbHliqggIHYxLjEN
>> "%B64FILE%" echo CiMg5L2c6ICFOiBjb25uZWN0c2VnYWJvdA0KIw0KIyDlnKjlk6rov5DooYzvvJoqKuaWsOijheea
>> "%B64FILE%" echo hOmCo+S4quiZmuaLn+ezu+e7n+mHjCoq77yI5LiN5piv5Y6f5p2l55qE57O757uf77yJ44CCDQoj
>> "%B64FILE%" echo DQojIHYxLjEg5L+u5LqG5LuA5LmI77yaDQojICAxKSB2MS4wIOaKiuaJgOaciSBQcm9ibGVt4omg
>> "%B64FILE%" echo MCDnmoTorr7lpIfpg73nrpfjgIzmnInpl67popjjgI3vvIznu5PmnpwgNTUzIOS4qiBDTV9QUk9C
>> "%B64FILE%" echo X1BIQU5UT00NCiMgICAgIO+8iOWFi+mahumVnOWDj+eVmeWcqOazqOWGjOihqOmHjOeahOWOhuWP
>> "%B64FILE%" echo suiuvuWkh+iusOW9le+8ieaKiuecn+ato+eahCAzIOS4quaVhemanOa3ueaOieS6huOAgg0KIyAg
>> "%B64FILE%" echo ICAgcGhhbnRvbSDkuI3mmK/mlYXpmpwg4oCU4oCUIOiuvuWkh+aXqeWwseS4jeWcqOacuuWZqOS4
>> "%B64FILE%" echo iuS6hu+8jOWPquaYr+iusOW9leayoea4heOAgg0KIyAgMikgdjEuMCDnlKggcG5wdXRpbCAvYWRk
>> "%B64FILE%" echo LWRyaXZlciA855uu5b2VPiAvc3ViZGlycyDkuIDmrKHoo4XlrozvvIzlrp7mtYvor6Xnm67lvZXk
>> "%B64FILE%" echo uIsNCiMgICAgIDE1NCDkuKogSU5GIOWNtOaKpeOAjOmpseWKqOeoi+W6j+WMheaAu+aVsDogMOOA
>> "%B64FILE%" echo jeOAgg0KIyAgICAgdjEuMSDmlLnmiJDvvJrlhYjmjInmlYXpmpzorr7lpIfnmoTnoazku7YgSUQg
>> "%B64FILE%" echo 5Y67IElORiDph4zmib7ljLnphY3pobnvvIzlho3pgJDkuKogSU5GIOijheOAgg0KIyAgICAg5pei
>> "%B64FILE%" echo 57uV5byAIC9zdWJkaXJz77yM5Lmf5LiN55So5oqKIDE1NCDkuKrljIXlhajot5HkuIDpgY3jgIIN
>> "%B64FILE%" echo CiMNCiMg57uT5p6c5paH5Lu277yaPOafkOS4quebmD46XOaWsOezu+e7n+iviuaWrS50eHQNCiMg
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09DQoNCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnQ29udGludWUnDQokU2NyaXB0OlZlcnNp
>> "%B64FILE%" echo b24gPSAnMS4zNCcNCnRyeSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIuaWsOezu+e7
>> "%B64FILE%" echo n+iviuaWreW5tuijhempseWKqCB2JCgkU2NyaXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3Qi
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCg0KIyBbdjEuMzJdIOWFseS6q+aooeWdl+OAguaJk+WMheaXtueUsSBzcmMv
>> "%B64FILE%" echo YnVpbGQvaW5saW5lX3NoYXJlZC5weSDlhoXogZTmnKzmlofku7bvvIwNCiMgLmJhdCDovb3ojbfk
>> "%B64FILE%" echo u43mmK/oh6rljIXlkKvljZXmlofku7bjgIINCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09DQojIOWFseS6q+aXpeW/l+WHveaVsCAg
>> "%B64FILE%" echo IHYxLjMyDQojDQojIOacrOaWh+S7tuS4jeaYr+WPkeW4g+eJqeOAguaJk+WMhSAuYmF0IOi9veiN
>> "%B64FILE%" echo t+aXtu+8jHNyYy9idWlsZC9pbmxpbmVfc2hhcmVkLnB5IOS8muaKiui/memHjOeahA0KIyDlhoXl
>> "%B64FILE%" echo rrnlhoXogZTov5vmr4/kuKrlhaXlj6PohJrmnKzvvIzkv53or4Hlj5HluIPlh7rljrvnmoTlkK/l
>> "%B64FILE%" echo iqjlmajku43mmK/oh6rljIXlkKvljZXmlofku7YNCiMg77yI6Ieq6Kej5Y6LIGJhdCDlnKjov5Do
>> "%B64FILE%" echo oYzmnJ/msqHlip7ms5XlvJXnlKjlpJbpg6jmqKHlnZfvvInjgIINCiMNCiMg6KeE55+p77ya5Y+q
>> "%B64FILE%" echo 5pS56L+Z6YeM77yM5LiN6KaB5YaN5oqK6L+Z5Lqb5Ye95pWw5aSN5Yi25Zue5YWl5Y+j6ISa5pys
>> "%B64FILE%" echo 44CCDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PQ0KDQpmdW5jdGlvbiBTYXkgew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtz
>> "%B64FILE%" echo dHJpbmddJENvbG9yID0gJ0dyYXknKQ0KICAgIFdyaXRlLUhvc3QgJFRleHQgLUZvcmVncm91bmRD
>> "%B64FILE%" echo b2xvciAkQ29sb3INCn0NCg0KU2F5ICIiDQpTYXkgIiAg5paw57O757uf6K+K5pat5bm26KOF6amx
>> "%B64FILE%" echo 5YqoICB2JCgkU2NyaXB0OlZlcnNpb24pIiAnQ3lhbicNClNheSAiICDkvZzogIU6IGNvbm5lY3Rz
>> "%B64FILE%" echo ZWdhYm90IiAnRGFya0dyYXknDQpTYXkgIiAgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiAnRGFya0dyYXknDQpTYXkgIiINCg0KJGFk
>> "%B64FILE%" echo bWluID0gKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbF1bU2VjdXJpdHkuUHJp
>> "%B64FILE%" echo bmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKSkuSXNJblJvbGUoW1NlY3VyaXR5
>> "%B64FILE%" echo LlByaW5jaXBhbC5XaW5kb3dzQnVpbHRJblJvbGVdOjpBZG1pbmlzdHJhdG9yKQ0KaWYgKC1ub3Qg
>> "%B64FILE%" echo JGFkbWluKSB7DQogICAgU2F5ICIgIFvplJnor69dIOmcgOimgeeuoeeQhuWRmOadg+mZkOOAguiv
>> "%B64FILE%" echo t+WPs+mUriAtPiDku6XnrqHnkIblkZjouqvku73ov5DooYzjgIIiICdSZWQnDQogICAgUmVhZC1I
>> "%B64FILE%" echo b3N0ICIgIOaMieWbnui9pumAgOWHuiINCiAgICBleGl0IDENCn0NCg0KJHJlcG9ydCA9IE5ldy1P
>> "%B64FILE%" echo YmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KZnVuY3Rpb24gQWRkLUxpbmUgeyBw
>> "%B64FILE%" echo YXJhbShbc3RyaW5nXSRUID0gJycpIFt2b2lkXSRyZXBvcnQuQWRkKCRUKSB9DQoNCiRvcyA9IEdl
>> "%B64FILE%" echo dC1DaW1JbnN0YW5jZSBXaW4zMl9PcGVyYXRpbmdTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUNCkFkZC1MaW5lICI9PT09PT09PT09PT09PT09PT09PSDmlrDns7vnu5/or4rmlq0g
>> "%B64FILE%" echo diQoJFNjcmlwdDpWZXJzaW9uKSA9PT09PT09PT09PT09PT09PT09PSINCkFkZC1MaW5lICgi6K6h
>> "%B64FILE%" echo 566X5py65ZCNIDogIiArICRlbnY6Q09NUFVURVJOQU1FKQ0KQWRkLUxpbmUgKCLns7vnu58gICAg
>> "%B64FILE%" echo IDogIiArICRvcy5DYXB0aW9uICsgIiAgQnVpbGQgIiArICRvcy5CdWlsZE51bWJlcikNCkFkZC1M
>> "%B64FILE%" echo aW5lICgi5ZCv5Yqo5pe26Ze0IDogIiArICRvcy5MYXN0Qm9vdFVwVGltZSkNCkFkZC1MaW5lICgi
>> "%B64FILE%" echo 6L+Q6KGM5pe26ZW/IDogIiArIFtzdHJpbmddKFtkYXRldGltZV06Ok5vdyAtICRvcy5MYXN0Qm9v
>> "%B64FILE%" echo dFVwVGltZSkpDQpBZGQtTGluZSAoIuezu+e7n+ebmCAgIDogIiArICRlbnY6U3lzdGVtRHJpdmUp
>> "%B64FILE%" echo DQpBZGQtTGluZSAiIg0KDQojIC0tLS0tLS0tLS0g5Y+q6KaB55yf5pWF6Zqc77yM5LiN6KaBIHBo
>> "%B64FILE%" echo YW50b20gLS0tLS0tLS0tLQ0KIyAgIDIyID0gQ01fUFJPQl9ESVNBQkxFRO+8iOiiq+emgeeUqO+8
>> "%B64FILE%" echo jOmAmuW4uOaYr+acieaEj+S4uuS5i++8iQ0KIyAgIDQ1ID0gQ01fUFJPQl9QSEFOVE9N77yI5Y6G
>> "%B64FILE%" echo 5Y+y6K6w5b2V77yM6K6+5aSH5LiN5Zyo77yJDQokaWdub3JlUHJvYmxlbSA9IEAoMCwgMjIsIDQ1
>> "%B64FILE%" echo KQ0KZnVuY3Rpb24gR2V0LVJlYWxQcm9ibGVtcyB7DQogICAgJGxpc3QgPSBAKCkNCiAgICAkc2Vl
>> "%B64FILE%" echo biA9IEB7fQ0KICAgIGZvcmVhY2ggKCRkIGluIEAoR2V0LVBucERldmljZSAtRXJyb3JBY3Rpb24g
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJGQpIHsgY29udGludWUgfQ0K
>> "%B64FILE%" echo ICAgICAgICAkcCA9ICRkLlByb2JsZW0NCiAgICAgICAgaWYgKCRwIC1lcSAkbnVsbCkgeyAkcCA9
>> "%B64FILE%" echo IDAgfQ0KICAgICAgICBpZiAoJGlnbm9yZVByb2JsZW0gLWNvbnRhaW5zIFtpbnRdJHApIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICAgICBpZiAoJGQuU3RhdHVzIC1lcSAnVW5rbm93bicpIHsgY29udGludWUg
>> "%B64FILE%" echo fQ0KICAgICAgICBpZiAoJHNlZW4uQ29udGFpbnNLZXkoJGQuSW5zdGFuY2VJZCkpIHsgY29udGlu
>> "%B64FILE%" echo dWUgfQ0KICAgICAgICAkc2VlblskZC5JbnN0YW5jZUlkXSA9IDENCiAgICAgICAgJGxpc3QgKz0g
>> "%B64FILE%" echo JGQNCiAgICB9DQogICAgcmV0dXJuICRsaXN0DQp9DQoNClNheSAiWzEvNF0g5pS26ZuG55yf5pWF
>> "%B64FILE%" echo 6Zqc6K6+5aSH77yI6Lez6L+HIHBoYW50b23vvIkuLi4iICdXaGl0ZScNCiRwcm9ibGVtcyA9IEAo
>> "%B64FILE%" echo R2V0LVJlYWxQcm9ibGVtcykNCkFkZC1MaW5lICItLS0tLS0tLS0tIOecn+aVhemanOiuvuWkhyAt
>> "%B64FILE%" echo LS0tLS0tLS0tIg0KQWRkLUxpbmUgKCLlhbEgezB9IOS4qiIgLWYgJHByb2JsZW1zLkNvdW50KQ0K
>> "%B64FILE%" echo QWRkLUxpbmUgIiINCmZvcmVhY2ggKCRkIGluICRwcm9ibGVtcykgew0KICAgICRodyA9IEAoKQ0K
>> "%B64FILE%" echo ICAgIHRyeSB7ICRodyA9IEAoKEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZC5J
>> "%B64FILE%" echo bnN0YW5jZUlkIC1LZXlOYW1lICdERVZQS0VZX0RldmljZV9IYXJkd2FyZUlkcycgLUVycm9yQWN0
>> "%B64FILE%" echo aW9uIFN0b3ApLkRhdGEpIH0gY2F0Y2gge30NCiAgICBBZGQtTGluZSAoIlt7MH1dIHsxfSIgLWYg
>> "%B64FILE%" echo JGQuU3RhdHVzLCAkZC5GcmllbmRseU5hbWUpDQogICAgQWRkLUxpbmUgKCIgICAg6Zeu6aKY56CB
>> "%B64FILE%" echo OiB7MH0gICDnsbs6IHsxfSIgLWYgJGQuUHJvYmxlbSwgJGQuQ2xhc3MpDQogICAgQWRkLUxpbmUg
>> "%B64FILE%" echo KCIgICAg5a6e5L6LSUQ6IHswfSIgLWYgJGQuSW5zdGFuY2VJZCkNCiAgICBpZiAoJGh3LkNvdW50
>> "%B64FILE%" echo IC1ndCAwKSB7IEFkZC1MaW5lICgiICAgIOehrOS7tklEOiAiICsgKCRodyAtam9pbiAnIDsgJykp
>> "%B64FILE%" echo IH0NCiAgICBBZGQtTGluZSAiIg0KfQ0KU2F5ICgiICAgICAg55yf5pWF6ZqcIHswfSDkuKoiIC1m
>> "%B64FILE%" echo ICRwcm9ibGVtcy5Db3VudCkgJ0RhcmtHcmF5Jw0KDQojIC0tLS0tLS0tLS0g5om+6amx5Yqo55uu
>> "%B64FILE%" echo 5b2VIC0tLS0tLS0tLS0NCiRkcnZEaXJzID0gQCgpDQpmb3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1
>> "%B64FILE%" echo bWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgaWYgKC1ub3QgJHYuRHJp
>> "%B64FILE%" echo dmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgIGlmICgoW3N0cmluZ10kdi5Ecml2ZUxldHRlciku
>> "%B64FILE%" echo VG9VcHBlcigpIC1lcSAoKFtzdHJpbmddJGVudjpTeXN0ZW1Ecml2ZSkuVHJpbUVuZCgnOicpLlRv
>> "%B64FILE%" echo VXBwZXIoKSkpIHsgY29udGludWUgfQ0KICAgIGZvcmVhY2ggKCRubSBpbiBAKCdOZXdTeXN0ZW1E
>> "%B64FILE%" echo cml2ZXInLCAn5paw57O757uf6amx5YqoJykpIHsNCiAgICAgICAgJGMgPSAiezB9Olx7MX0iIC1m
>> "%B64FILE%" echo ICR2LkRyaXZlTGV0dGVyLCAkbm0NCiAgICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGgg
>> "%B64FILE%" echo JGMpIHsgJGRydkRpcnMgKz0gJGMgfQ0KICAgIH0NCn0NCmZvcmVhY2ggKCRjIGluIEAoJ0M6XE5l
>> "%B64FILE%" echo d1N5c3RlbURyaXZlcicsICdDOlzmlrDns7vnu5/pqbHliqgnKSkgew0KICAgIGlmIChUZXN0LVBh
>> "%B64FILE%" echo dGggLUxpdGVyYWxQYXRoICRjKSB7ICRkcnZEaXJzICs9ICRjIH0NCn0NCiRkcnZEaXJzID0gQCgk
>> "%B64FILE%" echo ZHJ2RGlycyB8IFNlbGVjdC1PYmplY3QgLVVuaXF1ZSkNCiRhbGxJbmYgPSBAKCkNCmZvcmVhY2gg
>> "%B64FILE%" echo KCRkZCBpbiAkZHJ2RGlycykgeyAkYWxsSW5mICs9IEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBh
>> "%B64FILE%" echo dGggJGRkIC1SZWN1cnNlIC1GaWx0ZXIgKi5pbmYgLUVBIFNpbGVudGx5Q29udGludWUpIH0NCkFk
>> "%B64FILE%" echo ZC1MaW5lICItLS0tLS0tLS0tIOmpseWKqOW6kyAtLS0tLS0tLS0tIg0KaWYgKCRhbGxJbmYuQ291
>> "%B64FILE%" echo bnQgLWVxIDApIHsgQWRkLUxpbmUgIuayoeaJvuWIsOS7u+S9lSBJTkYiIH0NCmZvcmVhY2ggKCRk
>> "%B64FILE%" echo ZCBpbiAkZHJ2RGlycykgeyBBZGQtTGluZSAoIuebruW9lTogIiArICRkZCkgfQ0KQWRkLUxpbmUg
>> "%B64FILE%" echo KCJJTkYg5oC75pWwOiB7MH0iIC1mICRhbGxJbmYuQ291bnQpDQpBZGQtTGluZSAiIg0KU2F5ICgi
>> "%B64FILE%" echo ICAgICAg6amx5Yqo55uu5b2VIHswfSDkuKrvvIxJTkYgezF9IOS4qiIgLWYgJGRydkRpcnMuQ291
>> "%B64FILE%" echo bnQsICRhbGxJbmYuQ291bnQpICdEYXJrR3JheScNCg0KIyAtLS0tLS0tLS0tIOaMieehrOS7tiBJ
>> "%B64FILE%" echo RCDljLnphY0gSU5GIC0tLS0tLS0tLS0NClNheSAiWzIvNF0g5oyJ56Gs5Lu2IElEIOaJvuWMuemF
>> "%B64FILE%" echo jeeahCBJTkYgLi4uIiAnV2hpdGUnDQpmdW5jdGlvbiBHZXQtTWF0Y2hLZXlzIHsNCiAgICBwYXJh
>> "%B64FILE%" echo bShbc3RyaW5nXSRpbnN0LCAkaHdMaXN0KQ0KICAgICRrZXlzID0gQCgpDQogICAgZm9yZWFjaCAo
>> "%B64FILE%" echo JGggaW4gQCgkaHdMaXN0KSkgew0KICAgICAgICBpZiAoLW5vdCAkaCkgeyBjb250aW51ZSB9DQog
>> "%B64FILE%" echo ICAgICAgICRrZXlzICs9ICRoDQogICAgICAgICRrZXlzICs9ICgkaCAtcmVwbGFjZSAnJlJFVl9b
>> "%B64FILE%" echo MC05QS1GYS1mXSsnLCAnJykNCiAgICB9DQogICAgJG0gPSBbcmVnZXhdOjpNYXRjaCgkaW5zdCwg
>> "%B64FILE%" echo Jyg/aSkoKD86UENJfFVTQilcXFZFTl9bMC05QS1GXXs0fSZERVZfWzAtOUEtRl17NH0mU1VCU1lT
>> "%B64FILE%" echo X1swLTlBLUZdezh9KScpDQogICAgaWYgKCRtLlN1Y2Nlc3MpIHsgJGtleXMgKz0gJG0uR3JvdXBz
>> "%B64FILE%" echo WzFdLlZhbHVlIH0NCiAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgkaW5zdCwgJyg/aSkoKD86UENJ
>> "%B64FILE%" echo fFVTQilcXFZFTl9bMC05QS1GXXs0fSZERVZfWzAtOUEtRl17NH0pJykNCiAgICBpZiAoJG0yLlN1
>> "%B64FILE%" echo Y2Nlc3MpIHsgJGtleXMgKz0gJG0yLkdyb3Vwc1sxXS5WYWx1ZSB9DQogICAgcmV0dXJuIEAoJGtl
>> "%B64FILE%" echo eXMgfCBXaGVyZS1PYmplY3QgeyAkXyB9IHwgU2VsZWN0LU9iamVjdCAtVW5pcXVlKQ0KfQ0KDQok
>> "%B64FILE%" echo aW5mVGV4dCA9IEB7fQ0KZm9yZWFjaCAoJGYgaW4gJGFsbEluZikgew0KICAgIHRyeSB7DQogICAg
>> "%B64FILE%" echo ICAgICR0ID0gJycNCiAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICR0ID0gW0lPLkZpbGVdOjpS
>> "%B64FILE%" echo ZWFkQWxsVGV4dCgkZi5GdWxsTmFtZSwgW1RleHQuRW5jb2RpbmddOjpVbmljb2RlKQ0KICAgICAg
>> "%B64FILE%" echo ICAgICAgaWYgKCR0IC1ub3RtYXRjaCAnXFtWZXJzaW9uXF0nKSB7ICR0ID0gW0lPLkZpbGVdOjpS
>> "%B64FILE%" echo ZWFkQWxsVGV4dCgkZi5GdWxsTmFtZSwgW1RleHQuRW5jb2RpbmddOjpEZWZhdWx0KSB9DQogICAg
>> "%B64FILE%" echo ICAgIH0gY2F0Y2ggeyAkdCA9ICcnIH0NCiAgICAgICAgaWYgKCR0KSB7ICRpbmZUZXh0WyRmLkZ1
>> "%B64FILE%" echo bGxOYW1lXSA9ICR0IH0NCiAgICB9IGNhdGNoIHt9DQp9DQpTYXkgKCIgICAgICDlt7Lor7vlj5Yg
>> "%B64FILE%" echo ezB9IOS4qiBJTkYg5YaF5a65IiAtZiAkaW5mVGV4dC5Db3VudCkgJ0RhcmtHcmF5Jw0KDQokaW5z
>> "%B64FILE%" echo dGFsbFF1ZXVlID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQpmb3Jl
>> "%B64FILE%" echo YWNoICgkZCBpbiAkcHJvYmxlbXMpIHsNCiAgICAkaHcgPSBAKCkNCiAgICB0cnkgeyAkaHcgPSBA
>> "%B64FILE%" echo KChHZXQtUG5wRGV2aWNlUHJvcGVydHkgLUluc3RhbmNlSWQgJGQuSW5zdGFuY2VJZCAtS2V5TmFt
>> "%B64FILE%" echo ZSAnREVWUEtFWV9EZXZpY2VfSGFyZHdhcmVJZHMnIC1FcnJvckFjdGlvbiBTdG9wKS5EYXRhKSB9
>> "%B64FILE%" echo IGNhdGNoIHt9DQogICAgJGtleXMgPSBHZXQtTWF0Y2hLZXlzIC1pbnN0ICRkLkluc3RhbmNlSWQg
>> "%B64FILE%" echo LWh3TGlzdCAkaHcNCiAgICAkbWF0Y2hlZCA9IEAoKQ0KICAgIGZvcmVhY2ggKCRrdiBpbiAkaW5m
>> "%B64FILE%" echo VGV4dC5HZXRFbnVtZXJhdG9yKCkpIHsNCiAgICAgICAgZm9yZWFjaCAoJGsgaW4gJGtleXMpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgIGlmICgka3YuVmFsdWUuSW5kZXhPZigkaywgW1N0cmluZ0NvbXBhcmlzb25d
>> "%B64FILE%" echo OjpPcmRpbmFsSWdub3JlQ2FzZSkgLWdlIDApIHsNCiAgICAgICAgICAgICAgICAkbWF0Y2hlZCAr
>> "%B64FILE%" echo PSAka3YuS2V5DQogICAgICAgICAgICAgICAgYnJlYWsNCiAgICAgICAgICAgIH0NCiAgICAgICAg
>> "%B64FILE%" echo fQ0KICAgIH0NCiAgICAkbWF0Y2hlZCA9IEAoJG1hdGNoZWQgfCBTZWxlY3QtT2JqZWN0IC1Vbmlx
>> "%B64FILE%" echo dWUpDQogICAgW3ZvaWRdJGluc3RhbGxRdWV1ZS5BZGQoW3BzY3VzdG9tb2JqZWN0XUB7IERldiA9
>> "%B64FILE%" echo ICRkOyBLZXlzID0gJGtleXM7IEluZnMgPSAkbWF0Y2hlZCB9KQ0KICAgIFNheSAoIiAgICAgIHsw
>> "%B64FILE%" echo fSAgLT4g5Yy56YWNIHsxfSDkuKogSU5GIiAtZiAkZC5GcmllbmRseU5hbWUsICRtYXRjaGVkLkNv
>> "%B64FILE%" echo dW50KSAnRGFya0dyYXknDQogICAgQWRkLUxpbmUgKCLljLnphY06IHswfSAgKHsxfSDkuKogSU5G
>> "%B64FILE%" echo KSIgLWYgJGQuRnJpZW5kbHlOYW1lLCAkbWF0Y2hlZC5Db3VudCkNCiAgICBmb3JlYWNoICgkbWkg
>> "%B64FILE%" echo aW4gJG1hdGNoZWQpIHsgQWRkLUxpbmUgKCIgICAgIiArICRtaSkgfQ0KfQ0KDQojIC0tLS0tLS0t
>> "%B64FILE%" echo LS0g546w5Zy65a6J6KOFIC0tLS0tLS0tLS0NClNheSAiWzMvNF0g546w5Zy65a6J6KOF77yI5YWI
>> "%B64FILE%" echo 5by65Yi26YeN5omr6K6+5aSH77yJLi4uIiAnV2hpdGUnDQpBZGQtTGluZSAiIg0KQWRkLUxpbmUg
>> "%B64FILE%" echo Ii0tLS0tLS0tLS0g546w5Zy65a6J6KOF57uT5p6cIC0tLS0tLS0tLS0iDQokc2NhbiA9ICcnDQp0
>> "%B64FILE%" echo cnkgeyAkc2NhbiA9ICgmIHBucHV0aWwgL3NjYW4tZGV2aWNlcyAyPiYxIHwgT3V0LVN0cmluZykg
>> "%B64FILE%" echo fSBjYXRjaCB7fQ0KJHNjYW5UeHQgPSAoJHNjYW4gLXJlcGxhY2UgIlxzKyIsICcgJykuVHJpbSgp
>> "%B64FILE%" echo DQpTYXkgKCIgICAgICDorr7lpIfph43mias6ICIgKyAkc2NhblR4dCkgJ0RhcmtHcmF5Jw0KQWRk
>> "%B64FILE%" echo LUxpbmUgKCLorr7lpIfph43mias6ICIgKyAkc2NhblR4dCkNClN0YXJ0LVNsZWVwIC1TZWNvbmRz
>> "%B64FILE%" echo IDMNCg0KJGxvZyA9IEpvaW4tUGF0aCAkZW52OlRFTVAgJ3BucHV0aWxfb25lLmxvZycNCmZvcmVh
>> "%B64FILE%" echo Y2ggKCRpdGVtIGluICRpbnN0YWxsUXVldWUpIHsNCiAgICBpZiAoJGl0ZW0uSW5mcy5Db3VudCAt
>> "%B64FILE%" echo ZXEgMCkgeyBjb250aW51ZSB9DQogICAgZm9yZWFjaCAoJGluZiBpbiAkaXRlbS5JbmZzKSB7DQog
>> "%B64FILE%" echo ICAgICAgIHRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRsb2cpIHsgUmVtb3ZlLUl0
>> "%B64FILE%" echo ZW0gJGxvZyAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9DQogICAgICAg
>> "%B64FILE%" echo IHRyeSB7IGlmIChUZXN0LVBhdGggKCRsb2cgKyAnLmVycicpKSB7IFJlbW92ZS1JdGVtICgkbG9n
>> "%B64FILE%" echo ICsgJy5lcnInKSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9DQogICAg
>> "%B64FILE%" echo ICAgICRwID0gU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggJ3BucHV0aWwuZXhlJyAtQXJndW1lbnRM
>> "%B64FILE%" echo aXN0IEAoJy9hZGQtZHJpdmVyJywgImAiJGluZmAiIiwgJy9pbnN0YWxsJykgYA0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIC1SZWRpcmVjdFN0YW5kYXJkT3V0cHV0ICRsb2cgLVJlZGlyZWN0U3RhbmRhcmRFcnJv
>> "%B64FILE%" echo ciAoJGxvZyArICcuZXJyJykgYA0KICAgICAgICAgICAgICAgIC1Ob05ld1dpbmRvdyAtUGFzc1Ro
>> "%B64FILE%" echo cnUgLUVycm9yQWN0aW9uIFN0b3ANCiAgICAgICAgJHN3ID0gW1N5c3RlbS5EaWFnbm9zdGljcy5T
>> "%B64FILE%" echo dG9wd2F0Y2hdOjpTdGFydE5ldygpDQogICAgICAgIHdoaWxlICgtbm90ICRwLkhhc0V4aXRlZCkg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA1MDANCiAgICAgICAgICAg
>> "%B64FILE%" echo IGlmICgkc3cuRWxhcHNlZE1pbGxpc2Vjb25kcyAtZ3QgMTgwMDAwKSB7IHRyeSB7IFN0b3AtUHJv
>> "%B64FILE%" echo Y2VzcyAtSWQgJHAuSWQgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge307IGJy
>> "%B64FILE%" echo ZWFrIH0NCiAgICAgICAgfQ0KICAgICAgICAkdCA9ICcnDQogICAgICAgIHRyeSB7ICR0ID0gW0lP
>> "%B64FILE%" echo LkZpbGVdOjpSZWFkQWxsVGV4dCgkbG9nLCBbVGV4dC5FbmNvZGluZ106OkRlZmF1bHQpIH0gY2F0
>> "%B64FILE%" echo Y2gge30NCiAgICAgICAgJGUgPSAnJw0KICAgICAgICB0cnkgeyBpZiAoVGVzdC1QYXRoICgkbG9n
>> "%B64FILE%" echo ICsgJy5lcnInKSkgeyAkZSA9IFtJTy5GaWxlXTo6UmVhZEFsbFRleHQoJGxvZyArICcuZXJyJywg
>> "%B64FILE%" echo W1RleHQuRW5jb2RpbmddOjpEZWZhdWx0KSB9IH0gY2F0Y2gge30NCiAgICAgICAgJGxlYWYgPSBT
>> "%B64FILE%" echo cGxpdC1QYXRoIC1MZWFmICRpbmYNCiAgICAgICAgIyBbdjEuMzJdIOiLseaWh+eJiCBwbnB1dGls
>> "%B64FILE%" echo IOeahOaIkOWKn+aPkOekuuaYryAiRHJpdmVyIHBhY2thZ2UgYWRkZWQgc3VjY2Vzc2Z1bGx5Ig0K
>> "%B64FILE%" echo ICAgICAgICAjIO+8iGFkZGVkIOWcqCBzdWNjZXNzZnVsbHkg5YmN6Z2i77yJ77yM5pen5Yy56YWN
>> "%B64FILE%" echo 5Liy5rC46L+c5omT5LiN5Lit77yM5a+86Ie05a6e6ZmF6KOF5LiK5LqG5Lmf5oql44CM5pyq5re7
>> "%B64FILE%" echo 5Yqg44CN44CCDQogICAgICAgICMg5Y+m5aSW5Yqg6amx5Yqo5LuT5bqT5YWc5bqV77ya5paH5a2X
>> "%B64FILE%" echo 5Yy56YWN5LiN5LiK5pe25p+lIHBucHV0aWwgL2VudW0tZHJpdmVycyDnoa7orqTvvIzkuI3lho3k
>> "%B64FILE%" echo vp3otZbmnKzlnLDljJbmloflrZfjgIINCiAgICAgICAgJG9rQWRkID0gKCR0IC1tYXRjaCAn5bey
>> "%B64FILE%" echo 5oiQ5Yqf5re75YqgfOW3suaIkOWKn+WvvOWFpXxhZGRlZCBzdWNjZXNzZnVsbHl8c3VjY2Vzc2Z1
>> "%B64FILE%" echo bGx5IGFkZGVkJykNCiAgICAgICAgaWYgKC1ub3QgJG9rQWRkKSB7DQogICAgICAgICAgICB0cnkg
>> "%B64FILE%" echo eyAkZW51bVR4dCA9ICgmIHBucHV0aWwuZXhlIC9lbnVtLWRyaXZlcnMgMj4mMSB8IE91dC1TdHJp
>> "%B64FILE%" echo bmcpIH0gY2F0Y2ggeyAkZW51bVR4dCA9ICcnIH0NCiAgICAgICAgICAgIGlmICgkZW51bVR4dCAt
>> "%B64FILE%" echo YW5kICRlbnVtVHh0LkluZGV4T2YoJGxlYWYsIFtTdHJpbmdDb21wYXJpc29uXTo6T3JkaW5hbEln
>> "%B64FILE%" echo bm9yZUNhc2UpIC1nZSAwKSB7ICRva0FkZCA9ICR0cnVlIH0NCiAgICAgICAgfQ0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoJG9rQWRkKSB7IFNheSAoIiAgICAgIHswfSA9PiDlt7Lmt7vliqAiIC1mICRsZWFmKSAnR3Jl
>> "%B64FILE%" echo ZW4nIH0gZWxzZSB7IFNheSAoIiAgICAgIHswfSA9PiDmnKrmt7vliqAiIC1mICRsZWFmKSAnWWVs
>> "%B64FILE%" echo bG93JyB9DQogICAgICAgIEFkZC1MaW5lICgiLS0tIHswfSIgLWYgJGluZikNCiAgICAgICAgQWRk
>> "%B64FILE%" echo LUxpbmUgKCIgICAg57uT5p6cOiAiICsgJChpZiAoJG9rQWRkKSB7ICflt7Lmt7vliqAnIH0gZWxz
>> "%B64FILE%" echo ZSB7ICfmnKrmt7vliqAnIH0pKQ0KICAgICAgICBmb3JlYWNoICgkbCBpbiBAKCR0IC1zcGxpdCAi
>> "%B64FILE%" echo W2ByYG5dKyIgfCBXaGVyZS1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFNlbGVjdC1PYmplY3QgLUxh
>> "%B64FILE%" echo c3QgNikpIHsgQWRkLUxpbmUgKCIgICAgIiArICRsKSB9DQogICAgICAgIGlmICgkZS5UcmltKCkp
>> "%B64FILE%" echo IHsgZm9yZWFjaCAoJGwgaW4gQCgkZSAtc3BsaXQgIltgcmBuXSsiIHwgV2hlcmUtT2JqZWN0IHsg
>> "%B64FILE%" echo JF8uVHJpbSgpIH0gfCBTZWxlY3QtT2JqZWN0IC1MYXN0IDQpKSB7IEFkZC1MaW5lICgiICAgIFtl
>> "%B64FILE%" echo cnJdICIgKyAkbCkgfSB9DQogICAgfQ0KfQ0KDQojIC0tLS0tLS0tLS0g5aSN5qC4IC0tLS0tLS0t
>> "%B64FILE%" echo LS0NClNheSAiWzQvNF0g5aSN5qC4IC4uLiIgJ1doaXRlJw0KU3RhcnQtU2xlZXAgLVNlY29uZHMg
>> "%B64FILE%" echo NQ0KdHJ5IHsgJiBwbnB1dGlsIC9zY2FuLWRldmljZXMgMj4mMSB8IE91dC1OdWxsIH0gY2F0Y2gg
>> "%B64FILE%" echo e30NClN0YXJ0LVNsZWVwIC1TZWNvbmRzIDUNCiRhZnRlciA9IEAoR2V0LVJlYWxQcm9ibGVtcykN
>> "%B64FILE%" echo CkFkZC1MaW5lICIiDQpBZGQtTGluZSAiLS0tLS0tLS0tLSDoo4XlrozlkI7ku43mlYXpmpwgLS0t
>> "%B64FILE%" echo LS0tLS0tLSINCkFkZC1MaW5lICgi5YWxIHswfSDkuKoiIC1mICRhZnRlci5Db3VudCkNCmZvcmVh
>> "%B64FILE%" echo Y2ggKCRkIGluICRhZnRlcikgew0KICAgIEFkZC1MaW5lICgiW3swfV0gezF9ICAg6Zeu6aKY56CB
>> "%B64FILE%" echo IHsyfSIgLWYgJGQuU3RhdHVzLCAkZC5GcmllbmRseU5hbWUsICRkLlByb2JsZW0pDQogICAgQWRk
>> "%B64FILE%" echo LUxpbmUgKCIgICAg5a6e5L6LSUQ6IHswfSIgLWYgJGQuSW5zdGFuY2VJZCkNCn0NCg0KJG5ldEFs
>> "%B64FILE%" echo bCA9IEAoR2V0LU5ldEFkYXB0ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpDQokbmV0
>> "%B64FILE%" echo VXAgPSBAKCRuZXRBbGwgfCBXaGVyZS1PYmplY3QgeyAkXy5TdGF0dXMgLWVxICdVcCcgfSkNCkFk
>> "%B64FILE%" echo ZC1MaW5lICIiDQpBZGQtTGluZSAiLS0tLS0tLS0tLSDnvZHljaEgLS0tLS0tLS0tLSINCmZvcmVh
>> "%B64FILE%" echo Y2ggKCRhIGluICRuZXRBbGwpIHsgQWRkLUxpbmUgKCJ7MH0gfCB7MX0gfCB7Mn0iIC1mICRhLk5h
>> "%B64FILE%" echo bWUsICRhLkludGVyZmFjZURlc2NyaXB0aW9uLCAkYS5TdGF0dXMpIH0NCkFkZC1MaW5lICgi54q2
>> "%B64FILE%" echo 5oCB5Li6IFVwIOeahOe9keWNoTogezB9IOS4qiIgLWYgJG5ldFVwLkNvdW50KQ0KQWRkLUxpbmUg
>> "%B64FILE%" echo IiINCkFkZC1MaW5lICI9PT09PT09PT09PT09PT09PT09PSDor4rmlq3nu5PmnZ8gPT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT0iDQoNCiMgLS0tLS0tLS0tLSDlhpnmiqXlkYogLS0tLS0tLS0tLQ0KIyDjgJB2
>> "%B64FILE%" echo MS4yOeOAkeaKpeWRiuS4jeWGjeebtOaOpeS4ouWcqOebmOague+8jOe7n+S4gOi/myA855uYPjpc
>> "%B64FILE%" echo 6Jma5ouf56Gs55uY57O757ufLeaXpeW/l1wNCiMg77yI5Lul5YmN5q+P5Liq55uY5qC56YO95Lya
>> "%B64FILE%" echo 5aSa5LiA5Liq44CM5paw57O757uf6K+K5patLnR4dOOAje+8jOijheWHoOasoeezu+e7n+Wwseez
>> "%B64FILE%" echo iuS4gOeJh++8iQ0KJHNhdmVkID0gQCgpDQpmb3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVy
>> "%B64FILE%" echo cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0
>> "%B64FILE%" echo ZXIpIHsgY29udGludWUgfQ0KICAgIGlmICgkdi5Ecml2ZVR5cGUgLW5lICdGaXhlZCcpIHsgY29u
>> "%B64FILE%" echo dGludWUgfQ0KICAgICRkaXIgPSAiezB9OlzomZrmi5/noaznm5jns7vnu58t5pel5b+XIiAtZiAk
>> "%B64FILE%" echo di5Ecml2ZUxldHRlcg0KICAgIHRyeSB7DQogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRkaXIpKSB7DQogICAgICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0
>> "%B64FILE%" echo b3J5IC1QYXRoICRkaXIgLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wIHwgT3V0LU51bGwNCiAgICAg
>> "%B64FILE%" echo ICAgfQ0KICAgICAgICAkb3V0RmlsZSA9IEpvaW4tUGF0aCAkZGlyICfmlrDns7vnu5/or4rmlq0u
>> "%B64FILE%" echo dHh0Jw0KICAgICAgICAkcmVwb3J0IC1qb2luICJgcmBuIiB8IFNldC1Db250ZW50IC1MaXRlcmFs
>> "%B64FILE%" echo UGF0aCAkb3V0RmlsZSAtRW5jb2RpbmcgVVRGOCAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICAk
>> "%B64FILE%" echo c2F2ZWQgKz0gJG91dEZpbGUNCiAgICB9IGNhdGNoIHt9DQp9DQoNClNheSAiIg0KU2F5ICgiICDn
>> "%B64FILE%" echo nJ/mlYXpmpzvvJroo4XliY0gezB9IOS4qiAtPiDoo4XlkI4gezF9IOS4qiIgLWYgJHByb2JsZW1z
>> "%B64FILE%" echo LkNvdW50LCAkYWZ0ZXIuQ291bnQpICdDeWFuJw0KU2F5ICgiICDnvZHljaEgVXA6IHswfSDkuKoi
>> "%B64FILE%" echo IC1mICRuZXRVcC5Db3VudCkgJ0N5YW4nDQppZiAoJHNhdmVkLkNvdW50IC1ndCAwKSB7DQogICAg
>> "%B64FILE%" echo U2F5ICIgIOaKpeWRiuW3suWGmeWIsO+8miIgJ0dyZWVuJw0KICAgIGZvcmVhY2ggKCRzIGluICRz
>> "%B64FILE%" echo YXZlZCkgeyBTYXkgKCIgICAgICAiICsgJHMpICdHcmVlbicgfQ0KfQ0KU2F5ICIiDQpSZWFkLUhv
>> "%B64FILE%" echo c3QgIiAg5oyJ5Zue6L2m6YCA5Ye6Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=12621"
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
