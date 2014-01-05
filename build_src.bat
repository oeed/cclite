@echo off
set /P version=Enter version (Format: x.y.z): 
cd src\
7z a -r -tzip -mx5 "..\cclite-beta-%version%.love" ".\*"
cd ..\
pause
