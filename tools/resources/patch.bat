@echo off
setlocal enabledelayedexpansion

:: Check if correct number of arguments is provided
if "%~2"=="" (
    echo Usage: %0 path\to\file_to_patch.java path\to\patch_file.patch
    exit /b 1
)

set "FILE_TO_PATCH=%~1"
set "PATCH_FILE=%~2"
set "BACKUP_FILE=%FILE_TO_PATCH%.bak"

echo File to patch: %FILE_TO_PATCH%
echo Patch file: %PATCH_FILE%

:: Check if the files exist
if not exist "%FILE_TO_PATCH%" (
    echo Error: File to patch '%FILE_TO_PATCH%' not found!
    exit /b 1
)

if not exist "%PATCH_FILE%" (
    echo Error: Patch file '%PATCH_FILE%' not found!
    exit /b 1
)

:: Find Git's patch executable
set "PATCH_EXE="

:: Look for patch in common Git locations
for %%p in (
    "C:\Program Files\Git\usr\bin\patch.exe"
    "C:\Program Files (x86)\Git\usr\bin\patch.exe"
) do (
    if exist "%%~p" (
        set "PATCH_EXE=%%~p"
        echo Found patch at: !PATCH_EXE!
        goto :found_patch
    )
)

:: Check if git is in PATH and find patch relative to it
for %%i in (git.exe) do (
    if not "%%~$PATH:i"=="" (
        set "GIT_PATH=%%~dp$PATH:i"
        if exist "!GIT_PATH!..\usr\bin\patch.exe" (
            set "PATCH_EXE=!GIT_PATH!..\usr\bin\patch.exe"
            echo Found patch at: !PATCH_EXE!
            goto :found_patch
        )
    )
)

echo Error: patch.exe not found. Please make sure Git for Windows is installed.
exit /b 1

:found_patch
:: Apply the patch
echo Running patch command: "!PATCH_EXE!" -p1 -f --binary --ignore-whitespace --no-backup-if-mismatch "!FILE_TO_PATCH!" ^< "!PATCH_FILE!"
call "!PATCH_EXE!" -p1 -f --binary --ignore-whitespace --no-backup-if-mismatch "!FILE_TO_PATCH!" < "!PATCH_FILE!"

:: Check if patch was applied successfully
if %ERRORLEVEL% EQU 0 (
    echo Patch applied successfully to !FILE_TO_PATCH!

    :: Try to delete the backup file if it exists
    if exist "!BACKUP_FILE!" (
        del /F /Q "!BACKUP_FILE!" 2>nul
        if exist "!BACKUP_FILE!" echo Warning: Failed to delete backup file: !BACKUP_FILE!
    )

    exit /b 0
) else (
    echo Failed to apply patch. Attempting to restore original file.

    if exist "!BACKUP_FILE!" (
        echo Restoring from backup file...
        copy /Y "!BACKUP_FILE!" "!FILE_TO_PATCH!" > nul
        del /F /Q "!BACKUP_FILE!" 2>nul
    )

    exit /b 1
)