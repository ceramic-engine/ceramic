@echo off
setlocal enabledelayedexpansion

:: Check if all arguments are provided
if "%~3"=="" (
    echo Usage: %0 ^<path-to-android-sdk^> ^<path-to-android-ndk^> ^<path-to-jnilibs-folder^>
    exit /b 1
)

set "SDK_PATH=%~1"
set "NDK_PATH=%~2"
set "JNILIBS_PATH=%~3"

:: Check if paths exist
if not exist "%SDK_PATH%" (
    echo Error: Android SDK path does not exist: %SDK_PATH%
    exit /b 1
)

if not exist "%NDK_PATH%" (
    echo Error: Android NDK path does not exist: %NDK_PATH%
    exit /b 1
)

if not exist "%JNILIBS_PATH%" (
    echo Error: jniLibs path does not exist: %JNILIBS_PATH%
    exit /b 1
)

:: Find adb in the SDK
set "ADB=%SDK_PATH%\platform-tools\adb.exe"
if not exist "!ADB!" (
    echo Error: Could not find adb at !ADB!
    echo Please make sure the Android SDK platform-tools are installed.
    exit /b 1
)

:: Find ndk-stack in the provided NDK path
set "NDK_STACK=%NDK_PATH%\ndk-stack.exe"
if not exist "!NDK_STACK!" (
    :: Check prebuilt directories if not in root
    if exist "%NDK_PATH%\prebuilt\windows-x86_64\bin\ndk-stack.exe" (
        set "NDK_STACK=%NDK_PATH%\prebuilt\windows-x86_64\bin\ndk-stack.exe"
    ) else if exist "%NDK_PATH%\prebuilt\windows\bin\ndk-stack.exe" (
        set "NDK_STACK=%NDK_PATH%\prebuilt\windows\bin\ndk-stack.exe"
    )
)

if not exist "!NDK_STACK!" (
    echo Error: Could not find ndk-stack.exe in the provided NDK path: %NDK_PATH%
    echo Please verify the NDK path and make sure ndk-stack.exe is available.
    exit /b 1
)

:: Get device ABI
for /f "tokens=*" %%a in ('"%ADB%" shell getprop ro.product.cpu.abi') do set DEVICE_ABI=%%a
if "%DEVICE_ABI%"=="" (
    echo Error: Could not determine device architecture.
    echo Please make sure a device is connected.
    exit /b 1
)

echo Detected device architecture: %DEVICE_ABI%

:: Check if we have symbols for this architecture
if exist "%JNILIBS_PATH%\%DEVICE_ABI%" (
    set "SYMBOLS_PATH=%JNILIBS_PATH%\%DEVICE_ABI%"
    echo Using symbols from: !SYMBOLS_PATH!
) else (
    echo Warning: No symbols found for architecture %DEVICE_ABI%

    :: Check for arm64-v8a first
    if exist "%JNILIBS_PATH%\arm64-v8a" (
        set "SYMBOLS_PATH=%JNILIBS_PATH%\arm64-v8a"
        echo Falling back to arm64-v8a: !SYMBOLS_PATH!
    :: Then check for other common architectures
    ) else if exist "%JNILIBS_PATH%\armeabi-v7a" (
        set "SYMBOLS_PATH=%JNILIBS_PATH%\armeabi-v7a"
        echo Falling back to armeabi-v7a: !SYMBOLS_PATH!
    ) else if exist "%JNILIBS_PATH%\x86_64" (
        set "SYMBOLS_PATH=%JNILIBS_PATH%\x86_64"
        echo Falling back to x86_64: !SYMBOLS_PATH!
    ) else if exist "%JNILIBS_PATH%\x86" (
        set "SYMBOLS_PATH=%JNILIBS_PATH%\x86"
        echo Falling back to x86: !SYMBOLS_PATH!
    ) else (
        echo Error: No architecture folders found in %JNILIBS_PATH%
        echo Available contents:
        dir "%JNILIBS_PATH%"
        exit /b 1
    )
)

echo Using adb: %ADB%
echo Using ndk-stack: %NDK_STACK%
echo Starting continuous crash log monitoring...
echo Press Ctrl+C to stop.

:: Clear logcat buffer
"%ADB%" logcat -c

:: Continuously monitor logcat and pipe directly to ndk-stack
"%ADB%" logcat | "%NDK_STACK%" -sym "%SYMBOLS_PATH%"