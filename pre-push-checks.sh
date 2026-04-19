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
echo -e "${BLUE}   🔎 Pre-Push Guardrail Checks${NC}"
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

# ─── 4. Dynamic Framework Lint * Test Checks ───────────────────────────────
echo -e "\n${YELLOW}[4/5] Running framework-specific lint and test checks...${NC}"

# Define a mapping of prefix to directory
FRAMEWORKS=(
  "ui:src/ui"
  #"orders:src/orders"
  #"cart:src/cart"
  #"app:src/app"
  #"checkout:src/checkout"
)

for ENTRY in "${FRAMEWORKS[@]}"; do
    FW="${ENTRY%%:*}"
    DIR="${ENTRY##*:}"

    # 1. First, check if the directory exists
    if [ ! -d "$DIR" ]; then
        continue
    fi

    # 2. Second, check if the Makefile target exists to avoid crashes
    if ! grep -q "^${FW}-lint:" Makefile; then
        echo -e "${YELLOW}⏩ Skipping ${FW^^}: Directory exists but Makefile target is missing.${NC}"
        continue
    fi

    echo -e "\n${YELLOW}🔍 Checking Framework: ${FW^^}${NC}" 
    
    # Run Lint
    echo -e "   Checking Linter..."
    if ! make "${FW}-lint"; then
        echo -e "${RED}🚫 ${FW^^} Linting failed!${NC}"
        exit 1
    fi

    # Run Tests
    echo -e "   Running Unit Tests..."
    if ! make "${FW}-test"; then
        echo -e "${RED}🚫 ${FW^^} Tests failed!${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ ${FW^^} is clean and passing.${NC}"

    # ─── 5. Docker files check ──────────────────────────────────────
    echo -e "   Checking Docker configuration for ${FW^^}..."
    MISSING_DOCKER=0
    for FILE in "Dockerfile" "docker-compose.yml" ".dockerignore"; do
        if [ ! -f "$DIR/$FILE" ]; then
            echo -e "${RED}      ❌ Missing: $DIR/$FILE${NC}"
            MISSING_DOCKER=1
        fi
    done

    if [ $MISSING_DOCKER -eq 1 ]; then
        echo -e "${RED}   🚫 Docker validation failed for ${FW^^}.${NC}"
        exit 1
    else
        echo -e "${GREEN}   ✅ All Docker files present for ${FW^^}.${NC}"
    fi

    echo -e "${GREEN}✅ ${FW^^} is ready for push.${NC}"
done 

# ─── All checks passed ──────────────────────────────────────────
echo -e "\n${BLUE}=======================================================================${NC}"
echo -e "${GREEN}🚀 All guardrail checks passed. Proceeding with push.${NC}"
echo -e "${BLUE}=======================================================================${NC}"
exit 0
