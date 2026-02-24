const std = @import("std");
const Pool = @import("pool.zig").Pool;
const Entity = @import("pool.zig").Entity;

pub fn World(comptime Components: type) type {
    const component_fields = @typeInfo(Components).@"struct".fields;

    comptime var pool_fields: [component_fields.len]std.builtin.Type.StructField = undefined;
    inline for (component_fields, 0..) |field, i| {
        const PoolType = Pool(field.type);
        pool_fields[i] = .{
            .name = field.name ++ "_pool",
            .type = PoolType,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(PoolType),
        };
    }

    const Pools = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &pool_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });

    return struct {
        const Self = @This();

        pools: Pools,
        next_entity: Entity,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            var self: Self = .{
                .pools = undefined,
                .next_entity = 0,
                .allocator = allocator,
            };

            inline for (component_fields) |field| {
                const pool_name = field.name ++ "_pool";
                const PoolType = Pool(field.type);
                @field(self.pools, pool_name) = PoolType.init(allocator);
            }

            return self;
        }

        pub fn deinit(self: *Self) void {
            inline for (component_fields) |field| {
                const pool_name = field.name ++ "_pool";
                @field(self.pools, pool_name).deinit();
            }
        }

        pub fn createEntity(self: *Self) Entity {
            defer self.next_entity += 1;
            return self.next_entity;
        }

        pub fn destroyEntity(self: *Self, entity: Entity) void {
            inline for (component_fields) |field| {
                const pool_name = field.name ++ "_pool";
                @field(self.pools, pool_name).remove(entity) catch {};
            }
        }

        pub fn add(
            self: *Self,
            comptime component_name: []const u8,
            entity: Entity,
            component: @FieldType(Components, component_name),
        ) !void {
            const pool_name = component_name ++ "_pool";
            try @field(self.pools, pool_name).add(entity, component);
        }

        pub fn get(
            self: *Self,
            comptime component_name: []const u8,
            entity: Entity,
        ) ?*@FieldType(Components, component_name) {
            const pool_name = component_name ++ "_pool";
            return @field(self.pools, pool_name).getMut(entity);
        }

        pub fn getConst(
            self: *const Self,
            comptime component_name: []const u8,
            entity: Entity,
        ) ?*const @FieldType(Components, component_name) {
            const pool_name = component_name ++ "_pool";
            return @field(self.pools, pool_name).get(entity);
        }

        pub fn has(
            self: *const Self,
            comptime component_name: []const u8,
            entity: Entity,
        ) bool {
            const pool_name = component_name ++ "_pool";
            return @field(self.pools, pool_name).has(entity);
        }

        pub fn remove(
            self: *Self,
            comptime component_name: []const u8,
            entity: Entity,
        ) !void {
            const pool_name = component_name ++ "_pool";
            try @field(self.pools, pool_name).remove(entity);
        }

        pub fn iter(
            self: *const Self,
            comptime component_name: []const u8,
        ) @import("pool.zig").Iter(@FieldType(Components, component_name)) {
            const pool_name = component_name ++ "_pool";
            return @field(self.pools, pool_name).iter();
        }
    };
}

fn validateComponentName(comptime name: []const u8, comptime Components: type) void {
    inline for (@typeInfo(Components).@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return;
    }
    @compileError("Component '" ++ name ++ "' not found in Components struct");
}
