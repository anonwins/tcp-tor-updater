# TCP TOR Updater

Unofficial Windows updater for the Tor files shipped with [Tor Control Panel](https://github.com/abysshint/tor-control-panel).

Tor Control Panel is a GUI for the Tor Expert Bundle. This tool is separate from that project. It checks the installed `tor.exe`, downloads the current stable Windows expert bundle, and replaces the Tor binaries, GeoIP files, and pluggable transports in that install.

## Download

[v1.0.1](https://github.com/anonwins/tcp-tor-updater/releases/tag/v1.0.1) — `tcp-tor-updater.exe`

## Usage

Put `tcp-tor-updater.exe` next to `TorControlPanel.exe`, or run it when Tor Control Panel is installed in `C:\Program Files\TorControlPanel`. It asks for administrator rights, then:

1. Finds Tor Control Panel
2. Reads the installed Tor version from `Tor\tor.exe`
3. Looks up the latest stable Windows expert bundle
4. Asks before downloading
5. Copies `tor.exe`, `tor-gencert.exe`, `geoip`, `geoip6`, and the pluggable transports into the Tor Control Panel folders

Close Tor Control Panel before the files are replaced. The updater waits if it is still running.

## Build

From `src`, with [ps2exe](https://github.com/MScholtes/PS2EXE) installed:

```bat
make.bat
```

That writes `src\tcp-tor-updater.exe`. The script is `src\tcp-tor-updater.ps1`.
