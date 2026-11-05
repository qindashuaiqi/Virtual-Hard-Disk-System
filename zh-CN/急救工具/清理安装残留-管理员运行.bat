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
>> "%B64FILE%" echo LS0tLSAxLiDnu5PmnZ/mrovnlZnnmoQgZGlzbSAtLS0tLS0tLS0tDQojDQojIFvlrqHorqEgUDMt
>> "%B64FILE%" echo MTZdIOS7peWJjeaXoOadoeS7tuaKiuacuuWZqOS4iuaJgOaciSBkaXNtLmV4ZSAvIERpc21Ib3N0
>> "%B64FILE%" echo IOWFqOadgOaOieOAgg0KIyDnlKjmiLfoh6rlt7HmraPlnKjot5EgRElTTSAvUmVzdG9yZUhlYWx0
>> "%B64FILE%" echo aCDkuZ/kvJrooqvkuK3pgJTmiZPmlq3jgILljaHkvY/nmoQgRGlzbUhvc3Qg56Gu5a6e6K+l5riF
>> "%B64FILE%" echo 77yI5q2j5piv5a6D5oyh5L2P6YeN6KOF77yJ77yMDQojIOS9huWFiOiuqeeUqOaIt+eci+a4heal
>> "%B64FILE%" echo muWcqOi3keS7gOS5iO+8jOWGjeiHquW3seWGs+WumuOAgg0KU2F5ICJbMS8zXSDmn6Xmib7mrovn
>> "%B64FILE%" echo lZnnmoQgZGlzbS5leGUgLi4uIg0KJGRpc21zID0gQChHZXQtUHJvY2VzcyAtTmFtZSBkaXNtLCBE
>> "%B64FILE%" echo aXNtSG9zdCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkNCiRraWxsZWQgPSAwDQppZiAo
>> "%B64FILE%" echo JGRpc21zLkNvdW50IC1lcSAwKSB7DQogICAgU2F5ICIgICAgICDmsqHmnInlnKjot5HnmoQiICdE
>> "%B64FILE%" echo YXJrR3JheScNCn0gZWxzZSB7DQogICAgU2F5ICgiICAgICAg5om+5YiwIHswfSDkuKrov5vnqIvv
>> "%B64FILE%" echo vJp7MX0iIC1mICRkaXNtcy5Db3VudCwgKCgkZGlzbXMgfCBGb3JFYWNoLU9iamVjdCB7ICIkKCRf
>> "%B64FILE%" echo LlByb2Nlc3NOYW1lKShQSUQgJCgkXy5JZCkpIiB9KSAtam9pbiAn44CBJykpICdZZWxsb3cnDQog
>> "%B64FILE%" echo ICAgU2F5ICIgICAgICDnu5PmnZ/lroPku6zkuZ/kvJrmiZPmlq3kvaDoh6rlt7HlvIDnmoQgRElT
>> "%B64FILE%" echo TSDku7vliqHvvIjkvovlpoIgL1Jlc3RvcmVIZWFsdGjvvInjgIIiICdEYXJrR3JheScNCiAgICAk
>> "%B64FILE%" echo YW5zID0gUmVhZC1Ib3N0ICIgICAgICDopoHnu5PmnZ/lkJfvvJ9beS9OXSINCiAgICBpZiAoJGFu
>> "%B64FILE%" echo cyAtbWF0Y2ggJ14oP2kpeShlcyk/JCcpIHsNCiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJGRpc21z
>> "%B64FILE%" echo KSB7DQogICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAgIFN0b3AtUHJvY2VzcyAtSWQg
>> "%B64FILE%" echo JHAuSWQgLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wDQogICAgICAgICAgICAgICAgJGtpbGxlZCsr
>> "%B64FILE%" echo DQogICAgICAgICAgICAgICAgU2F5ICgiICAgICAg5bey57uT5p2fIHswfSAoUElEIHsxfSkiIC1m
>> "%B64FILE%" echo ICRwLlByb2Nlc3NOYW1lLCAkcC5JZCkgJ0RhcmtHcmF5Jw0KICAgICAgICAgICAgfSBjYXRjaCB7
>> "%B64FILE%" echo DQogICAgICAgICAgICAgICAgU2F5ICgiICAgICAg57uT5p2fIHswfSAoUElEIHsxfSkg5aSx6LSl
>> "%B64FILE%" echo 77yaezJ9IiAtZiAkcC5Qcm9jZXNzTmFtZSwgJHAuSWQsICRfLkV4Y2VwdGlvbi5NZXNzYWdlKSAn
>> "%B64FILE%" echo WWVsbG93Jw0KICAgICAgICAgICAgfQ0KICAgICAgICB9DQogICAgfSBlbHNlIHsNCiAgICAgICAg
>> "%B64FILE%" echo U2F5ICIgICAgICDlt7Lot7Pov4ciICdEYXJrR3JheScNCiAgICB9DQp9DQpTdGFydC1TbGVlcCAt
>> "%B64FILE%" echo TWlsbGlzZWNvbmRzIDgwMA0KDQojIC0tLS0tLS0tLS0gMi4g5Y246L296Jma5ouf56OB55uYIC0t
>> "%B64FILE%" echo LS0tLS0tLS0NCiMNCiMgW+WuoeiuoSBQMy0xNl0g5ZCM5LiA5Liq5q+b55eF77ya5omA5pyJ5paH
>> "%B64FILE%" echo 5Lu25Z6L6Jma5ouf55uY5LiA5b6L5Y246L2977yM5YyF5ousIEh5cGVyLVYg55qE6Jma5ouf5py6
>> "%B64FILE%" echo 55uY44CBDQojIOaIluiAheeUqOaIt+ato+WcqOeUqOeahCBWSETjgILljbjovb3mnKzouqvkuI3k
>> "%B64FILE%" echo uKLmlbDmja7vvIzkvYbkvJrmiorliKvkurrmraPlnKjlgZrnmoTkuovmiZPmlq3jgIINCiMg5pS5
>> "%B64FILE%" echo 5oiQ5LiA5Z2X5LiA5Z2X6Zeu77yM5LiN54K55aS05bCx5LiN5Yqo44CCDQpTYXkgIlsyLzNdIOaM
>> "%B64FILE%" echo gui9veS4reeahOiZmuaLn+ejgeebmCAuLi4iDQokdmRzID0gQChHZXQtRGlzayAtRXJyb3JBY3Rp
>> "%B64FILE%" echo b24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7IFtzdHJpbmddJF8uQnVzVHlwZSAt
>> "%B64FILE%" echo ZXEgJ0ZpbGUgQmFja2VkIFZpcnR1YWwnIH0pDQppZiAoJHZkcy5Db3VudCAtZXEgMCkgew0KICAg
>> "%B64FILE%" echo IFNheSAiICAgICAg5rKh5pyJ5oyC552A55qE6Jma5ouf56OB55uYIiAnRGFya0dyYXknDQp9IGVs
>> "%B64FILE%" echo c2Ugew0KICAgIGZvcmVhY2ggKCRkIGluICR2ZHMpIHsNCiAgICAgICAgJGxvYyA9IFtzdHJpbmdd
>> "%B64FILE%" echo JGQuTG9jYXRpb24NCiAgICAgICAgU2F5ICgiICAgICAgRGlzayB7MH06IHsxfSIgLWYgJGQuTnVt
>> "%B64FILE%" echo YmVyLCAkbG9jKSAnRGFya0dyYXknDQogICAgICAgIGlmICgtbm90ICRsb2MpIHsgY29udGludWUg
>> "%B64FILE%" echo fQ0KICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAgICDopoHljbjovb3ov5nkuIDlnZflkJfv
>> "%B64FILE%" echo vJ9beS9OXSINCiAgICAgICAgaWYgKCRhbnMgLW5vdG1hdGNoICdeKD9pKXkoZXMpPyQnKSB7IFNh
>> "%B64FILE%" echo eSAiICAgICAg5L+d5oyB5oyC6L29IiAnRGFya0dyYXknOyBjb250aW51ZSB9DQogICAgICAgICRk
>> "%B64FILE%" echo cEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICgiZGV0YWNoX3swfS50eHQiIC1mICRkLk51bWJl
>> "%B64FILE%" echo cikNCiAgICAgICAgQCgNCiAgICAgICAgICAgICJzZWxlY3QgdmRpc2sgZmlsZT1gIiRsb2NgIiIs
>> "%B64FILE%" echo DQogICAgICAgICAgICAnZGV0YWNoIHZkaXNrIG5vZXJyJywNCiAgICAgICAgICAgICdleGl0Jw0K
>> "%B64FILE%" echo ICAgICAgICApIHwgU2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRkcEZpbGUgLUVuY29kaW5nIERl
>> "%B64FILE%" echo ZmF1bHQNCiAgICAgICAgJHIgPSAmIGRpc2twYXJ0IC9zICRkcEZpbGUgMj4mMSB8IE91dC1TdHJp
>> "%B64FILE%" echo bmcNCiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUgLUZvcmNlIC1FcnJv
>> "%B64FILE%" echo ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQogICAgICAgIGlmICgkciAtbWF0Y2ggJ3N1Y2Nlc3Nm
>> "%B64FILE%" echo dWxseXzmiJDlip8nKSB7IFNheSAiICAgICAg5bey5Y246L29IiAnR3JlZW4nIH0NCiAgICAgICAg
>> "%B64FILE%" echo ZWxzZSB7IFNheSAoIiAgICAgIOWNuOi9vee7k+aenO+8miIgKyAoJHIgLXJlcGxhY2UgIlxzKyIs
>> "%B64FILE%" echo ICcgJykuVHJpbSgpKSAnWWVsbG93JyB9DQogICAgfQ0KfQ0KU3RhcnQtU2xlZXAgLU1pbGxpc2Vj
>> "%B64FILE%" echo b25kcyA4MDANCg0KIyAtLS0tLS0tLS0tIDMuIOWkhOeQhuayoeacieWQr+WKqOmhueeahCB2aGR4
>> "%B64FILE%" echo IC0tLS0tLS0tLS0NCiMgdjEuMCDlj6rorqTlhpnmrbvnmoQgTmV3U3lzdGVtRGlzay52aGR444CC
>> "%B64FILE%" echo 5a6J6KOF5Zmo5LuOIHYxLjExIOi1t+WFgeiuuOiHquWumuS5ieWQjeWtl+WSjOebruW9le+8jA0K
>> "%B64FILE%" echo IyDoo4XliLAgRTpcVkhEXG1haW1haS52aGR4IOaXtuWNoeatu+eahOivne+8jOi/memHjOagueac
>> "%B64FILE%" echo rOaJq+S4jeWIsO+8jOmCoyAyMEdCIOWwseS4gOebtOWNoOedgOebmOOAgg0KIw0KIyDkvYbjgIzm
>> "%B64FILE%" echo sqHmnInlkK/liqjpobnjgI3kuI3nrYnkuo7jgIzmmK/mnKzlt6XlhbfnmoTlnoPlnL7jgI3jgIJI
>> "%B64FILE%" echo eXBlci1WIOeahOiZmuaLn+ejgeebmOOAgeWIq+eahOijheacuuW3peWFt+OAgQ0KIyDkvaDoh6rl
>> "%B64FILE%" echo t7HmiYvliqjmlL7nmoQgdmhkeO+8jOWQjOagt+ayoeaciSAuYm9vdC50eHTjgIJ2MS4xIOaKiuWu
>> "%B64FILE%" echo g+S7rOS4gOW+i+WIl+WHuuadpemXruOAjOimgeWIoOWQl+OAje+8jA0KIyDphY3nmoTov5jmmK/k
>> "%B64FILE%" echo uIDlj6XjgIzliKDkuobog73ohb7lh7ogMjBHQuOAjeKAlOKAlCDov5nmmK/lnKjpvJPlirHnlKjm
>> "%B64FILE%" echo iLfmjIkgeSDliKDmjonliKvkurrnmoTkuJzopb/vvIwNCiMg44CM55u05o6l5Zue6L2m6Lez6L+H
>> "%B64FILE%" echo 44CN5Y+q5piv6L+Q5rCU5aW977yM5LiN5piv6K6+6K6h44CCDQojDQojIHYxLjIg6LW35YiG5LiJ
>> "%B64FILE%" echo 57G75aSE55CG77yM6KeB5paH5Lu25aS044CCDQpTYXkgIlszLzNdIOajgOafpeayoeacieWQr+WK
>> "%B64FILE%" echo qOmhueeahOiZmuaLn+ejgeebmCAuLi4iDQoNCiMg5YWo55uY5omrICoudmhkeO+8muWPquaMieeb
>> "%B64FILE%" echo ruW9leWQjeWJquaene+8jOS4jei/m+ezu+e7n+ebruW9lS/lm57mlLbnq5kNCiMgPj4+IENPTU1P
>> "%B64FILE%" echo TjpHZXQtQWxsVmhkeEZpbGUNCiMg55SxIF/mupDnoIFcX2J1aWxkXHN5bmNfY29tbW9uLnB5IOS7
>> "%B64FILE%" echo jiBjb21tb25cR2V0LUFsbFZoZHhGaWxlLnBzMSDms6jlhaXjgILmlLnov5nph4zmsqHnlKjvvIzm
>> "%B64FILE%" echo lLnlrozkvJrooqvopobnm5bjgIINCmZ1bmN0aW9uIEdldC1BbGxWaGR4RmlsZSB7DQogICAgcGFy
>> "%B64FILE%" echo YW0oW2ludF0kTWF4RGVwdGggPSA2KQ0KICAgICMg5Y+q5oyJ55uu5b2V5ZCN5Ymq5p6d77yM5LiN
>> "%B64FILE%" echo 6L+b57O757uf55uu5b2VL+WbnuaUtuermS/kvp3otZbnvJPlrZjvvIzmiYDku6Xmt7HluqblvIDl
>> "%B64FILE%" echo iLAgNiDkuZ/kuI3mhaLjgIINCiAgICAjIOeUqCAuTkVUIOeahOebruW9leaemuS4vuiAjOS4jeaY
>> "%B64FILE%" echo ryBHZXQtQ2hpbGRJdGVt77ya5ZCO6ICF5q+P5bGC6YO96KaB55Sf5oiQIFBTT2JqZWN077yMDQog
>> "%B64FILE%" echo ICAgIyDlrp7mtYvlkIzkuIDmo7XmoJEgMTA3NCBtcyB2cyA4MyBtc++8jOW3riAxMiDlgI3vvIjn
>> "%B64FILE%" echo qpflj6Pmr4/mrKHliLfmlrDpg73opoHmiavkuIDpgY3vvIzlt67liKvlvojmmI7mmL7vvInjgIIN
>> "%B64FILE%" echo CiAgICAkc2tpcCA9IEAoJyRSRUNZQ0xFLkJJTicsICdTeXN0ZW0gVm9sdW1lIEluZm9ybWF0aW9u
>> "%B64FILE%" echo JywgJ1dpbmRvd3MnLCAnUHJvZ3JhbSBGaWxlcycsDQogICAgICAgICAgICAgICdQcm9ncmFtIEZp
>> "%B64FILE%" echo bGVzICh4ODYpJywgJ1Byb2dyYW1EYXRhJywgJ1VzZXJzJywgJyRXaW5SRUFnZW50JywgJ1JlY292
>> "%B64FILE%" echo ZXJ5JywNCiAgICAgICAgICAgICAgJ25vZGVfbW9kdWxlcycsICcuZ2l0JywgJ1dpblN4UycpDQog
>> "%B64FILE%" echo ICAgJGZvdW5kID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQogICAg
>> "%B64FILE%" echo Zm9yZWFjaCAoJHYgaW4gQChHZXQtVm9sdW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVl
>> "%B64FILE%" echo KSkgew0KICAgICAgICBpZiAoLW5vdCAkdi5Ecml2ZUxldHRlcikgeyBjb250aW51ZSB9DQogICAg
>> "%B64FILE%" echo ICAgIGlmICgkdi5GaWxlU3lzdGVtIC1uZSAnTlRGUycpIHsgY29udGludWUgfQ0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgJHF1ZXVl
>> "%B64FILE%" echo ID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuUXVldWUNCiAgICAgICAgJHF1ZXVlLkVu
>> "%B64FILE%" echo cXVldWUoQCgiJCgkdi5Ecml2ZUxldHRlcik6XCIsIDApKQ0KICAgICAgICB3aGlsZSAoJHF1ZXVl
>> "%B64FILE%" echo LkNvdW50IC1ndCAwKSB7DQogICAgICAgICAgICAkY3VyID0gJHF1ZXVlLkRlcXVldWUoKQ0KICAg
>> "%B64FILE%" echo ICAgICAgICAgJGRpciA9IFtzdHJpbmddJGN1clswXQ0KICAgICAgICAgICAgJGQgPSBbaW50XSRj
>> "%B64FILE%" echo dXJbMV0NCiAgICAgICAgICAgIHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGYgaW4g
>> "%B64FILE%" echo W1N5c3RlbS5JTy5EaXJlY3RvcnldOjpHZXRGaWxlcygkZGlyLCAnKi52aGR4JykpIHsNCiAgICAg
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgW3ZvaWRdJGZvdW5kLkFkZCgoTmV3LU9iamVjdCBTeXN0ZW0uSU8uRmls
>> "%B64FILE%" echo ZUluZm8gJGYpKQ0KICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAg
>> "%B64FILE%" echo ICAgICAgICAgIGlmICgkZCAtZ2UgJE1heERlcHRoKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAg
>> "%B64FILE%" echo IHRyeSB7DQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHN1YiBpbiBbU3lzdGVtLklPLkRpcmVj
>> "%B64FILE%" echo dG9yeV06OkVudW1lcmF0ZURpcmVjdG9yaWVzKCRkaXIpKSB7DQogICAgICAgICAgICAgICAgICAg
>> "%B64FILE%" echo IGlmICgkc2tpcCAtY29udGFpbnMgW1N5c3RlbS5JTy5QYXRoXTo6R2V0RmlsZU5hbWUoJHN1Yikp
>> "%B64FILE%" echo IHsgY29udGludWUgfQ0KICAgICAgICAgICAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICAgaWYgKFtTeXN0ZW0uSU8uRmlsZV06OkdldEF0dHJpYnV0ZXMoJHN1YikgLWJhbmQg
>> "%B64FILE%" echo W1N5c3RlbS5JTy5GaWxlQXR0cmlidXRlc106OlJlcGFyc2VQb2ludCkgeyBjb250aW51ZSB9DQog
>> "%B64FILE%" echo ICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggeyBjb250aW51ZSB9DQogICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICRxdWV1ZS5FbnF1ZXVlKEAoJHN1YiwgKCRkICsgMSkpKQ0KICAgICAgICAgICAgICAgIH0N
>> "%B64FILE%" echo CiAgICAgICAgICAgIH0gY2F0Y2gge30NCiAgICAgICAgfQ0KICAgIH0NCiAgICByZXR1cm4gJGZv
>> "%B64FILE%" echo dW5kLlRvQXJyYXkoKQ0KfQ0KIyA8PDwgQ09NTU9OOkdldC1BbGxWaGR4RmlsZQ0KDQpmdW5jdGlv
>> "%B64FILE%" echo biBHZXQtVmhkU3RhdGVHdWlkIHsNCiAgICBwYXJhbShbc3RyaW5nXSRQYXRoKQ0KICAgICRzdCA9
>> "%B64FILE%" echo IFtTeXN0ZW0uSU8uUGF0aF06OkNoYW5nZUV4dGVuc2lvbigkUGF0aCwgJy5ib290LnR4dCcpDQog
>> "%B64FILE%" echo ICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSkgeyByZXR1cm4gJycgfQ0K
>> "%B64FILE%" echo ICAgIGZvcmVhY2ggKCRsbiBpbiAoR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRzdCAtRW5jb2Rp
>> "%B64FILE%" echo bmcgVVRGOCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKCRs
>> "%B64FILE%" echo biAtbWF0Y2ggJ15ccypHdWlkXHMqPVxzKihce1swLTlhLWZBLUYtXXszNn1cfSlccyokJykgeyBy
>> "%B64FILE%" echo ZXR1cm4gJG1hdGNoZXNbMV0gfQ0KICAgIH0NCiAgICByZXR1cm4gJycNCn0NCg0KIyBCQ0Qg6YeM
>> "%B64FILE%" echo 6L+Y5pyJ5rKh5pyJ6L+Z5p2h5ZCv5Yqo6aG577yI5LiN5Yik5pat5oyH5ZCR5a+55LiN5a+577yM
>> "%B64FILE%" echo 5Y+q55yL5a2Y5Zyo77yJDQpmdW5jdGlvbiBUZXN0LUJjZEVudHJ5UHJlc2VudCB7DQogICAgcGFy
>> "%B64FILE%" echo YW0oW3N0cmluZ10kR3VpZCkNCiAgICBpZiAoLW5vdCAkR3VpZCkgeyByZXR1cm4gJGZhbHNlIH0N
>> "%B64FILE%" echo CiAgICAkdHh0ID0gJycNCiAgICB0cnkgeyAkdHh0ID0gKCYgYmNkZWRpdCAvZW51bSAkR3VpZCAy
>> "%B64FILE%" echo PiYxIHwgT3V0LVN0cmluZykgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQ0KICAgIGlmICgkTEFT
>> "%B64FILE%" echo VEVYSVRDT0RFIC1uZSAwKSB7IHJldHVybiAkZmFsc2UgfQ0KICAgIGlmICgkdHh0IC1tYXRjaCAn
>> "%B64FILE%" echo 5om+5LiN5YiwfG5vdCBmb3VuZHzml6DmlYh8aW52YWxpZHzmi5Lnu518ZGVuaWVkJykgeyByZXR1
>> "%B64FILE%" echo cm4gJGZhbHNlIH0NCiAgICByZXR1cm4gKCR0eHQgLW1hdGNoICcoP2kpaWRlbnRpZmllcnzmoIfo
>> "%B64FILE%" echo r4bnrKYnKQ0KfQ0KDQojIOWIoCB2aGR4IOeahOWQjOaXtuaKiuaXgei+ueeahCAuYm9vdC50eHQg
>> "%B64FILE%" echo 5LiA6LW35riF5o6J44CCDQojIOWPquWIoCB2aGR4IOeahOivne+8jOS4i+asoeaJq+aPj+S8muaK
>> "%B64FILE%" echo iui/meWFt+epuuWjs+mHjeaWsOW9kuWIsCBCIOexu+WGjemXruS4gOmBje+8mw0KIyDogIzkuJTn
>> "%B64FILE%" echo lZnnnYAgLmJvb3QudHh0IOaMh+WQkeS4gOS4quW3sue7j+S4jeWtmOWcqOeahCB2aGR477yM5a+5
>> "%B64FILE%" echo 5Yir55qE5bel5YW35Lmf5piv6K+v5a+844CCDQpmdW5jdGlvbiBSZW1vdmUtVmhkU2FmZWx5IHsN
>> "%B64FILE%" echo CiAgICBwYXJhbSgkSXRlbSkNCiAgICB0cnkgew0KICAgICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJh
>> "%B64FILE%" echo bFBhdGggJEl0ZW0uUGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3ANCiAgICAgICAgU2F5ICIg
>> "%B64FILE%" echo ICAgICAgICAgICAg5bey5Yig6ZmkIiAnR3JlZW4nDQogICAgICAgICRzdCA9IFtTeXN0ZW0uSU8u
>> "%B64FILE%" echo UGF0aF06OkNoYW5nZUV4dGVuc2lvbigkSXRlbS5QYXRoLCAnLmJvb3QudHh0JykNCiAgICAgICAg
>> "%B64FILE%" echo aWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0KSB7DQogICAgICAgICAgICBSZW1vdmUtSXRl
>> "%B64FILE%" echo bSAtTGl0ZXJhbFBhdGggJHN0IC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0K
>> "%B64FILE%" echo ICAgICAgICB9DQogICAgfSBjYXRjaCB7DQogICAgICAgIFNheSAoIiAgICAgICAgICAgICDliKDp
>> "%B64FILE%" echo maTlpLHotKXvvJoiICsgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpICdSZWQnDQogICAgICAgIFNheSAi
>> "%B64FILE%" echo ICAgICAgICAgICAgIOmAmuW4uOaYr+i/mOaciei/m+eoi+WNoOedgOWugyDigJTigJQg6YeN5ZCv
>> "%B64FILE%" echo 55S16ISR5ZCO5YaN6LeR5LiA5qyh5pys5bel5YW35Y2z5Y+v44CCIiAnWWVsbG93Jw0KICAgIH0N
>> "%B64FILE%" echo Cn0NCg0KJGNhdEEgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgICAj
>> "%B64FILE%" echo IOijheWlveeahO+8iOacieadoeebru+8iQ0KJGNhdEIgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xs
>> "%B64FILE%" echo ZWN0aW9ucy5BcnJheUxpc3QgICAjIOacrOW3peWFt+ijhei/h+OAgeadoeebruayoeS6hg0KJGNh
>> "%B64FILE%" echo dEMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgICAjIOS4jeaYr+ac
>> "%B64FILE%" echo rOeoi+W6j+WIm+W7uueahA0KDQpmb3JlYWNoICgkZiBpbiBAKEdldC1BbGxWaGR4RmlsZSkpIHsN
>> "%B64FILE%" echo CiAgICAkc3ogPSAwDQogICAgdHJ5IHsgJHN6ID0gW21hdGhdOjpSb3VuZCgkZi5MZW5ndGggLyAx
>> "%B64FILE%" echo R0IsIDIpIH0gY2F0Y2gge30NCiAgICAkc3QgPSBbU3lzdGVtLklPLlBhdGhdOjpDaGFuZ2VFeHRl
>> "%B64FILE%" echo bnNpb24oJGYuRnVsbE5hbWUsICcuYm9vdC50eHQnKQ0KICAgICRoYXNTdGF0ZSA9IFRlc3QtUGF0
>> "%B64FILE%" echo aCAtTGl0ZXJhbFBhdGggJHN0DQogICAgJGd1aWQgPSAnJw0KICAgIGlmICgkaGFzU3RhdGUpIHsg
>> "%B64FILE%" echo JGd1aWQgPSBHZXQtVmhkU3RhdGVHdWlkIC1QYXRoICRmLkZ1bGxOYW1lIH0NCiAgICAkaXRlbSA9
>> "%B64FILE%" echo IFtQU0N1c3RvbU9iamVjdF1AeyBQYXRoID0gJGYuRnVsbE5hbWU7IFNpemVHQiA9ICRzejsgSGFz
>> "%B64FILE%" echo U3RhdGUgPSAkaGFzU3RhdGUgfQ0KICAgIGlmIChUZXN0LUJjZEVudHJ5UHJlc2VudCAtR3VpZCAk
>> "%B64FILE%" echo Z3VpZCkgew0KICAgICAgICBbdm9pZF0kY2F0QS5BZGQoJGl0ZW0pDQogICAgfSBlbHNlaWYgKCRo
>> "%B64FILE%" echo YXNTdGF0ZSkgew0KICAgICAgICBbdm9pZF0kY2F0Qi5BZGQoJGl0ZW0pDQogICAgfSBlbHNlIHsN
>> "%B64FILE%" echo CiAgICAgICAgW3ZvaWRdJGNhdEMuQWRkKCRpdGVtKQ0KICAgIH0NCn0NCg0KaWYgKCRjYXRBLkNv
>> "%B64FILE%" echo dW50IC1ndCAwKSB7DQogICAgU2F5ICIgICAgICDkuIvpnaLov5nkupvlt7Lnu4/oo4Xlpb3jgIHl
>> "%B64FILE%" echo kK/liqjpobnov5jlnKjvvIzmnKzlt6XlhbfkuIDlvovkuI3norDvvJoiICdEYXJrR3JheScNCiAg
>> "%B64FILE%" echo ICBmb3JlYWNoICgkaXQgaW4gJGNhdEEpIHsNCiAgICAgICAgU2F5ICgoJyAgICAgICAgezB9ICAg
>> "%B64FILE%" echo KHsxfSBHQiknIC1mICRpdC5QYXRoLCAkaXQuU2l6ZUdCKSkgJ0RhcmtHcmF5Jw0KICAgIH0NCiAg
>> "%B64FILE%" echo ICBTYXkgIiAgICAgIO+8iOimgeWIoOWug+S7rOivt+eUqOOAjOWPjOWHu+aIkS3ljbjovb3mlrDn
>> "%B64FILE%" echo s7vnu58uYmF044CN77yM5Lya6L+e5byA5py66I+c5Y2V5LiA6LW35riF77yJIiAnRGFya0dyYXkn
>> "%B64FILE%" echo DQp9DQoNCmlmICgoJGNhdEIuQ291bnQgKyAkY2F0Qy5Db3VudCkgLWVxIDApIHsNCiAgICBTYXkg
>> "%B64FILE%" echo IiAgICAgIOayoeaciemcgOimgeWkhOeQhueahOiZmuaLn+ejgeebmO+8jOeOr+Wig+W3sue7j+aY
>> "%B64FILE%" echo r+W5suWHgOeahCIgJ0RhcmtHcmF5Jw0KfSBlbHNlIHsNCiAgICBpZiAoJGNhdEIuQ291bnQgLWd0
>> "%B64FILE%" echo IDApIHsNCiAgICAgICAgU2F5ICIiDQogICAgICAgIFNheSAoIiAgICAgIOOAkELjgJHmnKzlt6Xl
>> "%B64FILE%" echo hbfoo4Xov4fjgIHkvYblkK/liqjpobnlt7Lnu4/msqHkuobvvIh7MH0g5Liq77yJIiAtZiAkY2F0
>> "%B64FILE%" echo Qi5Db3VudCkgJ1doaXRlJw0KICAgICAgICBTYXkgIiAgICAgICAgICDml4HovrnmnInmnKzlt6Xl
>> "%B64FILE%" echo hbfnlZnkuIvnmoQgLmJvb3QudHh077yM5Yig5o6J5LiN5Lya5b2x5ZON5Lu75L2V6IO95ZCv5Yqo
>> "%B64FILE%" echo 55qE57O757uf44CCIiAnRGFya0dyYXknDQogICAgICAgIGZvcmVhY2ggKCRpdCBpbiAkY2F0Qikg
>> "%B64FILE%" echo ew0KICAgICAgICAgICAgU2F5ICgoJyAgICAgICAgICB7MH0gICAoezF9IEdCKScgLWYgJGl0LlBh
>> "%B64FILE%" echo dGgsICRpdC5TaXplR0IpKSAnV2hpdGUnDQogICAgICAgICAgICAkYW5zID0gUmVhZC1Ib3N0ICIg
>> "%B64FILE%" echo ICAgICAgICAgICAg5Yig6Zmk5ZCX77yf6L6T5YWlIHkg5Yig6Zmk77yM55u05o6l5Zue6L2m6Lez
>> "%B64FILE%" echo 6L+HIg0KICAgICAgICAgICAgaWYgKCRhbnMgLWFuZCAoJGFucy5UcmltKCkgLWllcSAneScpKSB7
>> "%B64FILE%" echo DQogICAgICAgICAgICAgICAgUmVtb3ZlLVZoZFNhZmVseSAtSXRlbSAkaXQNCiAgICAgICAgICAg
>> "%B64FILE%" echo IH0gZWxzZSB7DQogICAgICAgICAgICAgICAgU2F5ICIgICAgICAgICAgICAg5bey6Lez6L+HIiAn
>> "%B64FILE%" echo RGFya0dyYXknDQogICAgICAgICAgICB9DQogICAgICAgIH0NCiAgICB9DQogICAgaWYgKCRjYXRD
>> "%B64FILE%" echo LkNvdW50IC1ndCAwKSB7DQogICAgICAgIFNheSAiIg0KICAgICAgICBTYXkgKCIgICAgICDjgJBD
>> "%B64FILE%" echo 44CR5LiN5piv5pys56iL5bqP5Yib5bu655qE77yIezB9IOS4qu+8iSIgLWYgJGNhdEMuQ291bnQp
>> "%B64FILE%" echo ICdXaGl0ZScNCiAgICAgICAgU2F5ICIgICAgICAgICAg5rKh5pyJ5pys56iL5bqP55WZ5LiL55qE
>> "%B64FILE%" echo IC5ib290LnR4dOOAguWPr+iDveaYryBIeXBlci1WIOiZmuaLn+ejgeebmOOAgeWIq+eahOijheac
>> "%B64FILE%" echo uiIgJ0RhcmtHcmF5Jw0KICAgICAgICBTYXkgIiAgICAgICAgICDlt6XlhbfvvIzmiJbogIXkvaDo
>> "%B64FILE%" echo h6rlt7HmlL7nmoTlpIfku73jgILpu5jorqTkuI3liKDvvIzkuZ/kuI3lu7rorq7liKDjgIIiICdE
>> "%B64FILE%" echo YXJrR3JheScNCiAgICAgICAgZm9yZWFjaCAoJGl0IGluICRjYXRDKSB7DQogICAgICAgICAgICAk
>> "%B64FILE%" echo Zm4gPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRGaWxlTmFtZSgkaXQuUGF0aCkNCiAgICAgICAgICAg
>> "%B64FILE%" echo IFNheSAoKCcgICAgICAgICAgezB9ICAgKHsxfSBHQiknIC1mICRpdC5QYXRoLCAkaXQuU2l6ZUdC
>> "%B64FILE%" echo KSkgJ1doaXRlJw0KICAgICAgICAgICAgJGFucyA9IFJlYWQtSG9zdCAoIiAgICAgICAgICAgICDn
>> "%B64FILE%" echo oa7lrp7opoHliKDlsLHovpPlhaXmlofku7blkI0gezB977yI55u05o6l5Zue6L2m6Lez6L+H77yJ
>> "%B64FILE%" echo IiAtZiAkZm4pDQogICAgICAgICAgICBpZiAoLW5vdCAkYW5zKSB7DQogICAgICAgICAgICAgICAg
>> "%B64FILE%" echo U2F5ICIgICAgICAgICAgICAg5bey6Lez6L+HIiAnRGFya0dyYXknDQogICAgICAgICAgICB9IGVs
>> "%B64FILE%" echo c2VpZiAoJGFucy5UcmltKCkgLWllcSAkZm4pIHsNCiAgICAgICAgICAgICAgICBSZW1vdmUtVmhk
>> "%B64FILE%" echo U2FmZWx5IC1JdGVtICRpdA0KICAgICAgICAgICAgfSBlbHNlIHsNCiAgICAgICAgICAgICAgICAj
>> "%B64FILE%" echo IOWIq+eUqOm7hOWtl+ivtOOAjOaWh+S7tuWQjeS4jeWvueOAjeKAlOKAlCDlvojlpJrkurrkvJrl
>> "%B64FILE%" echo hYjor5UgeSAvIHllc++8jOWFtuWunuS7luaYr+ecn+aDs+WIoO+8jA0KICAgICAgICAgICAgICAg
>> "%B64FILE%" echo ICMg5Y+q5piv5LiN55+l6YGT6L+Z5LiA5qCP6KaB55qE5LiN5pivIHnjgILov5nph4zlj6rlubPp
>> "%B64FILE%" echo nZnlnLDor7TmuIXmpZrjgIzmgI7kuYjliKDjgI3vvIzkuI3liKTplJnjgIINCiAgICAgICAgICAg
>> "%B64FILE%" echo ICAgICBTYXkgKCIgICAgICAgICAgICAg5bey6Lez6L+H44CC6KaB5Yig6L+Z5LiA5Liq77yM6K+3
>> "%B64FILE%" echo 6L6T5YWl5a6M5pW05paH5Lu25ZCN77yaezB9IiAtZiAkZm4pICdEYXJrR3JheScNCiAgICAgICAg
>> "%B64FILE%" echo ICAgICAgICBpZiAoJGFucy5UcmltKCkgLWltYXRjaCAnXih5fHllc3zmmK985YigfOWIoOmZpHxv
>> "%B64FILE%" echo aykkJykgew0KICAgICAgICAgICAgICAgICAgICBTYXkgIiAgICAgICAgICAgICDvvIjov5nkuIDm
>> "%B64FILE%" echo oI/nibnmhI/kuI3mlLYgeSDigJTigJQg5a6D6Ziy55qE5piv5omL5ruR5Yig5o6J5Yir5Lq655qE
>> "%B64FILE%" echo 6Jma5ouf56OB55uY77yJIiAnRGFya0dyYXknDQogICAgICAgICAgICAgICAgfQ0KICAgICAgICAg
>> "%B64FILE%" echo ICAgfQ0KICAgICAgICB9DQogICAgfQ0KfQ0KDQojIC0tLS0tLS0tLS0g56ysIDQg5q2l77yIdjEu
>> "%B64FILE%" echo MjnvvInvvJrmuIUgYmNkZWRpdCDlr7zlh7ogQkNEIOaXtueVmeS4i+eahOS8tOeUn+aXpeW/lyAt
>> "%B64FILE%" echo LS0tLS0tLS0tDQojDQojIGJjZGVkaXQgL2V4cG9ydCDlr7zlh7rnmoTmmK/kuIDkuKrms6jlhozo
>> "%B64FILE%" echo oaggaGl2Ze+8jFdpbmRvd3Mg5Lya6aG65omL5Zyo55uu5qCH5peB6L6555Sf5oiQDQojICAgeHh4
>> "%B64FILE%" echo LmJjZC5MT0cgIHh4eC5iY2QuTE9HMSAgeHh4LmJjZC5MT0cyDQojIOecn+acuuWunua1i++8mkQ6
>> "%B64FILE%" echo XCDmoLnkuIrmlJLkuoYgMzEg5LiqIC5iY2QuTE9HKu+8jEQ6XOiZmuaLn+ejgeebmFwg6YeM6L+Y
>> "%B64FILE%" echo 5pyJIDE4IOS4quOAgg0KIyDms6jmhI/ov5nlh6DkuKrkvLTnlJ/mlofku7bluKYgSGlkZGVuICsg
>> "%B64FILE%" echo U3lzdGVtIOWxnuaAp++8jEdldC1DaGlsZEl0ZW0g5b+F6aG75YqgIC1Gb3JjZe+8jA0KIyDlkKbl
>> "%B64FILE%" echo iJnkuIDkuKrpg73miavkuI3liLDvvIh2MS4yOSDlsLHmmK/mvI/kuobov5nkuKrvvIzlip/og73p
>> "%B64FILE%" echo nZnpu5jlpLHmlYjvvInjgIINCiMg6L+Z5Lqb5piv5a+85Ye66L+H56iL55qE5Lit6Ze05paH5Lu2
>> "%B64FILE%" echo 77yM5a+55oGi5aSNIEJDRCDmsqHmnInku7vkvZXnlKjlpITvvIzliKDmjonkuI3lvbHlk40gLmJj
>> "%B64FILE%" echo ZCDlpIfku73mnKzouqvjgIINCiMgdjEuMjkg6LW35a6J6KOF5ZmoL+S/ruWkjeW3peWFt+aUueaI
>> "%B64FILE%" echo kOOAjOWFiOWvvOWIsOS4tOaXtuebruW9leWGjeaLt+i0neOAje+8jOS7peWQjuS4jeS8muWGjeS6
>> "%B64FILE%" echo p+eUn++8mw0KIyDov5nkuIDoioLmmK/nu5nlt7Lnu4/mlJLkuIvmnaXnmoTpgqPkupvmlLblsL7j
>> "%B64FILE%" echo gIINCiRzdHJheUxvZ3MgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QN
>> "%B64FILE%" echo CiMNCiMg44CQdjEuMzEg5a6J5YWo5Yqg5Zu644CR5Lul5YmN5piv5ou/ICcqLmJjZC5MT0cqJyDp
>> "%B64FILE%" echo gJrphY3ljrvmiasgNiDkuKrnm5jnmoTmoLkgKyDkuIDnuqflrZDnm67lvZXvvIznhLblkI4NCiMg
>> "%B64FILE%" echo 5LiA5oqKIFJlbW92ZS1JdGVt44CC5a6e5rWL56Gu5a6e5rKh5Yig5Yiw6L+H57O757uf5paH5Lu2
>> "%B64FILE%" echo IOKAlOKAlCDkvYbpgqPmmK/pnaAgLUZpbHRlciDnmoQgOC4zIOefreWQjeWMuemFjQ0KIyDmgKrn
>> "%B64FILE%" echo mZbnorDlt6fkuI3ljLnphY3jgIxCQ0QuTE9H44CN77yM5LiN5piv5Luj56CB6YeM5pyJ6Ziy5oqk
>> "%B64FILE%" echo 44CC6ICMIEM6XEJvb3RcQkNELkxPRyAvIEJDRC5MT0cxIC8NCiMgQkNELkxPRzIg5pivKirmtLvl
>> "%B64FILE%" echo iqggQkNEIOeahOS6i+WKoeaXpeW/lyoq77yM5ZCN5a2X5Y+q5beu5Lik5Liq5a2X5q+N77yM5o2i
>> "%B64FILE%" echo 5Liq5YaZ5rOV5oiW5o2i5Y+w5py65Zmo5bCx5Y+v6IO9DQojIOWRveS4re+8jOWIoOaOieacieaN
>> "%B64FILE%" echo n+Wdj+WQr+WKqOmFjee9rueahOmjjumZqeOAgg0KIw0KIyDnjrDlnKjmlLnmiJDnmb3lkI3ljZXv
>> "%B64FILE%" echo vJrlj6rorqTmnKznqIvluo/ljobku6Plr7zlh7rnmoTpgqPnp43lm7rlrprmoLzlvI/vvIzliKvn
>> "%B64FILE%" echo moTkuIDlvovkuI3norDjgIINCiMgICBiY2QtYmFja3VwLTx5eXl5TU1kZD4tPEhIbW1zcz4uYmNk
>> "%B64FILE%" echo LkxPRyAvIC5MT0cxIC8gLkxPRzINCiMgICBiY2QtYmFja3VwLWZpeC08eXl5eU1NZGQ+LTxISG1t
>> "%B64FILE%" echo c3M+LmJjZC5MT0cgLi4uDQojICAgYmNkLXJlc2N1ZS08eXl5eU1NZGQ+LTxISG1tc3M+LmJjZC5M
>> "%B64FILE%" echo T0cgLi4uICAg77yI5pep5pyf54mI5pys55So6L+H6L+Z5Liq5YmN57yA77yJDQojIOWFs+mUrueC
>> "%B64FILE%" echo ue+8muW/hemhu+S7pSBiY2QtIOW8gOWktOOAgeS4remXtOW4piA4IOS9jeaXpeacnyArIDYg5L2N
>> "%B64FILE%" echo 5pe26Ze044CB5omp5bGV5ZCN5pivIC5iY2TjgIINCiMg57O757uf6Ieq5bex55qEIEM6XEJvb3Rc
>> "%B64FILE%" echo QkNELkxPRyDkuInkuKrlkI3lrZfmsqHmnInkuIDmoLfog73lr7nkuIrvvIzmiYDku6Xnu5PmnoTk
>> "%B64FILE%" echo uIrkuI3lj6/og73ooqvpgInkuK3jgIINCiMg55uu5b2V5bGC6Z2i5YaN5o6S6Zmk5LiA6YGN57O7
>> "%B64FILE%" echo 57uf55uu5b2V77yM5Y+M5L+d6Zmp44CCDQokaXNTdHJheUJjZExvZyA9IHsNCiAgICBwYXJhbShb
>> "%B64FILE%" echo c3RyaW5nXSRuKQ0KICAgIHJldHVybiAoJG4gLW1hdGNoICdeYmNkLVthLXpdKyg/Oi1bYS16XSsp
>> "%B64FILE%" echo Ki1cZHs4fS1cZHs2fVwuYmNkXC5MT0dbMC05XT8kJykNCn0NCiRza2lwU3ViRGlycyA9ICdeKFdp
>> "%B64FILE%" echo bmRvd3N8UHJvZ3JhbSBGaWxlcy4qfFwkUmVjeWNsZVwuQmlufFN5c3RlbSBWb2x1bWUgSW5mb3Jt
>> "%B64FILE%" echo YXRpb258VXNlcnN8Qm9vdHxSZWNvdmVyeXxFRkl8UGVyZkxvZ3MpJCcNCmZvcmVhY2ggKCRydCBp
>> "%B64FILE%" echo biBAKCdDOlwnLCAnRDpcJywgJ0U6XCcsICdGOlwnLCAnRzpcJywgJ0g6XCcpKSB7DQogICAgaWYg
>> "%B64FILE%" echo KC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHJ0KSkgeyBjb250aW51ZSB9DQogICAgZm9y
>> "%B64FILE%" echo ZWFjaCAoJGYgaW4gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkcnQgLUZpbGUgLUZvcmNl
>> "%B64FILE%" echo IC1FQSBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJiAkaXNTdHJheUJjZExvZyAk
>> "%B64FILE%" echo Zi5OYW1lKSB7IFt2b2lkXSRzdHJheUxvZ3MuQWRkKCRmKSB9DQogICAgfQ0KICAgIGZvcmVhY2gg
>> "%B64FILE%" echo KCRkIGluIEAoR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJHJ0IC1EaXJlY3RvcnkgLUZvcmNl
>> "%B64FILE%" echo IC1FQSBTaWxlbnRseUNvbnRpbnVlKSkgew0KICAgICAgICBpZiAoJGQuTmFtZSAtbWF0Y2ggJHNr
>> "%B64FILE%" echo aXBTdWJEaXJzKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gQChHZXQtQ2hp
>> "%B64FILE%" echo bGRJdGVtIC1MaXRlcmFsUGF0aCAkZC5GdWxsTmFtZSAtRmlsZSAtRm9yY2UgLUVBIFNpbGVudGx5
>> "%B64FILE%" echo Q29udGludWUpKSB7DQogICAgICAgICAgICBpZiAoJiAkaXNTdHJheUJjZExvZyAkZi5OYW1lKSB7
>> "%B64FILE%" echo IFt2b2lkXSRzdHJheUxvZ3MuQWRkKCRmKSB9DQogICAgICAgIH0NCiAgICB9DQp9DQoNCmlmICgk
>> "%B64FILE%" echo c3RyYXlMb2dzLkNvdW50IC1ndCAwKSB7DQogICAgJHN6ID0gKCRzdHJheUxvZ3MgfCBNZWFzdXJl
>> "%B64FILE%" echo LU9iamVjdCAtUHJvcGVydHkgTGVuZ3RoIC1TdW0pLlN1bQ0KICAgIFNheSAiIg0KICAgIFNheSAo
>> "%B64FILE%" echo IiAgICAgIOOAkOmZhOOAkWJjZGVkaXQg5a+85Ye6IEJDRCDml7bnlZnkuIvnmoTkvLTnlJ/ml6Xl
>> "%B64FILE%" echo v5fvvIh7MH0g5Liq77yM5YWxIHsxOk4xfSBNQu+8iSIgLWYgJHN0cmF5TG9ncy5Db3VudCwgKCRz
>> "%B64FILE%" echo eiAvIDFNQikpICdXaGl0ZScNCiAgICBTYXkgIiAgICAgICAgICDlsLHmmK8gYmNkLWJhY2t1cC0q
>> "%B64FILE%" echo LmJjZCDml4HovrnnmoQgLkxPRyAvIC5MT0cxIC8gLkxPRzLjgIIiICdEYXJrR3JheScNCiAgICBT
>> "%B64FILE%" echo YXkgIiAgICAgICAgICDlroPku6zmmK/lr7zlh7rov4fnqIvkuK3nmoTkuK3pl7Tmlofku7bvvIzl
>> "%B64FILE%" echo iKDmjonkuI3lvbHlk40gLmJjZCDlpIfku73mnKzouqvvvIzkuZ/kuI3lvbHlk43lvIDmnLrjgIIi
>> "%B64FILE%" echo ICdEYXJrR3JheScNCiAgICBTYXkgIiAgICAgICAgICDlj6rorqTmnKznqIvluo/lr7zlh7rnmoTl
>> "%B64FILE%" echo pIfku73lkI3vvJvns7vnu5/oh6rlt7HnmoQgQzpcQm9vdFxCQ0QuTE9HIOS4jeWcqOiMg+WbtOWG
>> "%B64FILE%" echo he+8jOe7neS4jeS8muWKqOOAgiIgJ0RhcmtHcmF5Jw0KICAgIGZvcmVhY2ggKCRmIGluIEAoJHN0
>> "%B64FILE%" echo cmF5TG9ncyB8IFNvcnQtT2JqZWN0IEZ1bGxOYW1lIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgOCkp
>> "%B64FILE%" echo IHsNCiAgICAgICAgU2F5ICgiICAgICAgICAgICIgKyAkZi5GdWxsTmFtZSkgJ0RhcmtHcmF5Jw0K
>> "%B64FILE%" echo ICAgIH0NCiAgICBpZiAoJHN0cmF5TG9ncy5Db3VudCAtZ3QgOCkgeyBTYXkgKCIgICAgICAgICAg
>> "%B64FILE%" echo 4oCm4oCmIOi/mOaciSB7MH0g5LiqIiAtZiAoJHN0cmF5TG9ncy5Db3VudCAtIDgpKSAnRGFya0dy
>> "%B64FILE%" echo YXknIH0NCiAgICAkYW5zID0gUmVhZC1Ib3N0ICIgICAgICAgICAgICAg5YWo6YOo5Yig6Zmk5ZCX
>> "%B64FILE%" echo 77yf6L6T5YWlIHkg5Yig6Zmk77yM55u05o6l5Zue6L2m6Lez6L+HIg0KICAgIGlmICgkYW5zIC1h
>> "%B64FILE%" echo bmQgKCRhbnMuVHJpbSgpIC1pZXEgJ3knKSkgew0KICAgICAgICAkb2tOID0gMA0KICAgICAgICBm
>> "%B64FILE%" echo b3JlYWNoICgkZiBpbiAkc3RyYXlMb2dzKSB7DQogICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRl
>> "%B64FILE%" echo bSAtTGl0ZXJhbFBhdGggJGYuRnVsbE5hbWUgLUZvcmNlIC1FQSBTdG9wOyAkb2tOKysgfSBjYXRj
>> "%B64FILE%" echo aCB7fQ0KICAgICAgICB9DQogICAgICAgIFNheSAoIiAgICAgICAgICAgICDlt7LliKDpmaQgezB9
>> "%B64FILE%" echo IC8gezF9IOS4qiIgLWYgJG9rTiwgJHN0cmF5TG9ncy5Db3VudCkgJ0dyZWVuJw0KICAgICAgICBp
>> "%B64FILE%" echo ZiAoJG9rTiAtbHQgJHN0cmF5TG9ncy5Db3VudCkgeyBTYXkgIiAgICAgICAgICAgICDliKDkuI3m
>> "%B64FILE%" echo jonnmoTpgJrluLjmmK/ooqvliKvnmoTnqIvluo/ljaDnnYDvvIzph43lkK/lkI7lho3ot5HkuIDm
>> "%B64FILE%" echo rKHljbPlj68iICdEYXJrR3JheScgfQ0KICAgIH0gZWxzZSB7DQogICAgICAgIFNheSAiICAgICAg
>> "%B64FILE%" echo ICAgICAgIOW3sui3s+i/h++8iOS4gOS4qumDveayoeWIoO+8iSIgJ0RhcmtHcmF5Jw0KICAgIH0N
>> "%B64FILE%" echo Cn0NCg0KU2F5ICIiDQpTYXkgIiAgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiAnRGFya0dyYXknDQpTYXkgIiAg5riF55CG5a6M5oiQ
>> "%B64FILE%" echo 44CCIiAnR3JlZW4nDQpTYXkgIiINClNheSAiICDph43mlrDlronoo4XnmoTmraPnoa7lp7/lir/v
>> "%B64FILE%" echo vJoiICdXaGl0ZScNClNheSAiICAgIDEuIOmHjeaWsOWPjOWHu+OAjOWPjOWHu+aIkS3oo4Xns7vn
>> "%B64FILE%" echo u58uYmF044CNIiAnRGFya0dyYXknDQpTYXkgIiAgICAgICDov5vluqbmnaHkvJrmmL7npLrlt7Ll
>> "%B64FILE%" echo hpnlhaXlpJrlsJEgR0LvvIzmlbDlrZfkuIDnm7TlnKjmtqjlsLHor7TmmI7lnKjlt6XkvZzvvIzl
>> "%B64FILE%" echo iKvmgKXnnYDlhbPmjokiICdEYXJrR3JheScNClNheSAiICAgIDIuIOijheWujOmHjeWQr++8jOW8
>> "%B64FILE%" echo gOacuuiPnOWNlemHjOmAieaWsOezu+e7nyIgJ0RhcmtHcmF5Jw0KU2F5ICIiDQpSZWFkLUhvc3Qg
>> "%B64FILE%" echo IiAg5oyJ5Zue6L2m6YCA5Ye6Ig0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=17748"
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
