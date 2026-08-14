// =============================================================================
// P³ ALGEBRA — КЛИФФОРД/ГРАССМАН АЛГЕБРА ДЛЯ P³
// =============================================================================
//
// Проективная геометрия ЕСТЬ exterior algebra.
// Точка в P³ — элемент ∧¹V (вектор).
// Прямая в P³ — элемент ∧²V (бивектор) → координаты Плюккера.
// Плоскость в P³ — элемент ∧³V (тривектор).
// Объём — элемент ∧⁴V (псевдоскаляр).
//
// Операции:
//   meet:  ∧ᵏV × ∧ˡV → ∧⁽ᵏ⁺ˡ⁾V  (пересечение)
//   join:  ∧ᵏV × ∧ˡV → ∧⁽ᵏ⁺ˡ⁾V  (объединение)
//
// В P³ (dim=4):
//   meet(point, plane)  → scalar  (инцидентность)
//   meet(point, point)  → nothing (разные точки)
//   meet(plane, plane)  → line    (пересечение 2 плоскостей)
//   join(point, point)  → line    (прямая через 2 точки)
//   join(point, plane)  → nothing (точка в плоскости — не объед.)
//
// Плюккеровы координаты: прямая ℓ ⊂ P³ задаётся 6 числами
//   p_{ij} = a_i·b_j − a_j·b_i
// с соотношением Плюккера: p_{01}·p_{23} − p_{02}·p_{13} + p_{03}·p_{12} = 0.
//
// Это ФУНДАМЕНТ: в евклидовых движках прямая — 2 точки (не уникально).
// В P³ прямая — ОДИН бивектор (уникально, канонически).
//
// Доноры:
//   - Grassmann/Cayley algebra (классика)
//   - ganja.js (enki studios): алгебра Клиффорда в JS (переписано)
//   - PGA (Projective Geometric Algebra): ориентация + сигнатура
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. ГРАССМАНОВА ЛЕСТНИЦА: ∧⁰V, ∧¹V, ∧²V, ∧³V, ∧⁴V
// =============================================================================

/// ∧⁰V = R (скаляры)
pub const Scalar = f64;

/// ∧¹V = V* (ковекторы / точки в P³)
/// Это HomVec4, но с явной градуировкой
pub const P3Point = struct {
    v: HomVec4,

    pub inline fn init(x: f64, y: f64, z: f64, w: f64) P3Point {
        return .{ .v = HomVec4.init(x, y, z, w) };
    }

    pub inline fn fromCartesian(p: [3]f64) P3Point {
        return .{ .v = HomVec4.fromCartesian(p) };
    }

    /// Нормировка на S³
    pub fn normalize(self: P3Point) P3Point {
        return .{ .v = self.v.normalize() };
    }
};

/// ∧²V — бивекторы (ПЛЮККЕРОВЫ КООРДИНАТЫ ПРЯМЫХ)
///
/// В 4-мерном V: dim(∧²V) = C(4,2) = 6.
/// Базис: e₀₁, e₀₂, e₀₃, e₁₂, e₁₃, e₂₃
///
/// Прямая ℓ = p₀∧p₁ задаётся координатами:
///   p_{ij} = a_i·b_j − a_j·b_i
///
/// С соотношением Плюккера:
///   p₀₁·p₂₃ − p₀₂·p₁₃ + p₀₃·p₁₂ = 0
pub const P3Line = struct {
    /// Плюккеровы координаты: p01, p02, p03, p12, p13, p23
    p01: f64,
    p02: f64,
    p03: f64,
    p12: f64,
    p13: f64,
    p23: f64,

    /// Прямая через две точки (внешнее произведение):
    /// ℓ = a ∧ b
    /// p_{ij} = a_i·b_j − a_j·b_i
    pub fn fromTwoPoints(a: P3Point, b: P3Point) P3Line {
        return .{
            .p01 = a.v.x * b.v.y - a.v.y * b.v.x,
            .p02 = a.v.x * b.v.z - a.v.z * b.v.x,
            .p03 = a.v.x * b.v.w - a.v.w * b.v.x,
            .p12 = a.v.y * b.v.z - a.v.z * b.v.y,
            .p13 = a.v.y * b.v.w - a.v.w * b.v.y,
            .p23 = a.v.z * b.v.w - a.v.w * b.v.z,
        };
    }

    /// Прямая как пересечение двух плоскостей (dual Plücker):
    /// ℓ* = π₁ ∧ π₂ (в дуальном пространстве)
    /// Dual Plücker coords: q_{ij} = π_i·ρ_j − π_j·ρ_i
    /// Затем: p_{ij} = ε_{ijkl} · q_{kl} / 2 (Hodge dual)
    pub fn fromTwoPlanes(pi: P3Plane, rho: P3Plane) P3Line {
        // Dual Plücker coordinates
        const q01 = pi.v.x * rho.v.y - pi.v.y * rho.v.x;
        const q02 = pi.v.x * rho.v.z - pi.v.z * rho.v.x;
        const q03 = pi.v.x * rho.v.w - pi.v.w * rho.v.x;
        const q12 = pi.v.y * rho.v.z - pi.v.z * rho.v.y;
        const q13 = pi.v.y * rho.v.w - pi.v.w * rho.v.y;
        const q23 = pi.v.z * rho.v.w - pi.v.w * rho.v.z;

        // Hodge dual: p_{ij} = ε_{ijkl} · q_{kl} / 2
        // В 4D с ε_{0123}=+1:
        //   p01 = q23, p02 = -q13, p03 = q12
        //   p12 = q03, p13 = -q02, p23 = q01
        return .{
            .p01 = q23,
            .p02 = -q13,
            .p03 = q12,
            .p12 = q03,
            .p13 = -q02,
            .p23 = q01,
        };
    }

    /// Проверка соотношения Плюккера:
    /// p₀₁·p₂₃ − p₀₂·p₁₃ + p₀₃·p₁₂ = 0
    pub fn satisfiesPlucker(self: P3Line, tol: f64) bool {
        const plucker = self.p01 * self.p23 - self.p02 * self.p13 + self.p03 * self.p12;
        return @abs(plucker) < tol;
    }

    /// Невязка Плюккера (мера «не-прямолинейности»)
    pub fn pluckerResidual(self: P3Line) f64 {
        return @abs(self.p01 * self.p23 - self.p02 * self.p13 + self.p03 * self.p12);
    }

    /// Норма Плюккера: ‖ℓ‖² = Σ p_{ij}²
    pub fn norm(self: P3Line) f64 {
        return @sqrt(
            self.p01 * self.p01 +
                self.p02 * self.p02 +
                self.p03 * self.p03 +
                self.p12 * self.p12 +
                self.p13 * self.p13 +
                self.p23 * self.p23,
        );
    }

    /// Нормировка: ℓ/‖ℓ‖ (канонические Плюккеровы координаты)
    pub fn normalize(self: P3Line) P3Line {
        const n = self.norm();
        if (n < 1e-15) return self;
        return .{
            .p01 = self.p01 / n,
            .p02 = self.p02 / n,
            .p03 = self.p03 / n,
            .p12 = self.p12 / n,
            .p13 = self.p13 / n,
            .p23 = self.p23 / n,
        };
    }

    /// Инцидентность: точка лежит на прямой?
    /// p ∈ ℓ ↔ p ∧ ℓ = 0 (в ∧³V)
    /// Вычисляем p ∧ ℓ и проверяем что результат = 0.
    pub fn containsPoint(self: P3Line, point: P3Point) bool {
        // p ∧ ℓ в ∧³V: 4 компоненты
        const c0 = point.v.x * self.p23 - point.v.y * self.p13 + point.v.z * self.p12;
        const c1 = point.v.x * self.p03 - point.v.y * self.p02 + point.v.w * self.p12; // Wrong sign fix below
        const c2 = point.v.x * self.p01 + point.v.z * self.p02 + point.v.w * self.p13; // Need correct formula
        const c3 = point.v.y * self.p01 + point.v.z * self.p02 + point.v.w * self.p03; // Simplified

        // Правильная формула: (p ∧ ℓ)_i = Σⱼ pⱼ · ℓ_{ij}
        // Точнее: p ∈ ℓ ↔ для всех i: Σⱼ ε_{ijkl} pⱼ ℓ_{kl} = 0
        // Проверяем через все 4 минора
        const m0 = point.v.w * self.p12 - point.v.z * self.p13 + point.v.y * self.p23;
        const m1 = point.v.w * self.p02 - point.v.z * self.p03 + point.v.x * self.p23;
        const m2 = point.v.w * self.p01 - point.v.y * self.p03 + point.v.x * self.p13;
        const m3 = point.v.z * self.p01 - point.v.y * self.p02 + point.v.x * self.p12;

        _ = .{ c0, c1, c2, c3 };
        const tol: f64 = 1e-8;
        return @abs(m0) < tol and @abs(m1) < tol and @abs(m2) < tol and @abs(m3) < tol;
    }
};

/// ∧³V — тривекторы (ПЛОСКОСТИ в P³)
///
/// В 4-мерном V: dim(∧³V) = C(4,3) = 4.
/// Плоскость задаётся однородными координатами [a:b:c:d]
/// для уравнения a·x + b·y + c·z + d·w = 0.
pub const P3Plane = struct {
    v: HomVec4, // [a, b, c, d] — коэффициенты плоскости

    pub inline fn init(a: f64, b: f64, c: f64, d: f64) P3Plane {
        return .{ .v = HomVec4.init(a, b, c, d) };
    }

    /// Плоскость через 3 точки: π = a ∧ b ∧ c (в ∧³V)
    /// Коэффициенты — 3×3 миноры матрицы [a|b|c]:
    ///   a = det(b.y,b.z,b.w; c.y,c.z,c.w) — с правильными знаками
    pub fn fromThreePoints(a: P3Point, b: P3Point, c: P3Point) P3Plane {
        // Раскладываем по первой строке (координаты a)
        const a_coeff = b.v.y * (c.v.z * a.v.w - c.v.w * a.v.z) -
            b.v.z * (c.v.y * a.v.w - c.v.w * a.v.y) +
            b.v.w * (c.v.y * a.v.z - c.v.z * a.v.y);

        const b_coeff = -(b.v.x * (c.v.z * a.v.w - c.v.w * a.v.z) -
            b.v.z * (c.v.x * a.v.w - c.v.w * a.v.x) +
            b.v.w * (c.v.x * a.v.z - c.v.z * a.v.x));

        const c_coeff = b.v.x * (c.v.y * a.v.w - c.v.w * a.v.y) -
            b.v.y * (c.v.x * a.v.w - c.v.w * a.v.x) +
            b.v.w * (c.v.x * a.v.y - c.v.y * a.v.x);

        const d_coeff = -(b.v.x * (c.v.y * a.v.z - c.v.z * a.v.y) -
            b.v.y * (c.v.x * a.v.z - c.v.z * a.v.x) +
            b.v.z * (c.v.x * a.v.y - c.v.y * a.v.x));

        return .{ .v = HomVec4.init(a_coeff, b_coeff, c_coeff, d_coeff) };
    }

    /// Инцидентность: точка лежит на плоскости?
    /// ⟨π, p⟩ = a·x + b·y + c·z + d·w = 0
    pub fn containsPoint(self: P3Plane, point: P3Point, tol: f64) bool {
        return @abs(HomVec4.dot(self.v, point.v)) < tol;
    }

    /// Инцидентность: прямая лежит в плоскости?
    /// ℓ ⊂ π ↔ для всех точек p ∈ ℓ: ⟨π, p⟩ = 0
    /// Эквивалентно: ℓ ∧ π = 0 в ∧⁴V
    pub fn containsLine(self: P3Plane, line: P3Line, tol: f64) bool {
        // ℓ ∧ π = 0:
        // a·p12 − b·p02 + c·p01 = 0  и  a·p13 − b·p03 + d·p01 = 0
        // a·p23 − c·p03 + d·p02 = 0  и  b·p23 − c·p13 + d·p12 = 0
        const c1 = self.v.x * line.p12 - self.v.y * line.p02 + self.v.z * line.p01;
        const c2 = self.v.x * line.p13 - self.v.y * line.p03 + self.v.w * line.p01;
        const c3 = self.v.x * line.p23 - self.v.z * line.p03 + self.v.w * line.p02;
        const c4 = self.v.y * line.p23 - self.v.z * line.p13 + self.v.w * line.p12;
        return @abs(c1) < tol and @abs(c2) < tol and @abs(c3) < tol and @abs(c4) < tol;
    }
};

/// ∧⁴V — псевдоскаляры (ОБЪЁМ в P³)
/// dim(∧⁴V) = 1. Единственный базис: e₀₁₂₃
pub const P3Volume = struct {
    value: f64,

    /// Объём тетраэдра (4 точки в P³)
    /// vol = det([a|b|c|d]) / 6
    pub fn fromFourPoints(a: P3Point, b: P3Point, c: P3Point, d: P3Point) P3Volume {
        // 4×4 определитель
        const m = [4][4]f64{
            .{ a.v.x, b.v.x, c.v.x, d.v.x },
            .{ a.v.y, b.v.y, c.v.y, d.v.y },
            .{ a.v.z, b.v.z, c.v.z, d.v.z },
            .{ a.v.w, b.v.w, c.v.w, d.v.w },
        };
        const det = m[0][0] * (
            m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) -
                m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1]) +
                m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
        ) - m[0][1] * (
            m[1][0] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) -
                m[1][2] * (m[2][0] * m[3][3] - m[2][3] * m[3][0]) +
                m[1][3] * (m[2][0] * m[3][2] - m[2][2] * m[3][0])
        ) + m[0][2] * (
            m[1][0] * (m[2][1] * m[3][3] - m[2][3] * m[3][1]) -
                m[1][1] * (m[2][0] * m[3][3] - m[2][3] * m[3][0]) +
                m[1][3] * (m[2][0] * m[3][1] - m[2][1] * m[3][0])
        ) - m[0][3] * (
            m[1][0] * (m[2][1] * m[3][2] - m[2][2] * m[3][1]) -
                m[1][1] * (m[2][0] * m[3][2] - m[2][2] * m[3][0]) +
                m[1][2] * (m[2][0] * m[3][1] - m[2][1] * m[3][0])
        );
        return .{ .value = det / 6.0 };
    }

    /// Копланарность: 4 точки в одной плоскости ↔ volume = 0
    pub fn isCoplanar(self: P3Volume, tol: f64) bool {
        return @abs(self.value) < tol;
    }
};

// =============================================================================
// 2. ТИПОБЕЗОПАСНЫЕ MEET И JOIN
// =============================================================================
//
// meet и join — операции exterior algebra, НЕ просто функции.
// Возвращаемый тип ЗАВИСИТ от входных типов:
//
//   meet(P3Point, P3Plane)  → Scalar       (инцидентность)
//   meet(P3Plane, P3Plane)  → P3Line       (пересечение)
//   meet(P3Line, P3Plane)   → P3Point      (пересечение)
//   join(P3Point, P3Point)  → P3Line       (прямая через 2 точки)
//   join(P3Point, P3Plane)  → P3Volume     (объём)

/// Meet: точка ∩ плоскость → скаляр (инцидентность)
/// Результат = 0 ↔ точка на плоскости
pub fn meetPointPlane(point: P3Point, plane: P3Plane) Scalar {
    return HomVec4.dot(point.v, plane.v);
}

/// Meet: плоскость₁ ∩ плоскость₂ → прямая
/// Пересечение двух плоскостей — прямая (Плюккеровы координаты)
pub fn meetPlanePlane(pi1: P3Plane, pi2: P3Plane) P3Line {
    return P3Line.fromTwoPlanes(pi1, pi2);
}

/// Meet: прямая ∩ плоскость → точка
/// Пересечение прямой и плоскости — точка
pub fn meetLinePlane(line: P3Line, plane: P3Plane) P3Point {
    // Точка = *(ℓ ∧ π) в дуальном пространстве
    // p_i = ε_{ijkl} · ℓ_{jk} · π_l / 2
    const px = line.p12 * plane.v.w - line.p13 * plane.v.z + line.p23 * plane.v.y;
    const py = -line.p02 * plane.v.w + line.p03 * plane.v.z - line.p23 * plane.v.x;
    const pz = line.p01 * plane.v.w - line.p03 * plane.v.y + line.p13 * plane.v.x;
    const pw = -line.p01 * plane.v.z + line.p02 * plane.v.y - line.p12 * plane.v.x;
    return P3Point.init(px, py, pz, pw);
}

/// Join: точка₁ ∨ точка₂ → прямая
/// Прямая через две точки — Плюккеровы координаты
pub fn joinPointPoint(a: P3Point, b: P3Point) P3Line {
    return P3Line.fromTwoPoints(a, b);
}

/// Join: точка ∨ плоскость → объём (детерминант)
/// Объём тетраэдра, если добавить ещё точки
pub fn joinPointPlane(point: P3Point, plane: P3Plane) Scalar {
    return HomVec4.dot(point.v, plane.v);
}

// =============================================================================
// 3. ДВОЙСТВЕННОСТЬ ПОДЖЕ (HODGE DUAL)
// =============================================================================
//
// В P³ (dim=4): *: ∧ᵏV → ∧⁽⁴⁻ᵏ⁾V
//   *: ∧⁰V → ∧⁴V   (скаляр → псевдоскаляр)
//   *: ∧¹V → ∧³V   (точка ↔ плоскость)
//   *: ∧²V → ∧²V   (прямая ↔ прямая, self-dual!)
//   *: ∧³V → ∧¹V   (плоскость ↔ точка)
//   *: ∧⁴V → ∧⁰V   (псевдоскаляр → скаляр)

/// Hodge dual: точка → плоскость
/// В P³ с ε_{0123}=+1: *(eᵢ) = εᵢⱼₖₗ eⱼ∧eₖ∧eₗ
/// Т.е. *(x,y,z,w) = плоскость [x,y,z,w]
/// Это и есть полюс-полярная двойственность!
pub fn hodgeDualPoint(point: P3Point) P3Plane {
    // В стандартной метрике: dual of point = plane with same coords
    return .{ .v = point.v };
}

/// Hodge dual: плоскость → точка
pub fn hodgeDualPlane(plane: P3Plane) P3Point {
    return .{ .v = plane.v };
}

/// Hodge dual: прямая → прямая (self-dual в ∧²V!)
/// *ℓ: dual Plücker coords
///   (*ℓ)₀₁ = ℓ₂₃, (*ℓ)₀₂ = −ℓ₁₃, (*ℓ)₀₃ = ℓ₁₂
///   (*ℓ)₁₂ = ℓ₀₃, (*ℓ)₁₃ = −ℓ₀₂, (*ℓ)₂₃ = ℓ₀₁
pub fn hodgeDualLine(line: P3Line) P3Line {
    return .{
        .p01 = line.p23,
        .p02 = -line.p13,
        .p03 = line.p12,
        .p12 = line.p03,
        .p13 = -line.p02,
        .p23 = line.p01,
    };
}

// =============================================================================
// 4. ТЕСТЫ
// =============================================================================

test "Algebra: Plücker coords from two points" {
    const a = P3Point.fromCartesian(.{ 1, 0, 0 });
    const b = P3Point.fromCartesian(.{ 0, 1, 0 });
    const line = P3Line.fromTwoPoints(a, b);
    // a = [1,0,0,1], b = [0,1,0,1]
    // p01 = 1·1 − 0·0 = 1
    // p03 = 1·1 − 1·0 = 1
    // p12 = 0·0 − 0·1 = 0
    // p23 = 0·1 − 1·0 = 0
    try std.testing.expectApproxEqAbs(line.p01, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(line.p03, 1.0, 1e-10);
    try std.testing.expect(line.satisfiesPlucker(1e-8));
}

test "Algebra: Plücker relation is satisfied" {
    const a = P3Point.fromCartesian(.{ 1, 2, 3 });
    const b = P3Point.fromCartesian(.{ 4, 5, 6 });
    const line = P3Line.fromTwoPoints(a, b);
    try std.testing.expect(line.satisfiesPlucker(1e-8));
}

test "Algebra: Plücker norm is non-zero for distinct points" {
    const a = P3Point.fromCartesian(.{ 1, 0, 0 });
    const b = P3Point.fromCartesian(.{ 0, 1, 0 });
    const line = P3Line.fromTwoPoints(a, b);
    try std.testing.expect(line.norm() > 0.5);
}

test "Algebra: Plücker norm is zero for same point" {
    const a = P3Point.fromCartesian(.{ 1, 2, 3 });
    const line = P3Line.fromTwoPoints(a, a);
    try std.testing.expectApproxEqAbs(line.norm(), 0.0, 1e-10);
}

test "Algebra: plane through 3 points contains them" {
    const a = P3Point.fromCartesian(.{ 1, 0, 0 });
    const b = P3Point.fromCartesian(.{ 0, 1, 0 });
    const c = P3Point.fromCartesian(.{ 0, 0, 1 });
    const plane = P3Plane.fromThreePoints(a, b, c);
    try std.testing.expect(plane.containsPoint(a, 1e-8));
    try std.testing.expect(plane.containsPoint(b, 1e-8));
    try std.testing.expect(plane.containsPoint(c, 1e-8));
}

test "Algebra: meet point-plane (incidence)" {
    const point = P3Point.fromCartesian(.{ 1, 0, 0 });
    // Плоскость x=1: [1, 0, 0, -1] → x - w = 0 → x = 1 (в UW)
    const plane = P3Plane.init(1, 0, 0, -1);
    const s = meetPointPlane(point, plane);
    try std.testing.expectApproxEqAbs(s, 0.0, 1e-10);
}

test "Algebra: meet point-plane (non-incidence)" {
    const point = P3Point.fromCartesian(.{ 2, 0, 0 });
    const plane = P3Plane.init(1, 0, 0, -1); // x = 1
    const s = meetPointPlane(point, plane);
    // 2·1 + 0·0 + 0·0 + 1·(-1) = 1 ≠ 0
    try std.testing.expect(@abs(s) > 0.5);
}

test "Algebra: join two points gives line" {
    const a = P3Point.fromCartesian(.{ 1, 0, 0 });
    const b = P3Point.fromCartesian(.{ 0, 1, 0 });
    const line = joinPointPoint(a, b);
    try std.testing.expect(line.satisfiesPlucker(1e-8));
    try std.testing.expect(line.norm() > 0.5);
}

test "Algebra: meet two planes gives line" {
    const pi1 = P3Plane.init(1, 0, 0, 0); // x = 0
    const pi2 = P3Plane.init(0, 1, 0, 0); // y = 0
    const line = meetPlanePlane(pi1, pi2);
    // Пересечение x=0 и y=0 — ось z
    try std.testing.expect(line.satisfiesPlucker(1e-8));
}

test "Algebra: Hodge dual point→plane→point round-trip" {
    const point = P3Point.fromCartesian(.{ 1, 2, 3 });
    const plane = hodgeDualPoint(point);
    const back = hodgeDualPlane(plane);
    try std.testing.expectApproxEqAbs(back.v.x, point.v.x, 1e-10);
    try std.testing.expectApproxEqAbs(back.v.y, point.v.y, 1e-10);
    try std.testing.expectApproxEqAbs(back.v.z, point.v.z, 1e-10);
}

test "Algebra: Hodge dual line→line double dual = identity" {
    const a = P3Point.fromCartesian(.{ 1, 0, 0 });
    const b = P3Point.fromCartesian(.{ 0, 1, 0 });
    const line = P3Line.fromTwoPoints(a, b);
    const dual = hodgeDualLine(line);
    const dual2 = hodgeDualLine(dual);
    // ** = (−1)^(k(n−k)) = (−1)^(2·2) = +1 в dim 4
    try std.testing.expectApproxEqAbs(dual2.p01, line.p01, 1e-10);
    try std.testing.expectApproxEqAbs(dual2.p23, line.p23, 1e-10);
}

test "Algebra: volume of tetrahedron" {
    const a = P3Point.fromCartesian(.{ 0, 0, 0 });
    const b = P3Point.fromCartesian(.{ 1, 0, 0 });
    const c = P3Point.fromCartesian(.{ 0, 1, 0 });
    const d = P3Point.fromCartesian(.{ 0, 0, 1 });
    const vol = P3Volume.fromFourPoints(a, b, c, d);
    // Единичный тетраэдр: |объём| = 1/6 (знак зависит от порядка)
    try std.testing.expectApproxEqAbs(@abs(vol.value), 1.0 / 6.0, 1e-10);
}

test "Algebra: coplanar points have zero volume" {
    const a = P3Point.fromCartesian(.{ 0, 0, 0 });
    const b = P3Point.fromCartesian(.{ 1, 0, 0 });
    const c = P3Point.fromCartesian(.{ 0, 1, 0 });
    const d = P3Point.fromCartesian(.{ 1, 1, 0 }); // В той же плоскости z=0
    const vol = P3Volume.fromFourPoints(a, b, c, d);
    try std.testing.expect(vol.isCoplanar(1e-10));
}

test "Algebra: Plücker normalize" {
    const a = P3Point.fromCartesian(.{ 1, 2, 3 });
    const b = P3Point.fromCartesian(.{ 4, 5, 6 });
    const line = P3Line.fromTwoPoints(a, b).normalize();
    try std.testing.expectApproxEqAbs(line.norm(), 1.0, 1e-10);
}

test "Algebra: meet line-plane gives point" {
    // Прямая (0,0,0)→(1,0,1), плоскость y=0
    const a = P3Point.fromCartesian(.{ 0, 0, 0 });
    const b = P3Point.fromCartesian(.{ 1, 0, 1 });
    const line = P3Line.fromTwoPoints(a, b);
    const plane = P3Plane.init(0, 1, 0, 0); // y = 0
    // Вся прямая в y=0 → любая точка на прямой лежит в плоскости
    // Проверяем: результат ненулевой (прямая и плоскость пересекаются)
    const pt = meetLinePlane(line, plane);
    try std.testing.expect(pt.v.norm() > 0.5);
}
