#include <geometry/cone.h>
#include <geometry/cylinder.h>

PAL_MeshComponent* PAL_CreateConeMesh (const PAL_ConeMeshCreateInfo* info) {
    // cylinder returns normals
    PAL_CylinderMeshCreateInfo cylinder_info = {
        .radius_top = 0.0f,
        .radius_bottom = info->radius,
        .height = info->height,
        .radial_segments = info->radial_segments,
        .height_segments = info->height_segments,
        .open_ended = info->open_ended,
        .theta_start = info->theta_start,
        .theta_length = info->theta_length,
        .device = info->device
    };
    return PAL_CreateCylinderMesh (&cylinder_info);
}