@echo off
rem Run one testbench with Vivado xsim from the command line.
rem Usage (in a console where Vivado settings64.bat has been called):  sim\run_xsim.bat tb_physics
setlocal
set TB=%1
if "%TB%"=="" set TB=tb_physics
set R=%~dp0..
if not exist "%~dp0work_xsim" mkdir "%~dp0work_xsim"
cd /d "%~dp0work_xsim"
copy /y "%R%\rtl\*.mem" . >nul
copy /y "%R%\sim\*.mem" . >nul
call xvlog -i "%R%\rtl" -i "%R%\sim" "%R%\rtl\top.v" "%R%\rtl\tick_gen.v" "%R%\rtl\game_core.v" "%R%\rtl\map_rom.v" "%R%\rtl\input_sync.v" "%R%\rtl\led_gauge.v" "%R%\rtl\servo_pwm.v" "%R%\rtl\trig_rom.v" "%R%\rtl\trig_taylor.v" "%R%\rtl\packet_tx.v" "%R%\rtl\uart_tx.v" "%R%\sim\%TB%.v"
if errorlevel 1 exit /b 1
call xelab %TB% -s %TB%_snap
if errorlevel 1 exit /b 1
call xsim %TB%_snap -R
