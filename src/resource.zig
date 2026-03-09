const std = @import("std");

pub fn Resources(comptime ResourceDefs: type) type {
    const fields = @typeInfo(ResourceDefs).@"struct".fields;

    comptime var storage_fields: [fields.len]std.builtin.Type.StructField = undefined;
    inline for (fields, 0..) |field, i| {
        storage_fields[i] = .{
            .name = field.name,
            .type = ?field.type,
            .default_value_ptr = @ptrCast(&@as(?field.type, null)),
            .is_comptime = false,
            .alignment = @alignOf(?field.type),
        };
    }

    const Storage = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &storage_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });

    return struct {
        storage: Storage,

        const Self = @This();

        pub fn init() Self {
            return .{ .storage = std.mem.zeroInit(Storage, .{}) };
        }

        pub fn set(self: *Self, comptime name: []const u8, value: @FieldType(ResourceDefs, name)) void {
            @field(self.storage, name) = value;
        }

        pub fn get(self: *const Self, comptime name: []const u8) ?@FieldType(ResourceDefs, name) {
            return @field(self.storage, name);
        }

        pub fn getConst(self: *const Self, comptime name: []const u8) ?@FieldType(ResourceDefs, name) {
            return @field(self.storage, name);
        }

        pub fn has(self: *const Self, comptime name: []const u8) bool {
            return @field(self.storage, name) != null;
        }
    };
}
