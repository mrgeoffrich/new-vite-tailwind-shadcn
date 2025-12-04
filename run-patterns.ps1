# Pattern Installation Script (PowerShell)
# This script runs pattern installation guides step-by-step using Claude Code CLI
# Each step is executed in a NEW Claude Code context window
#
# Usage: .\run-patterns.ps1
# Run from the root of your generated project (not the template repo)

$ErrorActionPreference = "Continue"

$PROJECT_ROOT = Get-Location

# Colors for output
function Write-Header {
    param([string]$Message)
    Write-Host "============================================" -ForegroundColor Blue
    Write-Host "  $Message" -ForegroundColor Blue
    Write-Host "============================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-StepHeader {
    param([string]$Message)
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host $Message -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
}

function Invoke-PatternStep {
    param(
        [int]$StepNum,
        [string]$StepFile,
        [string]$Description
    )

    Write-StepHeader "STEP ${StepNum}: $Description"

    $prompt = @"
Please read @patterns/$StepFile and implement all the patterns described in it. Add tasks to the todo list and complete them one by one.

IMPORTANT: Work in the current directory structure:
- packages/shared/ for shared code patterns
- packages/backend/ for Express patterns
- packages/backend/prisma/ for Prisma patterns
- Docker files in the project root

Read one section at a time to avoid context overload. After major changes, run builds to catch errors early.
"@

    # Run Claude with the prompt
    Write-Host "Running Claude Code..." -ForegroundColor Yellow
    Write-Host ""
    & claude --dangerously-skip-permissions --output-format text -p $prompt

    $claudeExit = $LASTEXITCODE
    Write-Host ""

    if ($claudeExit -ne 0) {
        Write-Host "✗ Claude exited with error code $claudeExit" -ForegroundColor Red
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            exit 1
        }
    }

    Write-Host "✓ Step $StepNum complete" -ForegroundColor Green
    Write-Host ""
}

# Check if claude is available
Write-Header "Pattern Installation - Automated"

try {
    $null = Get-Command claude -ErrorAction Stop
} catch {
    Write-Host "Error: 'claude' command not found" -ForegroundColor Red
    Write-Host "Please install Claude Code CLI first"
    exit 1
}

# Check if we're in a valid project directory
if (-not (Test-Path "packages")) {
    Write-Host "Error: 'packages' directory not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script should be run from the root of your generated project,"
    Write-Host "not from the template repository."
    Write-Host ""
    exit 1
}

if (-not (Test-Path "patterns")) {
    Write-Host "Error: 'patterns' directory not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure the patterns directory was copied to your project"
    Write-Host "during the setup process (SETUP-5-FINAL.md)."
    Write-Host ""
    exit 1
}

Write-Host "Working directory: $PROJECT_ROOT" -ForegroundColor Yellow
Write-Host ""

# Confirm before starting
$response = Read-Host "Ready to install patterns? This will modify your codebase. Continue? (y/N)"
if ($response -ne "y" -and $response -ne "Y") {
    exit 0
}

Write-Host ""

# Step 1: Shared Package Patterns
Invoke-PatternStep -StepNum 1 -StepFile "INSTALL_SHARED_PATTERNS.md" -Description "Shared Package Patterns"

# Step 2: Express Backend Patterns
Invoke-PatternStep -StepNum 2 -StepFile "INSTALL_EXPRESS_PATTERNS.md" -Description "Express Backend Patterns"

# Step 3: Prisma Patterns
Invoke-PatternStep -StepNum 3 -StepFile "PRISMA_PATTERNS.md" -Description "Prisma Migration Patterns"

# Step 4: Docker Patterns
Invoke-PatternStep -StepNum 4 -StepFile "DOCKER_PATTERNS.md" -Description "Docker Setup"

Write-StepHeader "✓ All patterns installed!"

Write-Host "Pattern installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the implemented patterns in your codebase"
Write-Host "2. Run 'npm run build' to ensure everything compiles"
Write-Host "3. Test the application with 'npm run dev'"
Write-Host "4. Set up Docker with 'docker compose up -d --build' (if you installed Docker patterns)"
Write-Host ""
