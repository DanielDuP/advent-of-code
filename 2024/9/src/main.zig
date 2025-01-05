const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var line_buf: [65536]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var diskMapDescription = try DiskMapDescription.initCapacity(allocator, line.len);
        defer diskMapDescription.deinit();
        for (line) |char| {
            if (char >= '0' and char <= '9') {
                try diskMapDescription.append(@as(i32, char - '0'));
            }
        }
        try evaluateDiskMap(allocator, diskMapDescription);
    }
}

const FileBlock = union(enum) {
    Empty,
    Data: i32,
};

const DiskMap = std.ArrayList(FileBlock);
const DiskMapDescription = std.ArrayList(i32);

fn evaluateDiskMap(allocator: std.mem.Allocator, diskMapDescription: DiskMapDescription) !void {
    var diskMap = try composeDiskMap(allocator, diskMapDescription);
    defer diskMap.deinit();
    compactDiskMap(&diskMap);
    const cs = try checkSum(diskMap);
    std.debug.print("Checksum: {}\n", .{cs});
}

fn composeDiskMap(allocator: std.mem.Allocator, diskMapDescription: DiskMapDescription) !DiskMap {
    var diskMap = DiskMap.init(allocator);
    errdefer diskMap.deinit();

    var isEmpty = false;
    var id: i32 = 0;
    for (diskMapDescription.items) |count| {
        const fileBlock = if (isEmpty) FileBlock.Empty else FileBlock{ .Data = id };
        try diskMap.appendNTimes(fileBlock, @as(usize, @intCast(count)));
        isEmpty = !isEmpty;
        if (!isEmpty) id += 1;
    }
    return diskMap;
}

fn compactDiskMap(diskMap: *DiskMap) void {
    var j: usize = diskMap.items.len - 1;
    var i: usize = 0;
    while (i < j) {
        if (diskMap.items[i] == FileBlock.Empty) {
            while (j > i and diskMap.items[j] == FileBlock.Empty) {
                j -= 1;
            }
            if (j > i) {
                diskMap.items[i] = diskMap.items[j];
                diskMap.items[j] = FileBlock.Empty;
            }
        }
        i += 1;
    }
}

fn checkSum(diskMap: DiskMap) !u64 {
    var sum: u64 = 0;

    for (diskMap.items, 0..) |block, pos| {
        switch (block) {
            .Empty => {},
            .Data => |value| {
                sum += @as(u64, @intCast(value)) * @as(u64, @intCast(pos));
            },
        }
    }

    return sum;
}
