// =============================================================================
// P³ ECS — ENTITY COMPONENT SYSTEM (ИЗ O3DE, ПЕРЕПИСАНО НА ZIG)
// =============================================================================
//
// Донор: O3DE AzCore/Component/ — зрелый ECS с:
//   - Entity + Component lifecycle (Init/Activate/Deactivate)
//   - Service dependencies (provided/required/incompatible)
//   - EBus (type-safe event bus)
//   - Transform hierarchy (parent/child)
//
// Мы УБИВАЕМ O3DE-математику (Vector3 для всего, деление на ноль)
// и ПОЖИРАЕМ архитектуру (ECS, service deps, event bus).
//
// КЛЮЧЕВОЕ ОТЛИЧИЕ от O3DE:
//   - Entity позиция — HomVec4 (P³), НЕ Vector3 (R³)
//   - Component transform — PGL4 (проективный), НЕ Transform (евклидов)
//   - Transform hierarchy — геодезические связи на S³
//   - Service dependencies — comptime, НЕ runtime RTTI
//   - Event bus — Zig generics, НЕ C++ virtual
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. ENTITY — КОНТЕЙНЕР КОМПОНЕНТОВ В P³
// =============================================================================

/// Entity ID — уникальный идентификатор в мире
pub const EntityId = struct {
    id: u64,

    pub fn init(id: u64) EntityId {
        return .{ .id = id };
    }

    pub fn invalid() EntityId {
        return .{ .id = 0 };
    }

    pub fn isValid(self: EntityId) bool {
        return self.id != 0;
    }
};

/// Entity state
pub const EntityState = enum {
    init,
    active,
    deactivating,
    inactive,
    destroyed,
};

/// Entity — контейнер компонентов с позицией в P³
///
/// В O3DE: Entity содержит Component[] + Vector3 position
/// В P³:    Entity содержит Component[] + HomVec4 position (на S³!)
pub const Entity = struct {
    id: EntityId,
    name: []const u8,
    state: EntityState,
    /// Позиция в P³ (однородные координаты, нормирована на S³)
    position: HomVec4,
    /// Мировой трансформ (PGL4 — проективный, НЕ евклидов Transform)
    world_transform: PGL4,
    /// Родительская сущность (для иерархии)
    parent_id: EntityId,
    /// Версия для change tracking
    version: u64,

    pub fn init(id: u64, name: []const u8) Entity {
        return .{
            .id = EntityId.init(id),
            .name = name,
            .state = .init,
            .position = HomVec4.fromCartesian(.{ 0, 0, 0 }),
            .world_transform = PGL4.identity(),
            .parent_id = EntityId.invalid(),
            .version = 0,
        };
    }

    /// Активировать сущность
    pub fn activate(self: *Entity) void {
        if (self.state == .init or self.state == .inactive) {
            self.state = .active;
            self.version += 1;
        }
    }

    /// Деактивировать
    pub fn deactivate(self: *Entity) void {
        if (self.state == .active) {
            self.state = .deactivating;
            self.version += 1;
        }
    }

    /// Установить позицию в P³ (автонормировка на S³)
    pub fn setPosition(self: *Entity, pos: HomVec4) void {
        const n = pos.norm();
        if (n > 1e-15) {
            self.position = pos.normalize();
        }
        self.version += 1;
    }

    /// Установить мировой трансформ (PGL4)
    pub fn setWorldTransform(self: *Entity, m: PGL4) void {
        self.world_transform = m;
        self.version += 1;
    }

    /// FS-расстояние до другой сущности
    pub fn distanceTo(self: Entity, other: Entity) f64 {
        return p3_kernel.fsDistance(self.position, other.position);
    }

    pub fn isActive(self: Entity) bool {
        return self.state == .active;
    }
};

// =============================================================================
// 2. COMPONENT — БАЗОВЫЙ КОМПОНЕНТ (ИЗ O3DE, ПЕРЕПИСАНО)
// =============================================================================

/// Component type ID (comptime, НЕ runtime RTTI как в O3DE)
pub const ComponentTypeId = struct {
    id: u64,

    pub fn init(comptime T: type) ComponentTypeId {
        return .{ .id = @intCast(@intFromPtr(&@as(T, undefined))) };
    }

    pub fn fromId(id: u64) ComponentTypeId {
        return .{ .id = id };
    }
};

/// Component lifecycle (как в O3DE: Init → Activate → Deactivate → Destroy)
pub const ComponentState = enum {
    init,
    active,
    inactive,
    destroyed,
};

/// Базовый компонент
///
/// В O3DE: Component — C++ класс с virtual Init/Activate/Deactivate
/// В P³:    Component — Zig struct с fn pointers (zero-cost abstraction)
pub const Component = struct {
    type_id: ComponentTypeId,
    entity_id: EntityId,
    state: ComponentState,
    name: []const u8,

    pub fn init(type_id: ComponentTypeId, entity_id: EntityId, name: []const u8) Component {
        return .{
            .type_id = type_id,
            .entity_id = entity_id,
            .state = .init,
            .name = name,
        };
    }

    pub fn activate(self: *Component) void {
        if (self.state == .init or self.state == .inactive) {
            self.state = .active;
        }
    }

    pub fn deactivate(self: *Component) void {
        if (self.state == .active) {
            self.state = .inactive;
        }
    }

    pub fn isActive(self: Component) bool {
        return self.state == .active;
    }
};

// =============================================================================
// 3. SERVICE ЗАВИСИМОСТИ (ИЗ O3DE, COMPTIME)
// =============================================================================
//
// O3DE: ComponentApplication::GetProvidedServices/GetDependentServices
// P³:   comptime объявления — никаких runtime RTTI

/// Service dependency descriptor
pub const ServiceDependency = struct {
    service_id: u64,
    is_required: bool, // true = must have, false = optional
};

/// Component descriptor — comptime информация о компоненте
pub const ComponentDescriptor = struct {
    type_id: ComponentTypeId,
    name: []const u8,
    provided_services: []const u64,
    required_services: []const u64,
    incompatible_services: []const u64,
    is_system_component: bool,
};

// =============================================================================
// 4. EVENT BUS (ИЗ O3DE EBus, ПЕРЕПИСАНО НА ZIG GENERICS)
// =============================================================================
//
// O3DE EBus — type-safe publish/subscribe с policy-based design.
// Мы переписываем на Zig generics — zero-cost, comptime-полиморфизм.

/// Simple event bus: single handler per event type
/// В O3DE: EBus<Interface, Policy> с multiple/single handler policies
/// В P³:   упрощённый вариант для одного обработчика
pub fn EventBus(comptime Event: type) type {
    return struct {
        handler: ?*const fn (Event) void,

        const Self = @This();

        pub fn init() Self {
            return .{ .handler = null };
        }

        pub fn setHandler(self: *Self, h: *const fn (Event) void) void {
            self.handler = h;
        }

        pub fn dispatch(self: Self, event: Event) void {
            if (self.handler) |h| {
                h(event);
            }
        }
    };
}

/// Multi-handler event bus: slice of handlers
pub fn MultiEventBus(comptime Event: type) type {
    return struct {
        handlers: std.ArrayList(*const fn (Event) void),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .handlers = std.ArrayList(*const fn (Event) void).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *Self, h: *const fn (Event) void) !void {
            try self.handlers.append(h);
        }

        pub fn dispatch(self: Self, event: Event) void {
            for (self.handlers.items) |h| {
                h(event);
            }
        }
    };
}

// =============================================================================
// 5. P³-СПЕЦИФИЧНЫЕ СОБЫТИЯ
// =============================================================================

/// Событие: позиция сущности изменилась
pub const PositionChangedEvent = struct {
    entity_id: EntityId,
    old_position: HomVec4,
    new_position: HomVec4,
    fs_distance_moved: f64, // расстояние Фубини-Штуди
};

/// Событие: трансформ сущности изменился
pub const TransformChangedEvent = struct {
    entity_id: EntityId,
    old_transform: PGL4,
    new_transform: PGL4,
};

/// Событие: сущность создана/уничтожена
pub const EntityLifecycleEvent = struct {
    entity_id: EntityId,
    event_type: enum { created, activated, deactivated, destroyed },
};

// =============================================================================
// 6. МИР (WORLD) — КОНТЕЙНЕР ВСЕХ СУЩНОСТЕЙ
// =============================================================================

/// P³ World — контейнер сущностей с P³-метрикой
pub const World = struct {
    entities: std.ArrayList(Entity),
    next_id: u64,
    position_bus: EventBus(PositionChangedEvent),
    transform_bus: EventBus(TransformChangedEvent),

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .entities = std.ArrayList(Entity).init(allocator),
            .next_id = 1,
            .position_bus = EventBus(PositionChangedEvent).init(),
            .transform_bus = EventBus(TransformChangedEvent).init(),
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();
    }

    /// Создать сущность
    pub fn createEntity(self: *World, name: []const u8) !EntityId {
        const id = self.next_id;
        self.next_id += 1;
        var entity = Entity.init(id, name);
        entity.activate();
        try self.entities.append(entity);
        return EntityId.init(id);
    }

    /// Найти сущность по ID
    pub fn getEntity(self: World, id: EntityId) ?*Entity {
        for (self.entities.items) |*entity| {
            if (entity.id.id == id.id) return entity;
        }
        return null;
    }

    /// Найти ближайшую сущность в FS-метрике
    pub fn findNearest(self: World, position: HomVec4) ?EntityId {
        var best_id: ?EntityId = null;
        var best_dist: f64 = math.pi; // max FS distance

        for (self.entities.items) |entity| {
            if (!entity.isActive()) continue;
            const d = p3_kernel.fsDistance(position, entity.position);
            if (d < best_dist) {
                best_dist = d;
                best_id = entity.id;
            }
        }
        return best_id;
    }

    /// Найти все сущности в FS-радиусе
    pub fn findInRadius(
        self: World,
        center: HomVec4,
        radius: f64,
        allocator: std.mem.Allocator,
    ) ![]EntityId {
        var result = std.ArrayList(EntityId).init(allocator);
        for (self.entities.items) |entity| {
            if (!entity.isActive()) continue;
            const d = p3_kernel.fsDistance(center, entity.position);
            if (d <= radius) {
                try result.append(entity.id);
            }
        }
        return result.items;
    }

    /// Количество активных сущностей
    pub fn activeCount(self: World) u32 {
        var count: u32 = 0;
        for (self.entities.items) |entity| {
            if (entity.isActive()) count += 1;
        }
        return count;
    }
};

// =============================================================================
// 7. ТЕСТЫ
// =============================================================================

test "ECS: Entity creation and lifecycle" {
    var entity = Entity.init(1, "test_entity");
    try std.testing.expect(entity.state == .init);
    try std.testing.expect(!entity.isActive());

    entity.activate();
    try std.testing.expect(entity.isActive());
    try std.testing.expect(entity.state == .active);

    entity.deactivate();
    try std.testing.expect(entity.state == .deactivating);
}

test "ECS: Entity position in P³" {
    var entity = Entity.init(1, "point");
    entity.setPosition(HomVec4.fromCartesian(.{ 3, 4, 0 }));
    // Автонормировка на S³
    try std.testing.expectApproxEqAbs(entity.position.norm(), 1.0, 1e-10);
}

test "ECS: Entity FS distance" {
    var a = Entity.init(1, "a");
    a.setPosition(HomVec4.init(1, 0, 0, 0));
    var b = Entity.init(2, "b");
    b.setPosition(HomVec4.init(0, 1, 0, 0));

    const d = a.distanceTo(b);
    try std.testing.expectApproxEqAbs(d, math.pi / 2.0, 1e-10);
}

test "ECS: EntityId validity" {
    const valid = EntityId.init(42);
    const invalid = EntityId.invalid();
    try std.testing.expect(valid.isValid());
    try std.testing.expect(!invalid.isValid());
}

test "ECS: Component lifecycle" {
    var comp = Component.init(ComponentTypeId.fromId(1), EntityId.init(1), "transform");
    try std.testing.expect(!comp.isActive());
    comp.activate();
    try std.testing.expect(comp.isActive());
    comp.deactivate();
    try std.testing.expect(!comp.isActive());
}

test "ECS: World create and find" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const id = try world.createEntity("player");
    try std.testing.expect(id.isValid());

    const entity = world.getEntity(id);
    try std.testing.expect(entity != null);
    try std.testing.expect(entity.?.isActive());
}

test "ECS: World findNearest" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const id1 = try world.createEntity("near");
    const id2 = try world.createEntity("far");

    if (world.getEntity(id1)) |e| {
        e.setPosition(HomVec4.init(1, 0, 0, 0));
    }
    if (world.getEntity(id2)) |e| {
        e.setPosition(HomVec4.init(0, 1, 0, 0));
    }

    const nearest = world.findNearest(HomVec4.init(0.9, 0.1, 0, 0));
    try std.testing.expect(nearest != null);
    try std.testing.expect(nearest.?.id == id1.id);
}

test "ECS: World active count" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = try world.createEntity("a");
    _ = try world.createEntity("b");
    _ = try world.createEntity("c");
    try std.testing.expect(world.activeCount() == 3);
}

test "ECS: EventBus dispatch" {
    const Handler = struct {
        fn handle(event: PositionChangedEvent) void {
            _ = event;
        }
    };

    var bus = EventBus(PositionChangedEvent).init();
    bus.setHandler(Handler.handle);
    // Dispatch works without crash
    bus.dispatch(.{
        .entity_id = EntityId.init(1),
        .old_position = HomVec4.zero(),
        .new_position = HomVec4.zero(),
        .fs_distance_moved = 0,
    });
}

test "ECS: Entity version tracking" {
    var entity = Entity.init(1, "tracked");
    const v0 = entity.version;
    entity.setPosition(HomVec4.init(1, 0, 0, 0));
    try std.testing.expect(entity.version > v0);
}

test "ECS: Entity world transform PGL4" {
    var entity = Entity.init(1, "transformed");
    entity.setWorldTransform(p3_kernel.pglTranslate(1, 2, 3));
    try std.testing.expectApproxEqAbs(entity.world_transform.get(0, 3), 1.0, 1e-10);
}
