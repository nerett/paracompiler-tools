CONTAINER_TOOL ?= $(shell which podman >/dev/null 2>&1 && echo podman || echo docker)

IMG_DEV_LOCAL = paracompiler-dev:local
IMG_CI_LOCAL  = paracompiler-ci:local

REGISTRY      = ghcr.io/nerett
IMG_DEV_REMOTE= $(REGISTRY)/paracompiler-tools:latest
IMG_CI_REMOTE = $(REGISTRY)/paracompiler-tools-ci:latest

WORKSPACE_ROOT = $(shell pwd)/..
ARCHIVE_NAME   = toolchain-llvm-antlr.tar.gz

RUN_FLAGS = --rm -it \
	--security-opt label=disable \
	-v "$(WORKSPACE_ROOT):/project:Z" \
	-w /project/paracl

.PHONY: help \
	pull-toolchain build-toolchain \
	pull-img-dev pull-img-ci \
	build-img-dev build-img-ci \
	shell-dev shell-ci shell-dev-local shell-ci-local \
	clean

help:
	@echo "ParaCompiler Infrastructure Manager"
	@echo "Tool detected: $(CONTAINER_TOOL)"
	@echo "----------------------------------------------------------------"
	@echo "Toolchain Management (Local folder: ../external/dist):"
	@echo "  make pull-toolchain   - Download pre-built toolchain from GitHub"
	@echo "  make build-toolchain  - Build toolchain from source (takes time!)"
	@echo ""
	@echo "Container Images (Management):"
	@echo "  make pull-img-dev     - Pull Base image (OS + sys deps)"
	@echo "  make pull-img-ci      - Pull CI image (OS + pre-built toolchain)"
	@echo "  make build-img-dev    - Build Base image locally (Containerfile)"
	@echo "  make build-img-ci     - Build CI image locally (Builds toolchain first!)"
	@echo ""
	@echo "Shell Access (Interactive):"
	@echo "  make shell-dev        - Run Pulled Base Image"
	@echo "  make shell-ci         - Run Pulled CI Image (Recommended)"
	@echo "  make shell-dev-local  - Run Local Base Image"
	@echo "  make shell-ci-local   - Run Local CI Image"
	@echo ""
	@echo "  make clean            - Remove artifacts and local images"

# --- Toolchain ---
pull-toolchain:
	@bash ./download_toolchain.sh

build-toolchain:
	@echo "Building toolchain from source (Bootstrap mode)..."
	@chmod +x build_toolchain.sh
	./build_toolchain.sh --bootstrap

# --- 2. Images (pull) ---
pull-img-dev:
	$(CONTAINER_TOOL) pull $(IMG_DEV_REMOTE)

pull-img-ci:
	$(CONTAINER_TOOL) pull $(IMG_CI_REMOTE)

# --- 3. Images (build) ---
build-img-dev:
	$(CONTAINER_TOOL) build -f Containerfile -t $(IMG_DEV_LOCAL) .

build-img-ci: build-toolchain
	@echo "Packing toolchain for container build..."
	tar -czf $(ARCHIVE_NAME) -C ../external/dist .
	@echo "Building container image..."
	$(CONTAINER_TOOL) build -f Containerfile.ci -t $(IMG_CI_LOCAL) .
	rm $(ARCHIVE_NAME)

# --- 4. Images (run) ---
shell-dev:
	$(CONTAINER_TOOL) run $(RUN_FLAGS) $(IMG_DEV_REMOTE)

shell-ci:
	$(CONTAINER_TOOL) run $(RUN_FLAGS) $(IMG_CI_REMOTE)

shell-dev-local:
	$(CONTAINER_TOOL) run $(RUN_FLAGS) $(IMG_DEV_LOCAL)

shell-ci-local:
	$(CONTAINER_TOOL) run $(RUN_FLAGS) $(IMG_CI_LOCAL)

# --- Cleanup ---
clean:
	rm -rf $(ARCHIVE_NAME)
	-$(CONTAINER_TOOL) rmi $(IMG_DEV_LOCAL) $(IMG_CI_LOCAL)
