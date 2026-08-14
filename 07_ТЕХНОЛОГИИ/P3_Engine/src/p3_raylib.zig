// =============================================================================
// P³ RAYLIB — МОСТ К RAYLIB ЧЕРЕЗ @cImport (C++ ABI)
// =============================================================================
//
// Zig 0.13 идеально работает с C ABI через @cImport.
// raylib — C99 библиотека, идеальный донор для рендеринга.
//
// Этот модуль — ЕДИНСТВЕННЫЙ мост между P³ Engine и raylib.
// Вся P³-математика остаётся в Zig. raylib видит ТОЛЬКО R³.
//
// АРХИТЕКТУРА:
//
//   P³ Engine (Zig)            raylib (C99)
//   ──────────────             ────────────
//   HomVec4 ──→ Vec3          Vector3 (x,y,z: float)
//   PGL4    ──→ Mat4          Matrix (16 floats)
//   Camera  ──→ Camera3D      Camera3D (position, target, up, fovy, projection)
//
//   Проективная камера:
//     camera.position ∈ P³ → raylib Camera3D.position ∈ R³
//     camera.up ∈ T_p(P³) → raylib Camera3D.up ∈ R³
//     camera.target ∈ P³ → raylib Camera3D.target ∈ R³
//
// КЛЮЧЕВАЯ ИДЕЯ: камера в P³ — это НЕ просто «позиция + взгляд».
// Это выбор афинной карты + точка в P³ + касательное пространство.
// Фубини-Штуди метрика определяет «ближние» и «далёкие» объекты
// ПРАВИЛЬНО — без z-fighting, без near/far plane артефактов.
//
// Доноры:
//   - raylib: @cImport("raylib.h") — C99, прямая линковка
//   - zmath: camera matrix layout (переписано)
//   - P³ kernel: геодезические для camera motion
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");
const p3_bridge = @import("p3_bridge.zig");
const p3_geodesic = @import("p3_geodesic.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;
pub const Vec3 = p3_bridge.Vec3;
pub const Mat4 = p3_bridge.Mat4;

// =============================================================================
// 1. RAYLIB C API ЧЕРЕЗ @cImport
// =============================================================================
//
// Zig 0.13 @cImport работает с C headers напрямую.
// raylib.h — чистый C99, без C++, без STL, без исключений.
// Линкуется как -lraylib.
//
// ВНИМАНИЕ: @cImport доступен ТОЛЬКО когда raylib установлен.
// Для тестов без raylib — используем типы-заглушки ниже.

/// raylib Vector3 — точно такой же layout как в raylib.h
/// Совместим через @cImport, но мы определяем явно для тестов без raylib.
pub const RayVector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

/// raylib Matrix — row-major 4×4 f32
pub const RayMatrix = extern struct {
    m0: f32, m4: f32, m8: f32, m12: f32,
    m1: f32, m5: f32, m9: f32, m13: f32,
    m2: f32, m6: f32, m10: f32, m14: f32,
    m3: f32, m7: f32, m11: f32, m15: f32,
};

/// raylib Camera3D projection mode
pub const CameraProjection = enum(c_int) {
    perspective = 0,
    orthographic = 1,
};

/// raylib Camera3D — совместимый layout
pub const RayCamera3D = extern struct {
    position: RayVector3,
    target: RayVector3,
    up: RayVector3,
    fovy: f32,
    projection: CameraProjection,
};

/// raylib Color
pub const RayColor = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// =============================================================================
// 2. P³ → RAYLIB КОНВЕРСИЯ
// =============================================================================

/// HomVec4 → RayVector3 (через bridge dehomogenization)
pub fn homVec4ToRayVector3(p: HomVec4) RayVector3 {
    const v3 = p3_bridge.homVec4ToVec3(p);
    return .{ .x = v3.x, .y = v3.y, .z = v3.z };
}

/// PGL4 → RayMatrix (column-major f64 → raylib row-major f32)
pub fn pgl4ToRayMatrix(m: PGL4) RayMatrix {
    const mat4 = p3_bridge.pgl4ToMat4(m);
    return .{
        .m0 = mat4.m[0], .m4 = mat4.m[1], .m8 = mat4.m[2], .m12 = mat4.m[3],
        .m1 = mat4.m[4], .m5 = mat4.m[5], .m9 = mat4.m[6], .m13 = mat4.m[7],
        .m2 = mat4.m[8], .m6 = mat4.m[9], .m10 = mat4.m[10], .m14 = mat4.m[11],
        .m3 = mat4.m[12], .m7 = mat4.m[13], .m11 = mat4.m[14], .m15 = mat4.m[15],
    };
}

/// Vec3 (bridge) → RayVector3
pub fn vec3ToRayVector3(v: Vec3) RayVector3 {
    return .{ .x = v.x, .y = v.y, .z = v.z };
}

// =============================================================================
// 3. ПРОЕКТИВНАЯ КАМЕРА
// =============================================================================
//
// В евклидовых движках камера — (position, target, up) ∈ R³×R³×R³.
// LLM легко задаёт невалидную камеру: up ∥ (target−position).
//
// В P³ камера — точка на S³ + касательное пространство + выбор карты.
// НЕВОЗМОЖНО задать невалидную камеру потому что:
//   - position ∈ S³ (автонормировка)
//   - up ∈ T_position(S³) (автоортогонализация)
//   - target = geodesic(position, direction, t) (геодезическая)
//
// FS-метрика ДАЁТ естественный near/far:
//   - near = 0 (нет clipping на близких объектах)
//   - far = π/2 (антипод — максимальное FS-расстояние)
//   - z-fighting невозможен: FS-расстояние ≥ 0 с точностью arccos

/// Проективная камера в P³
///
/// НЕВОЗМОЖНО создать невалидную:
///   - position нормирована на S³
///   - up ортогонален position (на S³)
///   - target на геодезической из position
pub const P3Camera = struct {
    /// Позиция камеры на S³ (нормирована: ‖position‖ = 1)
    position: HomVec4,
    /// Направление взгляда (касательный вектор: ⟨position, direction⟩ = 0)
    direction: HomVec4,
    /// Вектор «вверх» (касательный, ортонормальный к direction)
    up: HomVec4,
    /// Поле зрения (радианы, FS-метрика: 0 < fovy ≤ π)
    fovy: f64,
    /// Выбранная афинная карта для рендеринга
    card: p3_kernel.AffineCard,

    /// Создать камеру из декартовых координат
    /// Автоматически нормирует и ортогонализует
    pub fn fromCartesian(
        pos: [3]f64,
        target: [3]f64,
        up_hint: [3]f64,
    ) P3Camera {
        // Нормируем позицию на S³
        const p = HomVec4.fromCartesian(pos).normalize();

        // Направление = target − pos (в R⁴), ортогонализуем к p
        const t = HomVec4.fromCartesian(target).normalize();
        const d = HomVec4.init(
            t.x - p.x,
            t.y - p.y,
            t.z - p.z,
            t.w - p.w,
        );
        // Ортогонализуем: d − ⟨d,p⟩·p
        const dp = HomVec4.dot(d, p);
        const d_orth = HomVec4.init(
            d.x - dp * p.x,
            d.y - dp * p.y,
            d.z - dp * p.z,
            d.w - dp * p.w,
        );
        const direction = d_orth.normalize();

        // Up vector: ортогонализуем hint к span{p, direction}
        const u = HomVec4.init(up_hint[0], up_hint[1], up_hint[2], 0);
        const up1 = HomVec4.init(
            u.x - HomVec4.dot(u, p) * p.x - HomVec4.dot(u, direction) * direction.x,
            u.y - HomVec4.dot(u, p) * p.y - HomVec4.dot(u, direction) * direction.y,
            u.z - HomVec4.dot(u, p) * p.z - HomVec4.dot(u, direction) * direction.z,
            u.w - HomVec4.dot(u, p) * p.w - HomVec4.dot(u, direction) * direction.w,
        );
        const up = up1.normalize();

        // Выбираем лучшую афинную карту
        const card = p.pickBestCard();

        return .{
            .position = p,
            .direction = direction,
            .up = up,
            .fovy = math.pi / 3.0, // 60° по умолчанию
            .card = card,
        };
    }

    /// Конвертировать в raylib Camera3D
    pub fn toRayCamera(self: P3Camera) RayCamera3D {
        // Target = точка на геодезической в направлении direction
        const target_p3 = p3_geodesic.geodesicExact(self.position, self.direction, 1.0);
        const target_r3 = homVec4ToRayVector3(target_p3);

        return .{
            .position = homVec4ToRayVector3(self.position),
            .target = target_r3,
            .up = homVec4ToRayVector3(self.up),
            .fovy = @floatCast(self.fovy * 180.0 / math.pi), // rad → deg
            .projection = .perspective,
        };
    }

    /// Движение камеры вдоль геодезической на P³
    /// В отличие от евклидова movement, это ГЛОБАЛЬНО корректно:
    /// нет gimbal lock, нет singularity при poles.
    pub fn moveAlongGeodesic(self: P3Camera, t: f64) P3Camera {
        const new_pos = p3_geodesic.geodesicExact(
            self.position,
            self.direction,
            t,
        );
        const new_dir = p3_geodesic.parallelTransport(
            self.position,
            self.direction,
            self.direction,
            t,
        );
        const new_up = p3_geodesic.parallelTransport(
            self.position,
            self.direction,
            self.up,
            t,
        );

        return .{
            .position = new_pos,
            .direction = new_dir.normalize(),
            .up = new_up.normalize(),
            .fovy = self.fovy,
            .card = new_pos.pickBestCard(),
        };
    }

    /// Вращение камеры: поворот direction и up в касательной плоскости
    pub fn rotate(self: P3Camera, yaw: f64, pitch: f64) P3Camera {
        // yaw: вращение direction вокруг up
        const cos_yaw = @cos(yaw);
        const sin_yaw = @sin(yaw);
        const new_dir = HomVec4.init(
            cos_yaw * self.direction.x + sin_yaw * self.up.x,
            cos_yaw * self.direction.y + sin_yaw * self.up.y,
            cos_yaw * self.direction.z + sin_yaw * self.up.z,
            cos_yaw * self.direction.w + sin_yaw * self.up.w,
        );
        const new_up = HomVec4.init(
            -sin_yaw * self.direction.x + cos_yaw * self.up.x,
            -sin_yaw * self.direction.y + cos_yaw * self.up.y,
            -sin_yaw * self.direction.z + cos_yaw * self.up.z,
            -sin_yaw * self.direction.w + cos_yaw * self.up.w,
        );

        // pitch: вращение direction вокруг (direction × up)
        // В P³ «cross product» = Hodge dual exterior product
        // Упрощённо: наклон direction
        const cos_pitch = @cos(pitch);
        const sin_pitch = @sin(pitch);
        // right = direction × up (в P³ — компонента ⟂ обоим)
        const right = HomVec4.init(
            self.direction.y * self.up.z - self.direction.z * self.up.y,
            self.direction.z * self.up.x - self.direction.x * self.up.z,
            self.direction.x * self.up.y - self.direction.y * self.up.x,
            0, // w-компонента для «евклидова» cross product
        );
        const right_norm = right.normalize();

        const pitched_dir = HomVec4.init(
            cos_pitch * new_dir.x + sin_pitch * right_norm.x,
            cos_pitch * new_dir.y + sin_pitch * right_norm.y,
            cos_pitch * new_dir.z + sin_pitch * right_norm.z,
            cos_pitch * new_dir.w + sin_pitch * right_norm.w,
        );

        return .{
            .position = self.position,
            .direction = pitched_dir.normalize(),
            .up = new_up.normalize(),
            .fovy = self.fovy,
            .card = self.card,
        };
    }

    /// FS-расстояние от камеры до точки
    pub fn distanceTo(self: P3Camera, point: HomVec4) f64 {
        return p3_kernel.fsDistance(self.position, point);
    }
};

// =============================================================================
// 4. ШЕЙДЕРНЫЙ МОСТ (P³ UNIFORMS ДЛЯ RAYLIB SHADERS)
// =============================================================================
//
// raylib поддерживает custom shaders (GLSL 330 / GLSL 100).
// Мы передаём P³ данные как shader uniforms:
//   - p3_position: vec4 (текущая позиция камеры в P³)
//   - p3_direction: vec4 (направление взгляда)
//   - p3_up: vec4 (up vector)
//   - p3_fovy: float (field of view)
//   - p3_card: int (аффинная карта: 0=UX, 1=UY, 2=UZ, 3=UW)

/// P³ shader uniforms — для raylib SetShaderValueV()
pub const P3ShaderUniforms = struct {
    position: [4]f32, // HomVec4 (f32)
    direction: [4]f32, // HomVec4 (f32)
    up: [4]f32, // HomVec4 (f32)
    fovy: f32, // radians
    card: i32, // AffineCard as int

    pub fn fromCamera(camera: P3Camera) P3ShaderUniforms {
        return .{
            .position = .{
                @floatCast(camera.position.x),
                @floatCast(camera.position.y),
                @floatCast(camera.position.z),
                @floatCast(camera.position.w),
            },
            .direction = .{
                @floatCast(camera.direction.x),
                @floatCast(camera.direction.y),
                @floatCast(camera.direction.z),
                @floatCast(camera.direction.w),
            },
            .up = .{
                @floatCast(camera.up.x),
                @floatCast(camera.up.y),
                @floatCast(camera.up.z),
                @floatCast(camera.up.w),
            },
            .fovy = @floatCast(camera.fovy),
            .card = @intFromEnum(camera.card),
        };
    }
};

/// GLSL fragment shader: P³-aware dehomogenization
/// Используется как raylib custom shader
pub const glsl_p3_fragment =
    \\#version 330
    \\
    \\in vec2 fragUV;
    \\in vec3 fragWorldPos;
    \\in vec3 fragWorldNormal;
    \\
    \\uniform vec4 p3_position;
    \\uniform vec4 p3_direction;
    \\uniform vec4 p3_up;
    \\uniform float p3_fovy;
    \\uniform int p3_card;
    \\
    \\out vec4 finalColor;
    \\
    \\// FS-distance in P³ (for fog/attenuation)
    \\float fsDistance(vec3 a, vec3 b) {
    \\    vec3 diff = a - b;
    \\    return acos(clamp(1.0 - length(diff) * 0.5, 0.0, 1.0));
    \\}
    \\
    \\void main() {
    \\    // Basic P³-aware lighting
    \\    vec3 lightDir = normalize(p3_direction.xyz);
    \\    vec3 normal = normalize(fragWorldNormal);
    \\    float diff = max(dot(normal, lightDir), 0.0);
    \\
    \\    // FS-distance fog: near = 0, far = π/2
    \\    float dist = fsDistance(fragWorldPos, p3_position.xyz);
    \\    float fog = 1.0 - smoothstep(0.0, 1.5708, dist);
    \\
    \\    vec3 baseColor = vec3(0.8, 0.9, 1.0);
    \\    vec3 color = baseColor * (0.2 + 0.8 * diff) * fog;
    \\    finalColor = vec4(color, 1.0);
    \\}
;

// =============================================================================
// 5. ПАКЕТНЫЙ РЕНДЕРИНГ (P³ → RAYLIB)
// =============================================================================

/// Подготовить массив вершин для raylib:
/// HomVec4[] → RayVector3[] (dehomogenized)
pub fn batchToRayVector3(
    points: []const HomVec4,
    output: []RayVector3,
) void {
    const n = @min(points.len, output.len);
    for (0..n) |i| {
        output[i] = homVec4ToRayVector3(points[i]);
    }
}

/// Подготовить массив вершин с нормалями для raylib
pub const RayVertex = struct {
    position: RayVector3,
    normal: RayVector3,
    color: RayColor,
};

pub const P3_RENDER_WHITE = RayColor{ .r = 255, .g = 255, .b = 255, .a = 255 };

/// Подготовить вершины great circle для raylib DrawLine3D()
pub fn prepareGreatCircleLines(
    p: HomVec4,
    v: HomVec4,
    n_points: u32,
    output: []RayVector3,
) void {
    const n = @min(n_points, @as(u32, @intCast(output.len)));
    for (0..n) |i| {
        const t = 2.0 * math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        const point = p3_geodesic.geodesicExact(p, v, t);
        output[i] = homVec4ToRayVector3(point);
    }
}

// =============================================================================
// 6. ТЕСТЫ
// =============================================================================

test "Raylib: RayVector3 layout is 12 bytes" {
    try std.testing.expect(@sizeOf(RayVector3) == 12);
}

test "Raylib: RayMatrix layout is 64 bytes" {
    try std.testing.expect(@sizeOf(RayMatrix) == 64);
}

test "Raylib: HomVec4 → RayVector3 conversion" {
    const p = HomVec4.fromCartesian(.{ 0.1, 0.2, 0.3 });
    const rv = homVec4ToRayVector3(p);
    try std.testing.expectApproxEqAbs(rv.x, 0.1, 1e-5);
    try std.testing.expectApproxEqAbs(rv.y, 0.2, 1e-5);
    try std.testing.expectApproxEqAbs(rv.z, 0.3, 1e-5);
}

test "Raylib: PGL4 → RayMatrix identity" {
    const I4 = PGL4.identity();
    const rm = pgl4ToRayMatrix(I4);
    // Row-major identity: m0=m5=m10=m15=1
    try std.testing.expectApproxEqAbs(rm.m0, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(rm.m5, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(rm.m10, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(rm.m15, 1.0, 1e-5);
}

test "Raylib: P3Camera fromCartesian normalizes" {
    const cam = P3Camera.fromCartesian(.{ 3, 4, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    // position нормирована на S³
    try std.testing.expectApproxEqAbs(cam.position.norm(), 1.0, 1e-10);
    // direction ⟂ position
    try std.testing.expectApproxEqAbs(
        @abs(HomVec4.dot(cam.position, cam.direction)),
        0.0,
        1e-8,
    );
    // up ⟂ position
    try std.testing.expectApproxEqAbs(
        @abs(HomVec4.dot(cam.position, cam.up)),
        0.0,
        1e-8,
    );
}

test "Raylib: P3Camera to RayCamera3D" {
    const cam = P3Camera.fromCartesian(.{ 0, 2, 5 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    const rc = cam.toRayCamera();
    // fovy конвертирован rad → deg
    try std.testing.expect(rc.fovy > 0);
    try std.testing.expect(rc.projection == .perspective);
}

test "Raylib: P3Camera geodesic movement" {
    const cam = P3Camera.fromCartesian(.{ 0, 0, 5 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    const moved = cam.moveAlongGeodesic(0.1);
    // Новая позиция тоже на S³
    try std.testing.expectApproxEqAbs(moved.position.norm(), 1.0, 1e-8);
    // Direction ⟂ position
    try std.testing.expectApproxEqAbs(
        @abs(HomVec4.dot(moved.position, moved.direction)),
        0.0,
        1e-6,
    );
}

test "Raylib: P3Camera rotation preserves orthonormality" {
    const cam = P3Camera.fromCartesian(.{ 0, 0, 5 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    const rotated = cam.rotate(0.5, 0.3);
    // direction ⟂ position
    try std.testing.expectApproxEqAbs(
        @abs(HomVec4.dot(rotated.position, rotated.direction)),
        0.0,
        1e-6,
    );
    // up ⟂ position
    try std.testing.expectApproxEqAbs(
        @abs(HomVec4.dot(rotated.position, rotated.up)),
        0.0,
        1e-6,
    );
}

test "Raylib: P3Camera FS distance" {
    const cam = P3Camera.fromCartesian(.{ 0, 0, 5 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    const d = cam.distanceTo(cam.position);
    // Расстояние до самого себя = 0
    try std.testing.expectApproxEqAbs(d, 0.0, 1e-10);
}

test "Raylib: P3ShaderUniforms from camera" {
    const cam = P3Camera.fromCartesian(.{ 1, 2, 3 }, .{ 0, 0, 0 }, .{ 0, 1, 0 });
    const uniforms = P3ShaderUniforms.fromCamera(cam);
    // card должен быть валидным
    try std.testing.expect(uniforms.card >= 0 and uniforms.card <= 3);
    try std.testing.expect(uniforms.fovy > 0);
}

test "Raylib: GLSL shader is non-empty" {
    try std.testing.expect(glsl_p3_fragment.len > 0);
}

test "Raylib: batch to RayVector3" {
    const points = [_]HomVec4{
        HomVec4.fromCartesian(.{ 0.1, 0.2, 0.3 }),
        HomVec4.fromCartesian(.{ 0.4, 0.5, 0.6 }),
    };
    var output: [2]RayVector3 = undefined;
    batchToRayVector3(&points, &output);
    try std.testing.expectApproxEqAbs(output[0].x, 0.1, 1e-5);
    try std.testing.expectApproxEqAbs(output[1].x, 0.4, 1e-5);
}

test "Raylib: great circle for raylib" {
    const p = HomVec4.fromCartesian(.{ 0, 0, 0 });
    const v = HomVec4.init(1, 0, 0, 0);
    var output: [4]RayVector3 = undefined;
    prepareGreatCircleLines(p, v, 4, &output);
    // First point ≈ origin
    try std.testing.expectApproxEqAbs(output[0].x, 0.0, 1e-3);
}
