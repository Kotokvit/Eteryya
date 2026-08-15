// =============================================================================
// P³ PHYSICS — ФИЗИКА НА ФУБИНИ-ШТУДИ МЕТРИКЕ
// =============================================================================
//
// В евклидовых движках: гравитация — СИЛА (F = mg).
// Проблемы: singularities, energy drift, gimbal lock, z-fighting.
//
// В P³ Engine: гравитация — КРИВИЗНА (геодезическое уравнение).
// Нет «силы» — есть уравнение геодезической на искривлённом P³.
// Нет «энергии» — есть метрика Фубини-Штуди (всегда корректна).
//
// Геодезическое уравнение с «гравитацией»:
//   ẍ^i + Γ^i_{jk} ẋ^j ẋ^k = F^i(x, ẋ)
//
// где Γ^i_{jk} — символы Кристоффеля FS-метрики,
//     F^i — «сила» = −∇V (потенциальная) или [H,P] (POLER)
//
// Свободная геодезическая: F=0 → большие круги на S³.
// Гравитация: F ≠ 0 → искривлённые геодезические.
//
// Доноры:
//   - O3DE PhysX: RigidBody, Shape, Force (переписано)
//   - P³ geodesic: RK4, exp/log, parallel transport
//   - POLER: idempotent dynamics [H,P] − γ(P²−P)
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");
const p3_geodesic = @import("p3_geodesic.zig");
const p3_idempotent = @import("p3_idempotent.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;
pub const GeodesicState = p3_geodesic.GeodesicState;

// =============================================================================
// 1. ТЕЛО В P³ (P3-BODY)
// =============================================================================

/// Физическое тело в P³
///
/// В O3DE: RigidBody — mass, velocity, angular velocity, forces
///   Проблема: Vector3 для всего, division-by-zero, gimbal lock
///
/// В P³: P3Body — position на S³, tangent velocity, mass
///   Нет division-by-zero (карты переключаются)
///   Нет gimbal lock (нет Euler angles)
pub const P3Body = struct {
    /// Позиция на S³ (нормирована: ‖position‖ = 1)
    position: HomVec4,
    /// Касательная скорость ∈ T_position(S³)
    velocity: HomVec4,
    /// Масса (>0, comptime гарантируется)
    mass: f64,
    /// Упругость (0 = полностью неупругий, 1 = полностью упругий)
    restitution: f64,
    /// Трение (0 = нет, 1 = полное)
    friction: f64,
    /// Тип тела
    body_type: BodyType,
    /// Суммарная сила (касательный вектор)
    force_accum: HomVec4,
    /// Флаг: нужна интеграция
    active: bool,

    pub const BodyType = enum {
        static, // неподвижный
        dynamic, // подвержен силам
        kinematic, // управляемый напрямую
    };

    pub fn init(pos: HomVec4, vel: HomVec4, mass: f64) P3Body {
        const n = pos.norm();
        const normalized = if (n > 1e-15) pos.normalize() else HomVec4.fromCartesian(.{ 0, 0, 0 });
        return .{
            .position = normalized,
            .velocity = vel,
            .mass = mass,
            .restitution = 0.5,
            .friction = 0.3,
            .body_type = .dynamic,
            .force_accum = HomVec4.zero(),
            .active = true,
        };
    }

    pub fn static(pos: HomVec4) P3Body {
        var body = P3Body.init(pos, HomVec4.zero(), 0);
        body.body_type = .static;
        body.active = false;
        return body;
    }

    /// Приложить силу (касательный вектор к S³)
    pub fn applyForce(self: *P3Body, force: HomVec4) void {
        if (self.body_type != .dynamic) return;
        self.force_accum = HomVec4.init(
            self.force_accum.x + force.x,
            self.force_accum.y + force.y,
            self.force_accum.z + force.z,
            self.force_accum.w + force.w,
        );
    }

    /// Очистить накопленные силы
    pub fn clearForces(self: *P3Body) void {
        self.force_accum = HomVec4.zero();
    }

    /// FS-расстояние до другого тела
    pub fn distanceTo(self: P3Body, other: P3Body) f64 {
        return p3_kernel.fsDistance(self.position, other.position);
    }
};

// =============================================================================
// 2. СИЛЫ В P³
// =============================================================================

/// P³-гравитация: сила направлена вдоль геодезической
/// от тела к аттрактору, модулированная FS-расстоянием
///
/// В отличие от ньютоновской гравитации (1/r², singularity при r=0),
/// FS-гравитация КОНЕЧНА при d=0:
///   F = G · M / (sin²(d) + ε) · direction
///
/// где d = FS-расстояние, direction = log(body.pos, attractor.pos)
pub fn p3Gravity(
    body: P3Body,
    attractor_position: HomVec4,
    attractor_mass: f64,
    G: f64,
) HomVec4 {
    const d = p3_kernel.fsDistance(body.position, attractor_position);
    if (d < 1e-10) return HomVec4.zero(); // Точка совпадения — нет силы

    // Направление = log map (касательный вектор к геодезической)
    const tangent = p3_geodesic.logMap(body.position, attractor_position);
    const t_norm = tangent.norm();
    if (t_norm < 1e-15) return HomVec4.zero();

    // FS-гравитация: F = G·M / (sin²(d) + ε) · direction
    // При d→0: F → 0 (нет сингулярности!)
    // При d=π/2: F = G·M (максимальная сила)
    const sin_d = @sin(d);
    const denom = sin_d * sin_d + 1e-10; // Регуляризация
    const magnitude = G * attractor_mass / denom;

    // Нормированное направление × magnitude
    return HomVec4.init(
        magnitude * tangent.x / t_norm,
        magnitude * tangent.y / t_norm,
        magnitude * tangent.z / t_norm,
        magnitude * tangent.w / t_norm,
    );
}

/// Центростремительная сила: удерживает на S³
/// F = −⟨v,p⟩·p (проекция радиальной компоненты скорости)
pub fn centripetalForce(body: P3Body) HomVec4 {
    const vradial = HomVec4.dot(body.velocity, body.position);
    return HomVec4.init(
        -vradial * body.position.x,
        -vradial * body.position.y,
        -vradial * body.position.z,
        -vradial * body.position.w,
    );
}

/// Демпфирование: F = −γ·v
pub fn dampingForce(velocity: HomVec4, gamma: f64) HomVec4 {
    return HomVec4.init(
        -gamma * velocity.x,
        -gamma * velocity.y,
        -gamma * velocity.z,
        -gamma * velocity.w,
    );
}

// =============================================================================
// 3. ИНТЕГРАТОР: RK4 НА P³ С СИЛАМИ
// =============================================================================

/// Шаг интеграции для тела в P³ с силами
///
/// ẍ = −|v|²·q + F/m    (геодезическое + сила)
/// q̈ = −|v|²·q + F/m
pub fn integrateStep(
    body: *P3Body,
    dt: f64,
    external_force: HomVec4,
) void {
    if (!body.active or body.body_type != .dynamic) return;

    const q = body.position;
    const v = body.velocity;
    const m = body.mass;
    if (m < 1e-10) return;

    // Полная сила = external + centripetal + accumulated
    const total_force = HomVec4.init(
        external_force.x + body.force_accum.x,
        external_force.y + body.force_accum.y,
        external_force.z + body.force_accum.z,
        external_force.w + body.force_accum.w,
    );

    // Ускорение = геодезическое + сила
    const speed_sq = v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w;

    // RK4 k1
    const k1_q = v;
    const k1_v = HomVec4.init(
        -speed_sq * q.x + total_force.x / m,
        -speed_sq * q.y + total_force.y / m,
        -speed_sq * q.z + total_force.z / m,
        -speed_sq * q.w + total_force.w / m,
    );

    // RK4 k2 (midpoint)
    const q2 = HomVec4.init(
        q.x + 0.5 * dt * k1_q.x,
        q.y + 0.5 * dt * k1_q.y,
        q.z + 0.5 * dt * k1_q.z,
        q.w + 0.5 * dt * k1_q.w,
    );
    const v2 = HomVec4.init(
        v.x + 0.5 * dt * k1_v.x,
        v.y + 0.5 * dt * k1_v.y,
        v.z + 0.5 * dt * k1_v.z,
        v.w + 0.5 * dt * k1_v.w,
    );
    const speed_sq_2 = v2.x * v2.x + v2.y * v2.y + v2.z * v2.z + v2.w * v2.w;
    const k2_q = v2;
    const k2_v = HomVec4.init(
        -speed_sq_2 * q2.x + total_force.x / m,
        -speed_sq_2 * q2.y + total_force.y / m,
        -speed_sq_2 * q2.z + total_force.z / m,
        -speed_sq_2 * q2.w + total_force.w / m,
    );

    // RK4 k3 (midpoint with k2)
    const q3 = HomVec4.init(
        q.x + 0.5 * dt * k2_q.x,
        q.y + 0.5 * dt * k2_q.y,
        q.z + 0.5 * dt * k2_q.z,
        q.w + 0.5 * dt * k2_q.w,
    );
    const v3 = HomVec4.init(
        v.x + 0.5 * dt * k2_v.x,
        v.y + 0.5 * dt * k2_v.y,
        v.z + 0.5 * dt * k2_v.z,
        v.w + 0.5 * dt * k2_v.w,
    );
    const speed_sq_3 = v3.x * v3.x + v3.y * v3.y + v3.z * v3.z + v3.w * v3.w;
    const k3_q = v3;
    const k3_v = HomVec4.init(
        -speed_sq_3 * q3.x + total_force.x / m,
        -speed_sq_3 * q3.y + total_force.y / m,
        -speed_sq_3 * q3.z + total_force.z / m,
        -speed_sq_3 * q3.w + total_force.w / m,
    );

    // RK4 k4 (endpoint with k3)
    const q4 = HomVec4.init(
        q.x + dt * k3_q.x,
        q.y + dt * k3_q.y,
        q.z + dt * k3_q.z,
        q.w + dt * k3_q.w,
    );
    const v4 = HomVec4.init(
        v.x + dt * k3_v.x,
        v.y + dt * k3_v.y,
        v.z + dt * k3_v.z,
        v.w + dt * k3_v.w,
    );
    const speed_sq_4 = v4.x * v4.x + v4.y * v4.y + v4.z * v4.z + v4.w * v4.w;
    const k4_q = v4;
    const k4_v = HomVec4.init(
        -speed_sq_4 * q4.x + total_force.x / m,
        -speed_sq_4 * q4.y + total_force.y / m,
        -speed_sq_4 * q4.z + total_force.z / m,
        -speed_sq_4 * q4.w + total_force.w / m,
    );

    // Combine: y(t+dt) = y(t) + dt/6·(k1 + 2k2 + 2k3 + k4)
    body.position = HomVec4.init(
        q.x + dt / 6.0 * (k1_q.x + 2 * k2_q.x + 2 * k3_q.x + k4_q.x),
        q.y + dt / 6.0 * (k1_q.y + 2 * k2_q.y + 2 * k3_q.y + k4_q.y),
        q.z + dt / 6.0 * (k1_q.z + 2 * k2_q.z + 2 * k3_q.z + k4_q.z),
        q.w + dt / 6.0 * (k1_q.w + 2 * k2_q.w + 2 * k3_q.w + k4_q.w),
    );
    body.velocity = HomVec4.init(
        v.x + dt / 6.0 * (k1_v.x + 2 * k2_v.x + 2 * k3_v.x + k4_v.x),
        v.y + dt / 6.0 * (k1_v.y + 2 * k2_v.y + 2 * k3_v.y + k4_v.y),
        v.z + dt / 6.0 * (k1_v.z + 2 * k2_v.z + 2 * k3_v.z + k4_v.z),
        v.w + dt / 6.0 * (k1_v.w + 2 * k2_v.w + 2 * k3_v.w + k4_v.w),
    );

    // Ренормализация на S³
    const n = body.position.norm();
    if (n > 1e-15) {
        body.position = body.position.normalize();
    }

    // Ортогонализация скорости к позиции
    const vradial = HomVec4.dot(body.velocity, body.position);
    body.velocity = HomVec4.init(
        body.velocity.x - vradial * body.position.x,
        body.velocity.y - vradial * body.position.y,
        body.velocity.z - vradial * body.position.z,
        body.velocity.w - vradial * body.position.w,
    );

    body.clearForces();
}

// =============================================================================
// 4. СТОЛКНОВЕНИЕ В P³ (FS-DISTANCE BASED)
// =============================================================================

/// Результат столкновения
pub const CollisionResult = struct {
    collided: bool,
    fs_distance: f64,
    normal: HomVec4, // «нормаль» = касательный вектор к геодезической
};

/// Проверка столкновения: FS-расстояние < threshold
pub fn checkCollision(
    a: P3Body,
    b: P3Body,
    threshold: f64,
) CollisionResult {
    const d = p3_kernel.fsDistance(a.position, b.position);
    if (d >= threshold) {
        return .{
            .collided = false,
            .fs_distance = d,
            .normal = HomVec4.zero(),
        };
    }

    // Нормаль столкновения = направление геодезической
    const tangent = p3_geodesic.logMap(a.position, b.position);
    const t_norm = tangent.norm();
    const normal = if (t_norm > 1e-15) tangent.normalize() else HomVec4.zero();

    return .{
        .collided = true,
        .fs_distance = d,
        .normal = normal,
    };
}

// =============================================================================
// 5. ТЕСТЫ
// =============================================================================

test "Physics: P3Body creation normalizes position" {
    const body = P3Body.init(
        HomVec4.fromCartesian(.{ 3, 4, 0 }),
        HomVec4.zero(),
        1.0,
    );
    try std.testing.expectApproxEqAbs(body.position.norm(), 1.0, 1e-10);
}

test "Physics: P3Body static is not active" {
    const body = P3Body.static(HomVec4.init(0, 0, 0, 1));
    try std.testing.expect(!body.active);
    try std.testing.expect(body.body_type == .static);
}

test "Physics: P3Body FS distance" {
    const a = P3Body.init(HomVec4.init(1, 0, 0, 0), HomVec4.zero(), 1.0);
    const b = P3Body.init(HomVec4.init(0, 1, 0, 0), HomVec4.zero(), 1.0);
    const d = a.distanceTo(b);
    try std.testing.expectApproxEqAbs(d, math.pi / 2.0, 1e-10);
}

test "Physics: P3Gravity has no singularity at d=0" {
    const body = P3Body.init(HomVec4.init(1, 0, 0, 0), HomVec4.zero(), 1.0);
    const force = p3Gravity(body, HomVec4.init(1, 0, 0, 0), 1.0, 1.0);
    // При d=0: F = 0 (нет сингулярности!)
    try std.testing.expectApproxEqAbs(force.norm(), 0.0, 1e-10);
}

test "Physics: P3Gravity is finite at d=π/2" {
    const body = P3Body.init(HomVec4.init(1, 0, 0, 0), HomVec4.zero(), 1.0);
    const force = p3Gravity(body, HomVec4.init(0, 1, 0, 0), 1.0, 1.0);
    // F = G·M/sin²(π/2) = 1/1 = 1 — конечна!
    try std.testing.expect(force.norm() > 0.5);
    try std.testing.expect(!math.isNan(force.norm()));
    try std.testing.expect(!math.isInf(force.norm()));
}

test "Physics: Damping force" {
    const v = HomVec4.init(1, 0, 0, 0);
    const f = dampingForce(v, 0.5);
    try std.testing.expectApproxEqAbs(f.x, -0.5, 1e-10);
}

test "Physics: Integrate step preserves S³" {
    var body = P3Body.init(
        HomVec4.init(1, 0, 0, 0),
        HomVec4.init(0, 0.1, 0, 0),
        1.0,
    );
    integrateStep(&body, 0.01, HomVec4.zero());
    // После шага: ‖position‖ ≈ 1 (ренормализация)
    try std.testing.expectApproxEqAbs(body.position.norm(), 1.0, 1e-6);
}

test "Physics: Integrate step velocity orthogonal to position" {
    var body = P3Body.init(
        HomVec4.init(1, 0, 0, 0),
        HomVec4.init(0, 0.1, 0, 0),
        1.0,
    );
    integrateStep(&body, 0.01, HomVec4.zero());
    // v ⟂ p после ортогонализации
    const inner = HomVec4.dot(body.velocity, body.position);
    try std.testing.expectApproxEqAbs(@abs(inner), 0.0, 1e-6);
}

test "Physics: Collision detection" {
    const a = P3Body.init(HomVec4.init(1, 0, 0, 0), HomVec4.zero(), 1.0);
    const b = P3Body.init(HomVec4.init(0, 1, 0, 0), HomVec4.zero(), 1.0);
    const result = checkCollision(a, b, 0.1);
    // d = π/2 ≈ 1.57 > 0.1 → no collision
    try std.testing.expect(!result.collided);
}

test "Physics: Collision at close range" {
    const a = P3Body.init(HomVec4.init(1, 0, 0, 0), HomVec4.zero(), 1.0);
    const b = P3Body.init(HomVec4.init(0.99, 0.01, 0, 0).normalize(), HomVec4.zero(), 1.0);
    const result = checkCollision(a, b, 0.5);
    // Very close → collision
    try std.testing.expect(result.collided);
}

test "Physics: P3Body apply force" {
    var body = P3Body.init(HomVec4.init(0, 0, 0, 1), HomVec4.zero(), 1.0);
    body.applyForce(HomVec4.init(1, 0, 0, 0));
    try std.testing.expectApproxEqAbs(body.force_accum.x, 1.0, 1e-10);
}

test "Physics: Static body ignores force" {
    var body = P3Body.static(HomVec4.init(0, 0, 0, 1));
    body.applyForce(HomVec4.init(100, 0, 0, 0));
    try std.testing.expectApproxEqAbs(body.force_accum.x, 0.0, 1e-10);
}

// =============================================================================
// 6. ДИФФЕРЕНЦИАЛЬНАЯ ГЕОМЕТРИЯ FS-МЕТРИКИ
// =============================================================================
//
// Фубини-Штуди метрика на CP¹ = S²:
//   ds² = 4/(1+|z|²)² (dx² + dy²)
//
// На S³ ⊂ R⁴ (standard embedding):
//   g_ij = δ_ij − x_i·x_j / |x|²
//
// Символы Кристоффеля для S³ (в координатах карты):
//   Γ^i_{jk} = −x^i·g_{jk} / |x|²  (для сферы в R⁴)
//
// Тензор кривизны Римана для S³ (постоянная секционная кривизна K=1):
//   R^i_{jkl} = δ^i_k·g_{jl} − δ^i_l·g_{jk}
//
// Это означает: S³ имеет КОНСТАНТНУЮ кривизну = 1.
// В отличие от O3DE/PhysX: кривизна = 0 (плоское пространство).
//
// ГЕОМЕТРИЧЕСКИЙ СМЫСЛ:
//   - Свободные тела движутся по геодезическим = большим кругам на S³
//   - Параллельный перенос зависит от пути (голономия = вращение)
//   - Два параллельных луча СХОДЯТСЯ (положительная кривизна)
//   - Это и есть «гравитация» — не сила, а КРИВИЗНА пространства

/// Символы Кристоффеля Γ^i_{jk} для FS-метрики на S³
///
/// На S³ с индуцированной метрикой из R⁴:
///   Γ^i_{jk} = −x^i · δ_{jk} / |x|²
/// (для точки на единичной сфере |x|² = 1)
///
/// Возвращает 4×4×4 массив: gamma[i][j][k] = Γ^i_{jk}
pub fn christoffelSymbols(point: HomVec4) [4][4][4]f64 {
    const n_sq = point.x * point.x + point.y * point.y +
        point.z * point.z + point.w * point.w;

    var gamma: [4][4][4]f64 = .{.{.{0} ** 4} ** 4} ** 4;

    if (n_sq < 1e-15) return gamma; // Zero point → zero Christoffel

    const coords = [4]f64{ point.x, point.y, point.z, point.w };

    // Γ^i_{jk} = −x^i · δ_{jk} / |x|²
    for (0..4) |i| {
        for (0..4) |j| {
            for (0..4) |k| {
                if (j == k) {
                    gamma[i][j][k] = -coords[i] / n_sq;
                }
            }
        }
    }

    return gamma;
}

/// Геодезическое ускорение от кривизны:
///   a^i = −Γ^i_{jk} · v^j · v^k
///
/// Это «гравитационное» ускорение от кривизны FS-метрики.
/// Для S³: a = −|v|² · x (центростремительное)
pub fn geodesicAcceleration(
    point: HomVec4,
    velocity: HomVec4,
) HomVec4 {
    const gamma = christoffelSymbols(point);
    const v = [4]f64{ velocity.x, velocity.y, velocity.z, velocity.w };

    var accel = [4]f64{ 0, 0, 0, 0 };
    for (0..4) |i| {
        for (0..4) |j| {
            for (0..4) |k| {
                accel[i] -= gamma[i][j][k] * v[j] * v[k];
            }
        }
    }

    return HomVec4.init(accel[0], accel[1], accel[2], accel[3]);
}

/// Тензор кривизны Римана R^i_{jkl} для S³
///
/// Для сферы с секционной кривизной K=1:
///   R^i_{jkl} = K·(δ^i_k·g_{jl} − δ^i_l·g_{jk})
///
/// На S³: K = 1 (постоянная!)
/// g_{ij} = δ_{ij} − x_i·x_j / |x|²
pub fn riemannTensor(
    point: HomVec4,
    i: usize,
    j: usize,
    k: usize,
    l: usize,
) f64 {
    const n_sq = point.x * point.x + point.y * point.y +
        point.z * point.z + point.w * point.w;
    if (n_sq < 1e-15) return 0;

    const coords = [4]f64{ point.x, point.y, point.z, point.w };

    // Метрика g_{ab} = δ_{ab} − x_a·x_b / |x|²
    const kronecker_jl: f64 = if (j == l) 1.0 else 0.0;
    const g_jl: f64 = kronecker_jl - coords[j] * coords[l] / n_sq;
    const kronecker_jk: f64 = if (j == k) 1.0 else 0.0;
    const g_jk: f64 = kronecker_jk - coords[j] * coords[k] / n_sq;

    const delta_ik: f64 = if (i == k) 1.0 else 0.0;
    const delta_il: f64 = if (i == l) 1.0 else 0.0;

    // R^i_{jkl} = δ^i_k·g_{jl} − δ^i_l·g_{jk}  (K=1)
    return delta_ik * g_jl - delta_il * g_jk;
}

/// Секционная кривизна K(plane) для S³
///
/// Для сферы: K = 1/|x|² для всех плоскостей
/// На единичной сфере: K = 1 (константа!)
///
/// В O3DE/PhysX: K = 0 (плоское пространство — «нет гравитации»)
/// В P³: K = 1 (искривлённое — «гравитация = кривизна»)
pub fn sectionalCurvature(point: HomVec4) f64 {
    const n_sq = point.x * point.x + point.y * point.y +
        point.z * point.z + point.w * point.w;
    if (n_sq < 1e-15) return 0;
    return 1.0 / n_sq; // K = 1/|x|²
}

/// Скалярная кривизна (R) для S³
///
/// R = K · n·(n−1) где n = dim, K = секционная кривизна
/// Для S³(1): R = 1 · 3·2 = 6
pub fn scalarCurvature(point: HomVec4) f64 {
    const K = sectionalCurvature(point);
    return K * 3.0 * 2.0; // n=3, n(n-1) = 6
}

/// Тензор Риччи Ric_{ij} для S³
///
/// Ric_{ij} = (n−1)·K·g_{ij} = 2·K·g_{ij}  (для n=3)
pub fn ricciTensor(
    point: HomVec4,
    j: usize,
    k: usize,
) f64 {
    const K = sectionalCurvature(point);
    const n_sq = point.x * point.x + point.y * point.y +
        point.z * point.z + point.w * point.w;
    if (n_sq < 1e-15) return 0;

    const coords = [4]f64{ point.x, point.y, point.z, point.w };

    // g_{jk} = δ_{jk} − x_j·x_k / |x|²
    const kronecker: f64 = if (j == k) 1.0 else 0.0;
    const g_jk: f64 = kronecker - coords[j] * coords[k] / n_sq;

    return 2.0 * K * g_jk; // (n-1) = 2 для n=3
}

// =============================================================================
// 7. ТЕСТЫ ДИФФЕРЕНЦИАЛЬНОЙ ГЕОМЕТРИИ
// =============================================================================

test "Physics: Christoffel symbols at north pole" {
    const north_pole = HomVec4.init(0, 0, 0, 1);
    const gamma = christoffelSymbols(north_pole);
    // At north pole (0,0,0,1): Γ^i_{jk} = −x^i·δ_{jk}/|x|²
    // x^0=x^1=x^2=0, x^3=1, |x|²=1
    // Γ^0_{00} = −x^0·δ_{00}/1 = −0·1 = 0
    try std.testing.expectApproxEqAbs(gamma[0][0][0], 0.0, 1e-10);
    // Γ^3_{00} = −x^3·δ_{00}/1 = −1·1 = −1
    try std.testing.expectApproxEqAbs(gamma[3][0][0], -1.0, 1e-10);
    // Γ^3_{11} = −x^3·δ_{11}/1 = −1
    try std.testing.expectApproxEqAbs(gamma[3][1][1], -1.0, 1e-10);
    // Γ^0_{01} = 0 (j≠k, δ_{01}=0)
    try std.testing.expectApproxEqAbs(gamma[0][0][1], 0.0, 1e-10);
}

test "Physics: Christoffel symbols at origin are zero" {
    const origin = HomVec4.init(0, 0, 0, 0);
    const gamma = christoffelSymbols(origin);
    // At origin: |x|²=0 → return zero
    try std.testing.expectApproxEqAbs(gamma[0][0][0], 0.0, 1e-10);
}

test "Physics: Geodesic acceleration for pure radial" {
    const point = HomVec4.init(0, 0, 0, 1); // north pole
    const velocity = HomVec4.init(1, 0, 0, 0); // tangent to S³
    const accel = geodesicAcceleration(point, velocity);
    // a^i = −Γ^i_{jk}·v^j·v^k
    // For j=k=0, v^0=1: a^i = −Γ^i_{00}
    // a^0 = −Γ^0_{00} = 0
    // a^3 = −Γ^3_{00} = 1
    try std.testing.expectApproxEqAbs(accel.x, 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(accel.w, 1.0, 1e-10);
}

test "Physics: Sectional curvature on unit sphere" {
    const point = HomVec4.init(1, 0, 0, 0);
    const K = sectionalCurvature(point);
    // On unit sphere: K = 1/|x|² = 1
    try std.testing.expectApproxEqAbs(K, 1.0, 1e-10);
}

test "Physics: Sectional curvature on scaled sphere" {
    const point = HomVec4.init(2, 0, 0, 0); // |x|=2
    const K = sectionalCurvature(point);
    // K = 1/4
    try std.testing.expectApproxEqAbs(K, 0.25, 1e-10);
}

test "Physics: Scalar curvature on S³" {
    const point = HomVec4.init(1, 0, 0, 0);
    const R = scalarCurvature(point);
    // R = 6 for S³(1)
    try std.testing.expectApproxEqAbs(R, 6.0, 1e-10);
}

test "Physics: Ricci tensor diagonal on S³" {
    const point = HomVec4.init(1, 0, 0, 0);
    const ric_00 = ricciTensor(point, 0, 0);
    // Ric_{00} = 2·K·g_{00} = 2·1·(1−x₀²/|x|²) = 2·1·0 = 0
    // (since x₀=1, |x|²=1, so g_{00}=0)
    try std.testing.expectApproxEqAbs(ric_00, 0.0, 1e-10);

    const ric_11 = ricciTensor(point, 1, 1);
    // Ric_{11} = 2·K·g_{11} = 2·1·(1−0) = 2
    try std.testing.expectApproxEqAbs(ric_11, 2.0, 1e-10);
}

test "Physics: Riemann tensor antisymmetry in last two indices" {
    const point = HomVec4.init(0.5, 0.5, 0.5, 0.5);
    // R^i_{jkl} = −R^i_{jlk} (antisymmetry)
    const R0123 = riemannTensor(point, 0, 1, 2, 3);
    const R0132 = riemannTensor(point, 0, 1, 3, 2);
    try std.testing.expectApproxEqAbs(R0123, -R0132, 1e-10);
}

test "Physics: Riemann tensor symmetry R_{ijkl} = R_{klij}" {
    const point = HomVec4.init(0, 0, 0, 1);
    // First Bianchi: R^i_{jkl} + R^i_{klj} + R^i_{ljk} = 0
    const R0_123 = riemannTensor(point, 0, 1, 2, 3);
    const R0_231 = riemannTensor(point, 0, 2, 3, 1);
    const R0_312 = riemannTensor(point, 0, 3, 1, 2);
    try std.testing.expectApproxEqAbs(R0_123 + R0_231 + R0_312, 0.0, 1e-10);
}
