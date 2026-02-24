const std = @import("std");

pub const Entity = u32;

pub const INVALID: u32 = std.math.maxInt(u32);

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T,
        entity_to_index: []u32,
        index_to_entity: []Entity,
        count: u32,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = &.{},
                .entity_to_index = &.{},
                .index_to_entity = &.{},
                .count = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.data.len > 0) self.allocator.free(self.data);
            if (self.entity_to_index.len > 0) self.allocator.free(self.entity_to_index);
            if (self.index_to_entity.len > 0) self.allocator.free(self.index_to_entity);
        }

        pub fn add(self: *Self, entity: Entity, component: T) !void {
            if (entity >= self.entity_to_index.len) {
                try self.growSparse(entity + 1);
            }

            if (self.entity_to_index[entity] != INVALID) {
                const idx = self.entity_to_index[entity];
                self.data[idx] = component;
                return;
            }

            if (self.count >= self.data.len) {
                try self.growDense();
            }

            const idx = self.count;
            self.entity_to_index[entity] = idx;
            self.index_to_entity[idx] = entity;
            self.data[idx] = component;
            self.count += 1;
        }

        pub fn get(self: *const Self, entity: Entity) ?*const T {
            if (!self.has(entity)) return null;
            const idx = self.entity_to_index[entity];
            return &self.data[idx];
        }

        pub fn getMut(self: *Self, entity: Entity) ?*T {
            if (!self.has(entity)) return null;
            const idx = self.entity_to_index[entity];
            return &self.data[idx];
        }

        pub fn has(self: *const Self, entity: Entity) bool {
            return entity < self.entity_to_index.len and self.entity_to_index[entity] != INVALID;
        }

        pub const Error = error{EntityNotFound};

        pub fn remove(self: *Self, entity: Entity) Error!void {
            if (!self.has(entity)) return Error.EntityNotFound;

            const idx = self.entity_to_index[entity];
            const last_idx = self.count - 1;

            self.entity_to_index[entity] = INVALID;

            if (idx != last_idx) {
                const moved_entity = self.index_to_entity[last_idx];
                self.index_to_entity[idx] = moved_entity;
                self.data[idx] = self.data[last_idx];
                self.entity_to_index[moved_entity] = idx;
            }

            self.count -= 1;
        }

        pub fn iter(self: *const Self) Iter(T) {
            return .{
                .data = self.data,
                .index_to_entity = self.index_to_entity,
                .count = self.count,
            };
        }

        fn growSparse(self: *Self, min_size: usize) !void {
            const new_size = @max(min_size, if (self.entity_to_index.len == 0) 64 else self.entity_to_index.len * 2);
            const old_len = self.entity_to_index.len;

            const new_sparse = try self.allocator.alloc(u32, new_size);
            @memcpy(new_sparse[0..old_len], self.entity_to_index);
            @memset(new_sparse[old_len..], INVALID);

            if (self.entity_to_index.len > 0) self.allocator.free(self.entity_to_index);
            self.entity_to_index = new_sparse;
        }

        fn growDense(self: *Self) !void {
            const new_size = if (self.data.len == 0) 64 else self.data.len * 2;

            const new_data = try self.allocator.alloc(T, new_size);
            const new_index_to_entity = try self.allocator.alloc(Entity, new_size);

            @memcpy(new_data[0..self.count], self.data[0..self.count]);
            @memcpy(new_index_to_entity[0..self.count], self.index_to_entity[0..self.count]);

            if (self.data.len > 0) self.allocator.free(self.data);
            if (self.index_to_entity.len > 0) self.allocator.free(self.index_to_entity);

            self.data = new_data;
            self.index_to_entity = new_index_to_entity;
        }
    };
}

pub fn Iter(comptime T: type) type {
    return struct {
        data: []const T,
        index_to_entity: []const Entity,
        count: u32,
        index: u32 = 0,

        pub fn next(self: *@This()) ?struct { entity: Entity, component: *const T } {
            if (self.index >= self.count) return null;
            const entity = self.index_to_entity[self.index];
            const component = &self.data[self.index];
            self.index += 1;
            return .{ .entity = entity, .component = component };
        }
    };
}
