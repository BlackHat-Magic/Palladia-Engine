const std = @import("std");
const SystemContext = @import("context.zig").SystemContext;
const SystemStage = @import("context.zig").SystemStage;
const Entity = @import("../pool.zig").Entity;

pub fn validateSystem(comptime System: type) void {
    const has_run = @hasDecl(System, "run");
    const has_run_entity = @hasDecl(System, "runEntity");

    if (!has_run and !has_run_entity) {
        @compileError("System must have either `run(ctx: *SystemContext, world: *World) void` or `runEntity(ctx: *const SystemContext, entity: Entity, q: Query) void`");
    }

    if (has_run_entity and !@hasDecl(System, "Query")) {
        @compileError("System with `runEntity` must declare a `Query` struct");
    }
}

pub fn getSystemStage(comptime System: type) SystemStage {
    if (@hasDecl(System, "stage")) {
        return System.stage;
    }
    return .update;
}

pub fn Scheduler(comptime World: type, comptime systems: anytype) type {
    const system_count = systems.len;

    comptime var event_systems: [system_count]type = undefined;
    comptime var event_count: usize = 0;
    comptime var update_systems: [system_count]type = undefined;
    comptime var update_count: usize = 0;
    comptime var render_systems: [system_count]type = undefined;
    comptime var render_count: usize = 0;

    inline for (systems) |Sys| {
        validateSystem(Sys);
        const stage = getSystemStage(Sys);

        switch (stage) {
            .event => {
                event_systems[event_count] = Sys;
                event_count += 1;
            },
            .update => {
                update_systems[update_count] = Sys;
                update_count += 1;
            },
            .render => {
                render_systems[render_count] = Sys;
                render_count += 1;
            },
        }
    }

    const EventSystems = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &([_]std.builtin.Type.StructField{}),
        .decls = &.{
            .{ .name = "systems", .type = [event_count]type, .is_comptime = true, .value = event_systems[0..event_count] },
        },
        .is_tuple = false,
    } });

    const UpdateSystems = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &([_]std.builtin.Type.StructField{}),
        .decls = &.{
            .{ .name = "systems", .type = [update_count]type, .is_comptime = true, .value = update_systems[0..update_count] },
        },
        .is_tuple = false,
    } });

    const RenderSystems = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &([_]std.builtin.Type.StructField{}),
        .decls = &.{
            .{ .name = "systems", .type = [render_count]type, .is_comptime = true, .value = render_systems[0..render_count] },
        },
        .is_tuple = false,
    } });

    return struct {
        pub fn runEvent(ctx: *SystemContext, world: *World) void {
            inline for (EventSystems.systems) |Sys| {
                runSystem(Sys, ctx, world);
            }
        }

        pub fn runUpdate(ctx: *SystemContext, world: *World) void {
            inline for (UpdateSystems.systems) |Sys| {
                runSystem(Sys, ctx, world);
            }
        }

        pub fn runRender(ctx: *SystemContext, world: *World) void {
            inline for (RenderSystems.systems) |Sys| {
                runSystem(Sys, ctx, world);
            }
        }

        fn runSystem(comptime Sys: type, ctx: *SystemContext, world: *World) void {
            if (@hasDecl(Sys, "run")) {
                Sys.run(ctx, world);
            } else if (@hasDecl(Sys, "runEntity")) {
                runQuerySystem(Sys, ctx, world);
            }
        }

        fn runQuerySystem(comptime Sys: type, ctx: *SystemContext, world: *World) void {
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

                Sys.runEntity(ctx, entity, query);
            }
        }
    };
}
