"""
High-level Pythonic wrapper for OCCT-RT raytracer.

This module provides an easy-to-use API for ray-surface intersection
that integrates seamlessly with pythonocc-core.
"""

from enum import Enum
from typing import Dict, Optional, Tuple, Union
import numpy as np

# Import the SWIG-generated bindings
from . import _OCCTRT


class Backend(Enum):
    """BVH backend selection for ray-triangle intersection."""

    OCCT = "occt"  # OCCT's built-in BVH (fastest for single rays)
    EMBREE = "embree"  # Embree scalar (single ray)
    EMBREE_SIMD4 = "embree_simd4"  # Embree SSE (4 rays at once)
    EMBREE_SIMD8 = "embree_simd8"  # Embree AVX (8 rays at once)


# Map string names to enum values
_BACKEND_MAP = {
    "occt": _OCCTRT.BRepIntCurveSurface_BVHBackend_OCCT_BVH,
    "embree": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_Scalar,
    "embree_scalar": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_Scalar,
    "embree_simd4": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD4,
    "embree4": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD4,
    "embree_simd8": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD8,
    "embree8": _OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD8,
}


class Raytracer:
    """
    High-performance BVH-accelerated ray-surface intersection.

    This class wraps the BRepIntCurveSurface_InterBVH C++ class with a
    Pythonic API that integrates with pythonocc-core.

    Example:
        >>> from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeSphere
        >>> sphere = BRepPrimAPI_MakeSphere(50).Shape()
        >>> rt = Raytracer(sphere, deflection=0.1, backend='occt')
        >>> result = rt.cast_ray((0, 0, 100), (0, 0, -1))
        >>> print(result['point'])
        [0. 0. 50.]

    Args:
        shape: A TopoDS_Shape from pythonocc (must be tessellated or will be auto-tessellated)
        tolerance: Intersection tolerance (default: 0.001)
        deflection: Tessellation deflection - smaller = finer mesh (default: 0.1)
        backend: BVH backend - 'occt', 'embree', 'embree_simd4', 'embree_simd8' (default: 'occt')
        openmp: Enable OpenMP parallelization for batch operations (default: True)
    """

    def __init__(
        self,
        shape,
        tolerance: float = 0.001,
        deflection: float = 0.1,
        backend: Union[str, Backend] = "occt",
        openmp: bool = True,
    ):
        # Tessellate the shape if not already done
        try:
            from OCC.Core.BRepMesh import BRepMesh_IncrementalMesh

            BRepMesh_IncrementalMesh(shape, deflection)
        except ImportError:
            # pythonocc not available, assume shape is already tessellated
            pass

        # Create the C++ raytracer
        self._rt = _OCCTRT.BRepIntCurveSurface_InterBVH()

        # Set backend
        if isinstance(backend, Backend):
            backend = backend.value
        if backend not in _BACKEND_MAP:
            raise ValueError(
                f"Unknown backend '{backend}'. "
                f"Valid options: {list(_BACKEND_MAP.keys())}"
            )
        self._rt.SetBackend(_BACKEND_MAP[backend])

        # Set OpenMP
        self._rt.SetUseOpenMP(openmp)

        # Load shape and build BVH (use load_shape for pythonocc compatibility)
        self._rt.load_shape(shape, tolerance, deflection)

        # Store config
        self._tolerance = tolerance
        self._deflection = deflection
        self._backend = backend
        self._openmp = openmp

    @property
    def is_loaded(self) -> bool:
        """Check if shape has been loaded and BVH built."""
        return self._rt.IsLoaded()

    @property
    def num_faces(self) -> int:
        """Number of faces in the loaded shape."""
        return self._rt.NbFaces()

    @property
    def backend(self) -> str:
        """Current BVH backend name."""
        return self._backend

    @property
    def openmp_enabled(self) -> bool:
        """Whether OpenMP parallelization is enabled."""
        return self._rt.GetUseOpenMP()

    def cast_ray(
        self,
        origin: Tuple[float, float, float],
        direction: Tuple[float, float, float],
        min_dist: float = 0.0,
        max_dist: float = 1e308,
    ) -> Dict:
        """
        Cast a single ray and return hit information.

        Args:
            origin: Ray origin point (x, y, z)
            direction: Ray direction (x, y, z) - will be normalized
            min_dist: Minimum distance along ray to consider (default: 0)
            max_dist: Maximum distance along ray to consider (default: infinity)

        Returns:
            Dictionary with hit information:
            - hit (bool): Whether the ray hit anything
            - point (ndarray[3]): Hit point coordinates (if hit)
            - normal (ndarray[3]): Surface normal at hit (if hit)
            - uv (ndarray[2]): UV parameters on surface (if hit)
            - w (float): Distance along ray (if hit)
            - face_id (int): Index of hit face (if hit)
        """
        # Create gp_Lin
        pnt = _OCCTRT.gp_Pnt(origin[0], origin[1], origin[2])
        dir_ = _OCCTRT.gp_Dir(direction[0], direction[1], direction[2])
        ray = _OCCTRT.gp_Lin(pnt, dir_)

        # Perform intersection
        self._rt.Perform(ray, min_dist, max_dist)

        if not self._rt.IsDone() or self._rt.NbPnt() == 0:
            return {"hit": False}

        # Extract results (1-based indexing in C++ API)
        hit_pnt = self._rt.Pnt(1)
        normal = self._rt.Normal(1)

        return {
            "hit": True,
            "point": np.array([hit_pnt.X(), hit_pnt.Y(), hit_pnt.Z()]),
            "normal": np.array([normal.X(), normal.Y(), normal.Z()]),
            "uv": np.array([self._rt.U(1), self._rt.V(1)]),
            "w": self._rt.W(1),
            "face_id": 1,  # TODO: get actual face index
        }

    def cast_rays(
        self,
        origins: np.ndarray,
        directions: np.ndarray,
    ) -> Dict[str, np.ndarray]:
        """
        Cast multiple rays in batch (uses OpenMP if enabled).

        Args:
            origins: Nx3 array of ray origins
            directions: Nx3 array of ray directions

        Returns:
            Dictionary with NumPy arrays:
            - hits (bool[N]): Whether each ray hit
            - points (float[N,3]): Hit points
            - normals (float[N,3]): Surface normals
            - uvs (float[N,2]): UV parameters
            - ws (float[N]): Distances along rays
            - face_ids (int[N]): Face indices (-1 if no hit)
        """
        origins = np.asarray(origins, dtype=np.float64)
        directions = np.asarray(directions, dtype=np.float64)

        if origins.ndim == 1:
            origins = origins.reshape(1, 3)
        if directions.ndim == 1:
            directions = directions.reshape(1, 3)

        return self._rt.cast_rays_numpy(origins, directions)

    def render_orthographic(
        self,
        resolution: Tuple[int, int],
        bounds: Tuple[float, float, float, float],
        axis: str = "z",
        offset: float = 100.0,
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Render orthographic depth and normal maps.

        Args:
            resolution: (width, height) of output images
            bounds: (xmin, ymin, xmax, ymax) bounding box in view plane
            axis: View axis - 'x', 'y', or 'z' (default: 'z' = top-down)
            offset: Distance to start rays from above bounds (default: 100)

        Returns:
            Tuple of (depth_map, normal_map, face_id_map):
            - depth_map: float32[H,W] - Z heights (NaN where no hit)
            - normal_map: float32[H,W,3] - Surface normals
            - face_id_map: int32[H,W] - Face indices (-1 where no hit)
        """
        width, height = resolution
        xmin, ymin, xmax, ymax = bounds

        # Generate ray grid
        xs = np.linspace(xmin, xmax, width)
        ys = np.linspace(ymax, ymin, height)  # Flip Y for image coords
        xx, yy = np.meshgrid(xs, ys)

        n_rays = width * height

        # Set up ray origins and directions based on axis
        if axis.lower() == "z":
            # Top-down view (Z axis)
            zmax = offset  # Assume rays start from above
            origins = np.column_stack(
                [xx.ravel(), yy.ravel(), np.full(n_rays, zmax)]
            )
            directions = np.tile([0.0, 0.0, -1.0], (n_rays, 1))
        elif axis.lower() == "y":
            # Front view (Y axis)
            origins = np.column_stack(
                [xx.ravel(), np.full(n_rays, offset), yy.ravel()]
            )
            directions = np.tile([0.0, -1.0, 0.0], (n_rays, 1))
        elif axis.lower() == "x":
            # Side view (X axis)
            origins = np.column_stack(
                [np.full(n_rays, offset), xx.ravel(), yy.ravel()]
            )
            directions = np.tile([-1.0, 0.0, 0.0], (n_rays, 1))
        else:
            raise ValueError(f"axis must be 'x', 'y', or 'z', got '{axis}'")

        # Cast rays
        results = self.cast_rays(origins, directions)

        # Reshape results to images
        hits = results["hits"].reshape(height, width)
        points = results["points"].reshape(height, width, 3)
        normals = results["normals"].reshape(height, width, 3)
        face_ids = results["face_ids"].reshape(height, width)

        # Create depth map (Z coordinate for z-axis view, etc.)
        if axis.lower() == "z":
            depth = points[:, :, 2].copy()
        elif axis.lower() == "y":
            depth = points[:, :, 1].copy()
        else:
            depth = points[:, :, 0].copy()

        # Set NaN where no hit
        depth[~hits] = np.nan

        return (
            depth.astype(np.float32),
            normals.astype(np.float32),
            face_ids.astype(np.int32),
        )

    def __repr__(self) -> str:
        return (
            f"Raytracer(faces={self.num_faces}, "
            f"backend='{self._backend}', "
            f"openmp={self._openmp})"
        )
