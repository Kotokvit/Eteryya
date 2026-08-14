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
    // ========================================================

    // --- Kernel tests ---
    const kernel_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_kernel.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_kernel_tests = b.addRunArtifact(kernel_tests);

    // --- Idempotent module tests ---
    const idempotent_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_idempotent.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_idempotent_tests = b.addRunArtifact(idempotent_tests);

    // --- Geodesic module tests ---
    const geodesic_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_geodesic.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_geodesic_tests = b.addRunArtifact(geodesic_tests);

    // --- Bridge module tests ---
    const bridge_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_bridge.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_bridge_tests = b.addRunArtifact(bridge_tests);

    // --- Cross-ratio module tests ---
    const crossratio_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_crossratio.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_crossratio_tests = b.addRunArtifact(crossratio_tests);

    // --- Safety module tests ---
    const safety_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_safety.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_safety_tests = b.addRunArtifact(safety_tests);

    // --- GPU module tests (WGSL shaders + CPU equivalents) ---
    const gpu_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_gpu.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_gpu_tests = b.addRunArtifact(gpu_tests);

    // --- Raylib bridge tests ---
    const raylib_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_raylib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_raylib_tests = b.addRunArtifact(raylib_tests);

    // --- Invariant module tests ---
    const invariant_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_invariant.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_invariant_tests = b.addRunArtifact(invariant_tests);

    // --- Algebra module tests (Grassmann/Plücker) ---
    const algebra_tests = b.addTest(.{
        .root_source_file = b.path("src/p3_algebra.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_algebra_tests = b.addRunArtifact(algebra_tests);

    // --- Test step: run ALL module tests ---
    const test_step = b.step("test", "Run all P³ engine tests");
    test_step.dependOn(&run_kernel_tests.step);
    test_step.dependOn(&run_idempotent_tests.step);
    test_step.dependOn(&run_geodesic_tests.step);
    test_step.dependOn(&run_bridge_tests.step);
    test_step.dependOn(&run_crossratio_tests.step);
    test_step.dependOn(&run_safety_tests.step);
    test_step.dependOn(&run_gpu_tests.step);
    test_step.dependOn(&run_raylib_tests.step);
    test_step.dependOn(&run_invariant_tests.step);
    test_step.dependOn(&run_algebra_tests.step);

    // --- Individual test steps ---
    const kernel_test_step = b.step("test-kernel", "Run p3_kernel tests only");
    kernel_test_step.dependOn(&run_kernel_tests.step);

    const idempotent_test_step = b.step("test-idempotent", "Run p3_idempotent tests only");
    idempotent_test_step.dependOn(&run_idempotent_tests.step);

    const geodesic_test_step = b.step("test-geodesic", "Run p3_geodesic tests only");
    geodesic_test_step.dependOn(&run_geodesic_tests.step);

    const bridge_test_step = b.step("test-bridge", "Run p3_bridge tests only");
    bridge_test_step.dependOn(&run_bridge_tests.step);

    const crossratio_test_step = b.step("test-crossratio", "Run p3_crossratio tests only");
    crossratio_test_step.dependOn(&run_crossratio_tests.step);

    const safety_test_step = b.step("test-safety", "Run p3_safety tests only");
    safety_test_step.dependOn(&run_safety_tests.step);

    const gpu_test_step = b.step("test-gpu", "Run p3_gpu tests only");
    gpu_test_step.dependOn(&run_gpu_tests.step);

    const raylib_test_step = b.step("test-raylib", "Run p3_raylib tests only");
    raylib_test_step.dependOn(&run_raylib_tests.step);

    const invariant_test_step = b.step("test-invariant", "Run p3_invariant tests only");
    invariant_test_step.dependOn(&run_invariant_tests.step);

    const algebra_test_step = b.step("test-algebra", "Run p3_algebra tests only");
    algebra_test_step.dependOn(&run_algebra_tests.step);
}
