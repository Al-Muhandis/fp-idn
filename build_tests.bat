@echo off
echo Building tests for fpidn and fppunycode...
echo.

REM Determine FreePascal compiler
if "%FPC%"=="" (
    for /f "delims=" %%i in ('where fpc 2^>nul') do set "FPC=%%i"
)
if "%FPC%"=="" (
    echo ERROR: FreePascal compiler ^(fpc^) not found. Please install FPC and set the FPC environment variable.
    exit /b 1
)

REM Compile console test application
echo Compiling the console test application...
%FPC% ^
  -Mobjfpc -Scghi -O1 -g -gl -l -vewnhibq ^
  -Fu. -FUlib\ ^
  tests\testconsole.lpr

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to compile the console application
    exit /b %ERRORLEVEL%
)

echo Compilation successful!
echo.

REM Run tests; propagate the failure exit code so CI can detect it
echo Running tests...
echo.
tests\testconsole.exe --all
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Tests failed
    exit /b %ERRORLEVEL%
)

echo.
echo Tests completed.
