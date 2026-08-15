// =============================================================================
// P³ SERIAL — СЕРИАЛИЗАЦИЯ ЧЕРЕЗ @typeInfo (ИЗ O3DE AzCore/Serialization)
// =============================================================================
//
// Донор: O3DE AzCore/Serialization — 94 файла C++:
//   - SerializeContext с runtime RTTI для reflection
//   - JsonSerializer, XmlSerializer, BinarySerializer
//   - DataPatch, ObjectStream, DynamicSerializableField
//   - Проблема: ВСЁ на virtual dispatch + runtime RTTI
//
// Мы УБИВАЕМ runtime reflection и ПОЖИРАЕМ формат.
// Zig @typeInfo — comptime reflection, zero cost.
// Сериализация — автоматическая для любого struct через @typeInfo.
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. ФОРМАТ СЕРИАЛИЗАЦИИ
// =============================================================================

pub const Format = enum {
    json,
    binary,
    /// P³-native: binary + FS-metric checksum
    p3bin,
};

// =============================================================================
// 2. СЕРИАЛИЗАТОР — COMPTIME @typeInfo
// =============================================================================

/// Сериализовать любое Zig struct в JSON автоматически через @typeInfo
///
/// O3DE: 94 файла C++, runtime RTTI, virtual dispatch
/// P³:   1 функция, comptime @typeInfo, zero overhead
pub fn serializeJson(
    allocator: std.mem.Allocator,
    value: anytype,
) ![]const u8 {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    const writer = list.writer();

    switch (type_info) {
        .Struct => |s| {
            try writer.writeAll("{");
            var first = true;
            inline for (s.fields) |field| {
                if (!first) try writer.writeAll(",");
                first = false;
                try writer.print("\"{s}\":", .{field.name});
                try writeJsonValue(writer, @field(value, field.name));
            }
            try writer.writeAll("}");
        },
        else => {
            try writeJsonValue(writer, value);
        },
    }

    return list.toOwnedSlice();
}

/// Внутренняя функция записи JSON значений
fn writeJsonValue(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    switch (type_info) {
        .Int, .ComptimeInt => {
            try writer.print("{d}", .{value});
        },
        .Float, .ComptimeFloat => {
            try writer.print("{d}", .{@as(f64, @floatCast(value))});
        },
        .Bool => {
            try writer.writeAll(if (value) "true" else "false");
        },
        .Enum => {
            // Use @tagName for enum serialization
            try writer.print("\"{s}\"", .{@tagName(value)});
        },
        .Struct => |s| {
            try writer.writeAll("{");
            var first = true;
            inline for (s.fields) |field| {
                if (!first) try writer.writeAll(",");
                first = false;
                try writer.print("\"{s}\":", .{field.name});
                try writeJsonValue(writer, @field(value, field.name));
            }
            try writer.writeAll("}");
        },
        .Array => |a| {
            try writer.writeAll("[");
            for (value, 0..) |item, i| {
                if (i > 0) try writer.writeAll(",");
                try writeJsonValue(writer, item);
            }
            _ = a;
            try writer.writeAll("]");
        },
        .Optional => {
            if (value) |v| {
                try writeJsonValue(writer, v);
            } else {
                try writer.writeAll("null");
            }
        },
        else => {
            try writer.print("\"<unsupported:{s}>\"", .{@typeName(T)});
        },
    }
}

// =============================================================================
// 3. ДЕСЕРИАЛИЗАТОР (JSON → struct)
// =============================================================================

/// Упрощённый JSON парсер для P³ типов
/// Полный парсер через std.json (Zig 0.13.0)
pub fn deserializeJson(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_text: []const u8,
) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, json_text, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Освободить десериализованное значение
pub fn deserializeJsonFree(
    comptime T: type,
    allocator: std.mem.Allocator,
    value: T,
) void {
    std.json.parseFree(T, allocator, value);
}

// =============================================================================
// 4. БИНАРНАЯ СЕРИАЛИЗАЦИЯ (P³-NATIVE)
// =============================================================================
//
// Формат: [magic:u32][version:u32][field_count:u32][fields...]
// Каждый field: [name_len:u16][name:bytes][type_tag:u8][data...]
// HomVec4: type_tag=0x10, data = 4×f64
// PGL4:    type_tag=0x20, data = 16×f64
// FS-check: type_tag=0xFF, data = f64 (FS-distance от norm=1)

const P3BIN_MAGIC: u32 = 0x50334249; // "P3BI"
const P3BIN_VERSION: u32 = 1;

/// Сериализовать HomVec4 в бинарный формат
pub fn serializeHomVec4(writer: anytype, v: HomVec4) !void {
    try writer.writeAll(&std.mem.toBytes(v.x));
    try writer.writeAll(&std.mem.toBytes(v.y));
    try writer.writeAll(&std.mem.toBytes(v.z));
    try writer.writeAll(&std.mem.toBytes(v.w));
}

/// Десериализовать HomVec4 из бинарного формата
pub fn deserializeHomVec4(reader: anytype) !HomVec4 {
    const x: f64 = @bitCast(try reader.readInt(u64, .little));
    const y: f64 = @bitCast(try reader.readInt(u64, .little));
    const z: f64 = @bitCast(try reader.readInt(u64, .little));
    const w: f64 = @bitCast(try reader.readInt(u64, .little));
    return HomVec4.init(x, y, z, w);
}

/// Сериализовать PGL4 в бинарный формат
pub fn serializePGL4(writer: anytype, m: PGL4) !void {
    for (0..4) |row| {
        for (0..4) |col| {
            try writer.writeAll(&std.mem.toBytes(m.get(row, col)));
        }
    }
}

/// Десериализовать PGL4 из бинарного формата
pub fn deserializePGL4(reader: anytype) !PGL4 {
    var data: [16]f64 = undefined;
    for (0..16) |i| {
        data[i] = @bitCast(try reader.readInt(u64, .little));
    }
    return PGL4.init(data);
}

/// P³-native бинарный заголовок
pub const P3BinHeader = struct {
    magic: u32,
    version: u32,
    field_count: u32,
    /// FS-integrity: сумма FS-расстояний всех HomVec4 от S³
    /// Если ≠ 0 после десериализации — данные повреждены
    fs_integrity: f64,

    pub fn init(field_count: u32, fs_integrity: f64) P3BinHeader {
        return .{
            .magic = P3BIN_MAGIC,
            .version = P3BIN_VERSION,
            .field_count = field_count,
            .fs_integrity = fs_integrity,
        };
    }

    pub fn isValid(self: P3BinHeader) bool {
        return self.magic == P3BIN_MAGIC and self.version == P3BIN_VERSION;
    }
};

/// Вычислить FS-integrity: сумму отклонений от S³
pub fn computeFsIntegrity(positions: []const HomVec4) f64 {
    var integrity: f64 = 0;
    for (positions) |pos| {
        const deviation = @abs(pos.norm() - 1.0);
        integrity += deviation;
    }
    return integrity;
}

// =============================================================================
// 5. ТЕСТЫ
// =============================================================================

test "Serial: serialize HomVec4 to JSON" {
    const v = HomVec4.init(1, 2, 3, 4);
    const json = try serializeJson(std.testing.allocator, v);
    defer std.testing.allocator.free(json);
    try std.testing.expect(json.len > 0);
    try std.testing.expect(json[0] == '{');
}

test "Serial: serialize simple struct to JSON" {
    const TestStruct = struct {
        x: f64,
        y: f64,
        name: []const u8,
    };
    const val = TestStruct{ .x = 1.5, .y = 2.5, .name = "test" };
    const json = try serializeJson(std.testing.allocator, val);
    defer std.testing.allocator.free(json);
    try std.testing.expect(json.len > 0);
    // Should contain field names
    try std.testing.expect(std.mem.indexOf(u8, json, "\"x\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"y\"") != null);
}

test "Serial: serialize bool to JSON" {
    const json = try serializeJson(std.testing.allocator, true);
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("true", json);
}

test "Serial: serialize integer to JSON" {
    const json = try serializeJson(std.testing.allocator, @as(i32, 42));
    defer std.testing.allocator.free(json);
    try std.testing.expect(json.len > 0);
}

test "Serial: P3BinHeader creation and validation" {
    const header = P3BinHeader.init(3, 0.0);
    try std.testing.expect(header.isValid());
    try std.testing.expect(header.field_count == 3);
    try std.testing.expect(header.fs_integrity == 0.0);
}

test "Serial: P3BinHeader invalid magic" {
    const header = P3BinHeader{ .magic = 0xDEAD, .version = 1, .field_count = 0, .fs_integrity = 0 };
    try std.testing.expect(!header.isValid());
}

test "Serial: FS integrity for normalized vectors" {
    const positions = [_]HomVec4{
        HomVec4.init(1, 0, 0, 0),
        HomVec4.init(0, 1, 0, 0),
    };
    const integrity = computeFsIntegrity(&positions);
    try std.testing.expectApproxEqAbs(integrity, 0.0, 1e-10);
}

test "Serial: FS integrity for non-normalized vectors" {
    const positions = [_]HomVec4{
        HomVec4.init(2, 0, 0, 0), // norm = 2, deviation = 1
    };
    const integrity = computeFsIntegrity(&positions);
    try std.testing.expect(integrity > 0.5);
}

test "Serial: HomVec4 binary roundtrip" {
    const original = HomVec4.init(1.5, 2.5, 3.5, 4.5);
    var buf: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try serializeHomVec4(stream.writer(), original);
    stream.reset();
    const restored = try deserializeHomVec4(stream.reader());
    try std.testing.expectApproxEqAbs(restored.x, original.x, 1e-10);
    try std.testing.expectApproxEqAbs(restored.y, original.y, 1e-10);
    try std.testing.expectApproxEqAbs(restored.z, original.z, 1e-10);
    try std.testing.expectApproxEqAbs(restored.w, original.w, 1e-10);
}

test "Serial: PGL4 binary roundtrip" {
    const original = PGL4.identity();
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try serializePGL4(stream.writer(), original);
    stream.reset();
    const restored = try deserializePGL4(stream.reader());
    try std.testing.expectApproxEqAbs(restored.get(0, 0), 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(restored.get(1, 1), 1.0, 1e-10);
}

test "Serial: enum serialization" {
    const Color = enum { red, green, blue };
    const json = try serializeJson(std.testing.allocator, Color.green);
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("\"green\"", json);
}
