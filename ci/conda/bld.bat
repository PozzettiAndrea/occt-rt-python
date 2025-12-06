@echo off

REM Use Visual Studio generator - it finds the compiler automatically
mkdir build
cd build

cmake -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DPython3_EXECUTABLE=%PYTHON% ^
    -DOCCT_RT_DIR=%SRC_DIR%\external\OCCT-RT ^
    ..
if errorlevel 1 exit 1

cmake --build . --config Release --parallel
if errorlevel 1 exit 1

xcopy /E /I occt_rt %SP_DIR%\occt_rt
if errorlevel 1 exit 1
