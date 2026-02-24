const std = @import("std");
const sdl = @import("../sdl.zig").c;
const math = @import("../math.zig");
const SystemContext = @import("../system/context.zig").SystemContext;
const SystemStage = @import("../system/context.zig").SystemStage;
const Entity = @import("../pool.zig").Entity;
const Transform = @import("../components/transform.zig").Transform;
const FPSCameraController = @import("../components/fpscameracontroller.zig").FPSCameraController;

pub const FPSCameraEventSystem = struct {
    pub const stage = SystemStage.event;

    pub const Query = struct {
        transform: *Transform,
        controller: *const FPSCameraController,
    };

    pub fn runEntity(ctx: *const SystemContext, entity: Entity, q: Query) void {
        _ = entity;
        const event = ctx.event orelse return;

        if (event.type != sdl.SDL_EVENT_MOUSE_MOTION) return;

        const ctrl = q.controller;
        const trans = q.transform;

        const delta_yaw = event.motion.xrel * ctrl.mouse_sense;
        const delta_pitch = event.motion.yrel * ctrl.mouse_sense;

        const dq_yaw = math.quatFromAxisAngle(.{ 0, 1, 0 }, delta_yaw);
        trans.rotation = math.quatMultiply(dq_yaw, trans.rotation);

        var forward = math.vec3Rotate(trans.rotation, .{ 0, 0, -1 });
        const right = math.vec3Normalize(math.vec3Cross(forward, .{ 0, 1, 0 }));
        const dq_pitch = math.quatFromAxisAngle(right, delta_pitch);
        trans.rotation = math.quatMultiply(dq_pitch, trans.rotation);

        trans.rotation = math.quatNormalize(trans.rotation);

        forward = math.vec3Rotate(trans.rotation, .{ 0, 0, -1 });
        const curr_pitch = std.math.asin(forward[1]);
        const pitch_limit: f32 = std.math.pi * 0.49;
        if (curr_pitch > pitch_limit or curr_pitch < -pitch_limit) {
            const clamped_pitch = std.math.clamp(curr_pitch, -pitch_limit, pitch_limit);
            const curr_yaw = std.math.atan2(forward[0], forward[2]) + std.math.pi;
            trans.rotation = math.quatFromEuler(.{ clamped_pitch, curr_yaw, 0 });
        }
    }
};

pub const FPSCameraUpdateSystem = struct {
    pub const stage = SystemStage.update;

    pub const Query = struct {
        transform: *Transform,
        controller: *const FPSCameraController,
    };

    pub fn runEntity(ctx: *const SystemContext, entity: Entity, q: Query) void {
        _ = entity;
        const ctrl = q.controller;
        const trans = q.transform;
        const dt = ctx.dt;

        const forward = math.vec3Rotate(trans.rotation, .{ 0, 0, 1 });
        const right = math.vec3Rotate(trans.rotation, .{ 1, 0, 0 });
        const up = math.vec3Rotate(trans.rotation, .{ 0, 1, 0 });

        const keyboard = ctx.getKeyboardState();
        var motion: math.Vec3 = .{ 0, 0, 0 };

        if (keyboard[@intCast(sdl.SDL_SCANCODE_W)]) {
            motion = math.vec3Add(motion, forward);
        }
        if (keyboard[@intCast(sdl.SDL_SCANCODE_A)]) {
            motion = math.vec3Sub(motion, right);
        }
        if (keyboard[@intCast(sdl.SDL_SCANCODE_S)]) {
            motion = math.vec3Sub(motion, forward);
        }
        if (keyboard[@intCast(sdl.SDL_SCANCODE_D)]) {
            motion = math.vec3Add(motion, right);
        }
        if (keyboard[@intCast(sdl.SDL_SCANCODE_SPACE)]) {
            motion = math.vec3Add(motion, up);
        }

        motion = math.vec3Normalize(motion);
        motion = math.vec3Scale(motion, dt * ctrl.move_speed);
        trans.position = math.vec3Add(trans.position, motion);
    }
};
