@echo off
echo Building tests for fpidn and fppunycode...
echo.

REM Compile console test application
echo Compiling the console test application...
C:\lazarus-4.0\fpc\bin\x86_64-win64\fpc.exe ^
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
