# TCP TOR Updater

Unofficial Windows updater for the Tor files shipped with [Tor Control Panel](https://github.com/abysshint/tor-control-panel).

Tor Control Panel is a GUI for the Tor Expert Bundle. This tool is separate from that project. It checks the installed `tor.exe`, downloads the current stable Windows expert bundle, and replaces the Tor binaries, GeoIP files, and pluggable transports in that install.

## Run

Double-click `src\tcp-tor-updater.bat`. It starts the script with execution policy bypass, so Windows does not need a `.ps1` file association.

Or run the script directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\tcp-tor-updater.ps1
```

The script looks for Tor Control Panel in `C:\Program Files\TorControlPanel`, then in the same folder as `tcp-tor-updater.ps1`. For a portable copy, put `tcp-tor-updater.bat` and `tcp-tor-updater.ps1` next to `TorControlPanel.exe`.

It asks for administrator rights, then:

1. Finds Tor Control Panel
2. Reads the installed Tor version from `Tor\tor.exe`
3. Looks up the latest stable Windows expert bundle
4. Asks before downloading
5. Copies `tor.exe`, `tor-gencert.exe`, `geoip`, `geoip6`, and the pluggable transports into the Tor Control Panel folders

Close Tor Control Panel before the files are replaced. The updater waits if it is still running.
