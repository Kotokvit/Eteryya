// =============================================================================
// P³ RHI — RENDER HARDWARE INTERFACE (ИЗ O3DE Atom/RHI)
// =============================================================================
//
// Донор: O3DE Atom/RHI — 1193 файла C++:
//   - RHI.Core: Buffer, Image, PipelineState, CommandList, FrameGraph
//   - RHI.Vulkan: 245 файлов (runtime backend)
//   - RHI.DX12: 172 файлов
//   - RHI.Metal: 168 файлов
//   - Проблема: глубокая иерархия наследования, virtual dispatch
//     на КАЖДОМ GPU вызове, RTTI для resource validation
//
// Мы УБИВАЕМ C++ OOP иерархию и ПОЖИРАЕМ концепции.
// Zig: tagged unions вместо virtual dispatch,
//      comptime backend selection вместо runtime polymorphism,
//      WGSL/Vulkan direct вместо abstraction layers.
//
// P³-СПЕЦИФИКА:
//   - PGL4 matrices uploaded DIRECTLY to GPU (no Matrix4x4 conversion)
//   - HomVec4 positions as GPU buffers (no Vector3 conversion)
//   - FS-distance computed on GPU (WGSL compute shader)
//   - Geodesic rendering (great circles on S³)
//   - Projective camera (no perspective Matrix4x4 — native PGL4)
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const p3_kernel = @import("p3_kernel.zig");
const p3_gpu = @import("p3_gpu.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const PGL4 = p3_kernel.PGL4;

// =============================================================================
// 1. GPU BACKEND — COMPTIME SELECTION (НЕ RUNTIME POLYMORPHISM)
// =============================================================================
//
// O3DE: Factory* g_factory — runtime polymorphism через virtual
// P³:   comptime Backend — zero-cost, inline all GPU calls

/// GPU Backend — выбирается при компиляции
pub const Backend = enum {
    vulkan,
    wgpu, // WebGPU (Mach sysgpu)
    null, // Headless (testing)
};

/// Format данных (GPU-native)
pub const Format = enum {
    undefined,
    // 8-bit
    r8_unorm,
    rg8_unorm,
    rgba8_unorm,
    rgba8_srgb,
    // 16-bit
    r16_float,
    rg16_float,
    rgba16_float,
    // 32-bit
    r32_float,
    rg32_float,
    rgb32_float,
    rgba32_float,
    r32_uint,
    rg32_uint,
    rgba32_uint,
    // Depth
    depth16_unorm,
    depth24_unorm_stencil8_uint,
    depth32_float,
    depth32_float_stencil8_uint,
    // P³-specific: HomVec4 = 4×f64 = 32 bytes
    homvec4_f64,
    // P³-specific: PGL4 = 16×f64 = 128 bytes
    pgl4_f64,

    /// Размер одного элемента в байтах
    pub fn size(self: Format) u32 {
        return switch (self) {
            .undefined => 0,
            .r8_unorm => 1,
            .rg8_unorm => 2,
            .rgba8_unorm, .rgba8_srgb => 4,
            .r16_float => 2,
            .rg16_float => 4,
            .rgba16_float => 8,
            .r32_float => 4,
            .rg32_float => 8,
            .rgb32_float => 12,
            .rgba32_float => 16,
            .r32_uint => 4,
            .rg32_uint => 8,
            .rgba32_uint => 16,
            .depth16_unorm => 2,
            .depth24_unorm_stencil8_uint => 4,
            .depth32_float => 4,
            .depth32_float_stencil8_uint => 8,
            .homvec4_f64 => 32, // [x:f64, y:f64, z:f64, w:f64]
            .pgl4_f64 => 128, // [16×f64]
        };
    }

    pub fn isDepth(self: Format) bool {
        return switch (self) {
            .depth16_unorm, .depth24_unorm_stencil8_uint, .depth32_float, .depth32_float_stencil8_uint => true,
            else => false,
        };
    }

    pub fn isP3(self: Format) bool {
        return self == .homvec4_f64 or self == .pgl4_f64;
    }
};

// =============================================================================
// 2. GPU BUFFER (ИЗ O3DE RHI Buffer + BufferView)
// =============================================================================

/// Тип буфера
pub const BufferType = enum {
    vertex,
    index,
    uniform,
    storage,
    // P³-specific: buffer of HomVec4 positions
    p3_positions,
    // P³-specific: buffer of PGL4 transforms
    p3_transforms,
};

/// Heap type
pub const HeapType = enum {
    device_local, // GPU-only (fastest)
    upload, // CPU→GPU (staging)
    readback, // GPU→CPU (readback)
};

/// Buffer descriptor
pub const BufferDescriptor = struct {
    type: BufferType,
    format: Format,
    size: u64,
    stride: u64, // sizeof(element)
    heap: HeapType,
    /// Can be updated dynamically
    dynamic: bool,

    pub fn initP3Positions(count: u32) BufferDescriptor {
        return .{
            .type = .p3_positions,
            .format = .homvec4_f64,
            .size = count * 32, // 4×f64 = 32 bytes
            .stride = 32,
            .heap = .device_local,
            .dynamic = true,
        };
    }

    pub fn initP3Transforms(count: u32) BufferDescriptor {
        return .{
            .type = .p3_transforms,
            .format = .pgl4_f64,
            .size = count * 128, // 16×f64 = 128 bytes
            .stride = 128,
            .heap = .device_local,
            .dynamic = true,
        };
    }

    pub fn initVertex(format: Format, count: u32, stride: u64) BufferDescriptor {
        return .{
            .type = .vertex,
            .format = format,
            .size = count * stride,
            .stride = stride,
            .heap = .device_local,
            .dynamic = false,
        };
    }

    pub fn initUniform(size: u64) BufferDescriptor {
        return .{
            .type = .uniform,
            .format = .undefined,
            .size = size,
            .stride = 0,
            .heap = .upload,
            .dynamic = true,
        };
    }
};

/// GPU Buffer handle (type-safe — нельзя перепутать buffer и image)
pub const BufferId = struct {
    id: u64,
    generation: u32, // Для обнаружения use-after-free

    pub fn invalid() BufferId {
        return .{ .id = 0, .generation = 0 };
    }

    pub fn isValid(self: BufferId) bool {
        return self.id != 0;
    }
};

// =============================================================================
// 3. GPU IMAGE (ИЗ O3DE RHI Image + ImageView)
// =============================================================================

/// Image dimension
pub const ImageDimension = enum {
    dim_1d,
    dim_2d,
    dim_3d,
    cube,
};

/// Image usage flags
pub const ImageUsage = packed struct {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    input_attachment: bool = false,
    // P³: render geodesics
    p3_geodesic_target: bool = false,
};

/// Image descriptor
pub const ImageDescriptor = struct {
    dimension: ImageDimension,
    format: Format,
    width: u32,
    height: u32,
    depth: u32,
    mip_levels: u32,
    array_layers: u32,
    usage: ImageUsage,

    pub fn init2D(format: Format, width: u32, height: u32, usage: ImageUsage) ImageDescriptor {
        return .{
            .dimension = .dim_2d,
            .format = format,
            .width = width,
            .height = height,
            .depth = 1,
            .mip_levels = 1,
            .array_layers = 1,
            .usage = usage,
        };
    }

    /// P³ render target: RGBA16f с geodesic overlay
    pub fn initP3RenderTarget(width: u32, height: u32) ImageDescriptor {
        return init2D(.rgba16_float, width, height, .{
            .color_attachment = true,
            .transfer_src = true,
            .sampled = true,
            .p3_geodesic_target = true,
        });
    }
};

/// GPU Image handle
pub const ImageId = struct {
    id: u64,
    generation: u32,

    pub fn invalid() ImageId {
        return .{ .id = 0, .generation = 0 };
    }

    pub fn isValid(self: ImageId) bool {
        return self.id != 0;
    }
};

// =============================================================================
// 4. SHADER / PIPELINE (ИЗ O3DE RHI PipelineState + ShaderResourceGroup)
// =============================================================================

/// Shader stage
pub const ShaderStage = enum {
    vertex,
    fragment,
    compute,
    // P³-specific: geodesic compute
    p3_geodesic,
    // P³-specific: FS-distance compute
    p3_fs_distance,
    // P³-specific: idempotent Newton
    p3_idempotent,
};

/// Shader module handle
pub const ShaderModuleId = struct {
    id: u64,

    pub fn invalid() ShaderModuleId {
        return .{ .id = 0 };
    }
};

/// Pipeline type
pub const PipelineType = enum {
    graphics,
    compute,
    // P³-specific
    p3_projective, // Full PGL4 pipeline
};

/// Primitive topology
pub const PrimitiveTopology = enum {
    point_list,
    line_list,
    line_strip,
    triangle_list,
    triangle_strip,
    // P³: geodesic lines
    geodesic_list,
};

/// Blend factor
pub const BlendFactor = enum {
    zero,
    one,
    src_alpha,
    one_minus_src_alpha,
};

/// Blend state
pub const BlendState = struct {
    enabled: bool = false,
    src_color: BlendFactor = .src_alpha,
    dst_color: BlendFactor = .one_minus_src_alpha,
    src_alpha: BlendFactor = .one,
    dst_alpha: BlendFactor = .zero,
};

/// Depth state
pub const DepthState = struct {
    depth_test: bool = true,
    depth_write: bool = true,
    depth_compare: CompareOp = .less,
    // P³: FS-distance based depth (instead of Z-buffer)
    fs_depth: bool = false,
};

/// Compare operation
pub const CompareOp = enum {
    never,
    less,
    equal,
    less_equal,
    greater,
    not_equal,
    greater_equal,
    always,
};

/// Graphics pipeline descriptor
pub const GraphicsPipelineDescriptor = struct {
    pipeline_type: PipelineType = .graphics,
    vertex_shader: ShaderModuleId = ShaderModuleId.invalid(),
    fragment_shader: ShaderModuleId = ShaderModuleId.invalid(),
    topology: PrimitiveTopology = .triangle_list,
    blend: BlendState = .{},
    depth: DepthState = .{},
    /// Render target formats
    color_formats: []const Format = &.{.rgba8_unorm},
    depth_format: Format = .depth32_float,
    /// P³: upload PGL4 matrices directly
    p3_projective_pipeline: bool = false,
};

/// Compute pipeline descriptor
pub const ComputePipelineDescriptor = struct {
    pipeline_type: PipelineType = .compute,
    compute_shader: ShaderModuleId = ShaderModuleId.invalid(),
    workgroup_size_x: u32 = 64,
    workgroup_size_y: u32 = 1,
    workgroup_size_z: u32 = 1,
};

/// Pipeline handle (tagged union — нет виртуального dispatch!)
pub const PipelineId = union(enum) {
    graphics: u64,
    compute: u64,
    p3_projective: u64,

    pub fn isValid(self: PipelineId) bool {
        return switch (self) {
            .graphics => |id| id != 0,
            .compute => |id| id != 0,
            .p3_projective => |id| id != 0,
        };
    }
};

// =============================================================================
// 5. COMMAND LIST (ИЗ O3DE RHI CommandList)
// =============================================================================
//
// O3DE: CommandList — virtual dispatch на КАЖДОЙ команде рисования
// P³:   CommandBuffer — enum тегов, comptime dispatch

/// Draw command
pub const DrawCommand = struct {
    pipeline: PipelineId,
    vertex_buffer: BufferId,
    index_buffer: BufferId,
    index_count: u32,
    instance_count: u32 = 1,
    /// P³: PGL4 transform buffer (projective transform per instance)
    p3_transform_buffer: BufferId = BufferId.invalid(),
    /// P³: HomVec4 position buffer
    p3_position_buffer: BufferId = BufferId.invalid(),
};

/// Dispatch command (compute)
pub const DispatchCommand = struct {
    pipeline: PipelineId,
    group_count_x: u32,
    group_count_y: u32 = 1,
    group_count_z: u32 = 1,
};

/// GPU command (tagged union — НЕ virtual!)
pub const GpuCommand = union(enum) {
    /// Clear render target
    clear: struct {
        color_attachment: ImageId,
        r: f32,
        g: f32,
        b: f32,
        a: f32,
        depth: f32 = 1.0,
    },
    /// Begin render pass
    begin_pass: struct {
        color_attachments: []const ImageId,
        depth_attachment: ?ImageId = null,
    },
    /// End render pass
    end_pass,
    /// Bind pipeline
    bind_pipeline: PipelineId,
    /// Bind vertex buffer
    bind_vertex_buffer: struct {
        buffer: BufferId,
        offset: u64 = 0,
    },
    /// Bind uniform buffer
    bind_uniform: struct {
        buffer: BufferId,
        offset: u64 = 0,
        size: u64 = 0,
        binding: u32,
    },
    /// Draw indexed
    draw_indexed: DrawCommand,
    /// Dispatch compute
    dispatch: DispatchCommand,
    /// P³: Upload PGL4 matrices to GPU
    p3_upload_pgl4: struct {
        buffer: BufferId,
        transforms: []const PGL4,
    },
    /// P³: Upload HomVec4 positions to GPU
    p3_upload_positions: struct {
        buffer: BufferId,
        positions: []const HomVec4,
    },
    /// P³: Compute FS-distance batch on GPU
    p3_compute_fs_distance: struct {
        positions_a: BufferId,
        positions_b: BufferId,
        results: BufferId,
        count: u32,
    },
    /// P³: Render geodesic lines
    p3_render_geodesics: struct {
        positions: BufferId,
        count: u32,
        color_r: f32 = 1.0,
        color_g: f32 = 1.0,
        color_b: f32 = 1.0,
    },
};

// =============================================================================
// 6. FRAME GRAPH (ИЗ O3DE RHI FrameGraph)
// =============================================================================
//
// O3DE: FrameGraph — runtime graph construction with virtual passes
// P³:   FrameGraph — comptime-pass registration, execution order fixed

/// Frame pass type
pub const PassType = enum {
    clear,
    geometry, // O3DE: "DrawPass"
    lighting, // O3DE: "LightPass"
    post_process,
    ui,
    // P³-specific
    p3_geodesic, // Render geodesic lines
    p3_fs_compute, // FS-distance compute shader
    p3_idempotent, // Idempotent Newton iteration
    p3_dehomogenize, // P³ → R³ bridge on GPU
};

/// Frame pass descriptor
pub const FramePass = struct {
    pass_type: PassType,
    name: []const u8,
    /// Read attachments
    reads: []const ImageId,
    /// Write attachments
    writes: []const ImageId,
    /// Commands for this pass
    commands: []const GpuCommand,
};

/// Frame graph — sequence of passes for one frame
pub const FrameGraph = struct {
    passes: std.ArrayList(FramePass),
    frame_index: u64,

    pub fn init(allocator: std.mem.Allocator) FrameGraph {
        return .{
            .passes = std.ArrayList(FramePass).init(allocator),
            .frame_index = 0,
        };
    }

    pub fn deinit(self: *FrameGraph) void {
        self.passes.deinit();
    }

    /// Add a pass
    pub fn addPass(self: *FrameGraph, pass: FramePass) !void {
        try self.passes.append(pass);
    }

    /// Advance frame
    pub fn advanceFrame(self: *FrameGraph) void {
        self.frame_index += 1;
    }

    /// Number of passes
    pub fn passCount(self: FrameGraph) u32 {
        return @intCast(self.passes.items.len);
    }
};

// =============================================================================
// 7. GPU DEVICE — АБСТРАКЦИЯ (COMPTIME BACKEND)
// =============================================================================

/// GPU device limits (from Vulkan/DX12 physical device)
pub const DeviceLimits = struct {
    max_texture_size_2d: u32 = 8192,
    max_texture_size_3d: u32 = 2048,
    max_uniform_buffer_size: u32 = 65536,
    max_storage_buffer_size: u64 = 128 * 1024 * 1024,
    max_vertex_attributes: u32 = 32,
    max_color_attachments: u32 = 8,
    max_anisotropy: f32 = 16.0,
    min_uniform_buffer_alignment: u32 = 256,
    // P³: max HomVec4 per draw call
    max_p3_positions_per_draw: u32 = 1000000,
    // P³: max PGL4 transforms per draw call
    max_p3_transforms_per_draw: u32 = 100000,
};

/// GPU device descriptor
pub const DeviceDescriptor = struct {
    backend: Backend,
    limits: DeviceLimits,
    /// Enable P³ projective pipeline
    p3_enabled: bool = true,
    /// Enable WGSL shader compilation
    wgsl_enabled: bool = true,
};

// =============================================================================
// 8. ТЕСТЫ
// =============================================================================

test "RHI: Format sizes" {
    try std.testing.expect(Format.rgba8_unorm.size() == 4);
    try std.testing.expect(Format.rgba32_float.size() == 16);
    try std.testing.expect(Format.depth32_float.size() == 4);
    try std.testing.expect(Format.homvec4_f64.size() == 32);
    try std.testing.expect(Format.pgl4_f64.size() == 128);
}

test "RHI: Format P³ detection" {
    try std.testing.expect(Format.homvec4_f64.isP3());
    try std.testing.expect(Format.pgl4_f64.isP3());
    try std.testing.expect(!Format.rgba32_float.isP3());
}

test "RHI: Buffer descriptor P³ positions" {
    const desc = BufferDescriptor.initP3Positions(1000);
    try std.testing.expect(desc.type == .p3_positions);
    try std.testing.expect(desc.format == .homvec4_f64);
    try std.testing.expect(desc.size == 32000); // 1000 × 32
    try std.testing.expect(desc.dynamic);
}

test "RHI: Buffer descriptor P³ transforms" {
    const desc = BufferDescriptor.initP3Transforms(100);
    try std.testing.expect(desc.type == .p3_transforms);
    try std.testing.expect(desc.format == .pgl4_f64);
    try std.testing.expect(desc.size == 12800); // 100 × 128
}

test "RHI: Buffer descriptor uniform" {
    const desc = BufferDescriptor.initUniform(256);
    try std.testing.expect(desc.type == .uniform);
    try std.testing.expect(desc.size == 256);
    try std.testing.expect(desc.heap == .upload);
}

test "RHI: Image descriptor P³ render target" {
    const desc = ImageDescriptor.initP3RenderTarget(1920, 1080);
    try std.testing.expect(desc.dimension == .dim_2d);
    try std.testing.expect(desc.format == .rgba16_float);
    try std.testing.expect(desc.width == 1920);
    try std.testing.expect(desc.height == 1080);
    try std.testing.expect(desc.usage.color_attachment);
    try std.testing.expect(desc.usage.p3_geodesic_target);
}

test "RHI: Pipeline ID validity" {
    const gfx: PipelineId = .{ .graphics = 1 };
    const comp: PipelineId = .{ .compute = 1 };
    const p3: PipelineId = .{ .p3_projective = 1 };
    const invalid: PipelineId = .{ .graphics = 0 };
    try std.testing.expect(gfx.isValid());
    try std.testing.expect(comp.isValid());
    try std.testing.expect(p3.isValid());
    try std.testing.expect(!invalid.isValid());
}

test "RHI: Graphics pipeline defaults" {
    const desc = GraphicsPipelineDescriptor{};
    try std.testing.expect(desc.pipeline_type == .graphics);
    try std.testing.expect(desc.depth.depth_test);
    try std.testing.expect(!desc.p3_projective_pipeline);
}

test "RHI: GPU command tagged union" {
    const cmd: GpuCommand = .end_pass;
    try std.testing.expect(cmd == .end_pass);

    const clear_cmd: GpuCommand = .{
        .clear = .{
            .color_attachment = ImageId.invalid(),
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        },
    };
    try std.testing.expect(clear_cmd == .clear);
}

test "RHI: Frame graph" {
    var graph = FrameGraph.init(std.testing.allocator);
    defer graph.deinit();

    try graph.addPass(.{
        .pass_type = .clear,
        .name = "clear_pass",
        .reads = &.{},
        .writes = &.{},
        .commands = &.{},
    });
    try graph.addPass(.{
        .pass_type = .p3_geodesic,
        .name = "geodesic_pass",
        .reads = &.{},
        .writes = &.{},
        .commands = &.{},
    });

    try std.testing.expect(graph.passCount() == 2);
    graph.advanceFrame();
    try std.testing.expect(graph.frame_index == 1);
}

test "RHI: Device limits defaults" {
    const limits = DeviceLimits{};
    try std.testing.expect(limits.max_p3_positions_per_draw == 1000000);
    try std.testing.expect(limits.max_p3_transforms_per_draw == 100000);
}

test "RHI: Depth state FS-depth" {
    var depth = DepthState{};
    try std.testing.expect(depth.depth_test);
    try std.testing.expect(!depth.fs_depth);
    depth.fs_depth = true;
    try std.testing.expect(depth.fs_depth);
}

test "RHI: P³ upload command" {
    const identity = PGL4.identity();
    const cmd: GpuCommand = .{
        .p3_upload_pgl4 = .{
            .buffer = BufferId{ .id = 1, .generation = 1 },
            .transforms = &.{identity},
        },
    };
    try std.testing.expect(cmd == .p3_upload_pgl4);
}
