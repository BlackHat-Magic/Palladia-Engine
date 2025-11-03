#include <geometry/cone.h>
#include <geometry/cylinder.h>

PAL_MeshComponent PAL_CreateConeMesh (static PAL_ConeMeshCreateInfo* info) {
    // cylinder returns normals
    return PAL_CreateCylinderMesh (
        0.0f, info->radius, info->height, info->radial_segments,
        info->height_segments, info->open_ended, info->theta_start,
        info->theta_length, info->device
    );
}