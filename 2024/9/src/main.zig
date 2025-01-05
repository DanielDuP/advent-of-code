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
        try evaluateDiskMap(allocator, diskMapDescription, compactDiskMapWithoutFragmentation);
    }
}

const FileBlock = union(enum) {
    Empty,
    Data: i32,
};

const DiskMap = std.ArrayList(FileBlock);
const DiskMapDescription = std.ArrayList(i32);

fn evaluateDiskMap(allocator: std.mem.Allocator, diskMapDescription: DiskMapDescription, compactionStrategy: *const fn (*DiskMap) anyerror!void) !void {
    var diskMap = try composeDiskMap(allocator, diskMapDescription);
    defer diskMap.deinit();
    try compactionStrategy(&diskMap);
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

fn compactDiskMapWithFragmentation(diskMap: *DiskMap) !void {
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

const MemorySlot = struct {
    beginning: usize,
    end: usize,

    fn length(self: MemorySlot) usize {
        return self.end - self.beginning + 1;
    }
};

fn findOpenMemorySlots(diskMap: *DiskMap, allocator: std.mem.Allocator) !std.ArrayList(MemorySlot) {
    var openMemorySlots = std.ArrayList(MemorySlot).init(allocator);
    errdefer openMemorySlots.deinit();

    var j: usize = 0;
    while (j < diskMap.items.len) {
        switch (diskMap.items[j]) {
            .Data => j += 1,
            .Empty => {
                var i = j + 1;
                while (i < diskMap.items.len and diskMap.items[i] == .Empty) {
                    i += 1;
                }
                try openMemorySlots.append(MemorySlot{ .beginning = j, .end = i - 1 });
                j = i;
            },
        }
    }

    return openMemorySlots;
}

fn compactDiskMapWithoutFragmentation(diskMap: *DiskMap) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var openMemorySlots = try findOpenMemorySlots(diskMap, allocator);
    defer openMemorySlots.deinit();

    var i: usize = diskMap.items.len;
    while (i > 0) {
        i -= 1;
        switch (diskMap.items[i]) {
            .Empty => {},
            .Data => |value| {
                var j: usize = i;
                while (j > 0 and diskMap.items[j - 1] == .Data and diskMap.items[j - 1].Data == value) {
                    j -= 1;
                }
                const requiredLength = i - j + 1;
                slot_search: for (openMemorySlots.items, 0..) |slot, slot_index| {
                    if (slot.length() >= requiredLength and slot.beginning < j) {
                        moveBlock(diskMap, j, i, slot.beginning);
                        if (slot.length() > requiredLength) {
                            openMemorySlots.items[slot_index] = MemorySlot{
                                .beginning = slot.beginning + requiredLength,
                                .end = slot.end,
                            };
                        } else {
                            _ = openMemorySlots.orderedRemove(slot_index);
                        }
                        break :slot_search;
                    }
                }
                i = j;
            },
        }
    }
}

fn moveBlock(diskMap: *DiskMap, copyFromStart: usize, copyFromEnd: usize, copyToStart: usize) void {
    assert(diskMap.items.len > copyFromEnd);
    assert(copyToStart + (copyFromEnd - copyFromStart) < diskMap.items.len);

    const blockSize = copyFromEnd - copyFromStart + 1;
    var i: usize = 0;
    while (i < blockSize) : (i += 1) {
        diskMap.items[copyToStart + i] = diskMap.items[copyFromStart + i];
        diskMap.items[copyFromStart + i] = FileBlock.Empty;
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
