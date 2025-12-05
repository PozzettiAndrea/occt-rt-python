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

__version__ = "1.0.0"
__author__ = "Andrea Pozzetti"
__license__ = "LGPL-2.1"

from .raytracer import Raytracer, Backend

__all__ = ["Raytracer", "Backend"]
