const std = @import("std");
const SystemStage = @import("context.zig").SystemStage;
const Entity = @import("../pool.zig").Entity;
const Resources = @import("../resource.zig").Resources;

pub fn validateSystem(comptime System: type) void {
    const has_run = @hasDecl(System, "run");
    const has_run_entity = @hasDecl(System, "runEntity");

    if (!has_run and !has_run_entity) {
        @compileError("System must have either `run(res, world)` or `runEntity(res, entity, query)`");
    }

    if (has_run_entity and !@hasDecl(System, "Query")) {
        @compileError("System with `runEntity` must declare a `Query` struct");
    }
}

pub fn getSystemStage(comptime System: type) SystemStage {
    if (@hasDecl(System, "stage")) {
        return System.stage;
    }
    return .Update;
}

pub fn Scheduler(
    comptime World: type,
    comptime ResourceDefs: type,
    comptime systems: anytype,
) type {
    const ResourcesStore = Resources(ResourceDefs);
    const stage_count = @typeInfo(SystemStage).@"enum".fields.len;

    comptime var counts: [stage_count]usize = @splat(0);
    inline for (systems) |Sys| {
        validateSystem(Sys);
        counts[@intFromEnum(getSystemStage(Sys))] += 1;
    }

    return struct {
        pub fn runStage(comptime stage: SystemStage, world: *World, resources: *const ResourcesStore) void {
            inline for (systems) |Sys| {
                if (comptime getSystemStage(Sys) == stage) {
                    runSystem(Sys, world, resources);
                }
            }
        }

        fn runSystem(comptime Sys: type, world: *World, resources: *const ResourcesStore) void {
            const has_res = @hasDecl(Sys, "Res");
            const has_run = @hasDecl(Sys, "run");
            const has_run_entity = @hasDecl(Sys, "runEntity");

            if (has_res) {
                const res = buildRes(Sys.Res, resources);

                if (has_run) {
                    Sys.run(res, world);
                } else if (has_run_entity) {
                    runQuerySystem(Sys, res, world);
                }
            } else {
                if (has_run) {
                    Sys.run(world);
                } else if (has_run_entity) {
                    runQuerySystemNoRes(Sys, world);
                }
            }
        }

        fn buildRes(comptime ResDecl: type, resources: *const ResourcesStore) ResDecl {
            const res_fields = @typeInfo(ResDecl).@"struct".fields;
            var result: ResDecl = undefined;

            inline for (res_fields) |field| {
                const name = field.name;
                const value = resources.get(name);
                if (value == null) {
                    if (@typeInfo(field.type) == .optional) {
                        @field(result, name) = null;
                        continue;
                    }
                    std.debug.panic("Resource '{s}' not set", .{name});
                }
                @field(result, name) = value.?;
            }

            return result;
        }

        fn runQuerySystem(
            comptime Sys: type,
            res: Sys.Res,
            world: *World,
        ) void {
            const Query = Sys.Query;
            const query_fields = @typeInfo(Query).@"struct".fields;

            const first_field = query_fields[0];
            const first_component_name = first_field.name;

            var iter = world.iter(first_component_name);

            while (iter.next()) |entry| {
                const entity = entry.entity;

                var has_all = true;
                inline for (query_fields) |field| {
                    const comp_name = field.name;
                    if (!world.has(comp_name, entity)) {
                        has_all = false;
                        break;
                    }
                }

                if (!has_all) continue;

                var query: Query = undefined;
                inline for (query_fields) |field| {
                    const comp_name = field.name;
                    const ptr = world.get(comp_name, entity);
                    @field(query, comp_name) = ptr.?;
                }

                Sys.runEntity(res, entity, query);
            }
        }

        fn runQuerySystemNoRes(
            comptime Sys: type,
            world: *World,
        ) void {
            const Query = Sys.Query;
            const query_fields = @typeInfo(Query).@"struct".fields;

            const first_field = query_fields[0];
            const first_component_name = first_field.name;

            var iter = world.iter(first_component_name);

            while (iter.next()) |entry| {
                const entity = entry.entity;

                var has_all = true;
                inline for (query_fields) |field| {
                    const comp_name = field.name;
                    if (!world.has(comp_name, entity)) {
                        has_all = false;
                        break;
                    }
                }

                if (!has_all) continue;

                var query: Query = undefined;
                inline for (query_fields) |field| {
                    const comp_name = field.name;
                    const ptr = world.get(comp_name, entity);
                    @field(query, comp_name) = ptr.?;
                }

                Sys.runEntity(entity, query);
            }
        }
    };
}

test "Scheduler groups systems by stage" {
    const TestWorld = struct {
        fn iter(_: *const @This(), _: []const u8) void {}
        fn has(_: *const @This(), _: []const u8, _: u32) bool {
            return false;
        }
    };

    const SystemA = struct {
        pub const stage = SystemStage.PreUpdate;
        pub fn run(_: *TestWorld) void {}
    };

    const SystemB = struct {
        pub const stage = SystemStage.Update;
        pub fn run(_: *TestWorld) void {}
    };

    const SystemC = struct {
        pub fn run(_: *TestWorld) void {}
    };

    const MyScheduler = Scheduler(TestWorld, struct {}, .{ SystemA, SystemB, SystemC });
    _ = MyScheduler;
}
