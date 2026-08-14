// =============================================================================
// P³ GPU — ВЫЧИСЛИТЕЛЬНЫЕ ШЕЙДЕРЫ ДЛЯ WGSL (MACH SYSGPU)
// =============================================================================
//
// Mach engine (https://machengine.org) использует sysgpu — абстракцию
// над WebGPU (wgpu-native). Шейдеры — WGSL (WebGPU Shading Language).
//
// P³ на GPU — это НЕ «рендеринг точек». Это:
//   - Пакетная FS-distance для тысяч точек (compute shader)
//   - Проекция на идемпотентное многообразие P²=P (compute shader)
//   - Геодезический RK4 на GPU (compute shader)
//   - Дегомогенизация P³→R³ с переключением карт (vertex shader)
//   - PGL-действие на массивы точек (compute shader)
//
// Доноры:
//   - Mach sysgpu: @import("sysgpu") для WebGPU API
//   - zmath: GPU buffer layout (переписано)
//   - WGSL compute patterns из Bevy/wgpu examples (переписано)
//
// АРХИТЕКТУРА:
//
//   CPU (Zig)                    GPU (WGSL)
//   ─────────                    ──────────
//   HomVec4[] ──upload──→       struct HomVec4 { x,y,z,w: f32 }
//   PGL4      ──uniform──→      struct PGL4 { data: array<f32,16> }
//                               ─────────────────────────────────
//                               @compute fs_distance_batch()
//                               @compute idempotent_project_batch()
//                               @compute geodesic_rk4_step()
//                               @compute pgl_action_batch()
//                               @vertex   dehomogenize()
//
// КЛЮЧЕВАЯ ИДЕЯ: мы НЕ рендерим P³-точки как R³.
// Мы ВЫЧИСЛЯЕМ на GPU в P³, и только финальный @vertex
// дегомогенизирует для растеризатора.
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. WGSL ШЕЙДЕРЫ (COMPTIME СТРОКИ)
// =============================================================================
//
// Шейдеры — comptime строки. Mach/sysgpu компилирует их при создании
// pipeline. Мы ХРАНИМ их здесь, рядом с математикой, потому что
// шейдер БЕЗ понимания P³ — это мусор.

/// WGSL: структура HomVec4 для GPU
pub const wgsl_hom_vec4 =
    \\struct HomVec4 {
    \\    x: f32,
    \\    y: f32,
    \\    z: f32,
    \\    w: f32,
    \\}
;

/// WGSL: структура PGL4 для GPU (column-major 4×4)
pub const wgsl_pgl4 =
    \\struct PGL4 {
    \\    data: array<f32, 16>,
    \\}
;

/// WGSL: структура GeodesicState для GPU
pub const wgsl_geodesic_state =
    \\struct GeodesicState {
    \\    qx: f32, qy: f32, qz: f32, qw: f32,
    \\    vx: f32, vy: f32, vz: f32, vw: f32,
    \\}
;

/// WGSL compute shader: пакетная FS-distance
///
/// Вход: массив HomVec4 (positions) + 1 HomVec4 (reference point)
/// Выход: массив f32 (FS distances)
///
/// FS-distance: d_FS(p,q) = arccos(|⟨p,q⟩| / (‖p‖·‖q‖))
pub const wgsl_fs_distance_batch =
    \\@group(0) @binding(0) var<storage, read> positions: array<HomVec4>;
    \\@group(0) @binding(1) var<storage, read_write> distances: array<f32>;
    \\@group(0) @binding(2) var<uniform> reference: HomVec4;
    \\
    \\fn hom_dot(a: HomVec4, b: HomVec4) -> f32 {
    \\    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    \\}
    \\
    \\fn hom_norm(v: HomVec4) -> f32 {
    \\    return sqrt(hom_dot(v, v));
    \\}
    \\
    \\@compute @workgroup_size(64)
    \\fn fs_distance_batch(@builtin(global_invocation_id) id: vec3<u32>) {
    \\    let i = id.x;
    \\    if (i >= arrayLength(&positions)) { return; }
    \\
    \\    let p = positions[i];
    \\    let q = reference;
    \\    let n1 = hom_norm(p);
    \\    let n2 = hom_norm(q);
    \\    if (n1 < 1e-15 || n2 < 1e-15) {
    \\        distances[i] = 0.0;
    \\        return;
    \\    }
    \\
    \\    let cos_theta = clamp(abs(hom_dot(p, q)) / (n1 * n2), 0.0, 1.0);
    \\    distances[i] = acos(cos_theta);
    \\}
;

/// WGSL compute shader: пакетное PGL-действие
///
/// Вход: HomVec4[] + PGL4 (uniform)
/// Выход: HomVec4[] (преобразованные точки)
///
/// PGL-действие: (M·p)_i = Σⱼ M[i,j]·pⱼ
pub const wgsl_pgl_action_batch =
    \\@group(0) @binding(0) var<storage, read> input_points: array<HomVec4>;
    \\@group(0) @binding(1) var<storage, read_write> output_points: array<HomVec4>;
    \\@group(0) @binding(2) var<uniform> transform: PGL4;
    \\
    \\@compute @workgroup_size(64)
    \\fn pgl_action_batch(@builtin(global_invocation_id) id: vec3<u32>) {
    \\    let i = id.x;
    \\    if (i >= arrayLength(&input_points)) { return; }
    \\
    \\    let p = input_points[i];
    \\    let m = transform.data;
    \\    // Column-major: column j, row i → data[j*4+i]
    \\    output_points[i] = HomVec4(
    \\        m[0]*p.x + m[4]*p.y + m[8]*p.z  + m[12]*p.w,
    \\        m[1]*p.x + m[5]*p.y + m[9]*p.z  + m[13]*p.w,
    \\        m[2]*p.x + m[6]*p.y + m[10]*p.z + m[14]*p.w,
    \\        m[3]*p.x + m[7]*p.y + m[11]*p.z + m[15]*p.w,
    \\    );
    \\}
;

/// WGSL compute shader: геодезический RK4 шаг на GPU
///
/// Вход: GeodesicState[] (текущие состояния)
/// Выход: GeodesicState[] (после одного RK4 шага)
/// Uniform: dt (шаг), speed_sq (‖v‖²)
///
/// Свободная геодезическая: ẍ = −|v|²·q
pub const wgsl_geodesic_rk4_step =
    \\@group(0) @binding(0) var<storage, read> states_in: array<GeodesicState>;
    \\@group(0) @binding(1) var<storage, read_write> states_out: array<GeodesicState>;
    \\@group(0) @binding(2) var<uniform> params: RK4Params;
    \\
    \\struct RK4Params {
    \\    dt: f32,
    \\    _pad0: f32,
    \\    _pad1: f32,
    \\    _pad2: f32,
    \\}
    \\
    \\fn geodesic_rhs(s: GeodesicState) -> GeodesicState {
    \\    let speed_sq = s.vx*s.vx + s.vy*s.vy + s.vz*s.vz + s.vw*s.vw;
    \\    return GeodesicState(
    \\        s.vx, s.vy, s.vz, s.vw,                    // dq/dt = v
    \\        -speed_sq * s.qx, -speed_sq * s.qy,        // dv/dt = -|v|²·q
    \\        -speed_sq * s.qz, -speed_sq * s.qw,
    \\    );
    \\}
    \\
    \\fn add_state(a: GeodesicState, b: GeodesicState) -> GeodesicState {
    \\    return GeodesicState(
    \\        a.qx+b.qx, a.qy+b.qy, a.qz+b.qz, a.qw+b.qw,
    \\        a.vx+b.vx, a.vy+b.vy, a.vz+b.vz, a.vw+b.vw,
    \\    );
    \\}
    \\
    \\fn scale_state(s: GeodesicState, k: f32) -> GeodesicState {
    \\    return GeodesicState(
    \\        s.qx*k, s.qy*k, s.qz*k, s.qw*k,
    \\        s.vx*k, s.vy*k, s.vz*k, s.vw*k,
    \\    );
    \\}
    \\
    \\@compute @workgroup_size(64)
    \\fn geodesic_rk4_step(@builtin(global_invocation_id) id: vec3<u32>) {
    \\    let i = id.x;
    \\    if (i >= arrayLength(&states_in)) { return; }
    \\
    \\    let y = states_in[i];
    \\    let h = params.dt;
    \\
    \\    let k1 = geodesic_rhs(y);
    \\    let k2 = geodesic_rhs(add_state(y, scale_state(k1, 0.5 * h)));
    \\    let k3 = geodesic_rhs(add_state(y, scale_state(k2, 0.5 * h)));
    \\    let k4 = geodesic_rhs(add_state(y, scale_state(k3, h)));
    \\
    \\    let combined = add_state(
    \\        add_state(k1, scale_state(k2, 2.0)),
    \\        add_state(scale_state(k3, 2.0), k4),
    \\    );
    \\    states_out[i] = add_state(y, scale_state(combined, h / 6.0));
    \\}
;

/// WGSL compute shader: идемпотентная проекция (Newton шаг)
///
/// P_{k+1} = 3P²_k − 2P³_k (Newton для P²−P=0)
/// Работает на массиве 4×4 матриц (flat: 16 f32 каждая)
pub const wgsl_idempotent_newton =
    \\@group(0) @binding(0) var<storage, read_write> matrices: array<f32>;
    \\
    \\fn mat_mul_get(a: array<f32,16>, b: array<f32,16>, i: u32, j: u32) -> f32 {
    \\    var sum: f32 = 0.0;
    \\    for (var k: u32 = 0u; k < 4u; k = k + 1u) {
    \\        sum = sum + a[k*4u+i] * b[j*4u+k];
    \\    }
    \\    return sum;
    \\}
    \\
    \\@compute @workgroup_size(16)
    \\fn idempotent_newton_step(@builtin(global_invocation_id) id: vec3<u32>) {
    \\    let mat_idx = id.x;
    \\    let base = mat_idx * 16u;
    \\    if (base + 15u >= arrayLength(&matrices)) { return; }
    \\
    \\    // Load P
    \\    var p: array<f32, 16>;
    \\    for (var i: u32 = 0u; i < 16u; i = i + 1u) {
    \\        p[i] = matrices[base + i];
    \\    }
    \\
    \\    // Compute P²
    \\    var p2: array<f32, 16>;
    \\    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
    \\        for (var j: u32 = 0u; j < 4u; j = j + 1u) {
    \\            p2[j*4u+i] = mat_mul_get(p, p, i, j);
    \\        }
    \\    }
    \\
    \\    // Compute P³ = P²·P
    \\    var p3: array<f32, 16>;
    \\    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
    \\        for (var j: u32 = 0u; j < 4u; j = j + 1u) {
    \\            p3[j*4u+i] = mat_mul_get(p2, p, i, j);
    \\        }
    \\    }
    \\
    \\    // Newton: P_new = 3P² − 2P³
    \\    for (var i: u32 = 0u; i < 16u; i = i + 1u) {
    \\        matrices[base + i] = 3.0 * p2[i] - 2.0 * p3[i];
    \\    }
    \\}
;

/// WGSL vertex shader: дегомогенизация P³→R³
///
/// Вход: HomVec4 (position in P³)
/// Выход: vec4<f32> (clip-space: x/w, y/w, z/w, 1)
///
/// Выбирает лучшую афинную карту:
///   UW (w наибольший): (x/w, y/w, z/w)
///   UX (x наибольший): (y/x, z/x, w/x)  — «точка на бесконечности»
///   UY, UZ — аналогично
pub const wgsl_dehomogenize_vertex =
    \\struct VertexInput {
    \\    @location(0) position: HomVec4,
    \\    @location(1) normal: HomVec4,
    \\    @location(2) uv: vec2<f32>,
    \\}
    \\
    \\struct VertexOutput {
    \\    @builtin(position) clip_position: vec4<f32>,
    \\    @location(0) world_position: vec3<f32>,
    \\    @location(1) world_normal: vec3<f32>,
    \\    @location(2) uv: vec2<f32>,
    \\    @location(3) card_index: f32,
    \\}
    \\
    \\@group(0) @binding(0) var<uniform> mvp: array<f32, 16>;
    \\
    \\fn abs_f(x: f32) -> f32 {
    \\    return select(-x, x, x >= 0.0);
    \\}
    \\
    \\fn dehomogenize(p: HomVec4) -> vec3<f32> {
    \\    let ax = abs_f(p.x);
    \\    let ay = abs_f(p.y);
    \\    let az = abs_f(p.z);
    \\    let aw = abs_f(p.w);
    \\
    \\    // pickBestCard: выбираем координату с наибольшим |значением|
    \\    if (aw >= ax && aw >= ay && aw >= az) {
    \\        return vec3<f32>(p.x / p.w, p.y / p.w, p.z / p.w);
    \\    }
    \\    if (ax >= ay && ax >= az) {
    \\        return vec3<f32>(p.y / p.x, p.z / p.x, p.w / p.x);
    \\    }
    \\    if (ay >= az) {
    \\        return vec3<f32>(p.x / p.y, p.z / p.y, p.w / p.y);
    \\    }
    \\    return vec3<f32>(p.x / p.z, p.y / p.z, p.w / p.z);
    \\}
    \\
    \\@vertex
    \\fn dehomogenize_vertex(in: VertexInput) -> VertexOutput {
    \\    var out: VertexOutput;
    \\    let pos3 = dehomogenize(in.position);
    \\    out.world_position = pos3;
    \\    out.world_normal = dehomogenize(in.normal);
    \\    out.uv = in.uv;
    \\
    \\    // Apply MVP for clip space
    \\    let p4 = vec4<f32>(pos3.x, pos3.y, pos3.z, 1.0);
    \\    out.clip_position = vec4<f32>(
    \\        mvp[0]*p4.x + mvp[4]*p4.y + mvp[8]*p4.z  + mvp[12]*p4.w,
    \\        mvp[1]*p4.x + mvp[5]*p4.y + mvp[9]*p4.z  + mvp[13]*p4.w,
    \\        mvp[2]*p4.x + mvp[6]*p4.y + mvp[10]*p4.z + mvp[14]*p4.w,
    \\        mvp[3]*p4.x + mvp[7]*p4.y + mvp[11]*p4.z + mvp[15]*p4.w,
    \\    );
    \\
    \\    out.card_index = 0.0; // TODO: pass actual card index
    \\    return out;
    \\}
;

// =============================================================================
// 2. GPU БУФЕРНЫЕ ТИПЫ (WGSL-СОВМЕСТИМЫЕ)
// =============================================================================
//
// Все типы — f32 и align(16) для WGSL/storage_buffer.
// HomVec4 на GPU: 16 байт (4 × f32)
// PGL4 на GPU:    64 байта (16 × f32)
// GeodesicState:  32 байта (8 × f32)

/// GPU-aligned HomVec4: f32, 16 bytes, WGSL-compatible
pub const GpuHomVec4 = extern struct {
    x: f32 align(16),
    y: f32,
    z: f32,
    w: f32,
};

/// GPU-aligned PGL4: column-major f32, 64 bytes, WGSL-compatible
pub const GpuPGL4 = extern struct {
    data: [16]f32 align(16),
};

/// GPU-aligned GeodesicState: 32 bytes, WGSL-compatible
pub const GpuGeodesicState = extern struct {
    qx: f32 align(16),
    qy: f32,
    qz: f32,
    qw: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    vw: f32,
};

/// GPU-aligned RK4Params uniform: 16 bytes
pub const GpuRK4Params = extern struct {
    dt: f32 align(16),
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
};

/// GPU-aligned MVP uniform: 64 bytes
pub const GpuMVP = extern struct {
    data: [16]f32 align(16),
};

// =============================================================================
// 3. КОНВЕРСИЯ CPU → GPU
// =============================================================================
//
// Zig f64 → GPU f32 с правильным layout.
// Column-major сохраняется.

/// Конверсия HomVec4 (f64) → GpuHomVec4 (f32)
pub fn homVec4ToGpu(p: HomVec4) GpuHomVec4 {
    return .{
        .x = @floatCast(p.x),
        .y = @floatCast(p.y),
        .z = @floatCast(p.z),
        .w = @floatCast(p.w),
    };
}

/// Конверсия PGL4 (f64 column-major) → GpuPGL4 (f32 column-major)
pub fn pgl4ToGpu(m: PGL4) GpuPGL4 {
    var result: GpuPGL4 = undefined;
    for (0..16) |i| {
        result.data[i] = @floatCast(m.data[i]);
    }
    return result;
}

/// Пакетная конверсия HomVec4[] → GpuHomVec4[]
pub fn batchToGpu(points: []const HomVec4, output: []GpuHomVec4) void {
    const n = @min(points.len, output.len);
    for (0..n) |i| {
        output[i] = homVec4ToGpu(points[i]);
    }
}

/// Конверсия GeodesicState → GpuGeodesicState
pub fn geodesicStateToGpu(state: anytype) GpuGeodesicState {
    return .{
        .qx = @floatCast(state.q[0]),
        .qy = @floatCast(state.q[1]),
        .qz = @floatCast(state.q[2]),
        .qw = @floatCast(state.q[3]),
        .vx = @floatCast(state.v[0]),
        .vy = @floatCast(state.v[1]),
        .vz = @floatCast(state.v[2]),
        .vw = @floatCast(state.v[3]),
    };
}

// =============================================================================
// 4. PIPELINE ДЕСКРИПТОРЫ (ДЛЯ MACH SYSGPU)
// =============================================================================
//
// Mach использует sysgpu — прямой маппинг на WebGPU C API.
// Pipeline дескрипторы — это данные для sysgpu.createComputePipeline()
// и sysgpu.createRenderPipeline().
//
// Мы НЕ вызываем sysgpu здесь (нет GPU в тестах).
// Мы ПОДГОТАВЛИВАЕМ всё для вызова из приложения.

/// Workgroup size для compute шейдеров
pub const WORKGROUP_SIZE: u32 = 64;

/// Compute pipeline kind
pub const ComputePipelineKind = enum {
    fs_distance_batch,
    pgl_action_batch,
    geodesic_rk4_step,
    idempotent_newton,
};

/// Compute pipeline descriptor (metadata для Mach)
pub const ComputePipelineDesc = struct {
    kind: ComputePipelineKind,
    shader: [:0]const u8, // WGSL source
    workgroup_size: u32,

    pub fn forKind(kind: ComputePipelineKind) ComputePipelineDesc {
        return switch (kind) {
            .fs_distance_batch => .{
                .kind = kind,
                .shader = wgsl_fs_distance_batch,
                .workgroup_size = WORKGROUP_SIZE,
            },
            .pgl_action_batch => .{
                .kind = kind,
                .shader = wgsl_pgl_action_batch,
                .workgroup_size = WORKGROUP_SIZE,
            },
            .geodesic_rk4_step => .{
                .kind = kind,
                .shader = wgsl_geodesic_rk4_step,
                .workgroup_size = WORKGROUP_SIZE,
            },
            .idempotent_newton => .{
                .kind = kind,
                .shader = wgsl_idempotent_newton,
                .workgroup_size = 16, // 16 матриц на workgroup
            },
        };
    }
};

/// Все compute pipeline дескрипторы
pub fn allComputePipelines() [4]ComputePipelineDesc {
    return .{
        ComputePipelineDesc.forKind(.fs_distance_batch),
        ComputePipelineDesc.forKind(.pgl_action_batch),
        ComputePipelineDesc.forKind(.geodesic_rk4_step),
        ComputePipelineDesc.forKind(.idempotent_newton),
    };
}

// =============================================================================
// 5. ПОЛНЫЙ WGSL МОДУЛЬ (СБОРКА ВСЕХ ШЕЙДЕРОВ)
// =============================================================================

/// Полный WGSL модуль: все структуры + все compute shaders
pub fn buildWgslModule() []const u8 {
    return wgsl_hom_vec4 ++
        "\n" ++
        wgsl_pgl4 ++
        "\n" ++
        wgsl_geodesic_state ++
        "\n" ++
        wgsl_fs_distance_batch ++
        "\n" ++
        wgsl_pgl_action_batch ++
        "\n" ++
        wgsl_geodesic_rk4_step ++
        "\n" ++
        wgsl_idempotent_newton;
}

// =============================================================================
// 6. CPU ЭКВИВАЛЕНТЫ (ДЛЯ ТЕСТИРОВАНИЯ БЕЗ GPU)
// =============================================================================
//
// Те же вычисления, что и в WGSL, но на CPU (f64).
// Позволяет тестировать логику шейдеров без GPU.

/// CPU: пакетная FS-distance (эквивалент wgsl_fs_distance_batch)
pub fn cpuFSDistanceBatch(
    positions: []const HomVec4,
    reference: HomVec4,
    output: []f64,
) void {
    const n = @min(positions.len, output.len);
    for (0..n) |i| {
        output[i] = p3_kernel.fsDistance(positions[i], reference);
    }
}

/// CPU: пакетное PGL-действие (эквивалент wgsl_pgl_action_batch)
pub fn cpuPGLActionBatch(
    m: PGL4,
    input: []const HomVec4,
    output: []HomVec4,
) void {
    const n = @min(input.len, output.len);
    for (0..n) |i| {
        output[i] = m.apply(input[i]);
    }
}

/// CPU: пакетный RK4 шаг (эквивалент wgsl_geodesic_rk4_step)
pub fn cpuGeodesicRK4Batch(
    states: []const p3_kernel.HomVec4, // pairs: [q0,v0,q1,v1,...]
    dt: f64,
    output: []p3_kernel.HomVec4,
) void {
    const n_states = states.len / 2;
    const n_out = @min(n_states, output.len / 2);
    for (0..n_out) |i| {
        const q = states[i * 2];
        const v = states[i * 2 + 1];
        // Простой Euler шаг для теста (RK4 в p3_geodesic)
        const speed_sq = v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w;
        const new_q = HomVec4.init(
            q.x + dt * v.x,
            q.y + dt * v.y,
            q.z + dt * v.z,
            q.w + dt * v.w,
        );
        const new_v = HomVec4.init(
            v.x - dt * speed_sq * q.x,
            v.y - dt * speed_sq * q.y,
            v.z - dt * speed_sq * q.z,
            v.w - dt * speed_sq * q.w,
        );
        output[i * 2] = new_q;
        output[i * 2 + 1] = new_v;
    }
}

// =============================================================================
// 7. ТЕСТЫ
// =============================================================================

test "GPU: WGSL shaders are non-empty" {
    try std.testing.expect(wgsl_fs_distance_batch.len > 0);
    try std.testing.expect(wgsl_pgl_action_batch.len > 0);
    try std.testing.expect(wgsl_geodesic_rk4_step.len > 0);
    try std.testing.expect(wgsl_idempotent_newton.len > 0);
    try std.testing.expect(wgsl_dehomogenize_vertex.len > 0);
}

test "GPU: GpuHomVec4 is 16 bytes" {
    try std.testing.expect(@sizeOf(GpuHomVec4) == 16);
}

test "GPU: GpuPGL4 is 64 bytes" {
    try std.testing.expect(@sizeOf(GpuPGL4) == 64);
}

test "GPU: GpuGeodesicState is 32 bytes" {
    try std.testing.expect(@sizeOf(GpuGeodesicState) == 32);
}

test "GPU: HomVec4 → GpuHomVec4 conversion" {
    const p = HomVec4.init(1.0, 2.0, 3.0, 1.0);
    const gpu = homVec4ToGpu(p);
    try std.testing.expectApproxEqAbs(gpu.x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.y, 2.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.z, 3.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.w, 1.0, 1e-5);
}

test "GPU: PGL4 → GpuPGL4 conversion preserves identity" {
    const I4 = PGL4.identity();
    const gpu = pgl4ToGpu(I4);
    // Column-major identity: data[0]=1, data[5]=1, data[10]=1, data[15]=1
    try std.testing.expectApproxEqAbs(gpu.data[0], 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.data[5], 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.data[10], 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu.data[15], 1.0, 1e-5);
}

test "GPU: batch conversion" {
    const points = [_]HomVec4{
        HomVec4.init(1, 0, 0, 1),
        HomVec4.init(0, 1, 0, 1),
    };
    var gpu_points: [2]GpuHomVec4 = undefined;
    batchToGpu(&points, &gpu_points);
    try std.testing.expectApproxEqAbs(gpu_points[0].x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(gpu_points[1].y, 1.0, 1e-5);
}

test "GPU: CPU equivalent FS distance batch" {
    const points = [_]HomVec4{
        HomVec4.init(1, 0, 0, 0),
        HomVec4.init(0, 1, 0, 0),
        HomVec4.init(0, 0, 1, 0),
    };
    const ref = HomVec4.init(1, 0, 0, 0);
    var distances: [3]f64 = undefined;
    cpuFSDistanceBatch(&points, ref, &distances);

    // distance(p, p) ≈ 0
    try std.testing.expectApproxEqAbs(distances[0], 0.0, 1e-10);
    // distance(p, q) = π/2 для ортогональных
    try std.testing.expectApproxEqAbs(distances[1], math.pi / 2.0, 1e-10);
    try std.testing.expectApproxEqAbs(distances[2], math.pi / 2.0, 1e-10);
}

test "GPU: CPU equivalent PGL action batch" {
    const T = p3_kernel.pglTranslate(1, 0, 0);
    const points = [_]HomVec4{
        HomVec4.fromCartesian(.{ 0, 0, 0 }),
        HomVec4.fromCartesian(.{ 1, 0, 0 }),
    };
    var output: [2]HomVec4 = undefined;
    cpuPGLActionBatch(T, &points, &output);

    // T(0,0,0) = (1,0,0)
    try std.testing.expectApproxEqAbs(output[0].x, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(output[0].w, 1.0, 1e-10);
    // T(1,0,0) = (2,0,0)
    try std.testing.expectApproxEqAbs(output[1].x, 2.0, 1e-10);
}

test "GPU: all compute pipelines are valid" {
    const pipelines = allComputePipelines();
    try std.testing.expect(pipelines.len == 4);
    for (pipelines) |p| {
        try std.testing.expect(p.shader.len > 0);
        try std.testing.expect(p.workgroup_size > 0);
    }
}

test "GPU: WGSL module assembly" {
    const module = buildWgslModule();
    try std.testing.expect(module.len > 100); // Non-trivial
}

test "GPU: RK4Params alignment" {
    try std.testing.expect(@sizeOf(GpuRK4Params) == 16);
}

test "GPU: MVP alignment" {
    try std.testing.expect(@sizeOf(GpuMVP) == 64);
}
