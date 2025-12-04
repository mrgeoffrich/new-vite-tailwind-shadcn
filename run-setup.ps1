# Monorepo Setup Script (PowerShell)
# This script runs the setup process step-by-step using Claude Code CLI
# Each step is executed in a NEW Claude Code context window
#
# Usage: .\run-setup.ps1 <target-directory>
# Example: .\run-setup.ps1 C:\Projects\my-new-project

$ErrorActionPreference = "Continue"

$PROJECT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PROJECT_ROOT

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

function Invoke-Step {
    param(
        [int]$StepNum,
        [string]$StepFile,
        [string]$BuildCmd = "",
        [string]$TargetDir
    )

    Write-StepHeader "STEP ${StepNum}: $StepFile"

    # Build the prompt with setup instructions prepended
    $prompt = ""
    if ($script:SETUP_INSTRUCTIONS) {
        $prompt = @"
$script:SETUP_INSTRUCTIONS

---

"@
    }

    $prompt += @"
Please read @$StepFile and execute all the instructions in it. Add tasks to the todo list and complete them one by one.

IMPORTANT: Create all files in the target directory: $TargetDir

If the directory doesn't exist yet, create it first. Make sure to build any packages that changed.
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
Write-Header "Monorepo Setup - Automated"

# Check for target directory argument
if ($args.Count -eq 0) {
    Write-Host "Error: Target directory not specified" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\run-setup.ps1 <target-directory>"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\run-setup.ps1 C:\Projects\my-new-project"
    Write-Host "  .\run-setup.ps1 ..\my-new-project"
    Write-Host ""
    exit 1
}

$TARGET_DIR = $args[0]

# Convert to absolute path
if ([System.IO.Path]::IsPathRooted($TARGET_DIR)) {
    # Already absolute, normalize it
    $TARGET_DIR = [System.IO.Path]::GetFullPath($TARGET_DIR)
} else {
    # Relative path, make it absolute
    $TARGET_DIR = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $TARGET_DIR))
}

Write-Host "Target directory: $TARGET_DIR" -ForegroundColor Yellow
Write-Host ""

# Check if target directory already exists
if (Test-Path $TARGET_DIR) {
    Write-Host "Warning: Directory already exists" -ForegroundColor Yellow
    $response = Read-Host "Continue and use existing directory? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        exit 1
    }
} else {
    Write-Host "Will create directory: $TARGET_DIR" -ForegroundColor Yellow
    Write-Host ""
}

try {
    $null = Get-Command claude -ErrorAction Stop
} catch {
    Write-Host "Error: 'claude' command not found" -ForegroundColor Red
    Write-Host "Please install Claude Code CLI first"
    exit 1
}

# Load setup instructions if available
$SETUP_INSTRUCTIONS = ""
$SETUP_INSTRUCTIONS_FILE = Join-Path $PROJECT_ROOT "SETUP_INSTRUCTIONS.md"

if (Test-Path $SETUP_INSTRUCTIONS_FILE) {
    Write-Host "Loading setup instructions from SETUP_INSTRUCTIONS.md" -ForegroundColor Yellow
    $SETUP_INSTRUCTIONS = Get-Content $SETUP_INSTRUCTIONS_FILE -Raw
    Write-Host ""
} else {
    Write-Host "No SETUP_INSTRUCTIONS.md found, proceeding without additional instructions" -ForegroundColor Yellow
    Write-Host ""
}

# Configure Claude Code to allow access to target directory
Write-Host "Configuring Claude Code permissions for target directory..." -ForegroundColor Yellow
$claudeDir = Join-Path $PROJECT_ROOT ".claude"
$settingsFile = Join-Path $claudeDir "settings.json"

# Create .claude directory if it doesn't exist
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Escape backslashes for JSON
$escapedPath = $TARGET_DIR -replace '\\', '\\'

# Create or update settings.json
$settings = @{
    permissions = @{
        additionalDirectories = @($escapedPath)
    }
}

# If settings file exists, merge with existing settings
if (Test-Path $settingsFile) {
    try {
        $existingSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($existingSettings.permissions -and $existingSettings.permissions.additionalDirectories) {
            # Merge existing directories
            $existingDirs = @($existingSettings.permissions.additionalDirectories)
            if ($escapedPath -notin $existingDirs) {
                $existingDirs += $escapedPath
            }
            $settings.permissions.additionalDirectories = $existingDirs
        }
        # Preserve other settings
        foreach ($prop in $existingSettings.PSObject.Properties) {
            if ($prop.Name -ne "permissions") {
                $settings[$prop.Name] = $prop.Value
            }
        }
    } catch {
        Write-Host "Warning: Could not parse existing settings.json, will overwrite" -ForegroundColor Yellow
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
Write-Host "✓ Added $TARGET_DIR to Claude Code's allowed directories" -ForegroundColor Green
Write-Host ""

# Step 1: Root Setup
Invoke-Step -StepNum 1 -StepFile "SETUP-1-ROOT.md" -BuildCmd "npm run build:shared" -TargetDir $TARGET_DIR

# Step 2: Shared Package
Invoke-Step -StepNum 2 -StepFile "SETUP-2-SHARED.md" -BuildCmd "npm run build:shared" -TargetDir $TARGET_DIR

# Step 3: Frontend
Invoke-Step -StepNum 3 -StepFile "SETUP-3-FRONTEND.md" -BuildCmd "npm run build" -TargetDir $TARGET_DIR

# Step 4: Backend
Invoke-Step -StepNum 4 -StepFile "SETUP-4-BACKEND.md" -BuildCmd "npm run build" -TargetDir $TARGET_DIR

# Step 5: Final Setup
Invoke-Step -StepNum 5 -StepFile "SETUP-5-FINAL.md" -BuildCmd "npm run build" -TargetDir $TARGET_DIR

Write-StepHeader "✓ All steps complete!"

Write-Host "Your monorepo setup is complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Review the generated code"
Write-Host "2. Set up your .env file in packages/backend/"
Write-Host "3. Run 'npm run dev' to start development"
Write-Host ""
