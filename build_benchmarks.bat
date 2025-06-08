@echo off
setlocal

echo Building benchmarks...

if not defined FPC (
    for /f "delims=" %%i in ('where fpc 2^>nul') do set "FPC=%%i"
)
if not defined FPC (
    echo ERROR: FreePascal compiler (fpc) not found. Please install FPC and set the FPC environment variable.
    pause
    exit /b 1
)

"%FPC%" ^
  -Mobjfpc -Scghi -O1 -g -gl -l -vewnhibq ^
  -Fu. -FUlib\ ^
  benchmarks\benchconsole.lpr

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to compile benchmarks
    pause
    exit /b 1
)

echo Running benchmarks...
benchmarks\benchconsole.exe

echo.
echo Benchmarks completed.
pause
