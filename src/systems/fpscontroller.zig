const std = @import("std");
const sdl = @import("../sdl.zig").c;
const math = @import("../math.zig");
const SystemStage = @import("../system/context.zig").SystemStage;
const Time = @import("../system/context.zig").Time;
const Input = @import("../system/context.zig").Input;
const Entity = @import("../pool.zig").Entity;
const Transform = @import("../components/transform.zig").Transform;
const FPSCameraController = @import("../components/fpscameracontroller.zig").FPSCameraController;

pub const FPSCameraEventSystem = struct {
    pub const stage = SystemStage.event;

    pub const Query = struct {
        transform: *Transform,
        controller: *const FPSCameraController,
    };

    pub const Res = struct {
        input: *const Input,
    };

    pub fn runEntity(res: Res, entity: Entity, q: Query) void {
        _ = entity;

        const ctrl = q.controller;
        const trans = q.transform;

        const delta_yaw = res.input.mouse_xrel * ctrl.mouse_sense;
        const delta_pitch = res.input.mouse_yrel * ctrl.mouse_sense;

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

    pub const Res = struct {
        time: *const Time,
        input: *const Input,
    };

    pub fn runEntity(res: Res, entity: Entity, q: Query) void {
        _ = entity;

        const ctrl = q.controller;
        const trans = q.transform;
        const dt = res.time.dt;

        const forward = math.vec3Rotate(trans.rotation, .{ 0, 0, 1 });
        const right = math.vec3Rotate(trans.rotation, .{ 1, 0, 0 });
        const up = math.vec3Rotate(trans.rotation, .{ 0, 1, 0 });

        var motion: math.Vec3 = .{ 0, 0, 0 };

        if (res.input.keyPressed(sdl.SDL_SCANCODE_W)) {
            motion = math.vec3Add(motion, forward);
        }
        if (res.input.keyPressed(sdl.SDL_SCANCODE_A)) {
            motion = math.vec3Sub(motion, right);
        }
        if (res.input.keyPressed(sdl.SDL_SCANCODE_S)) {
            motion = math.vec3Sub(motion, forward);
        }
        if (res.input.keyPressed(sdl.SDL_SCANCODE_D)) {
            motion = math.vec3Add(motion, right);
        }
        if (res.input.keyPressed(sdl.SDL_SCANCODE_SPACE)) {
            motion = math.vec3Add(motion, up);
        }

        motion = math.vec3Normalize(motion);
        motion = math.vec3Scale(motion, dt * ctrl.move_speed);
        trans.position = math.vec3Add(trans.position, motion);
    }
};
