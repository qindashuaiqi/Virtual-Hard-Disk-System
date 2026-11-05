@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title 清理残留盘符

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
set "PS1FILE=%WORKDIR%\清理ESP盘符-管理员运行.ps1"

> "%B64FILE%" echo -----BEGIN-----
>> "%B64FILE%" echo 77u/IyDmkZjpmaTmrovnlZnnmoQgRVNQIOebmOespu+8iFM677yJDQojIOmcgOimgeeuoeeQhuWR
>> "%B64FILE%" echo mOadg+mZkOi/kOihjOOAguWPquenu+mZpOOAjOiuv+mXrui3r+W+hOOAje+8jOS4jeaUueWIhuWM
>> "%B64FILE%" echo uuaVsOaNru+8jOe7neWvueWuieWFqOOAgg0KIyDkvZzogIXvvJpjb25uZWN0c2VnYWJvdA0KJFNj
>> "%B64FILE%" echo cmlwdDpWZXJzaW9uID0gJzEuMzEnDQpXcml0ZS1Ib3N0ICgi5riF55CG5q6L55WZ55uY56ymIHZ7
>> "%B64FILE%" echo MH0gLSDkvZzogIXvvJpjb25uZWN0c2VnYWJvdCIgLWYgJFNjcmlwdDpWZXJzaW9uKQ0KV3JpdGUt
>> "%B64FILE%" echo SG9zdCAiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09Ig0KJGVzcEd1
>> "%B64FILE%" echo aWQgPSAnYzEyYTczMjgtZjgxZi0xMWQyLWJhNGItMDBhMGM5M2VjOTNiJw0KZm9yZWFjaCAoJHBh
>> "%B64FILE%" echo cnQgaW4gKEdldC1QYXJ0aXRpb24gLUVBIFNpbGVudGx5Q29udGludWUpKSB7DQogICAgaWYgKC1u
>> "%B64FILE%" echo b3QgJHBhcnQuRHJpdmVMZXR0ZXIpIHsgY29udGludWUgfQ0KICAgICRncHQgPSAoW3N0cmluZ10k
>> "%B64FILE%" echo cGFydC5HcHRUeXBlIC1yZXBsYWNlICdbe31dJywgJycpLlRvTG93ZXIoKQ0KICAgIGlmICgkZ3B0
>> "%B64FILE%" echo IC1uZSAkZXNwR3VpZCkgeyBjb250aW51ZSB9DQogICAgJGRsID0gW3N0cmluZ10kcGFydC5Ecml2
>> "%B64FILE%" echo ZUxldHRlcg0KICAgIFdyaXRlLUhvc3QgKCLlj5HnjrAgRUZJIOezu+e7n+WIhuWMuuWNoOedgOeb
>> "%B64FILE%" echo mOespiB7MH06IChEaXNrezF9IFBhcnR7Mn0pIiAtZiAkZGwsICRwYXJ0LkRpc2tOdW1iZXIsICRw
>> "%B64FILE%" echo YXJ0LlBhcnRpdGlvbk51bWJlcikNCiAgICB0cnkgew0KICAgICAgICAjIOeUqCAtRHJpdmVMZXR0
>> "%B64FILE%" echo ZXLvvJotQWNjZXNzUGF0aCDopoHnmoTmmK/ljbforr/pl67ot6/lvoTvvIgiUzpcIu+8ie+8jOS8
>> "%B64FILE%" echo oCAiUzoiIOS8muaKpeWPguaVsOaXoOaViA0KICAgICAgICBSZW1vdmUtUGFydGl0aW9uQWNjZXNz
>> "%B64FILE%" echo UGF0aCAtRGlza051bWJlciAkcGFydC5EaXNrTnVtYmVyIC1QYXJ0aXRpb25OdW1iZXIgJHBhcnQu
>> "%B64FILE%" echo UGFydGl0aW9uTnVtYmVyIC1Ecml2ZUxldHRlciAkZGwgLUVBIFN0b3AgfCBPdXQtTnVsbA0KICAg
>> "%B64FILE%" echo ICAgICBXcml0ZS1Ib3N0ICLlt7LmkZjpmaTnm5jnrKYgJGRsYDogICjnu7/oibI95oiQ5YqfKSIg
>> "%B64FILE%" echo LUZvcmVncm91bmRDb2xvciBHcmVlbg0KICAgIH0gY2F0Y2ggew0KICAgICAgICBXcml0ZS1Ib3N0
>> "%B64FILE%" echo ICgi5pGY6Zmk5aSx6LSlOiB7MH0iIC1mICRfLkV4Y2VwdGlvbi5NZXNzYWdlKSAtRm9yZWdyb3Vu
>> "%B64FILE%" echo ZENvbG9yIFJlZA0KICAgIH0NCn0NCldyaXRlLUhvc3QgIiINCldyaXRlLUhvc3QgIuWujOaIkOOA
>> "%B64FILE%" echo guatpOeql+WPoyA1IOenkuWQjuiHquWKqOWFs+mXreOAgiINCg==
>> "%B64FILE%" echo -----END-----

findstr /v /c:"-----BEGIN-----" /c:"-----END-----" "%B64FILE%" > "%RAW%"
certutil -decode "%RAW%" "%PS1FILE%" >nul 2>&1

rem 必须校验字节数：certutil 失败时不会返回可靠错误码，
rem 而文件可能已被创建成 0 字节或半截，光判断存在会漏掉。
set "NEED=1291"
set "GOT=0"
for %%A in ("%PS1FILE%") do if exist "%%A" set "GOT=%%~zA"
if not "%GOT%"=="%NEED%" (
    echo.
    echo   [错误] 自解压失败（期望 %NEED% 字节，实际 %GOT% 字节）。
    echo          请重新复制本文件，或临时关闭杀毒软件后重试。
    echo.
    pause
    exit /b 1
)

echo.
echo   正在启动，请稍候...
echo.
rem %~dp0 结尾带反斜杠，作为参数会转义引号，先去掉
set "ORIGIN=%~dp0"
if "%ORIGIN:~-1%"=="\" set "ORIGIN=%ORIGIN:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%PS1FILE%\"' -Verb RunAs"
exit /b 0
