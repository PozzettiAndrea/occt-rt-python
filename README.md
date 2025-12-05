# OCCT-RT Python Bindings

Python bindings for [OCCT-RT](https://github.com/PozzettiAndrea/OCCT-RT), a high-performance BVH raytracer for OpenCASCADE.

## Features

- **High Performance**: 6M+ rays/sec on 8-core systems using BVH acceleration
- **Multiple Backends**:
  - OCCT's built-in BVH (default, no extra dependencies)
  - Intel Embree with SIMD support (optional, SSE4/AVX)
- **OpenMP Parallelization**: Automatic multi-threaded batch ray processing
- **NumPy Integration**: Efficient batch operations with NumPy arrays
- **pythonocc Compatible**: Works seamlessly with pythonocc-core shapes

## Installation

### Via Conda (Recommended)

```bash
conda install -c conda-forge pythonocc-core
conda install -c pozzettiandrea occt-rt
```

### From Source

```bash
# Prerequisites
conda install -c conda-forge occt pythonocc-core swig cmake numpy

# Clone repository
git clone https://github.com/PozzettiAndrea/occt-rt-python.git
cd occt-rt-python
git submodule update --init --recursive

# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel

# The built module is in build/occt_rt/
# Add to PYTHONPATH or install:
pip install ..
```

## Quick Start

```python
from occt_rt import Raytracer
from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox
import numpy as np

# Create a box (100x100x50)
box = BRepPrimAPI_MakeBox(100, 100, 50).Shape()

# Create raytracer
rt = Raytracer(box, deflection=0.1, backend='occt', openmp=True)
print(rt)  # Raytracer(faces=6, backend='occt', openmp=True)

# Cast single ray from above
result = rt.cast_ray(origin=(50, 50, 100), direction=(0, 0, -1))
if result['hit']:
    print(f"Hit at: {result['point']}")      # [50. 50. 50.]
    print(f"Normal: {result['normal']}")     # [0. 0. 1.]
    print(f"UV: {result['uv']}")             # [50. 50.]
    print(f"Distance: {result['w']}")        # 50.0

# Cast multiple rays (uses OpenMP parallelization)
origins = np.array([
    [50, 50, 100],
    [25, 25, 100],
    [75, 75, 100],
    [200, 200, 100],  # This one misses
])
directions = np.array([
    [0, 0, -1],
    [0, 0, -1],
    [0, 0, -1],
    [0, 0, -1],
])
results = rt.cast_rays(origins, directions)
print(f"Hits: {results['hits']}")  # [ True  True  True False]

# Render orthographic depth map
depth, normals, face_ids = rt.render_orthographic(
    resolution=(512, 512),
    bounds=(-10, -10, 110, 110),
    axis='z',
    offset=100
)
# depth: float32[512,512] - Z heights (NaN where no hit)
# normals: float32[512,512,3] - Surface normals
# face_ids: int32[512,512] - Face indices (-1 where no hit)
```

## API Reference

### High-Level API: `Raytracer` Class

```python
from occt_rt import Raytracer

rt = Raytracer(
    shape,              # TopoDS_Shape from pythonocc
    tolerance=0.001,    # Intersection tolerance
    deflection=0.1,     # Tessellation deflection (smaller = finer mesh)
    backend='occt',     # 'occt', 'embree', 'embree_simd4', 'embree_simd8'
    openmp=True         # Enable parallel batch processing
)
```

#### Methods

##### `cast_ray(origin, direction, min_dist=0.0, max_dist=1e308) -> dict`

Cast a single ray and return hit information.

```python
result = rt.cast_ray(origin=(0, 0, 100), direction=(0, 0, -1))

# Returns dict:
{
    'hit': True,                    # bool - Whether ray hit anything
    'point': array([x, y, z]),      # ndarray[3] - Hit point coordinates
    'normal': array([nx, ny, nz]),  # ndarray[3] - Surface normal at hit
    'uv': array([u, v]),            # ndarray[2] - UV parameters on surface
    'w': 50.0,                      # float - Distance along ray
    'face_id': 1,                   # int - Index of hit face
}
# If no hit: {'hit': False}
```

##### `cast_rays(origins, directions) -> dict`

Cast multiple rays in batch (parallelized with OpenMP).

```python
origins = np.array([[0,0,100], [10,0,100], [20,0,100]])     # Nx3
directions = np.array([[0,0,-1], [0,0,-1], [0,0,-1]])       # Nx3

results = rt.cast_rays(origins, directions)

# Returns dict of NumPy arrays:
{
    'hits': array([True, True, False]),     # bool[N]
    'points': array([[x,y,z], ...]),        # float64[N,3]
    'normals': array([[nx,ny,nz], ...]),    # float64[N,3]
    'uvs': array([[u,v], ...]),             # float64[N,2]
    'ws': array([w1, w2, ...]),             # float64[N]
    'face_ids': array([1, 2, -1]),          # int32[N] (-1 = no hit)
}
```

##### `render_orthographic(resolution, bounds, axis='z', offset=100.0) -> tuple`

Render orthographic depth and normal maps.

```python
depth, normals, face_ids = rt.render_orthographic(
    resolution=(512, 512),          # (width, height)
    bounds=(-60, -60, 60, 60),      # (xmin, ymin, xmax, ymax)
    axis='z',                       # View axis: 'x', 'y', or 'z'
    offset=100.0                    # Distance to start rays from
)

# Returns:
# depth: float32[H,W] - Heights along view axis (NaN where no hit)
# normals: float32[H,W,3] - Surface normals
# face_ids: int32[H,W] - Face indices (-1 where no hit)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `is_loaded` | bool | Whether shape is loaded and BVH built |
| `num_faces` | int | Number of faces in the loaded shape |
| `backend` | str | Current backend name |
| `openmp_enabled` | bool | Whether OpenMP is enabled |

### Low-Level API: `_OCCTRT` Module

Direct access to SWIG-wrapped C++ classes:

```python
from occt_rt import _OCCTRT

# Geometry types
pnt = _OCCTRT.gp_Pnt(1.0, 2.0, 3.0)
dir = _OCCTRT.gp_Dir(0.0, 0.0, 1.0)
ray = _OCCTRT.gp_Lin(pnt, dir)

# Raytracer
rt = _OCCTRT.BRepIntCurveSurface_InterBVH()
rt.SetBackend(_OCCTRT.BRepIntCurveSurface_BVHBackend_OCCT_BVH)
rt.SetUseOpenMP(True)
rt.load_shape(pythonocc_shape, tolerance=0.001, deflection=0.1)

# Single ray
rt.Perform(ray, min_dist, max_dist)
if rt.IsDone() and rt.NbPnt() > 0:
    hit_point = rt.Pnt(1)      # 1-based indexing
    normal = rt.Normal(1)
    u, v = rt.U(1), rt.V(1)
    w = rt.W(1)

# Batch rays (returns dict of NumPy arrays)
results = rt.cast_rays_numpy(origins_array, directions_array)
```

#### Backend Enum

```python
_OCCTRT.BRepIntCurveSurface_BVHBackend_OCCT_BVH      # OCCT built-in
_OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_Scalar # Embree single ray
_OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD4  # Embree SSE (4 rays)
_OCCTRT.BRepIntCurveSurface_BVHBackend_Embree_SIMD8  # Embree AVX (8 rays)
```

### Backend Options

| Backend | String | Description |
|---------|--------|-------------|
| OCCT BVH | `'occt'` | OCCT's built-in BVH (default, fastest for single rays) |
| Embree Scalar | `'embree'` | Embree rtcIntersect1 (requires Embree) |
| Embree SIMD4 | `'embree_simd4'` | Embree SSE, processes 4 rays at once |
| Embree SIMD8 | `'embree_simd8'` | Embree AVX, processes 8 rays at once |

## Build Commands Reference

### Prerequisites

```bash
# Create conda environment
conda create -n occt-rt python=3.10
conda activate occt-rt

# Install dependencies
conda install -c conda-forge occt pythonocc-core swig cmake numpy
```

### Build from Source

```bash
# Clone
git clone https://github.com/PozzettiAndrea/occt-rt-python.git
cd occt-rt-python
git submodule update --init --recursive

# Configure
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build . --parallel

# Test
python -c "from occt_rt import Raytracer; print('OK')"
```

### CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `CMAKE_BUILD_TYPE` | Release | Build type (Release/Debug) |
| `OCCT_RT_DIR` | external/OCCT-RT | Path to OCCT-RT source |

### Development Install

```bash
# After building, add to Python path
export PYTHONPATH=/path/to/occt-rt-python/build:$PYTHONPATH

# Or create symlink
ln -s /path/to/occt-rt-python/build/occt_rt ~/.local/lib/python3.10/site-packages/
```

### Run Tests

```bash
cd occt-rt-python
pytest test/ -v
```

## Performance

Benchmark on 8-core AMD EPYC (1M rays on tessellated sphere):

| Backend | Rays/sec |
|---------|----------|
| OCCT BVH + OpenMP | 6.2M |
| Embree SIMD8 + OpenMP | 8.5M |

## Troubleshooting

### Import Error: `_OCCTRT.so not found`

Make sure the build completed successfully and the module is in your Python path:
```bash
export PYTHONPATH=/path/to/occt-rt-python/build:$PYTHONPATH
```

### TypeError with pythonocc shapes

Ensure you're using a compatible pythonocc-core version (>=7.8) built against the same OCCT version.

### No hits on valid geometry

Make sure your shape is tessellated before creating the raytracer:
```python
from OCC.Core.BRepMesh import BRepMesh_IncrementalMesh
BRepMesh_IncrementalMesh(shape, deflection=0.1)
```

## License

LGPL-2.1 with OCCT Exception (same as OpenCASCADE)

## Author

Andrea Pozzetti (with Claude Code assistance)
