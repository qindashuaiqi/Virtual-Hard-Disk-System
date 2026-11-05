@echo off
setlocal
chcp 437 >nul 2>&1
title Virtual Hard Disk System  -  connectsegabot
cd /d "%~dp0"

:menu
cls
echo.
echo    ============================================================
echo       Virtual Hard Disk System   author: connectsegabot
echo    ============================================================
echo.
echo    [Main]
echo       1. Install a system       as many as you like, name and folder are yours
echo       2. Uninstall a system     delete one virtual system by name
echo.
echo    [After installing / inside the new system]
echo       3. Diagnose and install drivers    devices still show a warning sign
echo       4. GPU check-up                    an extra empty GPU / ghost records
echo       5. Inject all drivers              Device Manager full of unknown devices
echo       6. Inject network drivers          just no network (network drivers only)
echo.
echo    [When something goes wrong / from the original system]
echo       7. Fix boot entry target   listed but will not boot / error on selection
echo       8. Repair boot menu        no menu after reboot, no need to reinstall
echo       9. Clean install residue   install hung / window closed early
echo      10. Clean leftover letter   an extra S: style drive appears
echo      11. Restore boot menu       the menu still pops up after uninstalling
echo.
echo.
echo       0. Open the user guide
echo       Q. Quit
echo.
set "c="
set /p "c=   Enter a number and press Enter: "
rem Strip mistyped spaces, otherwise "1 " is judged invalid
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
echo    Invalid choice, please try again.
pause
goto menu

:s1
set "T=Install-System.bat"
goto run

:s2
set "T=Uninstall-System.bat"
goto run

:s3
set "T=tools\Diagnose-And-Install-Drivers.bat"
goto run

:s4
set "T=tools\Clean-Ghost-GPU.bat"
goto run

:s5
set "T=tools\Inject-All-Drivers.bat"
goto run

:s6
set "T=tools\Inject-Network-Drivers.bat"
goto run

:s7
set "T=tools\Fix-Boot-Entry-Device.bat"
goto run

:s8
set "T=tools\Repair-Boot-Menu.bat"
goto run

:s9
set "T=tools\Clean-Install-Residue.bat"
goto run

:s10
set "T=tools\Clean-Esp-DriveLetter.bat"
goto run

:s11
set "T=tools\Restore-Boot-Menu.bat"
goto run

:run
if not exist "%~dp0%T%" goto missing
call "%~dp0%T%"
goto back

:missing
echo.
echo    [ERROR] Cannot find "%~dp0%T%"
echo            Copy the whole "en" folder, not just these few files
echo            from the root.
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
echo    [INFO] USER-GUIDE.md is not in this folder.
pause
goto menu

:quit
endlocal
exit /b 0
