const std = @import("std");

/// Exposes compress and decompress functionality for raw snappy.
pub const raw = @import("raw.zig");

/// Exposes compress and decompress functionality for snappy frames.
pub const frame = @import("frame.zig");

test {
    std.testing.refAllDecls(raw);
    std.testing.refAllDecls(frame);
}

test "round trip - raw" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var dir = try std.Io.Dir.cwd().openDir(io, "testdata", .{ .iterate = true });
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;

        const bytes = try dir.readFileAlloc(io, entry.name, allocator, .unlimited);
        defer allocator.free(bytes);

        const compressed = try allocator.alloc(u8, raw.maxCompressedLength(bytes.len));
        defer allocator.free(compressed);
        const compressed_len = try raw.compress(bytes, compressed);

        const got = try allocator.alloc(u8, try raw.uncompressedLength(compressed));
        defer allocator.free(got);
        _ = try raw.uncompress(compressed[0..compressed_len], got);

        try std.testing.expect(std.mem.eql(u8, bytes, got));
    }
}

test "bad data" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var dir = try std.Io.Dir.cwd().openDir(io, "testdata", .{ .iterate = true });
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.startsWith(u8, entry.name, "baddata")) continue;

        const bytes = try dir.readFileAlloc(io, entry.name, allocator, .unlimited);
        defer allocator.free(bytes);
        const got = try allocator.alloc(u8, try raw.uncompressedLength(bytes));
        defer allocator.free(got);
        try std.testing.expectError(raw.Error.invalid_input, raw.uncompress(bytes[0..], got));
    }
}

test "round trip - framed" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var dir = try std.Io.Dir.cwd().openDir(io, "testdata", .{ .iterate = true });
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;

        const bytes = try dir.readFileAlloc(io, entry.name, allocator, .unlimited);
        defer allocator.free(bytes);
        const d = bytes[0..];
        const compressed = try frame.compress(allocator, d[0..]);
        defer allocator.free(compressed);
        const got = (try frame.uncompress(allocator, compressed)).?;
        defer allocator.free(got);

        try std.testing.expect(std.mem.eql(u8, bytes, got));
    }
}
