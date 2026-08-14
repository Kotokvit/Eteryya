// =============================================================================
// P³ BRIDGE — МОСТ P³ → R³ ДЛЯ РЕНДЕРЕРОВ
// =============================================================================
//
// P³-движок — это поставщик геометрии. Рендереры (raylib, WebGL, wgpu)
// работают в R³. Этот мост — единственный адаптер: ~200 строк
// дегомогенизации, конверсии типов, переключения афинных карт.
//
// Доноры:
//   - zmath: load/store для SIMD конверсии (переписано)
//   - raylib: RayVector3/RayMatrix типы (через @cImport — Фаза 3)
//
// Принцип: мост тонкий, без логики. Вся математика в ядре.
// =============================================================================
//
// АРХИТЕКТУРА:
//
//   P³ Engine (geometry)  ──→  p3_bridge  ──→  Renderer (R³)
//       HomVec4                  cartesian3()      Vector3
//       PGL4                     toRowMajor4x4()   Matrix4x4
//
//   Мост НЕ делает:
//     - Фубини-Штуди вычисления (это в ядре)
//     - PGL-действия (это в ядре)
//     - Физику (это в geodesic)
//
//   Мост ДЕЛАЕТ:
//     - Дегомогенизация P³ → R³ (с выбором афинной карты)
//     - Конверсия PGL4 → renderer-specific Matrix4x4
//     - Конверсия HomVec4 → renderer-specific Vector3
//     - Пакетная обработка (сотни тысяч точек для GPU)
//
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;
pub const F32x4 = p3_kernel.F32x4;

// =============================================================================
// 1. R³ ТИПЫ ДЛЯ РЕНДЕРЕРА
// =============================================================================

/// Декартов 3D-вектор (R³) — то, что понимает любой рендерер
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub inline fn zero() Vec3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub inline fn length(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub inline fn normalize(self: Vec3) Vec3 {
        const l = self.length();
        if (l < 1e-10) return .zero();
        return .{ .x = self.x / l, .y = self.y / l, .z = self.z / l };
    }

    pub inline fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub inline fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }
};

/// Row-major 4×4 матрица f32 — стандартный формат для GPU
pub const Mat4 = struct {
    m: [16]f32, // row-major: m[row*4+col]

    pub fn identity() Mat4 {
        return .{ .m = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    pub inline fn get(self: Mat4, row: usize, col: usize) f32 {
        return self.m[row * 4 + col];
    }
};

/// Вершина для GPU: позиция + нормаль + текстурные координаты
pub const Vertex = struct {
    position: Vec3,
    normal: Vec3,
    uv: [2]f32,
};

// =============================================================================
// 2. КОНВЕРСИЯ P³ → R³
// =============================================================================

/// Дегомогенизация: HomVec4 [X:Y:Z:W] → Vec3 (X/W, Y/W, Z/W)
///
/// Выбирает наилучшую афинную карту автоматически.
/// Точки на бесконечности (W≈0) обрабатываются через
/// переключение карты.
pub fn homVec4ToVec3(p: HomVec4) Vec3 {
    const card = p.pickBestCard();
    const affine = p.toAffine(card);
    return Vec3.init(
        @floatCast(affine[0]),
        @floatCast(affine[1]),
        @floatCast(affine[2]),
    );
}

/// Дегомогенизация в заданной карте
pub fn homVec4ToVec3Card(p: HomVec4, card: p3_kernel.AffineCard) Vec3 {
    const affine = p.toAffine(card);
    return Vec3.init(
        @floatCast(affine[0]),
        @floatCast(affine[1]),
        @floatCast(affine[2]),
    );
}

/// Конверсия PGL4 (column-major f64) → Mat4 (row-major f32)
///
/// GPU-рендереры обычно ожидают row-major f32.
/// Это единственное место, где convention меняется.
pub fn pgl4ToMat4(m: PGL4) Mat4 {
    var result: Mat4 = undefined;
    for (0..4) |row| {
        for (0..4) |col| {
            result.m[row * 4 + col] = @floatCast(m.get(row, col));
        }
    }
    return result;
}

/// Конверсия HomVec4 → SIMD F32x4 (для GPU upload)
pub fn homVec4ToF32x4(p: HomVec4) F32x4 {
    return p.toSimdF32();
}

// =============================================================================
// 3. ПАКЕТНАЯ ОБРАБОТКА
// =============================================================================

/// Пакетная дегомогенизация: массив HomVec4 → массив Vec3
/// Для рендеринга: тысячи точек конвертируются за один вызов.
pub fn batchToVec3(points: []const HomVec4, output: []Vec3) void {
    const n = @min(points.len, output.len);
    for (0..n) |i| {
        output[i] = homVec4ToVec3(points[i]);
    }
}

/// Пакетная дегомогенизация с PGL-действием:
/// 1. Применяет M к каждой точке
/// 2. Дегомогенизирует результат
/// 3. Записывает в output
pub fn batchTransformToVec3(m: PGL4, points: []const HomVec4, output: []Vec3) void {
    const n = @min(points.len, output.len);
    for (0..n) |i| {
        const transformed = m.apply(points[i]);
        output[i] = homVec4ToVec3(transformed);
    }
}

/// Пакетная конверсия HomVec4 → F32x4 (для GPU buffer upload)
pub fn batchToF32x4(points: []const HomVec4, output: []F32x4) void {
    const n = @min(points.len, output.len);
    for (0..n) |i| {
        output[i] = points[i].toSimdF32();
    }
}

// =============================================================================
// 4. ГЕНЕРАЦИЯ ПРИМИТИВОВ В P³
// =============================================================================
//
// Вместо евклидовых кубов/сфер — проективные примитивы.
// Это то, что видит рендерер.

/// Генерация больших кругов на S³ (проективных прямых на RP³).
///
/// Выход: n_points вершин вдоль геодезической γ(t) = cos(t)·p + sin(t)·v
pub fn generateGreatCircle(
    p: HomVec4,
    v: HomVec4,
    n_points: u32,
    output: []Vec3,
) void {
    const n = @min(n_points, @as(u32, @intCast(output.len)));
    for (0..n) |i| {
        const t = 2.0 * math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        const ct = @cos(t);
        const st = @sin(t);
        const point = HomVec4.init(
            ct * p.x + st * v.x,
            ct * p.y + st * v.y,
            ct * p.z + st * v.z,
            ct * p.w + st * v.w,
        );
        output[i] = homVec4ToVec3(point);
    }
}

/// Генерация точек на S³ через сетку (θ, φ) → HomVec4
/// Параметризация: [sin(θ)cos(φ) : sin(θ)sin(φ) : cos(θ) : w]
/// w — гомогенная координата (w=1 → афинная часть).
pub fn generateS3Grid(
    n_theta: u32,
    n_phi: u32,
    w: f64,
    output: []Vec3,
) u32 {
    var idx: u32 = 0;
    for (0..n_theta) |i| {
        const theta = math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n_theta - 1));
        for (0..n_phi) |j| {
            if (idx >= output.len) return idx;
            const phi = 2.0 * math.pi * @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(n_phi));
            const point = HomVec4.init(
                @sin(theta) * @cos(phi),
                @sin(theta) * @sin(phi),
                @cos(theta),
                w,
            );
            output[idx] = homVec4ToVec3(point);
            idx += 1;
        }
    }
    return idx;
}

// =============================================================================
// 5. ТЕСТЫ
// =============================================================================

test "Bridge: HomVec4 → Vec3 dehomogenization" {
    // Малые координаты чтобы W=1 доминировал → pickBestCard = UW
    const p = HomVec4.fromCartesian(.{ 0.1, 0.2, 0.3 }); // [0.1:0.2:0.3:1]
    const v = homVec4ToVec3(p);
    try std.testing.expectApproxEqAbs(v.x, 0.1, 1e-5);
    try std.testing.expectApproxEqAbs(v.y, 0.2, 1e-5);
    try std.testing.expectApproxEqAbs(v.z, 0.3, 1e-5);

    // Тест с явной UW картой для произвольной точки
    const p2 = HomVec4.init(2, 4, 6, 2); // [1:2:3:1] в UW
    const v2 = homVec4ToVec3Card(p2, .UW);
    try std.testing.expectApproxEqAbs(v2.x, 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(v2.y, 2.0, 1e-5);
    try std.testing.expectApproxEqAbs(v2.z, 3.0, 1e-5);
}

test "Bridge: infinity point switches card" {
    // [1:0:0:0] — точка на бесконечности (W=0)
    const p = HomVec4.init(1, 0, 0, 0);
    const card = p.pickBestCard();
    try std.testing.expect(card == .UX); // X наибольший

    const v = homVec4ToVec3(p);
    // В UX: (Y/X, Z/X, W/X) = (0, 0, 0)
    try std.testing.expectApproxEqAbs(v.x, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(v.y, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(v.z, 0.0, 1e-5);
}

test "Bridge: PGL4 → Mat4 convention" {
    const m = p3_kernel.pglTranslate(1, 2, 3);
    const mat4 = pgl4ToMat4(m);

    // Трансляция в последнем столбце (column-major PGL4 → row-major Mat4)
    // В row-major: translation = [m[3], m[7], m[11]] = [1, 2, 3]
    try std.testing.expectApproxEqAbs(mat4.get(0, 3), 1.0, 1e-5);
    try std.testing.expectApproxEqAbs(mat4.get(1, 3), 2.0, 1e-5);
    try std.testing.expectApproxEqAbs(mat4.get(2, 3), 3.0, 1e-5);
}

test "Bridge: batch dehomogenization" {
    // Малые координаты чтобы W доминировал
    const points = [_]HomVec4{
        HomVec4.fromCartesian(.{ 0.1, 0.2, 0.3 }),
        HomVec4.fromCartesian(.{ 0.0, 0.0, 0.5 }),
    };
    var output: [2]Vec3 = undefined;
    batchToVec3(&points, &output);

    try std.testing.expectApproxEqAbs(output[0].x, 0.1, 1e-5);
    try std.testing.expectApproxEqAbs(output[0].y, 0.2, 1e-5);
    try std.testing.expectApproxEqAbs(output[0].z, 0.3, 1e-5);
    try std.testing.expectApproxEqAbs(output[1].x, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(output[1].z, 0.5, 1e-5);
}

test "Bridge: batch with PGL transform" {
    const T = p3_kernel.pglTranslate(0.1, 0, 0);
    const points = [_]HomVec4{
        HomVec4.fromCartesian(.{ 0.01, 0, 0 }),
    };
    var output: [1]Vec3 = undefined;
    batchTransformToVec3(T, &points, &output);

    // T(0.01,0,0) = (0.11,0,0) — W=1 доминирует → UW
    try std.testing.expectApproxEqAbs(output[0].x, 0.11, 1e-4);
}

test "Bridge: Vec3 operations" {
    const a = Vec3.init(1, 0, 0);
    const b = Vec3.init(0, 1, 0);

    try std.testing.expectApproxEqAbs(Vec3.dot(a, b), 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(Vec3.dot(a, a), 1.0, 1e-5);

    const c = Vec3.cross(a, b);
    try std.testing.expectApproxEqAbs(c.x, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(c.y, 0.0, 1e-5);
    try std.testing.expectApproxEqAbs(c.z, 1.0, 1e-5);
}

test "Bridge: great circle generation" {
    // Точка с W≠0 чтобы была в афинной карте UW
    const p = HomVec4.fromCartesian(.{ 0, 0, 0 }); // [0:0:0:1]
    const v = HomVec4.init(1, 0, 0, 0); // касательный вектор
    var output: [8]Vec3 = undefined;
    generateGreatCircle(p, v, 8, &output);

    // Первая точка: γ(0) = [0:0:0:1] → Vec3(0,0,0)
    try std.testing.expectApproxEqAbs(output[0].x, 0.0, 1e-3);
    try std.testing.expectApproxEqAbs(output[0].y, 0.0, 1e-3);
}
