@echo off
setlocal EnableDelayedExpansion

REM Find and activate Visual Studio (vswhere is in conda build env)
for /f "usebackq tokens=*" %%i in (`vswhere.exe -latest -property installationPath`) do (
    call "%%i\VC\Auxiliary\Build\vcvars64.bat"
)

REM Clear CMAKE_GENERATOR to avoid conflicts
set "CMAKE_GENERATOR="

mkdir build
cd build

cmake -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DPython3_EXECUTABLE=%PYTHON% ^
    -DOCCT_RT_DIR=%SRC_DIR%\external\OCCT-RT ^
    ..
if errorlevel 1 exit 1

cmake --build . --parallel --config Release
if errorlevel 1 exit 1

xcopy /E /I occt_rt %SP_DIR%\occt_rt
if errorlevel 1 exit 1
