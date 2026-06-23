@echo off

REM The MSVC environment is activated by {{ compiler('cxx') }} (vs2022_win-64),
REM so cl.exe is on PATH; use the Ninja generator like the Unix build.sh.
mkdir build
cd build

cmake -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DPython3_EXECUTABLE=%PYTHON% ^
    -DOCCT_RT_DIR=%SRC_DIR%\external\OCCT-RT ^
    ..
if errorlevel 1 exit 1

cmake --build . --parallel
if errorlevel 1 exit 1

xcopy /E /I occt_rt %SP_DIR%\occt_rt
if errorlevel 1 exit 1

REM Bundle required OCCT DLLs into the package (NVIDIA-style)
mkdir %SP_DIR%\occt_rt\libs
copy %LIBRARY_BIN%\TKernel.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKMath.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKG2d.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKG3d.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKGeomBase.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKBRep.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKGeomAlgo.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKTopAlgo.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKMesh.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKShHealing.dll %SP_DIR%\occt_rt\libs\
copy %LIBRARY_BIN%\TKPrim.dll %SP_DIR%\occt_rt\libs\
REM Copy TBB runtime
copy %LIBRARY_BIN%\tbb12.dll %SP_DIR%\occt_rt\libs\ 2>nul
REM Copy Embree if present
copy %LIBRARY_BIN%\embree4.dll %SP_DIR%\occt_rt\libs\ 2>nul
