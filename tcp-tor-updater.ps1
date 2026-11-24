# Tor Control Panel Updater Script
# Downloads and updates Tor files for Tor Control Panel bundle

# Script version
$ScriptVersion = "1.0.1"

# Directory containing this script.
function Get-ScriptPath {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($PSCommandPath) { return (Split-Path -Parent $PSCommandPath) }
    throw "Could not determine script directory"
}

# Function to find TorControlPanel.exe and return its directory path
function Find-TorControlPanelPath {
    $defaultPath = "C:\Program Files\TorControlPanel"
    $tcpExePath = Join-Path $defaultPath "TorControlPanel.exe"
    
    if (Test-Path $tcpExePath) {
        return $defaultPath
    }
    
    $scriptPath = Get-ScriptPath
    $localTcpExePath = Join-Path $scriptPath "TorControlPanel.exe"
    
    if (Test-Path $localTcpExePath) {
        return $scriptPath
    }
    
    throw "TorControlPanel.exe not found in $defaultPath or $scriptPath"
}

# Function to get the current local Tor version
function Get-CurrentTorVersion {
    param([string]$TcpPath)

    $torExePath = Join-Path $TcpPath "Tor\tor.exe"
    $versionOutput = & $torExePath "--version" 2>&1
    $versionString = $versionOutput -join "`n"

    if ($versionString -match "Tor version ([\d\.]+)") {
        return $Matches[1]
    }
    throw "Could not parse version from tor --version output"
}

# Function to get the latest Tor daemon version and archive URL
function Get-LatestTorInfo {
    $url = "https://www.torproject.org/download/tor/"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $htmlContent = $response.Content

        # Current page lists expert bundles in a table:
        #   href="https://dist.torproject.org/torbrowser/15.0.23/tor-expert-bundle-windows-i686-15.0.23.tar.gz"
        #   header: 15.0.23 (tor 0.4.9.12) Stable
        $pattern = 'href="([^"]*tor-expert-bundle-windows-i686-([^"/]+)\.tar\.gz)"'
        $linkMatches = [regex]::Matches($htmlContent, $pattern)
        $candidates = @()

        foreach ($linkMatch in $linkMatches) {
            $downloadUrl = $linkMatch.Groups[1].Value
            $bundleVersion = $linkMatch.Groups[2].Value

            # Skip signatures (already excluded) and alpha/rc builds such as 16.0a11
            if ($bundleVersion -match '[A-Za-z]') { continue }

            if ($downloadUrl -notmatch '^https?://') {
                $downloadUrl = [Uri]::new([Uri]$url, $downloadUrl).AbsoluteUri
            }

            $daemonVersion = $null
            $headerPattern = [regex]::Escape($bundleVersion) + '.{0,80}\(tor\s+([\d\.]+)\)'
            $headerMatch = [regex]::Match($htmlContent, $headerPattern)
            if ($headerMatch.Success) {
                $daemonVersion = $headerMatch.Groups[1].Value
            }

            $candidates += [pscustomobject]@{
                BundleVersion = $bundleVersion
                DaemonVersion = $daemonVersion
                DownloadUrl   = $downloadUrl
            }
        }

        if ($candidates.Count -eq 0) {
            throw "No Tor download links found"
        }

        $latest = $candidates |
            Sort-Object -Property @{ Expression = { [version]$_.BundleVersion }; Descending = $true } -Unique |
            Select-Object -First 1

        if (-not $latest.DaemonVersion) {
            $cardMatch = [regex]::Match($htmlContent, '(?i)(?:class="card-title"[^>]*>)?Tor\s+([\d\.]+)')
            if ($cardMatch.Success) {
                $latest.DaemonVersion = $cardMatch.Groups[1].Value
            }
        }

        if (-not $latest.DaemonVersion) {
            throw "Could not parse Tor daemon version"
        }

        return @{
            DaemonVersion = $latest.DaemonVersion
            DownloadUrl   = $latest.DownloadUrl
        }
    }
    catch {
        throw "Failed to fetch latest Tor info: $_"
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check if Tor Control Panel is running
function Test-TorControlPanelRunning {
    return (Get-Process -Name "TorControlPanel" -ErrorAction SilentlyContinue).Count -gt 0
}

# Function to wait for Tor Control Panel to close
function Wait-TorControlPanelClosed {
    Write-Host ""
    Write-Host "Tor Control Panel is running. Close it to continue." -ForegroundColor Yellow
    Write-Host "Press Enter when ready..." -ForegroundColor Cyan
    Read-Host
    
    while (Test-TorControlPanelRunning) {
        Write-Host "Tor Control Panel is still running. Please close it." -ForegroundColor Red
        Read-Host
    }
    Write-Host "OK, continuing..." -ForegroundColor Green
}

# Function to download a file
function Get-TorFile {
    param([string]$Url, [string]$OutputPath)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
}

# Function to extract a tar.gz file
function Expand-TorArchive {
    param([string]$TarGzPath, [string]$ExtractPath)
    
    if (-not (Test-Path $ExtractPath)) {
        New-Item -ItemType Directory -Path $ExtractPath | Out-Null
    }
    
    & tar -xzf $TarGzPath -C $ExtractPath
    if ($LASTEXITCODE -ne 0) {
        throw "tar extraction failed"
    }
}

# Function to apply the Tor update
function Install-TorUpdate {
    param([string]$ExtractPath, [string]$TcpPath)

    $sourceTorDir = Join-Path $ExtractPath "tor"
    $sourceDataDir = Join-Path $ExtractPath "data"
    $destTorDir = Join-Path $TcpPath "Tor"
    $destDataDir = Join-Path $TcpPath "Data"

    if (-not (Test-Path $destTorDir)) { New-Item -ItemType Directory -Path $destTorDir -Force | Out-Null }
    if (-not (Test-Path $destDataDir)) { New-Item -ItemType Directory -Path $destDataDir -Force | Out-Null }

    $filesToCopy = @(
        @{ Source = Join-Path $sourceTorDir "tor.exe"; Dest = Join-Path $destTorDir "tor.exe" },
        @{ Source = Join-Path $sourceTorDir "tor-gencert.exe"; Dest = Join-Path $destTorDir "tor-gencert.exe" },
        @{ Source = Join-Path $sourceDataDir "geoip"; Dest = Join-Path $destDataDir "geoip" },
        @{ Source = Join-Path $sourceDataDir "geoip6"; Dest = Join-Path $destDataDir "geoip6" }
    )

    foreach ($file in $filesToCopy) {
        if (Test-Path $file.Source) {
            Copy-Item -Path $file.Source -Destination $file.Dest -Force
            Write-Host "      Updated $(Split-Path $file.Dest -Leaf)" -ForegroundColor Green
        }
    }

    $sourcePluggableDir = Join-Path $sourceTorDir "pluggable_transports"
    $destPluggableDir = Join-Path $destTorDir "Pluggable_Transports"

    if (Test-Path $sourcePluggableDir) {
        if (-not (Test-Path $destPluggableDir)) {
            New-Item -ItemType Directory -Path $destPluggableDir -Force | Out-Null
        }
        Get-ChildItem -Path $sourcePluggableDir -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $destPluggableDir $_.Name) -Force
            Write-Host "      Updated Pluggable_Transports\$($_.Name)" -ForegroundColor Green
        }
    }
}

# Function to exit with key press
function Exit-Script {
    param([int]$ExitCode = 0)
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit $ExitCode
}

# === MAIN SCRIPT ===
Write-Host ""
Write-Host "Tor Control Panel Updater v$ScriptVersion" -ForegroundColor Cyan
Write-Host ("=" * 35) -ForegroundColor Cyan
Write-Host ""

try {
    # Step 1: Find Tor Control Panel
    Write-Host "[1/5] Locating Tor Control Panel..." -ForegroundColor Gray
    $TcpPath = Find-TorControlPanelPath
    Write-Host "      Found at: $TcpPath" -ForegroundColor Green

    # Step 2: Check admin privileges
    if (-not (Test-Administrator)) {
        Write-Host "[!] Administrator required, elevating..." -ForegroundColor Yellow
        
        try {
            if (-not $PSCommandPath) {
                throw "Could not determine script path"
            }
            Start-Process -FilePath "powershell.exe" -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath
            ) -Verb RunAs
            exit 0
        }
        catch {
            Write-Host "      ERROR: Elevation failed" -ForegroundColor Red
            Write-Host "      Please run as Administrator" -ForegroundColor Yellow
            Exit-Script -ExitCode 1
        }
    }

    # Step 3: Check current version
    Write-Host ""
    Write-Host "[2/5] Checking installed Tor version..." -ForegroundColor Gray
    try {
        $currentVersion = Get-CurrentTorVersion -TcpPath $TcpPath
        Write-Host "      Current version: $currentVersion" -ForegroundColor Green
    } catch {
        Write-Host "      Warning: Could not detect current version" -ForegroundColor Yellow
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "      Continue anyway? (Y/N): " -ForegroundColor Cyan -NoNewline
        if ((Read-Host) -notmatch "^[Yy]$") {
            Write-Host "      Cancelled" -ForegroundColor Yellow
            Exit-Script -ExitCode 0
        }
        $currentVersion = $null
    }

    # Step 4: Check for updates
    Write-Host ""
    Write-Host "[3/5] Checking for updates..." -ForegroundColor Gray
    $torInfo = Get-LatestTorInfo
    Write-Host "      Latest version: $($torInfo.DaemonVersion)" -ForegroundColor Green

    if ($currentVersion -and ($currentVersion -eq $torInfo.DaemonVersion)) {
        Write-Host ""
        Write-Host "[OK] You already have the latest version ($currentVersion)" -ForegroundColor Green
        Exit-Script -ExitCode 0
    }

    # Show update info and ask
    Write-Host ""
    Write-Host "Update available: $currentVersion -> $($torInfo.DaemonVersion)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download and install? (Y/N): " -ForegroundColor Cyan -NoNewline
    if ((Read-Host) -notmatch "^[Yy]$") {
        Write-Host "      Cancelled" -ForegroundColor Yellow
        Exit-Script -ExitCode 0
    }

    # Step 5: Download
    Write-Host ""
    Write-Host "[4/5] Downloading Tor $($torInfo.DaemonVersion)..." -ForegroundColor Gray
    $tempDir = [System.IO.Path]::GetTempPath()
    $downloadPath = Join-Path $tempDir "tor-update.tar.gz"
    $extractPath = Join-Path $tempDir "tor-update-extracted"

    try {
        if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

        Get-TorFile -Url $torInfo.DownloadUrl -OutputPath $downloadPath
        Write-Host "      Downloaded successfully" -ForegroundColor Green

        if (Test-TorControlPanelRunning) {
            Wait-TorControlPanelClosed
        }

        # Step 6: Install
        Write-Host ""
        Write-Host "[5/5] Installing update..." -ForegroundColor Gray
        Expand-TorArchive -TarGzPath $downloadPath -ExtractPath $extractPath
        Install-TorUpdate -ExtractPath $extractPath -TcpPath $TcpPath

        # Clean up
        Remove-Item $downloadPath, $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "[SUCCESS] Tor updated to $($torInfo.DaemonVersion)" -ForegroundColor Green
        Exit-Script -ExitCode 0

    } catch {
        Write-Host "      ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
        Exit-Script -ExitCode 1
    }

} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Exit-Script -ExitCode 1
}
