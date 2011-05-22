@echo off
:: Win32 wrapper using tools from the msysgit install
setlocal
for %%f in (git.cmd) do set GIT_HOME=%%~dp$PATH:f
::echo %GIT_HOME%
:: Unfortunately msysgit only bundles perl 5.8.8 and no Pod::Usage
"%GIT_HOME%\..\bin\perl.exe" %~dpn0 %*
