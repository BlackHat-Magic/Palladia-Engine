#pragma once

#include <ecs/ecs.h>
#include <geometry/g_common.h>

#define PAL_TetrahedronMeshCreateInfo PAL_PlatonicMeshCreateInfo

PAL_MeshComponent*
PAL_CreateTetrahedronMesh (const PAL_TetrahedronMeshCreateInfo* info);