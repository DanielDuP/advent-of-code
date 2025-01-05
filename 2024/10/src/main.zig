const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

const MAX_X = 256;
const MAX_Y = 256;
const MAX_HEIGHT = 9;

const Map = [MAX_X][MAX_Y]?u4;
const Coord = struct { x: i16, y: i16 };

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var line_buf: [65536]u8 = undefined;
    var map: Map = .{.{null} ** MAX_Y} ** MAX_X;

    var y: i16 = 0;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        for (line, 0..) |char, x| {
            loadValue(&map, Coord{ .x = @as(i16, @intCast(x)), .y = y }, @as(u4, @intCast(char - '0')));
        }
        y += 1;
    }
    const mapScore = try scoreMap(&map);
    std.debug.print("Map score: {d}\n", .{mapScore});
}

fn loadValue(map: *Map, coord: Coord, value: u4) void {
    assert(isValidCoordinate(coord));
    map[@as(usize, @intCast(coord.y))][@as(usize, @intCast(coord.x))] = value;
}

fn isValidCoordinate(coord: Coord) bool {
    return coord.x >= 0 and
        coord.y >= 0 and
        coord.x < MAX_X and
        coord.y < MAX_Y;
}

fn getValue(map: *const Map, coord: Coord) ?u4 {
    if (!isValidCoordinate(coord)) {
        return null;
    }
    return map[@as(usize, @intCast(coord.y))][@as(usize, @intCast(coord.x))];
}

const directions = [_][2]i16{
    .{ -1, 0 },
    .{ 1, 0 },
    .{ 0, -1 },
    .{ 0, 1 },
};

fn scoreMap(map: *const Map) !u32 {
    var score: u32 = 0;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for (map, 0..) |row, y| {
        if (row[0] == null) {
            break;
        }
        row_loop: for (row, 0..) |cell, x| {
            if (cell == null) {
                break :row_loop;
            }
            if (cell.? != 0) {
                continue;
            }
            const trailOrigin = Coord{ .x = @as(i16, @intCast(x)), .y = @as(i16, @intCast(y)) };
            var highest_points = std.AutoHashMap(Coord, void).init(allocator);
            scoreCoordinate(map, trailOrigin, &highest_points);
            score += @as(u32, @intCast(highest_points.count()));
        }
    }
    return score;
}

fn scoreCoordinate(map: *const Map, coord: Coord, highest_points: *std.AutoHashMap(Coord, void)) void {
    const currentVal = getValue(map, coord);
    if (currentVal == null) {
        return;
    }
    if (currentVal.? == MAX_HEIGHT) {
        highest_points.put(coord, {}) catch unreachable;
        return;
    }
    for (directions) |direction| {
        const newCoordinate = Coord{ .x = coord.x + direction[0], .y = coord.y + direction[1] };
        const newValue = getValue(map, newCoordinate);
        if (newValue == null or newValue.? != currentVal.? + 1) {
            continue;
        }
        scoreCoordinate(map, newCoordinate, highest_points);
    }
}
