const std = @import("std");

pub const ecs = struct {
    pub const Entity = @import("pool.zig").Entity;
    pub const Pool = @import("pool.zig").Pool;
    pub const World = @import("world.zig").World;
};

pub const components = struct {
    pub const Transform = @import("components/transform.zig").Transform;
    pub const MeshComponent = @import("components/mesh.zig").MeshComponent;
    pub const CameraComponent = @import("components/camera.zig").CameraComponent;
    pub const MaterialComponent = @import("components/material.zig").MaterialComponent;
    pub const FPSCameraController = @import("components/fpscameracontroller.zig").FPSCameraController;
    pub const AmbientLightComponent = @import("components/ambientlight.zig").AmbientLightComponent;
    pub const GPUAmbientLight = @import("components/ambientlight.zig").GPUAmbientLight;
    pub const PointLightComponent = @import("components/pointlight.zig").PointLightComponent;
    pub const PointLight = @import("components/pointlight.zig").PointLight;
    pub const UIComponent = @import("components/ui.zig").UIComponent;
};

pub const geometry = struct {
    pub const createBox = @import("geometry/box.zig").createBox;
    pub const createSphere = @import("geometry/sphere.zig").createSphere;
    pub const createLathe = @import("geometry/lathe.zig").createLathe;
    pub const createCapsule = @import("geometry/capsule.zig").createCapsule;
    pub const createCircle = @import("geometry/circle.zig").createCircle;
    pub const createCone = @import("geometry/cone.zig").createCone;
    pub const createCylinder = @import("geometry/cylinder.zig").createCylinder;
    pub const createPlane = @import("geometry/plane.zig").createPlane;
    pub const createRing = @import("geometry/ring.zig").createRing;
    pub const createTorus = @import("geometry/torus.zig").createTorus;
    pub const createTetrahedron = @import("geometry/tetrahedron.zig").createTetrahedron;
    pub const createOctahedron = @import("geometry/octahedron.zig").createOctahedron;
    pub const createIcosahedron = @import("geometry/icosahedron.zig").createIcosahedron;
    pub const createDodecahedron = @import("geometry/dodecahedron.zig").createDodecahedron;
};

pub const material = struct {
    pub const loadShader = @import("material/common.zig").loadShader;
    pub const loadTexture = @import("material/common.zig").loadTexture;
    pub const createWhiteTexture = @import("material/common.zig").createWhiteTexture;
    pub const createPhongMaterial = @import("material/phong.zig").createPhongMaterial;
    pub const createBasicMaterial = @import("material/basic.zig").createBasicMaterial;
};

pub const World = ecs.World;
pub const Transform = components.Transform;
pub const MeshComponent = components.MeshComponent;
pub const CameraComponent = components.CameraComponent;
pub const MaterialComponent = components.MaterialComponent;
pub const FPSCameraController = components.FPSCameraController;
pub const AmbientLightComponent = components.AmbientLightComponent;
pub const PointLightComponent = components.PointLightComponent;
pub const UIComponent = components.UIComponent;

test {
    std.testing.refAllDeclsRecursive(@This());
}
