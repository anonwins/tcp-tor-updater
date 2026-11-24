@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$version = (Get-Date).ToString('yyyy.MM.dd.0');" ^
  "ps2exe .\tcp-tor-updater.ps1 .\tcp-tor-updater.exe -icon .\tcp-tor-updater.ico -x64 -conHost -title 'TCP TOR Updater' -description 'TOR Updater for Tor Control Panel on Windows' -company 'Unofficial' -product 'TCP_TOR_UPDATER' -version $version;" ^
  "Write-Host ''; Write-Host 'Build complete: version' $version"
pause
