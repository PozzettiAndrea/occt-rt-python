"""
OCCT-RT: High-Performance BVH Raytracer for OpenCASCADE

A Python package providing fast ray-surface intersection for CAD shapes.

Example:
    >>> from occt_rt import Raytracer
    >>> from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox
    >>>
    >>> box = BRepPrimAPI_MakeBox(10, 10, 10).Shape()
    >>> rt = Raytracer(box, deflection=0.1)
    >>> result = rt.cast_ray(origin=(5, 5, 100), direction=(0, 0, -1))
    >>> print(result)
    {'hit': True, 'point': array([5., 5., 10.]), 'normal': array([0., 0., 1.]), ...}
"""
import os
import sys
import ctypes
import glob

__version__ = "1.1.0"
__author__ = "Andrea Pozzetti"
__license__ = "LGPL-2.1"

# Add bundled libs to search path BEFORE importing _OCCTRT
_libs_dir = os.path.join(os.path.dirname(__file__), 'libs')

if sys.platform == 'win32' and os.path.isdir(_libs_dir):
    # Windows: Use add_dll_directory (Python 3.8+) and PATH
    if hasattr(os, 'add_dll_directory'):
        os.add_dll_directory(_libs_dir)
    os.environ['PATH'] = _libs_dir + os.pathsep + os.environ.get('PATH', '')

elif sys.platform == 'linux' and os.path.isdir(_libs_dir):
    # Linux: Preload bundled shared libraries
    for lib_name in ['libTKernel.so', 'libTKMath.so', 'libTKG2d.so', 'libTKG3d.so',
                     'libTKGeomBase.so', 'libTKBRep.so', 'libTKGeomAlgo.so',
                     'libTKTopAlgo.so', 'libTKMesh.so']:
        lib_path = os.path.join(_libs_dir, lib_name)
        if os.path.exists(lib_path):
            try:
                ctypes.CDLL(lib_path, mode=ctypes.RTLD_GLOBAL)
            except OSError:
                pass

elif sys.platform == 'darwin' and os.path.isdir(_libs_dir):
    # macOS: Preload bundled shared libraries (use glob for versioned names)
    for lib_base in ['libTKernel', 'libTKMath', 'libTKG2d', 'libTKG3d',
                     'libTKGeomBase', 'libTKBRep', 'libTKGeomAlgo',
                     'libTKTopAlgo', 'libTKMesh']:
        # Match libTKernel.dylib, libTKernel.7.dylib, libTKernel.7.8.1.dylib, etc.
        matches = glob.glob(os.path.join(_libs_dir, lib_base + '*.dylib'))
        for lib_path in matches:
            try:
                ctypes.CDLL(lib_path, mode=ctypes.RTLD_GLOBAL)
            except OSError:
                pass

from .raytracer import Raytracer, Backend

__all__ = ["Raytracer", "Backend"]
