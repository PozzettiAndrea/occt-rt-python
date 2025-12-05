/*
 * OCCTRT.i - SWIG interface file for OCCT-RT High-Performance Raytracer
 * Copyright (c) 2024-2025 Andrea Pozzetti
 * LGPL-2.1 with OCCT Exception
 */

%module(package="occt_rt") _OCCTRT

%{
#include <Standard.hxx>
#include <Standard_Real.hxx>
#include <Standard_Integer.hxx>
#include <Standard_Boolean.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Face.hxx>
#include <IntCurveSurface_TransitionOnCurve.hxx>
#include <TopAbs_State.hxx>
#include <NCollection_Array1.hxx>

#include "BRepIntCurveSurface_InterBVH.hxx"

#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
#include <numpy/arrayobject.h>
%}

/* Initialize NumPy */
%init %{
import_array();
%}

/* Include standard SWIG typemaps */
%include "std_vector.i"
%include "exception.i"

/* Exception handling */
%exception {
    try {
        $action
    } catch (Standard_Failure& e) {
        SWIG_exception(SWIG_RuntimeError, e.GetMessageString());
    } catch (std::exception& e) {
        SWIG_exception(SWIG_RuntimeError, e.what());
    } catch (...) {
        SWIG_exception(SWIG_RuntimeError, "Unknown exception");
    }
}

/* Standard types */
typedef double Standard_Real;
typedef int Standard_Integer;
typedef bool Standard_Boolean;

/* gp_Pnt - 3D Point */
class gp_Pnt {
public:
    gp_Pnt();
    gp_Pnt(Standard_Real X, Standard_Real Y, Standard_Real Z);
    Standard_Real X() const;
    Standard_Real Y() const;
    Standard_Real Z() const;
    void SetX(Standard_Real X);
    void SetY(Standard_Real Y);
    void SetZ(Standard_Real Z);
    void SetCoord(Standard_Real X, Standard_Real Y, Standard_Real Z);
};

/* gp_Dir - Direction (normalized vector) */
class gp_Dir {
public:
    gp_Dir();
    gp_Dir(Standard_Real X, Standard_Real Y, Standard_Real Z);
    gp_Dir(const gp_Vec& V);
    Standard_Real X() const;
    Standard_Real Y() const;
    Standard_Real Z() const;
};

/* gp_Vec - 3D Vector */
class gp_Vec {
public:
    gp_Vec();
    gp_Vec(Standard_Real X, Standard_Real Y, Standard_Real Z);
    gp_Vec(const gp_Pnt& P1, const gp_Pnt& P2);
    Standard_Real X() const;
    Standard_Real Y() const;
    Standard_Real Z() const;
};

/* gp_Lin - Line (point + direction) */
class gp_Lin {
public:
    gp_Lin();
    gp_Lin(const gp_Pnt& P, const gp_Dir& D);
    const gp_Pnt& Location() const;
    const gp_Dir& Direction() const;
};

/* gp_Pnt2d - 2D Point (for UV coordinates) */
class gp_Pnt2d {
public:
    gp_Pnt2d();
    gp_Pnt2d(Standard_Real X, Standard_Real Y);
    Standard_Real X() const;
    Standard_Real Y() const;
};

/* Forward declaration for opaque TopoDS types */
class TopoDS_Shape;
class TopoDS_Face;

/* Make TopoDS_Shape work with pythonocc
 * pythonocc stores the shape pointer in a 'this' attribute as a SwigPyObject
 * We can get the pointer value via int(this_attr)
 */
%typemap(in) const TopoDS_Shape& (TopoDS_Shape* temp_ptr) {
    // pythonocc wraps TopoDS_Shape with a 'this' attribute containing SWIG ptr
    PyObject* this_attr = PyObject_GetAttrString($input, "this");
    if (this_attr) {
        // SwigPyObject supports __int__ which returns the pointer value
        PyObject* ptr_as_long = PyNumber_Long(this_attr);
        if (ptr_as_long) {
            temp_ptr = (TopoDS_Shape*)PyLong_AsVoidPtr(ptr_as_long);
            Py_DECREF(ptr_as_long);
        } else {
            Py_DECREF(this_attr);
            PyErr_Clear();
            SWIG_exception(SWIG_TypeError, "Cannot extract pointer from pythonocc shape");
        }
        Py_DECREF(this_attr);
        if (temp_ptr) {
            $1 = temp_ptr;
        } else {
            SWIG_exception(SWIG_TypeError, "NULL pointer from pythonocc shape");
        }
    } else {
        PyErr_Clear();
        // Maybe it's already a raw pointer or our own type
        void *argp = 0;
        int res = SWIG_ConvertPtr($input, &argp, SWIGTYPE_p_TopoDS_Shape, 0);
        if (SWIG_IsOK(res) && argp) {
            $1 = reinterpret_cast<TopoDS_Shape*>(argp);
        } else {
            SWIG_exception(SWIG_TypeError, "Expected TopoDS_Shape from pythonocc");
        }
    }
}

/* Enums */
enum class BRepIntCurveSurface_BVHBackend {
    OCCT_BVH,
    Embree_Scalar,
    Embree_SIMD4,
    Embree_SIMD8
};

enum IntCurveSurface_TransitionOnCurve {
    IntCurveSurface_Tangent,
    IntCurveSurface_In,
    IntCurveSurface_Out
};

enum TopAbs_State {
    TopAbs_IN,
    TopAbs_OUT,
    TopAbs_ON,
    TopAbs_UNKNOWN
};

/* Hit result structure */
struct BRepIntCurveSurface_HitResult {
    Standard_Boolean IsValid;
    gp_Pnt Point;
    Standard_Real U;
    Standard_Real V;
    Standard_Real W;
    Standard_Integer FaceIndex;
    gp_Dir Normal;
    IntCurveSurface_TransitionOnCurve Transition;
    TopAbs_State State;
    Standard_Real GaussianCurvature;
    Standard_Real MeanCurvature;
    Standard_Real MinCurvature;
    Standard_Real MaxCurvature;

    BRepIntCurveSurface_HitResult();
};

/* Main raytracer class - hide Load, expose via %extend */
class BRepIntCurveSurface_InterBVH {
public:
    BRepIntCurveSurface_InterBVH();
    ~BRepIntCurveSurface_InterBVH();

    // Load is hidden, use load_shape from %extend instead
    %ignore Load;

    void Perform(const gp_Lin& theLine,
                 const Standard_Real theMin = 0.0,
                 const Standard_Real theMax = 1e308);

    Standard_Boolean IsDone() const;
    Standard_Integer NbPnt() const;

    const gp_Pnt& Pnt(const Standard_Integer theIndex) const;
    Standard_Real U(const Standard_Integer theIndex) const;
    Standard_Real V(const Standard_Integer theIndex) const;
    Standard_Real W(const Standard_Integer theIndex) const;
    gp_Dir Normal(const Standard_Integer theIndex) const;
    IntCurveSurface_TransitionOnCurve Transition(const Standard_Integer theIndex) const;
    TopAbs_State State(const Standard_Integer theIndex) const;

    Standard_Boolean IsLoaded() const;
    Standard_Integer NbFaces() const;

    void SetBackend(BRepIntCurveSurface_BVHBackend theBackend);
    BRepIntCurveSurface_BVHBackend GetBackend() const;

    void SetUseOpenMP(Standard_Boolean theUse);
    Standard_Boolean GetUseOpenMP() const;
};

/* Extend with Pythonic methods */
%extend BRepIntCurveSurface_InterBVH {
    /* Load shape from pythonocc - extracts pointer from SwigPyObject */
    void load_shape(PyObject* shape_obj, double tolerance, double deflection = 0.0) {
        // pythonocc wraps TopoDS_Shape with a 'this' attribute containing SWIG ptr
        PyObject* this_attr = PyObject_GetAttrString(shape_obj, "this");
        if (!this_attr) {
            PyErr_SetString(PyExc_TypeError, "Expected pythonocc shape with 'this' attribute");
            return;
        }

        // SwigPyObject supports __int__ which returns the pointer value
        PyObject* ptr_as_long = PyNumber_Long(this_attr);
        Py_DECREF(this_attr);

        if (!ptr_as_long) {
            PyErr_SetString(PyExc_TypeError, "Cannot extract pointer from pythonocc shape");
            return;
        }

        TopoDS_Shape* shape_ptr = (TopoDS_Shape*)PyLong_AsVoidPtr(ptr_as_long);
        Py_DECREF(ptr_as_long);

        if (!shape_ptr) {
            PyErr_SetString(PyExc_ValueError, "NULL pointer from pythonocc shape");
            return;
        }

        // Call the real Load method
        $self->Load(*shape_ptr, tolerance, deflection);
    }

    /* Cast multiple rays and return NumPy arrays */
    PyObject* cast_rays_numpy(PyObject* origins_obj, PyObject* directions_obj) {
        // Validate inputs
        PyArrayObject* origins = (PyArrayObject*)PyArray_FROM_OTF(origins_obj, NPY_FLOAT64, NPY_ARRAY_IN_ARRAY);
        PyArrayObject* directions = (PyArrayObject*)PyArray_FROM_OTF(directions_obj, NPY_FLOAT64, NPY_ARRAY_IN_ARRAY);

        if (!origins || !directions) {
            Py_XDECREF(origins);
            Py_XDECREF(directions);
            PyErr_SetString(PyExc_ValueError, "origins and directions must be numpy arrays");
            return NULL;
        }

        // Check dimensions
        if (PyArray_NDIM(origins) != 2 || PyArray_NDIM(directions) != 2) {
            Py_DECREF(origins);
            Py_DECREF(directions);
            PyErr_SetString(PyExc_ValueError, "origins and directions must be 2D arrays (N x 3)");
            return NULL;
        }

        npy_intp n_rays = PyArray_DIM(origins, 0);
        if (PyArray_DIM(origins, 1) != 3 || PyArray_DIM(directions, 1) != 3) {
            Py_DECREF(origins);
            Py_DECREF(directions);
            PyErr_SetString(PyExc_ValueError, "Second dimension must be 3 (x, y, z)");
            return NULL;
        }

        if (PyArray_DIM(directions, 0) != n_rays) {
            Py_DECREF(origins);
            Py_DECREF(directions);
            PyErr_SetString(PyExc_ValueError, "origins and directions must have same number of rows");
            return NULL;
        }

        // Get data pointers
        double* orig_data = (double*)PyArray_DATA(origins);
        double* dir_data = (double*)PyArray_DATA(directions);

        // Create output arrays
        npy_intp dims_n = n_rays;
        npy_intp dims_n3[2] = {n_rays, 3};
        npy_intp dims_n2[2] = {n_rays, 2};

        PyArrayObject* hits = (PyArrayObject*)PyArray_SimpleNew(1, &dims_n, NPY_BOOL);
        PyArrayObject* points = (PyArrayObject*)PyArray_SimpleNew(2, dims_n3, NPY_FLOAT64);
        PyArrayObject* normals = (PyArrayObject*)PyArray_SimpleNew(2, dims_n3, NPY_FLOAT64);
        PyArrayObject* uvs = (PyArrayObject*)PyArray_SimpleNew(2, dims_n2, NPY_FLOAT64);
        PyArrayObject* ws = (PyArrayObject*)PyArray_SimpleNew(1, &dims_n, NPY_FLOAT64);
        PyArrayObject* face_ids = (PyArrayObject*)PyArray_SimpleNew(1, &dims_n, NPY_INT32);

        if (!hits || !points || !normals || !uvs || !ws || !face_ids) {
            Py_DECREF(origins);
            Py_DECREF(directions);
            Py_XDECREF(hits);
            Py_XDECREF(points);
            Py_XDECREF(normals);
            Py_XDECREF(uvs);
            Py_XDECREF(ws);
            Py_XDECREF(face_ids);
            PyErr_SetString(PyExc_MemoryError, "Failed to allocate output arrays");
            return NULL;
        }

        npy_bool* hits_data = (npy_bool*)PyArray_DATA(hits);
        double* points_data = (double*)PyArray_DATA(points);
        double* normals_data = (double*)PyArray_DATA(normals);
        double* uvs_data = (double*)PyArray_DATA(uvs);
        double* ws_data = (double*)PyArray_DATA(ws);
        int32_t* face_ids_data = (int32_t*)PyArray_DATA(face_ids);

        // Perform raycasting
        for (npy_intp i = 0; i < n_rays; i++) {
            gp_Pnt origin(orig_data[i*3], orig_data[i*3+1], orig_data[i*3+2]);
            gp_Dir direction(dir_data[i*3], dir_data[i*3+1], dir_data[i*3+2]);
            gp_Lin ray(origin, direction);

            $self->Perform(ray);

            if ($self->IsDone() && $self->NbPnt() > 0) {
                hits_data[i] = 1;

                gp_Pnt p = $self->Pnt(1);
                points_data[i*3] = p.X();
                points_data[i*3+1] = p.Y();
                points_data[i*3+2] = p.Z();

                gp_Dir n = $self->Normal(1);
                normals_data[i*3] = n.X();
                normals_data[i*3+1] = n.Y();
                normals_data[i*3+2] = n.Z();

                uvs_data[i*2] = $self->U(1);
                uvs_data[i*2+1] = $self->V(1);

                ws_data[i] = $self->W(1);
                face_ids_data[i] = 1;  // Face() returns TopoDS_Face, need index
            } else {
                hits_data[i] = 0;
                points_data[i*3] = 0;
                points_data[i*3+1] = 0;
                points_data[i*3+2] = 0;
                normals_data[i*3] = 0;
                normals_data[i*3+1] = 0;
                normals_data[i*3+2] = 1;
                uvs_data[i*2] = 0;
                uvs_data[i*2+1] = 0;
                ws_data[i] = -1;
                face_ids_data[i] = -1;
            }
        }

        Py_DECREF(origins);
        Py_DECREF(directions);

        // Build result dictionary
        PyObject* result = PyDict_New();
        PyDict_SetItemString(result, "hits", (PyObject*)hits);
        PyDict_SetItemString(result, "points", (PyObject*)points);
        PyDict_SetItemString(result, "normals", (PyObject*)normals);
        PyDict_SetItemString(result, "uvs", (PyObject*)uvs);
        PyDict_SetItemString(result, "ws", (PyObject*)ws);
        PyDict_SetItemString(result, "face_ids", (PyObject*)face_ids);

        Py_DECREF(hits);
        Py_DECREF(points);
        Py_DECREF(normals);
        Py_DECREF(uvs);
        Py_DECREF(ws);
        Py_DECREF(face_ids);

        return result;
    }
}
