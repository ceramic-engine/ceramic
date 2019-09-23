
@echo off
SET PATH=%~dp0;%PATH%
SET PATH=%~dp0/../git/haxe-binary/windows/neko;%PATH%
SET PATH=%~dp0/../git/haxe-binary/windows/haxe;%PATH%
%~dp0/../git/haxe-binary/windows/neko/neko %*
