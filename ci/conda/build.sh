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
