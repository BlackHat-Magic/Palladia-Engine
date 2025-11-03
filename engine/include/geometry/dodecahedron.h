#pragma once

#include <ecs/ecs.h>
#include <geometry/g_common.h>

#define PAL_DodecahedronMeshCreateInfo PAL_PlatonicMeshCreateInfo

PAL_MeshComponent
PAL_CreateDodecahedronMesh (static PAL_DodecahedronMeshCreateInfo* info);