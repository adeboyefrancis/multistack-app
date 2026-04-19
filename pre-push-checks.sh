#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# pre-push-checks.sh
# Guardrail script — runs before every push via hooks/pre-push
# Enforces branch rules, cleanliness checks, runtime versions,
# and lint/test validation. Fails fast if any condition is not met.
# ═══════════════════════════════════════════════════════════════

# ─── Colours ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=======================================================================${NC}"
echo -e "${BLUE}  🔎 Pre-Push Guardrail Checks${NC}"
echo -e "${BLUE}=======================================================================${NC}"

# ─── 1. Block pushes to main branch ─────────────────────────────
current_branch=$(git symbolic-ref --short HEAD)

echo -e "\n${YELLOW}[1/4] Checking branch...${NC}"
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
  echo -e "${RED}🚫 Direct pushes to '$current_branch' are not allowed.${NC}"
  echo -e "${RED}    Please push to a feature branch and open a pull request.${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Branch is '$current_branch' — safe to push.${NC}"

# ─── 2. Check for uncommitted changes ───────────────────────────
echo -e "\n${YELLOW}[2/4] Checking for uncommitted changes...${NC}"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo -e "${RED}🚫 You have uncommitted changes. Please commit or stash them before pushing.${NC}"
  git status --short
  exit 1
fi
echo -e "${GREEN}✅ Working tree is clean.${NC}"

# ─── 3. Validate runtime versions ───────────────────────────────
echo -e "\n${YELLOW}[3/4] Validating runtime versions...${NC}"

if [ -f "package.json" ]; then
  # ── Node / React project ──
  required_node="18"
  current_node=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)

  if [ -z "$current_node" ]; then
    echo -e "${RED}🚫 Node.js is not installed or not found in PATH.${NC}"
    exit 1
  fi

  if [ "$current_node" -lt "$required_node" ]; then
    echo -e "${RED}🚫 Node.js v$required_node+ required. Found: v$current_node${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ Node.js version: v$current_node (required: v$required_node+)${NC}"

elif [ -f "requirements.txt" ] || [ -f "manage.py" ] || [ -f "app.py" ]; then
  # ── Python / Django / Flask project ──
  required_python="3"
  current_python=$(python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d. -f1)

  if [ -z "$current_python" ]; then
    echo -e "${RED}🚫 Python 3 is not installed or not found in PATH.${NC}"
    exit 1
  fi

  if [ "$current_python" -lt "$required_python" ]; then
    echo -e "${RED}🚫 Python $required_python+ required. Found: $current_python${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ Python version: $(python3 --version) (required: Python $required_python+)${NC}"

else
  echo -e "${YELLOW}⚠️  No recognised runtime indicator found. Skipping version check.${NC}"
fi

# ─── 4. Dynamic Framework Checks ───────────────────────────────
echo -e "\n${YELLOW}[4/5] Running framework-specific lint and test checks...${NC}"

# List of your frameworks as defined in the Makefile prefixes
FRAMEWORKS=("ui" "orders" "cart" "app" "checkout")

for FW in "${FRAMEWORKS[@]}"; do
    echo -e "\n${YELLOW}🔍 Checking Framework: ${FW^^}${NC}" # ^^ converts to uppercase
    
    # 1. Run Lint
    echo -e "   Checking Linter..."
    if ! make "${FW}-lint"; then
        echo -e "${RED}🚫 ${FW^^} Linting failed! Check style violations.${NC}"
        exit 1
    fi

    # 2. Run Tests
    echo -e "   Running Unit Tests..."
    if ! make "${FW}-test"; then
        echo -e "${RED}🚫 ${FW^^} Tests failed! Fix code before pushing.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ ${FW^^} is clean and passing.${NC}"
done

echo -e "\n${GREEN}⭐ All frameworks passed all checks!${NC}"


# ─── 5. Docker files check ──────────────────────────────────────
echo -e "\n${YELLOW}[5/5] Checking for Docker files...${NC}"

if [ -f "Dockerfile" ] && [ -f "docker-compose.yml" ] && [ -f ".dockerignore" ]; then
  echo -e "${GREEN}✅ All Docker files present.${NC}"
else
  echo -e "${RED}🚫 Docker files missing. Please ensure Dockerfile, docker-compose.yml and .dockerignore exist.${NC}"
  exit 1
fi



# ─── All checks passed ──────────────────────────────────────────
echo -e "\n${BLUE}=======================================================================${NC}"
echo -e "${GREEN}🚀 All guardrail checks passed. Proceeding with push.${NC}"
echo -e "${BLUE}=======================================================================${NC}"
exit 0
