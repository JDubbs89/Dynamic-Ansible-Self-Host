# =============================================================================
# Run Ansible Playbook with Docker & Environment Variables
# =============================================================================
# This script intelligently handles Ansible deployment:
# - Detects if Docker is running
# - Automatically starts docker-compose if needed
# - Passes environment variables from .env to Ansible
# - Runs Ansible inside the Docker container
#
# Usage: .\run-playbook.ps1 [playbook] [additional args]
# Examples:
#   .\run-playbook.ps1                          # Runs site.yml in Docker
#   .\run-playbook.ps1 site.yml                 # Runs site.yml in Docker
#   .\run-playbook.ps1 site.yml --tags matrix   # Runs with tags
# =============================================================================

param(
    [string]$Playbook = "site.yml",
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$AdditionalArgs
)

# Ensure .env exists
if (-not (Test-Path ".env")) {
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "Please copy .env.example to .env with your actual values" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is available
Write-Host "Checking Docker availability..." -ForegroundColor Cyan
$dockerAvailable = $false
try {
    $dockerOutput = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $dockerAvailable = $true
        Write-Host $dockerOutput -ForegroundColor Green
    }
} catch {
    $dockerAvailable = $false
}

if (-not $dockerAvailable) {
    Write-Host "Docker not found. Install Docker or use local Ansible." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting Docker services..." -ForegroundColor Green
docker compose up -d 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: docker compose had issues, but continuing..." -ForegroundColor Yellow
}

Write-Host "Docker services ready" -ForegroundColor Green
Write-Host ""

# Build environment variables for docker exec
Write-Host "Building environment variables..." -ForegroundColor Cyan
$envArgs = @()
$envLines = Get-Content .env

foreach ($line in $envLines) {
    if ($line.Trim() -eq "" -or $line.Trim().StartsWith("#")) {
        continue
    }
    
    $parts = $line.Split('=', 2)
    if ($parts.Length -eq 2) {
        $name = $parts[0].Trim()
        $value = $parts[1].Trim()
        $envArgs += "-e"
        $envArgs += "$name=$value"
    }
}

Write-Host "Prepared $($envArgs.Count / 2) environment variables" -ForegroundColor Green
Write-Host ""

# Build the ansible-playbook command
$playbookCmd = "ansible-playbook -i inventory/hosts.yml $Playbook"
if ($AdditionalArgs.Count -gt 0) {
    $playbookCmd += " " + ($AdditionalArgs -join " ")
}

Write-Host "Running Ansible inside Docker container..." -ForegroundColor Green
Write-Host "Command: $playbookCmd" -ForegroundColor Cyan
Write-Host ""

# Execute the playbook inside the container
& docker compose exec @envArgs ansible sh -c $playbookCmd
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "SUCCESS: Ansible playbook completed!" -ForegroundColor Green
} else {
    Write-Host "FAILED: Ansible playbook exited with code $exitCode" -ForegroundColor Red
}

exit $exitCode
