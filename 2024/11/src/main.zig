const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
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

    var stones = StoneList.init(allocator);
    defer stones.deinit();

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        while (iter.next()) |number| {
            const stone = try std.fmt.parseInt(Stone, number, 10);
            try stones.append(stone);
        }
    }

    for (0..FIRST_INTERMISSION) |_| {
        try stones.step();
    }
    std.debug.print("Stone count after first intermission: {}\n", .{stones.len()});

    for (FIRST_INTERMISSION..SECOND_INTERMISSION) |_| {
        try stones.step();
    }
    std.debug.print("Stone count after second intermission: {}\n", .{stones.len()});
}

const Stone = u128;

const StoneList = struct {
    items: std.ArrayList(Stone),
    memoized_values: std.AutoHashMap(Stone, [2]?Stone),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .items = std.ArrayList(Stone).init(allocator),
            .memoized_values = std.AutoHashMap(Stone, [2]?Stone).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.memoized_values.deinit();
        self.items.deinit();
    }

    pub fn append(self: *Self, stone: Stone) !void {
        try self.items.append(stone);
    }

    pub fn step(self: *Self) !void {
        var i: usize = 0;
        const length = self.items.items.len;
        while (i < length) : (i += 1) {
            const stone = self.items.items[i];
            const newStones = try self.getOrCalculateStones(stone);
            self.items.items[i] = newStones[0] orelse unreachable;
            if (newStones[1]) |newStone| {
                try self.items.append(newStone);
            }
        }
    }

    pub fn getOrCalculateStones(self: *Self, stone: Stone) ![2]?Stone {
        const gop = try self.memoized_values.getOrPut(stone);
        if (gop.found_existing) {
            return gop.value_ptr.*;
        } else {
            const newStones = self.stepStone(stone);
            gop.value_ptr.* = newStones;
            return newStones;
        }
    }

    pub fn stepStone(self: *Self, stone: Stone) [2]?Stone {
        if (self.handleEvenDigits(stone)) |newStones| {
            return newStones;
        }
        if (self.handleZeroStone(stone)) |newStones| {
            return newStones;
        }
        return self.handleDefault(stone);
    }

    fn handleZeroStone(_: *Self, stone: Stone) ?[2]?Stone {
        if (stone == 0) {
            return .{ 1, null };
        }
        return null;
    }

    fn handleEvenDigits(_: *Self, stone: Stone) ?[2]?Stone {
        if (stone == 0) return null;
        const digits = std.math.log10_int(stone) + 1;
        if (digits % 2 != 0) {
            return null;
        }
        const half_digits = digits / 2;
        const divisor = std.math.pow(u128, 10, half_digits);
        const left = stone / divisor;
        const right = stone % divisor;
        return .{ left, right };
    }

    fn handleDefault(_: *Self, stone: Stone) [2]?Stone {
        return .{ stone * 2024, null };
    }

    pub fn print(self: *const Self) !void {
        const stdout = std.io.getStdOut().writer();
        for (self.items.items) |stone| {
            try stdout.print("{} ", .{stone});
        }
        try stdout.print("\n", .{});
    }

    pub fn len(self: *const Self) usize {
        return self.items.items.len;
    }
};
