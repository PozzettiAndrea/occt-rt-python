# occt-rt-python: Python Bindings for OCCT-RT High-Performance Raytracer
# Copyright (c) 2024-2025 Andrea Pozzetti
# LGPL-2.1 with OCCT Exception

cmake_minimum_required(VERSION 3.18 FATAL_ERROR)
project(occt_rt_python VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

message(STATUS "=== occt-rt-python: Python Bindings for OCCT-RT ===")

# =============================================================================
# FIND DEPENDENCIES
# =============================================================================

# Python
find_package(Python3 REQUIRED COMPONENTS Interpreter Development NumPy)
message(STATUS "Python: ${Python3_EXECUTABLE} (${Python3_VERSION})")
message(STATUS "NumPy include: ${Python3_NumPy_INCLUDE_DIRS}")

# SWIG
find_package(SWIG 4.0 REQUIRED)
include(${SWIG_USE_FILE})
message(STATUS "SWIG: ${SWIG_EXECUTABLE} (${SWIG_VERSION})")

# OpenCASCADE
find_package(OpenCASCADE CONFIG QUIET)
if(NOT OpenCASCADE_FOUND)
    find_package(OpenCASCADE CONFIG QUIET
        PATHS
            /usr/local/lib/cmake/opencascade
            /opt/opencascade/lib/cmake/opencascade
            $ENV{CONDA_PREFIX}/lib/cmake/opencascade
    )
endif()

if(OpenCASCADE_FOUND)
    message(STATUS "OpenCASCADE: ${OpenCASCADE_VERSION} at ${OpenCASCADE_LIBRARY_DIR}")
else()
    message(FATAL_ERROR "OpenCASCADE not found! Install via conda: conda install -c conda-forge occt")
endif()

# OCCT-RT library
set(OCCT_RT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/OCCT-RT" CACHE PATH "Path to OCCT-RT source")

if(NOT EXISTS "${OCCT_RT_DIR}/src/BRepIntCurveSurface/BRepIntCurveSurface_InterBVH.hxx")
    message(FATAL_ERROR "OCCT-RT not found at ${OCCT_RT_DIR}. Please set OCCT_RT_DIR or run: git submodule update --init")
endif()
message(STATUS "OCCT-RT: ${OCCT_RT_DIR}")

# =============================================================================
# PORTABLE OCCT LIBRARY FINDER
# =============================================================================

function(find_occt_library VAR_NAME LIB_NAME)
    find_library(${VAR_NAME}
        NAMES ${LIB_NAME}
        PATHS ${OpenCASCADE_LIBRARY_DIR}
        NO_DEFAULT_PATH
    )
    if(NOT ${VAR_NAME})
        message(FATAL_ERROR "Could not find OCCT library: ${LIB_NAME}")
    endif()
endfunction()

find_occt_library(OCCT_TKTopAlgo TKTopAlgo)
find_occt_library(OCCT_TKBRep TKBRep)
find_occt_library(OCCT_TKMath TKMath)
find_occt_library(OCCT_TKernel TKernel)
find_occt_library(OCCT_TKG3d TKG3d)
find_occt_library(OCCT_TKGeomBase TKGeomBase)
find_occt_library(OCCT_TKMesh TKMesh)

# =============================================================================
# BUILD OCCT-RT AS STATIC LIBRARY
# =============================================================================

set(OCCT_RT_SOURCES
    ${OCCT_RT_DIR}/src/BRepIntCurveSurface/BRepIntCurveSurface_InterBVH.cxx
    ${OCCT_RT_DIR}/src/BRepIntCurveSurface/BRepIntCurveSurface_ZEvaluator.cxx
    ${OCCT_RT_DIR}/src/BRepIntCurveSurface/BRepIntCurveSurface_OverlapAnalyzer.cxx
)

add_library(occt_rt_core STATIC ${OCCT_RT_SOURCES})

target_include_directories(occt_rt_core PUBLIC
    ${OCCT_RT_DIR}/src/BRepIntCurveSurface
    ${OpenCASCADE_INCLUDE_DIR}
)

target_link_libraries(occt_rt_core PUBLIC
    ${OCCT_TKTopAlgo}
    ${OCCT_TKBRep}
    ${OCCT_TKMath}
    ${OCCT_TKernel}
    ${OCCT_TKG3d}
    ${OCCT_TKGeomBase}
    ${OCCT_TKMesh}
)

# Optional: OpenMP
find_package(OpenMP QUIET)
if(OpenMP_CXX_FOUND)
    target_link_libraries(occt_rt_core PUBLIC OpenMP::OpenMP_CXX)
    message(STATUS "OpenMP: enabled")
else()
    message(STATUS "OpenMP: not found")
endif()

# Optional: Embree 4
find_package(embree 4 QUIET CONFIG)
if(embree_FOUND)
    target_link_libraries(occt_rt_core PUBLIC embree)
    target_compile_definitions(occt_rt_core PUBLIC OCCT_USE_EMBREE)
    message(STATUS "Embree: ${embree_VERSION}")
else()
    message(STATUS "Embree: not found")
endif()

# =============================================================================
# SWIG PYTHON BINDINGS
# =============================================================================

set(CMAKE_SWIG_FLAGS -py3 -builtin)
set_property(SOURCE src/swig/wrapper/OCCTRT.i PROPERTY CPLUSPLUS ON)
set_property(SOURCE src/swig/wrapper/OCCTRT.i PROPERTY USE_TARGET_INCLUDE_DIRECTORIES TRUE)

swig_add_library(OCCTRT
    TYPE SHARED
    LANGUAGE python
    SOURCES src/swig/wrapper/OCCTRT.i
)

target_include_directories(OCCTRT PRIVATE
    ${OCCT_RT_DIR}/src/BRepIntCurveSurface
    ${OpenCASCADE_INCLUDE_DIR}
    ${Python3_INCLUDE_DIRS}
    ${Python3_NumPy_INCLUDE_DIRS}
)

target_link_libraries(OCCTRT PRIVATE
    occt_rt_core
    Python3::Module
    Python3::NumPy
)

# Set output directory (disable per-config subdirectories for multi-config generators)
# On Windows, .pyd files are DLLs so need RUNTIME_OUTPUT_DIRECTORY
set_target_properties(OCCTRT PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/occt_rt"
    LIBRARY_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/occt_rt"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/occt_rt"
    LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_BINARY_DIR}/occt_rt"
    LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_BINARY_DIR}/occt_rt"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/occt_rt"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/occt_rt"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/occt_rt"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_BINARY_DIR}/occt_rt"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_BINARY_DIR}/occt_rt"
    SWIG_USE_TARGET_INCLUDE_DIRECTORIES TRUE
    # Python extension modules need .so suffix on macOS (not .dylib)
    SUFFIX ".${Python3_SOABI}.so"
)

# Copy __init__.py to build directory
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/occt_rt/__init__.py
    ${CMAKE_BINARY_DIR}/occt_rt/__init__.py
    COPYONLY
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/occt_rt/raytracer.py
    ${CMAKE_BINARY_DIR}/occt_rt/raytracer.py
    COPYONLY
)

message(STATUS "=== occt-rt-python configuration complete ===")
