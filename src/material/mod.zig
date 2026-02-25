pub const loadShader = @import("common.zig").loadShader;
pub const loadShaderFromBytes = @import("common.zig").loadShaderFromBytes;
pub const loadTexture = @import("common.zig").loadTexture;
pub const createWhiteTexture = @import("common.zig").createWhiteTexture;
pub const createDefaultSampler = @import("common.zig").createDefaultSampler;

pub const createBasicMaterial = @import("basic.zig").createBasicMaterial;
pub const createBasicMaterialWithCustomShaders = @import("basic.zig").createBasicMaterialWithCustomShaders;
pub const BasicMaterialArgs = @import("basic.zig").BasicMaterialArgs;
pub const basic_material_vert_spv = @import("basic.zig").basic_material_vert_spv;
pub const basic_material_frag_spv = @import("basic.zig").basic_material_frag_spv;

pub const createPhongMaterial = @import("phong.zig").createPhongMaterial;
pub const createPhongMaterialWithCustomShaders = @import("phong.zig").createPhongMaterialWithCustomShaders;
pub const PhongMaterialArgs = @import("phong.zig").PhongMaterialArgs;
pub const phong_material_vert_spv = @import("phong.zig").phong_material_vert_spv;
pub const phong_material_frag_spv = @import("phong.zig").phong_material_frag_spv;

pub const createUIMaterial = @import("ui.zig").createUIMaterial;
pub const UIMaterialArgs = @import("ui.zig").UIMaterialArgs;
pub const UIVertex = @import("ui.zig").UIVertex;
pub const ui_vert_spv = @import("ui.zig").ui_vert_spv;
pub const ui_frag_spv = @import("ui.zig").ui_frag_spv;
