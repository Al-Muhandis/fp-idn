@echo off
setlocal
echo Building tests for fpidn and fppunycode...
echo.

REM Determine FreePascal compiler
if not defined FPC (
    for /f "delims=" %%i in ('where fpc 2^>nul') do set "FPC=%%i"
)
if not defined FPC (
    echo ERROR: FreePascal compiler (fpc) not found. Please install FPC and set the FPC environment variable.
    pause
    exit /b 1
)

REM Compile console test application
echo Compiling the console test application...
"%FPC%" ^
  -Mobjfpc -Scghi -O1 -g -gl -l -vewnhibq ^
  -Fu. -Fu..\ -FUlib\ ^
  tests\testconsole.lpr

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to compile the console application
    pause
    exit /b 1
)

echo Compilation successful!
echo.

REM Run tests
echo Running tests...
echo.
tests\testconsole.exe --all

echo.
echo Tests completed.
pause
