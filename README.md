# ParaCompiler Infrastructure & Tools
This repository contains the build infrastructure, CI configurations, and toolchain management scripts for the [ParaCompiler](https://github.com/vian96/ParaCompiler).

Its primary purpose is to provide a consistent, reproducible build environment across different Linux distributions (OpenSUSE Leap, Ubuntu) and CI runners, resolving binary compatibility issues inherent to C++20 Modules and LLVM development.

## Overview
Developing a compiler using C++20 Modules requires a strict alignment between the compiler version, the standard library (`libc++` vs `libstdc++`), and the build tools. To avoid forcing users to manually compile LLVM 20+ from source, we provide mechanisms to:
- **Download** a pre-built, portable toolchain (LLVM 22 + ANTLR Runtime).
- **Bootstrap** the toolchain from source if necessary.
- **Run** the build in isolated Docker/Podman containers.

## Quick Start (recommended)
If you have synchronized the project using `repo`, you will have this directory as `tools/` alongside `paracl/`.

### Option 1: Local Setup (no docker/podman)
This downloads the pre-compiled LLVM binaries into `../external/dist`. This is the fastest way to get started on a Linux machine. It requires system with `glibc-2.35` or higher (e.g. Ubuntu 22.04).

```bash
make pull-toolchain
```

After this, you can build the main project normally; the CMake presets are configured to detect this custom toolchain automatically.

### Option 2: Containerized Environment
If you prefer not to download binaries to your host machine or have incompatible system libraries (glibc < 2.35), use the CI container. It comes with the toolchain pre-installed.

```bash
make pull-img-ci
make shell-ci
```

This will drop you into a shell inside the container with all paths (`CC`, `CXX`, `CMAKE_PREFIX_PATH`, path to project) pre-configured.

## Requirements & Building from Source
To run containers you need `docker` or `podman` to be installed and `make` for `Makefile`-based interface.

Toolchain requires your system to have `glibc-2.31+` (for `ubuntu-20.04`-based builds). If you have an older system, consider building toolchain from source or use our container images.

If you decided to build toolchain from source, you have 2 options: single-stage build and bootstrap build.
Bootstrap build is preferable, because it requires less preliminary setup and produces more portable binaries (`libc++` is linked statically). You will need:
- `make`
- `cmake`
- `ninja`
- `clang++` (recommended) or `g++`
- `libc++` or `libstdc++`
- `lld`
- `zlib` (optional)
- `libxml` (optional)

If you're on Ubuntu, check corresponding ci `buil-toolchain.yml` file.

Single-stage build is ~2 times faster, but will require you to set up LLVM environment properly. You will absoulutely need `libc++`. Here you can go with our `paracompiler-tools` container.

## Toolchain Management
We use a custom build of LLVM (derived from tested commit of the `master` branch) and ANTLR 4.13.1.

| Command | Description |
| :--- | :--- |
| `make pull-toolchain` | **Recommended.** Downloads the latest pre-built toolchain artifact from our GitHub Releases. |
| `make build-toolchain` | **Advanced.** Compiles LLVM and ANTLR from source locally. **Warning:** This process usually takes 1-3 hours depending on hardware (single-stage build can be finished in 30 minutes on an average desktop though). |

### Why use Custom Toolchain?
Standard Linux distributions usually link against `libstdc++` (GCC). However, proper C++20 Modules support in Clang requires `libc++` (LLVM). Mixing these standard libraries leads to ABI conflicts and segmentation faults.

Our toolchain is built using a **2-stage bootstrap process** on an older Linux kernel (Ubuntu 22.04) to ensure:
- **Static Linkage:** `libc++` is statically linked into the `clang` binary, making it portable.
- **GLIBC Compatibility:** The binaries run on most modern Linux distros (Ubuntu 22.04+, OpenSUSE Leap 15.6+).
- **Correct Defaults:** The compiler defaults to `-stdlib=libc++` and includes the necessary module maps.

## Container Environments
The `Makefile` provides an interface for managing OCI-compliant containers (Docker or Podman).

| Target | Description |
| :--- | :--- |
| `make pull-ci` | Pulls the production CI image from GHCR. Contains the custom LLVM toolchain. Identical to the GitHub Actions environment. |
| `make pull-dev` | Pulls a "clean" OpenSUSE Leap 15.6 image with system + development packages only. Useful for testing compatibility with system package managers. |
| `make shell-ci/-dev` | Opens shell inside a container, mouts project directory. |
| `make build-img-ci/-dev` | Build container image (and toolchain for `-ci` if necessary) from source. |
| `make check` | Runs the full configuration, build, and test cycle for ParaCL inside the CI container. |

## CI/CD Pipeline
This repository includes GitHub Actions workflows that:
- Build the toolchain from source and publish tarballs to **Releases**.
- Build the container image with the toolchain and publish it to **GitHub Container Registry (GHCR)**.
- Build the container image with base system and some development packages.

For details on the build configuration, refer to `build_toolchain.sh`.
