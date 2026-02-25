const std = @import("std");

pub fn Resources(comptime ResourceDefs: type) type {
    const fields = @typeInfo(ResourceDefs).@"struct".fields;

    comptime var storage_fields: [fields.len]std.builtin.Type.StructField = undefined;
    inline for (fields, 0..) |field, i| {
        storage_fields[i] = .{
            .name = field.name,
            .type = ?*field.type,
            .default_value_ptr = @ptrCast(&@as(?*field.type, null)),
            .is_comptime = false,
            .alignment = @alignOf(?*field.type),
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

        pub fn set(self: *Self, comptime name: []const u8, ptr: *@FieldType(ResourceDefs, name)) void {
            @field(self.storage, name) = ptr;
        }

        pub fn get(self: *const Self, comptime name: []const u8) ?*@FieldType(ResourceDefs, name) {
            return @field(self.storage, name);
        }

        pub fn getConst(self: *const Self, comptime name: []const u8) ?*const @FieldType(ResourceDefs, name) {
            return @field(self.storage, name);
        }

        pub fn has(self: *const Self, comptime name: []const u8) bool {
            return @field(self.storage, name) != null;
        }
    };
}

pub fn buildResourceStruct(
    comptime ResourceDefs: type,
    comptime ResourcesStore: type,
    comptime ResDecl: type,
    resources: *const ResourcesStore,
) ResDecl {
    const res_fields = @typeInfo(ResDecl).@"struct".fields;
    var result: ResDecl = undefined;

    inline for (res_fields) |field| {
        const name = field.name;
        const ResType = @FieldType(ResourceDefs, name);

        comptime {
            if (@typeInfo(field.type) != .pointer) {
                @compileError("Resource field '" ++ name ++ "' must be a pointer type (*T or *const T)");
            }
            const ChildType = @typeInfo(field.type).pointer.child;
            if (ChildType != ResType) {
                @compileError("Resource '" ++ name ++ "' type mismatch: expected " ++ @typeName(ChildType) ++ ", found " ++ @typeName(ResType));
            }
        }

        const ptr = resources.get(name);
        if (ptr == null) {
            std.debug.panic("Resource '{s}' not set", .{name});
        }

        const is_const = @typeInfo(field.type).pointer.is_const;
        if (is_const) {
            @field(result, name) = @ptrCast(ptr);
        } else {
            @field(result, name) = ptr;
        }
    }

    return result;
}
