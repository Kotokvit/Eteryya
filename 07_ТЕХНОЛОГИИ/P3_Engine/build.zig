const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================
    // P³ Engine — Projective Geometry Engine
    // Zig 0.13.0 — C++ ABI совместимость, @cImport для доноров
    // ========================================================
    // Фаза 1: Ядро + Идемпотенты + Геодезические + Мост
    //         + Cross-ratio + Safety (type-level guarantees)
    // Фаза 2: GPU (WGSL) + raylib мост + Инварианты
    //         + Алгебра (Грассман/Клиффорд/Плюккер)
    // Фаза 3: ECS (из O3DE) + Scene Graph + Physics
    // ========================================================

    const modules = .{
        .{ "kernel",      "src/p3_kernel.zig" },
        .{ "idempotent",  "src/p3_idempotent.zig" },
        .{ "geodesic",    "src/p3_geodesic.zig" },
        .{ "bridge",      "src/p3_bridge.zig" },
        .{ "crossratio",  "src/p3_crossratio.zig" },
        .{ "safety",      "src/p3_safety.zig" },
        .{ "gpu",         "src/p3_gpu.zig" },
        .{ "raylib",      "src/p3_raylib.zig" },
        .{ "invariant",   "src/p3_invariant.zig" },
        .{ "algebra",     "src/p3_algebra.zig" },
        .{ "ecs",         "src/p3_ecs.zig" },
        .{ "scene",       "src/p3_scene.zig" },
        .{ "physics",     "src/p3_physics.zig" },
    };

    // --- Generate test steps for all modules ---
    const test_step = b.step("test", "Run all P³ engine tests");

    inline for (modules) |mod| {
        const mod_name = mod.@"0";
        const mod_path = mod.@"1";

        const mod_tests = b.addTest(.{
            .root_source_file = b.path(mod_path),
            .target = target,
            .optimize = optimize,
        });
        const run_mod_tests = b.addRunArtifact(mod_tests);

        test_step.dependOn(&run_mod_tests.step);

        // Individual test step: zig build test-<name>
        const individual_step = b.step(
            b.fmt("test-{s}", .{mod_name}),
            b.fmt("Run p3_{s} tests only", .{mod_name}),
        );
        individual_step.dependOn(&run_mod_tests.step);
    }
}
