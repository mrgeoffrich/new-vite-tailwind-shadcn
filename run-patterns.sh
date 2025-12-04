#!/bin/bash

# Pattern Installation Script
# This script runs pattern installation guides step-by-step using Claude Code CLI
# Each step is executed in a NEW Claude Code context window
#
# Usage: ./run-patterns.sh
# Run from the root of your generated project (not the template repo)

set -e

PROJECT_ROOT="$(pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Pattern Installation - Automated${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if claude is available
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: 'claude' command not found${NC}"
    echo "Please install Claude Code CLI first"
    exit 1
fi

# Check if we're in a valid project directory
if [ ! -d "packages" ]; then
    echo -e "${RED}Error: 'packages' directory not found${NC}"
    echo ""
    echo "This script should be run from the root of your generated project,"
    echo "not from the template repository."
    echo ""
    exit 1
fi

if [ ! -d "patterns" ]; then
    echo -e "${RED}Error: 'patterns' directory not found${NC}"
    echo ""
    echo "Make sure the patterns directory was copied to your project"
    echo "during the setup process (SETUP-5-FINAL.md)."
    echo ""
    exit 1
fi

echo -e "${YELLOW}Working directory: $PROJECT_ROOT${NC}"
echo ""

# Confirm before starting
read -p "Ready to install patterns? This will modify your codebase. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""

# Function to run a pattern installation step
run_pattern_step() {
    local step_num=$1
    local step_file=$2
    local description=$3

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}STEP $step_num: $description${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local prompt="Please read @patterns/$step_file and implement all the patterns described in it. Add tasks to the todo list and complete them one by one.

IMPORTANT: Work in the current directory structure:
- packages/shared/ for shared code patterns
- packages/backend/ for Express patterns
- packages/backend/prisma/ for Prisma patterns
- Docker files in the project root

Read one section at a time to avoid context overload. After major changes, run builds to catch errors early."

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

    echo -e "${GREEN}✓ Step $step_num complete${NC}"
    echo ""
}

# Step 1: Shared Package Patterns
run_pattern_step "1" "INSTALL_SHARED_PATTERNS.md" "Shared Package Patterns"

# Step 2: Express Backend Patterns
run_pattern_step "2" "INSTALL_EXPRESS_PATTERNS.md" "Express Backend Patterns"

# Step 3: Prisma Patterns
run_pattern_step "3" "PRISMA_PATTERNS.md" "Prisma Migration Patterns"

# Step 4: Docker Patterns
run_pattern_step "4" "DOCKER_PATTERNS.md" "Docker Setup"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All patterns installed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Pattern installation complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the implemented patterns in your codebase"
echo "2. Run 'npm run build' to ensure everything compiles"
echo "3. Test the application with 'npm run dev'"
echo "4. Set up Docker with 'docker compose up -d --build' (if you installed Docker patterns)"
echo ""
