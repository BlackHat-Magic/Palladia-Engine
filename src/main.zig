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
