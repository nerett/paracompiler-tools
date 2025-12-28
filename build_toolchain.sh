#!/bin/bash
set -e

ENABLE_BOOTSTRAP=false

function show_help {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Builds the LLVM and ANTLR toolchain."
    echo ""
    echo "Options:"
    echo "  --bootstrap    Enable 2-stage Bootstrap build."
    echo "                 Builds Clang twice. Produces a portable binary with static libc++."
    echo "                 Recommended for creating distribution artifacts."
    echo "  --help         Show this help message."
    echo ""
    echo "Default behavior: Single-stage build using the host compiler and host libc++."
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bootstrap) ENABLE_BOOTSTRAP=true ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
TOOLCHAIN_ROOT="$WORKSPACE_ROOT/external"

DIST_DIR="$TOOLCHAIN_ROOT/dist"
LLVM_DIR="$TOOLCHAIN_ROOT/llvm-project"
ANTLR_DIR="$TOOLCHAIN_ROOT/antlr4"

LLVM_TAG="main"
ANTLR_TAG="4.13.1"
LLVM_COMMIT="2e16cadd560f760f100030e575fe402f3f6b2eba"

echo "=== Configured Paths ==="
echo "Script Dir:     $SCRIPT_DIR"
echo "Workspace Root: $WORKSPACE_ROOT"
echo "Toolchain Root: $TOOLCHAIN_ROOT"
echo "Destination:    $DIST_DIR"
echo "========================"

mkdir -p "$TOOLCHAIN_ROOT"
mkdir -p "$DIST_DIR"

if [ ! -d "$LLVM_DIR" ]; then
    echo "Cloning LLVM Project (${LLVM_TAG})..."
    git clone --branch "$LLVM_TAG" https://github.com/llvm/llvm-project.git "$LLVM_DIR"
else
    echo "LLVM source found at $LLVM_DIR (Skipping clone)"
fi

if [ ! -d "$ANTLR_DIR" ]; then
    echo "Cloning ANTLR4 (${ANTLR_TAG})..."
    git clone --depth 1 --branch "$ANTLR_TAG" https://github.com/antlr/antlr4.git "$ANTLR_DIR"
else
    echo "ANTLR source found at $ANTLR_DIR (Skipping clone)"
fi

echo "=== Building LLVM ==="
cd "$LLVM_DIR"
git checkout "$LLVM_COMMIT"
rm -rf build && mkdir build && cd build

export CC="clang"
export CXX="clang++"

if [ "$ENABLE_BOOTSTRAP" = true ]; then
    echo "=== Using Bootstrap build method ==="

    cmake -G Ninja ../llvm \
        -DCMAKE_BUILD_TYPE=Release \
        \
        -DCLANG_ENABLE_BOOTSTRAP=ON \
        -DCLANG_BOOTSTRAP_PASSTHROUGH="LLVM_ENABLE_PROJECTS;LLVM_ENABLE_RUNTIMES;LLVM_TARGETS_TO_BUILD;LIBCXX_ENABLE_SHARED;LIBCXX_ENABLE_STATIC;LIBCXX_ENABLE_STATIC_ABI_LIBRARY;LIBCXXABI_ENABLE_SHARED;LIBCXXABI_ENABLE_STATIC;LIBCXXABI_USE_LLVM_UNWINDER;LIBUNWIND_ENABLE_SHARED;LIBUNWIND_ENABLE_STATIC;CLANG_DEFAULT_CXX_STDLIB" \
        \
        -DBOOTSTRAP_CMAKE_INSTALL_PREFIX="$DIST_DIR" \
        -DBOOTSTRAP_LLVM_STATIC_LINK_CXX_STDLIB=ON \
        -DBOOTSTRAP_CMAKE_CXX_FLAGS="-stdlib=libc++" \
        -DBOOTSTRAP_CMAKE_EXE_LINKER_FLAGS="-stdlib=libc++ -static-libstdc++" \
        -DBOOTSTRAP_LLVM_INSTALL_UTILS=ON \
        \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_ENABLE_STATIC=ON \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_ENABLE_STATIC=ON \
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DLIBUNWIND_ENABLE_SHARED=OFF \
        -DLIBUNWIND_ENABLE_STATIC=ON \
        \
        -DLIBCXX_INSTALL_MODULES=ON \
        \
        -DCMAKE_INSTALL_PREFIX="$LLVM_DIR/build/stage1-install" \
        -DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF

    ninja stage2-install
else
    echo "=== Using default (single-stage) build method ==="

    cmake -G Ninja ../llvm \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DCMAKE_INSTALL_PREFIX="$DIST_DIR" \
        \
        -DLLVM_INSTALL_UTILS=ON \
        \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        -DCLANG_DEFAULT_RTLIB=compiler-rt \
        -DCLANG_DEFAULT_UNWINDLIB=libunwind \
        \
        -DLIBCXX_USE_COMPILER_RT=YES \
        -DLIBCXXABI_USE_COMPILER_RT=YES \
        -DLIBCXXABI_USE_LLVM_UNWINDER=YES \
        -DLIBUNWIND_USE_COMPILER_RT=YES \
        \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_ENABLE_STATIC=ON \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_ENABLE_STATIC=ON \
        -DLIBUNWIND_ENABLE_SHARED=OFF \
        -DLIBUNWIND_ENABLE_STATIC=ON \
        \
        -DLIBCXX_INSTALL_MODULES=ON \
        \
        -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
        -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
        -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++"

    ninja install
fi

echo "=== Building ANTLR Runtime ==="
cd "${ANTLR_DIR}/runtime/Cpp"
rm -rf build && mkdir build && cd build

export CC="${DIST_DIR}/bin/clang"
export CXX="${DIST_DIR}/bin/clang++"

echo "Checking custom compiler version..."
$CXX --version

cmake -G Ninja .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$DIST_DIR" \
    -DANTLR4_INSTALL=ON \
    -DWITH_DEMO=OFF \
    -DANTLR_BUILD_CPP_TESTS=OFF \
    -DCMAKE_CXX_STANDARD=23 \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++"

ninja install

echo "=== Toolchain Build Complete ==="
echo "Artifacts located in: $DIST_DIR"
