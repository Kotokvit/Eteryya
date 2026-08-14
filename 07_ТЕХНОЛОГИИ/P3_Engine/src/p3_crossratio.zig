// =============================================================================
// P³ CROSS-RATIO — ДВОЙНОЕ ОТНОШЕНИЕ И ПОЛЮС-ПОЛЯР
// =============================================================================
//
// Двойное отношение (cross-ratio) — фундаментальный инвариант
// проективной геометрии. PGL(n) — это в точности группа
// преобразований, сохраняющих cross-ratio.
//
// Для четырёх коллинеарных точек A, B, C, D на проективной прямой:
//   [A,B;C,D] = (AC/BC) / (AD/BD)
//
// где AC — «расстояние» (в афинной карте) между A и C.
//
// В однородных координатах (для точек на прямой в P³):
//   [A,B;C,D] = det(A,C)·det(B,D) / (det(A,D)·det(B,C))
//
// Свойства:
//   1. PGL-инвариант: [f(A),f(B);f(C),f(D)] = [A,B;C,D] для f ∈ PGL
//   2. [A,B;C,D] = [B,A;D,C] = [C,D;A,B]
//   3. [A,B;C,D] · [A,C;B,D] = [A,B;D,C]
//   4. [A,B;C,D] = −1 ↔ гармоническая четвёрка
//
// Доноры:
//   - Классическая проективная геометрия (Poncelet, Möbius)
//   - POLER Eq.13: полюс-полярное дуальное преобразование
//   - zm/zmath: структура вычислений (переписано)
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. ДВОЙНОЕ ОТНОШЕНИЕ (CROSS-RATIO)
// =============================================================================

/// 2×2 определитель для двух 2D-векторов (для точек на прямой)
/// det(a,b) = a₀·b₁ − a₁·b₀
pub inline fn det2(a0: f64, a1: f64, b0: f64, b1: f64) f64 {
    return a0 * b1 - a1 * b0;
}

/// Cross-ratio четырёх точек на проективной прямой P¹.
///
/// Точки заданы однородными координатами [a₀:a₁].
/// [A,B;C,D] = det(A,C)·det(B,D) / (det(A,D)·det(B,C))
///
/// Если det(A,D)·det(B,C) = 0 — вырожденная конфигурация.
pub fn crossRatio1D(
    a: [2]f64,
    b: [2]f64,
    c: [2]f64,
    d: [2]f64,
) ?f64 {
    const ac = det2(a[0], a[1], c[0], c[1]);
    const bd = det2(b[0], b[1], d[0], d[1]);
    const ad = det2(a[0], a[1], d[0], d[1]);
    const bc = det2(b[0], b[1], c[0], c[1]);

    const denom = ad * bc;
    if (@abs(denom) < 1e-15) return null; // Вырождено
    return (ac * bd) / denom;
}

/// Cross-ratio четырёх коллинеарных точек в P³.
///
/// Если точки лежат на прямой, проецируем на 2D (выбираем 2 координаты
/// с наибольшей проекцией) и вычисляем cross-ratio.
///
/// Используем координаты, максимизирующие «разброс» проекции.
pub fn crossRatioCollinear(a: HomVec4, b: HomVec4, c: HomVec4, d: HomVec4) ?f64 {
    // Выбираем лучшую пару координат для проекции
    // (максимизируем определитель)
    var best_det: f64 = 0;
    var best_i: usize = 0;
    var best_j: usize = 1;

    const coords_a = [4]f64{ a.x, a.y, a.z, a.w };
    const coords_b = [4]f64{ b.x, b.y, b.z, b.w };

    for (0..4) |i| {
        for ((i + 1)..4) |j| {
            const d_val = @abs(det2(coords_a[i], coords_a[j], coords_b[i], coords_b[j]));
            if (d_val > best_det) {
                best_det = d_val;
                best_i = i;
                best_j = j;
            }
        }
    }

    if (best_det < 1e-15) return null; // Точки совпадают

    const ca = [4]f64{ a.x, a.y, a.z, a.w };
    const cb = [4]f64{ b.x, b.y, b.z, b.w };
    const cc = [4]f64{ c.x, c.y, c.z, c.w };
    const cd = [4]f64{ d.x, d.y, d.z, d.w };

    return crossRatio1D(
        .{ ca[best_i], ca[best_j] },
        .{ cb[best_i], cb[best_j] },
        .{ cc[best_i], cc[best_j] },
        .{ cd[best_i], cd[best_j] },
    );
}

/// Проверка гармонической четвёрки: [A,B;C,D] = −1
///
/// Гармоническая четвёрка — фундаментальное понятие:
/// C и D гармонически сопряжены относительно A и B.
/// Это означает, что C и D симметричны относительно
/// «середины» пары A, B в проективном смысле.
pub fn isHarmonic(a: [2]f64, b: [2]f64, c: [2]f64, d: [2]f64, tol: f64) bool {
    const cr = crossRatio1D(a, b, c, d) orelse return false;
    return @abs(cr + 1.0) < tol;
}

/// Гармонически сопряжённая точка D к C относительно A, B.
///
/// Если [A,B;C,D] = −1, то:
/// D = 2·⟨A,C⟩·⟨B,C⟩ / (⟨A,C⟩ + ⟨B,C⟩) — в афинной карте.
///
/// Простой случай (афинная карта, a=0, b=∞):
/// D = 2c (удвоение).
pub fn harmonicConjugate1D(a: [2]f64, b: [2]f64, c: [2]f64) ?[2]f64 {
    // [A,B;C,D] = −1
    // det(A,C)·det(B,D) = −det(A,D)·det(B,C)
    //
    // Пусть A=[a0:a1], B=[b0:b1], C=[c0:c1], D=[d0:d1]
    // Решаем для D:
    const ac = det2(a[0], a[1], c[0], c[1]);
    const bc = det2(b[0], b[1], c[0], c[1]);

    // det(B,D)·ac = −det(A,D)·bc
    // ac·(b0·d1−b1·d0) = −bc·(a0·d1−a1·d0)
    // d1·(ac·b0+bc·a0) = d0·(ac·b1+bc·a1)
    // D = [ac·b1+bc·a1 : ac·b0+bc·a0]

    const d0 = ac * b[1] + bc * a[1];
    const d1 = ac * b[0] + bc * a[0];

    if (@abs(d0) < 1e-15 and @abs(d1) < 1e-15) return null;
    return .{ d0, d1 };
}

// =============================================================================
// 2. PGL-ИНВАРИАНТНОСТЬ CROSS-RATIO
// =============================================================================
//
// Проверка: для любого f ∈ PGL(4,ℝ):
//   [f(A),f(B);f(C),f(D)] = [A,B;C,D]
//
// Это ОПРЕДЕЛЯЮЩЕЕ свойство PGL.

/// Проверка PGL-инвариантности cross-ratio численно.
/// Применяет M ко всем четырём точкам и сравнивает cross-ratio.
pub fn verifyPGLInvariance(
    m: PGL4,
    a: HomVec4,
    b: HomVec4,
    c: HomVec4,
    d: HomVec4,
    tol: f64,
) bool {
    const cr_orig = crossRatioCollinear(a, b, c, d) orelse return false;
    const cr_transformed = crossRatioCollinear(
        m.apply(a),
        m.apply(b),
        m.apply(c),
        m.apply(d),
    ) orelse return false;
    return @abs(cr_orig - cr_transformed) < tol;
}

// =============================================================================
// 3. ПОЛЮС-ПОЛЯРНАЯ ДУАЛЬНОСТЬ
// =============================================================================
//
// В P³ с невырожденной квадрикой Q (заданной симметричной 4×4 матрицей):
//
//   Полюс точки p: полярная плоскость π = Q·p
//   Полюс плоскости π: точка p = Q⁻¹·π
//
// Это дуальность точка ↔ плоскость — фундамент P³.
// В POLER: Eq.13 — «дуальное сопряжение».
//
// Инцидентность: точка p лежит на поляре точки q ↔ ⟨p, Q·q⟩ = 0.

/// Полярная плоскость точки p относительно квадрики Q.
/// π = Q · p (однородные координаты плоскости [a:b:c:d] для ax+by+cz+dw=0)
pub fn polarPlane(q: PGL4, p: HomVec4) HomVec4 {
    return q.apply(p);
}

/// Полюс плоскости π относительно квадрики Q.
/// p = Q⁻¹ · π
pub fn polePoint(q: PGL4, pi: HomVec4, delta: f64) HomVec4 {
    const q_inv = q.inverse(delta, 12);
    return q_inv.apply(pi);
}

/// Проверка инцидентности: лежит ли точка p на своей поляре?
/// ⟨p, Q·p⟩ = 0 ↔ p лежит на квадрике Q.
pub fn isOnQuadric(q: PGL4, p: HomVec4, tol: f64) bool {
    const polar = q.apply(p);
    return @abs(HomVec4.dot(p, polar)) < tol;
}

/// Двойное соотношение точка-полюс:
/// Если p — полюс плоскости π, то для любой точки x на π:
/// ⟨x, Q·p⟩ = 0.
/// Это проверяется для массива точек на плоскости.
pub fn verifyPolePolarIncidence(
    q: PGL4,
    pole: HomVec4,
    points_on_plane: []const HomVec4,
    tol: f64,
) bool {
    const polar = q.apply(pole);
    for (points_on_plane) |pt| {
        if (@abs(HomVec4.dot(pt, polar)) > tol) return false;
    }
    return true;
}

// =============================================================================
// 4. ТЕСТЫ
// =============================================================================

test "Cross-ratio: basic computation" {
    // На P¹: A=[1:0], B=[0:1], C=[1:1], D=[2:1]
    // [A,B;C,D] = det(A,C)·det(B,D) / (det(A,D)·det(B,C))
    // det(A,C) = 1·1−0·1 = 1
    // det(B,D) = 0·1−1·2 = −2
    // det(A,D) = 1·1−0·2 = 1
    // det(B,C) = 0·1−1·1 = −1
    // [A,B;C,D] = (1·(−2))/(1·(−1)) = 2
    const cr = crossRatio1D(.{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 });
    try std.testing.expect(cr != null);
    try std.testing.expectApproxEqAbs(cr.?, 2.0, 1e-10);
}

test "Cross-ratio: harmonic quartet [A,B;C,D] = −1" {
    // Классический пример: A=[1:0], B=[0:1], C=[1:1], D=[1:−1]
    // det(A,C) = 1, det(B,D) = 0·(−1)−1·1 = −1
    // det(A,D) = 1·(−1)−0·1 = −1, det(B,C) = 0·1−1·1 = −1
    // [A,B;C,D] = (1·(−1))/((−1)·(−1)) = −1
    const cr = crossRatio1D(.{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 1, -1 });
    try std.testing.expect(cr != null);
    try std.testing.expectApproxEqAbs(cr.?, -1.0, 1e-10);
    try std.testing.expect(isHarmonic(.{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 1, -1 }, 1e-8));
}

test "Cross-ratio: symmetry [A,B;C,D] = [B,A;D,C]" {
    const a = [2]f64{ 1, 0 };
    const b = [2]f64{ 0, 1 };
    const c = [2]f64{ 2, 1 };
    const d = [2]f64{ 3, 1 };

    const cr1 = crossRatio1D(a, b, c, d);
    const cr2 = crossRatio1D(b, a, d, c);
    try std.testing.expect(cr1 != null);
    try std.testing.expect(cr2 != null);
    try std.testing.expectApproxEqAbs(cr1.?, cr2.?, 1e-10);
}

test "Cross-ratio: PGL invariance" {
    // Четыре точки на прямой x=y=z в P³
    const a = HomVec4.init(1, 1, 1, 0);
    const b = HomVec4.init(2, 2, 2, 1);
    const c = HomVec4.init(3, 3, 3, 2);
    const d = HomVec4.init(5, 5, 5, 3);

    const m = p3_kernel.pglScale(2, 3, 4); // Проективное преобразование
    try std.testing.expect(verifyPGLInvariance(m, a, b, c, d, 1e-6));
}

test "Cross-ratio: harmonic conjugate" {
    const a = [2]f64{ 1, 0 };
    const b = [2]f64{ 0, 1 };
    const c = [2]f64{ 1, 1 };

    const d = harmonicConjugate1D(a, b, c);
    try std.testing.expect(d != null);

    // Проверяем: [A,B;C,D] = −1
    const cr = crossRatio1D(a, b, c, d.?);
    try std.testing.expect(cr != null);
    try std.testing.expectApproxEqAbs(cr.?, -1.0, 1e-8);
}

test "Pole-polar: point on quadric lies on its polar" {
    // Квадрика Q = diag(1,1,1,−1) (Лоренцева)
    // Точка p = [1,0,0,1]: ⟨p,Q·p⟩ = 1+0+0−1 = 0 → на квадрике
    const q = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, -1 },
    });
    const p = HomVec4.init(1, 0, 0, 1);
    try std.testing.expect(isOnQuadric(q, p, 1e-10));
}

test "Pole-polar: interior point not on quadric" {
    const q = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, -1 },
    });
    const p = HomVec4.init(0, 0, 0, 1); // ⟨p,Q·p⟩ = −1 ≠ 0
    try std.testing.expect(!isOnQuadric(q, p, 1e-10));
}

test "Pole-polar: polar plane computation" {
    // Q = I (стандартная квадрика)
    // Поляра p=[1,2,3,4]: π = Q·p = [1,2,3,4] (самодвойственная)
    const q = PGL4.identity();
    const p = HomVec4.init(1, 2, 3, 4);
    const pi = polarPlane(q, p);

    try std.testing.expectApproxEqAbs(pi.x, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(pi.y, 2.0, 1e-10);
    try std.testing.expectApproxEqAbs(pi.z, 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(pi.w, 4.0, 1e-10);
}
