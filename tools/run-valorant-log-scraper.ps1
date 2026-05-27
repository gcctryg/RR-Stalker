$ErrorActionPreference = "Stop"

$toolDir = Join-Path $PSScriptRoot "valorant-log-endpoint-scraper"

if (-not (Test-Path -LiteralPath $toolDir)) {
    throw "Missing scraper folder: $toolDir"
}

Push-Location $toolDir
try {
    if (-not (Test-Path -LiteralPath "node_modules")) {
        npm.cmd install
    }

    node index.js
    Write-Host "Output: $(Join-Path $toolDir 'out\endpoints.json')"
} finally {
    Pop-Location
}
