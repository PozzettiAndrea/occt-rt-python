#!/bin/bash
set -ex

mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DPython3_EXECUTABLE=$PYTHON \
    -DOCCT_RT_DIR=$SRC_DIR/external/OCCT-RT

cmake --build . --parallel --config Release

echo "=== Files in build/occt_rt after build ==="
ls -la occt_rt/
echo "=== End file listing ==="

cp -r occt_rt $SP_DIR/

echo "=== Files in $SP_DIR/occt_rt after copy ==="
ls -la $SP_DIR/occt_rt/
echo "=== End file listing ==="

# Detect platform for correct library extension
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_EXT="dylib"
else
    LIB_EXT="so"
fi

# Bundle required OCCT shared libraries (NVIDIA-style)
mkdir -p $SP_DIR/occt_rt/libs
for lib in TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo TKMesh TKShHealing TKPrim; do
    cp $PREFIX/lib/lib${lib}.*${LIB_EXT}* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
done
# Copy TBB runtime
cp $PREFIX/lib/libtbb.*${LIB_EXT}* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
# Copy Embree if present
cp $PREFIX/lib/libembree4.*${LIB_EXT}* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
