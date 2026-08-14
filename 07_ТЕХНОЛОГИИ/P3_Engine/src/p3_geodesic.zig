// =============================================================================
// P³ GEODESIC — ГЕОДЕЗИЧЕСКИЕ НА P³ С RK4 ИНТЕГРАТОРОМ
// =============================================================================
//
// Геодезические на RP³ (с метрикой Фубини-Штуди) — это большие круги
// на S³, проектируемые на RP³. В однородных координатах:
//
//   γ(t) = cos(t)·p + sin(t)·v
//
// где p — начальная точка (нормирована: ‖p‖=1),
//     v — начальная скорость (ортогональна p: ⟨p,v⟩=0, ‖v‖=1),
//     t — параметр (не расстояние! d_FS = 2·|t| mod π).
//
// Доноры:
//   - Донор #7 (Astrodynamics): RK4/RK45 структура интеграторов
//   - zmath/zm: SIMD векторных операций (переписано)
//   - P³ COMPENDIUM: геодезические как Z/2Z-орбиты больших кругов
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================
//
// МАТЕМАТИЧЕСКАЯ СПРАВКА:
//
// 1. Геодезическая на (S³, g_FS) через точку p со скоростью v:
//    γ(t) = cos(|v|·t)·p + sin(|v|·t)·v/|v|
//    Для |v|=1: γ(t) = cos(t)·p + sin(t)·v
//
// 2. На RP³ геодезическая замкнута с периодом π (Z/2Z-отождествление).
//    γ(t) и γ(t+π) = −γ(t) — одна RP³-точка.
//
// 3. Расстояние Фубини-Штуди вдоль геодезической:
//    d_FS(p, γ(t)) = min(|t|, π−|t|) ∈ [0, π/2]
//
// 4. Геодезическое уравнение (общий случай, для потока в P³):
//    ẍ^i + Γ^i_{jk} ẋ^j ẋ^k = F^i(x, ẋ)
//    где Γ^i_{jk} — символы Кристоффеля метрики Фубини-Штуди,
//    F^i — внешняя сила (POLER-динамика).
//
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. АНАЛИТИЧЕСКИЕ ГЕОДЕЗИЧЕСКИЕ (ТОЧНОЕ РЕШЕНИЕ)
// =============================================================================

/// Геодезическая на S³: γ(t) = cos(t)·p + sin(t)·v
///
/// p: начальная точка, ‖p‖ = 1
/// v: начальная скорость, ⟨p,v⟩ = 0, ‖v‖ = 1
/// t: параметр
///
/// Результат всегда на S³ (‖γ‖ = 1 для любых t).
pub fn geodesicExact(p: HomVec4, v: HomVec4, t: f64) HomVec4 {
    const ct = @cos(t);
    const st = @sin(t);
    return HomVec4.init(
        ct * p.x + st * v.x,
        ct * p.y + st * v.y,
        ct * p.z + st * v.z,
        ct * p.w + st * v.w,
    );
}

/// Геодезическая с масштабом скорости: γ(t) = cos(|v|·t)·p + sin(|v|·t)·v/|v|
///
/// Если |v| ≠ 1, геодезическая проходит с другой скоростью.
pub fn geodesicScaled(p: HomVec4, v: HomVec4, t: f64) HomVec4 {
    const speed = v.norm();
    if (speed < 1e-15) return p;
    const st = speed * t;
    const ct = @cos(st);
    const sn = @sin(st);
    const inv_speed = 1.0 / speed;
    return HomVec4.init(
        ct * p.x + sn * v.x * inv_speed,
        ct * p.y + sn * v.y * inv_speed,
        ct * p.z + sn * v.z * inv_speed,
        ct * p.w + sn * v.w * inv_speed,
    );
}

/// Расстояние Фубини-Штуди вдоль геодезической: min(|t|, π−|t|)
pub fn fsDistanceAlongGeodesic(t: f64) f64 {
    const abs_t = @abs(t);
    // Приводим к [0, π] и берём минимум с антиподом
    const reduced = @mod(abs_t, math.pi);
    return @min(reduced, math.pi - reduced);
}

/// Выбор ортонормального вектора v ⟂ p.
/// v — касательный к S³ в точке p, для инициализации геодезической.
/// Стратегия: берём стандартный базисный вектор eᵢ с наименьшим |⟨p,eᵢ⟩|.
pub fn orthogonalVelocity(p: HomVec4) HomVec4 {
    const aw = @abs(p.w);
    const ax = @abs(p.x);
    const ay = @abs(p.y);
    const az = @abs(p.z);

    // Берём базисный вектор, наименее параллельный p
    if (aw <= ax and aw <= ay and aw <= az) {
        // e_w = [0,0,0,1], ортогонализуем: e_w − ⟨p,e_w⟩·p = e_w − p.w·p
        var v = HomVec4.init(-p.w * p.x, -p.w * p.y, -p.w * p.z, 1.0 - p.w * p.w);
        return v.normalize();
    }
    if (ax <= ay and ax <= az) {
        var v = HomVec4.init(1.0 - p.x * p.x, -p.x * p.y, -p.x * p.z, -p.x * p.w);
        return v.normalize();
    }
    if (ay <= az) {
        var v = HomVec4.init(-p.y * p.x, 1.0 - p.y * p.y, -p.y * p.z, -p.y * p.w);
        return v.normalize();
    }
    {
        var v = HomVec4.init(-p.z * p.x, -p.z * p.y, 1.0 - p.z * p.z, -p.z * p.w);
        return v.normalize();
    }
}

/// Параллельный перенос вектора w вдоль геодезической γ(t).
///
/// На S³ с FS-метрикой параллельный перенос вдоль γ(t) = cos(t)·p + sin(t)·v:
///   P_t(w) = w − ⟨w,γ̇⟩·γ̇ + ⟨w,γ̇⟩·(−sin(t)·p + cos(t)·v)
///          = w + ⟨w,v⟩·(−sin(t)·p + cos(t)·v − v)
///
/// Упрощённая версия: если w ∈ span{p, v}, то поворот на угол t.
/// Если w ⟂ p и w ⟂ v, то P_t(w) = w (не меняется).
pub fn parallelTransport(p: HomVec4, v: HomVec4, w: HomVec4, t: f64) HomVec4 {
    const ct = @cos(t);
    const st = @sin(t);

    // Разложение w = w_∥ + w_⊥ где w_∥ ∈ span{p, v}
    const wp = HomVec4.dot(w, p); // ⟨w, p⟩
    const wv = HomVec4.dot(w, v); // ⟨w, v⟩

    // Параллельно перенесённая часть в span{p, v}: поворот на t
    // P_t(w_∥) = wp·γ(t) + wv·γ̇(t) = wp·(cos·p+sin·v) + wv·(−sin·p+cos·v)
    const parallel_x = (wp * ct - wv * st) * p.x + (wp * st + wv * ct) * v.x;
    const parallel_y = (wp * ct - wv * st) * p.y + (wp * st + wv * ct) * v.y;
    const parallel_z = (wp * ct - wv * st) * p.z + (wp * st + wv * ct) * v.z;
    const parallel_w = (wp * ct - wv * st) * p.w + (wp * st + wv * ct) * v.w;

    // Перпендикулярная часть не меняется: w_⊥ = w − wp·p − wv·v
    const perp_x = w.x - wp * p.x - wv * v.x;
    const perp_y = w.y - wp * p.y - wv * v.y;
    const perp_z = w.z - wp * p.z - wv * v.z;
    const perp_w = w.w - wp * p.w - wv * v.w;

    return HomVec4.init(
        parallel_x + perp_x,
        parallel_y + perp_y,
        parallel_z + perp_z,
        parallel_w + perp_w,
    );
}

// =============================================================================
// 2. RK4 ИНТЕГРАТОР (ИЗ ДОНОРА #7 — ASTRODYNAMICS, ПЕРЕПИСАНО)
// =============================================================================
//
// Структура взята из Zig-astrodynamics lib:
//   - RK4 для нежёстких ODE
//   - Адаптивный шаг (вложенный RK45 — Фаза 2)
//   - comptime выбор порядка
//
// Переписано: вместо Kepler/SGP4 — геодезические на P³.
//             вместо евклидова пространства — RP³ с FS-метрикой.
//
// ODE система: ẋ = f(t, x) где x ∈ R⁸ (позиция + скорость в R⁴)

/// Состояние ODE: позиция q ∈ R⁴ и скорость v ∈ R⁴
/// Полное состояние = точка в T(R⁴) ≅ R⁸
pub const GeodesicState = struct {
    q: [4]f64, // позиция (однородные координаты)
    v: [4]f64, // скорость (касательный вектор)

    pub inline fn init(q: [4]f64, v: [4]f64) GeodesicState {
        return .{ .q = q, .v = v };
    }

    pub inline fn fromHomVec4(position: HomVec4, velocity: HomVec4) GeodesicState {
        return .{
            .q = .{ position.x, position.y, position.z, position.w },
            .v = .{ velocity.x, velocity.y, velocity.z, velocity.w },
        };
    }

    pub inline fn pos(self: GeodesicState) HomVec4 {
        return HomVec4.init(self.q[0], self.q[1], self.q[2], self.q[3]);
    }

    pub inline fn vel(self: GeodesicState) HomVec4 {
        return HomVec4.init(self.v[0], self.v[1], self.v[2], self.v[3]);
    }
};

/// Тип функции правой части ODE: f(t, state) → d(state)/dt
pub const OdeFn = *const fn (f64, GeodesicState) GeodesicState;

/// Свободная геодезическая на S³: ẍ = −|v|²·x
/// Уравнение: q̈ = −‖v‖²·q (гармонический осциллятор на S³)
pub fn freeGeodesicRhs(_: f64, state: GeodesicState) GeodesicState {
    // |v|²
    const speed_sq = state.v[0] * state.v[0] +
        state.v[1] * state.v[1] +
        state.v[2] * state.v[2] +
        state.v[3] * state.v[3];

    // ẋ = v
    // ẍ = −|v|²·x (геодезическое уравнение на S³)
    return .{
        .q = .{ state.v[0], state.v[1], state.v[2], state.v[3] },
        .v = .{
            -speed_sq * state.q[0],
            -speed_sq * state.q[1],
            -speed_sq * state.q[2],
            -speed_sq * state.q[3],
        },
    };
}

/// Геодезическая с силой: ẍ = −|v|²·q + F(t, q, v)
/// F — внешняя сила (POLER-динамика, гравитация и т.д.)
pub const ForceFn = *const fn (f64, GeodesicState) [4]f64;

/// RK4 шаг: классический 4-порядок Runge-Kutta
///
/// k1 = f(t, y)
/// k2 = f(t + h/2, y + h/2·k1)
/// k3 = f(t + h/2, y + h/2·k2)
/// k4 = f(t + h, y + h·k3)
/// y(t+h) = y(t) + h/6·(k1 + 2k2 + 2k3 + k4)
pub fn rk4Step(f: OdeFn, t: f64, y: GeodesicState, h: f64) GeodesicState {
    const k1 = f(t, y);
    const k2 = f(t + 0.5 * h, addState(y, scaleState(k1, 0.5 * h)));
    const k3 = f(t + 0.5 * h, addState(y, scaleState(k2, 0.5 * h)));
    const k4 = f(t + h, addState(y, scaleState(k3, h)));

    // y + h/6·(k1 + 2k2 + 2k3 + k4)
    const combined = addState(
        addState(k1, scaleState(k2, 2.0)),
        addState(scaleState(k3, 2.0), k4),
    );
    return addState(y, scaleState(combined, h / 6.0));
}

/// Полная RK4 интеграция на интервале [t0, t1] с N шагами
pub fn rk4Integrate(
    f: OdeFn,
    t0: f64,
    t1: f64,
    y0: GeodesicState,
    n_steps: u32,
    allocator: std.mem.Allocator,
) ![]GeodesicState {
    const trajectory = try allocator.alloc(GeodesicState, n_steps + 1);
    const h = (t1 - t0) / @as(f64, @floatFromInt(n_steps));

    trajectory[0] = y0;
    var t = t0;
    for (1..n_steps + 1) |i| {
        trajectory[i] = rk4Step(f, t, trajectory[i - 1], h);
        t += h;
    }
    return trajectory;
}

/// Ренормализация состояния на S³: проецируем q на единичную сферу
/// и корректируем v, чтобы она была касательной.
/// Вызывать каждые ~100 шагов для предотвращения численного увода.
pub fn renormalizeOnS3(state: GeodesicState) GeodesicState {
    const q = state.pos();
    const n = q.norm();
    if (n < 1e-15) return state;

    // q → q/‖q‖ (проекция на S³)
    const q_norm = HomVec4.init(q.x / n, q.y / n, q.z / n, q.w / n);

    // v → v − ⟨v,q_norm⟩·q_norm (ортогонализация к S³)
    const v = state.vel();
    const vn = HomVec4.dot(v, q_norm);
    const v_tangent = HomVec4.init(
        v.x - vn * q_norm.x,
        v.y - vn * q_norm.y,
        v.z - vn * q_norm.z,
        v.w - vn * q_norm.w,
    );

    return GeodesicState.fromHomVec4(q_norm, v_tangent);
}

// =============================================================================
// 3. ЭКСПОНЕЦИАЛЬНОЕ ОТОБРАЖЕНИЕ
// =============================================================================
//
// exp_p: T_p(RP³) → RP³
// exp_p(v) = cos(|v|)·p + sin(|v|)·v/|v|
//
// Это «поднятие» касательного вектора v в точку на RP³,
// достигаемую движением вдоль геодезической на расстояние |v|.

/// Экспоненциальное отображение: exp_p(v) = cos(|v|)·p + sin(|v|)·v/|v|
pub fn expMap(p: HomVec4, v: HomVec4) HomVec4 {
    return geodesicScaled(p, v, 1.0);
}

/// Логарифмическое отображение: log_p(q) — касательный вектор,
/// такой что exp_p(log_p(q)) = q.
///
/// log_p(q) = d_FS(p,q) / sin(d_FS(p,q)) · (q − cos(d)·p)
/// где d = d_FS(p,q)
pub fn logMap(p: HomVec4, q: HomVec4) HomVec4 {
    const d = p3_kernel.fsDistance(p, q);
    if (d < 1e-15) return HomVec4.zero();

    const cos_d = @cos(d);
    const sin_d = @sin(d);
    if (@abs(sin_d) < 1e-15) return HomVec4.zero(); // Антипод

    const scale = d / sin_d;
    return HomVec4.init(
        scale * (q.x - cos_d * p.x),
        scale * (q.y - cos_d * p.y),
        scale * (q.z - cos_d * p.z),
        scale * (q.w - cos_d * p.w),
    );
}

// =============================================================================
// 4. ВНУТРЕННИЕ ПОМОГАТЕЛЬНЫЕ
// =============================================================================

fn addState(a: GeodesicState, b: GeodesicState) GeodesicState {
    var result: GeodesicState = undefined;
    for (0..4) |i| {
        result.q[i] = a.q[i] + b.q[i];
        result.v[i] = a.v[i] + b.v[i];
    }
    return result;
}

fn scaleState(s: GeodesicState, k: f64) GeodesicState {
    var result: GeodesicState = undefined;
    for (0..4) |i| {
        result.q[i] = s.q[i] * k;
        result.v[i] = s.v[i] * k;
    }
    return result;
}

// =============================================================================
// 5. ТЕСТЫ
// =============================================================================

test "Geodesic: exact solution stays on S³" {
    const p = HomVec4.init(1, 0, 0, 0);
    const v = HomVec4.init(0, 1, 0, 0);
    // γ(π/4) должен быть на S³
    const g = geodesicExact(p, v, math.pi / 4.0);
    try std.testing.expectApproxEqAbs(g.norm(), 1.0, 1e-10);
}

test "Geodesic: γ(0) = p" {
    const p = HomVec4.init(0.6, 0, 0, 0.8); // На S³
    const v = HomVec4.init(0, 1, 0, 0); // ⟂ p
    const g = geodesicExact(p, v, 0.0);
    try std.testing.expectApproxEqAbs(g.x, p.x, 1e-10);
    try std.testing.expectApproxEqAbs(g.y, p.y, 1e-10);
    try std.testing.expectApproxEqAbs(g.z, p.z, 1e-10);
    try std.testing.expectApproxEqAbs(g.w, p.w, 1e-10);
}

test "Geodesic: γ(π/2) = v when p ⟂ v" {
    const p = HomVec4.init(1, 0, 0, 0);
    const v = HomVec4.init(0, 1, 0, 0);
    const g = geodesicExact(p, v, math.pi / 2.0);
    // γ(π/2) = cos(π/2)·p + sin(π/2)·v = 0·p + 1·v = v
    try std.testing.expectApproxEqAbs(g.x, 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(g.y, 1.0, 1e-10);
}

test "Geodesic: γ(π) = −p (antipodal point)" {
    const p = HomVec4.init(1, 0, 0, 0);
    const v = HomVec4.init(0, 1, 0, 0);
    const g = geodesicExact(p, v, math.pi);
    // γ(π) = cos(π)·p + sin(π)·v = −p
    try std.testing.expectApproxEqAbs(g.x, -1.0, 1e-10);
    try std.testing.expectApproxEqAbs(g.y, 0.0, 1e-10);
}

test "Geodesic: FS distance along geodesic" {
    // d_FS(p, γ(t)) = min(|t|, π−|t|) для |v|=1
    try std.testing.expectApproxEqAbs(fsDistanceAlongGeodesic(0.0), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(fsDistanceAlongGeodesic(math.pi / 4.0), math.pi / 4.0, 1e-10);
    try std.testing.expectApproxEqAbs(fsDistanceAlongGeodesic(math.pi / 2.0), math.pi / 2.0, 1e-10);
    // t = 3π/4 → min(3π/4, π−3π/4) = π/4
    try std.testing.expectApproxEqAbs(fsDistanceAlongGeodesic(3.0 * math.pi / 4.0), math.pi / 4.0, 1e-10);
}

test "Geodesic: orthogonal velocity ⟂ p" {
    const p = HomVec4.init(0.6, 0, 0, 0.8); // На S³
    const v = orthogonalVelocity(p);
    // ⟨p,v⟩ = 0
    try std.testing.expectApproxEqAbs(HomVec4.dot(p, v), 0.0, 1e-8);
    // ‖v‖ = 1
    try std.testing.expectApproxEqAbs(v.norm(), 1.0, 1e-8);
}

test "Geodesic: RK4 vs exact solution" {
    const p = HomVec4.init(1, 0, 0, 0);
    const v = HomVec4.init(0, 1, 0, 0);

    const y0 = GeodesicState.fromHomVec4(p, v);
    const t_final = math.pi / 4.0;
    const n_steps: u32 = 100;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const trajectory = try rk4Integrate(freeGeodesicRhs, 0, t_final, y0, n_steps, arena.allocator());
    const rk4_result = trajectory[n_steps];
    const exact_result = geodesicExact(p, v, t_final);

    // RK4 должен быть близок к точному решению
    const rk4_pos = rk4_result.pos();
    try std.testing.expectApproxEqAbs(rk4_pos.x, exact_result.x, 1e-6);
    try std.testing.expectApproxEqAbs(rk4_pos.y, exact_result.y, 1e-6);
    try std.testing.expectApproxEqAbs(rk4_pos.z, exact_result.z, 1e-6);
    try std.testing.expectApproxEqAbs(rk4_pos.w, exact_result.w, 1e-6);
}

test "Geodesic: parallel transport preserves norm" {
    const p = HomVec4.init(1, 0, 0, 0);
    const v = HomVec4.init(0, 1, 0, 0);
    const w = HomVec4.init(0, 0, 1, 0); // ⟂ p, ⟂ v

    const t = math.pi / 3.0;
    const w_transported = parallelTransport(p, v, w, t);

    // Параллельный перенос сохраняет норму
    try std.testing.expectApproxEqAbs(w_transported.norm(), w.norm(), 1e-10);

    // w ⟂ p и w ⟂ v → P_t(w) = w (не меняется)
    try std.testing.expectApproxEqAbs(w_transported.x, w.x, 1e-10);
    try std.testing.expectApproxEqAbs(w_transported.y, w.y, 1e-10);
    try std.testing.expectApproxEqAbs(w_transported.z, w.z, 1e-10);
    try std.testing.expectApproxEqAbs(w_transported.w, w.w, 1e-10);
}

test "Geodesic: exp/log round-trip" {
    const p = HomVec4.init(1, 0, 0, 0);
    const q = HomVec4.init(0, 1, 0, 0); // На расстоянии π/2

    const v = logMap(p, q);
    const q_back = expMap(p, v);

    // exp_p(log_p(q)) ≈ q
    try std.testing.expectApproxEqAbs(q_back.x, q.x, 1e-6);
    try std.testing.expectApproxEqAbs(q_back.y, q.y, 1e-6);
}

test "Geodesic: renormalize on S³" {
    // «Сбитое» состояние — не на S³
    const bad_state = GeodesicState.init(
        .{ 1.01, 0.02, 0.01, 0.01 },
        .{ 0.0, 1.0, 0.0, 0.0 },
    );
    const fixed = renormalizeOnS3(bad_state);

    // После ренормализации: ‖q‖ = 1
    const q = fixed.pos();
    try std.testing.expectApproxEqAbs(q.norm(), 1.0, 1e-10);

    // v ⟂ q
    const v = fixed.vel();
    try std.testing.expectApproxEqAbs(HomVec4.dot(q, v), 0.0, 1e-10);
}
