const std = @import("std");

pub const ecs = struct {
    pub const Entity = @import("ecs/pool.zig").Entity;
    pub const Pool = @import("ecs/pool.zig").Pool;
    pub const World = @import("ecs/world.zig").World;
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
