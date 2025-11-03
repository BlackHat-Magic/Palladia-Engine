#pragma once

#include <ecs/ecs.h>
#include <geometry/g_common.h>

#define PAL_OctahedronMeshCreateInfo PAL_PlatonicMeshCreateInfo

PAL_MeshComponent*
PAL_CreateOctahedronMesh (static PAL_OctahedronMeshCreateInfo* info);