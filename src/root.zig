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
};

pub const resource = struct {
    pub const Resources = @import("resource.zig").Resources;
};

pub const system = struct {
    pub const SystemStage = @import("system/context.zig").SystemStage;
    pub const Time = @import("system/context.zig").Time;
    pub const Input = @import("system/context.zig").Input;
    pub const ActiveCamera = @import("system/context.zig").ActiveCamera;
    pub const Scheduler = @import("system/scheduler.zig").Scheduler;
};

pub const systems = struct {
    pub const FPSCameraEventSystem = @import("systems/fpscontroller.zig").FPSCameraEventSystem;
    pub const FPSCameraUpdateSystem = @import("systems/fpscontroller.zig").FPSCameraUpdateSystem;
    pub const RenderSystem = @import("systems/render.zig").RenderSystem;
};

pub const math = struct {
    pub const Vec2 = @import("math.zig").Vec2;
    pub const Vec3 = @import("math.zig").Vec3;
    pub const Vec4 = @import("math.zig").Vec4;
    pub const Mat4 = @import("math.zig").Mat4;
    pub const pi = @import("math.zig").pi;

    pub const vec2Add = @import("math.zig").vec2Add;
    pub const vec2Sub = @import("math.zig").vec2Sub;
    pub const vec2Scale = @import("math.zig").vec2Scale;
    pub const vec2Normalize = @import("math.zig").vec2Normalize;
    pub const vec2Dot = @import("math.zig").vec2Dot;
    pub const vec2Cross = @import("math.zig").vec2Cross;

    pub const vec3Add = @import("math.zig").vec3Add;
    pub const vec3Sub = @import("math.zig").vec3Sub;
    pub const vec3Scale = @import("math.zig").vec3Scale;
    pub const vec3Normalize = @import("math.zig").vec3Normalize;
    pub const vec3Dot = @import("math.zig").vec3Dot;
    pub const vec3Cross = @import("math.zig").vec3Cross;

    pub const vec4Add = @import("math.zig").vec4Add;
    pub const vec4Sub = @import("math.zig").vec4Sub;
    pub const vec4Scale = @import("math.zig").vec4Scale;
    pub const vec4Normalize = @import("math.zig").vec4Normalize;
    pub const vec4Dot = @import("math.zig").vec4Dot;

    pub const quatFromEuler = @import("math.zig").quatFromEuler;
    pub const eulerFromQuat = @import("math.zig").eulerFromQuat;
    pub const quatMultiply = @import("math.zig").quatMultiply;
    pub const quatConjugate = @import("math.zig").quatConjugate;
    pub const quatNormalize = @import("math.zig").quatNormalize;
    pub const quatFromAxisAngle = @import("math.zig").quatFromAxisAngle;
    pub const vec3Rotate = @import("math.zig").vec3Rotate;

    pub const mat4Identity = @import("math.zig").mat4Identity;
    pub const mat4Translate = @import("math.zig").mat4Translate;
    pub const mat4RotateX = @import("math.zig").mat4RotateX;
    pub const mat4RotateY = @import("math.zig").mat4RotateY;
    pub const mat4RotateZ = @import("math.zig").mat4RotateZ;
    pub const mat4RotateQuat = @import("math.zig").mat4RotateQuat;
    pub const mat4Scale = @import("math.zig").mat4Scale;
    pub const mat4Multiply = @import("math.zig").mat4Multiply;
    pub const mat4Perspective = @import("math.zig").mat4Perspective;
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

test {
    std.testing.refAllDeclsRecursive(@This());
}
