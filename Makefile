CONTAINER_TOOL ?= $(shell which podman >/dev/null 2>&1 && echo podman || echo docker)

IMAGE_NAME = paracompiler-env

WORKSPACE_ROOT = $(shell pwd)/..

.PHONY: help build image shell check clean

help:
	@echo "ParaCompiler Environment Helper"
	@echo "Tool detected: $(CONTAINER_TOOL)"
	@echo "-------------------------"
	@echo "  make image   - Build the container image"
	@echo "  make shell   - Enter the container (interactive)"
	@echo "  make check   - Run config + build + tests inside container (one-shot)"
	@echo "  make clean   - Remove the image"

image:
	@echo "Building image using $(CONTAINER_TOOL)..."
	$(CONTAINER_TOOL) build -t $(IMAGE_NAME) .

shell:
	@echo "Entering container..."
	$(CONTAINER_TOOL) run --rm -it \
		-v "$(WORKSPACE_ROOT):/project:Z" \
		-w /project/paracl \
		$(IMAGE_NAME)

check:
	@echo "Running full check inside container..."
	$(CONTAINER_TOOL) run --rm \
		-v "$(WORKSPACE_ROOT):/project:Z" \
		-w /project/paracl \
		$(IMAGE_NAME) \
		bash -c "make config && make build && make test"

clean:
	$(CONTAINER_TOOL) rmi $(IMAGE_NAME)
