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
>> "%B64FILE%" echo cHQ6VmVyc2lvbiA9ICcxLjMxJw0KJFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQoNCnRy
>> "%B64FILE%" echo eSB7ICRIb3N0LlVJLlJhd1VJLldpbmRvd1RpdGxlID0gIua4heeQhuWuieijheaui+eVmSB2JCgk
>> "%B64FILE%" echo U2NyaXB0OlZlcnNpb24pIC0gY29ubmVjdHNlZ2Fib3QiIH0gY2F0Y2gge30NCg0KZnVuY3Rpb24g
>> "%B64FILE%" echo U2F5IHsNCiAgICBwYXJhbShbc3RyaW5nXSRUZXh0LCBbc3RyaW5nXSRDb2xvciA9ICdHcmF5JykN
>> "%B64FILE%" echo CiAgICBXcml0ZS1Ib3N0ICRUZXh0IC1Gb3JlZ3JvdW5kQ29sb3IgJENvbG9yDQp9DQoNClNheSAi
>> "%B64FILE%" echo Ig0KU2F5ICIgIOa4heeQhuWuieijheaui+eVmSAgdiQoJFNjcmlwdDpWZXJzaW9uKSIgJ0N5YW4n
>> "%B64FILE%" echo DQpTYXkgIiAg5L2c6ICFOiBjb25uZWN0c2VnYWJvdCIgJ0RhcmtHcmF5Jw0KU2F5ICIgIC0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSIg
>> "%B64FILE%" echo J0RhcmtHcmF5Jw0KU2F5ICIiDQoNCiRhZG1pbiA9IChbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRv
>> "%B64FILE%" echo d3NQcmluY2lwYWxdW1NlY3VyaXR5LlByaW5jaXBhbC5XaW5kb3dzSWRlbnRpdHldOjpHZXRDdXJy
>> "%B64FILE%" echo ZW50KCkpLklzSW5Sb2xlKFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6
>> "%B64FILE%" echo QWRtaW5pc3RyYXRvcikNCmlmICgtbm90ICRhZG1pbikgew0KICAgIFNheSAiICBb6ZSZ6K+vXSDp
>> "%B64FILE%" echo nIDopoHnrqHnkIblkZjmnYPpmZDjgILor7flhbPmjonmnKznqpflj6PvvIzlj7PplK7mnKzmlofk
>> "%B64FILE%" echo u7YgLT4g5Lul566h55CG5ZGY6Lqr5Lu96L+Q6KGM44CCIiAnUmVkJw0KICAgIFNheSAiIg0KICAg
>> "%B64FILE%" echo IFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhpdCAxDQp9DQoNCiMgLS0tLS0t
>> "%B64FILE%" echo LS0tLSAxLiDnu5PmnZ/mrovnlZnnmoQgZGlzbSAtLS0tLS0tLS0tDQpTYXkgIlsxLzNdIOe7k+ad
>> "%B64FILE%" echo n+aui+eVmeeahCBkaXNtLmV4ZSAuLi4iDQoka2lsbGVkID0gMA0KZm9yZWFjaCAoJHAgaW4gQChH
>> "%B64FILE%" echo ZXQtUHJvY2VzcyAtTmFtZSBkaXNtLCBEaXNtSG9zdCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
>> "%B64FILE%" echo aW51ZSkpIHsNCiAgICB0cnkgew0KICAgICAgICBTdG9wLVByb2Nlc3MgLUlkICRwLklkIC1Gb3Jj
>> "%B64FILE%" echo ZSAtRXJyb3JBY3Rpb24gU3RvcA0KICAgICAgICAka2lsbGVkKysNCiAgICAgICAgU2F5ICgiICAg
>> "%B64FILE%" echo ICAg5bey57uT5p2fIHswfSAoUElEIHsxfSkiIC1mICRwLlByb2Nlc3NOYW1lLCAkcC5JZCkgJ0Rh
>> "%B64FILE%" echo cmtHcmF5Jw0KICAgIH0gY2F0Y2ggew0KICAgICAgICBTYXkgKCIgICAgICDnu5PmnZ8gezB9IChQ
>> "%B64FILE%" echo SUQgezF9KSDlpLHotKXvvJp7Mn0iIC1mICRwLlByb2Nlc3NOYW1lLCAkcC5JZCwgJF8uRXhjZXB0
>> "%B64FILE%" echo aW9uLk1lc3NhZ2UpICdZZWxsb3cnDQogICAgfQ0KfQ0KaWYgKCRraWxsZWQgLWVxIDApIHsgU2F5
>> "%B64FILE%" echo ICIgICAgICDmsqHmnInpnIDopoHnu5PmnZ/nmoTov5vnqIsiICdEYXJrR3JheScgfQ0KU3RhcnQt
>> "%B64FILE%" echo U2xlZXAgLU1pbGxpc2Vjb25kcyA4MDANCg0KIyAtLS0tLS0tLS0tIDIuIOWNuOi9veaJgOacieiZ
>> "%B64FILE%" echo muaLn+ejgeebmCAtLS0tLS0tLS0tDQpTYXkgIlsyLzNdIOWNuOi9veaMguedgOeahOiZmuaLn+ej
>> "%B64FILE%" echo geebmCAuLi4iDQokdmRzID0gQChHZXQtRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51
>> "%B64FILE%" echo ZSB8IFdoZXJlLU9iamVjdCB7IFtzdHJpbmddJF8uQnVzVHlwZSAtZXEgJ0ZpbGUgQmFja2VkIFZp
>> "%B64FILE%" echo cnR1YWwnIH0pDQppZiAoJHZkcy5Db3VudCAtZXEgMCkgew0KICAgIFNheSAiICAgICAg5rKh5pyJ
>> "%B64FILE%" echo 5oyC552A55qE6Jma5ouf56OB55uYIiAnRGFya0dyYXknDQp9IGVsc2Ugew0KICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRkIGluICR2ZHMpIHsNCiAgICAgICAgJGxvYyA9IFtzdHJpbmddJGQuTG9jYXRpb24NCiAgICAg
>> "%B64FILE%" echo ICAgU2F5ICgiICAgICAgRGlzayB7MH06IHsxfSIgLWYgJGQuTnVtYmVyLCAkbG9jKSAnRGFya0dy
>> "%B64FILE%" echo YXknDQogICAgICAgIGlmICgtbm90ICRsb2MpIHsgY29udGludWUgfQ0KICAgICAgICAkZHBGaWxl
>> "%B64FILE%" echo ID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImRldGFjaF97MH0udHh0IiAtZiAkZC5OdW1iZXIpDQog
>> "%B64FILE%" echo ICAgICAgIEAoDQogICAgICAgICAgICAic2VsZWN0IHZkaXNrIGZpbGU9YCIkbG9jYCIiLA0KICAg
>> "%B64FILE%" echo ICAgICAgICAgJ2RldGFjaCB2ZGlzayBub2VycicsDQogICAgICAgICAgICAnZXhpdCcNCiAgICAg
>> "%B64FILE%" echo ICAgKSB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0
>> "%B64FILE%" echo DQogICAgICAgICRyID0gJiBkaXNrcGFydCAvcyAkZHBGaWxlIDI+JjEgfCBPdXQtU3RyaW5nDQog
>> "%B64FILE%" echo ICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU2lsZW50bHlDb250aW51ZQ0KICAgICAgICBpZiAoJHIgLW1hdGNoICdzdWNjZXNzZnVsbHl8
>> "%B64FILE%" echo 5oiQ5YqfJykgeyBTYXkgIiAgICAgIOW3suWNuOi9vSIgJ0dyZWVuJyB9DQogICAgICAgIGVsc2Ug
>> "%B64FILE%" echo eyBTYXkgKCIgICAgICDljbjovb3nu5PmnpzvvJoiICsgKCRyIC1yZXBsYWNlICJccysiLCAnICcp
>> "%B64FILE%" echo LlRyaW0oKSkgJ1llbGxvdycgfQ0KICAgIH0NCn0NClN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMg
>> "%B64FILE%" echo ODAwDQoNCiMgLS0tLS0tLS0tLSAzLiDlpITnkIbmsqHmnInlkK/liqjpobnnmoQgdmhkeCAtLS0t
>> "%B64FILE%" echo LS0tLS0tDQojIHYxLjAg5Y+q6K6k5YaZ5q2755qEIE5ld1N5c3RlbURpc2sudmhkeOOAguWuieij
>> "%B64FILE%" echo heWZqOS7jiB2MS4xMSDotbflhYHorrjoh6rlrprkuYnlkI3lrZflkoznm67lvZXvvIwNCiMg6KOF
>> "%B64FILE%" echo 5YiwIEU6XFZIRFxtYWltYWkudmhkeCDml7bljaHmrbvnmoTor53vvIzov5nph4zmoLnmnKzmiavk
>> "%B64FILE%" echo uI3liLDvvIzpgqMgMjBHQiDlsLHkuIDnm7TljaDnnYDnm5jjgIINCiMNCiMg5L2G44CM5rKh5pyJ
>> "%B64FILE%" echo 5ZCv5Yqo6aG544CN5LiN562J5LqO44CM5piv5pys5bel5YW355qE5Z6D5Zy+44CN44CCSHlwZXIt
>> "%B64FILE%" echo ViDnmoTomZrmi5/no4Hnm5jjgIHliKvnmoToo4XmnLrlt6XlhbfjgIENCiMg5L2g6Ieq5bex5omL
>> "%B64FILE%" echo 5Yqo5pS+55qEIHZoZHjvvIzlkIzmoLfmsqHmnIkgLmJvb3QudHh044CCdjEuMSDmiorlroPku6zk
>> "%B64FILE%" echo uIDlvovliJflh7rmnaXpl67jgIzopoHliKDlkJfjgI3vvIwNCiMg6YWN55qE6L+Y5piv5LiA5Y+l
>> "%B64FILE%" echo 44CM5Yig5LqG6IO96IW+5Ye6IDIwR0LjgI3igJTigJQg6L+Z5piv5Zyo6byT5Yqx55So5oi35oyJ
>> "%B64FILE%" echo IHkg5Yig5o6J5Yir5Lq655qE5Lic6KW/77yMDQojIOOAjOebtOaOpeWbnui9pui3s+i/h+OAjeWP
>> "%B64FILE%" echo quaYr+i/kOawlOWlve+8jOS4jeaYr+iuvuiuoeOAgg0KIw0KIyB2MS4yIOi1t+WIhuS4ieexu+Wk
>> "%B64FILE%" echo hOeQhu+8jOingeaWh+S7tuWktOOAgg0KU2F5ICJbMy8zXSDmo4Dmn6XmsqHmnInlkK/liqjpobnn
>> "%B64FILE%" echo moTomZrmi5/no4Hnm5ggLi4uIg0KDQojIOWFqOebmOaJqyAqLnZoZHjvvJrlj6rmjInnm67lvZXl
>> "%B64FILE%" echo kI3liarmnp3vvIzkuI3ov5vns7vnu5/nm67lvZUv5Zue5pS256uZDQojID4+PiBDT01NT046R2V0
>> "%B64FILE%" echo LUFsbFZoZHhGaWxlDQojIOeUsSBf5rqQ56CBXF9idWlsZFxzeW5jX2NvbW1vbi5weSDku44gY29t
>> "%B64FILE%" echo bW9uXEdldC1BbGxWaGR4RmlsZS5wczEg5rOo5YWl44CC5pS56L+Z6YeM5rKh55So77yM5pS55a6M
>> "%B64FILE%" echo 5Lya6KKr6KaG55uW44CCDQpmdW5jdGlvbiBHZXQtQWxsVmhkeEZpbGUgew0KICAgIHBhcmFtKFtp
>> "%B64FILE%" echo bnRdJE1heERlcHRoID0gNikNCiAgICAjIOWPquaMieebruW9leWQjeWJquaene+8jOS4jei/m+ez
>> "%B64FILE%" echo u+e7n+ebruW9lS/lm57mlLbnq5kv5L6d6LWW57yT5a2Y77yM5omA5Lul5rex5bqm5byA5YiwIDYg
>> "%B64FILE%" echo 5Lmf5LiN5oWi44CCDQogICAgIyDnlKggLk5FVCDnmoTnm67lvZXmnprkuL7ogIzkuI3mmK8gR2V0
>> "%B64FILE%" echo LUNoaWxkSXRlbe+8muWQjuiAheavj+WxgumDveimgeeUn+aIkCBQU09iamVjdO+8jA0KICAgICMg
>> "%B64FILE%" echo 5a6e5rWL5ZCM5LiA5qO15qCRIDEwNzQgbXMgdnMgODMgbXPvvIzlt64gMTIg5YCN77yI56qX5Y+j
>> "%B64FILE%" echo 5q+P5qyh5Yi35paw6YO96KaB5omr5LiA6YGN77yM5beu5Yir5b6I5piO5pi+77yJ44CCDQogICAg
>> "%B64FILE%" echo JHNraXAgPSBAKCckUkVDWUNMRS5CSU4nLCAnU3lzdGVtIFZvbHVtZSBJbmZvcm1hdGlvbicsICdX
>> "%B64FILE%" echo aW5kb3dzJywgJ1Byb2dyYW0gRmlsZXMnLA0KICAgICAgICAgICAgICAnUHJvZ3JhbSBGaWxlcyAo
>> "%B64FILE%" echo eDg2KScsICdQcm9ncmFtRGF0YScsICdVc2VycycsICckV2luUkVBZ2VudCcsICdSZWNvdmVyeScs
>> "%B64FILE%" echo DQogICAgICAgICAgICAgICdub2RlX21vZHVsZXMnLCAnLmdpdCcsICdXaW5TeFMnKQ0KICAgICRm
>> "%B64FILE%" echo b3VuZCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkFycmF5TGlzdA0KICAgIGZvcmVh
>> "%B64FILE%" echo Y2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsN
>> "%B64FILE%" echo CiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoJHYuRmlsZVN5c3RlbSAtbmUgJ05URlMnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgaWYgKCR2
>> "%B64FILE%" echo LkRyaXZlVHlwZSAtbmUgJ0ZpeGVkJykgeyBjb250aW51ZSB9DQogICAgICAgICRxdWV1ZSA9IE5l
>> "%B64FILE%" echo dy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLlF1ZXVlDQogICAgICAgICRxdWV1ZS5FbnF1ZXVl
>> "%B64FILE%" echo KEAoIiQoJHYuRHJpdmVMZXR0ZXIpOlwiLCAwKSkNCiAgICAgICAgd2hpbGUgKCRxdWV1ZS5Db3Vu
>> "%B64FILE%" echo dCAtZ3QgMCkgew0KICAgICAgICAgICAgJGN1ciA9ICRxdWV1ZS5EZXF1ZXVlKCkNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICRkaXIgPSBbc3RyaW5nXSRjdXJbMF0NCiAgICAgICAgICAgICRkID0gW2ludF0kY3VyWzFd
>> "%B64FILE%" echo DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRmIGluIFtTeXN0
>> "%B64FILE%" echo ZW0uSU8uRGlyZWN0b3J5XTo6R2V0RmlsZXMoJGRpciwgJyoudmhkeCcpKSB7DQogICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgIFt2b2lkXSRmb3VuZC5BZGQoKE5ldy1PYmplY3QgU3lzdGVtLklPLkZpbGVJbmZv
>> "%B64FILE%" echo ICRmKSkNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9IGNhdGNoIHt9DQogICAgICAg
>> "%B64FILE%" echo ICAgICBpZiAoJGQgLWdlICRNYXhEZXB0aCkgeyBjb250aW51ZSB9DQogICAgICAgICAgICB0cnkg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRzdWIgaW4gW1N5c3RlbS5JTy5EaXJlY3Rvcnld
>> "%B64FILE%" echo OjpFbnVtZXJhdGVEaXJlY3RvcmllcygkZGlyKSkgew0KICAgICAgICAgICAgICAgICAgICBpZiAo
>> "%B64FILE%" echo JHNraXAgLWNvbnRhaW5zIFtTeXN0ZW0uSU8uUGF0aF06OkdldEZpbGVOYW1lKCRzdWIpKSB7IGNv
>> "%B64FILE%" echo bnRpbnVlIH0NCiAgICAgICAgICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgIGlmIChbU3lzdGVtLklPLkZpbGVdOjpHZXRBdHRyaWJ1dGVzKCRzdWIpIC1iYW5kIFtTeXN0
>> "%B64FILE%" echo ZW0uSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgY29udGludWUgfQ0KICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICB9IGNhdGNoIHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICAk
>> "%B64FILE%" echo cXVldWUuRW5xdWV1ZShAKCRzdWIsICgkZCArIDEpKSkNCiAgICAgICAgICAgICAgICB9DQogICAg
>> "%B64FILE%" echo ICAgICAgICB9IGNhdGNoIHt9DQogICAgICAgIH0NCiAgICB9DQogICAgcmV0dXJuICRmb3VuZC5U
>> "%B64FILE%" echo b0FycmF5KCkNCn0NCiMgPDw8IENPTU1PTjpHZXQtQWxsVmhkeEZpbGUNCg0KZnVuY3Rpb24gR2V0
>> "%B64FILE%" echo LVZoZFN0YXRlR3VpZCB7DQogICAgcGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkc3QgPSBbU3lz
>> "%B64FILE%" echo dGVtLklPLlBhdGhdOjpDaGFuZ2VFeHRlbnNpb24oJFBhdGgsICcuYm9vdC50eHQnKQ0KICAgIGlm
>> "%B64FILE%" echo ICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdCkpIHsgcmV0dXJuICcnIH0NCiAgICBm
>> "%B64FILE%" echo b3JlYWNoICgkbG4gaW4gKEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkc3QgLUVuY29kaW5nIFVU
>> "%B64FILE%" echo RjggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgICAgIGlmICgkbG4gLW1h
>> "%B64FILE%" echo dGNoICdeXHMqR3VpZFxzKj1ccyooXHtbMC05YS1mQS1GLV17MzZ9XH0pXHMqJCcpIHsgcmV0dXJu
>> "%B64FILE%" echo ICRtYXRjaGVzWzFdIH0NCiAgICB9DQogICAgcmV0dXJuICcnDQp9DQoNCiMgQkNEIOmHjOi/mOac
>> "%B64FILE%" echo ieayoeaciei/meadoeWQr+WKqOmhue+8iOS4jeWIpOaWreaMh+WQkeWvueS4jeWvue+8jOWPquec
>> "%B64FILE%" echo i+WtmOWcqO+8iQ0KZnVuY3Rpb24gVGVzdC1CY2RFbnRyeVByZXNlbnQgew0KICAgIHBhcmFtKFtz
>> "%B64FILE%" echo dHJpbmddJEd1aWQpDQogICAgaWYgKC1ub3QgJEd1aWQpIHsgcmV0dXJuICRmYWxzZSB9DQogICAg
>> "%B64FILE%" echo JHR4dCA9ICcnDQogICAgdHJ5IHsgJHR4dCA9ICgmIGJjZGVkaXQgL2VudW0gJEd1aWQgMj4mMSB8
>> "%B64FILE%" echo IE91dC1TdHJpbmcpIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0NCiAgICBpZiAoJExBU1RFWElU
>> "%B64FILE%" echo Q09ERSAtbmUgMCkgeyByZXR1cm4gJGZhbHNlIH0NCiAgICBpZiAoJHR4dCAtbWF0Y2ggJ+aJvuS4
>> "%B64FILE%" echo jeWIsHxub3QgZm91bmR85peg5pWIfGludmFsaWR85ouS57udfGRlbmllZCcpIHsgcmV0dXJuICRm
>> "%B64FILE%" echo YWxzZSB9DQogICAgcmV0dXJuICgkdHh0IC1tYXRjaCAnKD9pKWlkZW50aWZpZXJ85qCH6K+G56ym
>> "%B64FILE%" echo JykNCn0NCg0KIyDliKAgdmhkeCDnmoTlkIzml7bmiorml4HovrnnmoQgLmJvb3QudHh0IOS4gOi1
>> "%B64FILE%" echo t+a4heaOieOAgg0KIyDlj6rliKAgdmhkeCDnmoTor53vvIzkuIvmrKHmiavmj4/kvJrmiorov5nl
>> "%B64FILE%" echo hbfnqbrlo7Pph43mlrDlvZLliLAgQiDnsbvlho3pl67kuIDpgY3vvJsNCiMg6ICM5LiU55WZ552A
>> "%B64FILE%" echo IC5ib290LnR4dCDmjIflkJHkuIDkuKrlt7Lnu4/kuI3lrZjlnKjnmoQgdmhkeO+8jOWvueWIq+ea
>> "%B64FILE%" echo hOW3peWFt+S5n+aYr+ivr+WvvOOAgg0KZnVuY3Rpb24gUmVtb3ZlLVZoZFNhZmVseSB7DQogICAg
>> "%B64FILE%" echo cGFyYW0oJEl0ZW0pDQogICAgdHJ5IHsNCiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRo
>> "%B64FILE%" echo ICRJdGVtLlBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wDQogICAgICAgIFNheSAiICAgICAg
>> "%B64FILE%" echo ICAgICAgIOW3suWIoOmZpCIgJ0dyZWVuJw0KICAgICAgICAkc3QgPSBbU3lzdGVtLklPLlBhdGhd
>> "%B64FILE%" echo OjpDaGFuZ2VFeHRlbnNpb24oJEl0ZW0uUGF0aCwgJy5ib290LnR4dCcpDQogICAgICAgIGlmIChU
>> "%B64FILE%" echo ZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdCkgew0KICAgICAgICAgICAgUmVtb3ZlLUl0ZW0gLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRzdCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUNCiAgICAg
>> "%B64FILE%" echo ICAgfQ0KICAgIH0gY2F0Y2ggew0KICAgICAgICBTYXkgKCIgICAgICAgICAgICAg5Yig6Zmk5aSx
>> "%B64FILE%" echo 6LSl77yaIiArICRfLkV4Y2VwdGlvbi5NZXNzYWdlKSAnUmVkJw0KICAgICAgICBTYXkgIiAgICAg
>> "%B64FILE%" echo ICAgICAgICDpgJrluLjmmK/ov5jmnInov5vnqIvljaDnnYDlroMg4oCU4oCUIOmHjeWQr+eUteiE
>> "%B64FILE%" echo keWQjuWGjei3keS4gOasoeacrOW3peWFt+WNs+WPr+OAgiIgJ1llbGxvdycNCiAgICB9DQp9DQoN
>> "%B64FILE%" echo CiRjYXRBID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0ICAgIyDoo4Xl
>> "%B64FILE%" echo pb3nmoTvvIjmnInmnaHnm67vvIkNCiRjYXRCID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlv
>> "%B64FILE%" echo bnMuQXJyYXlMaXN0ICAgIyDmnKzlt6Xlhbfoo4Xov4fjgIHmnaHnm67msqHkuoYNCiRjYXRDID0g
>> "%B64FILE%" echo TmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0ICAgIyDkuI3mmK/mnKznqIvl
>> "%B64FILE%" echo uo/liJvlu7rnmoQNCg0KZm9yZWFjaCAoJGYgaW4gQChHZXQtQWxsVmhkeEZpbGUpKSB7DQogICAg
>> "%B64FILE%" echo JHN6ID0gMA0KICAgIHRyeSB7ICRzeiA9IFttYXRoXTo6Um91bmQoJGYuTGVuZ3RoIC8gMUdCLCAy
>> "%B64FILE%" echo KSB9IGNhdGNoIHt9DQogICAgJHN0ID0gW1N5c3RlbS5JTy5QYXRoXTo6Q2hhbmdlRXh0ZW5zaW9u
>> "%B64FILE%" echo KCRmLkZ1bGxOYW1lLCAnLmJvb3QudHh0JykNCiAgICAkaGFzU3RhdGUgPSBUZXN0LVBhdGggLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRzdA0KICAgICRndWlkID0gJycNCiAgICBpZiAoJGhhc1N0YXRlKSB7ICRndWlk
>> "%B64FILE%" echo ID0gR2V0LVZoZFN0YXRlR3VpZCAtUGF0aCAkZi5GdWxsTmFtZSB9DQogICAgJGl0ZW0gPSBbUFND
>> "%B64FILE%" echo dXN0b21PYmplY3RdQHsgUGF0aCA9ICRmLkZ1bGxOYW1lOyBTaXplR0IgPSAkc3o7IEhhc1N0YXRl
>> "%B64FILE%" echo ID0gJGhhc1N0YXRlIH0NCiAgICBpZiAoVGVzdC1CY2RFbnRyeVByZXNlbnQgLUd1aWQgJGd1aWQp
>> "%B64FILE%" echo IHsNCiAgICAgICAgW3ZvaWRdJGNhdEEuQWRkKCRpdGVtKQ0KICAgIH0gZWxzZWlmICgkaGFzU3Rh
>> "%B64FILE%" echo dGUpIHsNCiAgICAgICAgW3ZvaWRdJGNhdEIuQWRkKCRpdGVtKQ0KICAgIH0gZWxzZSB7DQogICAg
>> "%B64FILE%" echo ICAgIFt2b2lkXSRjYXRDLkFkZCgkaXRlbSkNCiAgICB9DQp9DQoNCmlmICgkY2F0QS5Db3VudCAt
>> "%B64FILE%" echo Z3QgMCkgew0KICAgIFNheSAiICAgICAg5LiL6Z2i6L+Z5Lqb5bey57uP6KOF5aW944CB5ZCv5Yqo
>> "%B64FILE%" echo 6aG56L+Y5Zyo77yM5pys5bel5YW35LiA5b6L5LiN56Kw77yaIiAnRGFya0dyYXknDQogICAgZm9y
>> "%B64FILE%" echo ZWFjaCAoJGl0IGluICRjYXRBKSB7DQogICAgICAgIFNheSAoKCcgICAgICAgIHswfSAgICh7MX0g
>> "%B64FILE%" echo R0IpJyAtZiAkaXQuUGF0aCwgJGl0LlNpemVHQikpICdEYXJrR3JheScNCiAgICB9DQogICAgU2F5
>> "%B64FILE%" echo ICIgICAgICDvvIjopoHliKDlroPku6zor7fnlKjjgIzlj4zlh7vmiJEt5Y246L295paw57O757uf
>> "%B64FILE%" echo LmJhdOOAje+8jOS8mui/nuW8gOacuuiPnOWNleS4gOi1t+a4he+8iSIgJ0RhcmtHcmF5Jw0KfQ0K
>> "%B64FILE%" echo DQppZiAoKCRjYXRCLkNvdW50ICsgJGNhdEMuQ291bnQpIC1lcSAwKSB7DQogICAgU2F5ICIgICAg
>> "%B64FILE%" echo ICDmsqHmnInpnIDopoHlpITnkIbnmoTomZrmi5/no4Hnm5jvvIznjq/looPlt7Lnu4/mmK/lubLl
>> "%B64FILE%" echo h4DnmoQiICdEYXJrR3JheScNCn0gZWxzZSB7DQogICAgaWYgKCRjYXRCLkNvdW50IC1ndCAwKSB7
>> "%B64FILE%" echo DQogICAgICAgIFNheSAiIg0KICAgICAgICBTYXkgKCIgICAgICDjgJBC44CR5pys5bel5YW36KOF
>> "%B64FILE%" echo 6L+H44CB5L2G5ZCv5Yqo6aG55bey57uP5rKh5LqG77yIezB9IOS4qu+8iSIgLWYgJGNhdEIuQ291
>> "%B64FILE%" echo bnQpICdXaGl0ZScNCiAgICAgICAgU2F5ICIgICAgICAgICAg5peB6L655pyJ5pys5bel5YW355WZ
>> "%B64FILE%" echo 5LiL55qEIC5ib290LnR4dO+8jOWIoOaOieS4jeS8muW9seWTjeS7u+S9leiDveWQr+WKqOeahOez
>> "%B64FILE%" echo u+e7n+OAgiIgJ0RhcmtHcmF5Jw0KICAgICAgICBmb3JlYWNoICgkaXQgaW4gJGNhdEIpIHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgIFNheSAoKCcgICAgICAgICAgezB9ICAgKHsxfSBHQiknIC1mICRpdC5QYXRoLCAk
>> "%B64FILE%" echo aXQuU2l6ZUdCKSkgJ1doaXRlJw0KICAgICAgICAgICAgJGFucyA9IFJlYWQtSG9zdCAiICAgICAg
>> "%B64FILE%" echo ICAgICAgIOWIoOmZpOWQl++8n+i+k+WFpSB5IOWIoOmZpO+8jOebtOaOpeWbnui9pui3s+i/hyIN
>> "%B64FILE%" echo CiAgICAgICAgICAgIGlmICgkYW5zIC1hbmQgKCRhbnMuVHJpbSgpIC1pZXEgJ3knKSkgew0KICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgIFJlbW92ZS1WaGRTYWZlbHkgLUl0ZW0gJGl0DQogICAgICAgICAgICB9IGVs
>> "%B64FILE%" echo c2Ugew0KICAgICAgICAgICAgICAgIFNheSAiICAgICAgICAgICAgIOW3sui3s+i/hyIgJ0RhcmtH
>> "%B64FILE%" echo cmF5Jw0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQogICAgfQ0KICAgIGlmICgkY2F0Qy5Db3Vu
>> "%B64FILE%" echo dCAtZ3QgMCkgew0KICAgICAgICBTYXkgIiINCiAgICAgICAgU2F5ICgiICAgICAg44CQQ+OAkeS4
>> "%B64FILE%" echo jeaYr+acrOeoi+W6j+WIm+W7uueahO+8iHswfSDkuKrvvIkiIC1mICRjYXRDLkNvdW50KSAnV2hp
>> "%B64FILE%" echo dGUnDQogICAgICAgIFNheSAiICAgICAgICAgIOayoeacieacrOeoi+W6j+eVmeS4i+eahCAuYm9v
>> "%B64FILE%" echo dC50eHTjgILlj6/og73mmK8gSHlwZXItViDomZrmi5/no4Hnm5jjgIHliKvnmoToo4XmnLoiICdE
>> "%B64FILE%" echo YXJrR3JheScNCiAgICAgICAgU2F5ICIgICAgICAgICAg5bel5YW377yM5oiW6ICF5L2g6Ieq5bex
>> "%B64FILE%" echo 5pS+55qE5aSH5Lu944CC6buY6K6k5LiN5Yig77yM5Lmf5LiN5bu66K6u5Yig44CCIiAnRGFya0dy
>> "%B64FILE%" echo YXknDQogICAgICAgIGZvcmVhY2ggKCRpdCBpbiAkY2F0Qykgew0KICAgICAgICAgICAgJGZuID0g
>> "%B64FILE%" echo W1N5c3RlbS5JTy5QYXRoXTo6R2V0RmlsZU5hbWUoJGl0LlBhdGgpDQogICAgICAgICAgICBTYXkg
>> "%B64FILE%" echo KCgnICAgICAgICAgIHswfSAgICh7MX0gR0IpJyAtZiAkaXQuUGF0aCwgJGl0LlNpemVHQikpICdX
>> "%B64FILE%" echo aGl0ZScNCiAgICAgICAgICAgICRhbnMgPSBSZWFkLUhvc3QgKCIgICAgICAgICAgICAg56Gu5a6e
>> "%B64FILE%" echo 6KaB5Yig5bCx6L6T5YWl5paH5Lu25ZCNIHswfe+8iOebtOaOpeWbnui9pui3s+i/h++8iSIgLWYg
>> "%B64FILE%" echo JGZuKQ0KICAgICAgICAgICAgaWYgKC1ub3QgJGFucykgew0KICAgICAgICAgICAgICAgIFNheSAi
>> "%B64FILE%" echo ICAgICAgICAgICAgIOW3sui3s+i/hyIgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgfSBlbHNlaWYg
>> "%B64FILE%" echo KCRhbnMuVHJpbSgpIC1pZXEgJGZuKSB7DQogICAgICAgICAgICAgICAgUmVtb3ZlLVZoZFNhZmVs
>> "%B64FILE%" echo eSAtSXRlbSAkaXQNCiAgICAgICAgICAgIH0gZWxzZSB7DQogICAgICAgICAgICAgICAgIyDliKvn
>> "%B64FILE%" echo lKjpu4TlrZfor7TjgIzmlofku7blkI3kuI3lr7njgI3igJTigJQg5b6I5aSa5Lq65Lya5YWI6K+V
>> "%B64FILE%" echo IHkgLyB5ZXPvvIzlhbblrp7ku5bmmK/nnJ/mg7PliKDvvIwNCiAgICAgICAgICAgICAgICAjIOWP
>> "%B64FILE%" echo quaYr+S4jeefpemBk+i/meS4gOagj+imgeeahOS4jeaYryB544CC6L+Z6YeM5Y+q5bmz6Z2Z5Zyw
>> "%B64FILE%" echo 6K+05riF5qWa44CM5oCO5LmI5Yig44CN77yM5LiN5Yik6ZSZ44CCDQogICAgICAgICAgICAgICAg
>> "%B64FILE%" echo U2F5ICgiICAgICAgICAgICAgIOW3sui3s+i/h+OAguimgeWIoOi/meS4gOS4qu+8jOivt+i+k+WF
>> "%B64FILE%" echo peWujOaVtOaWh+S7tuWQje+8mnswfSIgLWYgJGZuKSAnRGFya0dyYXknDQogICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgaWYgKCRhbnMuVHJpbSgpIC1pbWF0Y2ggJ14oeXx5ZXN85pivfOWIoHzliKDpmaR8b2spJCcp
>> "%B64FILE%" echo IHsNCiAgICAgICAgICAgICAgICAgICAgU2F5ICIgICAgICAgICAgICAg77yI6L+Z5LiA5qCP54m5
>> "%B64FILE%" echo 5oSP5LiN5pS2IHkg4oCU4oCUIOWug+mYsueahOaYr+aJi+a7keWIoOaOieWIq+S6uueahOiZmuaL
>> "%B64FILE%" echo n+ejgeebmO+8iSIgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgIH0N
>> "%B64FILE%" echo CiAgICAgICAgfQ0KICAgIH0NCn0NCg0KIyAtLS0tLS0tLS0tIOesrCA0IOatpe+8iHYxLjI577yJ
>> "%B64FILE%" echo 77ya5riFIGJjZGVkaXQg5a+85Ye6IEJDRCDml7bnlZnkuIvnmoTkvLTnlJ/ml6Xlv5cgLS0tLS0t
>> "%B64FILE%" echo LS0tLQ0KIw0KIyBiY2RlZGl0IC9leHBvcnQg5a+85Ye655qE5piv5LiA5Liq5rOo5YaM6KGoIGhp
>> "%B64FILE%" echo dmXvvIxXaW5kb3dzIOS8mumhuuaJi+WcqOebruagh+aXgei+ueeUn+aIkA0KIyAgIHh4eC5iY2Qu
>> "%B64FILE%" echo TE9HICB4eHguYmNkLkxPRzEgIHh4eC5iY2QuTE9HMg0KIyDnnJ/mnLrlrp7mtYvvvJpEOlwg5qC5
>> "%B64FILE%" echo 5LiK5pSS5LqGIDMxIOS4qiAuYmNkLkxPRyrvvIxEOlzomZrmi5/no4Hnm5hcIOmHjOi/mOaciSAx
>> "%B64FILE%" echo OCDkuKrjgIINCiMg5rOo5oSP6L+Z5Yeg5Liq5Ly055Sf5paH5Lu25bimIEhpZGRlbiArIFN5c3Rl
>> "%B64FILE%" echo bSDlsZ7mgKfvvIxHZXQtQ2hpbGRJdGVtIOW/hemhu+WKoCAtRm9yY2XvvIwNCiMg5ZCm5YiZ5LiA
>> "%B64FILE%" echo 5Liq6YO95omr5LiN5Yiw77yIdjEuMjkg5bCx5piv5ryP5LqG6L+Z5Liq77yM5Yqf6IO96Z2Z6buY
>> "%B64FILE%" echo 5aSx5pWI77yJ44CCDQojIOi/meS6m+aYr+WvvOWHuui/h+eoi+eahOS4remXtOaWh+S7tu+8jOWv
>> "%B64FILE%" echo ueaBouWkjSBCQ0Qg5rKh5pyJ5Lu75L2V55So5aSE77yM5Yig5o6J5LiN5b2x5ZONIC5iY2Qg5aSH
>> "%B64FILE%" echo 5Lu95pys6Lqr44CCDQojIHYxLjI5IOi1t+WuieijheWZqC/kv67lpI3lt6XlhbfmlLnmiJDjgIzl
>> "%B64FILE%" echo hYjlr7zliLDkuLTml7bnm67lvZXlho3mi7fotJ3jgI3vvIzku6XlkI7kuI3kvJrlho3kuqfnlJ/v
>> "%B64FILE%" echo vJsNCiMg6L+Z5LiA6IqC5piv57uZ5bey57uP5pSS5LiL5p2l55qE6YKj5Lqb5pS25bC+44CCDQok
>> "%B64FILE%" echo c3RyYXlMb2dzID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQojDQoj
>> "%B64FILE%" echo IOOAkHYxLjMxIOWuieWFqOWKoOWbuuOAkeS7peWJjeaYr+aLvyAnKi5iY2QuTE9HKicg6YCa6YWN
>> "%B64FILE%" echo 5Y675omrIDYg5Liq55uY55qE5qC5ICsg5LiA57qn5a2Q55uu5b2V77yM54S25ZCODQojIOS4gOaK
>> "%B64FILE%" echo iiBSZW1vdmUtSXRlbeOAguWunua1i+ehruWunuayoeWIoOWIsOi/h+ezu+e7n+aWh+S7tiDigJTi
>> "%B64FILE%" echo gJQg5L2G6YKj5piv6Z2gIC1GaWx0ZXIg55qEIDguMyDnn63lkI3ljLnphY0NCiMg5oCq55mW56Kw
>> "%B64FILE%" echo 5ben5LiN5Yy56YWN44CMQkNELkxPR+OAje+8jOS4jeaYr+S7o+eggemHjOaciemYsuaKpOOAguiA
>> "%B64FILE%" echo jCBDOlxCb290XEJDRC5MT0cgLyBCQ0QuTE9HMSAvDQojIEJDRC5MT0cyIOaYryoq5rS75YqoIEJD
>> "%B64FILE%" echo RCDnmoTkuovliqHml6Xlv5cqKu+8jOWQjeWtl+WPquW3ruS4pOS4quWtl+avje+8jOaNouS4quWG
>> "%B64FILE%" echo meazleaIluaNouWPsOacuuWZqOWwseWPr+iDvQ0KIyDlkb3kuK3vvIzliKDmjonmnInmjZ/lnY/l
>> "%B64FILE%" echo kK/liqjphY3nva7nmoTpo47pmanjgIINCiMNCiMg546w5Zyo5pS55oiQ55m95ZCN5Y2V77ya5Y+q
>> "%B64FILE%" echo 6K6k5pys56iL5bqP5Y6G5Luj5a+85Ye655qE6YKj56eN5Zu65a6a5qC85byP77yM5Yir55qE5LiA
>> "%B64FILE%" echo 5b6L5LiN56Kw44CCDQojICAgYmNkLWJhY2t1cC08eXl5eU1NZGQ+LTxISG1tc3M+LmJjZC5MT0cg
>> "%B64FILE%" echo LyAuTE9HMSAvIC5MT0cyDQojICAgYmNkLWJhY2t1cC1maXgtPHl5eXlNTWRkPi08SEhtbXNzPi5i
>> "%B64FILE%" echo Y2QuTE9HIC4uLg0KIyAgIGJjZC1yZXNjdWUtPHl5eXlNTWRkPi08SEhtbXNzPi5iY2QuTE9HIC4u
>> "%B64FILE%" echo LiAgIO+8iOaXqeacn+eJiOacrOeUqOi/h+i/meS4quWJjee8gO+8iQ0KIyDlhbPplK7ngrnvvJrl
>> "%B64FILE%" echo v4Xpobvku6UgYmNkLSDlvIDlpLTjgIHkuK3pl7TluKYgOCDkvY3ml6XmnJ8gKyA2IOS9jeaXtumX
>> "%B64FILE%" echo tOOAgeaJqeWxleWQjeaYryAuYmNk44CCDQojIOezu+e7n+iHquW3seeahCBDOlxCb290XEJDRC5M
>> "%B64FILE%" echo T0cg5LiJ5Liq5ZCN5a2X5rKh5pyJ5LiA5qC36IO95a+55LiK77yM5omA5Lul57uT5p6E5LiK5LiN
>> "%B64FILE%" echo 5Y+v6IO96KKr6YCJ5Lit44CCDQojIOebruW9leWxgumdouWGjeaOkumZpOS4gOmBjeezu+e7n+eb
>> "%B64FILE%" echo ruW9le+8jOWPjOS/nemZqeOAgg0KJGlzU3RyYXlCY2RMb2cgPSB7DQogICAgcGFyYW0oW3N0cmlu
>> "%B64FILE%" echo Z10kbikNCiAgICByZXR1cm4gKCRuIC1tYXRjaCAnXmJjZC1bYS16XSsoPzotW2Etel0rKSotXGR7
>> "%B64FILE%" echo OH0tXGR7Nn1cLmJjZFwuTE9HWzAtOV0/JCcpDQp9DQokc2tpcFN1YkRpcnMgPSAnXihXaW5kb3dz
>> "%B64FILE%" echo fFByb2dyYW0gRmlsZXMuKnxcJFJlY3ljbGVcLkJpbnxTeXN0ZW0gVm9sdW1lIEluZm9ybWF0aW9u
>> "%B64FILE%" echo fFVzZXJzfEJvb3R8UmVjb3Zlcnl8RUZJfFBlcmZMb2dzKSQnDQpmb3JlYWNoICgkcnQgaW4gQCgn
>> "%B64FILE%" echo QzpcJywgJ0Q6XCcsICdFOlwnLCAnRjpcJywgJ0c6XCcsICdIOlwnKSkgew0KICAgIGlmICgtbm90
>> "%B64FILE%" echo IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRydCkpIHsgY29udGludWUgfQ0KICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRmIGluIEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJHJ0IC1GaWxlIC1Gb3JjZSAtRUEg
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKCYgJGlzU3RyYXlCY2RMb2cgJGYuTmFt
>> "%B64FILE%" echo ZSkgeyBbdm9pZF0kc3RyYXlMb2dzLkFkZCgkZikgfQ0KICAgIH0NCiAgICBmb3JlYWNoICgkZCBp
>> "%B64FILE%" echo biBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRydCAtRGlyZWN0b3J5IC1Gb3JjZSAtRUEg
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKCRkLk5hbWUgLW1hdGNoICRza2lwU3Vi
>> "%B64FILE%" echo RGlycykgeyBjb250aW51ZSB9DQogICAgICAgIGZvcmVhY2ggKCRmIGluIEAoR2V0LUNoaWxkSXRl
>> "%B64FILE%" echo bSAtTGl0ZXJhbFBhdGggJGQuRnVsbE5hbWUgLUZpbGUgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRp
>> "%B64FILE%" echo bnVlKSkgew0KICAgICAgICAgICAgaWYgKCYgJGlzU3RyYXlCY2RMb2cgJGYuTmFtZSkgeyBbdm9p
>> "%B64FILE%" echo ZF0kc3RyYXlMb2dzLkFkZCgkZikgfQ0KICAgICAgICB9DQogICAgfQ0KfQ0KDQppZiAoJHN0cmF5
>> "%B64FILE%" echo TG9ncy5Db3VudCAtZ3QgMCkgew0KICAgICRzeiA9ICgkc3RyYXlMb2dzIHwgTWVhc3VyZS1PYmpl
>> "%B64FILE%" echo Y3QgLVByb3BlcnR5IExlbmd0aCAtU3VtKS5TdW0NCiAgICBTYXkgIiINCiAgICBTYXkgKCIgICAg
>> "%B64FILE%" echo ICDjgJDpmYTjgJFiY2RlZGl0IOWvvOWHuiBCQ0Qg5pe255WZ5LiL55qE5Ly055Sf5pel5b+X77yI
>> "%B64FILE%" echo ezB9IOS4qu+8jOWFsSB7MTpOMX0gTULvvIkiIC1mICRzdHJheUxvZ3MuQ291bnQsICgkc3ogLyAx
>> "%B64FILE%" echo TUIpKSAnV2hpdGUnDQogICAgU2F5ICIgICAgICAgICAg5bCx5pivIGJjZC1iYWNrdXAtKi5iY2Qg
>> "%B64FILE%" echo 5peB6L6555qEIC5MT0cgLyAuTE9HMSAvIC5MT0cy44CCIiAnRGFya0dyYXknDQogICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICAgICAg5a6D5Lus5piv5a+85Ye66L+H56iL5Lit55qE5Lit6Ze05paH5Lu277yM5Yig5o6J
>> "%B64FILE%" echo 5LiN5b2x5ZONIC5iY2Qg5aSH5Lu95pys6Lqr77yM5Lmf5LiN5b2x5ZON5byA5py644CCIiAnRGFy
>> "%B64FILE%" echo a0dyYXknDQogICAgU2F5ICIgICAgICAgICAg5Y+q6K6k5pys56iL5bqP5a+85Ye655qE5aSH5Lu9
>> "%B64FILE%" echo 5ZCN77yb57O757uf6Ieq5bex55qEIEM6XEJvb3RcQkNELkxPRyDkuI3lnKjojIPlm7TlhoXvvIzn
>> "%B64FILE%" echo u53kuI3kvJrliqjjgIIiICdEYXJrR3JheScNCiAgICBmb3JlYWNoICgkZiBpbiBAKCRzdHJheUxv
>> "%B64FILE%" echo Z3MgfCBTb3J0LU9iamVjdCBGdWxsTmFtZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDgpKSB7DQog
>> "%B64FILE%" echo ICAgICAgIFNheSAoIiAgICAgICAgICAiICsgJGYuRnVsbE5hbWUpICdEYXJrR3JheScNCiAgICB9
>> "%B64FILE%" echo DQogICAgaWYgKCRzdHJheUxvZ3MuQ291bnQgLWd0IDgpIHsgU2F5ICgiICAgICAgICAgIOKApuKA
>> "%B64FILE%" echo piDov5jmnIkgezB9IOS4qiIgLWYgKCRzdHJheUxvZ3MuQ291bnQgLSA4KSkgJ0RhcmtHcmF5JyB9
>> "%B64FILE%" echo DQogICAgJGFucyA9IFJlYWQtSG9zdCAiICAgICAgICAgICAgIOWFqOmDqOWIoOmZpOWQl++8n+i+
>> "%B64FILE%" echo k+WFpSB5IOWIoOmZpO+8jOebtOaOpeWbnui9pui3s+i/hyINCiAgICBpZiAoJGFucyAtYW5kICgk
>> "%B64FILE%" echo YW5zLlRyaW0oKSAtaWVxICd5JykpIHsNCiAgICAgICAgJG9rTiA9IDANCiAgICAgICAgZm9yZWFj
>> "%B64FILE%" echo aCAoJGYgaW4gJHN0cmF5TG9ncykgew0KICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gLUxp
>> "%B64FILE%" echo dGVyYWxQYXRoICRmLkZ1bGxOYW1lIC1Gb3JjZSAtRUEgU3RvcDsgJG9rTisrIH0gY2F0Y2gge30N
>> "%B64FILE%" echo CiAgICAgICAgfQ0KICAgICAgICBTYXkgKCIgICAgICAgICAgICAg5bey5Yig6ZmkIHswfSAvIHsx
>> "%B64FILE%" echo fSDkuKoiIC1mICRva04sICRzdHJheUxvZ3MuQ291bnQpICdHcmVlbicNCiAgICAgICAgaWYgKCRv
>> "%B64FILE%" echo a04gLWx0ICRzdHJheUxvZ3MuQ291bnQpIHsgU2F5ICIgICAgICAgICAgICAg5Yig5LiN5o6J55qE
>> "%B64FILE%" echo 6YCa5bi45piv6KKr5Yir55qE56iL5bqP5Y2g552A77yM6YeN5ZCv5ZCO5YaN6LeR5LiA5qyh5Y2z
>> "%B64FILE%" echo 5Y+vIiAnRGFya0dyYXknIH0NCiAgICB9IGVsc2Ugew0KICAgICAgICBTYXkgIiAgICAgICAgICAg
>> "%B64FILE%" echo ICDlt7Lot7Pov4fvvIjkuIDkuKrpg73msqHliKDvvIkiICdEYXJrR3JheScNCiAgICB9DQp9DQoN
>> "%B64FILE%" echo ClNheSAiIg0KU2F5ICIgIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLSIgJ0RhcmtHcmF5Jw0KU2F5ICIgIOa4heeQhuWujOaIkOOAgiIg
>> "%B64FILE%" echo J0dyZWVuJw0KU2F5ICIiDQpTYXkgIiAg6YeN5paw5a6J6KOF55qE5q2j56Gu5ae/5Yq/77yaIiAn
>> "%B64FILE%" echo V2hpdGUnDQpTYXkgIiAgICAxLiDph43mlrDlj4zlh7vjgIzlj4zlh7vmiJEt6KOF57O757ufLmJh
>> "%B64FILE%" echo dOOAjSIgJ0RhcmtHcmF5Jw0KU2F5ICIgICAgICAg6L+b5bqm5p2h5Lya5pi+56S65bey5YaZ5YWl
>> "%B64FILE%" echo 5aSa5bCRIEdC77yM5pWw5a2X5LiA55u05Zyo5rao5bCx6K+05piO5Zyo5bel5L2c77yM5Yir5oCl
>> "%B64FILE%" echo 552A5YWz5o6JIiAnRGFya0dyYXknDQpTYXkgIiAgICAyLiDoo4Xlrozph43lkK/vvIzlvIDmnLro
>> "%B64FILE%" echo j5zljZXph4zpgInmlrDns7vnu58iICdEYXJrR3JheScNClNheSAiIg0KUmVhZC1Ib3N0ICIgIOaM
>> "%B64FILE%" echo ieWbnui9pumAgOWHuiINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=16546"
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

powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1FILE%" -OriginDir "%ORIGIN%"
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
