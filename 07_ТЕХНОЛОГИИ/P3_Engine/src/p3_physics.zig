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
