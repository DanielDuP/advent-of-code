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
    const mapScoreByPeaks = try scoreMap(&map, scoreTrailByPeaks);
    const mapScoreByRoutes = try scoreMap(&map, scoreTrailByRoutes);
    std.debug.print("Map score by peaks: {d}\n", .{mapScoreByPeaks});
    std.debug.print("Map score by routes: {d}\n", .{mapScoreByRoutes});
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

fn scoreMap(map: *const Map, scoringStrategy: fn (*const Map, Coord) anyerror!u32) !u32 {
    var score: u32 = 0;
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
            score += try scoringStrategy(map, trailOrigin);
        }
    }
    return score;
}

fn scoreTrailByPeaks(map: *const Map, trailOrigin: Coord) !u32 {
    var score: u32 = 0;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var distinctHighestPoints = std.AutoHashMap(Coord, void).init(allocator);
    const listOfHighestPoints = try scoreCoordinate(map, trailOrigin, allocator);
    defer listOfHighestPoints.deinit();

    for (listOfHighestPoints.items) |coord| {
        try distinctHighestPoints.put(coord, {});
    }

    score = @intCast(distinctHighestPoints.count());
    return score;
}

fn scoreTrailByRoutes(map: *const Map, trailOrigin: Coord) !u32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const listOfHighestPoints = try scoreCoordinate(map, trailOrigin, allocator);
    defer listOfHighestPoints.deinit();
    return @intCast(listOfHighestPoints.items.len);
}

fn scoreCoordinate(map: *const Map, coord: Coord, allocator: std.mem.Allocator) !ArrayList(Coord) {
    var highest_points = ArrayList(Coord).init(allocator);
    const currentVal = getValue(map, coord);
    if (currentVal == null) {
        return highest_points;
    }
    if (currentVal.? == MAX_HEIGHT) {
        try highest_points.append(coord);
        return highest_points;
    }
    for (directions) |direction| {
        const newCoordinate = Coord{ .x = coord.x + direction[0], .y = coord.y + direction[1] };
        const newValue = getValue(map, newCoordinate);
        if (newValue == null or newValue.? != currentVal.? + 1) {
            continue;
        }
        var subPoints = try scoreCoordinate(map, newCoordinate, allocator);
        try highest_points.appendSlice(subPoints.items);
        subPoints.deinit();
    }
    return highest_points;
}
