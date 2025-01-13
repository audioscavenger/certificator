@echo off
@set PATH=%~dp0bin;%PATH%

title Win64 OpenSSL Command Prompt
echo Win64 OpenSSL Command Prompt
echo.
openssl version -a
echo.

pushd %~dp0

cmd.exe /K
