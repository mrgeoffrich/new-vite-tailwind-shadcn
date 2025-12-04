#!/bin/bash

# Monorepo Setup Script
# This script runs the setup process step-by-step using Claude Code CLI
# Each step is executed in a NEW Claude Code context window
#
# Usage: ./run-setup.sh <target-directory>
# Example: ./run-setup.sh /Users/john/my-new-project

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Monorepo Setup - Automated${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check for target directory argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: Target directory not specified${NC}"
    echo ""
    echo "Usage: $0 <target-directory>"
    echo ""
    echo "Example:"
    echo "  $0 /Users/john/my-new-project"
    echo "  $0 ../my-new-project"
    echo ""
    exit 1
fi

TARGET_DIR="$1"

# Convert to absolute path
TARGET_DIR=$(cd "$(dirname "$TARGET_DIR")" 2>/dev/null && pwd)/$(basename "$TARGET_DIR") || TARGET_DIR="$(pwd)/$TARGET_DIR"

echo -e "${YELLOW}Target directory: $TARGET_DIR${NC}"
echo ""

# Check if target directory already exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Warning: Directory already exists${NC}"
    read -p "Continue and use existing directory? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${YELLOW}Will create directory: $TARGET_DIR${NC}"
    echo ""
fi

# Check if claude is available
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: 'claude' command not found${NC}"
    echo "Please install Claude Code CLI first"
    exit 1
fi

# Load setup instructions if available
SETUP_INSTRUCTIONS=""
SETUP_INSTRUCTIONS_FILE="$PROJECT_ROOT/SETUP_INSTRUCTIONS.md"

if [ -f "$SETUP_INSTRUCTIONS_FILE" ]; then
    echo -e "${YELLOW}Loading setup instructions from SETUP_INSTRUCTIONS.md${NC}"
    SETUP_INSTRUCTIONS=$(cat "$SETUP_INSTRUCTIONS_FILE")
    echo ""
else
    echo -e "${YELLOW}No SETUP_INSTRUCTIONS.md found, proceeding without additional instructions${NC}"
    echo ""
fi

# Configure Claude Code to allow access to target directory
echo -e "${YELLOW}Configuring Claude Code permissions for target directory...${NC}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Create .claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Create or update settings.json
if [ -f "$SETTINGS_FILE" ]; then
    # Settings file exists, try to merge
    if command -v jq &> /dev/null; then
        # Use jq if available for proper JSON merging
        jq --arg path "$TARGET_DIR" '.permissions.additionalDirectories += [$path] | .permissions.additionalDirectories |= unique' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    else
        # Fallback: simple append (may create duplicates but will work)
        echo -e "${YELLOW}Warning: jq not found, using simple merge (may create duplicates)${NC}"
        cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    "additionalDirectories": ["$TARGET_DIR"]
  }
}
EOF
    fi
else
    # Create new settings file
    cat > "$SETTINGS_FILE" <<EOF
{
  "permissions": {
    "additionalDirectories": ["$TARGET_DIR"]
  }
}
EOF
fi

echo -e "${GREEN}✓ Added $TARGET_DIR to Claude Code's allowed directories${NC}"
echo ""

# Function to run a setup step
run_step() {
    local step_num=$1
    local step_file=$2
    local build_cmd=$3

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}STEP $step_num: $step_file${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Build the prompt with setup instructions prepended
    local prompt=""
    if [ -n "$SETUP_INSTRUCTIONS" ]; then
        prompt="$SETUP_INSTRUCTIONS

---

"
    fi

    prompt="${prompt}Please read @$step_file and execute all the instructions in it. Add tasks to the todo list and complete them one by one.

IMPORTANT: Create all files in the target directory: $TARGET_DIR

If the directory doesn't exist yet, create it first. Make sure to build any packages that changed."

    # Run Claude with the prompt
    echo -e "${YELLOW}Running Claude Code...${NC}"
    echo ""
    claude --dangerously-skip-permissions --output-format text -p "$prompt"

    local claude_exit=$?
    echo ""

    if [ $claude_exit -ne 0 ]; then
        echo -e "${RED}✗ Claude exited with error code $claude_exit${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Run build command if specified
    if [ -n "$build_cmd" ]; then
        echo -e "${YELLOW}Running build: $build_cmd${NC}"
        if $build_cmd; then
            echo -e "${GREEN}✓ Build successful${NC}"
        else
            echo -e "${RED}✗ Build failed${NC}"
            read -p "Fix issues and press ENTER to continue, or Ctrl+C to exit..."
        fi
        echo ""
    fi

    echo -e "${GREEN}✓ Step $step_num complete${NC}"
    echo ""
}

# Step 1: Root Setup
run_step "1" "SETUP-1-ROOT.md"

# Step 2: Shared Package
run_step "2" "SETUP-2-SHARED.md"

# Step 3: Frontend
run_step "3" "SETUP-3-FRONTEND.md"

# Step 4: Backend
run_step "4" "SETUP-4-BACKEND.md"

# Step 5: Final Setup
run_step "5" "SETUP-5-FINAL.md"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All steps complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Your monorepo setup is complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated code"
echo "2. Set up your .env file in packages/backend/"
echo "3. Run 'npm run dev' to start development"
echo ""
