#!/bin/bash
set -e

ROOT_DIR="$(pwd)"

TOOLCHAIN_ROOT="${ROOT_DIR}/../external"
DIST_DIR="${TOOLCHAIN_ROOT}/dist"

LLVM_DIR="${TOOLCHAIN_ROOT}/llvm-project/"
ANTLR_DIR="${TOOLCHAIN_ROOT}/antlr4"

LLVM_TAG="llvmorg-22-init"
ANTLR_TAG="4.13.1"

echo "=== Building Toolchain in $ROOT_DIR ==="
echo "=== Destination: $DIST_DIR ==="

mkdir -p "$DIST_DIR"

if [ ! -d "$LLVM_DIR" ]; then
    echo "Cloning LLVM Project (${LLVM_TAG})..."
    git clone --depth 1 --branch "$LLVM_TAG" https://github.com/llvm/llvm-project.git "$LLVM_DIR"
fi

if [ ! -d "$ANTLR_DIR" ]; then
    echo "Cloning ANTLR4 (${ANTLR_TAG})..."
    git clone --depth 1 --branch "$ANTLR_TAG" https://github.com/antlr/antlr4.git "$ANTLR_DIR"
fi

echo "=== Building LLVM ==="
cd "$LLVM_DIR"
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

cd "$ROOT_DIR"

echo "=== Building ANTLR Runtime ==="
cd "${ANTLR_DIR}/runtime/Cpp"
rm -rf build && mkdir build && cd build

export CC="${DIST_DIR}/bin/clang"
export CXX="${DIST_DIR}/bin/clang++"

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
