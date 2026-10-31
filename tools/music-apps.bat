@echo off
rem Scan music generation apps and related software, then create and open
rem an HTML report (music apps list) on the desktop. Read-only: nothing is changed or deleted.
rem Requires Python 3.12 or later.
chcp 65001 >NUL
set "PYTHONPATH=%~dp0..\src;%PYTHONPATH%"
set "PY=python"
where py >NUL 2>NUL
if not errorlevel 1 set "PY=py -3"
%PY% -m cleaner.musicapps --open %*
echo.
pause
