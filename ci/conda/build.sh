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

cp -r occt_rt $SP_DIR/

# Bundle required OCCT shared libraries (NVIDIA-style)
mkdir -p $SP_DIR/occt_rt/libs
for lib in TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo TKMesh TKShHealing TKPrim; do
    cp $PREFIX/lib/lib${lib}.so* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
done
# Copy TBB runtime
cp $PREFIX/lib/libtbb.so* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
# Copy Embree if present
cp $PREFIX/lib/libembree4.so* $SP_DIR/occt_rt/libs/ 2>/dev/null || true
