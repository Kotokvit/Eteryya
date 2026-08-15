// =============================================================================
// P³ SCENE — SCENE GRAPH В P³ С ГЕОДЕЗИЧЕСКИМИ СВЯЗЯМИ
// =============================================================================
//
// В O3DE/Unity/Unreal: Scene graph — дерево Transform узлов.
//   - Parent → Child связь через Matrix4x4
//   - World = Parent.World × Child.Local
//   - Проблема: gimbal lock, singular matrices, float drift
//
// В P³ Engine: Scene graph — дерево PGL4 узлов НА S³.
//   - Parent → Child связь через ГЕОДЕЗИЧЕСКУЮ связь
//   - World = exp(log(Parent.World) + log(Child.Local))  — на многообразии!
//   - Нет gimbal lock (нет Euler angles)
//   - Нет singular matrices (NonSingularPGL4 — тип)
//   - Нет float drift (ренормализация на S³ каждые N шагов)
//
// Доноры:
//   - O3DE: TransformComponent (parent-child hierarchy)
//   - P³ geodesic: exp/log maps для composition
//   - p3_ecs: Entity + Component lifecycle
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");
const p3_geodesic = @import("p3_geodesic.zig");
const p3_ecs = @import("p3_ecs.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;
pub const EntityId = p3_ecs.EntityId;
pub const Entity = p3_ecs.Entity;

// =============================================================================
// 1. СЦЕНОВЫЙ УЗЕЛ (SCENE NODE)
// =============================================================================

/// Scenовый узел в P³ — точка на S³ с локальным трансформом
///
/// В отличие от O3DE TransformComponent:
///   - position ∈ S³ (автонормировка)
///   - local_transform ∈ PGL4 (проективный, не евклидов)
///   - parent связь — через геодезическую, не матричное умножение
pub const SceneNode = struct {
    id: EntityId,
    /// Локальная позиция на S³ (нормирована)
    local_position: HomVec4,
    /// Локальный PGL4 трансформ
    local_transform: PGL4,
    /// Мировая позиция (вычисленная)
    world_position: HomVec4,
    /// Мировой трансформ (вычисленный)
    world_transform: PGL4,
    /// ID родителя
    parent_id: EntityId,
    /// Глубина в дереве (0 = root)
    depth: u32,
    /// Грязный флаг (нужен пересчёт world)
    dirty: bool,

    pub fn init(id: EntityId) SceneNode {
        return .{
            .id = id,
            .local_position = HomVec4.fromCartesian(.{ 0, 0, 0 }),
            .local_transform = PGL4.identity(),
            .world_position = HomVec4.fromCartesian(.{ 0, 0, 0 }),
            .world_transform = PGL4.identity(),
            .parent_id = EntityId.invalid(),
            .depth = 0,
            .dirty = true,
        };
    }

    /// Установить локальную позицию
    pub fn setLocalPosition(self: *SceneNode, pos: HomVec4) void {
        const n = pos.norm();
        self.local_position = if (n > 1e-15) pos.normalize() else HomVec4.fromCartesian(.{ 0, 0, 0 });
        self.dirty = true;
    }

    /// Установить локальный трансформ
    pub fn setLocalTransform(self: *SceneNode, m: PGL4) void {
        self.local_transform = m;
        self.dirty = true;
    }

    /// Установить родителя
    pub fn setParent(self: *SceneNode, parent_id: EntityId, parent_depth: u32) void {
        self.parent_id = parent_id;
        self.depth = parent_depth + 1;
        self.dirty = true;
    }

    /// Отсоединить от родителя
    pub fn detach(self: *SceneNode) void {
        self.parent_id = EntityId.invalid();
        self.depth = 0;
        self.dirty = true;
    }

    pub fn isRoot(self: SceneNode) bool {
        return !self.parent_id.isValid();
    }
};

// =============================================================================
// 2. ГЕОДЕЗИЧЕСКАЯ СВЯЗЬ МЕЖДУ УЗЛАМИ
// =============================================================================
//
// Вместо матричного умножения Parent.World × Child.Local
// мы используем геодезическую связь на S³:
//
//   Child.WorldPosition = geodesic(Parent.WorldPosition, direction, distance)
//
// где direction и distance определяются из Child.LocalPosition
// через log map: v = log_p(q), direction = v/|v|, distance = |v|

/// Геодезическая связь: вычислить мировую позицию ребёнка
/// по мировой позиции родителя и локальной позиции ребёнка
///
/// На S³: child_world = exp(parent_world, log(identity, child_local))
/// Т.е. параллельно переносим child_local вдоль геодезической из parent
pub fn geodesicCompose(
    parent_world: HomVec4,
    child_local: HomVec4,
) HomVec4 {
    // Логарифм child_local из identity
    const identity = HomVec4.init(0, 0, 0, 1); // [0:0:0:1] — «начало» в UW карте
    const tangent = p3_geodesic.logMap(identity, child_local);

    // Параллельный перенос касательного вектора из identity → parent_world
    // На S³: переносим v = tangent из origin в parent_world
    // Упрощение: для близких точек ≈ M·v где M = parallel transport
    // Точный: используем exp map
    const transported = p3_geodesic.expMap(parent_world, tangent);
    return transported.normalize(); // Ренормализация на S³
}

/// Геодезическое расстояние между узлами (FS-метрика)
pub fn geodesicDistance(a: HomVec4, b: HomVec4) f64 {
    return p3_kernel.fsDistance(a, b);
}

// =============================================================================
// 3. SCENE GRAPH — ДЕРЕВО СЦЕНОВЫХ УЗЛОВ
// =============================================================================

/// Scene Graph — коллекция узлов с parent-child связями
pub const SceneGraph = struct {
    nodes: std.ArrayList(SceneNode),
    renormalize_counter: u32,
    renormalize_interval: u32, // каждые N обновлений

    pub fn init(allocator: std.mem.Allocator) SceneGraph {
        return .{
            .nodes = std.ArrayList(SceneNode).init(allocator),
            .renormalize_counter = 0,
            .renormalize_interval = 100,
        };
    }

    pub fn deinit(self: *SceneGraph) void {
        self.nodes.deinit();
    }

    /// Добавить корневой узел
    pub fn addRootNode(self: *SceneGraph, id: EntityId) !void {
        var node = SceneNode.init(id);
        node.dirty = false;
        node.world_position = node.local_position;
        node.world_transform = node.local_transform;
        try self.nodes.append(node);
    }

    /// Добавить дочерний узел
    pub fn addChildNode(self: *SceneGraph, id: EntityId, parent_id: EntityId) !void {
        const parent_depth: u32 = blk: {
            for (self.nodes.items) |n| {
                if (n.id.id == parent_id.id) break :blk n.depth;
            }
            break :blk 0;
        };
        var node = SceneNode.init(id);
        node.setParent(parent_id, parent_depth);
        try self.nodes.append(node);
    }

    /// Найти узел по ID
    pub fn getNode(self: SceneGraph, id: EntityId) ?*SceneNode {
        for (self.nodes.items) |*node| {
            if (node.id.id == id.id) return node;
        }
        return null;
    }

    /// Обновить мировые трансформы (dirty propagation)
    /// Сортирует по depth (родители первыми), затем обновляет
    pub fn updateWorldTransforms(self: *SceneGraph) void {
        // Сортировка по depth (bubble sort — достаточно для <100 узлов)
        const node_count = self.nodes.items.len;
        for (0..node_count) |i| {
            for (0..node_count - 1 - i) |j| {
                if (self.nodes.items[j].depth > self.nodes.items[j + 1].depth) {
                    const tmp = self.nodes.items[j];
                    self.nodes.items[j] = self.nodes.items[j + 1];
                    self.nodes.items[j + 1] = tmp;
                }
            }
        }

        // Обновление: корни первыми, дети потом
        for (self.nodes.items) |*node| {
            if (!node.dirty and node.isRoot()) continue;

            if (node.isRoot()) {
                node.world_position = node.local_position;
                node.world_transform = node.local_transform;
            } else {
                // Найти родителя
                if (self.getNode(node.parent_id)) |parent| {
                    // Геодезическая композиция (НЕ матричное умножение!)
                    node.world_position = geodesicCompose(
                        parent.world_position,
                        node.local_position,
                    );
                    // PGL4 композиция
                    node.world_transform = PGL4.mul(
                        parent.world_transform,
                        node.local_transform,
                    );
                } else {
                    // Родитель не найден — становимся корнем
                    node.detach();
                    node.world_position = node.local_position;
                    node.world_transform = node.local_transform;
                }
            }
            node.dirty = false;
        }

        // Периодическая ренормализация на S³
        self.renormalize_counter += 1;
        if (self.renormalize_counter >= self.renormalize_interval) {
            self.renormalize_counter = 0;
            for (self.nodes.items) |*node| {
                const wnorm = node.world_position.norm();
                if (@abs(wnorm - 1.0) > 1e-10 and wnorm > 1e-15) {
                    node.world_position = node.world_position.normalize();
                }
            }
        }
    }

    /// Количество узлов
    pub fn count(self: SceneGraph) u32 {
        return @intCast(self.nodes.items.len);
    }

    /// Максимальная глубина
    pub fn maxDepth(self: SceneGraph) u32 {
        var max_d: u32 = 0;
        for (self.nodes.items) |node| {
            max_d = @max(max_d, node.depth);
        }
        return max_d;
    }
};

// =============================================================================
// 4. ТЕСТЫ
// =============================================================================

test "Scene: SceneNode creation" {
    const node = SceneNode.init(EntityId.init(1));
    try std.testing.expect(node.isRoot());
    try std.testing.expect(node.dirty);
    try std.testing.expect(node.depth == 0);
}

test "Scene: SceneNode set position normalizes" {
    var node = SceneNode.init(EntityId.init(1));
    node.setLocalPosition(HomVec4.fromCartesian(.{ 3, 4, 0 }));
    try std.testing.expectApproxEqAbs(node.local_position.norm(), 1.0, 1e-10);
}

test "Scene: Geodesic compose identity" {
    const parent = HomVec4.init(0, 0, 0, 1); // origin
    const child = HomVec4.fromCartesian(.{ 0, 0, 0 }).normalize(); // same point
    const result = geodesicCompose(parent, child);
    // Compose(origin, origin) ≈ origin
    try std.testing.expectApproxEqAbs(result.w, 1.0, 0.1);
}

test "Scene: SceneGraph add root node" {
    var graph = SceneGraph.init(std.testing.allocator);
    defer graph.deinit();

    try graph.addRootNode(EntityId.init(1));
    try std.testing.expect(graph.count() == 1);
    try std.testing.expect(graph.maxDepth() == 0);
}

test "Scene: SceneGraph add child node" {
    var graph = SceneGraph.init(std.testing.allocator);
    defer graph.deinit();

    try graph.addRootNode(EntityId.init(1));
    try graph.addChildNode(EntityId.init(2), EntityId.init(1));
    try std.testing.expect(graph.count() == 2);
    try std.testing.expect(graph.maxDepth() == 1);
}

test "Scene: SceneGraph update world transforms" {
    var graph = SceneGraph.init(std.testing.allocator);
    defer graph.deinit();

    try graph.addRootNode(EntityId.init(1));
    try graph.addChildNode(EntityId.init(2), EntityId.init(1));

    graph.updateWorldTransforms();

    const root = graph.getNode(EntityId.init(1));
    try std.testing.expect(root != null);
    try std.testing.expect(!root.?.dirty);
}

test "Scene: SceneNode detach" {
    var node = SceneNode.init(EntityId.init(1));
    node.setParent(EntityId.init(99), 0);
    try std.testing.expect(!node.isRoot());
    node.detach();
    try std.testing.expect(node.isRoot());
}

test "Scene: Geodesic distance between nodes" {
    const a = HomVec4.init(1, 0, 0, 0);
    const b = HomVec4.init(0, 1, 0, 0);
    const d = geodesicDistance(a, b);
    try std.testing.expectApproxEqAbs(d, math.pi / 2.0, 1e-10);
}
