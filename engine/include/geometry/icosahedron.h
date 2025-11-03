#pragma once

#include <ecs/ecs.h>
#include <geometry/g_common.h>

#define PAL_IcosahedronMeshCreateInfo PAL_PlatonicMeshCreateInfo

PAL_MeshComponent*
PAL_CreateIcosahedronMesh (static PAL_IcosahedronMeshCreateInfo* info);