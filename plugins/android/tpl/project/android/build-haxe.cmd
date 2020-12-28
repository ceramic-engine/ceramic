@echo off

cd %~dp0
cd ..
cd ..

call ceramic luxe assets android --no-colors
if %errorlevel% neq 0 exit /b %errorlevel%

call ceramic luxe build android --no-colors --setup %*
if %errorlevel% neq 0 exit /b %errorlevel%

cd project
cd android
