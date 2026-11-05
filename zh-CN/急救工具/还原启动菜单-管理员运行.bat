@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 还原启动菜单
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
set "PS1FILE=%WORKDIR%\还原启动菜单-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/PCMNCiAg6L+Y5Y6f5ZCv5Yqo6I+c5Y2V77yI5LiA6ZSu5YWz6Zet5q6L55WZ55qE5byA5py6
>> "%B64FILE%" echo 6I+c5Y2V77yJDQogIOS9nOiAhe+8mmNvbm5lY3RzZWdhYm90DQoNCiAg55So6YCU77ya5Y246L29
>> "%B64FILE%" echo 5paw57O757uf5ZCO77yM5aaC5p6c5byA5py66I+c5Y2V6L+Y5Zyo77yI5rKh55u05o6l6L+b5Y6f
>> "%B64FILE%" echo 57O757uf77yJ77yMDQogICAgICAgIOWPjOWHu+WvueW6lOeahCBiYXQg6LeR5LiA5qyh5Y2z5Y+v
>> "%B64FILE%" echo 44CC5a6D5Lya77yaDQogICAgICAgICAgMS4g5oqKIGRpc3BsYXlib290bWVudSDorr7kuLogTm/v
>> "%B64FILE%" echo vIjlhbPmjonoj5zljZXvvIznm7TmjqXov5vpu5jorqTns7vnu5/vvIkNCiAgICAgICAgICAyLiDm
>> "%B64FILE%" echo ioogdGltZW91dCDorr7kuLogMO+8iOS4jeetie+8jOenkui/m++8iQ0KICAgICAgICDov5nmoLfl
>> "%B64FILE%" echo vIDmnLrlsLHmgaLlpI3liLDjgIzkuI3mmL7npLroj5zljZXjgIHnm7TmjqXov5vljp/ns7vnu5/j
>> "%B64FILE%" echo gI3nmoTpu5jorqTnirbmgIHjgIINCg0KICDlpoLmnpzkvaDkuYvliY3oh6rlt7HphY3ov4flvIDm
>> "%B64FILE%" echo nLroj5zljZXvvIjmr5TlpoLlj4zns7vnu5/vvInvvIzkuI3mg7PlrozlhajlhbPmjonvvIwNCiAg
>> "%B64FILE%" echo 6K+35pS555So5LiL6Z2i5Lik5Y+l5omL5Yqo5ZG95Luk77yM5oqKIHRpbWVvdXQg5o2i5oiQ5L2g
>> "%B64FILE%" echo 6KaB55qE56eS5pWw77yaDQogICAgICBiY2RlZGl0IC9zZXQge2Jvb3RtZ3J9IGRpc3BsYXlib290
>> "%B64FILE%" echo bWVudSBObw0KICAgICAgYmNkZWRpdCAvc2V0IHtib290bWdyfSB0aW1lb3V0IDUNCiM+DQoNCiRF
>> "%B64FILE%" echo cnJvckFjdGlvblByZWZlcmVuY2UgPSAnU3RvcCcNCiRTY3JpcHQ6VmVyc2lvbiA9ICcxLjMyJw0K
>> "%B64FILE%" echo DQpmdW5jdGlvbiBUZXN0LUFkbWluIHsNCiAgICAkaWQgPSBbU2VjdXJpdHkuUHJpbmNpcGFsLldp
>> "%B64FILE%" echo bmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKQ0KICAgICRwID0gTmV3LU9iamVjdCBTZWN1cml0
>> "%B64FILE%" echo eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbCgkaWQpDQogICAgcmV0dXJuICRwLklzSW5Sb2xl
>> "%B64FILE%" echo KFtTZWN1cml0eS5QcmluY2lwYWwuV2luZG93c0J1aWx0SW5Sb2xlXTo6QWRtaW5pc3RyYXRvcikN
>> "%B64FILE%" echo Cn0NCg0KV3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAoIui/mOWOn+WQr+WKqOiPnOWNle+8iOWF
>> "%B64FILE%" echo s+mXreaui+eVmeeahOW8gOacuuiPnOWNle+8iSB2ezB9IC0g5L2c6ICF77yaY29ubmVjdHNlZ2Fi
>> "%B64FILE%" echo b3QiIC1mICRTY3JpcHQ6VmVyc2lvbikNCldyaXRlLUhvc3QgJz09PT09PT09PT09PT09PT09PT09
>> "%B64FILE%" echo PT09PT09PT09PT09PT09PT09PT09PT09Jw0KV3JpdGUtSG9zdCAnJw0KDQppZiAoLW5vdCAoVGVz
>> "%B64FILE%" echo dC1BZG1pbikpIHsNCiAgICBXcml0ZS1Ib3N0ICdb6ZSZ6K+vXSDpnIDopoHnrqHnkIblkZjmnYPp
>> "%B64FILE%" echo mZDjgILor7flj7PplK7mnKzohJrmnKzvvIzpgInmi6njgIzkvb/nlKggUG93ZXJTaGVsbCDov5Do
>> "%B64FILE%" echo oYzjgI3vvIzmiJbpgJrov4fpmYTluKbnmoQgYmF0IOS7peeuoeeQhuWRmOi6q+S7vei/kOihjOOA
>> "%B64FILE%" echo gicgLUZvcmVncm91bmRDb2xvciBSZWQNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9z
>> "%B64FILE%" echo dCAn5oyJ5Lu75oSP6ZSu6YCA5Ye6Li4uJw0KICAgICRudWxsID0gJEhvc3QuVUkuUmF3VUkuUmVh
>> "%B64FILE%" echo ZEtleSgnTm9FY2hvLEluY2x1ZGVLZXlEb3duJykNCiAgICBleGl0IDENCn0NCg0KV3JpdGUtSG9z
>> "%B64FILE%" echo dCAn5Y2z5bCG5omn6KGM77yaJw0KV3JpdGUtSG9zdCAnICBiY2RlZGl0IC9zZXQge2Jvb3RtZ3J9
>> "%B64FILE%" echo IGRpc3BsYXlib290bWVudSBObyAgIO+8iOW8gOacuuS4jeWGjeaYvuekuuiPnOWNle+8iScNCldy
>> "%B64FILE%" echo aXRlLUhvc3QgJyAgYmNkZWRpdCAvc2V0IHtib290bWdyfSB0aW1lb3V0IDAgICAgICAgICAgICDv
>> "%B64FILE%" echo vIjkuI3nrYnlvoXvvIznm7TmjqXov5vpu5jorqTns7vnu5/vvIknDQpXcml0ZS1Ib3N0ICcnDQpX
>> "%B64FILE%" echo cml0ZS1Ib3N0ICfms6jmhI/vvJrlpoLmnpzkvaDmmK/lpJrns7vnu5/nlKjmiLfvvIjmnLrlmajk
>> "%B64FILE%" echo uIrov5jmnInlj6bkuIDkuKogV2luZG93c+OAgUxpbnV4IOaIliBXaW5QRSDlkK/liqjpobnvvInv
>> "%B64FILE%" echo vIwnIC1Gb3JlZ3JvdW5kQ29sb3IgWWVsbG93DQpXcml0ZS1Ib3N0ICcgICAgICDoj5zljZXlhbPm
>> "%B64FILE%" echo jonlkI7lvIDmnLrlsLHmsqHms5XpgInns7vnu5/kuobjgILopoHmgaLlpI3or7flnKjnrqHnkIbl
>> "%B64FILE%" echo kZjlkb3ku6TooYzmiafooYzvvJonIC1Gb3JlZ3JvdW5kQ29sb3IgWWVsbG93DQpXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICcgICAgICAgICAgYmNkZWRpdCAvc2V0IHtib290bWdyfSBkaXNwbGF5Ym9vdG1lbnUgWWVzJyAt
>> "%B64FILE%" echo Rm9yZWdyb3VuZENvbG9yIFllbGxvdw0KV3JpdGUtSG9zdCAnICAgICAgICAgIGJjZGVkaXQgL3Nl
>> "%B64FILE%" echo dCB7Ym9vdG1ncn0gdGltZW91dCAxMCcgLUZvcmVncm91bmRDb2xvciBZZWxsb3cNCldyaXRlLUhv
>> "%B64FILE%" echo c3QgJycNCiRhbnMgPSBSZWFkLUhvc3QgJ+ehruWumue7p+e7re+8n+i+k+WFpSB5IOWGjeWbnui9
>> "%B64FILE%" echo puehruiupO+8jOebtOaOpeWbnui9puWPlua2iCcNCmlmICgkYW5zIC1uZSAneScgLWFuZCAkYW5z
>> "%B64FILE%" echo IC1uZSAnWScpIHsNCiAgICBXcml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9zdCAn5bey5Y+W5raI
>> "%B64FILE%" echo 77yM5rKh5pyJ5YGa5Lu75L2V5L+u5pS544CCJyAtRm9yZWdyb3VuZENvbG9yIEN5YW4NCiAgICBX
>> "%B64FILE%" echo cml0ZS1Ib3N0ICcnDQogICAgV3JpdGUtSG9zdCAn5oyJ5Lu75oSP6ZSu6YCA5Ye6Li4uJw0KICAg
>> "%B64FILE%" echo ICRudWxsID0gJEhvc3QuVUkuUmF3VUkuUmVhZEtleSgnTm9FY2hvLEluY2x1ZGVLZXlEb3duJykN
>> "%B64FILE%" echo CiAgICBleGl0IDANCn0NCg0KV3JpdGUtSG9zdCAnJw0KV3JpdGUtSG9zdCAn5q2j5Zyo5YWz6Zet
>> "%B64FILE%" echo 5byA5py66I+c5Y2VLi4uJw0KJHIxID0gJiBiY2RlZGl0IC9zZXQgJ3tib290bWdyfScgZGlzcGxh
>> "%B64FILE%" echo eWJvb3RtZW51IE5vIDI+JjEgfCBPdXQtU3RyaW5nDQpXcml0ZS1Ib3N0ICgiICBkaXNwbGF5Ym9v
>> "%B64FILE%" echo dG1lbnUgTm8gID0+ICB7MH0iIC1mICgkcjEgLXJlcGxhY2UgJ1xzKycsICcgJykuVHJpbSgpKQ0K
>> "%B64FILE%" echo DQokcjIgPSAmIGJjZGVkaXQgL3NldCAne2Jvb3RtZ3J9JyB0aW1lb3V0IDAgMj4mMSB8IE91dC1T
>> "%B64FILE%" echo dHJpbmcNCldyaXRlLUhvc3QgKCIgIHRpbWVvdXQgMCAgICAgICAgICAgPT4gIHswfSIgLWYgKCRy
>> "%B64FILE%" echo MiAtcmVwbGFjZSAnXHMrJywgJyAnKS5UcmltKCkpDQoNCldyaXRlLUhvc3QgJycNCldyaXRlLUhv
>> "%B64FILE%" echo c3QgJ+WujOaIkOOAgueOsOWcqOW8gOacuuS8muebtOaOpei/m+m7mOiupOezu+e7n++8jOS4jeWG
>> "%B64FILE%" echo jeaYvuekuuiPnOWNleOAgicgLUZvcmVncm91bmRDb2xvciBHcmVlbg0KV3JpdGUtSG9zdCAnJw0K
>> "%B64FILE%" echo V3JpdGUtSG9zdCAn5oyJ5Lu75oSP6ZSu6YCA5Ye6Li4uJw0KJG51bGwgPSAkSG9zdC5VSS5SYXdV
>> "%B64FILE%" echo SS5SZWFkS2V5KCdOb0VjaG8sSW5jbHVkZUtleURvd24nKQ0K
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=3228"
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
