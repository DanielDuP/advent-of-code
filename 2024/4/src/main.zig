const std = @import("std");
const assert = std.debug.assert;

const TARGET_PHRASE = "XMAS";

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var grid = std.ArrayList([]u8).init(std.heap.page_allocator);
    defer {
        for (grid.items) |row| {
            std.heap.page_allocator.free(row);
        }
        grid.deinit();
    }

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const row = try std.heap.page_allocator.alloc(u8, line.len);
        std.mem.copyForward(u8, row, line);
        try grid.append(row);
    }

    var total_count: usize = 0;
    const rows = grid.items.len;
    const cols = grid.items[0].len;

    for (0..rows) |y| {
        for (0..cols) |x| {
            if (grid.items[y][x] == 'X') {
                if (checkXMAS(&grid, x, y, rows, cols)) {
                    total_count += 1;
                }
            }
        }
    }

    std.debug.print("Total XMAS count: {}\n", .{total_count});
}

fn checkXMAS(grid: *const std.ArrayList([]u8), x: usize, y: usize, rows: usize, cols: usize) bool {
    const directions = [_][2]i32{
        [_]i32{ 1, 0 }, // right
        [_]i32{ 0, 1 }, // down
        [_]i32{ 1, 1 }, // diagonal down-right
        [_]i32{ -1, 1 }, // diagonal down-left
        [_]i32{ -1, 0 }, // left
        [_]i32{ 0, -1 }, // up
        [_]i32{ -1, -1 }, // diagonal up-left
        [_]i32{ 1, -1 }, // diagonal up-right
    };

    for (directions) |dir| {
        if (checkDirection(grid, x, y, dir[0], dir[1], rows, cols)) {
            return true;
        }
    }
    return false;
}

fn checkDirection(grid: *const std.ArrayList([]u8), x: usize, y: usize, dx: i32, dy: i32, rows: usize, cols: usize) bool {
    for (1..4) |i| {
        const nx = @as(i32, @intCast(x)) + dx * @as(i32, @intCast(i));
        const ny = @as(i32, @intCast(y)) + dy * @as(i32, @intCast(i));
        if (nx < 0 or nx >= cols or ny < 0 or ny >= rows) {
            return false;
        }
        if (grid.items[@intCast(ny)][@intCast(nx)] != TARGET_PHRASE[i]) {
            return false;
        }
    }
    return true;
}
