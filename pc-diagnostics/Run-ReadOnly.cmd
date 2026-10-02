@echo off
rem Honors the existing PowerShell execution policy. No elevation or policy change.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -File "%~dp0Check-Win11.ps1"
exit /b %ERRORLEVEL%
