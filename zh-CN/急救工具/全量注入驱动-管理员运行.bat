@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 全量注入驱动
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
set "PS1FILE=%WORKDIR%\全量注入驱动-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/cGFyYW0oDQogICAgW3N0cmluZ10kT3JpZ2luRGlyID0gJycNCikNCg0KIyA9PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCiMg5YWo
>> "%B64FILE%" echo 6YeP5rOo5YWl6amx5YqoICB2MS4zDQojIOS9nOiAhTogY29ubmVjdHNlZ2Fib3QNCiMNCiMg55So
>> "%B64FILE%" echo 6YCU77ya6KOF5aW955qE6Jma5ouf57O757uf6YeM44CM6K6+5aSH566h55CG5Zmo5LiA5aCG5pyq
>> "%B64FILE%" echo 55+l6K6+5aSH44CN44CCDQojICAg5oqK5pys5py65omA5pyJ56ys5LiJ5pa56amx5Yqo5YyF77yI
>> "%B64FILE%" echo 6Iqv54mH57uE44CBQUNQSeOAgVBDSWXjgIHnvZHljaHjgIHpn7PpopHjgIHok53niZnjgIHmmL7l
>> "%B64FILE%" echo jaHigKbvvIkNCiMgICDkuIDmrKHmgKfmkKzov5vomZrmi5/ns7vnu5/vvIzph43lkK/lkI4gUG5Q
>> "%B64FILE%" echo IOiHquW3seWwseiDveiupOWHuuadpeOAgg0KIw0KIyDlkozjgIzms6jlhaXnvZHljaHpqbHliqjj
>> "%B64FILE%" echo gI3nmoTljLrliKvvvJrpgqPkuKrlj6rmkKwgTmV0IOexuyA5IOS4quWMhe+8jOi/meS4quaQrOWF
>> "%B64FILE%" echo qOmDqCAxNjArIOS4quOAgg0KIw0KIyDlkIzml7bkvJrmiorlr7zlh7rnmoTpqbHliqjnlZnkuIDk
>> "%B64FILE%" echo u73lnKggdmhkeCDmiYDlnKjnm5jnmoQgTmV3U3lzdGVtRHJpdmVyIOebruW9le+8jA0KIyDkuIfk
>> "%B64FILE%" echo uIDmn5Dlh6DkuKrmsqHnu5HkuIrvvIzov5vmlrDns7vnu5/lkI7ov5jog73nlKjjgIzmlrDns7vn
>> "%B64FILE%" echo u58t6K+K5pat5bm26KOF6amx5YqoLmJhdOOAjeeOsOWcuuijheOAgg0KIyA9PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0NCg0KJEVycm9y
>> "%B64FILE%" echo QWN0aW9uUHJlZmVyZW5jZSA9ICdDb250aW51ZScNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjM0Jw0K
>> "%B64FILE%" echo JFNjcmlwdDpPcmlnaW5EaXIgPSAkT3JpZ2luRGlyDQp0cnkgeyAkSG9zdC5VSS5SYXdVSS5XaW5k
>> "%B64FILE%" echo b3dUaXRsZSA9ICLlhajph4/ms6jlhaXpqbHliqggdiQoJFNjcmlwdDpWZXJzaW9uKSAtIGNvbm5l
>> "%B64FILE%" echo Y3RzZWdhYm90IiB9IGNhdGNoIHt9DQoNCiMgW3YxLjMyXSDlhbHkuqvmqKHlnZfjgILmiZPljIXm
>> "%B64FILE%" echo l7bnlLEgc3JjL2J1aWxkL2lubGluZV9zaGFyZWQucHkg5YaF6IGU5pys5paH5Lu277yMDQojIC5i
>> "%B64FILE%" echo YXQg6L296I235LuN5piv6Ieq5YyF5ZCr5Y2V5paH5Lu244CCDQojID09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQ0KIyDlhbHkuqvml6Xl
>> "%B64FILE%" echo v5flh73mlbAgICB2MS4zMg0KIw0KIyDmnKzmlofku7bkuI3mmK/lj5HluIPnianjgILmiZPljIUg
>> "%B64FILE%" echo LmJhdCDovb3ojbfml7bvvIxzcmMvYnVpbGQvaW5saW5lX3NoYXJlZC5weSDkvJrmiorov5nph4zn
>> "%B64FILE%" echo moQNCiMg5YaF5a655YaF6IGU6L+b5q+P5Liq5YWl5Y+j6ISa5pys77yM5L+d6K+B5Y+R5biD5Ye6
>> "%B64FILE%" echo 5Y6755qE5ZCv5Yqo5Zmo5LuN5piv6Ieq5YyF5ZCr5Y2V5paH5Lu2DQojIO+8iOiHquino+WOiyBi
>> "%B64FILE%" echo YXQg5Zyo6L+Q6KGM5pyf5rKh5Yqe5rOV5byV55So5aSW6YOo5qih5Z2X77yJ44CCDQojDQojIOin
>> "%B64FILE%" echo hOefqe+8muWPquaUuei/memHjO+8jOS4jeimgeWGjeaKiui/meS6m+WHveaVsOWkjeWItuWbnuWF
>> "%B64FILE%" echo peWPo+iEmuacrOOAgg0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT0NCg0KZnVuY3Rpb24gU2F5IHsNCiAgICBwYXJhbShbc3RyaW5n
>> "%B64FILE%" echo XSRUZXh0LCBbc3RyaW5nXSRDb2xvciA9ICdHcmF5JykNCiAgICBXcml0ZS1Ib3N0ICRUZXh0IC1G
>> "%B64FILE%" echo b3JlZ3JvdW5kQ29sb3IgJENvbG9yDQp9DQoNClNheSAiIg0KU2F5ICIgIOWFqOmHj+azqOWFpemp
>> "%B64FILE%" echo seWKqCAgdiQoJFNjcmlwdDpWZXJzaW9uKSIgJ0N5YW4nDQpTYXkgIiAg5L2c6ICFOiBjb25uZWN0
>> "%B64FILE%" echo c2VnYWJvdCIgJ0RhcmtHcmF5Jw0KU2F5ICIgIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
>> "%B64FILE%" echo LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSIgJ0RhcmtHcmF5Jw0KU2F5ICIiDQoNCiRh
>> "%B64FILE%" echo ZG1pbiA9IChbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NQcmluY2lwYWxdW1NlY3VyaXR5LlBy
>> "%B64FILE%" echo aW5jaXBhbC5XaW5kb3dzSWRlbnRpdHldOjpHZXRDdXJyZW50KCkpLklzSW5Sb2xlKFtTZWN1cml0
>> "%B64FILE%" echo eS5QcmluY2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6QWRtaW5pc3RyYXRvcikNCmlmICgtbm90
>> "%B64FILE%" echo ICRhZG1pbikgew0KICAgIFNheSAiICBb6ZSZ6K+vXSDpnIDopoHnrqHnkIblkZjmnYPpmZDjgILo
>> "%B64FILE%" echo r7flhbPmjonmnKznqpflj6PvvIzlj7PplK7mnKzmlofku7YgLT4g5Lul566h55CG5ZGY6Lqr5Lu9
>> "%B64FILE%" echo 6L+Q6KGM44CCIiAnUmVkJw0KICAgIFNheSAiIg0KICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabp
>> "%B64FILE%" echo gIDlh7oiDQogICAgZXhpdCAxDQp9DQoNCiMgLS0tLS0tLS0tLSDmjpLpmaTjgIzlvZPliY3mraPl
>> "%B64FILE%" echo nKjov5DooYznmoTns7vnu5/jgI0gLS0tLS0tLS0tLQ0KJHN5c0xldHRlciA9IChbc3RyaW5nXSRl
>> "%B64FILE%" echo bnY6U3lzdGVtRHJpdmUpLlRyaW1FbmQoJzonKS5Ub1VwcGVyKCkNCiRzeXNWb2xJZCA9ICcnDQp0
>> "%B64FILE%" echo cnkgeyAkc3lzVm9sSWQgPSBbc3RyaW5nXShHZXQtVm9sdW1lIC1Ecml2ZUxldHRlciAkc3lzTGV0
>> "%B64FILE%" echo dGVyIC1FcnJvckFjdGlvbiBTdG9wKS5VbmlxdWVJZCB9IGNhdGNoIHt9DQoNCmZ1bmN0aW9uIFRl
>> "%B64FILE%" echo c3QtSXNSdW5uaW5nU3lzdGVtIHsNCiAgICBwYXJhbSgkVm9sKQ0KICAgIGlmICgoW3N0cmluZ10k
>> "%B64FILE%" echo Vm9sLkRyaXZlTGV0dGVyKS5Ub1VwcGVyKCkgLWVxICRzeXNMZXR0ZXIpIHsgcmV0dXJuICR0cnVl
>> "%B64FILE%" echo IH0NCiAgICBpZiAoJHN5c1ZvbElkIC1hbmQgKFtzdHJpbmddJFZvbC5VbmlxdWVJZCAtZXEgJHN5
>> "%B64FILE%" echo c1ZvbElkKSkgeyByZXR1cm4gJHRydWUgfQ0KICAgIHJldHVybiAkZmFsc2UNCn0NCg0KZnVuY3Rp
>> "%B64FILE%" echo b24gR2V0LVRhcmdldENhbmRpZGF0ZXMgew0KICAgICRsaXN0ID0gQCgpDQogICAgJHZoZERpc2tz
>> "%B64FILE%" echo ID0gQHt9DQogICAgZm9yZWFjaCAoJGQgaW4gQChHZXQtRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50
>> "%B64FILE%" echo bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKFtzdHJpbmddJGQuQnVzVHlwZSAtZXEgJ0ZpbGUg
>> "%B64FILE%" echo QmFja2VkIFZpcnR1YWwnKSB7ICR2aGREaXNrc1tbaW50XSRkLk51bWJlcl0gPSAkdHJ1ZSB9DQog
>> "%B64FILE%" echo ICAgfQ0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JBY3Rpb24gU2lsZW50
>> "%B64FILE%" echo bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0ZXIpIHsgY29udGlu
>> "%B64FILE%" echo dWUgfQ0KICAgICAgICAkcm9vdCA9ICJ7MH06XCIgLWYgJHYuRHJpdmVMZXR0ZXINCiAgICAgICAg
>> "%B64FILE%" echo aWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggKCRyb290ICsgJ1dpbmRvd3NcU3lzdGVt
>> "%B64FILE%" echo MzJcbnRvc2tybmwuZXhlJykpKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgJGRpc2tOdW0gPSAtMQ0K
>> "%B64FILE%" echo ICAgICAgICB0cnkgeyAkZGlza051bSA9IFtpbnRdKEdldC1QYXJ0aXRpb24gLURyaXZlTGV0dGVy
>> "%B64FILE%" echo ICR2LkRyaXZlTGV0dGVyIC1FcnJvckFjdGlvbiBTdG9wKS5EaXNrTnVtYmVyIH0gY2F0Y2gge30N
>> "%B64FILE%" echo CiAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7DQogICAgICAgICAgICBMZXR0ZXIg
>> "%B64FILE%" echo ID0gW3N0cmluZ10kdi5Ecml2ZUxldHRlcg0KICAgICAgICAgICAgTGFiZWwgICA9IFtzdHJpbmdd
>> "%B64FILE%" echo JHYuRmlsZVN5c3RlbUxhYmVsDQogICAgICAgICAgICBSdW5uaW5nID0gKFRlc3QtSXNSdW5uaW5n
>> "%B64FILE%" echo U3lzdGVtICR2KQ0KICAgICAgICAgICAgSXNWaGQgICA9ICgkZGlza051bSAtZ2UgMCAtYW5kICR2
>> "%B64FILE%" echo aGREaXNrcy5Db250YWluc0tleSgkZGlza051bSkpDQogICAgICAgICAgICBEaXNrICAgID0gJGRp
>> "%B64FILE%" echo c2tOdW0NCiAgICAgICAgICAgIFNpemVHQiAgPSBbbWF0aF06OlJvdW5kKCR2LlNpemUgLyAxR0Is
>> "%B64FILE%" echo IDEpDQogICAgICAgICAgICBGcmVlR0IgID0gW21hdGhdOjpSb3VuZCgkdi5TaXplUmVtYWluaW5n
>> "%B64FILE%" echo IC8gMUdCLCAxKQ0KICAgICAgICB9DQogICAgfQ0KICAgIHJldHVybiAkbGlzdA0KfQ0KDQpmdW5j
>> "%B64FILE%" echo dGlvbiBGaW5kLVZoZHhGaWxlcyB7DQogICAgJGZvdW5kID0gQCgpDQogICAgaWYgKCRTY3JpcHQ6
>> "%B64FILE%" echo T3JpZ2luRGlyIC1hbmQgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJFNjcmlwdDpPcmlnaW5EaXIp
>> "%B64FILE%" echo KSB7DQogICAgICAgICRjID0gSm9pbi1QYXRoICRTY3JpcHQ6T3JpZ2luRGlyICdOZXdTeXN0ZW1E
>> "%B64FILE%" echo aXNrLnZoZHgnDQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjKSB7ICRmb3Vu
>> "%B64FILE%" echo ZCArPSAkYyB9DQogICAgfQ0KICAgIGZvcmVhY2ggKCR2IGluIEAoR2V0LVZvbHVtZSAtRXJyb3JB
>> "%B64FILE%" echo Y3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsNCiAgICAgICAgaWYgKC1ub3QgJHYuRHJpdmVMZXR0
>> "%B64FILE%" echo ZXIpIHsgY29udGludWUgfQ0KICAgICAgICBpZiAoJHYuRHJpdmVUeXBlIC1uZSAnRml4ZWQnKSB7
>> "%B64FILE%" echo IGNvbnRpbnVlIH0NCiAgICAgICAgJGMgPSAiezB9OlxOZXdTeXN0ZW1EaXNrLnZoZHgiIC1mICR2
>> "%B64FILE%" echo LkRyaXZlTGV0dGVyDQogICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRjKSB7DQog
>> "%B64FILE%" echo ICAgICAgICAgICAkZnVsbCA9IChHZXQtSXRlbSAtTGl0ZXJhbFBhdGggJGMpLkZ1bGxOYW1lDQog
>> "%B64FILE%" echo ICAgICAgICAgICBpZiAoJGZvdW5kIC1ub3Rjb250YWlucyAkZnVsbCkgeyAkZm91bmQgKz0gJGZ1
>> "%B64FILE%" echo bGwgfQ0KICAgICAgICB9DQogICAgfQ0KICAgIHJldHVybiAkZm91bmQNCn0NCg0KZnVuY3Rpb24g
>> "%B64FILE%" echo TW91bnQtVmhkeCB7DQogICAgcGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkZHBGaWxlID0gSm9p
>> "%B64FILE%" echo bi1QYXRoICRlbnY6VEVNUCAoImF0dGFjaF9hbGxfezB9LnR4dCIgLWYgJFBJRCkNCiAgICBAKCJz
>> "%B64FILE%" echo ZWxlY3QgdmRpc2sgZmlsZT1gIiRQYXRoYCIiLCAnYXR0YWNoIHZkaXNrJywgJ2V4aXQnKSB8IFNl
>> "%B64FILE%" echo dC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0DQogICAgJHIg
>> "%B64FILE%" echo PSAnJw0KICAgIHRyeSB7ICRyID0gKCYgZGlza3BhcnQgL3MgJGRwRmlsZSAyPiYxIHwgT3V0LVN0
>> "%B64FILE%" echo cmluZykgfSBjYXRjaCB7ICRyID0gJF8uRXhjZXB0aW9uLk1lc3NhZ2UgfQ0KICAgIFJlbW92ZS1J
>> "%B64FILE%" echo dGVtIC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
>> "%B64FILE%" echo aW51ZQ0KICAgIGlmICgkciAtbWF0Y2ggJ3N1Y2Nlc3NmdWxseXzmiJDlip8nKSB7IHJldHVybiAk
>> "%B64FILE%" echo dHJ1ZSB9DQogICAgU2F5ICgiICAgICAg5oyC6L296L+U5ZueOiAiICsgKCgkciAtcmVwbGFjZSAi
>> "%B64FILE%" echo XHMrIiwgJyAnKS5UcmltKCkpKSAnWWVsbG93Jw0KICAgIHJldHVybiAkZmFsc2UNCn0NCg0KZnVu
>> "%B64FILE%" echo Y3Rpb24gRGlzbW91bnQtVmhkeCB7DQogICAgcGFyYW0oW3N0cmluZ10kUGF0aCkNCiAgICAkZHBG
>> "%B64FILE%" echo aWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoImRldGFjaF9hbGxfezB9LnR4dCIgLWYgJFBJRCkN
>> "%B64FILE%" echo CiAgICBAKCJzZWxlY3QgdmRpc2sgZmlsZT1gIiRQYXRoYCIiLCAnZGV0YWNoIHZkaXNrJywgJ2V4
>> "%B64FILE%" echo aXQnKSB8IFNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZHBGaWxlIC1FbmNvZGluZyBEZWZhdWx0
>> "%B64FILE%" echo DQogICAgdHJ5IHsgJiBkaXNrcGFydCAvcyAkZHBGaWxlIDI+JjEgfCBPdXQtTnVsbCB9IGNhdGNo
>> "%B64FILE%" echo IHt9DQogICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcEZpbGUgLUZvcmNlIC1FcnJvckFj
>> "%B64FILE%" echo dGlvbiBTaWxlbnRseUNvbnRpbnVlDQp9DQoNCiMgLS0tLS0tLS0tLSBbMS80XSDmib7nm67moIcg
>> "%B64FILE%" echo LS0tLS0tLS0tLQ0KU2F5ICJbMS80XSDmib7nm67moIfns7vnu58gLi4uIiAnV2hpdGUnDQoNCiRh
>> "%B64FILE%" echo dHRhY2hlZFZoZHggPSAnJw0KJHRhcmdldHMgPSBAKEdldC1UYXJnZXRDYW5kaWRhdGVzKQ0KJHVz
>> "%B64FILE%" echo YWJsZSA9IEAoJHRhcmdldHMgfCBXaGVyZS1PYmplY3QgeyAtbm90ICRfLlJ1bm5pbmcgfSkNCiR2
>> "%B64FILE%" echo aGRUYXJnZXRzID0gQCgkdXNhYmxlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSXNWaGQgfSkNCg0KaWYg
>> "%B64FILE%" echo KCR2aGRUYXJnZXRzLkNvdW50IC1lcSAwKSB7DQogICAgZm9yZWFjaCAoJGYgaW4gQChGaW5kLVZo
>> "%B64FILE%" echo ZHhGaWxlcykpIHsNCiAgICAgICAgU2F5ICgiICAgICAg5Y+R546w6Jma5ouf56OB55uYIHswfe+8
>> "%B64FILE%" echo jOato+WcqOaMgui9vSAuLi4iIC1mICRmKSAnRGFya0dyYXknDQogICAgICAgIGlmIChNb3VudC1W
>> "%B64FILE%" echo aGR4IC1QYXRoICRmKSB7DQogICAgICAgICAgICAkYXR0YWNoZWRWaGR4ID0gJGYNCiAgICAgICAg
>> "%B64FILE%" echo ICAgIFNheSAiICAgICAg5bey5oyC6L29IiAnR3JlZW4nDQogICAgICAgICAgICBicmVhaw0KICAg
>> "%B64FILE%" echo ICAgICB9DQogICAgfQ0KICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7DQogICAgICAgIFN0YXJ0LVNs
>> "%B64FILE%" echo ZWVwIC1TZWNvbmRzIDINCiAgICAgICAgJHRhcmdldHMgPSBAKEdldC1UYXJnZXRDYW5kaWRhdGVz
>> "%B64FILE%" echo KQ0KICAgICAgICAkdXNhYmxlID0gQCgkdGFyZ2V0cyB8IFdoZXJlLU9iamVjdCB7IC1ub3QgJF8u
>> "%B64FILE%" echo UnVubmluZyB9KQ0KICAgICAgICAkdmhkVGFyZ2V0cyA9IEAoJHVzYWJsZSB8IFdoZXJlLU9iamVj
>> "%B64FILE%" echo dCB7ICRfLklzVmhkIH0pDQogICAgfQ0KfQ0KDQppZiAoJHZoZFRhcmdldHMuQ291bnQgLWVxIDEp
>> "%B64FILE%" echo IHsNCiAgICAkdGFyZ2V0ID0gJHZoZFRhcmdldHNbMF0NCn0gZWxzZWlmICgkdXNhYmxlLkNvdW50
>> "%B64FILE%" echo IC1lcSAwKSB7DQogICAgU2F5ICIiDQogICAgU2F5ICIgIFvplJnor69dIOayoeaJvuWIsOWPr+az
>> "%B64FILE%" echo qOWFpeeahOiZmuaLn+ezu+e7n+OAgiIgJ1JlZCcNCiAgICBTYXkgKCIgICAgICAgICB7MH06IOaY
>> "%B64FILE%" echo r+W9k+WJjeato+WcqOi/kOihjOeahOezu+e7n++8jOS4jeiDveW9k+ebruagh++8iERJU00g5Lya
>> "%B64FILE%" echo 5oqlIEVycm9yIDg377yJ44CCIiAtZiAkc3lzTGV0dGVyKSAnWWVsbG93Jw0KICAgIFNheSAiICAg
>> "%B64FILE%" echo ICAgICAg5Lmf5rKh5om+5YiwIE5ld1N5c3RlbURpc2sudmhkeOOAgiIgJ1llbGxvdycNCiAgICBT
>> "%B64FILE%" echo YXkgIiINCiAgICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRh
>> "%B64FILE%" echo Y2hlZFZoZHggfQ0KICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhpdCAx
>> "%B64FILE%" echo DQp9IGVsc2Ugew0KICAgIFNheSAiICAgICAg5om+5Yiw5aSa5Liq5Y+v5rOo5YWl55qE57O757uf
>> "%B64FILE%" echo 77yaIiAnV2hpdGUnDQogICAgZm9yICgkaSA9IDA7ICRpIC1sdCAkdXNhYmxlLkNvdW50OyAkaSsr
>> "%B64FILE%" echo KSB7DQogICAgICAgICR0ID0gJHVzYWJsZVskaV0NCiAgICAgICAgJGtpbmQgPSBpZiAoJHQuSXNW
>> "%B64FILE%" echo aGQpIHsgJ+iZmuaLn+ejgeebmCcgfSBlbHNlIHsgJ+eJqeeQhuWIhuWMuicgfQ0KICAgICAgICBT
>> "%B64FILE%" echo YXkgKCIgICAgICBbezB9XSB7MX06ICB7Mn0gIHszfSBHQiDljbfmoIc9ezR9IiAtZiAoJGkgKyAx
>> "%B64FILE%" echo KSwgJHQuTGV0dGVyLCAka2luZCwgJHQuU2l6ZUdCLCAkdC5MYWJlbCkNCiAgICB9DQogICAgJHNl
>> "%B64FILE%" echo bCA9IFJlYWQtSG9zdCAiICAgICAg6L6T5YWl5bqP5Y+377yI6buY6K6kIDHvvIkiDQogICAgJGlk
>> "%B64FILE%" echo eCA9IDENCiAgICBbaW50XTo6VHJ5UGFyc2UoJHNlbCwgW3JlZl0kaWR4KSB8IE91dC1OdWxsDQog
>> "%B64FILE%" echo ICAgaWYgKCRpZHggLWx0IDEgLW9yICRpZHggLWd0ICR1c2FibGUuQ291bnQpIHsgJGlkeCA9IDEg
>> "%B64FILE%" echo fQ0KICAgICR0YXJnZXQgPSAkdXNhYmxlWyRpZHggLSAxXQ0KfQ0KDQppZiAoJHRhcmdldC5SdW5u
>> "%B64FILE%" echo aW5nKSB7DQogICAgU2F5ICIgIFvplJnor69dIOmAieS4reeahOaYr+i/kOihjOS4reeahOezu+e7
>> "%B64FILE%" echo n++8jOW3suS4reatouOAgiIgJ1JlZCcNCiAgICBpZiAoJGF0dGFjaGVkVmhkeCkgeyBEaXNtb3Vu
>> "%B64FILE%" echo dC1WaGR4IC1QYXRoICRhdHRhY2hlZFZoZHggfQ0KICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabp
>> "%B64FILE%" echo gIDlh7oiDQogICAgZXhpdCAxDQp9DQpTYXkgKCIgICAgICDnm67moIfvvJp7MH06ICDliankvZkg
>> "%B64FILE%" echo ezF9IEdCIiAtZiAkdGFyZ2V0LkxldHRlciwgJHRhcmdldC5GcmVlR0IpICdHcmVlbicNCg0KIyAt
>> "%B64FILE%" echo LS0tLS0tLS0tIFsyLzRdIOWvvOWHuuacrOacuuWFqOmDqOesrOS4ieaWuempseWKqCAtLS0tLS0t
>> "%B64FILE%" echo LS0tDQpTYXkgIlsyLzRdIOWvvOWHuuacrOacuuWFqOmDqOesrOS4ieaWuempseWKqCAuLi4iICdX
>> "%B64FILE%" echo aGl0ZScNCiRkcnZEaXIgPSBKb2luLVBhdGggJGVudjpURU1QICgiYWxsZHJ2X3swfSIgLWYgJFBJ
>> "%B64FILE%" echo RCkNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRkcnZEaXIpIHsgUmVtb3ZlLUl0
>> "%B64FILE%" echo ZW0gLUxpdGVyYWxQYXRoICRkcnZEaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRp
>> "%B64FILE%" echo bnVlIH0gfSBjYXRjaCB7fQ0KTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkZHJ2
>> "%B64FILE%" echo RGlyIC1Gb3JjZSB8IE91dC1OdWxsDQoNCiRlbnVtVGV4dCA9ICcnDQp0cnkgeyAkZW51bVRleHQg
>> "%B64FILE%" echo PSAoJiBwbnB1dGlsIC9lbnVtLWRyaXZlcnMgMj4mMSB8IE91dC1TdHJpbmcpIH0gY2F0Y2gge30N
>> "%B64FILE%" echo CiRvZW1zID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuQXJyYXlMaXN0DQpmb3JlYWNo
>> "%B64FILE%" echo ICgkYmxrIGluICgkZW51bVRleHQgLXNwbGl0ICIoPzpccj9cbil7Mix9IikpIHsNCiAgICAkbSA9
>> "%B64FILE%" echo IFtyZWdleF06Ok1hdGNoKCRibGssICcoP2kpXGIob2VtXGQrXC5pbmYpXGInKQ0KICAgIGlmICgt
>> "%B64FILE%" echo bm90ICRtLlN1Y2Nlc3MpIHsgY29udGludWUgfQ0KICAgICRubSA9ICRtLkdyb3Vwc1sxXS5WYWx1
>> "%B64FILE%" echo ZS5Ub0xvd2VyKCkNCiAgICBpZiAoLW5vdCAkb2Vtcy5Db250YWlucygkbm0pKSB7IFt2b2lkXSRv
>> "%B64FILE%" echo ZW1zLkFkZCgkbm0pIH0NCn0NClNheSAoIiAgICAgIOesrOS4ieaWuempseWKqOWMhTogezB9IOS4
>> "%B64FILE%" echo qiIgLWYgJG9lbXMuQ291bnQpICdEYXJrR3JheScNCg0KJG9rRXhwb3J0ID0gMA0KZm9yZWFjaCAo
>> "%B64FILE%" echo JG9lbSBpbiAkb2Vtcykgew0KICAgICRlciA9ICgmIHBucHV0aWwgL2V4cG9ydC1kcml2ZXIgJG9l
>> "%B64FILE%" echo bSAkZHJ2RGlyIDI+JjEgfCBPdXQtU3RyaW5nKQ0KICAgIGlmICgkZXIgLW1hdGNoICdzdWNjZXNz
>> "%B64FILE%" echo ZnVsbHl85oiQ5YqfJykgeyAkb2tFeHBvcnQrKyB9DQp9DQoNCiMg44CQdjEuMuOAkXBucHV0aWwg
>> "%B64FILE%" echo L2VudW0tZHJpdmVycyDlj6rliJfnrKzkuInmlrkgb2VtKi5pbmbvvIzniannkIbnvZHljaHluLjn
>> "%B64FILE%" echo lKjns7vnu5/lhoXnva7vvIhpbi1ib3jvvIkNCiMg5YyF4oCU4oCU5LiN5ZyoIG9lbSDliJfooajp
>> "%B64FILE%" echo h4zvvIzkuIDkuKrpg73lr7zkuI3lh7rvvIzogIznsr7nroDplZzlg48vU2VydmVyIOaWsOezu+e7
>> "%B64FILE%" echo n+mHjOaBsOWlveayoeaciei/meS4quWMheOAgg0KIyDmiYDku6XmiorjgIzlvZPliY3nnJ/lrp7l
>> "%B64FILE%" echo rZjlnKjnmoTniannkIbnvZHljaHjgI3mraPlnKjnlKjnmoQgSU5GIOihpeWvvOWHuu+8muesrOS4
>> "%B64FILE%" echo ieaWuSBvZW0g5bey5a+86L+H77yI6Lez6L+H77yJ77ybDQojIGluLWJveCDnmoTku44gRHJpdmVy
>> "%B64FILE%" echo U3RvcmVcRmlsZVJlcG9zaXRvcnkg5pW05YyF5aSN5Yi24oCU4oCU5rOo5YWl5ZKMIE5ld1N5c3Rl
>> "%B64FILE%" echo bURyaXZlciDlpIfku73pg73luKbkuIrjgIINCnRyeSB7DQogICAgJHBoeXNOZXRzID0gQChHZXQt
>> "%B64FILE%" echo UG5wRGV2aWNlIC1DbGFzcyBOZXQgLVByZXNlbnRPbmx5IC1FQSBTaWxlbnRseUNvbnRpbnVlIHwN
>> "%B64FILE%" echo CiAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uSW5zdGFuY2VJZCAtbWF0Y2ggJ14oUENJfFVTQikn
>> "%B64FILE%" echo IH0pDQogICAgZm9yZWFjaCAoJGRldiBpbiAkcGh5c05ldHMpIHsNCiAgICAgICAgdHJ5IHsNCiAg
>> "%B64FILE%" echo ICAgICAgICAgICRkcnZJbmYgPSAnJw0KICAgICAgICAgICAgdHJ5IHsgJGRydkluZiA9IFtzdHJp
>> "%B64FILE%" echo bmddKEdldC1QbnBEZXZpY2VQcm9wZXJ0eSAtSW5zdGFuY2VJZCAkZGV2Lkluc3RhbmNlSWQgLUtl
>> "%B64FILE%" echo eU5hbWUgJ0RFVlBLRVlfRGV2aWNlX0RyaXZlckluZlBhdGgnIC1FQSBTdG9wKS5EYXRhIH0gY2F0
>> "%B64FILE%" echo Y2gge30NCiAgICAgICAgICAgIGlmICgtbm90ICRkcnZJbmYpIHsgY29udGludWUgfQ0KICAgICAg
>> "%B64FILE%" echo ICAgICAgJGRydkluZiA9ICRkcnZJbmYuVG9Mb3dlcigpDQogICAgICAgICAgICBTYXkgKCIgICAg
>> "%B64FILE%" echo ICDniannkIbnvZHljaEgezB9IOato+WcqOS9v+eUqCB7MX0iIC1mICRkZXYuRnJpZW5kbHlOYW1l
>> "%B64FILE%" echo LCAkZHJ2SW5mKSAnRGFya0dyYXknDQogICAgICAgICAgICBpZiAoJGRydkluZiAtbWF0Y2ggJ15v
>> "%B64FILE%" echo ZW1cZCtcLmluZiQnKSB7IGNvbnRpbnVlIH0NCiAgICAgICAgICAgICMgRmlsZVJlcG9zaXRvcnkg
>> "%B64FILE%" echo 55qE5YyF55uu5b2V5ZCN5pivIDxpbmbmlofku7blkI0+XzzmnrbmnoQ+Xzzlk4jluIw+77yM5L6L
>> "%B64FILE%" echo 5aaCDQogICAgICAgICAgICAjIHJ0NjQweDY0LmluZl9hbWQ2NF9jYmY0ZTIzOTgxYzNjOGEz44CC
>> "%B64FILE%" echo 5b+F6aG755So5bimIC5pbmYg55qE5a6M5pW05paH5Lu25ZCN5Y675Yy56YWN77ybDQogICAgICAg
>> "%B64FILE%" echo ICAgICAjIOaXqeWJjeivr+eUqOOAjOWOu+aOieaJqeWxleWQjeOAjeeahOWQjeWtl++8iHJ0NjQw
>> "%B64FILE%" echo eDY0XyrvvInvvIzmsLjov5zljLnphY3kuI3kuIrvvIzlhoXnva7pqbHliqjkuIDkuKrpg70NCiAg
>> "%B64FILE%" echo ICAgICAgICAgICMg5aSN5Yi25LiN5Ye65p2lIOKAlOKAlCDooajnjrDlsLHmmK/jgIzms6jlhaXk
>> "%B64FILE%" echo uobkvYbnvZHljaHov5jmmK/msqHpqbHliqjjgI3jgIINCiAgICAgICAgICAgICRmclJvb3QgPSAi
>> "%B64FILE%" echo JGVudjpTeXN0ZW1Sb290XFN5c3RlbTMyXERyaXZlclN0b3JlXEZpbGVSZXBvc2l0b3J5Ig0KICAg
>> "%B64FILE%" echo ICAgICAgICAgJHBrZ0RpcnMgPSBAKEdldC1DaGlsZEl0ZW0gJGZyUm9vdCAtRGlyZWN0b3J5IC1G
>> "%B64FILE%" echo aWx0ZXIgKCRkcnZJbmYgKyAnXyonKSAtRUEgU2lsZW50bHlDb250aW51ZSkNCiAgICAgICAgICAg
>> "%B64FILE%" echo IGlmICgkcGtnRGlycy5Db3VudCAtZXEgMCkgew0KICAgICAgICAgICAgICAgICRwa2dEaXJzID0g
>> "%B64FILE%" echo QChHZXQtQ2hpbGRJdGVtICRmclJvb3QgLURpcmVjdG9yeSAtRUEgU2lsZW50bHlDb250aW51ZSB8
>> "%B64FILE%" echo DQogICAgICAgICAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLk5hbWUuVG9Mb3dlcigpLlN0
>> "%B64FILE%" echo YXJ0c1dpdGgoJGRydkluZiArICdfJykgfSkNCiAgICAgICAgICAgIH0NCiAgICAgICAgICAgIGlm
>> "%B64FILE%" echo ICgkcGtnRGlycy5Db3VudCAtZXEgMCkgew0KICAgICAgICAgICAgICAgIFNheSAoIiAg5pyq5om+
>> "%B64FILE%" echo 5YiwIHswfSDnmoTpqbHliqjljIXnm67lvZXvvIjlj6/og73pqbHliqjlkI3kuI7nm67lvZXlkI3k
>> "%B64FILE%" echo uI3kuIDoh7TvvIkiIC1mICRkcnZJbmYpICdZZWxsb3cnDQogICAgICAgICAgICB9DQogICAgICAg
>> "%B64FILE%" echo ICAgICBmb3JlYWNoICgkcGQgaW4gJHBrZ0RpcnMpIHsNCiAgICAgICAgICAgICAgICBDb3B5LUl0
>> "%B64FILE%" echo ZW0gLUxpdGVyYWxQYXRoICRwZC5GdWxsTmFtZSAtRGVzdGluYXRpb24gJGRydkRpciAtUmVjdXJz
>> "%B64FILE%" echo ZSAtRm9yY2UgLUVBIFNpbGVudGx5Q29udGludWUNCiAgICAgICAgICAgICAgICBTYXkgKCIgIOW3
>> "%B64FILE%" echo suWkjeWItuWGhee9rue9keWNoempseWKqOWMhTogIiArICRwZC5OYW1lKSAnRGFya0dyYXknDQog
>> "%B64FILE%" echo ICAgICAgICAgICB9DQogICAgICAgIH0gY2F0Y2ggeyBTYXkgKCIgICAgICDlhoXnva7nvZHljaHp
>> "%B64FILE%" echo qbHliqjlr7zlh7rlpLHotKU6ICIgKyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1llbGxvdycgfQ0K
>> "%B64FILE%" echo ICAgIH0NCn0gY2F0Y2ggeyBTYXkgKCIgICAgICDlhoXnva7nvZHljaHpqbHliqjlr7zlh7rlvILl
>> "%B64FILE%" echo uLg6ICIgKyAkXy5FeGNlcHRpb24uTWVzc2FnZSkgJ1llbGxvdycgfQ0KDQokaW5mRmlsZXMgPSBA
>> "%B64FILE%" echo KEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRkcnZEaXIgLVJlY3Vyc2UgLUZpbHRlciAqLmlu
>> "%B64FILE%" echo ZiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkNCiRkcnZNQiA9IDANCnRyeSB7ICRkcnZN
>> "%B64FILE%" echo QiA9IFttYXRoXTo6Um91bmQoKChHZXQtQ2hpbGRJdGVtICRkcnZEaXIgLVJlY3Vyc2UgLUZpbGUg
>> "%B64FILE%" echo fCBNZWFzdXJlLU9iamVjdCBMZW5ndGggLVN1bSkuU3VtKSAvIDFNQiwgMSkgfSBjYXRjaCB7fQ0K
>> "%B64FILE%" echo U2F5ICgiICAgICAg5a+85Ye65a6M5oiQ77yaezB9IOS4quWMhSAvIHsxfSDkuKogSU5GIC8gezJ9
>> "%B64FILE%" echo IE1CIiAtZiAkb2tFeHBvcnQsICRpbmZGaWxlcy5Db3VudCwgJGRydk1CKSAnR3JlZW4nDQppZiAo
>> "%B64FILE%" echo JGluZkZpbGVzLkNvdW50IC1lcSAwKSB7DQogICAgU2F5ICIgIFvplJnor69dIOS4gOS4qiBJTkYg
>> "%B64FILE%" echo 6YO95rKh5a+85Ye677yM5peg5rOV57un57ut44CCIiAnUmVkJw0KICAgIHRyeSB7IFJlbW92ZS1J
>> "%B64FILE%" echo dGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250
>> "%B64FILE%" echo aW51ZSB9IGNhdGNoIHt9DQogICAgaWYgKCRhdHRhY2hlZFZoZHgpIHsgRGlzbW91bnQtVmhkeCAt
>> "%B64FILE%" echo UGF0aCAkYXR0YWNoZWRWaGR4IH0NCiAgICBSZWFkLUhvc3QgIiAg5oyJ5Zue6L2m6YCA5Ye6Ig0K
>> "%B64FILE%" echo ICAgIGV4aXQgMQ0KfQ0KDQojIC0tLS0tLS0tLS0g5o6S6ZmkIElERCDomZrmi5/mmL7npLrpqbHl
>> "%B64FILE%" echo iqggLS0tLS0tLS0tLQ0KIyDjgJDkuLrku4DkuYjopoHmjpLpmaTjgJHov5znqIvkuLLmtYEgLyDm
>> "%B64FILE%" echo qKHmi5/lmaggLyDmipXlsY/ov5nnsbvova/ku7bkvJroo4XkuIDkuKrjgIzpl7TmjqXmmL7npLrp
>> "%B64FILE%" echo qbHliqjjgI3vvIhJRETvvInvvIwNCiMg5a6D5rOo5YaM55qE6K6+5aSH5pivIFJPT1RcRElTUExB
>> "%B64FILE%" echo WVxOTk5OIOKAlOKAlCDnlLHova/ku7boh6rlt7Hlrp7kvovljJbvvIzmsqHmnInnnJ/lrp4gR1BV
>> "%B64FILE%" echo IOehrOS7tuOAgg0KIyDov5nnsbsgSU5GIOS4gOaXpuiiq+azqOWFpe+8jOaWsOezu+e7n+mmluas
>> "%B64FILE%" echo oeW8gOacuiBQblAg5bCx5Lya54WnIFJvb3Qg5p6a5Li+IElEIOW7uuS4gOS4quiuvuWkh+WHuuad
>> "%B64FILE%" echo pe+8jA0KIyDku7vliqHnrqHnkIblmajjgIzmgKfog73jgI3pobXkuo7mmK/lpJrlh7rkuIDlvKDm
>> "%B64FILE%" echo mL7lrZgvM0QvVmlkZW8g5YWo5piv56m655qEIEdQVeOAgg0KIyDnlKjmiLfnnIvliLDnmoTlsLHm
>> "%B64FILE%" echo mK/jgIzoo4Xlpb3kuYvlkI7lpJrkuobkuKrnqbogR1BV44CN77yM6ICM5LiU5Yig5bm954G15pi+
>> "%B64FILE%" echo 5Y2h5a+55a6D5a6M5YWo5peg5pWI44CCDQojIOacrOacuuacieOAgeebruagh+acuuS4jeS4gOWu
>> "%B64FILE%" echo mumcgOimgSDigJTigJQg5bGe5LqO44CM5pCs6L+H5Y675Y+q5Lya5re75Lmx44CN55qE5LiA57G7
>> "%B64FILE%" echo 44CCDQokaWRkUGF0ID0gJyg/aSkoR2FtZVZpZXdlcklkZHxJZGREcml2ZXJ8SWRkU2FtcGxlRHJp
>> "%B64FILE%" echo dmVyfHVzYm1taWRkfFZpcnR1YWxccypEaXNwbGF5fFZpcnR1YWxEaXNwbGF5fE11TXVJZGR8c3Bh
>> "%B64FILE%" echo Y2VkZXNrfGFzdHJvcGFkfFBhcnNlYy4qSWRkfE9jdWx1cy4qKElkZHxEaXNwbGF5KSknDQokYnlE
>> "%B64FILE%" echo aXIgPSBAe30NCmZvcmVhY2ggKCRpbmYgaW4gJGluZkZpbGVzKSB7DQogICAgJGRuID0gJGluZi5E
>> "%B64FILE%" echo aXJlY3RvcnlOYW1lDQogICAgaWYgKC1ub3QgJGJ5RGlyLkNvbnRhaW5zS2V5KCRkbikpIHsgJGJ5
>> "%B64FILE%" echo RGlyWyRkbl0gPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5BcnJheUxpc3QgfQ0KICAg
>> "%B64FILE%" echo IFt2b2lkXSRieURpclskZG5dLkFkZCgkaW5mKQ0KfQ0KJGV4Y2x1ZGVkUGtncyA9IEAoKQ0KJGV4
>> "%B64FILE%" echo Y2x1ZGVkSW5mID0gQCgpDQpmb3JlYWNoICgkZG4gaW4gQCgkYnlEaXIuS2V5cykpIHsNCiAgICAk
>> "%B64FILE%" echo bGlzdCA9ICRieURpclskZG5dDQogICAgJGFsbE1hdGNoID0gJHRydWUNCiAgICAkaGl0TmFtZSA9
>> "%B64FILE%" echo ICcnDQogICAgZm9yZWFjaCAoJGluZiBpbiAkbGlzdCkgew0KICAgICAgICAkdHh0ID0gJycNCiAg
>> "%B64FILE%" echo ICAgICAgdHJ5IHsgJHR4dCA9IFtJTy5GaWxlXTo6UmVhZEFsbFRleHQoJGluZi5GdWxsTmFtZSwg
>> "%B64FILE%" echo W1RleHQuRW5jb2RpbmddOjpEZWZhdWx0KSB9IGNhdGNoIHsgJGFsbE1hdGNoID0gJGZhbHNlOyBi
>> "%B64FILE%" echo cmVhayB9DQogICAgICAgIGlmICgkdHh0IC1ub3RtYXRjaCAkaWRkUGF0KSB7ICRhbGxNYXRjaCA9
>> "%B64FILE%" echo ICRmYWxzZTsgYnJlYWsgfQ0KICAgICAgICBpZiAoLW5vdCAkaGl0TmFtZSkgeyAkaGl0TmFtZSA9
>> "%B64FILE%" echo ICRpbmYuTmFtZSB9DQogICAgfQ0KICAgIGlmICgkYWxsTWF0Y2ggLWFuZCAkbGlzdC5Db3VudCAt
>> "%B64FILE%" echo Z3QgMCkgew0KICAgICAgICAkZXhjbHVkZWRQa2dzICs9IFtQU0N1c3RvbU9iamVjdF1AeyBEaXIg
>> "%B64FILE%" echo PSAkZG47IEluZiA9ICRoaXROYW1lIH0NCiAgICAgICAgZm9yZWFjaCAoJGluZiBpbiAkbGlzdCkg
>> "%B64FILE%" echo eyAkZXhjbHVkZWRJbmYgKz0gJGluZi5GdWxsTmFtZSB9DQogICAgfQ0KfQ0KJGV4Y2x1ZGVkTUIg
>> "%B64FILE%" echo PSAwDQppZiAoJGV4Y2x1ZGVkUGtncy5Db3VudCAtZ3QgMCkgew0KICAgIFNheSAoIiAgICAgIOaO
>> "%B64FILE%" echo kumZpOiZmuaLn+aYvuekuumpseWKqCB7MH0g5Liq77yI5a6D5Lus5Lya6K6p5paw57O757uf5aSa
>> "%B64FILE%" echo 5Ye656m6IEdQVe+8ie+8miIgLWYgJGV4Y2x1ZGVkUGtncy5Db3VudCkgJ1llbGxvdycNCiAgICBm
>> "%B64FILE%" echo b3JlYWNoICgkZSBpbiAkZXhjbHVkZWRQa2dzKSB7DQogICAgICAgIFNheSAoIiAgICAgICAgLSAi
>> "%B64FILE%" echo ICsgJGUuSW5mKSAnRGFya0dyYXknDQogICAgICAgIHRyeSB7ICRleGNsdWRlZE1CICs9IFttYXRo
>> "%B64FILE%" echo XTo6Um91bmQoKChHZXQtQ2hpbGRJdGVtICRlLkRpciAtUmVjdXJzZSAtRmlsZSB8IE1lYXN1cmUt
>> "%B64FILE%" echo T2JqZWN0IExlbmd0aCAtU3VtKS5TdW0pIC8gMU1CLCAxKSB9IGNhdGNoIHt9DQogICAgICAgIHRy
>> "%B64FILE%" echo eSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZS5EaXIgLVJlY3Vyc2UgLUZvcmNlIC1FQSBT
>> "%B64FILE%" echo aWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30NCiAgICB9DQogICAgIyDph43mlrDnu5/orqHopoHm
>> "%B64FILE%" echo s6jlhaXnmoQgSU5GDQogICAgJGluZkZpbGVzID0gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0
>> "%B64FILE%" echo aCAkZHJ2RGlyIC1SZWN1cnNlIC1GaWx0ZXIgKi5pbmYgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
>> "%B64FILE%" echo dGludWUpDQogICAgdHJ5IHsgJGRydk1CID0gW21hdGhdOjpSb3VuZCgoKEdldC1DaGlsZEl0ZW0g
>> "%B64FILE%" echo JGRydkRpciAtUmVjdXJzZSAtRmlsZSB8IE1lYXN1cmUtT2JqZWN0IExlbmd0aCAtU3VtKS5TdW0p
>> "%B64FILE%" echo IC8gMU1CLCAxKSB9IGNhdGNoIHt9DQogICAgU2F5ICgiICAgICAg5a6e6ZmF5rOo5YWl77yaezB9
>> "%B64FILE%" echo IOS4qiBJTkYgLyB7MX0gTULvvIjlt7LmjpLpmaQgezJ9IE1C77yJIiAtZiAkaW5mRmlsZXMuQ291
>> "%B64FILE%" echo bnQsICRkcnZNQiwgJGV4Y2x1ZGVkTUIpICdHcmVlbicNCiAgICBpZiAoJGluZkZpbGVzLkNvdW50
>> "%B64FILE%" echo IC1lcSAwKSB7DQogICAgICAgIFNheSAiICBb6ZSZ6K+vXSDmjpLpmaTlkI7msqHmnInlj6/ms6jl
>> "%B64FILE%" echo haXnmoTpqbHliqjljIXjgIIiICdSZWQnDQogICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtIC1MaXRl
>> "%B64FILE%" echo cmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IGNh
>> "%B64FILE%" echo dGNoIHt9DQogICAgICAgIGlmICgkYXR0YWNoZWRWaGR4KSB7IERpc21vdW50LVZoZHggLVBhdGgg
>> "%B64FILE%" echo JGF0dGFjaGVkVmhkeCB9DQogICAgICAgIFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQog
>> "%B64FILE%" echo ICAgICAgIGV4aXQgMQ0KICAgIH0NCn0gZWxzZSB7DQogICAgU2F5ICIgICAgICDmsqHmnInlj5Hn
>> "%B64FILE%" echo jrDomZrmi5/mmL7npLrvvIhJRETvvInpqbHliqgiICdEYXJrR3JheScNCn0NCg0KIyDnqbrpl7Tm
>> "%B64FILE%" echo o4Dmn6XvvJrms6jlhaXlkI7pqbHliqjlupPkvJrljaDmjonlkIznrYnkvZPnp6/vvIznlZkgMS41
>> "%B64FILE%" echo IOWAjeS9memHjw0KJG5lZWRHQiA9IFttYXRoXTo6Um91bmQoKCRkcnZNQiAvIDEwMjQpICogMS41
>> "%B64FILE%" echo ICsgMC41LCAxKQ0KaWYgKCR0YXJnZXQuRnJlZUdCIC1sdCAkbmVlZEdCKSB7DQogICAgU2F5ICgi
>> "%B64FILE%" echo ICBb6ZSZ6K+vXSDnm67moIfns7vnu5/lj6rliakgezB9IEdC77yM5rOo5YWl5aSn57qm6ZyA6KaB
>> "%B64FILE%" echo IHsxfSBHQuOAguivt+WFiOaJqeWuueaIlua4heeQhuOAgiIgLWYgJHRhcmdldC5GcmVlR0IsICRu
>> "%B64FILE%" echo ZWVkR0IpICdSZWQnDQogICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRkcnZEaXIg
>> "%B64FILE%" echo LVJlY3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30NCiAgICBpZiAo
>> "%B64FILE%" echo JGF0dGFjaGVkVmhkeCkgeyBEaXNtb3VudC1WaGR4IC1QYXRoICRhdHRhY2hlZFZoZHggfQ0KICAg
>> "%B64FILE%" echo IFJlYWQtSG9zdCAiICDmjInlm57ovabpgIDlh7oiDQogICAgZXhpdCAxDQp9DQpTYXkgKCIgICAg
>> "%B64FILE%" echo ICDnqbrpl7Tmo4Dmn6XpgJrov4fvvIjpnIDopoEgezB9IEdC77yM5Y+v55SoIHsxfSBHQu+8iSIg
>> "%B64FILE%" echo LWYgJG5lZWRHQiwgJHRhcmdldC5GcmVlR0IpICdEYXJrR3JheScNCg0KIyDnlZnkuIDku73nu5nj
>> "%B64FILE%" echo gIzmlrDns7vnu5/ph4znjrDlnLroo4XjgI3nlKjvvJrmlL7liLAgdmhkeCDmiYDlnKjnm5jnmoQg
>> "%B64FILE%" echo TmV3U3lzdGVtRHJpdmVyDQoka2VlcERpciA9ICcnDQokdmhkeFBhdGggPSAkYXR0YWNoZWRWaGR4
>> "%B64FILE%" echo DQppZiAoLW5vdCAkdmhkeFBhdGgpIHsNCiAgICBmb3JlYWNoICgkZiBpbiBAKEZpbmQtVmhkeEZp
>> "%B64FILE%" echo bGVzKSkgeyAkdmhkeFBhdGggPSAkZjsgYnJlYWsgfQ0KfQ0KaWYgKCR2aGR4UGF0aCkgew0KICAg
>> "%B64FILE%" echo IHRyeSB7DQogICAgICAgICRrZWVwRGlyID0gSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQg
>> "%B64FILE%" echo JHZoZHhQYXRoKSAnTmV3U3lzdGVtRHJpdmVyJw0KICAgICAgICBpZiAoVGVzdC1QYXRoIC1MaXRl
>> "%B64FILE%" echo cmFsUGF0aCAka2VlcERpcikgeyBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGtlZXBEaXIgLVJl
>> "%B64FILE%" echo Y3Vyc2UgLUZvcmNlIC1FQSBTaWxlbnRseUNvbnRpbnVlIH0NCiAgICAgICAgTmV3LUl0ZW0gLUl0
>> "%B64FILE%" echo ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAka2VlcERpciAtRm9yY2UgfCBPdXQtTnVsbA0KICAgICAg
>> "%B64FILE%" echo ICBTYXkgKCIgICAgICDlj6blrZjkuIDku73liLAgezB977yI6L+b5paw57O757uf5ZCO5Y+v546w
>> "%B64FILE%" echo 5Zy66KOF77yJLi4uIiAtZiAka2VlcERpcikgJ0RhcmtHcmF5Jw0KICAgICAgICBDb3B5LUl0ZW0g
>> "%B64FILE%" echo LVBhdGggKEpvaW4tUGF0aCAkZHJ2RGlyICcqJykgLURlc3RpbmF0aW9uICRrZWVwRGlyIC1SZWN1
>> "%B64FILE%" echo cnNlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZQ0KICAgICAgICBTYXkgIiAgICAgIOW3suWP
>> "%B64FILE%" echo puWtmCIgJ0dyZWVuJw0KICAgIH0gY2F0Y2ggew0KICAgICAgICAka2VlcERpciA9ICcnDQogICAg
>> "%B64FILE%" echo ICAgIFNheSAoIiAgICAgIOWPpuWtmOWksei0pe+8iOS4jeW9seWTjeazqOWFpe+8iTogIiArICRf
>> "%B64FILE%" echo LkV4Y2VwdGlvbi5NZXNzYWdlKSAnWWVsbG93Jw0KICAgIH0NCn0NCg0KIyAtLS0tLS0tLS0tIFsz
>> "%B64FILE%" echo LzRdIOazqOWFpSAtLS0tLS0tLS0tDQpTYXkgIlszLzRdIOazqOWFpeWFqOmDqOmpseWKqO+8iDN+
>> "%B64FILE%" echo MTAg5YiG6ZKf77yM5Yir5YWz56qX5Y+j77yJLi4uIiAnV2hpdGUnDQokbG9nRmlsZSA9IEpvaW4t
>> "%B64FILE%" echo UGF0aCAkZW52OlRFTVAgKCJhbGxkcnZfezB9LmxvZyIgLWYgJFBJRCkNCiRlcnJGaWxlID0gJGxv
>> "%B64FILE%" echo Z0ZpbGUgKyAnLmVycicNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRsb2dGaWxl
>> "%B64FILE%" echo KSB7IFJlbW92ZS1JdGVtICRsb2dGaWxlIC1Gb3JjZSAtRUEgU2lsZW50bHlDb250aW51ZSB9IH0g
>> "%B64FILE%" echo Y2F0Y2gge30NCg0KJGRpc21BcmdzID0gJy9FbmdsaXNoIC9JbWFnZTp7MH06XCAvQWRkLURyaXZl
>> "%B64FILE%" echo ciAvRHJpdmVyOiJ7MX0iIC9SZWN1cnNlJyAtZiAkdGFyZ2V0LkxldHRlciwgJGRydkRpcg0KU2F5
>> "%B64FILE%" echo ICgiICAgICAgZGlzbSB7MH0iIC1mICRkaXNtQXJncykgJ0RhcmtHcmF5Jw0KDQokcHJvYyA9IFN0
>> "%B64FILE%" echo YXJ0LVByb2Nlc3MgLUZpbGVQYXRoICdkaXNtLmV4ZScgLUFyZ3VtZW50TGlzdCAkZGlzbUFyZ3Mg
>> "%B64FILE%" echo YA0KICAgICAgICAgICAgLVJlZGlyZWN0U3RhbmRhcmRPdXRwdXQgJGxvZ0ZpbGUgLVJlZGlyZWN0
>> "%B64FILE%" echo U3RhbmRhcmRFcnJvciAkZXJyRmlsZSBgDQogICAgICAgICAgICAtTm9OZXdXaW5kb3cgLVBhc3NU
>> "%B64FILE%" echo aHJ1IC1FcnJvckFjdGlvbiBTdG9wDQoNCiRzdyA9IFtTeXN0ZW0uRGlhZ25vc3RpY3MuU3RvcHdh
>> "%B64FILE%" echo dGNoXTo6U3RhcnROZXcoKQ0KJGxhc3RCZWF0ID0gMA0Kd2hpbGUgKC1ub3QgJHByb2MuSGFzRXhp
>> "%B64FILE%" echo dGVkKSB7DQogICAgU3RhcnQtU2xlZXAgLU1pbGxpc2Vjb25kcyA5MDANCiAgICBpZiAoKCRzdy5F
>> "%B64FILE%" echo bGFwc2VkTWlsbGlzZWNvbmRzIC0gJGxhc3RCZWF0KSAtZ2UgNTAwMCkgew0KICAgICAgICAkbGFz
>> "%B64FILE%" echo dEJlYXQgPSAkc3cuRWxhcHNlZE1pbGxpc2Vjb25kcw0KICAgICAgICAkZG9uZSA9IDANCiAgICAg
>> "%B64FILE%" echo ICAgdHJ5IHsgJGRvbmUgPSBAKFtyZWdleF06Ok1hdGNoZXMoW0lPLkZpbGVdOjpSZWFkQWxsVGV4
>> "%B64FILE%" echo dCgkbG9nRmlsZSksICcoP2kpSW5zdGFsbGluZyBcZCsgb2YgXGQrJykpLkNvdW50IH0gY2F0Y2gg
>> "%B64FILE%" echo e30NCiAgICAgICAgU2F5ICgiICAgICAg5bey55SoIHswfSDnp5LvvIzlt7LlpITnkIYgezF9IOS4
>> "%B64FILE%" echo qiAuLi4iIC1mIFtpbnRdJHN3LkVsYXBzZWQuVG90YWxTZWNvbmRzLCAkZG9uZSkgJ0RhcmtHcmF5
>> "%B64FILE%" echo Jw0KICAgIH0NCiAgICBpZiAoJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgLWd0IDE4MDAwMDApIHsN
>> "%B64FILE%" echo CiAgICAgICAgdHJ5IHsgU3RvcC1Qcm9jZXNzIC1JZCAkcHJvYy5JZCAtRm9yY2UgLUVBIFNpbGVu
>> "%B64FILE%" echo dGx5Q29udGludWUgfSBjYXRjaCB7fQ0KICAgICAgICBTYXkgIiAgICAgIOi2hei/hyAzMCDliIbp
>> "%B64FILE%" echo kp/vvIzlt7LmlL7lvIMiICdSZWQnDQogICAgICAgIGJyZWFrDQogICAgfQ0KfQ0KdHJ5IHsgJHBy
>> "%B64FILE%" echo b2MuV2FpdEZvckV4aXQoKSB9IGNhdGNoIHt9DQoNCiMgLS0tLS0tLS0tLSBbNC80XSDnu5Pmnpwg
>> "%B64FILE%" echo LS0tLS0tLS0tLQ0KU2F5ICIiDQokdHh0ID0gJycNCnRyeSB7IGlmIChUZXN0LVBhdGggLUxpdGVy
>> "%B64FILE%" echo YWxQYXRoICRsb2dGaWxlKSB7ICR0eHQgPSBbSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRsb2dGaWxl
>> "%B64FILE%" echo LCBbVGV4dC5FbmNvZGluZ106OkRlZmF1bHQpIH0gfSBjYXRjaCB7fQ0KJGVyclR4dCA9ICcnDQp0
>> "%B64FILE%" echo cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZXJyRmlsZSkgeyAkZXJyVHh0ID0gW0lP
>> "%B64FILE%" echo LkZpbGVdOjpSZWFkQWxsVGV4dCgkZXJyRmlsZSwgW1RleHQuRW5jb2RpbmddOjpEZWZhdWx0KSB9
>> "%B64FILE%" echo IH0gY2F0Y2gge30NCg0KJG9rTGlzdCA9IEAoW3JlZ2V4XTo6TWF0Y2hlcygkdHh0LCAnKD9pKUlu
>> "%B64FILE%" echo c3RhbGxpbmcgXGQrIG9mIFxkKyAtICguKz8pOlxzKig/OlRoZSBkcml2ZXIgcGFja2FnZSB3YXMg
>> "%B64FILE%" echo c3VjY2Vzc2Z1bGx5IGluc3RhbGxlZHzpqbHliqjljIUuKj/lt7LmiJDlip/lronoo4UpJykgfCBG
>> "%B64FILE%" echo b3JFYWNoLU9iamVjdCB7ICRfLkdyb3Vwc1sxXS5WYWx1ZSB9KQ0KJGZhaWxMaXN0ID0gQChbcmVn
>> "%B64FILE%" echo ZXhdOjpNYXRjaGVzKCR0eHQsICcoP2kpSW5zdGFsbGluZyBcZCsgb2YgXGQrIC0gKC4rPyk6XHMq
>> "%B64FILE%" echo RXJyb3InKSB8IEZvckVhY2gtT2JqZWN0IHsgJF8uR3JvdXBzWzFdLlZhbHVlIH0pDQoNClNheSAi
>> "%B64FILE%" echo WzQvNF0g57uT5p6c77yaIiAnV2hpdGUnDQpTYXkgKCIgICAgICDmiJDlip/ms6jlhaU6IHswfSDk
>> "%B64FILE%" echo uKrpqbHliqjljIUiIC1mICRva0xpc3QuQ291bnQpICdHcmVlbicNCmlmICgkZmFpbExpc3QuQ291
>> "%B64FILE%" echo bnQgLWd0IDApIHsNCiAgICBTYXkgKCIgICAgICDmnKrpgILnlKggIDogezB9IOS4qu+8iOezu+e7
>> "%B64FILE%" echo n+eJiOacrOS4jeWMuemFje+8jOingeaXpeW/l++8iSIgLWYgJGZhaWxMaXN0LkNvdW50KSAnWWVs
>> "%B64FILE%" echo bG93Jw0KICAgIGZvcmVhY2ggKCRmIGluICgkZmFpbExpc3QgfCBTZWxlY3QtT2JqZWN0IC1GaXJz
>> "%B64FILE%" echo dCAxMikpIHsgU2F5ICgiICAgICAgICAtICIgKyAkZikgJ0RhcmtHcmF5JyB9DQogICAgaWYgKCRm
>> "%B64FILE%" echo YWlsTGlzdC5Db3VudCAtZ3QgMTIpIHsgU2F5ICgiICAgICAgICAuLi4g6L+Y5pyJIHswfSDkuKoi
>> "%B64FILE%" echo IC1mICgkZmFpbExpc3QuQ291bnQgLSAxMikpICdEYXJrR3JheScgfQ0KfQ0KU2F5ICgiICAgICAg
>> "%B64FILE%" echo 5pel5b+XOiB7MH0iIC1mICRsb2dGaWxlKSAnR3JheScNCg0KU2F5ICIiDQppZiAoJG9rTGlzdC5D
>> "%B64FILE%" echo b3VudCAtZ3QgMCkgew0KICAgIFNheSAiICDms6jlhaXlrozmiJDjgILph43lkK/ov5vmlrDns7vn
>> "%B64FILE%" echo u5/lkI7vvIzorr7lpIfnrqHnkIblmajph4znmoTmnKrnn6Xorr7lpIflupTor6XkvJrlpKfluYXl
>> "%B64FILE%" echo h4/lsJHjgIIiICdHcmVlbicNCiAgICBpZiAoJGtlZXBEaXIpIHsNCiAgICAgICAgU2F5ICgiICDl
>> "%B64FILE%" echo poLmnpzov5jmnInlh6DkuKrluKbmhJ/lj7nlj7fvvIzov5vmlrDns7vnu5/lkI7ov5DooYwg55uu
>> "%B64FILE%" echo 5b2V6YeM55qE44CM6K+K5pat5bm26KOF6amx5Yqo44CN77yM5a6D5Lya55SoIHswfSIgLWYgJGtl
>> "%B64FILE%" echo ZXBEaXIpICdHcmF5Jw0KICAgIH0NCn0gZWxzZSB7DQogICAgU2F5ICIgIOS4gOS4qumDveayoeaz
>> "%B64FILE%" echo qOWFpeaIkOWKn++8jOivt+eci+aXpeW/l+mHjOeahOmUmeivr+OAgiIgJ1JlZCcNCiAgICBpZiAo
>> "%B64FILE%" echo JGVyclR4dC5UcmltKCkpIHsgZm9yZWFjaCAoJGwgaW4gQCgkZXJyVHh0IC1zcGxpdCAiW2ByYG5d
>> "%B64FILE%" echo KyIgfCBXaGVyZS1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFNlbGVjdC1PYmplY3QgLUxhc3QgNikp
>> "%B64FILE%" echo IHsgU2F5ICgiICAgICAgIiArICRsKSAnWWVsbG93JyB9IH0NCn0NCg0KIyAtLS0tLS0tLS0tIOaU
>> "%B64FILE%" echo tuWwviAtLS0tLS0tLS0tDQp0cnkgeyBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZHJ2RGly
>> "%B64FILE%" echo KSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkZHJ2RGlyIC1SZWN1cnNlIC1Gb3JjZSAtRUEg
>> "%B64FILE%" echo U2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30NCmlmICgkYXR0YWNoZWRWaGR4KSB7DQogICAg
>> "%B64FILE%" echo U2F5ICIiDQogICAgU2F5ICgiICDljbjovb3kuLTml7bmjILovb3nmoTomZrmi5/no4Hnm5ggLi4u
>> "%B64FILE%" echo IikgJ0RhcmtHcmF5Jw0KICAgIERpc21vdW50LVZoZHggLVBhdGggJGF0dGFjaGVkVmhkeA0KICAg
>> "%B64FILE%" echo IFNheSAiICDlt7Lljbjovb0iICdEYXJrR3JheScNCn0NClNheSAiIg0KUmVhZC1Ib3N0ICIgIOaM
>> "%B64FILE%" echo ieWbnui9pumAgOWHuiINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=19852"
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
