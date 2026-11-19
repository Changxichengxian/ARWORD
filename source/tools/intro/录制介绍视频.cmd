@echo off
setlocal
set "REC_PY=%~dp0..\..\..\work\voice-env\Scripts\python.exe"
if exist "%REC_PY%" (
    "%REC_PY%" -X utf8 "%~dp0record.py" %*
) else (
    py -3 -X utf8 "%~dp0record.py" %*
)
set "REC_EXIT=%ERRORLEVEL%"
if not "%REC_EXIT%"=="0" pause
exit /b %REC_EXIT%
