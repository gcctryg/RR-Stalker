param(
    [string]$Shard = "na",
    [string]$LockfilePath = "",
    [string]$HostAddress = "",
    [int]$BridgePort = 0,
    [switch]$PrintTokens
)

$ErrorActionPreference = "Stop"

function Get-RiotClientLockfilePath {
    param([string]$ExplicitPath)

    $candidates = @()

    if ($ExplicitPath) {
        $candidates += $ExplicitPath
    }

    $candidates += @(
        "C:\Riot Games\Riot Client\Config\lockfile",
        (Join-Path $env:LOCALAPPDATA "Riot Games\Riot Client\Config\lockfile"),
        (Join-Path $env:PROGRAMDATA "Riot Games\Riot Client\Config\lockfile")
    )

    $installsPath = Join-Path $env:PROGRAMDATA "Riot Games\RiotClientInstalls.json"
    if (Test-Path -LiteralPath $installsPath) {
        try {
            $installs = Get-Content -LiteralPath $installsPath -Raw | ConvertFrom-Json
            foreach ($property in $installs.PSObject.Properties) {
                if ($property.Name -like "rc_*" -and $property.Value) {
                    $candidates += (Join-Path (Split-Path -Parent $property.Value) "Config\lockfile")
                }
            }
        } catch {
            Write-Warning "Could not read RiotClientInstalls.json: $($_.Exception.Message)"
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

$resolvedLockfilePath = Get-RiotClientLockfilePath -ExplicitPath $LockfilePath

if (-not $resolvedLockfilePath) {
    throw "Riot Client lockfile was not found. Start Riot Client, log in, then try again. To locate it manually, run: Get-ChildItem -Path C:\,`$env:LOCALAPPDATA,`$env:PROGRAMDATA -Filter lockfile -Recurse -ErrorAction SilentlyContinue"
}

Write-Host "Using Riot lockfile: $resolvedLockfilePath"

$lockfile = (Get-Content -LiteralPath $resolvedLockfilePath -Raw).Trim()
$parts = $lockfile -split ":"

if ($parts.Count -lt 5) {
    throw "Riot Client lockfile did not have the expected format."
}

$riotPort = $parts[2]
$riotPassword = $parts[3]

$authHelperPath = Join-Path $PSScriptRoot "riot-auth.js"
$tokenResponseJSON = node $authHelperPath $resolvedLockfilePath

if ($LASTEXITCODE -ne 0) {
    throw "Could not fetch Riot tokens from the local client."
}

$tokenResponse = $tokenResponseJSON | ConvertFrom-Json
$accessToken = $tokenResponse.accessToken
$entitlementsToken = $tokenResponse.entitlementsToken

if (-not $entitlementsToken) {
    $entitlementsToken = $tokenResponse.token
}

if (-not $accessToken) {
    throw "Riot local client did not return accessToken."
}

if (-not $entitlementsToken) {
    throw "Riot local client did not return an entitlements token."
}

$env:VALORANT_SHARD = $Shard
$env:VALORANT_ACCESS_TOKEN = $accessToken
$env:VALORANT_ENTITLEMENTS_TOKEN = $entitlementsToken
$env:RIOT_CLIENT_PORT = $riotPort
$env:RIOT_CLIENT_PASSWORD = $riotPassword

if ($tokenResponse.subject) {
    $env:VALORANT_PUUID = $tokenResponse.subject
}

if ($tokenResponse.clientVersion) {
    $env:VALORANT_CLIENT_VERSION = $tokenResponse.clientVersion
}

if ($HostAddress) {
    $env:HOST = $HostAddress
}

if ($BridgePort -gt 0) {
    $env:PORT = "$BridgePort"
}

Write-Host "Loaded Riot tokens from local client."
Write-Host "Shard: $env:VALORANT_SHARD"

if ($env:VALORANT_PUUID) {
    Write-Host "PUUID: $env:VALORANT_PUUID"
}

if ($env:VALORANT_CLIENT_VERSION) {
    Write-Host "Client version: $env:VALORANT_CLIENT_VERSION"
}

if ($PrintTokens) {
    Write-Host "VALORANT_ACCESS_TOKEN=$env:VALORANT_ACCESS_TOKEN"
    Write-Host "VALORANT_ENTITLEMENTS_TOKEN=$env:VALORANT_ENTITLEMENTS_TOKEN"
}

$serverPath = Join-Path $PSScriptRoot "server.js"
node $serverPath
