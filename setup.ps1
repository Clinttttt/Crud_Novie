<#
    Grocery Inventory System - one-command setup and run.

    Checks the three things this project needs (.NET SDK, Node.js, PostgreSQL), offers to
    install anything missing, works out the PostgreSQL password, installs the Angular
    packages the first time only, then starts the API and the web app and opens the browser.

    Safe to run again: anything already done is detected and skipped.

    Usage (from a terminal, or just double-click start.bat):
        powershell -ExecutionPolicy Bypass -File setup.ps1
        powershell -ExecutionPolicy Bypass -File setup.ps1 -SetupOnly   # prepare, do not run
        powershell -ExecutionPolicy Bypass -File setup.ps1 -NoBrowser   # run, do not open the browser
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SetupOnly,
    [switch]$NoBrowser,
    # Only needed if something else on your PC already uses port 4200.
    [int]$ClientPort = 4200
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$ApiProject = Join-Path $Root 'Grocery.Api'
$ClientDir = Join-Path $Root 'Grocery.Client'
# The API port is fixed because Grocery.Client/proxy.conf.json points at it.
$ApiPort = 5199
$DbName = 'grocerycrud'
$PgPort = 5432
$PgUser = 'postgres'

# ---------------------------------------------------------------------------- output helpers

function Write-Step { param([string]$Text) Write-Host "`n>> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "   [ok] $Text" -ForegroundColor Green }
function Write-Info { param([string]$Text) Write-Host "   $Text" -ForegroundColor Gray }
function Write-Note { param([string]$Text) Write-Host "   [!] $Text" -ForegroundColor Yellow }
function Write-Fail { param([string]$Text) Write-Host "   [x] $Text" -ForegroundColor Red }

function Stop-WithMessage {
    param([string]$Text, [string[]]$Hints)

    Write-Fail $Text
    foreach ($hint in $Hints) { Write-Host "       $hint" -ForegroundColor Yellow }
    exit 1
}

function Confirm-Action {
    param([string]$Question)

    while ($true) {
        $answer = Read-Host "   $Question [Y/n]"
        if ($answer -eq '' -or $answer -match '^(y|yes)$') { return $true }
        if ($answer -match '^(n|no)$') { return $false }
    }
}

# ---------------------------------------------------------------------------- small utilities

function Get-CommandPath {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

# A program installed a moment ago is not on PATH yet in this window, so read PATH again.
function Update-PathFromRegistry {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user | Where-Object { $_ }) -join ';'
}

function Install-WithWinget {
    param(
        [string]$Id,
        [string]$Label,
        [string]$Custom
    )

    if (-not (Get-CommandPath 'winget')) { return $false }

    Write-Info "Installing $Label with winget. Approve the Windows prompt if one appears."

    $wingetArgs = @(
        'install', '--id', $Id, '--exact', '--silent',
        '--accept-package-agreements', '--accept-source-agreements'
    )
    if ($Custom) { $wingetArgs += @('--custom', $Custom) }

    & winget @wingetArgs
    $installed = ($LASTEXITCODE -eq 0)

    if ($installed) {
        Update-PathFromRegistry
        Write-Ok "$Label installed."
    }
    else {
        Write-Note "winget could not install $Label (exit code $LASTEXITCODE)."
    }

    return $installed
}

function Test-Port {
    param([int]$Port)

    # Checked through the OS first: a dev server may listen on IPv6 (::1) only, which a
    # plain 127.0.0.1 connection would miss.
    $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listening) { return $true }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        # 'localhost' resolves to both IPv4 and IPv6, unlike a hardcoded address.
        $client.Connect('localhost', $Port)
        return $true
    }
    catch { return $false }
    finally { $client.Close() }
}

function Wait-ForPort {
    param(
        [int]$Port,
        [string]$Label,
        [int]$TimeoutSeconds = 180
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Port $Port) { return $true }
        Start-Sleep -Milliseconds 700
        Write-Host '.' -NoNewline -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Note "$Label did not start within $TimeoutSeconds seconds."
    return $false
}

# ---------------------------------------------------------------------------- prerequisites

function Assert-DotnetSdk {
    Write-Step 'Checking the .NET SDK'

    if (-not (Get-CommandPath 'dotnet')) {
        Write-Note 'The .NET SDK is not installed.'
        if (Confirm-Action 'Install the .NET 8 SDK now?') {
            Install-WithWinget -Id 'Microsoft.DotNet.SDK.8' -Label '.NET 8 SDK' | Out-Null
        }
    }

    if (-not (Get-CommandPath 'dotnet')) {
        Stop-WithMessage 'The .NET SDK is still not available.' @(
            'Install it from https://dotnet.microsoft.com/download/dotnet/8.0',
            'then close this window, open a new one, and run start.bat again.'
        )
    }

    $versions = @(& dotnet --list-sdks | ForEach-Object { ($_ -split ' ')[0] })
    $newest = 0
    foreach ($version in $versions) {
        $major = [int]($version -split '\.')[0]
        if ($major -gt $newest) { $newest = $major }
    }

    if ($newest -lt 8) {
        Stop-WithMessage "Found .NET SDK $newest, but this project needs 8 or newer." @(
            'Install it from https://dotnet.microsoft.com/download/dotnet/8.0'
        )
    }

    Write-Ok ".NET SDK $($versions -join ', ') detected."
}

function Assert-Node {
    Write-Step 'Checking Node.js'

    # The Angular version this project uses requires one of these Node lines.
    $isSupported = {
        param([string]$Raw)

        if ($Raw -notmatch '^v?(\d+)\.(\d+)\.(\d+)') { return $false }

        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]

        if ($major -eq 22) { return ($minor -gt 22) -or ($minor -eq 22 -and $patch -ge 3) }
        if ($major -eq 24) { return ($minor -ge 15) }
        if ($major -ge 26) { return $true }
        return $false
    }

    $version = ''
    if (Get-CommandPath 'node') { $version = (& node -v) }

    if (-not (& $isSupported $version)) {
        if ($version) {
            Write-Note "Node $version is too old for this project's Angular version."
        }
        else {
            Write-Note 'Node.js is not installed.'
        }

        if (Confirm-Action 'Install the current Node.js LTS now?') {
            Install-WithWinget -Id 'OpenJS.NodeJS.LTS' -Label 'Node.js LTS' | Out-Null
            if (Get-CommandPath 'node') { $version = (& node -v) }
        }
    }

    if (-not (& $isSupported $version)) {
        Stop-WithMessage 'Node.js 22.22.3+ or 24.15.0+ is required.' @(
            'Install the LTS build from https://nodejs.org',
            'then close this window, open a new one, and run start.bat again.'
        )
    }

    Write-Ok "Node $version detected."
}

function Assert-PostgresRunning {
    Write-Step 'Checking PostgreSQL'

    $service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $service -and -not (Test-Port $PgPort)) {
        Write-Note 'PostgreSQL does not look installed.'
        Write-Info "If the script installs it, the 'postgres' password will be set to: postgres"

        if (Confirm-Action 'Install PostgreSQL now?') {
            $custom = "--unattendedmodeui minimal --superpassword postgres --serverport $PgPort"
            $installed = $false
            foreach ($id in @('PostgreSQL.PostgreSQL.18', 'PostgreSQL.PostgreSQL.17', 'PostgreSQL.PostgreSQL.16')) {
                if (Install-WithWinget -Id $id -Label $id -Custom $custom) { $installed = $true; break }
            }
            if ($installed) {
                Start-Sleep -Seconds 5
                $service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        }
    }

    if ($service -and $service.Status -ne 'Running') {
        Write-Info "Starting the $($service.Name) service."
        try { Start-Service $service.Name; Start-Sleep -Seconds 3 }
        catch { Write-Note 'Could not start the service. Try running this script as administrator.' }
    }

    if (-not (Test-Port $PgPort)) {
        Stop-WithMessage "Nothing is listening on port $PgPort, so PostgreSQL is not running." @(
            'Install it from https://www.postgresql.org/download/ and keep port 5432,',
            'or open services.msc, find postgresql-x64-..., and start it.'
        )
    }

    Write-Ok "PostgreSQL is running on port $PgPort."
}

# ---------------------------------------------------------------------------- database password

function Get-PsqlPath {
    $path = Get-CommandPath 'psql'
    if ($path) { return $path }

    $found = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }

    return $null
}

function Test-PgLogin {
    param([string]$Psql, [string]$Password)

    $previous = $env:PGPASSWORD
    $env:PGPASSWORD = $Password
    try {
        & $Psql -h localhost -p $PgPort -U $PgUser -d postgres -tAc 'select 1' 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch { return $false }
    finally {
        if ($null -eq $previous) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
        else { $env:PGPASSWORD = $previous }
    }
}

function Get-ConfiguredPassword {
    # A password saved by an earlier run wins, because user secrets override appsettings.
    $secrets = & dotnet user-secrets list --project $ApiProject 2>&1
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $secrets) {
            if ($line -match 'ConnectionStrings:DefaultConnection\s*=\s*(.+)$' -and $Matches[1] -match 'Password=([^;]*)') {
                return $Matches[1]
            }
        }
    }

    $settingsPath = Join-Path $ApiProject 'appsettings.Development.json'
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $connection = $settings.ConnectionStrings.DefaultConnection
        if ($connection -match 'Password=([^;]*)') { return $Matches[1] }
    }

    return 'postgres'
}

function Save-Password {
    param([string]$Password)

    # Stored outside the repository, so a real password is never committed to GitHub.
    $connection = "Host=localhost;Port=$PgPort;Database=$DbName;Username=$PgUser;Password=$Password"
    & dotnet user-secrets set 'ConnectionStrings:DefaultConnection' $connection --project $ApiProject | Out-Null
    Write-Ok 'Password saved for this project (in your user secrets, not in the repository).'
}

function Read-PlainPassword {
    param([string]$Prompt)

    $secure = Read-Host "   $Prompt" -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Resolve-DatabasePassword {
    Write-Step 'Checking the database login'

    $psql = Get-PsqlPath
    $configured = Get-ConfiguredPassword

    if (-not $psql) {
        Write-Note 'psql.exe was not found, so the password cannot be checked in advance.'
        Write-Info 'If it is wrong, the API window will say: password authentication failed.'
        return
    }

    if (Test-PgLogin -Psql $psql -Password $configured) {
        Write-Ok "The configured password works for user '$PgUser'."
        return
    }

    Write-Note "The configured password does not work for user '$PgUser'."
    Write-Info 'This is the password you chose while installing PostgreSQL.'

    foreach ($attempt in 1..3) {
        $entered = Read-PlainPassword -Prompt "PostgreSQL password for '$PgUser' (attempt $attempt of 3)"

        if (Test-PgLogin -Psql $psql -Password $entered) {
            Write-Ok 'That password works.'
            Save-Password -Password $entered
            return
        }

        Write-Fail 'That password was rejected.'
    }

    Write-Note 'Continuing anyway. The API window will show the error if the login is wrong.'
    Write-Info 'You can also edit Grocery.Api/appsettings.Development.json by hand.'
}

# ---------------------------------------------------------------------------- build and packages

function Install-ClientPackages {
    Write-Step 'Checking the Angular packages'

    $modules = Join-Path $ClientDir 'node_modules'
    $lockFile = Join-Path $ClientDir 'package-lock.json'
    $needsInstall = $true

    if (Test-Path $modules) {
        $installedAt = (Get-Item $modules).LastWriteTime
        if ((Test-Path $lockFile) -and (Get-Item $lockFile).LastWriteTime -gt $installedAt) {
            Write-Info 'package-lock.json changed since the last install, installing again.'
        }
        else {
            $needsInstall = $false
        }
    }

    if (-not $needsInstall) {
        Write-Ok 'Packages are already installed, skipping npm install.'
        return
    }

    Write-Info 'Running npm install. The first time this takes a few minutes.'
    Push-Location $ClientDir
    try {
        & npm install
        if ($LASTEXITCODE -ne 0) {
            Stop-WithMessage 'npm install failed.' @(
                "Delete the folder $modules and run start.bat again."
            )
        }
    }
    finally { Pop-Location }

    Write-Ok 'Angular packages installed.'
}

function Build-Api {
    Write-Step 'Building the API'

    & dotnet build (Join-Path $Root 'GroceryCrud.sln') --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage 'The API did not compile.' @('Read the errors above.')
    }

    Write-Ok 'API compiled.'
}

# ---------------------------------------------------------------------------- run

function Start-InNewWindow {
    param(
        [string]$Title,
        [string]$WorkingDirectory,
        [string]$Command
    )

    # Each part runs in its own window so the logs stay visible and Ctrl+C stops it.
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/k', "title $Title && $Command" -WorkingDirectory $WorkingDirectory | Out-Null
}

function Get-PageText {
    param([string]$Url)

    try {
        return (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5).Content
    }
    catch { return '' }
}

function Start-Api {
    Write-Step 'Starting the API'

    if (Test-Port $ApiPort) {
        # Reuse it only if it really is this project's API, not some other program.
        if ((Get-PageText "http://localhost:$ApiPort/swagger/v1/swagger.json") -match '/api/products') {
            Write-Ok "This project's API is already running on port $ApiPort."
            return $true
        }

        Stop-WithMessage "Port $ApiPort is being used by another program." @(
            'Close whatever is using it and run start.bat again.',
            'It is usually an older API window that was never closed.'
        )
    }

    Start-InNewWindow -Title 'Grocery API' -WorkingDirectory $Root `
        -Command 'dotnet run --project Grocery.Api --launch-profile http'

    Write-Host '   waiting for the API' -NoNewline -ForegroundColor Gray
    if (-not (Wait-ForPort -Port $ApiPort -Label 'The API')) {
        Write-Info "Look at the 'Grocery API' window for the reason."
        return $false
    }

    Write-Host ''
    Write-Ok "API listening on http://localhost:$ApiPort (Swagger at /swagger)."
    return $true
}

function Start-Client {
    Write-Step 'Starting the web app'

    if (Test-Port $ClientPort) {
        # Matched on this app's own title, since any Angular app would contain <app-root>.
        if ((Get-PageText "http://localhost:$ClientPort/") -match 'Stockroom') {
            Write-Ok "This project's web app is already running on port $ClientPort."
            return $true
        }

        Stop-WithMessage "Port $ClientPort is being used by another program." @(
            'Close whatever is using it and run start.bat again,',
            "or pick another port:  start.bat -ClientPort 4300"
        )
    }

    # The port is passed explicitly so the dev server never quietly moves elsewhere.
    Start-InNewWindow -Title 'Grocery Web App' -WorkingDirectory $ClientDir `
        -Command "npm start -- --port $ClientPort"

    Write-Host '   waiting for the web app' -NoNewline -ForegroundColor Gray
    if (-not (Wait-ForPort -Port $ClientPort -Label 'The web app')) {
        Write-Info "Look at the 'Grocery Web App' window for the reason."
        return $false
    }

    Write-Host ''
    Write-Ok "Web app listening on http://localhost:$ClientPort."
    return $true
}

# ---------------------------------------------------------------------------- main

Write-Host ''
Write-Host '  Grocery Inventory System - setup and run' -ForegroundColor White
Write-Host '  ----------------------------------------' -ForegroundColor DarkGray

Assert-DotnetSdk
Assert-Node
Assert-PostgresRunning
Resolve-DatabasePassword
Install-ClientPackages
Build-Api

if ($SetupOnly) {
    Write-Host ''
    Write-Ok 'Setup finished. Run start.bat again to launch the app.'
    exit 0
}

$apiUp = Start-Api
$clientUp = Start-Client

Write-Host ''
if ($apiUp -and $clientUp) {
    if (-not $NoBrowser) {
        Write-Info 'Opening the app in your browser.'
        try { Start-Process "http://localhost:$ClientPort" | Out-Null }
        catch { Write-Note "Could not open the browser. Go to http://localhost:$ClientPort yourself." }
    }

    Write-Host '  Everything is running.' -ForegroundColor Green
    Write-Host "    Web app : http://localhost:$ClientPort" -ForegroundColor White
    Write-Host "    API     : http://localhost:$ApiPort/swagger" -ForegroundColor White
    Write-Host ''
    Write-Host '  To stop: close the "Grocery API" and "Grocery Web App" windows,' -ForegroundColor Gray
    Write-Host '  or press Ctrl+C in each of them.' -ForegroundColor Gray
}
else {
    Write-Note 'Not everything started. Check the two windows that opened.'
    exit 1
}

Write-Host ''
