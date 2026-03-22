$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$SourceSchema = Join-Path $RepoRoot "database/schema.sql"
$TargetSchema = Join-Path $RepoRoot "k8s/base/schema.sql"

if (-not (Test-Path $SourceSchema)) {
    Write-Error "[sync-schema] source schema not found: $SourceSchema"
    exit 1
}

Copy-Item -Path $SourceSchema -Destination $TargetSchema -Force
Write-Output "[sync-schema] synced $SourceSchema -> $TargetSchema"
