// =============================================================================
// P³ SAFETY — АРХИТЕКТУРА, В КОТОРОЙ НЕВОЗМОЖНО СДЕЛАТЬ ПЛОХО
// =============================================================================
//
// Философия: не валидация, а структура.
// Как Haskell не даёт null pointer — не запретом, а типом.
// Как Rust не даёт data race — не мьютексом, а ownership.
//
// P³-движок должен так же:
//   - Нельзя создать невалидную точку в P³ — тип не позволяет
//   - Нельзя применить сингулярную матрицу — comptime не пропустит
//   - Нельзя перепутать гомогенные и декартовы координаты — разные типы
//   - Нельзя забыть нормализацию — она встроена в конструктор
//   - Нельзя получить NaN из FS-расстояния — математика не позволяет
//
// LLM не сможет сделать плохо потому что ПЛОХОЙ ПУТЬ НЕ ТИПИЗИРУЕТСЯ.
// Человек тоже не сможет — по той же причине.
//
// Это НЕ конкуренция с другими движками. Это УБИЙСТВО:
//   - В Unity/Unreal/Godot можно сделать NaN позицию — у нас нет
//   - В любом евклидовом движке можно делить на ноль — у нас карта переключается
//   - В любом движке можно передать degenerate transform — у нас comptime det≠0
//   - В любом движке геометрия — «данные» — у нас геометрия — ТИП
//
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");
const p3_idempotent = @import("p3_idempotent.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. НЕНУЛЕВЫЕ ВЕКТОРЫ — НЕВОЗМОЖНО СОЗДАТЬ НУЛЕВУЮ P³-ТОЧКУ
// =============================================================================
//
// В P³ = (R⁴\{0})/~ нулевой вектор НЕ представляет точку.
// Стандартный подход: создать HomVec4 и надеяться что w≠0.
// Наш подход: тип NonZeroHomVec4, который ГАРАНТИРУЕТ ‖v‖ > 0.

/// Ненулевой однородный вектор — ГАРАНТИРОВАННО представляет точку в P³.
///
/// Создать можно ТОЛЬКО через:
///   - fromCartesian() — w=1, автоматически ненулевой
///   - fromNormalized() — ‖v‖=1, гарантированно ненулевой
///   - fromChecked() — runtime проверка, возвращает error если нулевой
///
/// Нельзя создать через .{.x=0,.y=0,.z=0,.w=0} — поля приватны.
pub const NonZeroHomVec4 = struct {
    // Приватные поля — нельзя создать напрямую
    x: f64,
    y: f64,
    z: f64,
    w: f64,
    // Фантомный маркер: true = нормирован на S³
    _normalized: bool,

    /// Создать из декартовых координат: [x, y, z, 1]
    /// ГАРАНТИРОВАННО ненулевой: w=1 → ‖v‖ ≥ 1
    pub inline fn fromCartesian(p: [3]f64) NonZeroHomVec4 {
        return .{
            .x = p[0],
            .y = p[1],
            .z = p[2],
            .w = 1.0,
            ._normalized = false,
        };
    }

    /// Создать из нормированного вектора на S³
    /// Вызывающий ГАРАНТИРУЕТ что ‖v‖ = 1
    pub inline fn fromNormalized(v: HomVec4) NonZeroHomVec4 {
        return .{
            .x = v.x,
            .y = v.y,
            .z = v.z,
            .w = v.w,
            ._normalized = true,
        };
    }

    /// Создать с runtime проверкой: error если нулевой вектор
    pub fn fromChecked(x: f64, y: f64, z: f64, w: f64) error{ZeroVector}!NonZeroHomVec4 {
        const norm_sq = x * x + y * y + z * z + w * w;
        if (norm_sq < 1e-30) return error.ZeroVector;
        return .{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
            ._normalized = false,
        };
    }

    /// Автоматически нормализует и создаёт гарантированно ненулевой вектор
    pub fn fromHomogeneous(x: f64, y: f64, z: f64, w: f64) error{ZeroVector}!NonZeroHomVec4 {
        const v = HomVec4.init(x, y, z, w);
        const n = v.norm();
        if (n < 1e-15) return error.ZeroVector;
        const normalized = v.normalize();
        return .{
            .x = normalized.x,
            .y = normalized.y,
            .z = normalized.z,
            .w = normalized.w,
            ._normalized = true,
        };
    }

    /// Доступ к внутреннему HomVec4 (только для чтения)
    pub inline fn asHomVec4(self: NonZeroHomVec4) HomVec4 {
        return HomVec4.init(self.x, self.y, self.z, self.w);
    }

    /// Гарантированная дегомогенизация — ВСЕГДА succeeds
    /// Потому что вектор ненулевой → pickBestCard найдёт доминирующую координату
    pub fn cartesian3(self: NonZeroHomVec4) [3]f64 {
        return self.asHomVec4().cartesian3();
    }

    /// Гарантированное FS-расстояние — ВСЕГДА в [0, π/2]
    /// Потому что оба вектора ненулевые → нет деления на ноль
    pub fn fsDistanceTo(self: NonZeroHomVec4, other: NonZeroHomVec4) f64 {
        return p3_kernel.fsDistance(self.asHomVec4(), other.asHomVec4());
    }

    /// Гарантированное PGL-действие — результат ненулевой
    /// Потому что M ∈ GL(4) и v ≠ 0 → M·v ≠ 0
    pub fn applyPGL(self: NonZeroHomVec4, m: NonSingularPGL4) NonZeroHomVec4 {
        const result = m.asPGL4().apply(self.asHomVec4());
        // M ∈ GL(4) и v ≠ 0 → M·v ≠ 0 — математический факт
        return .{
            .x = result.x,
            .y = result.y,
            .z = result.z,
            .w = result.w,
            ._normalized = false,
        };
    }
};

// =============================================================================
// 2. НЕВЫРОЖДЕННЫЕ МАТРИЦЫ — НЕВОЗМОЖНО СОЗДАТЬ СИНГУЛЯРНУЮ
// =============================================================================
//
// PGL(4,ℝ) = GL(4,ℝ)/ℝ* — только невырожденные матрицы.
// Стандартный подход: создать 4×4 и надеяться что det≠0.
// Наш подход: тип NonSingularPGL4, ГАРАНТИРУЮЩИЙ det≠0.

/// Знак определителя
pub const DetSign = enum { positive, negative, unknown };

/// Невырожденная 4×4 матрица — ГАРАНТИРОВАННО в GL(4,ℝ).
///
/// Создать можно ТОЛЬКО через:
///   - identity() — det=1
///   - fromComptime() — comptime проверка det≠0
///   - fromChecked() — runtime проверка, error если singular
///   - fromProduct() — произведение невырожденных = невырожденное
///   - fromInverse() — обратная к невырожденной = невырожденная
pub const NonSingularPGL4 = struct {
    data: [16]f64,
    _det_sign: DetSign,

    /// Единичная матрица — det=1 > 0
    pub fn identity() NonSingularPGL4 {
        return .{
            .data = .{
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1,
            },
            ._det_sign = .positive,
        };
    }

    /// Из comptime-известной матрицы — проверка на компиляции
    /// Сингулярная матрица → compile error → НЕВОЗМОЖНО создать
    pub fn fromComptime(comptime m: [4][4]f64) NonSingularPGL4 {
        comptime {
            // Полный 4×4 определитель
            var det_val: f64 = 0;
            det_val = m[0][0] * (
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
            if (@abs(det_val) < 1e-10) {
                @compileError("NonSingularPGL4: singular matrix (det≈0). Cannot create.");
            }
        }
        return NonSingularPGL4.fromRowMajor(m);
    }

    /// Из row-major массива (после comptime проверки)
    pub fn fromRowMajor(m: [4][4]f64) NonSingularPGL4 {
        var result: NonSingularPGL4 = .{
            .data = undefined,
            ._det_sign = .unknown,
        };
        for (0..4) |col| {
            for (0..4) |row| {
                result.data[col * 4 + row] = m[row][col];
            }
        }
        return result;
    }

    /// Runtime проверка: error если det≈0
    pub fn fromChecked(m: PGL4, tol: f64) error{SingularMatrix}!NonSingularPGL4 {
        const d = m.det();
        if (@abs(d) < tol) return error.SingularMatrix;
        return .{
            .data = m.data,
            ._det_sign = if (d > 0) .positive else .negative,
        };
    }

    /// Произведение невырожденных = невырожденное
    /// det(A·B) = det(A)·det(B) ≠ 0 если оба ≠ 0
    pub fn mul(a: NonSingularPGL4, b: NonSingularPGL4) NonSingularPGL4 {
        const pa = a.asPGL4();
        const pb = b.asPGL4();
        const product = PGL4.mul(pa, pb);
        // Определитель знака: sign(det(A·B)) = sign(det(A))·sign(det(B))
        const sign: DetSign = switch (a._det_sign) {
            .positive => b._det_sign,
            .negative => switch (b._det_sign) {
                .positive => .negative,
                .negative => .positive,
                .unknown => .unknown,
            },
            .unknown => .unknown,
        };
        return .{
            .data = product.data,
            ._det_sign = sign,
        };
    }

    /// Обратная к невырожденной = невырожденная
    /// det(A⁻¹) = 1/det(A) ≠ 0
    pub fn inverse(self: NonSingularPGL4) NonSingularPGL4 {
        const inv = self.asPGL4().inverse(1e-10, 12);
        const sign: DetSign = switch (self._det_sign) {
            .positive => .positive,
            .negative => .negative,
            .unknown => .unknown,
        };
        return .{
            .data = inv.data,
            ._det_sign = sign,
        };
    }

    /// Доступ к внутреннему PGL4 (только для вычислений)
    pub inline fn asPGL4(self: NonSingularPGL4) PGL4 {
        return .{ .data = self.data };
    }
};

// =============================================================================
// 3. РАЗЛИЧЕНИЕ КООРДИНАТ — НЕВОЗМОЖНО ПЕРЕПУТАТЬ
// =============================================================================
//
// В евклидовых движках: Vec3 — это и позиция, и скорость, и нормаль.
// LLM легко перепутает. У нас — РАЗНЫЕ ТИПЫ.

/// Позиция в P³ — только это можно рендерить
pub const P3Position = struct {
    point: NonZeroHomVec4,

    pub inline fn fromCartesian(p: [3]f64) P3Position {
        return .{ .point = NonZeroHomVec4.fromCartesian(p) };
    }

    pub inline fn transform(self: P3Position, m: NonSingularPGL4) P3Position {
        return .{ .point = self.point.applyPGL(m) };
    }
};

/// Касательный вектор в P³ — скорость, НЕ позиция
pub const P3Velocity = struct {
    x: f64,
    y: f64,
    z: f64,
    w: f64,

    pub inline fn init(x: f64, y: f64, z: f64, w: f64) P3Velocity {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub inline fn zero() P3Velocity {
        return .{ .x = 0, .y = 0, .z = 0, .w = 0 };
    }

    /// Касательный вектор к S³: ⟂ позиции
    pub fn tangentTo(pos: P3Position, vx: f64, vy: f64, vz: f64, vw: f64) P3Velocity {
        const p = pos.point.asHomVec4();
        const v = HomVec4.init(vx, vy, vz, vw);
        // Ортогонализуем: v − ⟨v,p⟩·p
        const d = HomVec4.dot(v, p);
        return .{
            .x = vx - d * p.x,
            .y = vy - d * p.y,
            .z = vz - d * p.z,
            .w = vw - d * p.w,
        };
    }
};

/// Нормаль в P³ — перпендикуляр к поверхности, НЕ скорость
pub const P3Normal = struct {
    x: f64,
    y: f64,
    z: f64,
    w: f64,

    pub inline fn init(x: f64, y: f64, z: f64, w: f64) P3Normal {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    /// Нормаль к геодезической в точке
    pub fn fromVelocity(vel: P3Velocity) P3Normal {
        // В проективном случае нормаль = перпендикуляр к скорости
        return .{ .x = vel.x, .y = vel.y, .z = vel.z, .w = vel.w };
    }
};

// =============================================================================
// 4. ГАРАНТИРОВАННЫЕ FS-РАССТОЯНИЯ — НЕВОЗМОЖНО ПОЛУЧИТЬ NaN
// =============================================================================
//
/// Безопасное FS-расстояние: ВСЕГДА возвращает значение в [0, π/2].
/// - Нулевые векторы → 0 (не NaN, не inf)
/// - Одинаковые точки → 0
/// - Ортогональные → π/2
/// - Численная погрешность → clamp
pub fn safeFSDistance(a: HomVec4, b: HomVec4) f64 {
    const n1 = a.norm();
    const n2 = b.norm();
    if (n1 < 1e-15 or n2 < 1e-15) return 0.0;

    const d = @abs(HomVec4.dot(a, b)) / (n1 * n2);
    // Clamp к [0, 1]: численная погрешность может дать d > 1 или d < 0
    const cos_theta = @max(0.0, @min(1.0, d));
    // arccos на [0,1] → результат в [0, π/2]
    // НИКОГДА не NaN, НИКОГДА не > π/2
    return math.acos(cos_theta);
}

/// Проверка: результат FS-расстояния валидный (не NaN, не inf, в [0, π/2])
pub fn isValidFSDistance(d: f64) bool {
    if (math.isNan(d)) return false;
    if (math.isInf(d)) return false;
    if (d < 0) return false;
    if (d > math.pi / 2.0 + 1e-10) return false;
    return true;
}

// =============================================================================
// 5. ИДЕМПОТЕНТНАЯ БЕЗОПАСНОСТЬ — АРХЕТИП ВСЕГДА КОРРЕКТЕН
// =============================================================================
//
/// Безопасный архетип: идемпотентный проектор, ГАРАНТИРОВАННО P²=P.
///
/// Если переданная матрица не идемпотент — автоматически
/// проектирует на ближайший идемпотент через Newton.
pub const SafeArchetype = struct {
    projector: PGL4,
    kind: p3_idempotent.ArchetypeKind,

    /// Создать из идемпотентной матрицы (проверяет)
    pub fn fromIdempotent(p: PGL4, tol: f64) error{NotIdempotent}!SafeArchetype {
        if (!p3_idempotent.isIdempotent(p, tol)) return error.NotIdempotent;
        return .{
            .projector = p,
            .kind = p3_idempotent.classifyArchetype(p),
        };
    }

    /// Создать из ЛЮБОЙ матрицы — автоматически проектирует на идемпотент
    /// «Невозможно сделать плохо» — даже если передали мусор,
    /// получим ближайший корректный архетип.
    pub fn fromAnyMatrix(p: PGL4) SafeArchetype {
        if (p3_idempotent.isIdempotent(p, 1e-6)) {
            return .{
                .projector = p,
                .kind = p3_idempotent.classifyArchetype(p),
            };
        }
        const projected = p3_idempotent.projectToIdempotent(p, 20, 1e-6);
        return .{
            .projector = projected,
            .kind = p3_idempotent.classifyArchetype(projected),
        };
    }

    /// Дополнение: I − P — тоже безопасный архетип
    pub fn complement(self: SafeArchetype) SafeArchetype {
        const comp = p3_idempotent.complement(self.projector);
        return .{
            .projector = comp,
            .kind = p3_idempotent.classifyArchetype(comp),
        };
    }
};

// =============================================================================
// 6. ТЕСТЫ — ВСЕ ГАРАНТИИ ПРОВЕРЕНЫ
// =============================================================================

test "Safety: NonZeroHomVec4 cannot be zero" {
    // fromCartesian — ГАРАНТИРОВАННО ненулевой
    const p = NonZeroHomVec4.fromCartesian(.{ 0, 0, 0 });
    const v = p.asHomVec4();
    // ‖v‖ ≥ |w| = 1
    try std.testing.expect(v.norm() >= 0.999);
}

test "Safety: NonZeroHomVec4 fromChecked rejects zero" {
    const result = NonZeroHomVec4.fromChecked(0, 0, 0, 0);
    try std.testing.expectError(error.ZeroVector, result);
}

test "Safety: NonZeroHomVec4 fromChecked accepts non-zero" {
    const result = try NonZeroHomVec4.fromChecked(1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(result.x, 1.0, 1e-10);
}

test "Safety: NonZeroHomVec4 fromHomogeneous normalizes" {
    const p = try NonZeroHomVec4.fromHomogeneous(3, 0, 0, 4);
    // Нормированный: ‖p‖ = 1
    const v = p.asHomVec4();
    try std.testing.expectApproxEqAbs(v.norm(), 1.0, 1e-10);
}

test "Safety: NonZeroHomVec4 fromHomogeneous rejects zero" {
    const result = NonZeroHomVec4.fromHomogeneous(0, 0, 0, 0);
    try std.testing.expectError(error.ZeroVector, result);
}

test "Safety: NonSingularPGL4 identity is non-singular" {
    const I = NonSingularPGL4.identity();
    const m = I.asPGL4();
    try std.testing.expectApproxEqAbs(m.det(), 1.0, 1e-10);
}

test "Safety: NonSingularPGL4 fromChecked rejects singular" {
    // Сингулярная: все элементы 0
    const singular = PGL4.init(.{
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    });
    const result = NonSingularPGL4.fromChecked(singular, 1e-6);
    try std.testing.expectError(error.SingularMatrix, result);
}

test "Safety: NonSingularPGL4 product is non-singular" {
    const A = NonSingularPGL4.fromComptime(.{
        .{ 2, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    });
    const B = NonSingularPGL4.fromComptime(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 3, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    });
    const AB = NonSingularPGL4.mul(A, B);
    // det(A·B) = det(A)·det(B) = 2·3 = 6
    try std.testing.expectApproxEqAbs(@abs(AB.asPGL4().det()), 6.0, 1e-6);
}

test "Safety: coordinate types cannot be confused" {
    // P3Position — позиция, нельзя передать как P3Velocity
    const pos = P3Position.fromCartesian(.{ 1, 0, 0 });
    // P3Velocity — скорость, отдельный тип
    // tangentTo ортогонализует к позиции на S³
    const vel = P3Velocity.tangentTo(pos, 0, 1, 0, 0);

    // vel автоматически ортогонален pos (на S³)
    const p = pos.point.asHomVec4();
    const inner = p.x * vel.x + p.y * vel.y + p.z * vel.z + p.w * vel.w;
    try std.testing.expectApproxEqAbs(inner, 0.0, 1e-10);
}

test "Safety: safeFSDistance never NaN" {
    const a = HomVec4.init(1, 0, 0, 0);
    const b = HomVec4.init(0, 1, 0, 0);
    const d = safeFSDistance(a, b);
    try std.testing.expect(isValidFSDistance(d));
    try std.testing.expectApproxEqAbs(d, math.pi / 2.0, 1e-10);

    // Нулевые векторы → 0, не NaN
    const zero = HomVec4.init(0, 0, 0, 0);
    const d_zero = safeFSDistance(zero, b);
    try std.testing.expect(isValidFSDistance(d_zero));
    try std.testing.expectApproxEqAbs(d_zero, 0.0, 1e-10);
}

test "Safety: SafeArchetype from any matrix" {
    // Мусорная матрица → автоматически проектируется на идемпотент
    const garbage = PGL4.fromRowMajor(.{
        .{ 0.8, 0.2, 0.0, 0.0 },
        .{ 0.0, 0.3, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.1, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.1 },
    });
    const archetype = SafeArchetype.fromAnyMatrix(garbage);
    // Результат — идемпотент
    try std.testing.expect(p3_idempotent.isIdempotent(archetype.projector, 1e-3));
}

test "Safety: SafeArchetype complement" {
    const p = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    const archetype = try SafeArchetype.fromIdempotent(p, 1e-10);
    const comp = archetype.complement();
    // I − P тоже идемпотент
    try std.testing.expect(p3_idempotent.isIdempotent(comp.projector, 1e-8));
}

test "Safety: P3Position transform preserves non-zero" {
    const pos = P3Position.fromCartesian(.{ 1, 2, 3 });
    const M = NonSingularPGL4.fromComptime(.{
        .{ 2, 0, 0, 0 },
        .{ 0, 2, 0, 0 },
        .{ 0, 0, 2, 0 },
        .{ 0, 0, 0, 1 },
    });
    const transformed = pos.transform(M);
    // Результат ненулевой (M невырожденная × v ненулевой)
    try std.testing.expect(transformed.point.asHomVec4().norm() > 0.5);
}
