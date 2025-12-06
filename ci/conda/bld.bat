@echo off
setlocal EnableDelayedExpansion

mkdir build
cd build

cmake -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%PREFIX% ^
    -DPython3_EXECUTABLE=%PYTHON% ^
    -DOCCT_RT_DIR=%SRC_DIR%\external\OCCT-RT ^
    ..
if errorlevel 1 exit 1

cmake --build . --parallel --config Release
if errorlevel 1 exit 1

xcopy /E /I occt_rt %SP_DIR%\occt_rt
if errorlevel 1 exit 1
