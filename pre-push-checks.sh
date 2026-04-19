# ═══════════════════════════════════════════════════════════════
# PHONY Targets (Ensures commands run even if a folder exists)
# ═══════════════════════════════════════════════════════════════
.PHONY: all print-env help install-misc build-tools verify-install \
        docker-install docker-login build-image run-container \
        push-images pull-images docker-exec docker-clean \
        validate-all ui-check ui-install ui-dev ui-build ui-lint ui-test ui-clean

# ═══════════════════════════════════════════════════════════════
# Settings & Paths
# ═══════════════════════════════════════════════════════════════

UI_SPRING_DIR  := $(shell pwd)/src/ui
# Future paths:
# ORDERS_DIR   := $(shell pwd)/src/orders
# CART_DIR     := $(shell pwd)/src/cart

# Colors for output
YELLOW := \033[0;33m
GREEN  := \033[0;32m
RED    := \033[0;31m
NC     := \033[0m

# Load .env file
ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif

# Variables
CURRENT_USER   := $(shell whoami)
DOCKER_REPO    := ${DOCKER_REPO}
IMAGE_NAME     := ${IMAGE_NAME}
CONTAINER_NAME := ${CONTAINER_NAME}
TAG_VERSION    := ${TAG_VERSION}
HOST_PORTS     := ${HOST_PORTS}
CONTAINER_PORT := ${CONTAINER_PORT}

# ═══════════════════════════════════════════════════════════════
# Global Validation (The "Master Switch")
# ═══════════════════════════════════════════════════════════════

validate-all: ui-check ## Run checks for ALL frameworks (Add orders-check etc. here later)
	@echo "$(GREEN)⭐ [SUCCESS] All frameworks passed all checks.$(NC)"

# ═══════════════════════════════════════════════════════════════
# Utility & Setup
# ═══════════════════════════════════════════════════════════════

help: ## Show available commands
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*##/ {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: install-misc docker-install

print-env: ## Print environment variables
	@echo "$(YELLOW)Current Environment Variables:$(NC)"
	@env | grep -E '^(DOCKER_REPO|IMAGE_NAME|CONTAINER_NAME|TAG_VERSION|HOST_PORTS|CONTAINER_PORT)=' || echo "No variables found."

install-misc: ## Install Misc utilities
	@echo "Installing Misc Tools (Zip & Unzip)..."
	sudo apt update -y && sudo apt install zip unzip -y

build-tools: ## Install Java, Maven, Nodejs
	@echo "Installing Build Stack..."
	sudo apt install openjdk-21-jdk maven nodejs npm -y

verify-install: ## Check versions
	@echo "--- Versions ---"
	@docker --version && java -version 2>&1 | head -n 1 && mvn -version | head -n 1

# ═══════════════════════════════════════════════════════════════
# Docker Orchestration
# ═══════════════════════════════════════════════════════════════

docker-install: ## Install Docker Engine
	@echo "Installing Docker..."
	# ... (Your existing install logic) ...
	@echo "Docker Installation Completed"

build-image: ## Build Docker image
	@docker build --build-arg GEMINI_API_KEY=${VITE_GEMINI_API_KEY} -t ${IMAGE_NAME}:${TAG_VERSION} .

# ... (Rest of your docker-login, push, pull, clean targets) ...

# ═══════════════════════════════════════════════════════════════
# UI Framework (Spring Boot)
# ═══════════════════════════════════════════════════════════════

ui-install: ## Install Maven dependencies
	@echo "Installing UI dependencies..."
	cd $(UI_SPRING_DIR) && ./mvnw dependency:resolve

ui-lint: ## Run Checkstyle linter
	@echo "Running UI Checkstyle..."
	cd $(UI_SPRING_DIR) && ./mvnw checkstyle:check || (echo "$(RED)🚫 UI Checkstyle failed.$(NC)" && exit 1)

ui-test: ## Run UI unit tests
	@echo "Running UI tests..."
	cd $(UI_SPRING_DIR) && ./mvnw test || (echo "$(RED)🚫 UI Tests failed.$(NC)" && exit 1)

ui-check: ui-lint ui-test ## Run all UI checks
	@echo "$(GREEN)✅ UI framework checks passed$(NC)"

ui-clean: ## Remove UI build artifacts
	cd $(UI_SPRING_DIR) && ./mvnw clean
