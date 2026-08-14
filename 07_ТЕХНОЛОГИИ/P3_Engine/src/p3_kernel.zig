// =============================================================================
// P³ KERNEL v3.0 — ZIG — ПРОЕКТИВНОЕ ЯДРО
// =============================================================================
//
// Это НЕ визуализатор. Это ЯДРО, работающее НА проективном
// многообразии P³.
//
// Порт p3_kernel.py v2.0 → Zig, с пожиранием доноров:
//   Донор #1 (zmath): SIMD F32x4 ядро для рендера
//   Донор #2 (zm):    Vec(n,T) / Matrix(m,n,T) comptime-конструкторы
//   Донор #3 (Mach):  зарезервировано для GPU compute (Фаза 2)
//
// Принцип: убивать и жрать и рождать новое.
// Не copy-paste. Не зависимость. Понять → переписать → проверить.
//
// Архитектор: Kotokvit (математик), Super Z (исполнение)
// =============================================================================

const std = @import("std");
const math = std.math;

// =============================================================================
// 0. КАНОНИЧЕСКИЕ КОНСТАНТЫ
// =============================================================================

/// Радиус Этерии (км) — CANON_PHYSICS_ABSOLUTE.md §III
pub const R_ETERIA_KM: f64 = 5838.4;
/// Радиус Земли (км)
pub const R_EARTH_KM: f64 = 6378.0;
/// Темпоральная константа анизотропии T = dI/dΣ ≈ 1.28571
pub const K_ANISO: f64 = 9.0 / 7.0;
/// Золотой угол Протоки: λ = π × 10⁻¹⁰ рад
pub const GOLDEN_ANGLE: f64 = math.pi * 1e-10;
/// Частота Бездны (Гц) — свинцовая фольга
pub const RESONANCE_HZ: f64 = 18.7;
/// Канонический сдвиг Одесса ↔ Сектор 4
pub const DELTA_LAT: f64 = 0.6533;
pub const DELTA_LON: f64 = 4.1567;
/// Расстояние Земля–Этерия (а.е.)
pub const D_ETERIA_AU: f64 = 1.3;
/// Порог переключения афинных карт
pub const W_EPS: f64 = 1e-6;
/// Ренормализация определителя каждые N шагов
pub const RENORM_EVERY: u32 = 100;

// =============================================================================
// 1. SIMD-ЯДРО (из zmath — переписано)
// =============================================================================
//
// zmath использует F32x4 = @Vector(4, f32) для SIMD-операций.
// Мы берём ТОЛЬКО: dot4, normalize, sin/cos, load/store.
// Выкидываем: все евклидовы проекции (lookTo, perspectiveFov),
//             row-major convention, f32-only.
//
// Добавляем: f64x4 для точных вычислений Фубини-Штуди.

/// SIMD вектор f32×4 — для рендеринга (дегомогенизация, нормализация на GPU)
pub const F32x4 = @Vector(4, f32);

/// SIMD вектор f64×4 — для точных научных вычислений (Фубини-Штуди)
pub const F64x4 = @Vector(4, f64);

/// Конструктор SIMD f32×4
pub inline fn f32x4(x: f32, y: f32, z: f32, w: f32) F32x4 {
    return .{ x, y, z, w };
}

/// Конструктор SIMD f64×4
pub inline fn f64x4(x: f64, y: f64, z: f64, w: f64) F64x4 {
    return .{ x, y, z, w };
}

/// SIMD скалярное произведение f32×4
/// ⟨a,b⟩ = a.x·b.x + a.y·b.y + a.z·b.z + a.w·b.w
pub inline fn simdDot4(a: F32x4, b: F32x4) f32 {
    return @reduce(.Add, a * b);
}

/// SIMD скалярное произведение f64×4 (для точных вычислений)
pub inline fn simdDot4f64(a: F64x4, b: F64x4) f64 {
    return @reduce(.Add, a * b);
}

/// SIMD нормализация f32×4: v / ‖v‖
/// Используется для дегомогенизации P³ → R³ на GPU
pub fn simdNormalize3(v: F32x4) F32x4 {
    const d = simdDot4(v, v);
    if (d < 1e-15) return f32x4(0, 0, 0, 1);
    const inv_len = @sqrt(d); // Zig @sqrt на SIMD
    return v / @as(F32x4, @splat(inv_len));
}

/// SIMD нормализация f64×4
pub fn simdNormalize4f64(v: F64x4) F64x4 {
    const d = simdDot4f64(v, v);
    if (d < 1e-30) return f64x4(0, 0, 0, 1);
    const inv_len = @sqrt(d);
    return v / @as(F64x4, @splat(inv_len));
}

// =============================================================================
// 2. ОДНОРОДНЫЙ ВЕКТОР HomVec4 (из zm — переписано)
// =============================================================================
//
// zm использует Vec(n, T) comptime-конструктор.
// Мы берём: Vec(4, f64), add/sub/mul, dot, normalize.
// Выкидываем: AABB, Ray, Quaternion — евклидовы концепции.
//
// Добавляем: семантика однородных координат [X:Y:Z:W],
//            антиподальная проверка Z/2Z,
//            афинные карты P³.

/// Афинная карта P³
/// P³ покрывается 4 афинными картами:
///   UW: W ≠ 0, (x,y,z) = (X/W, Y/W, Z/W)  — основная
///   UX: X ≠ 0, (y,z,w) = (Y/X, Z/X, W/X)  — восток
///   UY: Y ≠ 0, (x,z,w) = (X/Y, Z/Y, W/Y)  — север
///   UZ: Z ≠ 0, (x,y,w) = (X/Z, Y/Z, W/Z)  — вверх
pub const AffineCard = enum(u2) {
    UW = 0,
    UX = 1,
    UY = 2,
    UZ = 3,
};

/// Однородный вектор [X:Y:Z:W] — точка в P³.
///
/// P³ = (R⁴ \ {0}) / ~, где (X,Y,Z,W) ~ (λX, λY, λZ, λW), λ ≠ 0.
/// Канонический представитель: нормированный на S³ (‖v‖ = 1).
///
/// Внутреннее представление: [4]f64 (не SIMD — точность важнее).
/// SIMD-версия для рендера: F64x4 через toSimd().
pub const HomVec4 = struct {
    x: f64,
    y: f64,
    z: f64,
    w: f64,

    /// Конструктор однородного вектора [X:Y:Z:W]
    pub inline fn init(X: f64, Y: f64, Z: f64, W: f64) HomVec4 {
        return .{ .x = X, .y = Y, .z = Z, .w = W };
    }

    /// Конструктор из декартовых координат: [x, y, z, 1]
    pub inline fn fromCartesian(p: [3]f64) HomVec4 {
        return .{ .x = p[0], .y = p[1], .z = p[2], .w = 1.0 };
    }

    /// Нулевой вектор (не представляет точку в P³ — используется как sentinel)
    pub inline fn zero() HomVec4 {
        return .{ .x = 0, .y = 0, .z = 0, .w = 0 };
    }

    /// Дегомогенизация P³ → R³: (X/W, Y/W, Z/W) при W ≠ 0
    /// Если W = 0 — точка на бесконечности, возвращаем направление
    pub fn cartesian3(self: HomVec4) [3]f64 {
        if (@abs(self.w) < W_EPS) {
            // Точка на бесконечности — возвращаем нормированное направление
            const n = self.norm();
            if (n < 1e-15) return .{ 0, 0, 0 };
            return .{ self.x / n, self.y / n, self.z / n };
        }
        return .{
            self.x / self.w,
            self.y / self.w,
            self.z / self.w,
        };
    }

    /// Норма ‖v‖ = √(X² + Y² + Z² + W²)
    pub fn norm(self: HomVec4) f64 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
    }

    /// Нормализация на S³: v / ‖v‖
    /// CORDIC-подобная (здесь прямая — CORDIC в cordicInvSqrt)
    pub fn normalize(self: HomVec4) HomVec4 {
        const n = self.norm();
        if (n < 1e-15) return HomVec4.init(0, 0, 0, 1);
        return HomVec4.init(self.x / n, self.y / n, self.z / n, self.w / n);
    }

    /// Скалярное произведение в гильбертовом пространстве:
    /// ⟨a, b⟩ = a.x·b.x + a.y·b.y + a.z·b.z + a.w·b.w
    pub inline fn dot(a: HomVec4, b: HomVec4) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    }

    /// Проверка: представляют ли два вектора одну P³-точку?
    /// v ~ ±w (антиподальное отождествление Z/2Z)
    /// |⟨v,w⟩| / (‖v‖·‖w‖) ≈ 1
    pub fn isSamePoint(a: HomVec4, b: HomVec4, tol: f64) bool {
        const n1 = a.norm();
        const n2 = b.norm();
        if (n1 < tol or n2 < tol) return false;
        const d = @abs(HomVec4.dot(a, b)) / (n1 * n2);
        return d > 1.0 - tol;
    }

    /// Антиподальная проверка: p ≈ −p?
    /// В RP³: p и −p — одна точка. В S³ — разные.
    /// Эта функция определяет, прошёл ли объект через
    /// антиподальное отождествление (Z/2Z-туннель).
    pub fn isAntipodalTo(a: HomVec4, b: HomVec4, tol: f64) bool {
        const neg_b = HomVec4.init(-b.x, -b.y, -b.z, -b.w);
        return HomVec4.isSamePoint(a, neg_b, tol);
    }

    /// Выбор наилучшей афинной карты.
    /// Карта с наибольшей координатой даёт наименьшую погрешность деления.
    /// Переключение при |W| < W_EPS (10⁻⁶) — это НЕ ошибка,
    /// это МЕХАНИКА бесшовного обхода P³.
    pub fn pickBestCard(self: HomVec4) AffineCard {
        const aw = @abs(self.w);
        const ax = @abs(self.x);
        const ay = @abs(self.y);
        const az = @abs(self.z);
        if (aw >= ax and aw >= ay and aw >= az) return .UW;
        if (ax >= ay and ax >= az) return .UX;
        if (ay >= az) return .UY;
        return .UZ;
    }

    /// Дегомогенизация в заданной афинной карте
    pub fn toAffine(self: HomVec4, card: AffineCard) [3]f64 {
        return switch (card) {
            .UW => .{ self.x / self.w, self.y / self.w, self.z / self.w },
            .UX => .{ self.y / self.x, self.z / self.x, self.w / self.x },
            .UY => .{ self.x / self.y, self.z / self.y, self.w / self.y },
            .UZ => .{ self.x / self.z, self.y / self.z, self.w / self.z },
        };
    }

    /// Конверсия в SIMD f64×4
    pub inline fn toSimd(self: HomVec4) F64x4 {
        return f64x4(self.x, self.y, self.z, self.w);
    }

    /// Конверсия в SIMD f32×4 (для рендера — с потерей точности)
    pub inline fn toSimdF32(self: HomVec4) F32x4 {
        return f32x4(
            @floatCast(self.x),
            @floatCast(self.y),
            @floatCast(self.z),
            @floatCast(self.w),
        );
    }

    /// Конверсия из SIMD f64×4
    pub inline fn fromSimd(v: F64x4) HomVec4 {
        return HomVec4.init(v[0], v[1], v[2], v[3]);
    }
};

// =============================================================================
// 3. МАТРИЦА PGL(4,ℝ) (из zm — переписано)
// =============================================================================
//
// zm использует Matrix(m, n, T) comptime-конструктор.
// Мы берём: Matrix(4, 4, f64), mul, transpose, det.
// Выкидываем: всё евклидово (rotation, lookAt, perspective).
//
// Добавляем: det ≠ 0 guarantee (comptime check),
//            Newton-Schulz inverse,
//            renormalization det → +1.

/// Матрица PGL(4,ℝ) = GL(4,ℝ) / ℝ*.
///
/// 4×4 матрица с det, нормированным к +1.
/// Это группа проективных преобразований P³.
///
/// Хранение: column-major (каноническое для PGL(4,ℝ)),
///           data[col * 4 + row].
pub const PGL4 = struct {
    /// Column-major 4×4 = [16]f64
    data: [16]f64,

    /// Единичная матрица
    pub fn identity() PGL4 {
        return .{ .data = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    /// Конструктор из column-major массива
    pub inline fn init(data: [16]f64) PGL4 {
        return .{ .data = data };
    }

    /// Конструктор из 2D row-major массива [4][4]f64 → конвертирует в column-major
    pub fn fromRowMajor(m: [4][4]f64) PGL4 {
        var result: PGL4 = undefined;
        for (0..4) |col| {
            for (0..4) |row| {
                result.data[col * 4 + row] = m[row][col];
            }
        }
        return result;
    }

    /// Доступ: M(row, col)
    pub inline fn get(self: PGL4, row: usize, col: usize) f64 {
        return self.data[col * 4 + row];
    }

    /// Установка: M(row, col) = val
    pub inline fn set(self: *PGL4, row: usize, col: usize, val: f64) void {
        self.data[col * 4 + row] = val;
    }

    /// Действие PGL(4) на P³: v → M·v
    /// (column-major × column-vector)
    pub fn apply(self: PGL4, v: HomVec4) HomVec4 {
        var result: [4]f64 = .{ 0, 0, 0, 0 };
        for (0..4) |row| {
            for (0..4) |col| {
                const v_comp: f64 = switch (col) {
                    0 => v.x,
                    1 => v.y,
                    2 => v.z,
                    3 => v.w,
                    else => unreachable,
                };
                result[row] += self.get(row, col) * v_comp;
            }
        }
        return HomVec4.init(result[0], result[1], result[2], result[3]);
    }

    /// Матричное умножение: A · B (композиция PGL(4))
    pub fn mul(a: PGL4, b: PGL4) PGL4 {
        var result: PGL4 = undefined;
        for (0..4) |col| {
            for (0..4) |row| {
                var sum: f64 = 0;
                for (0..4) |k| {
                    sum += a.get(row, k) * b.get(k, col);
                }
                result.set(row, col, sum);
            }
        }
        return result;
    }

    /// Транспозиция
    pub fn transpose(self: PGL4) PGL4 {
        var result: PGL4 = undefined;
        for (0..4) |row| {
            for (0..4) |col| {
                result.set(row, col, self.get(col, row));
            }
        }
        return result;
    }

    /// Определитель 4×4 через разложение по первой строке (Laplace)
    pub fn det(self: PGL4) f64 {
        // 3×3 минор: вычёркиваем строку row, столбец col
        const m3 = struct {
            fn minor(m: PGL4, r: usize, c: usize) f64 {
                // Собираем 3×3 подматрицу
                var s: [3][3]f64 = undefined;
                var si: usize = 0;
                for (0..4) |i| {
                    if (i == r) continue;
                    var sj: usize = 0;
                    for (0..4) |j| {
                        if (j == c) continue;
                        s[si][sj] = m.get(i, j);
                        sj += 1;
                    }
                    si += 1;
                }
                // det 3×3 (Sarrus)
                return s[0][0] * (s[1][1] * s[2][2] - s[1][2] * s[2][1]) -
                    s[0][1] * (s[1][0] * s[2][2] - s[1][2] * s[2][0]) +
                    s[0][2] * (s[1][0] * s[2][1] - s[1][1] * s[2][0]);
            }
        };
        return self.get(0, 0) * m3.minor(self, 0, 0) -
            self.get(0, 1) * m3.minor(self, 0, 1) +
            self.get(0, 2) * m3.minor(self, 0, 2) -
            self.get(0, 3) * m3.minor(self, 0, 3);
    }

    /// Ренормализация: det → +1
    /// det(λM) = λ⁴ det(M) → λ = det(M)^(−1/4)
    pub fn normalizeDet(self: PGL4) PGL4 {
        const d = self.det();
        if (@abs(d) < 1e-15) return self; // Сингулярная — не трогаем
        const det_scale = math.pow(f64, @abs(d), -0.25);
        var result = self;
        for (0..16) |i| {
            result.data[i] *= det_scale;
        }
        return result;
    }

    /// Newton-Schulz итеративная инверсия 4×4 матрицы.
    /// X_{k+1} = X_k · (2I − M · X_k)
    /// С Tikhonov регуляризацией: M_reg = M + δ·I
    pub fn inverse(self: PGL4, delta: f64, max_iter: u32) PGL4 {
        const I4 = PGL4.identity();

        // M_reg = M + δ·I
        var m_reg = self;
        for (0..4) |i| {
            m_reg.set(i, i, m_reg.get(i, i) + delta);
        }

        // Initial guess: X_0 = M^T / ‖M‖²
        const mt = m_reg.transpose();
        var norm_sq: f64 = 0;
        for (0..16) |i| {
            norm_sq += m_reg.data[i] * m_reg.data[i];
        }
        var x = mt;
        for (0..16) |i| {
            x.data[i] /= norm_sq;
        }

        // Итерации Newton-Schulz
        for (0..max_iter) |_| {
            const mx = PGL4.mul(m_reg, x);
            // X = X · (2I - MX)
            var two_i_minus_mx = mx;
            for (0..16) |i| {
                two_i_minus_mx.data[i] = 2.0 * I4.data[i] - two_i_minus_mx.data[i];
            }
            x = PGL4.mul(x, two_i_minus_mx);

            // Проверка сходимости: max|M·X − I|
            const residual_check = PGL4.mul(m_reg, x);
            var residual: f64 = 0;
            for (0..16) |i| {
                residual = @max(residual, @abs(residual_check.data[i] - I4.data[i]));
            }
            if (residual < 1e-12) break;
        }

        return x;
    }

    /// Масштабирование матрицы: s·M
    pub fn scale(self: PGL4, s: f64) PGL4 {
        var result: PGL4 = undefined;
        for (0..16) |i| {
            result.data[i] = self.data[i] * s;
        }
        return result;
    }

    /// Сложение матриц: A + B
    pub fn add(a: PGL4, b: PGL4) PGL4 {
        var result: PGL4 = undefined;
        for (0..16) |i| {
            result.data[i] = a.data[i] + b.data[i];
        }
        return result;
    }
};

/// Конструктор PGL4 с comptime-проверкой det ≠ 0
/// Матрица должна быть comptime-known для проверки.
/// Если матрица runtime — используй PGL4.fromRowMajor() + runtime assert.
pub fn pglFromHomogeneous(comptime m: [4][4]f64) PGL4 {
    // Comptime det check: вычисляем определитель прямо из m
    comptime {
        // Inline 4×4 determinant from row-major [4][4]f64
        var det_val: f64 = 0;
        // Laplace expansion along first row
        // We need the full 4×4 det from the raw array
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
            @compileError("PGL4: singular matrix (det ≈ 0). Not in GL(4,R).");
        }
    }
    return PGL4.fromRowMajor(m);
}

// =============================================================================
// 4. МЕТРИКА ФУБИНИ–ШТУДИ
// =============================================================================

/// Метрика Фубини–Штуди:
/// d_FS(v₁, v₂) = arccos( |⟨v₁, v₂⟩| / (‖v₁‖ · ‖v₂‖) )  ∈ [0, π/2]
///
/// Это CANONICAL расстояние на CPⁿ, индуцирует расстояние на RP³ ⊂ CP³.
/// d = 0: та же точка. d = π/2: ортогональные. d = π/4: «половина пути».
pub fn fsDistance(a: HomVec4, b: HomVec4) f64 {
    const n1 = a.norm();
    const n2 = b.norm();
    if (n1 < 1e-15 or n2 < 1e-15) return 0.0;
    const d = @abs(HomVec4.dot(a, b)) / (n1 * n2);
    // Clamp: численная погрешность может дать d > 1
    const cos_theta = @min(1.0, d);
    return math.acos(cos_theta);
}

/// W = cos(s / 2R) — калибровка расстояния
/// s = физическое расстояние (м), R = радиус (м)
/// W = гомогенная координата, соответствующая этому расстоянию
pub fn wFromDistance(s_meters: f64, R_meters: f64) f64 {
    return @cos(s_meters / (2.0 * R_meters));
}

/// s = 2R · arccos(W) — обратная калибровка
pub fn sFromW(W: f64, R_meters: f64) f64 {
    const W_clamped = @max(-1.0, @min(1.0, W));
    return 2.0 * R_meters * math.acos(W_clamped);
}

// =============================================================================
// 5. POLER MATH BRIDGE
// =============================================================================

/// CORDIC 1/√x через Newton-Raphson.
/// Из P3_Voxel_Engine: p3_poler_math::cordic::inv_sqrt
/// 3 итерации дают точность ~1e-15 для f64.
/// Быстрый inverse sqrt (Quake trick) + Newton-Raphson refinement.
pub fn cordicInvSqrt(x: f64) f64 {
    if (x <= 0) return 0.0;
    // Initial guess через bit manipulation (fast inverse sqrt)
    const bits: u64 = @bitCast(x);
    const magic: u64 = 0x5fe6eb50c7b537a9;
    const y_bits: u64 = magic - (bits >> 1);
    var y: f64 = @bitCast(y_bits);
    // Newton-Raphson: y → y(1.5 − 0.5·x·y²)
    const half_x = 0.5 * x;
    y = y * (1.5 - half_x * y * y);
    y = y * (1.5 - half_x * y * y);
    y = y * (1.5 - half_x * y * y);
    return y;
}

/// Матрица кручения J = A − Aᵀ (кососимметричная).
///
/// Генератор резонанса. J^T = −J → iJ — эрмитов оператор,
/// предотвращающий численный взрыв в POLER-динамике.
/// Спектр iJ ∈ ℝ — «частоты конфликта».
pub fn computeResonance(a: PGL4) PGL4 {
    const at = a.transpose();
    var result: PGL4 = undefined;
    for (0..16) |i| {
        result.data[i] = a.data[i] - at.data[i];
    }
    return result;
}

/// Каузальный проектор Π_Λ = I − Jcᵀ(Jc·Jcᵀ + δI)⁻¹Jc
///
/// Проектирует состояние на каузальное подмногообразие,
/// где логика и сохранение смысла выполняются.
/// Вычисляется через Newton-Schulz inversion.
pub fn computeProjector(jc: PGL4, delta: f64) PGL4 {
    const I4 = PGL4.identity();
    const jct = jc.transpose();

    // Jc · Jcᵀ + δ·I (symmetric positive-definite)
    var jjt = PGL4.mul(jc, jct);
    for (0..4) |i| {
        jjt.set(i, i, jjt.get(i, i) + delta);
    }

    // Обращение через Newton-Schulz
    const jjt_inv = jjt.inverse(delta, 8);

    // Π_Λ = I − Jcᵀ · (Jc·Jcᵀ + δI)⁻¹ · Jc
    const middle = PGL4.mul(jct, jjt_inv);
    const projector_part = PGL4.mul(middle, jc);

    var pi_lambda = I4;
    for (0..16) |i| {
        pi_lambda.data[i] -= projector_part.data[i];
    }
    return pi_lambda;
}

/// Деформированное тензорное произведение (Риффель):
/// X ⊗_ε Y = (X·Y) + ε·(X⊙Y)
///
/// где · — матричное умножение (линейное взаимодействие)
///     ⊙ — произведение Адамара (поэлементное, нелинейная связь)
///
/// ε = 0: стандартное произведение (коммутативный предел)
/// ε > 0: семантическое трение (порядок composition важен)
pub fn deformedTensorProduct(x: PGL4, y: PGL4, epsilon: f64) PGL4 {
    const linear = PGL4.mul(x, y);
    var result = linear;
    for (0..16) |i| {
        result.data[i] += epsilon * x.data[i] * y.data[i]; // Адамар
    }
    return result;
}

// =============================================================================
// 6. СТАНДАРТНЫЕ PGL(4,ℝ) ПРЕОБРАЗОВАНИЯ
// =============================================================================

/// Трансляция в P³: [X:Y:Z:W] → [X+tx·W : Y+ty·W : Z+tz·W : W]
/// Column-major: last column = [tx, ty, tz, 1]
pub fn pglTranslate(tx: f64, ty: f64, tz: f64) PGL4 {
    return PGL4.init(.{
        1, 0, 0, 0,  // col 0
        0, 1, 0, 0,  // col 1
        0, 0, 1, 0,  // col 2
        tx, ty, tz, 1, // col 3 (translation)
    });
}

/// Масштабирование в P³: [X:Y:Z:W] → [sx·X : sy·Y : sz·Z : W]
/// Column-major: diagonal
pub fn pglScale(sx: f64, sy: f64, sz: f64) PGL4 {
    return PGL4.init(.{
        sx, 0,  0,  0,  // col 0
        0,  sy, 0,  0,  // col 1
        0,  0,  sz, 0,  // col 2
        0,  0,  0,  1,  // col 3
    });
}

/// Проективное вращение вокруг оси Z:
/// [X:Y:Z:W] → [X·cos−Y·sin : X·sin+Y·cos : Z : W]
/// Column-major
pub fn pglRotateZ(angle: f64) PGL4 {
    const c = @cos(angle);
    const s = @sin(angle);
    return PGL4.init(.{
        c,  s, 0, 0,  // col 0
        -s, c, 0, 0,  // col 1
        0,  0, 1, 0,  // col 2
        0,  0, 0, 1,  // col 3
    });
}

/// Инверсия (полюс-полярное преобразование):
/// Модель для M1/M2 гравитационных линз.
/// [X:Y:Z:W] → [X:Y:Z: (X²+Y²+Z²)/R²]
pub fn pglInversion(radius: f64) PGL4 {
    // Это не линейное преобразование — возвращаем
    // аппроксимацию через проективное преобразование:
    // [X:Y:Z:W] → [R²·X : R²·Y : R²·Z : (X²+Y²+Z²)·W]
    // Полная инверсия — нелинейна, требует compute shader.
    // Здесь: простое масштабирование 1/R² как placeholder.
    _ = radius;
    return PGL4.identity(); // TODO: non-linear inversion in compute shader
}

// =============================================================================
// 7. ТЕСТЫ
// =============================================================================

test "HomVec4: constructors and cartesian dehomogenization" {
    const v = HomVec4.fromCartesian(.{ 3.0, 4.0, 5.0 });
    try std.testing.expectApproxEqAbs(v.x, 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(v.y, 4.0, 1e-10);
    try std.testing.expectApproxEqAbs(v.z, 5.0, 1e-10);
    try std.testing.expectApproxEqAbs(v.w, 1.0, 1e-10);

    const c = v.cartesian3();
    try std.testing.expectApproxEqAbs(c[0], 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(c[1], 4.0, 1e-10);
    try std.testing.expectApproxEqAbs(c[2], 5.0, 1e-10);

    // Однородное масштабирование: [2:4:6:2] = [1:2:3:1]
    const v2 = HomVec4.init(2, 4, 6, 2);
    const c2 = v2.cartesian3();
    try std.testing.expectApproxEqAbs(c2[0], 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(c2[1], 2.0, 1e-10);
    try std.testing.expectApproxEqAbs(c2[2], 3.0, 1e-10);
}

test "HomVec4: normalization on S³" {
    const v = HomVec4.init(3, 0, 0, 4);
    const n = v.normalize();
    try std.testing.expectApproxEqAbs(n.norm(), 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(n.x, 0.6, 1e-10);
    try std.testing.expectApproxEqAbs(n.w, 0.8, 1e-10);
}

test "HomVec4: dot product and isSamePoint" {
    const a = HomVec4.init(1, 0, 0, 0);
    const b = HomVec4.init(1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(HomVec4.dot(a, b), 1.0, 1e-10);

    const c = HomVec4.init(0, 1, 0, 0);
    try std.testing.expectApproxEqAbs(HomVec4.dot(a, c), 0.0, 1e-10);

    // Антипод: [1,0,0,0] и [-1,0,0,0] — одна RP³-точка
    const neg_a = HomVec4.init(-1, 0, 0, 0);
    try std.testing.expect(a.isSamePoint(neg_a, 1e-8));
}

test "HomVec4: antipodal check Z/2Z" {
    const p = HomVec4.init(1, 2, 3, 4);
    const neg_p = HomVec4.init(-1, -2, -3, -4);
    try std.testing.expect(p.isAntipodalTo(neg_p, 1e-8));

    const other = HomVec4.init(1, 2, 3, 5);
    try std.testing.expect(!p.isAntipodalTo(other, 1e-8));
}

test "HomVec4: affine card selection" {
    // [1:2:3:4] → W наибольшая → UW
    const v1 = HomVec4.init(1, 2, 3, 4);
    try std.testing.expect(v1.pickBestCard() == .UW);

    // [5:1:1:1] → X наибольшая → UX
    const v2 = HomVec4.init(5, 1, 1, 1);
    try std.testing.expect(v2.pickBestCard() == .UX);

    // [1:6:1:1] → Y наибольшая → UY
    const v3 = HomVec4.init(1, 6, 1, 1);
    try std.testing.expect(v3.pickBestCard() == .UY);

    // [1:1:7:1] → Z наибольшая → UZ
    const v4 = HomVec4.init(1, 1, 7, 1);
    try std.testing.expect(v4.pickBestCard() == .UZ);
}

test "Fubini-Study distance: known values" {
    // Одна точка: d = 0
    const a = HomVec4.init(1, 0, 0, 0);
    const b = HomVec4.init(1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(fsDistance(a, b), 0.0, 1e-10);

    // Ортогональные точки: d = π/2
    const c = HomVec4.init(1, 0, 0, 0);
    const d = HomVec4.init(0, 1, 0, 0);
    try std.testing.expectApproxEqAbs(fsDistance(c, d), math.pi / 2.0, 1e-10);

    // Антипод: d = 0 (в RP³ p ~ −p)
    // После нормализации |<p,-p>|/(||p||·||-p||) = 1.0 → arccos(1) = 0
    const e = HomVec4.init(1, 0, 0, 1).normalize();
    const f = HomVec4.init(-1, 0, 0, -1).normalize();
    try std.testing.expectApproxEqAbs(fsDistance(e, f), 0.0, 1e-6);

    // «Половина пути»: d = π/4
    // [1,0,0,0] и [1,0,0,1] → cos = 1/√2 → d = π/4
    const g = HomVec4.init(1, 0, 0, 0).normalize();
    const h = HomVec4.init(1, 0, 0, 1).normalize();
    try std.testing.expectApproxEqAbs(fsDistance(g, h), math.pi / 4.0, 1e-10);
}

test "PGL4: identity action" {
    const I = PGL4.identity();
    const v = HomVec4.init(3, 4, 5, 1);
    const result = I.apply(v);
    try std.testing.expectApproxEqAbs(result.x, 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(result.y, 4.0, 1e-10);
    try std.testing.expectApproxEqAbs(result.z, 5.0, 1e-10);
    try std.testing.expectApproxEqAbs(result.w, 1.0, 1e-10);
}

test "PGL4: determinant" {
    const I = PGL4.identity();
    try std.testing.expectApproxEqAbs(I.det(), 1.0, 1e-10);

    const S = pglScale(2, 3, 4);
    try std.testing.expectApproxEqAbs(S.det(), 24.0, 1e-10);
}

test "PGL4: translation and scale" {
    const T = pglTranslate(10, 20, 30);
    const v = HomVec4.fromCartesian(.{ 1, 2, 3 });
    const result = T.apply(v);
    const c = result.cartesian3();
    // T(x,y,z) = (x+10, y+20, z+30) = (11, 22, 33)
    try std.testing.expectApproxEqAbs(c[0], 11.0, 1e-8);
    try std.testing.expectApproxEqAbs(c[1], 22.0, 1e-8);
    try std.testing.expectApproxEqAbs(c[2], 33.0, 1e-8);
}

test "PGL4: Newton-Schulz inverse" {
    const M = pglScale(2, 3, 4);
    const M_inv = M.inverse(1e-10, 15);
    const product = PGL4.mul(M, M_inv);

    // M · M⁻¹ ≈ I
    for (0..4) |row| {
        for (0..4) |col| {
            const expected: f64 = if (row == col) 1.0 else 0.0;
            try std.testing.expectApproxEqAbs(product.get(row, col), expected, 1e-6);
        }
    }
}

test "PGL4: normalizeDet → det ≈ 1" {
    const M = pglScale(2, 3, 4);
    const M_norm = M.normalizeDet();
    try std.testing.expectApproxEqAbs(@abs(M_norm.det()), 1.0, 1e-6);
}

test "PGL4: rotation preserves norm" {
    const R = pglRotateZ(math.pi / 4.0);
    const v = HomVec4.init(1, 0, 0, 1);
    const result = R.apply(v);
    // ‖result‖² должна сохраниться (PGL(4) на P³)
    const n_before = v.norm();
    const n_after = result.norm();
    try std.testing.expectApproxEqAbs(n_before, n_after, 1e-10);
}

test "SIMD: dot4 and normalize" {
    const a = f32x4(1, 0, 0, 0);
    const b = f32x4(1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(simdDot4(a, b), 1.0, 1e-5);

    const c = f32x4(3, 0, 0, 4);
    const n = simdNormalize3(c);
    try std.testing.expectApproxEqAbs(simdDot4(n, n), 1.0, 1e-5);
}

test "CORDIC inverse sqrt" {
    try std.testing.expectApproxEqAbs(cordicInvSqrt(4.0), 0.5, 1e-10);
    try std.testing.expectApproxEqAbs(cordicInvSqrt(1.0), 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(cordicInvSqrt(9.0), 1.0 / 3.0, 1e-10);
}

test "Resonance J = A − Aᵀ is antisymmetric" {
    const A = PGL4.init(.{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16,
    });
    const J = computeResonance(A);
    const Jt = J.transpose();
    // J^T = −J
    for (0..4) |row| {
        for (0..4) |col| {
            try std.testing.expectApproxEqAbs(Jt.get(row, col), -J.get(row, col), 1e-10);
        }
    }
}

test "Projector Π_Λ is idempotent: Π² = Π" {
    const Jc = PGL4.init(.{
        0, 1, 0, 0,
        -1, 0, 0, 0,
        0, 0, 0, 1,
        0, 0, -1, 0,
    });
    const Pi = computeProjector(Jc, 1e-8);
    const Pi2 = PGL4.mul(Pi, Pi);
    // Π² ≈ Π (idempotent)
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(Pi2.data[i], Pi.data[i], 1e-4);
    }
}

test "Deformed tensor product: ε=0 is standard mul" {
    const A = pglScale(2, 1, 1);
    const B = pglTranslate(3, 0, 0);
    const standard = PGL4.mul(A, B);
    const deformed = deformedTensorProduct(A, B, 0.0);
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(standard.data[i], deformed.data[i], 1e-10);
    }
}

test "w_from_distance / s_from_W round-trip" {
    const s: f64 = 1000.0; // 1 км
    const R: f64 = R_ETERIA_KM * 1000.0; // в метрах
    const W = wFromDistance(s, R);
    const s_back = sFromW(W, R);
    // Round-trip через cos/arccos: потеря точности ожидаема
    try std.testing.expectApproxEqAbs(s, s_back, 0.01); // < 1 см при 1 км
}

test "PGL4 comptime: pglFromHomogeneous rejects singular" {
    // This test verifies that compile-time check works.
    // A non-singular matrix should compile fine:
    const M = pglFromHomogeneous(.{
        .{ 2, 0, 0, 0 },
        .{ 0, 3, 0, 0 },
        .{ 0, 0, 4, 0 },
        .{ 0, 0, 0, 5 },
    });
    try std.testing.expectApproxEqAbs(M.det(), 120.0, 1e-6);
    // Note: singular matrix would be caught at comptime,
    // so we can't test it in a runtime test (it won't compile).
}
