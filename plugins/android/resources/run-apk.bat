@echo off
setlocal enabledelayedexpansion

:: Check if the correct number of arguments is provided
if "%~2"=="" (
    echo Usage: %0 ^<path_to_apk^> ^<path_to_android_sdk^>
    exit /b 1
)

set "APK_PATH=%~1"
set "SDK_PATH=%~2"

:: Check if APK file exists
if not exist "%APK_PATH%" (
    echo Error: APK file not found at %APK_PATH%
    exit /b 1
)

:: Check if Android SDK directory exists
if not exist "%SDK_PATH%" (
    echo Error: Android SDK not found at %SDK_PATH%
    exit /b 1
)

:: Set path to ADB
set "ADB=%SDK_PATH%\platform-tools\adb.exe"

:: Check if ADB exists
if not exist "%ADB%" (
    echo Error: adb not found at %ADB%
    exit /b 1
)

:: Check if device is connected
for /f "tokens=*" %%a in ('"%ADB%" devices ^| findstr /v "List" ^| findstr /v "^$" ^| find /c /v ""') do set DEVICE_CHECK=%%a
if %DEVICE_CHECK% EQU 0 (
    echo Error: No Android device connected via USB
    exit /b 1
)

:: Create a temporary file for logcat PID
set "TEMP_DIR=%TEMP%\android_runner_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul
set "LOGCAT_PID_FILE=%TEMP_DIR%\logcat_pid.txt"
set "OUTPUT_FILE=%TEMP_DIR%\logcat_output.txt"

:: Initialize variables
set "LOGCAT_PID="

echo Installing APK...
"%ADB%" install -r "%APK_PATH%"
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to install APK
    call :cleanup 1
    exit /b 1
)

:: Get package name and main activity from APK
echo Extracting package info...

:: Extract the APK basename
for %%i in ("%APK_PATH%") do set "APK_BASENAME=%%~nxi"

:: Get package name
for /f "tokens=* usebackq" %%a in (`"%ADB%" shell pm list packages -f ^| findstr "%APK_BASENAME%" ^| for /f "tokens=1 delims==" %%b in ("%%a") do @echo %%b`) do (
    set "TEMP_STR=%%a"
    set "PACKAGE_NAME=!TEMP_STR:*:=!"
)

:: If package name is not found, try using aapt
if "%PACKAGE_NAME%"=="" (
    :: Find the latest build-tools version
    for /f "tokens=* usebackq" %%a in (`dir /b /ad "%SDK_PATH%\build-tools" ^| sort`) do set "BUILD_TOOLS_VERSION=%%a"
    set "AAPT=%SDK_PATH%\build-tools\%BUILD_TOOLS_VERSION%\aapt.exe"

    if exist "%AAPT%" (
        for /f "tokens=2 delims=''" %%a in ('"%AAPT%" dump badging "%APK_PATH%" ^| findstr "package"') do set "PACKAGE_NAME=%%a"
        for /f "tokens=2 delims=''" %%a in ('"%AAPT%" dump badging "%APK_PATH%" ^| findstr "launchable-activity"') do set "LAUNCHER_ACTIVITY=%%a"
    )
)

if "%PACKAGE_NAME%"=="" (
    echo Error: Could not determine package name
    call :cleanup 1
    exit /b 1
)

if "%LAUNCHER_ACTIVITY%"=="" (
    :: Get the main activity using dumpsys
    for /f "tokens=2 usebackq" %%a in (`"%ADB%" shell cmd package resolve-activity --brief "%PACKAGE_NAME%" ^| findstr /v "No activity" ^| tail -1`) do set "LAUNCHER_ACTIVITY=%%a"

    :: If still not found, try alternative method
    if "%LAUNCHER_ACTIVITY%"=="" (
        for /f "tokens=* usebackq" %%a in (`"%ADB%" shell pm dump "%PACKAGE_NAME%" ^| findstr /c:"MAIN" /b -A 5 ^| findstr /r "%PACKAGE_NAME%/[^ ]*"`) do (
            set "LAUNCHER_ACTIVITY=%%a"
        )
    )

    :: Extract just the activity name if full path is returned
    if not "%LAUNCHER_ACTIVITY%"=="" (
        if "!LAUNCHER_ACTIVITY:%PACKAGE_NAME%=!" NEQ "!LAUNCHER_ACTIVITY!" (
            set "LAUNCHER_ACTIVITY=!LAUNCHER_ACTIVITY:%PACKAGE_NAME%/=!"
        )
    )
)

echo Package name: %PACKAGE_NAME%
echo Launcher activity: %LAUNCHER_ACTIVITY%

:: Clear logcat
"%ADB%" logcat -c

:: Start the app
echo Launching app...
if not "%LAUNCHER_ACTIVITY%"=="" (
    "%ADB%" shell am start -n "%PACKAGE_NAME%/%LAUNCHER_ACTIVITY%"
) else (
    "%ADB%" shell monkey -p "%PACKAGE_NAME%" -c android.intent.category.LAUNCHER 1
)

if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to launch app
    call :cleanup 1
    exit /b 1
)

echo App launched. Waiting for app to start...

:: Wait for app to start (give it time to launch)
set MAX_WAIT=30
set WAIT_COUNT=0

:wait_loop
call :is_app_running
if %ERRORLEVEL% NEQ 0 (
    set /a WAIT_COUNT+=1
    if !WAIT_COUNT! LSS %MAX_WAIT% (
        echo|set /p=.
        timeout /t 1 /nobreak >nul
        goto :wait_loop
    ) else (
        echo.
        echo Error: App did not start within %MAX_WAIT% seconds
        call :cleanup 1
        exit /b 1
    )
) else (
    echo.
)

:: Get the actual PID
for /f "tokens=* usebackq" %%a in (`"%ADB%" shell pidof "%PACKAGE_NAME%" ^| tr -d "\r"`) do set "APP_PID=%%a"
echo App is running with PID: %APP_PID%. Monitoring logs...

:: Print the log begin delimiter
echo ----------- LOGS BEGIN -----------

:: Create a temporary batch file to run logcat
set "LOGCAT_SCRIPT=%TEMP_DIR%\run_logcat.bat"
(
    echo @echo off
    echo "%ADB%" logcat ^| findstr /r "%PACKAGE_NAME%\|%APP_PID%"
) > "%LOGCAT_SCRIPT%"

:: Start logcat in the background with direct output to console
start /b cmd /c "%LOGCAT_SCRIPT%" 2>&1 | more
for /f "tokens=* usebackq" %%a in (`wmic process where "CommandLine like '%%run_logcat.bat%%'" get ProcessId /format:value`) do (
    set "LOGCAT_LINE=%%a"
    if "!LOGCAT_LINE:~0,10!"=="ProcessId=" (
        set "LOGCAT_PID=!LOGCAT_LINE:ProcessId=!"
        echo !LOGCAT_PID! > "%LOGCAT_PID_FILE%"
    )
)

:: Monitor app until it stops
set CONSECUTIVE_NOT_RUNNING=0
set REQUIRED_CONSECUTIVE=2

:monitor_loop
call :is_app_running
if %ERRORLEVEL% EQU 0 (
    set CONSECUTIVE_NOT_RUNNING=0
) else (
    set /a CONSECUTIVE_NOT_RUNNING+=1
)

if %CONSECUTIVE_NOT_RUNNING% LSS %REQUIRED_CONSECUTIVE% (
    timeout /t 1 /nobreak >nul
    goto :monitor_loop
)

:: Print the log end delimiter precisely matching the Unix version
echo ----------- LOGS END -----------
echo App has stopped running.

call :cleanup 0
exit /b 0

:is_app_running
:: Function to check if app is running
for /f "tokens=* usebackq" %%a in (`"%ADB%" shell pidof "%PACKAGE_NAME%" 2^>nul`) do set "PID_OUTPUT=%%a"
if "%PID_OUTPUT%"=="" (
    exit /b 1
) else (
    exit /b 0
)

:cleanup
:: Cleanup function
if exist "%LOGCAT_PID_FILE%" (
    set /p LOGCAT_PID=<"%LOGCAT_PID_FILE%"
    if not "%LOGCAT_PID%"=="" (
        taskkill /F /PID %LOGCAT_PID% 2>nul
    )
)

:: Kill any remaining cmd processes that might be running our scripts
for /f "tokens=* usebackq" %%a in (`wmic process where "CommandLine like '%%run_logcat.bat%%'" get ProcessId /format:value`) do (
    set "KILL_LINE=%%a"
    if "!KILL_LINE:~0,10!"=="ProcessId=" (
        set "KILL_PID=!KILL_LINE:ProcessId=!"
        taskkill /F /PID !KILL_PID! 2>nul
    )
)

:: Clean up temporary directory
if exist "%TEMP_DIR%" (
    rd /s /q "%TEMP_DIR%" 2>nul
)

exit /b %1