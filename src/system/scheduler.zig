const std = @import("std");
const SystemStage = @import("context.zig").SystemStage;
const Entity = @import("../pool.zig").Entity;
const Resources = @import("../resource.zig").Resources;
const buildResourceStruct = @import("../resource.zig").buildResourceStruct;

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
    return .update;
}

pub fn Scheduler(
    comptime World: type,
    comptime ResourceDefs: type,
    comptime systems: anytype,
) type {
    const ResourcesStore = Resources(ResourceDefs);

    comptime var event_count: usize = 0;
    comptime var update_count: usize = 0;
    comptime var render_count: usize = 0;

    inline for (systems) |Sys| {
        validateSystem(Sys);
        const stage = getSystemStage(Sys);

        switch (stage) {
            .event => event_count += 1,
            .update => update_count += 1,
            .render => render_count += 1,
        }
    }

    comptime var event_systems: [event_count]type = undefined;
    comptime var event_idx: usize = 0;
    comptime var update_systems: [update_count]type = undefined;
    comptime var update_idx: usize = 0;
    comptime var render_systems: [render_count]type = undefined;
    comptime var render_idx: usize = 0;

    inline for (systems) |Sys| {
        const stage = getSystemStage(Sys);

        switch (stage) {
            .event => {
                event_systems[event_idx] = Sys;
                event_idx += 1;
            },
            .update => {
                update_systems[update_idx] = Sys;
                update_idx += 1;
            },
            .render => {
                render_systems[render_idx] = Sys;
                render_idx += 1;
            },
        }
    }

    return struct {
        pub fn runEvent(world: *World, resources: *const ResourcesStore) void {
            inline for (event_systems) |Sys| {
                runSystem(Sys, world, resources);
            }
        }

        pub fn runUpdate(world: *World, resources: *const ResourcesStore) void {
            inline for (update_systems) |Sys| {
                runSystem(Sys, world, resources);
            }
        }

        pub fn runRender(world: *World, resources: *const ResourcesStore) void {
            inline for (render_systems) |Sys| {
                runSystem(Sys, world, resources);
            }
        }

        fn runSystem(comptime Sys: type, world: *World, resources: *const ResourcesStore) void {
            const has_res = @hasDecl(Sys, "Res");
            const has_run = @hasDecl(Sys, "run");
            const has_run_entity = @hasDecl(Sys, "runEntity");

            if (has_res) {
                const res = buildResourceStruct(ResourceDefs, ResourcesStore, Sys.Res, resources);

                if (has_run) {
                    Sys.run(res, world);
                } else if (has_run_entity) {
                    runQuerySystem(Sys, res, world);
                }
            } else {
                if (has_run) {
                    if (hasParams(Sys.run, 2)) {
                        Sys.run(world, resources);
                    } else {
                        Sys.run(world);
                    }
                } else if (has_run_entity) {
                    runQuerySystemNoRes(Sys, world);
                }
            }
        }

        fn hasParams(comptime fn_ptr: anytype, comptime count: usize) bool {
            const fn_info = @typeInfo(@TypeOf(fn_ptr)).@"fn";
            return fn_info.params.len >= count;
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
