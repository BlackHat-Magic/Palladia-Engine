const std = @import("std");
const palladia = @import("palladia");

pub fn main() !void {
    std.debug.print("Palladia Engine\n", .{});
}

test "ECS basic usage" {
    const MyComponents = struct {
        transform: palladia.Transform,
        health: struct { current: f32, max: f32 },
    };

    const MyWorld = palladia.World(MyComponents);

    var world = MyWorld.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    try world.add("transform", entity, .{ .position = .{ 1, 2, 3 } });
    try world.add("health", entity, .{ .current = 100, .max = 100 });

    try std.testing.expect(world.has("transform", entity));
    try std.testing.expect(world.has("health", entity));

    if (world.get("health", entity)) |h| {
        h.current -= 10;
    }

    if (world.getConst("health", entity)) |h| {
        try std.testing.expectEqual(@as(f32, 90), h.current);
    }

    try world.remove("health", entity);
    try std.testing.expect(!world.has("health", entity));
}

test "Resources" {
    const MyResources = struct {
        time: palladia.system.Time,
        score: u32,
    };

    var time = palladia.system.Time{ .dt = 0.016, .total = 1.0, .frame = 60 };
    var score: u32 = 100;

    const ResourcesStore = palladia.resource.Resources(MyResources);
    var resources = ResourcesStore.init();

    resources.set("time", &time);
    resources.set("score", &score);

    try std.testing.expect(resources.has("time"));
    try std.testing.expect(resources.has("score"));

    if (resources.get("time")) |t| {
        try std.testing.expectEqual(@as(f32, 0.016), t.dt);
        t.dt = 0.032;
    }

    if (resources.getConst("time")) |t| {
        try std.testing.expectEqual(@as(f32, 0.032), t.dt);
    }

    if (resources.get("score")) |s| {
        s.* += 50;
    }

    if (resources.getConst("score")) |s| {
        try std.testing.expectEqual(@as(u32, 150), s.*);
    }
}

test "System with resources" {
    const MyComponents = struct {
        position: palladia.math.Vec3,
        velocity: palladia.math.Vec3,
    };

    const MyResources = struct {
        time: palladia.system.Time,
    };

    const MovementSystem = struct {
        pub const Query = struct {
            position: *palladia.math.Vec3,
            velocity: *const palladia.math.Vec3,
        };

        pub const Res = struct {
            time: *const palladia.system.Time,
        };

        pub fn runEntity(res: Res, entity: palladia.ecs.Entity, q: Query) void {
            _ = entity;
            q.position.* = palladia.math.vec3Add(
                q.position.*,
                palladia.math.vec3Scale(q.velocity.*, res.time.dt),
            );
        }
    };

    const MyWorld = palladia.World(MyComponents);
    const MyScheduler = palladia.system.Scheduler(MyWorld, MyResources, .{
        MovementSystem,
    });

    var world = MyWorld.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    try world.add("position", entity, .{ 0, 0, 0 });
    try world.add("velocity", entity, .{ 1, 2, 3 });

    var time = palladia.system.Time{ .dt = 0.5, .total = 0, .frame = 0 };
    const ResourcesStore = palladia.resource.Resources(MyResources);
    var resources = ResourcesStore.init();
    resources.set("time", &time);

    MyScheduler.runUpdate(&world, &resources);

    const pos = world.getConst("position", entity).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pos[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), pos[2], 0.001);
}
