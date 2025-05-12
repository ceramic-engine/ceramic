@echo off
setlocal enabledelayedexpansion

:: Check if correct number of arguments is provided
if "%~2"=="" (
    echo Usage: %0 path\to\file_to_patch.java path\to\patch_file.patch
    exit /b 1
)

set FILE_TO_PATCH=%~1
set PATCH_FILE=%~2

:: Check if the files exist
if not exist "%FILE_TO_PATCH%" (
    echo Error: File to patch '%FILE_TO_PATCH%' not found!
    exit /b 1
)

if not exist "%PATCH_FILE%" (
    echo Error: Patch file '%PATCH_FILE%' not found!
    exit /b 1
)

:: Create a backup of the original file
copy "%FILE_TO_PATCH%" "%FILE_TO_PATCH%.bak" > nul

:: Apply the patch with -p1 to strip the first path component (typical for git patches)
:: --binary ensures proper handling of line endings on Windows
:: --ignore-whitespace ignores whitespace changes
:: --no-backup-if-mismatch prevents creating reject files
:: -f forces the patch to apply even if the file doesn't match exactly
patch -p1 -f --binary --ignore-whitespace --no-backup-if-mismatch "%FILE_TO_PATCH%" < "%PATCH_FILE%"

:: Check if patch was applied successfully
if %ERRORLEVEL% EQU 0 (
    echo Patch applied successfully to %FILE_TO_PATCH%
    del "%FILE_TO_PATCH%.bak" > nul
    exit /b 0
) else (
    echo Failed to apply patch. Restoring original file.
    move /y "%FILE_TO_PATCH%.bak" "%FILE_TO_PATCH%" > nul
    exit /b 1
)

