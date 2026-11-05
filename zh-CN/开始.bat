@echo off
setlocal
chcp 936 >nul 2>&1
title 虚拟硬盘系统  -  connectsegabot
cd /d "%~dp0"

:menu
cls
echo.
echo    ============================================================
echo       虚拟硬盘系统   作者：connectsegabot
echo    ============================================================
echo.
echo    【主功能】
echo       1. 装系统            可装多个，名字和存放位置自己定
echo       2. 卸载新系统        按名字删掉某个虚拟系统
echo.
echo    【装完之后 / 在新系统里跑】
echo       3. 诊断并装驱动      还有设备带感叹号
echo       4. 显卡体检          多一张空 GPU / 有幽灵记录
echo       5. 全量注入驱动      设备管理器一堆未知设备
echo       6. 注入网卡驱动      只是没网（只搬网卡驱动）
echo.
echo    【出问题时 / 在原系统里跑】
echo       7. 修好菜单指向      菜单里有但进不去 / 一选就报错
echo       8. 修复启动菜单      重启没有菜单项，不用重装
echo       9. 清理安装残留      装到一半卡住 / 提前关窗口
echo      10. 清理残留盘符      多出一个 S: 之类的盘符
echo      11. 还原开机菜单      卸载后菜单还弹出来
echo.
echo.
echo       0. 看使用说明
echo       Q. 退出
echo.
set "c="
set /p "c=   请输入序号后回车: "
rem 去掉误输入的空格，否则 "1 " 会被判成无效
if defined c set "c=%c: =%"
if not defined c goto menu

if /i "%c%"=="0" goto doc
if /i "%c%"=="q" goto quit
if /i "%c%"=="1" goto s1
if /i "%c%"=="2" goto s2
if /i "%c%"=="3" goto s3
if /i "%c%"=="4" goto s4
if /i "%c%"=="5" goto s5
if /i "%c%"=="6" goto s6
if /i "%c%"=="7" goto s7
if /i "%c%"=="8" goto s8
if /i "%c%"=="9" goto s9
if /i "%c%"=="10" goto s10
if /i "%c%"=="11" goto s11

echo.
echo    输入无效，请重新选择。
pause
goto menu

:s1
set "T=双击我-装系统.bat"
goto run

:s2
set "T=双击我-卸载新系统.bat"
goto run

:s3
set "T=急救工具\新系统-诊断并装驱动.bat"
goto run

:s4
set "T=急救工具\新系统-清理幽灵显卡.bat"
goto run

:s5
set "T=急救工具\全量注入驱动-管理员运行.bat"
goto run

:s6
set "T=急救工具\注入网卡驱动-管理员运行.bat"
goto run

:s7
set "T=急救工具\修好菜单指向-管理员运行.bat"
goto run

:s8
set "T=急救工具\修复启动菜单-管理员运行.bat"
goto run

:s9
set "T=急救工具\清理安装残留-管理员运行.bat"
goto run

:s10
set "T=急救工具\清理ESP盘符-管理员运行.bat"
goto run

:s11
set "T=急救工具\还原启动菜单-管理员运行.bat"
goto run

:run
if not exist "%~dp0%T%" goto missing
call "%~dp0%T%"
goto back

:missing
echo.
echo    [错误] 找不到 "%~dp0%T%"
echo           请确认整个「虚拟硬盘系统」文件夹是完整复制的，
echo           不要只拷根目录这几个文件。
goto back

:back
echo.
echo   ------------------------------------------------------------
pause
goto menu

:doc
if not exist "%~dp0USER-GUIDE.md" goto nodoc
start "" notepad "%~dp0USER-GUIDE.md"
goto menu
:nodoc
echo.
echo    [提示] USER-GUIDE.md 不在这个文件夹里。
pause
goto menu

:quit
endlocal
exit /b 0
