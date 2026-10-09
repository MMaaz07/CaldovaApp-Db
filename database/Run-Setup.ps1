[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [switch]$SkipSeed
)
# Runs the setup scripts in order using Windows authentication. Stops at the first error (sqlcmd -b).
$ErrorActionPreference = 'Stop'
$scripts = @('01_create_database.sql', '02_create_schema.sql')
if (-not $SkipSeed) { $scripts += '03_seed_data.sql' }

foreach ($s in $scripts) {
    Write-Host "Running $s ..."
    sqlcmd -S $Server -E -C -b -I -i (Join-Path $PSScriptRoot $s)
    if ($LASTEXITCODE -ne 0) { throw "$s failed (exit code $LASTEXITCODE). Later scripts were not run." }
}
Write-Host 'Done.'
