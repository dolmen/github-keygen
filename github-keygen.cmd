@echo off
:: Win32 wrapper using tools from the msysgit install
setlocal
:: Add %GIT_HOME% to %PATH%: this should provide perl.exe and ssh-keygen.exe
:: Unfortunately msysgit only bundles perl 5.8.8 and no Pod::Usage
:: See https://github.com/msysgit/msysgit/issues/61
for %%f in (git.cmd) do for /D %%i in ("%%~dp$PATH:f..\bin") do path %PATH%;%%~fi
::echo %PATH%
perl %~dpn0 %*
