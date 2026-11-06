@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 清理安装残留
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
set "PS1FILE=%WORKDIR%\清理安装残留-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/I3JlcXVpcmVzIC1WZXJzaW9uIDUuMQ0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMg5riF55CG5a6J6KOF5q6L55WZICB2
>> "%B64FILE%" echo MS4zDQojIOS9nOiAhTogY29ubmVjdHNlZ2Fib3QNCiMNCiMg55So6YCU77ya5a6J6KOF6L+H56iL
>> "%B64FILE%" echo 5Y2h5q27IC8g5Lit6YCU5YWz5o6J56qX5Y+j5ZCO77yM5py65Zmo5LiK5Lya55WZ5LiLDQojICAg
>> "%B64FILE%" echo MSkg5LiA5Liq6L+Y5rKh57uT5p2f55qEIGRpc20uZXhl77yI5LiA55u05Y2g552AIHZoZHgg5paH
>> "%B64FILE%" echo 5Lu277yJDQojICAgMikg5LiA5Z2X5oyC552A55qE6Jma5ouf56OB55uY77yI5Y2g552A55uY56ym
>> "%B64FILE%" echo 77yM5q+U5aaCIEU677yJDQojICAgMykg5LiA5Liq5Y2K5oiQ5ZOBIHZoZHjvvIjml6fniYjlm7rl
>> "%B64FILE%" echo rprlj6sgTmV3U3lzdGVtRGlzay52aGR477yM546w5Zyo5Y+v5Lul5piv5Lu75oSP5ZCN5a2X77yJ
>> "%B64FILE%" echo DQojIOacrOiEmuacrOaMiemhuuW6j+a4heaOieWug+S7rO+8jOiuqeOAjOWPjOWHu+aIkS3oo4Xn
>> "%B64FILE%" echo s7vnu58uYmF044CN5Y+v5Lul5bmy5YeA5Zyw6YeN6LeR44CCDQojDQojIOesrCAzIOatpeWPquWk
>> "%B64FILE%" echo hOeQhuOAjOayoeacieWQr+WKqOmhueOAjeeahCB2aGR477yM6ICM5LiU5YiG5LiJ57G777yaDQoj
>> "%B64FILE%" echo ICAgQSDoo4Xlpb3jgIHlkK/liqjpobnov5jlnKggICAgICDihpIg5LiA5b6L5LiN56Kw77yI5Yig
>> "%B64FILE%" echo 5a6D6K+355So44CM5Y+M5Ye75oiRLeWNuOi9veaWsOezu+e7ny5iYXTjgI3vvIkNCiMgICBCIOac
>> "%B64FILE%" echo rOeoi+W6j+ijhei/h+OAgeadoeebruayoeS6hiAg4oaSIOaciSAuYm9vdC50eHQg5Li66K+B77yM
>> "%B64FILE%" echo 6L6T5YWlIHkg5Y2z5YigDQojICAgQyDkuI3mmK/mnKznqIvluo/liJvlu7rnmoQgICAgICDihpIg
>> "%B64FILE%" echo 5Y+v6IO95pivIEh5cGVyLVYgLyDliKvnmoTlt6XlhbcgLyDkvaDoh6rlt7HnmoTlpIfku73vvIwN
>> "%B64FILE%" echo CiMgICAgICAgICAgICAgICAgICAgICAgICAgICAgIOm7mOiupOe7neS4jeWIoO+8jOimgeWIoOW+
>> "%B64FILE%" echo l+eFp+edgOi+k+aWh+S7tuWQjQ0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KcGFyYW0oDQogICAgW3N0cmluZ10kT3JpZ2lu
>> "%B64FILE%" echo RGlyID0gJycNCikNCg0KJEVycm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdDb250aW51ZScNCiRTY3Jp
>> "%B64FILE%" echo cHQ6VmVyc2lvbiA9ICcxLjMzJw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQoNCnRy
>> "%B64FILE%" echo eSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIua4heeQhuWuieijheaui+eVmSB2JCgk
>> "%B64FILE%" echo U2NyaXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3QiIH0gY2F0Y2gge30NCg0KIyBbdjEuMzJd
>> "%B64FILE%" echo IOWFseS6q+aooeWdl+OAguaJk+WMheaXtueUsSBzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSDl
>> "%B64FILE%" echo hoXogZTmnKzmlofku7bvvIwNCiMgLmJhdCDovb3ojbfku43mmK/oh6rljIXlkKvljZXmlofku7bj
>> "%B64FILE%" echo gIINCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09DQojIOWFseS6q+aXpeW/l+WHveaVsCAgIHYxLjMyDQojDQojIOacrOaWh+S7tuS4
>> "%B64FILE%" echo jeaYr+WPkeW4g+eJqeOAguaJk+WMhSAuYmF0IOi9veiNt+aXtu+8jHNyYy9idWlsZC9pbmxpbmVf
>> "%B64FILE%" echo c2hhcmVkLnB5IOS8muaKiui/memHjOeahA0KIyDlhoXlrrnlhoXogZTov5vmr4/kuKrlhaXlj6Po
>> "%B64FILE%" echo hJrmnKzvvIzkv53or4Hlj5HluIPlh7rljrvnmoTlkK/liqjlmajku43mmK/oh6rljIXlkKvljZXm
>> "%B64FILE%" echo lofku7YNCiMg77yI6Ieq6Kej5Y6LIGJhdCDlnKjov5DooYzmnJ/msqHlip7ms5XlvJXnlKjlpJbp
>> "%B64FILE%" echo g6jmqKHlnZfvvInjgIINCiMNCiMg6KeE55+p77ya5Y+q5pS56L+Z6YeM77yM5LiN6KaB5YaN5oqK
>> "%B64FILE%" echo 6L+Z5Lqb5Ye95pWw5aSN5Yi25Zue5YWl5Y+j6ISa5pys44CCDQojID09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KDQpmdW5jdGlvbiBT
>> "%B64FILE%" echo YXkgew0KICAgIHBhcmFtKFtzdHJpbmddJFRleHQsIFtzdHJpbmddJENvbG9yID0gJ0dyYXknKQ0K
>> "%B64FILE%" echo ICAgIFdyaXRlLUhvc3QgJFRleHQgLUZvcmVncm91bmRDb2xvciAkQ29sb3INCn0NCg0KU2F5ICIi
>> "%B64FILE%" echo DQpTYXkgIiAg5riF55CG5a6J6KOF5q6L55WZICB2JCgkU2NyaXB0OlZlcnNpb24pIiAnQ3lhbicN
>> "%B64FILE%" echo ClNheSAiICDkvZzogIU6IGNvbm5lY3RzZWdhYm90IiAnRGFya0dyYXknDQpTYXkgIiAgLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiAn
>> "%B64FILE%" echo RGFya0dyYXknDQpTYXkgIiINCg0KJGFkbWluID0gKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93
>> "%B64FILE%" echo c1ByaW5jaXBhbF1bU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJl
>> "%B64FILE%" echo bnQoKSkuSXNJblJvbGUoW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzQnVpbHRJblJvbGVdOjpB
>> "%B64FILE%" echo ZG1pbmlzdHJhdG9yKQ0KaWYgKC1ub3QgJGFkbWluKSB7DQogICAgU2F5ICIgIFvplJnor69dIOmc
>> "%B64FILE%" echo gOimgeeuoeeQhuWRmOadg+mZkOOAguivt+WFs+aOieacrOeql+WPo++8jOWPs+mUruacrOaWh+S7
>> "%B64FILE%" echo tiAtPiDku6XnrqHnkIblkZjouqvku73ov5DooYzjgIIiICdSZWQnDQogICAgU2F5ICIiDQogICAg
>> "%B64FILE%" echo UmVhZC1Ib3N0ICIgIOaMieWbnui9pumAgOWHuiINCiAgICBleGl0IDENCn0NCg0KIyAtLS0tLS0t
>> "%B64FILE%" echo LS0tIDEuIOe7k+adn+aui+eVmeeahCBkaXNtIC0tLS0tLS0tLS0NCiMNCiMgW+WuoeiuoSBQMy0x
>> "%B64FILE%" echo Nl0g5Lul5YmN5peg5p2h5Lu25oqK5py65Zmo5LiK5omA5pyJIGRpc20uZXhlIC8gRGlzbUhvc3Qg
>> "%B64FILE%" echo 5YWo5p2A5o6J44CCDQojIOeUqOaIt+iHquW3seato+WcqOi3kSBESVNNIC9SZXN0b3JlSGVhbHRo
>> "%B64FILE%" echo IOS5n+S8muiiq+S4remAlOaJk+aWreOAguWNoeS9j+eahCBEaXNtSG9zdCDnoa7lrp7or6XmuIXv
>> "%B64FILE%" echo vIjmraPmmK/lroPmjKHkvY/ph43oo4XvvInvvIwNCiMg5L2G5YWI6K6p55So5oi355yL5riF5qWa
>> "%B64FILE%" echo 5Zyo6LeR5LuA5LmI77yM5YaN6Ieq5bex5Yaz5a6a44CCDQpTYXkgIlsxLzNdIOafpeaJvuaui+eV
>> "%B64FILE%" echo meeahCBkaXNtLmV4ZSAuLi4iDQokZGlzbXMgPSBAKEdldC1Qcm9jZXNzIC1OYW1lIGRpc20sIERp
>> "%B64FILE%" echo c21Ib3N0IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQ0KJGtpbGxlZCA9IDANCmlmICgk
>> "%B64FILE%" echo ZGlzbXMuQ291bnQgLWVxIDApIHsNCiAgICBTYXkgIiAgICAgIOayoeacieWcqOi3keeahCIgJ0Rh
>> "%B64FILE%" echo cmtHcmF5Jw0KfSBlbHNlIHsNCiAgICBTYXkgKCIgICAgICDmib7liLAgezB9IOS4qui/m+eoi++8
>> "%B64FILE%" echo mnsxfSIgLWYgJGRpc21zLkNvdW50LCAoKCRkaXNtcyB8IEZvckVhY2gtT2JqZWN0IHsgIiQoJF8u
>> "%B64FILE%" echo UHJvY2Vzc05hbWUpKFBJRCAkKCRfLklkKSkiIH0pIC1qb2luICfjgIEnKSkgJ1llbGxvdycNCiAg
>> "%B64FILE%" echo ICBTYXkgIiAgICAgIOe7k+adn+Wug+S7rOS5n+S8muaJk+aWreS9oOiHquW3seW8gOeahCBESVNN
>> "%B64FILE%" echo IOS7u+WKoe+8iOS+i+WmgiAvUmVzdG9yZUhlYWx0aO+8ieOAgiIgJ0RhcmtHcmF5Jw0KICAgICRh
>> "%B64FILE%" echo bnMgPSBSZWFkLUhvc3QgIiAgICAgIOimgee7k+adn+WQl++8n1t5L05dIg0KICAgIGlmICgkYW5z
>> "%B64FILE%" echo IC1tYXRjaCAnXig/aSl5KGVzKT8kJykgew0KICAgICAgICBmb3JlYWNoICgkcCBpbiAkZGlzbXMp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgU3RvcC1Qcm9jZXNzIC1JZCAk
>> "%B64FILE%" echo cC5JZCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3ANCiAgICAgICAgICAgICAgICAka2lsbGVkKysN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICDlt7Lnu5PmnZ8gezB9IChQSUQgezF9KSIgLWYg
>> "%B64FILE%" echo JHAuUHJvY2Vzc05hbWUsICRwLklkKSAnRGFya0dyYXknDQogICAgICAgICAgICB9IGNhdGNoIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBTYXkgKCIgICAgICDnu5PmnZ8gezB9IChQSUQgezF9KSDlpLHotKXv
>> "%B64FILE%" echo vJp7Mn0iIC1mICRwLlByb2Nlc3NOYW1lLCAkcC5JZCwgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpICdZ
>> "%B64FILE%" echo ZWxsb3cnDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9IGVsc2Ugew0KICAgICAgICBT
>> "%B64FILE%" echo YXkgIiAgICAgIOW3sui3s+i/hyIgJ0RhcmtHcmF5Jw0KICAgIH0NCn0NClN0YXJ0LVNsZWVwIC1N
>> "%B64FILE%" echo aWxsaXNlY29uZHMgODAwDQoNCiMgLS0tLS0tLS0tLSAyLiDljbjovb3omZrmi5/no4Hnm5ggLS0t
>> "%B64FILE%" echo LS0tLS0tLQ0KIw0KIyBb5a6h6K6hIFAzLTE2XSDlkIzkuIDkuKrmr5vnl4XvvJrmiYDmnInmlofk
>> "%B64FILE%" echo u7blnovomZrmi5/nm5jkuIDlvovljbjovb3vvIzljIXmi6wgSHlwZXItViDnmoTomZrmi5/mnLrn
>> "%B64FILE%" echo m5jjgIENCiMg5oiW6ICF55So5oi35q2j5Zyo55So55qEIFZIROOAguWNuOi9veacrOi6q+S4jeS4
>> "%B64FILE%" echo ouaVsOaNru+8jOS9huS8muaKiuWIq+S6uuato+WcqOWBmueahOS6i+aJk+aWreOAgg0KIyDmlLnm
>> "%B64FILE%" echo iJDkuIDlnZfkuIDlnZfpl67vvIzkuI3ngrnlpLTlsLHkuI3liqjjgIINClNheSAiWzIvM10g5oyC
>> "%B64FILE%" echo 6L295Lit55qE6Jma5ouf56OB55uYIC4uLiINCiR2ZHMgPSBAKEdldC1EaXNrIC1FcnJvckFjdGlv
>> "%B64FILE%" echo biBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgW3N0cmluZ10kXy5CdXNUeXBlIC1l
>> "%B64FILE%" echo cSAnRmlsZSBCYWNrZWQgVmlydHVhbCcgfSkNCmlmICgkdmRzLkNvdW50IC1lcSAwKSB7DQogICAg
>> "%B64FILE%" echo U2F5ICIgICAgICDmsqHmnInmjILnnYDnmoTomZrmi5/no4Hnm5giICdEYXJrR3JheScNCn0gZWxz
>> "%B64FILE%" echo ZSB7DQogICAgZm9yZWFjaCAoJGQgaW4gJHZkcykgew0KICAgICAgICAkbG9jID0gW3N0cmluZ10k
>> "%B64FILE%" echo ZC5Mb2NhdGlvbg0KICAgICAgICBTYXkgKCIgICAgICBEaXNrIHswfTogezF9IiAtZiAkZC5OdW1i
>> "%B64FILE%" echo ZXIsICRsb2MpICdEYXJrR3JheScNCiAgICAgICAgaWYgKC1ub3QgJGxvYykgeyBjb250aW51ZSB9
>> "%B64FILE%" echo DQogICAgICAgICRhbnMgPSBSZWFkLUhvc3QgIiAgICAgIOimgeWNuOi9vei/meS4gOWdl+WQl++8
>> "%B64FILE%" echo n1t5L05dIg0KICAgICAgICBpZiAoJGFucyAtbm90bWF0Y2ggJ14oP2kpeShlcyk/JCcpIHsgU2F5
>> "%B64FILE%" echo ICIgICAgICDkv53mjIHmjILovb0iICdEYXJrR3JheSc7IGNvbnRpbnVlIH0NCiAgICAgICAgJGRw
>> "%B64FILE%" echo RmlsZSA9IEpvaW4tUGF0aCAkZW52OlRFTVAgKCJkZXRhY2hfezB9LnR4dCIgLWYgJGQuTnVtYmVy
>> "%B64FILE%" echo KQ0KICAgICAgICBAKA0KICAgICAgICAgICAgInNlbGVjdCB2ZGlzayBmaWxlPWAiJGxvY2AiIiwN
>> "%B64FILE%" echo CiAgICAgICAgICAgICdkZXRhY2ggdmRpc2sgbm9lcnInLA0KICAgICAgICAgICAgJ2V4aXQnDQog
>> "%B64FILE%" echo ICAgICAgICkgfCBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGRwRmlsZSAtRW5jb2RpbmcgRGVm
>> "%B64FILE%" echo YXVsdA0KICAgICAgICAkciA9ICYgZGlza3BhcnQgL3MgJGRwRmlsZSAyPiYxIHwgT3V0LVN0cmlu
>> "%B64FILE%" echo Zw0KICAgICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGRwRmlsZSAtRm9yY2UgLUVycm9y
>> "%B64FILE%" echo QWN0aW9uIFNpbGVudGx5Q29udGludWUNCiAgICAgICAgaWYgKCRyIC1tYXRjaCAnc3VjY2Vzc2Z1
>> "%B64FILE%" echo bGx5fOaIkOWKnycpIHsgU2F5ICIgICAgICDlt7Lljbjovb0iICdHcmVlbicgfQ0KICAgICAgICBl
>> "%B64FILE%" echo bHNlIHsgU2F5ICgiICAgICAg5Y246L2957uT5p6c77yaIiArICgkciAtcmVwbGFjZSAiXHMrIiwg
>> "%B64FILE%" echo JyAnKS5UcmltKCkpICdZZWxsb3cnIH0NCiAgICB9DQp9DQpTdGFydC1TbGVlcCAtTWlsbGlzZWNv
>> "%B64FILE%" echo bmRzIDgwMA0KDQojIC0tLS0tLS0tLS0gMy4g5aSE55CG5rKh5pyJ5ZCv5Yqo6aG555qEIHZoZHgg
>> "%B64FILE%" echo LS0tLS0tLS0tLQ0KIyB2MS4wIOWPquiupOWGmeatu+eahCBOZXdTeXN0ZW1EaXNrLnZoZHjjgILl
>> "%B64FILE%" echo ronoo4Xlmajku44gdjEuMTEg6LW35YWB6K646Ieq5a6a5LmJ5ZCN5a2X5ZKM55uu5b2V77yMDQoj
>> "%B64FILE%" echo IOijheWIsCBFOlxWSERcbWFpbWFpLnZoZHgg5pe25Y2h5q2755qE6K+d77yM6L+Z6YeM5qC55pys
>> "%B64FILE%" echo 5omr5LiN5Yiw77yM6YKjIDIwR0Ig5bCx5LiA55u05Y2g552A55uY44CCDQojDQojIOS9huOAjOay
>> "%B64FILE%" echo oeacieWQr+WKqOmhueOAjeS4jeetieS6juOAjOaYr+acrOW3peWFt+eahOWeg+WcvuOAjeOAgkh5
>> "%B64FILE%" echo cGVyLVYg55qE6Jma5ouf56OB55uY44CB5Yir55qE6KOF5py65bel5YW344CBDQojIOS9oOiHquW3
>> "%B64FILE%" echo seaJi+WKqOaUvueahCB2aGR477yM5ZCM5qC35rKh5pyJIC5ib290LnR4dOOAgnYxLjEg5oqK5a6D
>> "%B64FILE%" echo 5Lus5LiA5b6L5YiX5Ye65p2l6Zeu44CM6KaB5Yig5ZCX44CN77yMDQojIOmFjeeahOi/mOaYr+S4
>> "%B64FILE%" echo gOWPpeOAjOWIoOS6huiDveiFvuWHuiAyMEdC44CN4oCU4oCUIOi/meaYr+WcqOm8k+WKseeUqOaI
>> "%B64FILE%" echo t+aMiSB5IOWIoOaOieWIq+S6uueahOS4nOilv++8jA0KIyDjgIznm7TmjqXlm57ovabot7Pov4fj
>> "%B64FILE%" echo gI3lj6rmmK/ov5DmsJTlpb3vvIzkuI3mmK/orr7orqHjgIINCiMNCiMgdjEuMiDotbfliIbkuInn
>> "%B64FILE%" echo sbvlpITnkIbvvIzop4Hmlofku7blpLTjgIINClNheSAiWzMvM10g5qOA5p+l5rKh5pyJ5ZCv5Yqo
>> "%B64FILE%" echo 6aG555qE6Jma5ouf56OB55uYIC4uLiINCg0KIyDlhajnm5jmiasgKi52aGR477ya5Y+q5oyJ55uu
>> "%B64FILE%" echo 5b2V5ZCN5Ymq5p6d77yM5LiN6L+b57O757uf55uu5b2VL+WbnuaUtuermQ0KIyA+Pj4gQ09NTU9O
>> "%B64FILE%" echo OkdldC1BbGxWaGR4RmlsZQ0KIyDnlLEgX+a6kOeggVxfYnVpbGRcc3luY19jb21tb24ucHkg5LuO
>> "%B64FILE%" echo IGNvbW1vblxHZXQtQWxsVmhkeEZpbGUucHMxIOazqOWFpeOAguaUuei/memHjOayoeeUqO+8jOaU
>> "%B64FILE%" echo ueWujOS8muiiq+imhuebluOAgg0KZnVuY3Rpb24gR2V0LUFsbFZoZHhGaWxlIHsNCiAgICBwYXJh
>> "%B64FILE%" echo bShbaW50XSRNYXhEZXB0aCA9IDYpDQogICAgIyDlj6rmjInnm67lvZXlkI3liarmnp3vvIzkuI3o
>> "%B64FILE%" echo v5vns7vnu5/nm67lvZUv5Zue5pS256uZL+S+nei1lue8k+WtmO+8jOaJgOS7pea3seW6puW8gOWI
>> "%B64FILE%" echo sCA2IOS5n+S4jeaFouOAgg0KICAgICMg55SoIC5ORVQg55qE55uu5b2V5p6a5Li+6ICM5LiN5piv
>> "%B64FILE%" echo IEdldC1DaGlsZEl0ZW3vvJrlkI7ogIXmr4/lsYLpg73opoHnlJ/miJAgUFNPYmplY3TvvIwNCiAg
>> "%B64FILE%" echo ICAjIOWunua1i+WQjOS4gOajteagkSAxMDc0IG1zIHZzIDgzIG1z77yM5beuIDEyIOWAje+8iOeq
>> "%B64FILE%" echo l+WPo+avj+asoeWIt+aWsOmDveimgeaJq+S4gOmBje+8jOW3ruWIq+W+iOaYjuaYvu+8ieOAgg0K
>> "%B64FILE%" echo ICAgICRza2lwID0gQCgnJFJFQ1lDTEUuQklOJywgJ1N5c3RlbSBWb2x1bWUgSW5mb3JtYXRpb24n
>> "%B64FILE%" echo LCAnV2luZG93cycsICdQcm9ncmFtIEZpbGVzJywNCiAgICAgICAgICAgICAgJ1Byb2dyYW0gRmls
>> "%B64FILE%" echo ZXMgKHg4NiknLCAnUHJvZ3JhbURhdGEnLCAnVXNlcnMnLCAnJFdpblJFQWdlbnQnLCAnUmVjb3Zl
>> "%B64FILE%" echo cnknLA0KICAgICAgICAgICAgICAnbm9kZV9tb2R1bGVzJywgJy5naXQnLCAnV2luU3hTJykNCiAg
>> "%B64FILE%" echo ICAkZm91bmQgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QNCiAgICBm
>> "%B64FILE%" echo b3JlYWNoICgkdiBpbiBAKEdldC1Wb2x1bWUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUp
>> "%B64FILE%" echo KSB7DQogICAgICAgIGlmICgtbm90ICR2LkRyaXZlTGV0dGVyKSB7IGNvbnRpbnVlIH0NCiAgICAg
>> "%B64FILE%" echo ICAgaWYgKCR2LkZpbGVTeXN0ZW0gLW5lICdOVEZTJykgeyBjb250aW51ZSB9DQogICAgICAgIGlm
>> "%B64FILE%" echo ICgkdi5Ecml2ZVR5cGUgLW5lICdGaXhlZCcpIHsgY29udGludWUgfQ0KICAgICAgICAkcXVldWUg
>> "%B64FILE%" echo PSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5RdWV1ZQ0KICAgICAgICAkcXVldWUuRW5x
>> "%B64FILE%" echo dWV1ZShAKCIkKCR2LkRyaXZlTGV0dGVyKTpcIiwgMCkpDQogICAgICAgIHdoaWxlICgkcXVldWUu
>> "%B64FILE%" echo Q291bnQgLWd0IDApIHsNCiAgICAgICAgICAgICRjdXIgPSAkcXVldWUuRGVxdWV1ZSgpDQogICAg
>> "%B64FILE%" echo ICAgICAgICAkZGlyID0gW3N0cmluZ10kY3VyWzBdDQogICAgICAgICAgICAkZCA9IFtpbnRdJGN1
>> "%B64FILE%" echo clsxXQ0KICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkZiBpbiBb
>> "%B64FILE%" echo U3lzdGVtLklPLkRpcmVjdG9yeV06OkdldEZpbGVzKCRkaXIsICcqLnZoZHgnKSkgew0KICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICBbdm9pZF0kZm91bmQuQWRkKChOZXctT2JqZWN0IFN5c3RlbS5JTy5GaWxl
>> "%B64FILE%" echo SW5mbyAkZikpDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAgICAgfSBjYXRjaCB7fQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgaWYgKCRkIC1nZSAkTWF4RGVwdGgpIHsgY29udGludWUgfQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo dHJ5IHsNCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkc3ViIGluIFtTeXN0ZW0uSU8uRGlyZWN0
>> "%B64FILE%" echo b3J5XTo6RW51bWVyYXRlRGlyZWN0b3JpZXMoJGRpcikpIHsNCiAgICAgICAgICAgICAgICAgICAg
>> "%B64FILE%" echo aWYgKCRza2lwIC1jb250YWlucyBbU3lzdGVtLklPLlBhdGhdOjpHZXRGaWxlTmFtZSgkc3ViKSkg
>> "%B64FILE%" echo eyBjb250aW51ZSB9DQogICAgICAgICAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICBpZiAoW1N5c3RlbS5JTy5GaWxlXTo6R2V0QXR0cmlidXRlcygkc3ViKSAtYmFuZCBb
>> "%B64FILE%" echo U3lzdGVtLklPLkZpbGVBdHRyaWJ1dGVzXTo6UmVwYXJzZVBvaW50KSB7IGNvbnRpbnVlIH0NCiAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICAgfSBjYXRjaCB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgJHF1ZXVlLkVucXVldWUoQCgkc3ViLCAoJGQgKyAxKSkpDQogICAgICAgICAgICAgICAgfQ0K
>> "%B64FILE%" echo ICAgICAgICAgICAgfSBjYXRjaCB7fQ0KICAgICAgICB9DQogICAgfQ0KICAgIHJldHVybiAkZm91
>> "%B64FILE%" echo bmQuVG9BcnJheSgpDQp9DQojIDw8PCBDT01NT046R2V0LUFsbFZoZHhGaWxlDQoNCmZ1bmN0aW9u
>> "%B64FILE%" echo IEdldC1WaGRTdGF0ZUd1aWQgew0KICAgIHBhcmFtKFtzdHJpbmddJFBhdGgpDQogICAgJHN0ID0g
>> "%B64FILE%" echo W1N5c3RlbS5JTy5QYXRoXTo6Q2hhbmdlRXh0ZW5zaW9uKCRQYXRoLCAnLmJvb3QudHh0JykNCiAg
>> "%B64FILE%" echo ICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkc3QpKSB7IHJldHVybiAnJyB9DQog
>> "%B64FILE%" echo ICAgZm9yZWFjaCAoJGxuIGluIChHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJHN0IC1FbmNvZGlu
>> "%B64FILE%" echo ZyBVVEY4IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJGxu
>> "%B64FILE%" echo IC1tYXRjaCAnXlxzKkd1aWRccyo9XHMqKFx7WzAtOWEtZkEtRi1dezM2fVx9KVxzKiQnKSB7IHJl
>> "%B64FILE%" echo dHVybiAkbWF0Y2hlc1sxXSB9DQogICAgfQ0KICAgIHJldHVybiAnJw0KfQ0KDQojIEJDRCDph4zo
>> "%B64FILE%" echo v5jmnInmsqHmnInov5nmnaHlkK/liqjpobnvvIjkuI3liKTmlq3mjIflkJHlr7nkuI3lr7nvvIzl
>> "%B64FILE%" echo j6rnnIvlrZjlnKjvvIkNCmZ1bmN0aW9uIFRlc3QtQmNkRW50cnlQcmVzZW50IHsNCiAgICBwYXJh
>> "%B64FILE%" echo bShbc3RyaW5nXSRHdWlkKQ0KICAgIGlmICgtbm90ICRHdWlkKSB7IHJldHVybiAkZmFsc2UgfQ0K
>> "%B64FILE%" echo ICAgICR0eHQgPSAnJw0KICAgIHRyeSB7ICR0eHQgPSAoJiBiY2RlZGl0IC9lbnVtICRHdWlkIDI+
>> "%B64FILE%" echo JjEgfCBPdXQtU3RyaW5nKSB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9DQogICAgaWYgKCRMQVNU
>> "%B64FILE%" echo RVhJVENPREUgLW5lIDApIHsgcmV0dXJuICRmYWxzZSB9DQogICAgaWYgKCR0eHQgLW1hdGNoICfm
>> "%B64FILE%" echo ib7kuI3liLB8bm90IGZvdW5kfOaXoOaViHxpbnZhbGlkfOaLkue7nXxkZW5pZWQnKSB7IHJldHVy
>> "%B64FILE%" echo biAkZmFsc2UgfQ0KICAgIHJldHVybiAoJHR4dCAtbWF0Y2ggJyg/aSlpZGVudGlmaWVyfOagh+iv
>> "%B64FILE%" echo huespicpDQp9DQoNCiMg5YigIHZoZHgg55qE5ZCM5pe25oqK5peB6L6555qEIC5ib290LnR4dCDk
>> "%B64FILE%" echo uIDotbfmuIXmjonjgIINCiMg5Y+q5YigIHZoZHgg55qE6K+d77yM5LiL5qyh5omr5o+P5Lya5oqK
>> "%B64FILE%" echo 6L+Z5YW356m65aOz6YeN5paw5b2S5YiwIEIg57G75YaN6Zeu5LiA6YGN77ybDQojIOiAjOS4lOeV
>> "%B64FILE%" echo meedgCAuYm9vdC50eHQg5oyH5ZCR5LiA5Liq5bey57uP5LiN5a2Y5Zyo55qEIHZoZHjvvIzlr7nl
>> "%B64FILE%" echo iKvnmoTlt6XlhbfkuZ/mmK/or6/lr7zjgIINCmZ1bmN0aW9uIFJlbW92ZS1WaGRTYWZlbHkgew0K
>> "%B64FILE%" echo ICAgIHBhcmFtKCRJdGVtKQ0KICAgIHRyeSB7DQogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFs
>> "%B64FILE%" echo UGF0aCAkSXRlbS5QYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICBTYXkgIiAg
>> "%B64FILE%" echo ICAgICAgICAgICDlt7LliKDpmaQiICdHcmVlbicNCiAgICAgICAgJHN0ID0gW1N5c3RlbS5JTy5Q
>> "%B64FILE%" echo YXRoXTo6Q2hhbmdlRXh0ZW5zaW9uKCRJdGVtLlBhdGgsICcuYm9vdC50eHQnKQ0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkc3QpIHsNCiAgICAgICAgICAgIFJlbW92ZS1JdGVt
>> "%B64FILE%" echo IC1MaXRlcmFsUGF0aCAkc3QgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQog
>> "%B64FILE%" echo ICAgICAgIH0NCiAgICB9IGNhdGNoIHsNCiAgICAgICAgU2F5ICgiICAgICAgICAgICAgIOWIoOmZ
>> "%B64FILE%" echo pOWksei0pe+8miIgKyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1JlZCcNCiAgICAgICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICAgICAgICAg6YCa5bi45piv6L+Y5pyJ6L+b56iL5Y2g552A5a6DIOKAlOKAlCDph43lkK/n
>> "%B64FILE%" echo lLXohJHlkI7lho3ot5HkuIDmrKHmnKzlt6XlhbfljbPlj6/jgIIiICdZZWxsb3cnDQogICAgfQ0K
>> "%B64FILE%" echo fQ0KDQokY2F0QSA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdCAgICMg
>> "%B64FILE%" echo 6KOF5aW955qE77yI5pyJ5p2h55uu77yJDQokY2F0QiA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxl
>> "%B64FILE%" echo Y3Rpb25zLkFycmF5TGlzdCAgICMg5pys5bel5YW36KOF6L+H44CB5p2h55uu5rKh5LqGDQokY2F0
>> "%B64FILE%" echo QyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdCAgICMg5LiN5piv5pys
>> "%B64FILE%" echo 56iL5bqP5Yib5bu655qEDQoNCmZvcmVhY2ggKCRmIGluIEAoR2V0LUFsbFZoZHhGaWxlKSkgew0K
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
>> "%B64FILE%" echo bnQgLWd0IDApIHsNCiAgICBTYXkgIiAgICAgIOS4i+mdoui/meS6m+W3sue7j+ijheWlveOAgeWQ
>> "%B64FILE%" echo r+WKqOmhuei/mOWcqO+8jOacrOW3peWFt+S4gOW+i+S4jeeisO+8miIgJ0RhcmtHcmF5Jw0KICAg
>> "%B64FILE%" echo IGZvcmVhY2ggKCRpdCBpbiAkY2F0QSkgew0KICAgICAgICBTYXkgKCgnICAgICAgICB7MH0gICAo
>> "%B64FILE%" echo ezF9IEdCKScgLWYgJGl0LlBhdGgsICRpdC5TaXplR0IpKSAnRGFya0dyYXknDQogICAgfQ0KICAg
>> "%B64FILE%" echo IFNheSAiICAgICAg77yI6KaB5Yig5a6D5Lus6K+355So44CM5Y+M5Ye75oiRLeWNuOi9veaWsOez
>> "%B64FILE%" echo u+e7ny5iYXTjgI3vvIzkvJrov57lvIDmnLroj5zljZXkuIDotbfmuIXvvIkiICdEYXJrR3JheScN
>> "%B64FILE%" echo Cn0NCg0KaWYgKCgkY2F0Qi5Db3VudCArICRjYXRDLkNvdW50KSAtZXEgMCkgew0KICAgIFNheSAi
>> "%B64FILE%" echo ICAgICAg5rKh5pyJ6ZyA6KaB5aSE55CG55qE6Jma5ouf56OB55uY77yM546v5aKD5bey57uP5piv
>> "%B64FILE%" echo 5bmy5YeA55qEIiAnRGFya0dyYXknDQp9IGVsc2Ugew0KICAgIGlmICgkY2F0Qi5Db3VudCAtZ3Qg
>> "%B64FILE%" echo MCkgew0KICAgICAgICBTYXkgIiINCiAgICAgICAgU2F5ICgiICAgICAg44CQQuOAkeacrOW3peWF
>> "%B64FILE%" echo t+ijhei/h+OAgeS9huWQr+WKqOmhueW3sue7j+ayoeS6hu+8iHswfSDkuKrvvIkiIC1mICRjYXRC
>> "%B64FILE%" echo LkNvdW50KSAnV2hpdGUnDQogICAgICAgIFNheSAiICAgICAgICAgIOaXgei+ueacieacrOW3peWF
>> "%B64FILE%" echo t+eVmeS4i+eahCAuYm9vdC50eHTvvIzliKDmjonkuI3kvJrlvbHlk43ku7vkvZXog73lkK/liqjn
>> "%B64FILE%" echo moTns7vnu5/jgIIiICdEYXJrR3JheScNCiAgICAgICAgZm9yZWFjaCAoJGl0IGluICRjYXRCKSB7
>> "%B64FILE%" echo DQogICAgICAgICAgICBTYXkgKCgnICAgICAgICAgIHswfSAgICh7MX0gR0IpJyAtZiAkaXQuUGF0
>> "%B64FILE%" echo aCwgJGl0LlNpemVHQikpICdXaGl0ZScNCiAgICAgICAgICAgICRhbnMgPSBSZWFkLUhvc3QgIiAg
>> "%B64FILE%" echo ICAgICAgICAgICDliKDpmaTlkJfvvJ/ovpPlhaUgeSDliKDpmaTvvIznm7TmjqXlm57ovabot7Po
>> "%B64FILE%" echo v4ciDQogICAgICAgICAgICBpZiAoJGFucyAtYW5kICgkYW5zLlRyaW0oKSAtaWVxICd5JykpIHsN
>> "%B64FILE%" echo CiAgICAgICAgICAgICAgICBSZW1vdmUtVmhkU2FmZWx5IC1JdGVtICRpdA0KICAgICAgICAgICAg
>> "%B64FILE%" echo fSBlbHNlIHsNCiAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICDlt7Lot7Pov4ciICdE
>> "%B64FILE%" echo YXJrR3JheScNCiAgICAgICAgICAgIH0NCiAgICAgICAgfQ0KICAgIH0NCiAgICBpZiAoJGNhdEMu
>> "%B64FILE%" echo Q291bnQgLWd0IDApIHsNCiAgICAgICAgU2F5ICIiDQogICAgICAgIFNheSAoIiAgICAgIOOAkEPj
>> "%B64FILE%" echo gJHkuI3mmK/mnKznqIvluo/liJvlu7rnmoTvvIh7MH0g5Liq77yJIiAtZiAkY2F0Qy5Db3VudCkg
>> "%B64FILE%" echo J1doaXRlJw0KICAgICAgICBTYXkgIiAgICAgICAgICDmsqHmnInmnKznqIvluo/nlZnkuIvnmoQg
>> "%B64FILE%" echo LmJvb3QudHh044CC5Y+v6IO95pivIEh5cGVyLVYg6Jma5ouf56OB55uY44CB5Yir55qE6KOF5py6
>> "%B64FILE%" echo IiAnRGFya0dyYXknDQogICAgICAgIFNheSAiICAgICAgICAgIOW3peWFt++8jOaIluiAheS9oOiH
>> "%B64FILE%" echo quW3seaUvueahOWkh+S7veOAgum7mOiupOS4jeWIoO+8jOS5n+S4jeW7uuiuruWIoOOAgiIgJ0Rh
>> "%B64FILE%" echo cmtHcmF5Jw0KICAgICAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEMpIHsNCiAgICAgICAgICAgICRm
>> "%B64FILE%" echo biA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRpdC5QYXRoKQ0KICAgICAgICAgICAg
>> "%B64FILE%" echo U2F5ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBhdGgsICRpdC5TaXplR0Ip
>> "%B64FILE%" echo KSAnV2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICgiICAgICAgICAgICAgIOeh
>> "%B64FILE%" echo ruWunuimgeWIoOWwsei+k+WFpeaWh+S7tuWQjSB7MH3vvIjnm7TmjqXlm57ovabot7Pov4fvvIki
>> "%B64FILE%" echo IC1mICRmbikNCiAgICAgICAgICAgIGlmICgtbm90ICRhbnMpIHsNCiAgICAgICAgICAgICAgICBT
>> "%B64FILE%" echo YXkgIiAgICAgICAgICAgICDlt7Lot7Pov4ciICdEYXJrR3JheScNCiAgICAgICAgICAgIH0gZWxz
>> "%B64FILE%" echo ZWlmICgkYW5zLlRyaW0oKSAtaWVxICRmbikgew0KICAgICAgICAgICAgICAgIFJlbW92ZS1WaGRT
>> "%B64FILE%" echo YWZlbHkgLUl0ZW0gJGl0DQogICAgICAgICAgICB9IGVsc2Ugew0KICAgICAgICAgICAgICAgICMg
>> "%B64FILE%" echo 5Yir55So6buE5a2X6K+044CM5paH5Lu25ZCN5LiN5a+544CN4oCU4oCUIOW+iOWkmuS6uuS8muWF
>> "%B64FILE%" echo iOivlSB5IC8geWVz77yM5YW25a6e5LuW5piv55yf5oOz5Yig77yMDQogICAgICAgICAgICAgICAg
>> "%B64FILE%" echo IyDlj6rmmK/kuI3nn6XpgZPov5nkuIDmoI/opoHnmoTkuI3mmK8geeOAgui/memHjOWPquW5s+md
>> "%B64FILE%" echo meWcsOivtOa4healmuOAjOaAjuS5iOWIoOOAje+8jOS4jeWIpOmUmeOAgg0KICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgIFNheSAoIiAgICAgICAgICAgICDlt7Lot7Pov4fjgILopoHliKDov5nkuIDkuKrvvIzor7fo
>> "%B64FILE%" echo vpPlhaXlrozmlbTmlofku7blkI3vvJp7MH0iIC1mICRmbikgJ0RhcmtHcmF5Jw0KICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgIGlmICgkYW5zLlRyaW0oKSAtaW1hdGNoICdeKHl8eWVzfOaYr3zliKB85Yig6ZmkfG9r
>> "%B64FILE%" echo KSQnKSB7DQogICAgICAgICAgICAgICAgICAgIFNheSAiICAgICAgICAgICAgIO+8iOi/meS4gOag
>> "%B64FILE%" echo j+eJueaEj+S4jeaUtiB5IOKAlOKAlCDlroPpmLLnmoTmmK/miYvmu5HliKDmjonliKvkurrnmoTo
>> "%B64FILE%" echo mZrmi5/no4Hnm5jvvIkiICdEYXJrR3JheScNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAg
>> "%B64FILE%" echo ICB9DQogICAgICAgIH0NCiAgICB9DQp9DQoNCiMgLS0tLS0tLS0tLSDnrKwgNCDmraXvvIh2MS4y
>> "%B64FILE%" echo Oe+8ie+8mua4hSBiY2RlZGl0IOWvvOWHuiBCQ0Qg5pe255WZ5LiL55qE5Ly055Sf5pel5b+XIC0t
>> "%B64FILE%" echo LS0tLS0tLS0NCiMNCiMgYmNkZWRpdCAvZXhwb3J0IOWvvOWHuueahOaYr+S4gOS4quazqOWGjOih
>> "%B64FILE%" echo qCBoaXZl77yMV2luZG93cyDkvJrpobrmiYvlnKjnm67moIfml4HovrnnlJ/miJANCiMgICB4eHgu
>> "%B64FILE%" echo YmNkLkxPRyAgeHh4LmJjZC5MT0cxICB4eHguYmNkLkxPRzINCiMg55yf5py65a6e5rWL77yaRDpc
>> "%B64FILE%" echo IOagueS4iuaUkuS6hiAzMSDkuKogLmJjZC5MT0cq77yMRDpc6Jma5ouf56OB55uYXCDph4zov5jm
>> "%B64FILE%" echo nIkgMTgg5Liq44CCDQojIOazqOaEj+i/meWHoOS4quS8tOeUn+aWh+S7tuW4piBIaWRkZW4gKyBT
>> "%B64FILE%" echo eXN0ZW0g5bGe5oCn77yMR2V0LUNoaWxkSXRlbSDlv4XpobvliqAgLUZvcmNl77yMDQojIOWQpuWI
>> "%B64FILE%" echo meS4gOS4qumDveaJq+S4jeWIsO+8iHYxLjI5IOWwseaYr+a8j+S6hui/meS4qu+8jOWKn+iDvemd
>> "%B64FILE%" echo mem7mOWkseaViO+8ieOAgg0KIyDov5nkupvmmK/lr7zlh7rov4fnqIvnmoTkuK3pl7Tmlofku7bv
>> "%B64FILE%" echo vIzlr7nmgaLlpI0gQkNEIOayoeacieS7u+S9leeUqOWkhO+8jOWIoOaOieS4jeW9seWTjSAuYmNk
>> "%B64FILE%" echo IOWkh+S7veacrOi6q+OAgg0KIyB2MS4yOSDotbflronoo4Xlmagv5L+u5aSN5bel5YW35pS55oiQ
>> "%B64FILE%" echo 44CM5YWI5a+85Yiw5Li05pe255uu5b2V5YaN5ou36LSd44CN77yM5Lul5ZCO5LiN5Lya5YaN5Lqn
>> "%B64FILE%" echo 55Sf77ybDQojIOi/meS4gOiKguaYr+e7meW3sue7j+aUkuS4i+adpeeahOmCo+S6m+aUtuWwvuOA
>> "%B64FILE%" echo gg0KJHN0cmF5TG9ncyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0K
>> "%B64FILE%" echo Iw0KIyDjgJB2MS4zMSDlronlhajliqDlm7rjgJHku6XliY3mmK/mi78gJyouYmNkLkxPRyonIOmA
>> "%B64FILE%" echo mumFjeWOu+aJqyA2IOS4quebmOeahOaguSArIOS4gOe6p+WtkOebruW9le+8jOeEtuWQjg0KIyDk
>> "%B64FILE%" echo uIDmioogUmVtb3ZlLUl0ZW3jgILlrp7mtYvnoa7lrp7msqHliKDliLDov4fns7vnu5/mlofku7Yg
>> "%B64FILE%" echo 4oCU4oCUIOS9humCo+aYr+mdoCAtRmlsdGVyIOeahCA4LjMg55+t5ZCN5Yy56YWNDQojIOaAqueZ
>> "%B64FILE%" echo lueisOW3p+S4jeWMuemFjeOAjEJDRC5MT0fjgI3vvIzkuI3mmK/ku6PnoIHph4zmnInpmLLmiqTj
>> "%B64FILE%" echo gILogIwgQzpcQm9vdFxCQ0QuTE9HIC8gQkNELkxPRzEgLw0KIyBCQ0QuTE9HMiDmmK8qKua0u+WK
>> "%B64FILE%" echo qCBCQ0Qg55qE5LqL5Yqh5pel5b+XKirvvIzlkI3lrZflj6rlt67kuKTkuKrlrZfmr43vvIzmjaLk
>> "%B64FILE%" echo uKrlhpnms5XmiJbmjaLlj7DmnLrlmajlsLHlj6/og70NCiMg5ZG95Lit77yM5Yig5o6J5pyJ5o2f
>> "%B64FILE%" echo 5Z2P5ZCv5Yqo6YWN572u55qE6aOO6Zmp44CCDQojDQojIOeOsOWcqOaUueaIkOeZveWQjeWNle+8
>> "%B64FILE%" echo muWPquiupOacrOeoi+W6j+WOhuS7o+WvvOWHuueahOmCo+enjeWbuuWumuagvOW8j++8jOWIq+ea
>> "%B64FILE%" echo hOS4gOW+i+S4jeeisOOAgg0KIyAgIGJjZC1iYWNrdXAtPHl5eXlNTWRkPi08SEhtbXNzPi5iY2Qu
>> "%B64FILE%" echo TE9HIC8gLkxPRzEgLyAuTE9HMg0KIyAgIGJjZC1iYWNrdXAtZml4LTx5eXl5TU1kZD4tPEhIbW1z
>> "%B64FILE%" echo cz4uYmNkLkxPRyAuLi4NCiMgICBiY2QtcmVzY3VlLTx5eXl5TU1kZD4tPEhIbW1zcz4uYmNkLkxP
>> "%B64FILE%" echo RyAuLi4gICDvvIjml6nmnJ/niYjmnKznlKjov4fov5nkuKrliY3nvIDvvIkNCiMg5YWz6ZSu54K5
>> "%B64FILE%" echo 77ya5b+F6aG75LulIGJjZC0g5byA5aS044CB5Lit6Ze05bimIDgg5L2N5pel5pyfICsgNiDkvY3m
>> "%B64FILE%" echo l7bpl7TjgIHmianlsZXlkI3mmK8gLmJjZOOAgg0KIyDns7vnu5/oh6rlt7HnmoQgQzpcQm9vdFxC
>> "%B64FILE%" echo Q0QuTE9HIOS4ieS4quWQjeWtl+ayoeacieS4gOagt+iDveWvueS4iu+8jOaJgOS7pee7k+aehOS4
>> "%B64FILE%" echo iuS4jeWPr+iDveiiq+mAieS4reOAgg0KIyDnm67lvZXlsYLpnaLlho3mjpLpmaTkuIDpgY3ns7vn
>> "%B64FILE%" echo u5/nm67lvZXvvIzlj4zkv53pmanjgIINCiRpc1N0cmF5QmNkTG9nID0gew0KICAgIHBhcmFtKFtz
>> "%B64FILE%" echo dHJpbmddJG4pDQogICAgcmV0dXJuICgkbiAtbWF0Y2ggJ15iY2QtW2Etel0rKD86LVthLXpdKykq
>> "%B64FILE%" echo LVxkezh9LVxkezZ9XC5iY2RcLkxPR1swLTldPyQnKQ0KfQ0KJHNraXBTdWJEaXJzID0gJ14oV2lu
>> "%B64FILE%" echo ZG93c3xQcm9ncmFtIEZpbGVzLip8XCRSZWN5Y2xlXC5CaW58U3lzdGVtIFZvbHVtZSBJbmZvcm1h
>> "%B64FILE%" echo dGlvbnxVc2Vyc3xCb290fFJlY292ZXJ5fEVGSXxQZXJmTG9ncykkJw0KZm9yZWFjaCAoJHJ0IGlu
>> "%B64FILE%" echo IEAoJ0M6XCcsICdEOlwnLCAnRTpcJywgJ0Y6XCcsICdHOlwnLCAnSDpcJykpIHsNCiAgICBpZiAo
>> "%B64FILE%" echo LW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkcnQpKSB7IGNvbnRpbnVlIH0NCiAgICBmb3Jl
>> "%B64FILE%" echo YWNoICgkZiBpbiBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRydCAtRmlsZSAtRm9yY2Ug
>> "%B64FILE%" echo LUVBIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRm
>> "%B64FILE%" echo Lk5hbWUpIHsgW3ZvaWRdJHN0cmF5TG9ncy5BZGQoJGYpIH0NCiAgICB9DQogICAgZm9yZWFjaCAo
>> "%B64FILE%" echo JGQgaW4gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkcnQgLURpcmVjdG9yeSAtRm9yY2Ug
>> "%B64FILE%" echo LUVBIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgkZC5OYW1lIC1tYXRjaCAkc2tp
>> "%B64FILE%" echo cFN1YkRpcnMpIHsgY29udGludWUgfQ0KICAgICAgICBmb3JlYWNoICgkZiBpbiBAKEdldC1DaGls
>> "%B64FILE%" echo ZEl0ZW0gLUxpdGVyYWxQYXRoICRkLkZ1bGxOYW1lIC1GaWxlIC1Gb3JjZSAtRUEgU2lsZW50bHlD
>> "%B64FILE%" echo b250aW51ZSkpIHsNCiAgICAgICAgICAgIGlmICgmICRpc1N0cmF5QmNkTG9nICRmLk5hbWUpIHsg
>> "%B64FILE%" echo W3ZvaWRdJHN0cmF5TG9ncy5BZGQoJGYpIH0NCiAgICAgICAgfQ0KICAgIH0NCn0NCg0KaWYgKCRz
>> "%B64FILE%" echo dHJheUxvZ3MuQ291bnQgLWd0IDApIHsNCiAgICAkc3ogPSAoJHN0cmF5TG9ncyB8IE1lYXN1cmUt
>> "%B64FILE%" echo T2JqZWN0IC1Qcm9wZXJ0eSBMZW5ndGggLVN1bSkuU3VtDQogICAgU2F5ICIiDQogICAgU2F5ICgi
>> "%B64FILE%" echo ICAgICAg44CQ6ZmE44CRYmNkZWRpdCDlr7zlh7ogQkNEIOaXtueVmeS4i+eahOS8tOeUn+aXpeW/
>> "%B64FILE%" echo l++8iHswfSDkuKrvvIzlhbEgezE6TjF9IE1C77yJIiAtZiAkc3RyYXlMb2dzLkNvdW50LCAoJHN6
>> "%B64FILE%" echo IC8gMU1CKSkgJ1doaXRlJw0KICAgIFNheSAiICAgICAgICAgIOWwseaYryBiY2QtYmFja3VwLSou
>> "%B64FILE%" echo YmNkIOaXgei+ueeahCAuTE9HIC8gLkxPRzEgLyAuTE9HMuOAgiIgJ0RhcmtHcmF5Jw0KICAgIFNh
>> "%B64FILE%" echo eSAiICAgICAgICAgIOWug+S7rOaYr+WvvOWHuui/h+eoi+S4reeahOS4remXtOaWh+S7tu+8jOWI
>> "%B64FILE%" echo oOaOieS4jeW9seWTjSAuYmNkIOWkh+S7veacrOi6q++8jOS5n+S4jeW9seWTjeW8gOacuuOAgiIg
>> "%B64FILE%" echo J0RhcmtHcmF5Jw0KICAgIFNheSAiICAgICAgICAgIOWPquiupOacrOeoi+W6j+WvvOWHuueahOWk
>> "%B64FILE%" echo h+S7veWQje+8m+ezu+e7n+iHquW3seeahCBDOlxCb290XEJDRC5MT0cg5LiN5Zyo6IyD5Zu05YaF
>> "%B64FILE%" echo 77yM57ud5LiN5Lya5Yqo44CCIiAnRGFya0dyYXknDQogICAgZm9yZWFjaCAoJGYgaW4gQCgkc3Ry
>> "%B64FILE%" echo YXlMb2dzIHwgU29ydC1PYmplY3QgRnVsbE5hbWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCA4KSkg
>> "%B64FILE%" echo ew0KICAgICAgICBTYXkgKCIgICAgICAgICAgIiArICRmLkZ1bGxOYW1lKSAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgfQ0KICAgIGlmICgkc3RyYXlMb2dzLkNvdW50IC1ndCA4KSB7IFNheSAoIiAgICAgICAgICDi
>> "%B64FILE%" echo gKbigKYg6L+Y5pyJIHswfSDkuKoiIC1mICgkc3RyYXlMb2dzLkNvdW50IC0gOCkpICdEYXJrR3Jh
>> "%B64FILE%" echo eScgfQ0KICAgICRhbnMgPSBSZWFkLUhvc3QgIiAgICAgICAgICAgICDlhajpg6jliKDpmaTlkJfv
>> "%B64FILE%" echo vJ/ovpPlhaUgeSDliKDpmaTvvIznm7TmjqXlm57ovabot7Pov4ciDQogICAgaWYgKCRhbnMgLWFu
>> "%B64FILE%" echo ZCAoJGFucy5UcmltKCkgLWllcSAneScpKSB7DQogICAgICAgICRva04gPSAwDQogICAgICAgIGZv
>> "%B64FILE%" echo cmVhY2ggKCRmIGluICRzdHJheUxvZ3MpIHsNCiAgICAgICAgICAgIHRyeSB7IFJlbW92ZS1JdGVt
>> "%B64FILE%" echo IC1MaXRlcmFsUGF0aCAkZi5GdWxsTmFtZSAtRm9yY2UgLUVBIFN0b3A7ICRva04rKyB9IGNhdGNo
>> "%B64FILE%" echo IHt9DQogICAgICAgIH0NCiAgICAgICAgU2F5ICgiICAgICAgICAgICAgIOW3suWIoOmZpCB7MH0g
>> "%B64FILE%" echo LyB7MX0g5LiqIiAtZiAkb2tOLCAkc3RyYXlMb2dzLkNvdW50KSAnR3JlZW4nDQogICAgICAgIGlm
>> "%B64FILE%" echo ICgkb2tOIC1sdCAkc3RyYXlMb2dzLkNvdW50KSB7IFNheSAiICAgICAgICAgICAgIOWIoOS4jeaO
>> "%B64FILE%" echo ieeahOmAmuW4uOaYr+iiq+WIq+eahOeoi+W6j+WNoOedgO+8jOmHjeWQr+WQjuWGjei3keS4gOas
>> "%B64FILE%" echo oeWNs+WPryIgJ0RhcmtHcmF5JyB9DQogICAgfSBlbHNlIHsNCiAgICAgICAgU2F5ICIgICAgICAg
>> "%B64FILE%" echo ICAgICAg5bey6Lez6L+H77yI5LiA5Liq6YO95rKh5Yig77yJIiAnRGFya0dyYXknDQogICAgfQ0K
>> "%B64FILE%" echo fQ0KDQpTYXkgIiINClNheSAiICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iICdEYXJrR3JheScNClNheSAiICDmuIXnkIblrozmiJDj
>> "%B64FILE%" echo gIIiICdHcmVlbicNClNheSAiIg0KU2F5ICIgIOmHjeaWsOWuieijheeahOato+ehruWnv+WKv++8
>> "%B64FILE%" echo miIgJ1doaXRlJw0KU2F5ICIgICAgMS4g6YeN5paw5Y+M5Ye744CM5Y+M5Ye75oiRLeijheezu+e7
>> "%B64FILE%" echo ny5iYXTjgI0iICdEYXJrR3JheScNClNheSAiICAgICAgIOi/m+W6puadoeS8muaYvuekuuW3suWG
>> "%B64FILE%" echo meWFpeWkmuWwkSBHQu+8jOaVsOWtl+S4gOebtOWcqOa2qOWwseivtOaYjuWcqOW3peS9nO+8jOWI
>> "%B64FILE%" echo q+aApeedgOWFs+aOiSIgJ0RhcmtHcmF5Jw0KU2F5ICIgICAgMi4g6KOF5a6M6YeN5ZCv77yM5byA
>> "%B64FILE%" echo 5py66I+c5Y2V6YeM6YCJ5paw57O757ufIiAnRGFya0dyYXknDQpTYXkgIiINClJlYWQtSG9zdCAi
>> "%B64FILE%" echo ICDmjInlm57ovabpgIDlh7oiDQo=
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=18374"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" -OriginDir "%ORIGIN%" %*
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
