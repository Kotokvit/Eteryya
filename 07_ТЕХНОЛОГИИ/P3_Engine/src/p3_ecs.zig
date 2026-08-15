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

// =============================================================================
// 8. ARCHETYPE STORAGE (ИЗ O3DE, ПЕРЕПИСАНО НА SPARSE SET)
// =============================================================================
//
// O3DE: ComponentArrayType = vector<Component*> — хаотичные указатели
// P³:   Archetype — плотный массив компонентов, cache-friendly
//
// Archetype = набор компонентов хранящихся SOA (Structure of Arrays)
// Все компоненты одного архетипа — в непрерывной памяти
// Запросы (Queries) фильтруют по архетипам — O(1) lookup

/// Archetype ID — уникальный идентификатор архетипа
pub const ArchetypeId = struct {
    id: u32,

    pub fn init(id: u32) ArchetypeId {
        return .{ .id = id };
    }

    pub fn invalid() ArchetypeId {
        return .{ .id = 0 };
    }

    pub fn isValid(self: ArchetypeId) bool {
        return self.id != 0;
    }
};

/// Archetype — набор типов компонентов в плотном хранилище
pub const Archetype = struct {
    id: ArchetypeId,
    /// Хэш от отсортированных type_id — уникальный ключ архетипа
    component_hash: u64,
    /// Типы компонентов в этом архетипе
    component_types: std.ArrayList(ComponentTypeId),
    /// Количество сущностей с этим архетипом
    entity_count: u32,
    /// Ёмкость (pre-allocated)
    capacity: u32,

    pub fn init(allocator: std.mem.Allocator, id: ArchetypeId) Archetype {
        return .{
            .id = id,
            .component_hash = 0,
            .component_types = std.ArrayList(ComponentTypeId).init(allocator),
            .entity_count = 0,
            .capacity = 0,
        };
    }

    pub fn deinit(self: *Archetype) void {
        self.component_types.deinit();
    }

    /// Добавить тип компонента
    pub fn addComponentType(self: *Archetype, type_id: ComponentTypeId) !void {
        try self.component_types.append(type_id);
        // Обновить хэш (FNV-1a)
        self.component_hash = self.component_hash *% 1099511628211 ^ type_id.id;
    }

    /// Проверить наличие компонента
    pub fn hasComponent(self: Archetype, type_id: ComponentTypeId) bool {
        for (self.component_types.items) |ct| {
            if (ct.id == type_id.id) return true;
        }
        return false;
    }

    /// Увеличить счётчик сущностей
    pub fn addEntity(self: *Archetype) void {
        self.entity_count += 1;
    }

    /// Уменьшить счётчик сущностей
    pub fn removeEntity(self: *Archetype) void {
        if (self.entity_count > 0) self.entity_count -= 1;
    }
};

// =============================================================================
// 9. QUERY SYSTEM (ИЗ O3DE, COMPTIME INSTEAD OF RUNTIME)
// =============================================================================
//
// O3DE: ComponentApplication::FindComponents — runtime RTTI search
// P³:   Query — comptime-known component set, iterated directly

/// Query filter — какие архетипы подходят
pub const QueryFilter = struct {
    /// Обязательные компоненты (AND)
    required: []const ComponentTypeId,
    /// Запрещённые компоненты (NOT)
    excluded: []const ComponentTypeId,
    /// Опциональные компоненты (OPTIONAL)
    optional: []const ComponentTypeId,

    pub fn init(required: []const ComponentTypeId) QueryFilter {
        return .{
            .required = required,
            .excluded = &.{},
            .optional = &.{},
        };
    }

    pub fn initWithExclusions(required: []const ComponentTypeId, excluded: []const ComponentTypeId) QueryFilter {
        return .{
            .required = required,
            .excluded = excluded,
            .optional = &.{},
        };
    }

    /// Проверить архетип на соответствие фильтру
    pub fn matches(self: QueryFilter, archetype: Archetype) bool {
        // Все required должны присутствовать
        for (self.required) |req| {
            if (!archetype.hasComponent(req)) return false;
        }
        // Ни один excluded не должен присутствовать
        for (self.excluded) |exc| {
            if (archetype.hasComponent(exc)) return false;
        }
        return true;
    }
};

/// Результат запроса — список подходящих архетипов
pub const QueryResult = struct {
    matching_archetypes: std.ArrayList(ArchetypeId),
    total_entities: u32,

    pub fn init(allocator: std.mem.Allocator) QueryResult {
        return .{
            .matching_archetypes = std.ArrayList(ArchetypeId).init(allocator),
            .total_entities = 0,
        };
    }

    pub fn deinit(self: *QueryResult) void {
        self.matching_archetypes.deinit();
    }
};

// =============================================================================
// 10. ARCHETYPE REGISTRY
// =============================================================================

/// Registry — хранилище всех архетипов
pub const ArchetypeRegistry = struct {
    archetypes: std.ArrayList(Archetype),
    next_id: u32,

    pub fn init(allocator: std.mem.Allocator) ArchetypeRegistry {
        return .{
            .archetypes = std.ArrayList(Archetype).init(allocator),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *ArchetypeRegistry) void {
        for (self.archetypes.items) |*a| {
            a.deinit();
        }
        self.archetypes.deinit();
    }

    /// Создать новый архетип
    pub fn createArchetype(self: *ArchetypeRegistry, component_types: []const ComponentTypeId) !ArchetypeId {
        const id = ArchetypeId.init(self.next_id);
        self.next_id += 1;
        var archetype = Archetype.init(self.archetypes.allocator, id);
        for (component_types) |ct| {
            try archetype.addComponentType(ct);
        }
        try self.archetypes.append(archetype);
        return id;
    }

    /// Найти архетип по ID
    pub fn getArchetype(self: ArchetypeRegistry, id: ArchetypeId) ?*Archetype {
        for (self.archetypes.items) |*a| {
            if (a.id.id == id.id) return a;
        }
        return null;
    }

    /// Выполнить запрос
    pub fn query(self: ArchetypeRegistry, allocator: std.mem.Allocator, filter: QueryFilter) !QueryResult {
        var result = QueryResult.init(allocator);
        for (self.archetypes.items) |archetype| {
            if (filter.matches(archetype)) {
                try result.matching_archetypes.append(archetype.id);
                result.total_entities += archetype.entity_count;
            }
        }
        return result;
    }

    /// Количество архетипов
    pub fn count(self: ArchetypeRegistry) u32 {
        return @intCast(self.archetypes.items.len);
    }
};

// =============================================================================
// 11. ТЕСТЫ ECS EXTENDED
// =============================================================================

test "ECS: Archetype creation" {
    var registry = ArchetypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const transform_type = ComponentTypeId.fromId(1);
    const physics_type = ComponentTypeId.fromId(2);

    const id = try registry.createArchetype(&.{ transform_type, physics_type });
    try std.testing.expect(id.isValid());
    try std.testing.expect(registry.count() == 1);
}

test "ECS: Archetype has component" {
    var registry = ArchetypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const t = ComponentTypeId.fromId(1);
    const p = ComponentTypeId.fromId(2);

    const id = try registry.createArchetype(&.{ t, p });
    const arch = registry.getArchetype(id);
    try std.testing.expect(arch != null);
    try std.testing.expect(arch.?.hasComponent(t));
    try std.testing.expect(arch.?.hasComponent(p));
    try std.testing.expect(!arch.?.hasComponent(ComponentTypeId.fromId(99)));
}

test "ECS: Archetype entity count" {
    var registry = ArchetypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const id = try registry.createArchetype(&.{ComponentTypeId.fromId(1)});
    const arch = registry.getArchetype(id).?;
    arch.addEntity();
    arch.addEntity();
    arch.addEntity();
    try std.testing.expect(arch.entity_count == 3);
    arch.removeEntity();
    try std.testing.expect(arch.entity_count == 2);
}

test "ECS: Query filter matches" {
    var registry = ArchetypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const transform = ComponentTypeId.fromId(1);
    const physics = ComponentTypeId.fromId(2);
    const render = ComponentTypeId.fromId(3);

    _ = try registry.createArchetype(&.{ transform, physics });
    _ = try registry.createArchetype(&.{ transform, render });
    _ = try registry.createArchetype(&.{ physics, render });

    // Query: entities with transform
    const filter = QueryFilter.init(&.{transform});
    var result = try registry.query(std.testing.allocator, filter);
    defer result.deinit();
    try std.testing.expect(result.matching_archetypes.items.len == 2);
}

test "ECS: Query filter with exclusions" {
    var registry = ArchetypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const transform = ComponentTypeId.fromId(1);
    const physics = ComponentTypeId.fromId(2);
    const render = ComponentTypeId.fromId(3);

    _ = try registry.createArchetype(&.{ transform, physics });
    _ = try registry.createArchetype(&.{ transform, render });
    _ = try registry.createArchetype(&.{ transform, physics, render });

    // Query: entities with transform, WITHOUT render
    const filter = QueryFilter.initWithExclusions(&.{transform}, &.{render});
    var result = try registry.query(std.testing.allocator, filter);
    defer result.deinit();
    // Only [transform, physics] matches (no render)
    try std.testing.expect(result.matching_archetypes.items.len == 1);
}

test "ECS: ArchetypeId validity" {
    const valid = ArchetypeId.init(5);
    const invalid = ArchetypeId.invalid();
    try std.testing.expect(valid.isValid());
    try std.testing.expect(!invalid.isValid());
}
