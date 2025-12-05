"""
Tests for OCCT-RT Python bindings.
"""

import numpy as np
import pytest


def test_import():
    """Test that the package can be imported."""
    from occt_rt import Raytracer, Backend

    assert Raytracer is not None
    assert Backend is not None


def test_backend_enum():
    """Test Backend enum values."""
    from occt_rt import Backend

    assert Backend.OCCT.value == "occt"
    assert Backend.EMBREE.value == "embree"
    assert Backend.EMBREE_SIMD4.value == "embree_simd4"
    assert Backend.EMBREE_SIMD8.value == "embree_simd8"


@pytest.fixture
def sphere_shape():
    """Create a simple sphere shape using pythonocc."""
    try:
        from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeSphere

        return BRepPrimAPI_MakeSphere(50.0).Shape()
    except ImportError:
        pytest.skip("pythonocc-core not installed")


@pytest.fixture
def box_shape():
    """Create a simple box shape using pythonocc."""
    try:
        from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox

        return BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape()
    except ImportError:
        pytest.skip("pythonocc-core not installed")


class TestRaytracer:
    """Tests for Raytracer class."""

    def test_create_raytracer(self, sphere_shape):
        """Test creating a raytracer from a shape."""
        from occt_rt import Raytracer

        rt = Raytracer(sphere_shape, deflection=0.1)
        assert rt.is_loaded
        assert rt.num_faces > 0
        assert rt.backend == "occt"

    def test_single_ray_hit(self, sphere_shape):
        """Test casting a single ray that hits the sphere."""
        from occt_rt import Raytracer

        rt = Raytracer(sphere_shape, deflection=0.1)

        # Ray from above, pointing down at center
        result = rt.cast_ray(
            origin=(0, 0, 100),
            direction=(0, 0, -1),
        )

        assert result["hit"] is True
        assert "point" in result
        assert "normal" in result
        assert "uv" in result
        assert "w" in result

        # Check hit point is on sphere surface (radius 50)
        point = result["point"]
        distance_from_center = np.linalg.norm(point)
        assert abs(distance_from_center - 50.0) < 0.1

        # Check normal points outward
        normal = result["normal"]
        assert normal[2] > 0  # Normal should point up at top of sphere

    def test_single_ray_miss(self, sphere_shape):
        """Test casting a ray that misses the sphere."""
        from occt_rt import Raytracer

        rt = Raytracer(sphere_shape, deflection=0.1)

        # Ray far to the side, pointing down
        result = rt.cast_ray(
            origin=(1000, 0, 100),
            direction=(0, 0, -1),
        )

        assert result["hit"] is False

    def test_batch_rays(self, sphere_shape):
        """Test casting multiple rays in batch."""
        from occt_rt import Raytracer

        rt = Raytracer(sphere_shape, deflection=0.1)

        # Create grid of rays
        n = 10
        xs = np.linspace(-60, 60, n)
        ys = np.linspace(-60, 60, n)
        xx, yy = np.meshgrid(xs, ys)

        origins = np.column_stack(
            [xx.ravel(), yy.ravel(), np.full(n * n, 100.0)]
        )
        directions = np.tile([0.0, 0.0, -1.0], (n * n, 1))

        results = rt.cast_rays(origins, directions)

        assert "hits" in results
        assert "points" in results
        assert "normals" in results
        assert len(results["hits"]) == n * n

        # Some rays should hit, some should miss
        n_hits = np.sum(results["hits"])
        assert n_hits > 0
        assert n_hits < n * n

    def test_render_orthographic(self, box_shape):
        """Test orthographic rendering."""
        from occt_rt import Raytracer

        rt = Raytracer(box_shape, deflection=0.05)

        depth, normals, face_ids = rt.render_orthographic(
            resolution=(64, 64),
            bounds=(-5, -10, 15, 30),
            axis="z",
            offset=50,
        )

        assert depth.shape == (64, 64)
        assert normals.shape == (64, 64, 3)
        assert face_ids.shape == (64, 64)

        # Check that we got some hits (non-NaN values)
        valid_hits = ~np.isnan(depth)
        assert np.sum(valid_hits) > 0

        # Box top face should have Z = 30
        # (within some tolerance due to tessellation)
        hit_depths = depth[valid_hits]
        assert np.max(hit_depths) > 25

    def test_different_backends(self, sphere_shape):
        """Test creating raytracers with different backends."""
        from occt_rt import Raytracer

        # OCCT backend (always available)
        rt_occt = Raytracer(sphere_shape, backend="occt")
        assert rt_occt.backend == "occt"

        # Embree backends may not be available
        try:
            rt_embree = Raytracer(sphere_shape, backend="embree")
            assert rt_embree.backend == "embree"
        except RuntimeError:
            pass  # Embree not compiled in

    def test_repr(self, sphere_shape):
        """Test string representation."""
        from occt_rt import Raytracer

        rt = Raytracer(sphere_shape)
        repr_str = repr(rt)
        assert "Raytracer" in repr_str
        assert "faces=" in repr_str
        assert "backend=" in repr_str


class TestLowLevelAPI:
    """Tests for low-level SWIG bindings."""

    def test_gp_types(self):
        """Test gp_Pnt, gp_Dir, gp_Lin."""
        from occt_rt._OCCTRT import gp_Pnt, gp_Dir, gp_Lin

        pnt = gp_Pnt(1.0, 2.0, 3.0)
        assert pnt.X() == 1.0
        assert pnt.Y() == 2.0
        assert pnt.Z() == 3.0

        dir_ = gp_Dir(0.0, 0.0, 1.0)
        assert dir_.Z() == 1.0

        lin = gp_Lin(pnt, dir_)
        assert lin.Location().X() == 1.0
        assert lin.Direction().Z() == 1.0

    def test_hit_result(self):
        """Test BRepIntCurveSurface_HitResult struct."""
        from occt_rt._OCCTRT import BRepIntCurveSurface_HitResult

        hit = BRepIntCurveSurface_HitResult()
        assert hit.IsValid is False
        assert hit.FaceIndex == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
