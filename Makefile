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
MULTI_PLATFORM_IMAGE_NAME := ${MULTI_PLATFORM_IMAGE_NAME}
DOCKER_DRIVER   := ${DOCKER_DRIVER}
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
# Print Environment Variables (for debugging)
# ═══════════════════════════════════════════════════════════════
print-env: ## Print all environment variables (for debugging)
	@echo "$(YELLOW)Current Environment Variables:$(NC)"
	@env | grep -E '^(DOCKER_REPO|IMAGE_NAME|CONTAINER_NAME|TAG_VERSION|HOST_PORTS|CONTAINER_PORT)=' || echo "No relevant environment variables found."

# Default target
help: ## Show available commands
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*##/ {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


all: install-misc docker-install

install-misc: ## Install Misc utilities
	@echo "Installing Misc Tools (Zip & Unzip)..."
	sudo apt update -y
	sudo apt install zip unzip -y

build-tools: ## Installing Java, Maven , Nodejs & npm
	@echo "Installing Java 21 ...."
	sudo apt install openjdk-21-jdk -y
	
	@echo "Installing Maven....."
	sudo apt install maven -y

	@echo "Installing Nodejs"
	sudo apt install nodejs -y && sudo apt install npm -y


docker-install: ## Docker Installation
	@echo "1. Adding Docker GPG Key..."
	sudo apt update -y
	sudo apt install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	@echo "2. Adding Repository..."
	echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$${VERSION_CODENAME}") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	@echo "3. Installing Docker Engines..."
	sudo apt update -y
	sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	@echo "4. Enabling and Starting Services..."
	sudo systemctl enable docker
	sudo systemctl start docker

	@echo "5. Running Post-Installation (User Groups)..."
	sudo groupadd docker || true
	sudo usermod -aG docker $(CURRENT_USER)
	newgrp docker
	@echo "Docker Installation Completed"

verify-install: ## Check versions
	@echo "--- Versions ---"
	@zip -v | head -n 1
	@unzip -v | head -n 1
	@docker --version
	@docker compose version
	@java -version 2>&1 | head -n 1
	@mvn -version | head -n 1
	@node --version
	@npm --version

# ═══════════════════════════════════════════════════════════════
# Docker Orchestration for Frontend UI (Application)
# ═══════════════════════════════════════════════════════════════
docker-login: ## Docker Login
	@echo "Login to Docker Hub via CLI locally"
	@docker login -u ${DOCKER_REPO}

build-image: ## Build Docker image locally
	@echo "Build Docker New docker Image locally...."
	@docker build -t ${IMAGE_NAME}:${TAG_VERSION} $(UI_SPRING_DIR)

run-container: ## Run Image as a Container
	@echo "Running Container using built image...."
	@docker run --name ${CONTAINER_NAME} -p ${HOST_PORTS}:${CONTAINER_PORT} -d ${IMAGE_NAME}:${TAG_VERSION}

push-images: ## Tag & Push Image to Docker Hub
	@echo "Tagging Docker image"
	@docker tag ${IMAGE_NAME}:${TAG_VERSION} ${DOCKER_REPO}/${IMAGE_NAME}:${TAG_VERSION}

	@echo "Pushing Tagged Image to Docker Registry"
	@docker push ${DOCKER_REPO}/${IMAGE_NAME}:${TAG_VERSION}

pull-images: ## Pull Docker Images
	@echo "Pulling docker Image...."
	@docker pull ${DOCKER_REPO}/${IMAGE_NAME}:${TAG_VERSION}


docker-exec: ## Connect to Docker Container via Terminal
	@docker exec -it ${CONTAINER_NAME} /bin/sh

docker-clean: ## Stop Container && Remove Image
# Stop Docker Container
	@echo "Stopping Container...."
	@docker stop ${CONTAINER_NAME}

# Remove Docker Container
	@echo "Removing Container...."
	@docker rm ${CONTAINER_NAME}

# Remove Docker Images
	@echo "Removing Image from Local Host /var/lib/docker/image"
	@docker rmi ${IMAGE_NAME}:${TAG_VERSION}
	@echo "$(GREEN)✅ Docker cleanup complete$(NC)"


# ═══════════════════════════════════════════════════════════════
# Spring Boot Backend 
# ═══════════════════════════════════════════════════════════════

ui-install: ## Install Maven dependencies
	@echo "Installing Maven dependencies...[1/6]"
	cd $(UI_SPRING_DIR) && ./mvnw dependency:resolve
	@echo "$(GREEN)✅ Dependencies installed$(NC)"

ui-dev: ## Run Spring Boot in development mode
	@echo "Starting Spring Boot server...[2/6]"
	cd $(UI_SPRING_DIR) && ./mvnw spring-boot:run

ui-build: ## Build the application JAR
	@echo "Building Backend application...[3/6]"
	cd $(UI_SPRING_DIR) && ./mvnw clean package -DskipTests
	@echo "$(GREEN)✅ Build complete — output in target/$(NC)"

ui-lint: ## Run Checkstyle linter
	@echo "Running Checkstyle...[4/6]"
	cd $(UI_SPRING_DIR) && ./mvnw checkstyle:check || (echo "$(RED)🚫 Checkstyle failed.$(NC)" && exit 1)
	@echo "$(GREEN)✅ Linting complete$(NC)"

ui-test: ## Run Spring Boot unit tests
	@echo "Running Backend tests...[5/6]"
	cd $(UI_SPRING_DIR) && ./mvnw test || (echo "$(RED)🚫 Tests failed.$(NC)" && exit 1)
	@echo "$(GREEN)✅ Tests complete$(NC)"

ui-check: ui-lint ui-test ## Run all Backend checks
	@echo "$(GREEN)✅ All backend checks passed$(NC)"

ui-clean: ## Remove Backend build artifacts
	@echo "Cleaning Backend...[6/6]"
	cd $(UI_SPRING_DIR) && ./mvnw clean
	@echo "✅ Clean complete"

# ═════════════════════════════════════════════════════════════════════
# Multi-Platform Using Docker Buildx (for ARM64 and AMD64 architectures)
# ═════════════════════════════════════════════════════════════════════

host-arch: ## Detect OS & Host Architecture (amd64 or arm64)
	@echo "Detecting Host Architecture..."
	@echo "OS Information:"
	@cat /etc/os-release | sed -n '1,6p' 2>/dev/null || echo "OS info not available"
	@echo "Host Architecture: $$(uname -m)"

buildx-version: ## Check Docker Buildx Version
	@echo "Checking Docker Buildx Version..."
	@export DOCKER_BUILDKIT=1
	@docker buildx version

install-qemu-binfmt: ## Install QEMU binfmt Emulator for multi-platform builds
	@echo "Installing QEMU binfmt for multi-platform builds..."
	@docker run --privileged --rm tonistiigi/binfmt --install all

buildx-create: ## Create multi-arch using Docker Buildx Builder   
	@echo "Creating Docker Buildx Builder instance..."
	@docker buildx create --name ${MULTI_PLATFORM_IMAGE_NAME} --driver ${DOCKER_DRIVER} --use || true

buildx-inspect: ## Inspect Docker Buildx Builder instance
	@echo "Inspecting Docker Buildx Builder instance..."
	@docker buildx inspect ${MULTI_PLATFORM_IMAGE_NAME} --bootstrap

buildx-list: ## List Docker Buildx Builder instances
	@echo "Listing Docker Buildx Builder instances..."
	@docker buildx ls

buildx-build-push: ## Build and Push multi-arch image using Docker Buildx
	@echo "Building and pushing multi-arch image using Docker Buildx..."
	@docker buildx build --platform linux/amd64,linux/arm64 \
		-t ${DOCKER_REPO}/${MULTI_PLATFORM_IMAGE_NAME}:${TAG_VERSION} --push $(UI_SPRING_DIR)

buildx-manifest: ## Verify pushed multi-arch image manifest
	@echo "Verifying pushed multi-arch image manifest..."
	@docker buildx imagetools inspect ${DOCKER_REPO}/${MULTI_PLATFORM_IMAGE_NAME}:${TAG_VERSION}

buildx-run-arm64: ## Run ARM64 image on AMD64 host using Buildx QEMU emulation
	@echo "Cleaning existing ARM64 container..."
	@docker rm -f ${CONTAINER_NAME}-arm64 2>/dev/null || true
	@echo "Running ARM64 image on AMD64 host using Buildx QEMU emulation..."
	@docker run --platform linux/arm64 \
		-p ${HOST_PORTS}:${CONTAINER_PORT} \
		--name ${CONTAINER_NAME}-arm64 -d \
		${DOCKER_REPO}/${MULTI_PLATFORM_IMAGE_NAME}:${TAG_VERSION}

buildx-run-amd64: ## Run AMD64 image on ARM64 host using Buildx QEMU emulation
	@echo "Cleaning existing AMD64 container..."
	@docker rm -f ${CONTAINER_NAME}-amd64 2>/dev/null || true
	@echo "Running AMD64 image on ARM64 host using Buildx QEMU emulation..."
	@docker run --platform linux/amd64 \
		-p ${HOST_PORTS}:${CONTAINER_PORT} \
		--name ${CONTAINER_NAME}-amd64 -d \
		${DOCKER_REPO}/${MULTI_PLATFORM_IMAGE_NAME}:${TAG_VERSION}

buildx-clean: ## Clean up Buildx builder and multi-arch images
	@echo "Cleaning up Buildx builder and multi-arch images..."
	@docker rm -f ${CONTAINER_NAME}-arm64 ${CONTAINER_NAME}-amd64 2>/dev/null || true
	@docker buildx rm ${MULTI_PLATFORM_IMAGE_NAME} 2>/dev/null || true
	@docker rmi ${DOCKER_REPO}/${MULTI_PLATFORM_IMAGE_NAME}:${TAG_VERSION} 2>/dev/null || true
