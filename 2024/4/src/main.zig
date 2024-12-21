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
        std.mem.copyForwards(u8, row, line);
        try grid.append(row);
    }

    var xmas_sum: usize = 0;
    var crossmas_sum: usize = 0;
    const rows = grid.items.len;
    const cols = grid.items[0].len;

    for (0..rows) |y| {
        for (0..cols) |x| {
            if (grid.items[y][x] == 'X') {
                xmas_sum += countXMAS(&grid, x, y);
            }
            if (grid.items[y][x] == 'A') {
                crossmas_sum += hasCROSSMAS(&grid, x, y);
            }
        }
    }

    std.debug.print("Total XMAS sum: {}\n", .{xmas_sum});
    std.debug.print("Total CROSSMAS sum: {}\n", .{crossmas_sum});
}

fn countXMAS(grid: *const std.ArrayList([]u8), x: usize, y: usize) usize {
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

    var count: usize = 0;
    for (directions) |dir| {
        count += countXMASDirection(grid, x, y, dir[0], dir[1]);
    }
    return count;
}

fn countXMASDirection(grid: *const std.ArrayList([]u8), x: usize, y: usize, dx: i32, dy: i32) usize {
    const rows = grid.items.len;
    const cols = grid.items[0].len;
    for (1..4) |i| {
        const nx = @as(i32, @intCast(x)) + dx * @as(i32, @intCast(i));
        const ny = @as(i32, @intCast(y)) + dy * @as(i32, @intCast(i));
        if (nx < 0 or nx >= @as(i32, @intCast(cols)) or ny < 0 or ny >= @as(i32, @intCast(rows))) {
            return 0;
        }
        if (grid.items[@intCast(ny)][@intCast(nx)] != TARGET_PHRASE[i]) {
            return 0;
        }
    }
    return 1;
}

fn hasCROSSMAS(grid: *const std.ArrayList([]u8), x: usize, y: usize) usize {
    const directions = [_][2][2]i32{
        [_][2]i32{ [_]i32{ -1, -1 }, [_]i32{ 1, 1 } },
        [_][2]i32{ [_]i32{ -1, 1 }, [_]i32{ 1, -1 } },
    };

    for (directions) |dir_pair| {
        if (!hasCROSSMASDirection(grid, x, y, dir_pair[0], dir_pair[1])) {
            return 0;
        }
    }
    return 1;
}

fn hasCROSSMASDirection(grid: *const std.ArrayList([]u8), x: usize, y: usize, dir1: [2]i32, dir2: [2]i32) bool {
    const rows = grid.items.len;
    const cols = grid.items[0].len;

    const nx1 = @as(i32, @intCast(x)) + dir1[0];
    const ny1 = @as(i32, @intCast(y)) + dir1[1];
    const nx2 = @as(i32, @intCast(x)) + dir2[0];
    const ny2 = @as(i32, @intCast(y)) + dir2[1];

    if (nx1 < 0 or nx1 >= @as(i32, @intCast(cols)) or ny1 < 0 or ny1 >= @as(i32, @intCast(rows)) or
        nx2 < 0 or nx2 >= @as(i32, @intCast(cols)) or ny2 < 0 or ny2 >= @as(i32, @intCast(rows)))
    {
        return false;
    }

    return (grid.items[@intCast(ny1)][@intCast(nx1)] == 'M' and
        grid.items[@intCast(ny2)][@intCast(nx2)] == 'S') or
        (grid.items[@intCast(ny1)][@intCast(nx1)] == 'S' and
        grid.items[@intCast(ny2)][@intCast(nx2)] == 'M');
}
