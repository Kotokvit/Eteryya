// =============================================================================
// P³ IDEMPOTENT ALGEBRA — АЛГЕБРА ИДЕМПОТЕНТОВ (АРХЕТИПОВ)
// =============================================================================
//
// Философия: "Всё есть наблюдатель, всё есть архетип."
// Алгебраически: P² = P (идемпотентный проектор).
//
// В проективной геометрии каждый архетип — это подпространство,
// выделяемое идемпотентным оператором. Два ортогональных идемпотента
// P, Q с P+Q = I дают прямое разложение V = im(P) ⊕ im(Q).
//
// Доноры:
//   - POLER Eq.1 (J=A−Aᵀ), Eq.8 (Π_Λ = I − Jcᵀ(Jc·Jcᵀ+δI)⁻¹Jc)
//   - Von Neumann: спектральное разложение P = Σ λᵢEᵢ
//   - zmath/zm: структура матричных операций (переписано)
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================
//
// ОПРЕДЕЛЕНИЯ:
//
// 1. Идемпотент: P ∈ End(V) такой что P² = P.
//    Спектр: σ(P) ⊆ {0, 1}.
//    rank(P) = tr(P).
//    im(P) = eigenspace(1), ker(P) = eigenspace(0).
//
// 2. Ортогональные идемпотенты: P·Q = Q·P = 0.
//    Тогда P+Q тоже идемпотент, rank(P+Q) = rank(P) + rank(Q).
//
// 3. Полное разложение: если P₁+...+Pₖ = I и Pᵢ·Pⱼ = δᵢⱼ·Pᵢ,
//    то V = ⊕ᵢ im(Pᵢ) — прямая сумма архетипов.
//
// 4. Спектральный проектор: для A ∈ End(V) с собственными значениями λᵢ,
//    Eᵢ = ∏_{j≠i} (A−λⱼI)/(λᵢ−λⱼ) — проектор на eigenspace(λᵢ).
//
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. ИДЕМПОТЕНТНАЯ ПРОВЕРКА И КЛАССИФИКАЦИЯ
// =============================================================================

/// Проверка идемпотентности: ‖P² − P‖ < tol
/// P² = P ↔ P — проектор (архетип).
pub fn isIdempotent(p: PGL4, tol: f64) bool {
    const p2 = PGL4.mul(p, p);
    return residualNorm(p2, p) < tol;
}

/// Невязка идемпотентности: ‖P² − P‖_max
/// Чем меньше, тем ближе к истинному идемпотенту.
pub fn idempotencyResidual(p: PGL4) f64 {
    const p2 = PGL4.mul(p, p);
    return residualNorm(p2, p);
}

/// Ранг идемпотента = tr(P).
/// Для P² = P: rank(P) = tr(P) ∈ {0, 1, 2, 3, 4}.
/// Целочисленный ранг для истинного идемпотента.
pub fn idempotentRank(p: PGL4) f64 {
    return trace(p);
}

/// Целочисленный ранг (округление tr(P) к ближайшему целому).
pub fn idempotentRankInt(p: PGL4) u32 {
    const t = trace(p);
    return @intFromFloat(@round(t));
}

/// Классификация идемпотента по рангу:
///   rank 0: нулевой проектор (нет архетипа)
///   rank 1: точка в P³ (один наблюдатель)
///   rank 2: прямая в P³ (пара наблюдателей)
///   rank 3: плоскость в P³ (три наблюдателя)
///   rank 4: тождественный (все наблюдатели = вся реальность)
pub const ArchetypeKind = enum(u3) {
    Null = 0, // rank 0
    Point = 1, // rank 1
    Line = 2, // rank 2
    Plane = 3, // rank 3
    Identity = 4, // rank 4
};

pub fn classifyArchetype(p: PGL4) ArchetypeKind {
    const r = idempotentRankInt(p);
    return switch (r) {
        0 => .Null,
        1 => .Point,
        2 => .Line,
        3 => .Plane,
        4 => .Identity,
        else => .Null, // не идемпотент
    };
}

// =============================================================================
// 2. ОРТОГОНАЛЬНЫЕ ИДЕМПОТЕНТЫ
// =============================================================================

/// Проверка ортогональности: P·Q ≈ 0 и Q·P ≈ 0
/// Ортогональные идемпотенты → независимые архетипы (наблюдатели).
pub fn areOrthogonal(p: PGL4, q: PGL4, tol: f64) bool {
    const pq = PGL4.mul(p, q);
    const qp = PGL4.mul(q, p);
    return residualNorm(pq, PGL4.identity().scale(0)) < tol and
        residualNorm(qp, PGL4.identity().scale(0)) < tol;
}

/// Проверка полноты: P₁ + P₂ + ... + Pₖ = I
/// Полный набор ортогональных идемпотентов = полная декомпозиция реальности.
pub fn isCompleteSet(projectors: []const PGL4, tol: f64) bool {
    if (projectors.len == 0) return false;
    var sum = projectors[0];
    for (1..projectors.len) |i| {
        sum = sum.add(projectors[i]);
    }
    return residualNorm(sum, PGL4.identity()) < tol;
}

/// Проектор на подпространство: P = V · (Vᵀ·V)⁻¹ · Vᵀ
/// где V — матрица, столбцы которой = базис подпространства.
/// Даёт ортогональный проектор на span(столбцы V).
pub fn orthogonalProjector(v: PGL4, delta: f64) PGL4 {
    const vt = v.transpose();
    const vtv = PGL4.mul(vt, v);
    // Регуляризация и обращение
    var vtv_reg = vtv;
    for (0..4) |i| {
        vtv_reg.set(i, i, vtv_reg.get(i, i) + delta);
    }
    const vtv_inv = vtv_reg.inverse(delta, 12);
    // P = V · (VᵀV)⁻¹ · Vᵀ
    return PGL4.mul(PGL4.mul(v, vtv_inv), vt);
}

/// Ортогональное дополнение: Q = I − P
/// Если P — проектор, то Q тоже проектор, P·Q = 0, im(Q) = ker(P).
pub fn complement(p: PGL4) PGL4 {
    const I4 = PGL4.identity();
    var result = I4;
    for (0..16) |i| {
        result.data[i] -= p.data[i];
    }
    return result;
}

// =============================================================================
// 3. СПЕКТРАЛЬНОЕ РАЗЛОЖЕНИЕ
// =============================================================================
//
// Для матрицы A с простым спектром {λ₁, λ₂, λ₃, λ₄}:
//   A = λ₁E₁ + λ₂E₂ + λ₃E₃ + λ₄E₄
// где Eᵢ — спектральные проекторы (идемпотенты).
//
// Eᵢ = ∏_{j≠i} (A − λⱼI) / (λᵢ − λⱼ)
//
// Это фундаментальная теорема: каждая матрица = сумма своих архетипов,
// взвешенных собственными значениями.

/// Спектральный проектор для собственного значения λᵢ:
/// Eᵢ = ∏_{j≠i} (A − λⱼI) / (λᵢ − λⱼ)
/// Работает для простого спектра (все λ различны).
pub fn spectralProjector(a: PGL4, lambda_i: f64, other_lambdas: []const f64) PGL4 {
    const I4 = PGL4.identity();
    var product = I4;

    for (other_lambdas) |lambda_j| {
        // (A − λⱼI) / (λᵢ − λⱼ)
        var factor = a;
        const scale = 1.0 / (lambda_i - lambda_j);
        for (0..16) |k| {
            factor.data[k] = (factor.data[k] - I4.data[k] * lambda_j) * scale;
        }
        product = PGL4.mul(product, factor);
    }
    return product;
}

/// Полное спектральное разложение A = Σ λᵢEᵢ
/// Возвращает массив пар (λᵢ, Eᵢ).
pub const SpectralComponent = struct {
    eigenvalue: f64,
    projector: PGL4,
};

pub fn spectralDecomposition(a: PGL4, eigenvalues: []const f64, allocator: std.mem.Allocator) ![]SpectralComponent {
    const n = eigenvalues.len;
    const components = try allocator.alloc(SpectralComponent, n);

    for (0..n) |i| {
        // Собираем все λⱼ, j ≠ i
        const others = try allocator.alloc(f64, n - 1);
        var idx: usize = 0;
        for (0..n) |j| {
            if (j != i) {
                others[idx] = eigenvalues[j];
                idx += 1;
            }
        }
        components[i] = .{
            .eigenvalue = eigenvalues[i],
            .projector = spectralProjector(a, eigenvalues[i], others),
        };
        allocator.free(others);
    }
    return components;
}

/// Восстановление из спектрального разложения: A = Σ λᵢEᵢ
pub fn reconstructFromSpectral(components: []const SpectralComponent) PGL4 {
    var result = PGL4.identity().scale(0);
    for (components) |comp| {
        var weighted = comp.projector;
        for (0..16) |i| {
            weighted.data[i] *= comp.eigenvalue;
        }
        for (0..16) |i| {
            result.data[i] += weighted.data[i];
        }
    }
    return result;
}

// =============================================================================
// 4. ИДЕМПОТЕНТНАЯ ДИНАМИКА (POLER-СВЯЗЬ)
// =============================================================================
//
// В POLER-формализме динамика идемпотентов:
//   dP/dt = [H, P] + F(P)
// где [H, P] = HP − PH — коммутатор (гамильтонова часть),
//     F(P) — диссипативная часть, приводящая к P² = P.
//
// Стационарное состояние: [H, P] = 0 → P — интеграл движения.
// Это и есть «архетип = наблюдатель»: идемпотент, коммутирующий с
// гамильтонианом, выделяет сохраняющуюся структуру.

/// Коммутатор [A, B] = A·B − B·A
/// Мера некоммутативности двух операторов.
/// [A,B] = 0 ↔ A и B одновременно диагонализуемы (одни архетипы).
pub fn commutator(a: PGL4, b: PGL4) PGL4 {
    const ab = PGL4.mul(a, b);
    const ba = PGL4.mul(b, a);
    var result: PGL4 = undefined;
    for (0..16) |i| {
        result.data[i] = ab.data[i] - ba.data[i];
    }
    return result;
}

/// Идемпотентная динамика: dP/dt = [H, P] − γ·(P² − P)
/// γ > 0: диссипация, загоняющая P → идемпотент.
/// γ = 0: чисто гамильтонова, P не обязателен идемпотент.
/// Правый член: P²−P = 0 когда P²=P, поэтому диссипация
/// «подтягивает» P к идемпотенту (архетипу).
pub fn idempotentDynamics(h: PGL4, p: PGL4, gamma: f64) PGL4 {
    const hamiltonian_part = commutator(h, p);
    const p2 = PGL4.mul(p, p);
    // P² − P (обнуляется когда P² = P)
    var dissipation: PGL4 = undefined;
    for (0..16) |i| {
        dissipation.data[i] = gamma * (p2.data[i] - p.data[i]);
    }
    // dP/dt = [H,P] − γ(P²−P)
    var result: PGL4 = undefined;
    for (0..16) |i| {
        result.data[i] = hamiltonian_part.data[i] - dissipation.data[i];
    }
    return result;
}

/// Проекция на идемпотентное многообразие:
/// P_proj = P² (один шаг Newton для P²−P=0).
/// Итерация: P_{k+1} = 3P_k² − 2P_k³ (Newton для идемпотентов).
pub fn newtonIdempotentStep(p: PGL4) PGL4 {
    const p2 = PGL4.mul(p, p);
    const p3 = PGL4.mul(p2, p);
    // 3P² − 2P³
    var result: PGL4 = undefined;
    for (0..16) |i| {
        result.data[i] = 3.0 * p2.data[i] - 2.0 * p3.data[i];
    }
    return result;
}

/// Итеративная проекция на идемпотент: Newton до сходимости.
pub fn projectToIdempotent(p: PGL4, max_iter: u32, tol: f64) PGL4 {
    var current = p;
    for (0..max_iter) |_| {
        if (isIdempotent(current, tol)) return current;
        current = newtonIdempotentStep(current);
    }
    return current;
}

// =============================================================================
// 5. ВНУТРЕННИЕ ПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// =============================================================================

/// След матрицы: tr(M) = Σ Mᵢᵢ
fn trace(m: PGL4) f64 {
    var sum: f64 = 0;
    for (0..4) |i| {
        sum += m.get(i, i);
    }
    return sum;
}

/// Макс-норма невязки: ‖A − B‖_max = max|Aᵢⱼ − Bᵢⱼ|
fn residualNorm(a: PGL4, b: PGL4) f64 {
    var max_val: f64 = 0;
    for (0..16) |i| {
        max_val = @max(max_val, @abs(a.data[i] - b.data[i]));
    }
    return max_val;
}

// =============================================================================
// 6. ТЕСТЫ
// =============================================================================

test "Idempotent: orthogonal projector P² = P" {
    // Проектор на первую координату: P = diag(1,0,0,0)
    const p = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    try std.testing.expect(isIdempotent(p, 1e-10));
    try std.testing.expect(idempotentRankInt(p) == 1);
    try std.testing.expect(classifyArchetype(p) == .Point);
}

test "Idempotent: rank-2 projector (Line archetype)" {
    // Проектор на первые две координаты
    const p = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    try std.testing.expect(isIdempotent(p, 1e-10));
    try std.testing.expect(idempotentRankInt(p) == 2);
    try std.testing.expect(classifyArchetype(p) == .Line);
}

test "Idempotent: I is idempotent (Identity archetype)" {
    const I4 = PGL4.identity();
    try std.testing.expect(isIdempotent(I4, 1e-10));
    try std.testing.expect(idempotentRankInt(I4) == 4);
    try std.testing.expect(classifyArchetype(I4) == .Identity);
}

test "Idempotent: orthogonal projectors P·Q = 0" {
    const p = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    const q = PGL4.fromRowMajor(.{
        .{ 0, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    try std.testing.expect(areOrthogonal(p, q, 1e-10));
}

test "Idempotent: complete set P₁+P₂+P₃+P₄ = I" {
    const p1 = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    const p2 = PGL4.fromRowMajor(.{
        .{ 0, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    const p3 = PGL4.fromRowMajor(.{
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 0 },
    });
    const p4 = PGL4.fromRowMajor(.{
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 1 },
    });
    const projectors = &[_]PGL4{ p1, p2, p3, p4 };
    try std.testing.expect(isCompleteSet(projectors, 1e-10));
}

test "Idempotent: complement Q = I−P is idempotent" {
    const p = PGL4.fromRowMajor(.{
        .{ 1, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    });
    const q = complement(p);
    try std.testing.expect(isIdempotent(q, 1e-10));
    try std.testing.expect(idempotentRankInt(q) == 3);
    try std.testing.expect(areOrthogonal(p, q, 1e-10));
}

test "Idempotent: spectral projector for diagonal matrix" {
    // A = diag(2, 3, 5, 7)
    const a = PGL4.fromRowMajor(.{
        .{ 2, 0, 0, 0 },
        .{ 0, 3, 0, 0 },
        .{ 0, 0, 5, 0 },
        .{ 0, 0, 0, 7 },
    });
    // Спектральный проектор для λ=3: E₂ = diag(0,1,0,0)
    const others = &[_]f64{ 2.0, 5.0, 7.0 };
    const e2 = spectralProjector(a, 3.0, others);
    try std.testing.expect(isIdempotent(e2, 1e-8));
    try std.testing.expectApproxEqAbs(idempotentRank(e2), 1.0, 1e-8);

    // E₂ должен выделять вторую координату
    const v = HomVec4.init(1, 1, 1, 1);
    const result = e2.apply(v);
    try std.testing.expectApproxEqAbs(result.x, 0.0, 1e-8);
    try std.testing.expectApproxEqAbs(result.y, 1.0, 1e-8);
    try std.testing.expectApproxEqAbs(result.z, 0.0, 1e-8);
    try std.testing.expectApproxEqAbs(result.w, 0.0, 1e-8);
}

test "Idempotent: spectral decomposition reconstructs A" {
    const a = PGL4.fromRowMajor(.{
        .{ 2, 0, 0, 0 },
        .{ 0, 3, 0, 0 },
        .{ 0, 0, 5, 0 },
        .{ 0, 0, 0, 7 },
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const eigenvalues = &[_]f64{ 2.0, 3.0, 5.0, 7.0 };
    const components = try spectralDecomposition(a, eigenvalues, alloc);
    const reconstructed = reconstructFromSpectral(components);

    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(reconstructed.data[i], a.data[i], 1e-8);
    }
}

test "Idempotent: commutator [A,A] = 0" {
    const a = p3_kernel.pglScale(2, 3, 4);
    const c = commutator(a, a);
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(c.data[i], 0.0, 1e-10);
    }
}

test "Idempotent: commutator [A,B] = −[B,A]" {
    const a = p3_kernel.pglScale(2, 3, 4);
    const b = p3_kernel.pglTranslate(1, 2, 3);
    const ab = commutator(a, b);
    const ba = commutator(b, a);
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(ab.data[i], -ba.data[i], 1e-10);
    }
}

test "Idempotent: Newton projection converges to idempotent" {
    // Начнём с близкой к проектору матрицы
    const p = PGL4.fromRowMajor(.{
        .{ 0.9, 0.1, 0.0, 0.0 },
        .{ 0.0, 0.1, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.05, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.05 },
    });
    const projected = projectToIdempotent(p, 20, 1e-8);
    try std.testing.expect(isIdempotent(projected, 1e-4));
}

test "Idempotent: dynamics dP/dt with γ>0 drives toward idempotent" {
    // Начнём с не-идемпотента
    const p = PGL4.fromRowMajor(.{
        .{ 0.8, 0.2, 0.0, 0.0 },
        .{ 0.0, 0.3, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.1, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.1 },
    });
    const h = PGL4.identity(); // H = I → [H,P] = 0

    // dP/dt при γ=1: должно быть −(P²−P)
    const dpdt = idempotentDynamics(h, p, 1.0);

    // P² − P для проверки знака
    const p2 = PGL4.mul(p, p);
    // (1,1) элемент: P²[0][0] − P[0][0] = 0.68+0.06 − 0.8 = −0.06
    // dP/dt[0][0] = −(−0.06) = +0.06 → P движется к идемпотенту
    const expected_11 = -(p2.get(0, 0) - p.get(0, 0));
    try std.testing.expectApproxEqAbs(dpdt.get(0, 0), expected_11, 1e-10);
}
