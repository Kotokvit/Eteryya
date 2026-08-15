// =============================================================================
// P³ IO — ФАЙЛОВЫЙ I/O (ИЗ O3DE AzCore/IO)
// =============================================================================
//
// Донор: O3DE AzCore/IO — 75 файлов C++:
//   - FileIOBase с virtual Read/Write/Exists/Copy
//   - LocalFileIO, RemoteFileIO, ArchiveFileIO
//   - StreamStack, Compressor, Driller
//   - Проблема: virtual dispatch на КАЖДОЙ файловой операции
//   - Проблема: глобальный FileIOBase singleton
//
// Мы УБИВАЕМ virtual I/O и singleton.
// Zig std.fs — прямые системные вызовы, zero overhead.
// Для asset streaming — mmap + async I/O.
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. VIRTUAL FILE SYSTEM (VFS) — БЕЗ VIRTUAL DISPATCH
// =============================================================================

/// Тип файла (для asset pipeline)
pub const FileType = enum {
    mesh,
    texture,
    shader,
    audio,
    scene,
    config,
    animation,
    unknown,
};

/// Метаданные файла
pub const FileMetadata = struct {
    path: []const u8,
    size: u64,
    modified_time: i128,
    file_type: FileType,
    /// FS-integrity для P³ assets (0 = perfect)
    fs_integrity: f64,

    pub fn init(path: []const u8, size: u64, mtime: i128, ft: FileType) FileMetadata {
        return .{
            .path = path,
            .size = size,
            .modified_time = mtime,
            .file_type = ft,
            .fs_integrity = 0.0,
        };
    }
};

/// Определить тип файла по расширению (comptime)
pub fn fileTypeFromPath(path: []const u8) FileType {
    if (std.mem.endsWith(u8, path, ".obj") or
        std.mem.endsWith(u8, path, ".gltf") or
        std.mem.endsWith(u8, path, ".glb") or
        std.mem.endsWith(u8, path, ".fbx"))
        return .mesh;
    if (std.mem.endsWith(u8, path, ".png") or
        std.mem.endsWith(u8, path, ".jpg") or
        std.mem.endsWith(u8, path, ".ktx2"))
        return .texture;
    if (std.mem.endsWith(u8, path, ".wgsl") or
        std.mem.endsWith(u8, path, ".glsl"))
        return .shader;
    if (std.mem.endsWith(u8, path, ".wav") or
        std.mem.endsWith(u8, path, ".ogg") or
        std.mem.endsWith(u8, path, ".mp3"))
        return .audio;
    if (std.mem.endsWith(u8, path, ".p3scene") or
        std.mem.endsWith(u8, path, ".p3world"))
        return .scene;
    if (std.mem.endsWith(u8, path, ".json") or
        std.mem.endsWith(u8, path, ".toml") or
        std.mem.endsWith(u8, path, ".cfg"))
        return .config;
    if (std.mem.endsWith(u8, path, ".anim"))
        return .animation;
    return .unknown;
}

// =============================================================================
// 2. АССЕТ-ПАКЕТ (PACKED ASSET FILE)
// =============================================================================
//
// Формат: [P3PACK header][TOC entry...][data blocks...]
// Каждый data block: [type_tag][size][bytes]
// HomVec4 массивы хранятся как: [count:u32][HomVec4...]
// FS-integrity хранится в TOC

const P3PACK_MAGIC: u32 = 0x50335041; // "P3PA"
const P3PACK_VERSION: u32 = 1;

/// Заголовок ассет-пакета
pub const PackHeader = struct {
    magic: u32,
    version: u32,
    entry_count: u32,
    total_size: u64,
    /// Контрольная сумма всех FS-integrity значений
    fs_checksum: f64,

    pub fn init(entry_count: u32, total_size: u64, fs_checksum: f64) PackHeader {
        return .{
            .magic = P3PACK_MAGIC,
            .version = P3PACK_VERSION,
            .entry_count = entry_count,
            .total_size = total_size,
            .fs_checksum = fs_checksum,
        };
    }

    pub fn isValid(self: PackHeader) bool {
        return self.magic == P3PACK_MAGIC and self.version == P3PACK_VERSION;
    }
};

/// Запись в TOC (Table of Contents)
pub const PackEntry = struct {
    /// Offset in pack file
    offset: u64,
    /// Size of data block
    size: u64,
    /// Type of asset
    file_type: FileType,
    /// FS-integrity: sum of deviations from S³
    fs_integrity: f64,
    /// CRC32 of data block
    crc32: u32,
};

// =============================================================================
// 3. АССЕТ ЗАГРУЗЧИК (ASSET LOADER)
// =============================================================================
//
// O3DE: AssetCatalog + AssetManager — 22 файла, virtual dispatch
// P³:   прямая загрузка через std.fs, comptime type dispatch

/// Результат загрузки массива HomVec4 из файла
pub const HomVec4Array = struct {
    positions: []HomVec4,
    fs_integrity: f64,

    pub fn deinit(self: *HomVec4Array, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
    }
};

/// Загрузить массив HomVec4 из сырых байтов (little-endian f64×4)
pub fn loadHomVec4Array(
    allocator: std.mem.Allocator,
    data: []const u8,
) !HomVec4Array {
    if (data.len < 4) return error.InvalidData;
    if (data.len % 32 != 4) return error.InvalidData; // 4 bytes count + N×32 bytes

    // Read count
    const count: u32 = std.mem.readInt(u32, data[0..4], .little);
    if (data.len < 4 + count * 32) return error.InvalidData;

    var positions = try allocator.alloc(HomVec4, count);
    for (0..count) |i| {
        const offset = 4 + i * 32;
        const x: f64 = @bitCast(std.mem.readInt(u64, @as(*const [8]u8, @ptrCast(data.ptr + offset)), .little));
        const y: f64 = @bitCast(std.mem.readInt(u64, @as(*const [8]u8, @ptrCast(data.ptr + offset + 8)), .little));
        const z: f64 = @bitCast(std.mem.readInt(u64, @as(*const [8]u8, @ptrCast(data.ptr + offset + 16)), .little));
        const w: f64 = @bitCast(std.mem.readInt(u64, @as(*const [8]u8, @ptrCast(data.ptr + offset + 24)), .little));
        positions[i] = HomVec4.init(x, y, z, w);
    }

    const fs_integrity = blk: {
        var integ: f64 = 0;
        for (positions) |pos| {
            integ += @abs(pos.norm() - 1.0);
        }
        break :blk integ;
    };

    return .{
        .positions = positions,
        .fs_integrity = fs_integrity,
    };
}

/// Сериализовать массив HomVec4 в сырые байты
pub fn saveHomVec4Array(
    allocator: std.mem.Allocator,
    positions: []const HomVec4,
) ![]const u8 {
    const total_size: usize = 4 + positions.len * 32;
    var buf = try allocator.alloc(u8, total_size);

    // Write count
    std.mem.writeInt(u32, buf[0..4], @intCast(positions.len), .little);

    for (positions, 0..) |pos, i| {
        const offset = 4 + i * 32;
        std.mem.writeInt(u64, buf[offset .. offset + 8][0..8], @bitCast(pos.x), .little);
        std.mem.writeInt(u64, buf[offset + 8 .. offset + 16][0..8], @bitCast(pos.y), .little);
        std.mem.writeInt(u64, buf[offset + 16 .. offset + 24][0..8], @bitCast(pos.z), .little);
        std.mem.writeInt(u64, buf[offset + 24 .. offset + 32][0..8], @bitCast(pos.w), .little);
    }

    return buf;
}

// =============================================================================
// 4. ASYNC I/O ЗАГЛУШКА (ДЛЯ БУДУЩЕГО MACH SYSGPU)
// =============================================================================

/// Async I/O request ID
pub const IoRequestId = struct {
    id: u64,

    pub fn init(id: u64) IoRequestId {
        return .{ .id = id };
    }
};

/// Async I/O result
pub const IoResult = enum {
    pending,
    completed,
    failed,
};

/// Async file reader stub — будет заменён на Mach I/O
pub const AsyncFileReader = struct {
    pending_count: u32,

    pub fn init() AsyncFileReader {
        return .{ .pending_count = 0 };
    }

    /// Запросить асинхронное чтение (заглушка)
    pub fn requestRead(self: *AsyncFileReader, path: []const u8) IoRequestId {
        _ = path;
        self.pending_count += 1;
        return IoRequestId.init(@intCast(self.pending_count));
    }

    /// Проверить статус (заглушка)
    pub fn checkStatus(self: *AsyncFileReader, id: IoRequestId) IoResult {
        _ = self;
        _ = id;
        return .completed; // Заглушка: всегда завершено
    }
};

// =============================================================================
// 5. ТЕСТЫ
// =============================================================================

test "IO: fileTypeFromPath" {
    try std.testing.expect(fileTypeFromPath("model.obj") == .mesh);
    try std.testing.expect(fileTypeFromPath("texture.png") == .texture);
    try std.testing.expect(fileTypeFromPath("shader.wgsl") == .shader);
    try std.testing.expect(fileTypeFromPath("sound.wav") == .audio);
    try std.testing.expect(fileTypeFromPath("scene.p3scene") == .scene);
    try std.testing.expect(fileTypeFromPath("config.json") == .config);
    try std.testing.expect(fileTypeFromPath("unknown.dat") == .unknown);
}

test "IO: FileMetadata creation" {
    const meta = FileMetadata.init("test.p3scene", 1024, 0, .scene);
    try std.testing.expect(meta.size == 1024);
    try std.testing.expect(meta.file_type == .scene);
    try std.testing.expect(meta.fs_integrity == 0.0);
}

test "IO: PackHeader creation and validation" {
    const header = PackHeader.init(5, 10000, 0.0);
    try std.testing.expect(header.isValid());
    try std.testing.expect(header.entry_count == 5);
}

test "IO: PackHeader invalid magic" {
    const header = PackHeader{ .magic = 0xBAD, .version = 1, .entry_count = 0, .total_size = 0, .fs_checksum = 0 };
    try std.testing.expect(!header.isValid());
}

test "IO: HomVec4 array save and load roundtrip" {
    const positions = [_]HomVec4{
        HomVec4.init(1, 0, 0, 0),
        HomVec4.init(0, 1, 0, 0),
        HomVec4.init(0, 0, 1, 0),
    };

    const data = try saveHomVec4Array(std.testing.allocator, &positions);
    defer std.testing.allocator.free(data);

    var loaded = try loadHomVec4Array(std.testing.allocator, data);
    defer loaded.deinit(std.testing.allocator);

    try std.testing.expect(loaded.positions.len == 3);
    try std.testing.expectApproxEqAbs(loaded.positions[0].x, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(loaded.positions[1].y, 1.0, 1e-10);
    try std.testing.expectApproxEqAbs(loaded.positions[2].z, 1.0, 1e-10);
}

test "IO: HomVec4 array FS integrity" {
    const positions = [_]HomVec4{
        HomVec4.init(1, 0, 0, 0), // on S³
        HomVec4.init(0, 1, 0, 0), // on S³
    };
    const data = try saveHomVec4Array(std.testing.allocator, &positions);
    defer std.testing.allocator.free(data);

    var loaded = try loadHomVec4Array(std.testing.allocator, data);
    defer loaded.deinit(std.testing.allocator);

    // Points on S³ should have zero FS integrity
    try std.testing.expectApproxEqAbs(loaded.fs_integrity, 0.0, 1e-10);
}

test "IO: AsyncFileReader stub" {
    var reader = AsyncFileReader.init();
    const id = reader.requestRead("test.p3scene");
    try std.testing.expect(id.id == 1);
    const status = reader.checkStatus(id);
    try std.testing.expect(status == .completed);
}

test "IO: Invalid data for loadHomVec4Array" {
    const bad_data = [_]u8{ 0, 0, 0 };
    const result = loadHomVec4Array(std.testing.allocator, &bad_data);
    try std.testing.expect(result == error.InvalidData);
}
