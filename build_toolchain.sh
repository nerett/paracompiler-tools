#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -d "$SCRIPT_DIR/../external/llvm-project" ]; then
    echo ">>> Detected 'repo' workspace layout."

    WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
    TOOLCHAIN_ROOT="$WORKSPACE_ROOT/external"
else
    echo ">>> Detected standalone/CI layout."

    WORKSPACE_ROOT="$(pwd)"
    TOOLCHAIN_ROOT="$WORKSPACE_ROOT/external"
fi

DIST_DIR="$TOOLCHAIN_ROOT/dist"
LLVM_DIR="$TOOLCHAIN_ROOT/llvm-project"
ANTLR_DIR="$TOOLCHAIN_ROOT/antlr4"

LLVM_TAG="main"
ANTLR_TAG="4.13.1"

LLVM_COMMIT="2e16cadd560f760f100030e575fe402f3f6b2eba"

echo "=== Configured Paths ==="
echo "Workspace:      $WORKSPACE_ROOT"
echo "Toolchain Src:  $TOOLCHAIN_ROOT"
echo "Destination:    $DIST_DIR"
echo "========================"

mkdir -p "$DIST_DIR"
mkdir -p "$TOOLCHAIN_ROOT"

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

cmake -G Ninja ../llvm \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
    -DLLVM_TARGETS_TO_BUILD="X86" \
    -DCMAKE_INSTALL_PREFIX="$DIST_DIR" \
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
