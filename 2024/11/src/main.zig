const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const AutoHashMap = std.AutoHashMap;

const FIRST_INTERMISSION = 25;
const SECOND_INTERMISSION = 75;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var buf: [4096]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stones = StoneCounter.init(allocator);
    defer stones.deinit();

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        while (iter.next()) |number| {
            const stone = try std.fmt.parseInt(Stone, number, 10);
            try stones.increment(stone, 1);
        }
    }

    for (0..FIRST_INTERMISSION) |_| {
        try stones.step();
    }
    std.debug.print("Stone count after first intermission: {}\n", .{stones.totalCount()});

    for (FIRST_INTERMISSION..SECOND_INTERMISSION) |_| {
        try stones.step();
    }
    std.debug.print("Stone count after second intermission: {}\n", .{stones.totalCount()});
}

const Stone = u128;

const StoneCounter = struct {
    counts: AutoHashMap(Stone, usize),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .counts = AutoHashMap(Stone, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.counts.deinit();
    }

    pub fn increment(self: *Self, stone: Stone, count: usize) !void {
        const gop = try self.counts.getOrPut(stone);
        if (!gop.found_existing) {
            gop.value_ptr.* = 0;
        }
        gop.value_ptr.* += count;
    }

    pub fn decrement(self: *Self, stone: Stone, count: usize) !void {
        const gop = try self.counts.getOrPut(stone);
        if (!gop.found_existing) {
            return;
        }
        if (gop.value_ptr.* <= count) {
            _ = self.counts.remove(stone);
        } else {
            gop.value_ptr.* -= count;
        }
    }

    pub fn step(self: *Self) !void {
        var stones = try self.counts.clone();
        defer stones.deinit();

        var it = stones.iterator();
        while (it.next()) |entry| {
            const stone = entry.key_ptr.*;
            const count = entry.value_ptr.*;

            if (count == 0) continue;

            if (stone == 0) {
                try self.increment(1, count);
                try self.decrement(0, count);
            } else if (std.math.log10_int(stone) % 2 == 1) {
                const stone_str = try std.fmt.allocPrint(self.counts.allocator, "{}", .{stone});
                defer self.counts.allocator.free(stone_str);
                const new_len = stone_str.len / 2;
                const stone_1 = try std.fmt.parseInt(Stone, stone_str[0..new_len], 10);
                const stone_2 = try std.fmt.parseInt(Stone, stone_str[new_len..], 10);
                try self.increment(stone_1, count);
                try self.increment(stone_2, count);
                try self.decrement(stone, count);
            } else {
                try self.increment(stone * 2024, count);
                try self.decrement(stone, count);
            }
        }
    }

    pub fn totalCount(self: *const Self) usize {
        var total: usize = 0;
        var it = self.counts.valueIterator();
        while (it.next()) |count| {
            total += count.*;
        }
        return total;
    }
};
