const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const compile_shaders = b.option(bool, "compile-shaders", "Compile GLSL shaders to SPIR-V (default: true)") orelse true;

    const mod = b.addModule("palladia", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    const sdl_test_lib = sdl_dep.artifact("SDL3_test");

    mod.linkLibrary(sdl_lib);
    mod.linkLibrary(sdl_test_lib);
    mod.linkSystemLibrary("SDL3_image", .{});

    const shader_step = b.step("shaders", "Compile built-in shaders to SPIR-V");

    if (compile_shaders) {
        const shaders = [_][]const u8{
            "basic_material.vert",
            "basic_material.frag",
            "phong_material.vert",
            "phong_material.frag",
            "ui.vert",
            "ui.frag",
        };

        const glslang = b.findProgram(&.{"glslangValidator"}, &.{}) catch null;

        if (glslang) |glslang_path| {
            inline for (shaders) |shader| {
                const input = b.path(b.fmt("src/shaders/glsl/{s}", .{shader}));
                const output_name = b.fmt("{s}.spv", .{shader});

                const run = b.addSystemCommand(&.{
                    glslang_path,
                    "-V",
                    "-o",
                });
                const output = run.addOutputFileArg(output_name);
                run.addFileArg(input);
                run.addArgs(&.{ "--target-env", "vulkan1.3" });

                shader_step.dependOn(&run.step);
                _ = output;
            }
        } else {
            std.log.warn("glslangValidator not found, shader compilation disabled", .{});
        }
    }

    const exe = b.addExecutable(.{
        .name = "palladia",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "palladia", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const demo_mesh = b.addExecutable(.{
        .name = "demo_mesh",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/demo_mesh_zig/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "palladia", .module = mod },
            },
        }),
    });

    const install_demo = b.addInstallArtifact(demo_mesh, .{});
    const demo_step = b.step("demo", "Build and run the demo_mesh example");
    demo_step.dependOn(&install_demo.step);

    const run_demo = b.addRunArtifact(demo_mesh);
    demo_step.dependOn(&run_demo.step);
}

pub const ShaderSpec = struct {
    source: std.Build.LazyPath,
    name: []const u8,
};

pub fn ShaderCompile(b: *std.Build, specs: []const ShaderSpec) *std.Build.Step {
    const glslang_opt = b.findProgram(&.{"glslangValidator"}, &.{}) catch null;
    const glslang_path = glslang_opt orelse @panic("glslangValidator not found. Install it to compile shaders.");

    const step = b.allocator.create(std.Build.Step) catch @panic("OOM");
    step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = "compile shaders",
        .owner = b,
    });

    for (specs) |spec| {
        const output_name = b.fmt("{s}.spv", .{spec.name});

        const run = b.addSystemCommand(&.{
            glslang_path,
            "-V",
            "-o",
        });
        const output = run.addOutputFileArg(output_name);
        run.addFileArg(spec.source);
        run.addArgs(&.{ "--target-env", "vulkan1.3" });

        step.dependOn(&run.step);
        _ = output;
    }

    return step;
}
