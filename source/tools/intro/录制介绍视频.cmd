@echo off
setlocal
pushd "%~dp0"
set "REC_PY=%~dp0..\..\..\work\voice-env\Scripts\python.exe"
if exist "%REC_PY%" (
    "%REC_PY%" -X utf8 record.py %*
) else (
    py -3 -X utf8 record.py %*
)
set "REC_EXIT=%ERRORLEVEL%"
popd
if not "%REC_EXIT%"=="0" pause
exit /b %REC_EXIT%
