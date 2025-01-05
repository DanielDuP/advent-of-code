const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

const MAX_X = 256;
const MAX_Y = 256;
const MAX_HEIGHT = 9;

const Map = [MAX_X][MAX_Y]?u4;
const Coord = struct { x: i16, y: i16 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var map = try loadMap(file.reader());

    const mapScoreByPeaks = try scoreMap(&map, scoreTrailByPeaks, allocator);
    const mapScoreByRoutes = try scoreMap(&map, scoreTrailByRoutes, allocator);

    std.debug.print("Map score by peaks: {d}\n", .{mapScoreByPeaks});
    std.debug.print("Map score by routes: {d}\n", .{mapScoreByRoutes});
}

fn loadMap(reader: anytype) !Map {
    var map: Map = .{.{null} ** MAX_Y} ** MAX_X;
    var y: i16 = 0;
    var line_buf: [MAX_X]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        for (line, 0..) |char, x| {
            const coord = Coord{ .x = @intCast(x), .y = y };
            loadValue(&map, coord, @intCast(char - '0'));
        }
        y += 1;
    }
    return map;
}

fn loadValue(map: *Map, coord: Coord, value: u4) void {
    assert(isValidCoordinate(coord));
    map[@intCast(coord.y)][@intCast(coord.x)] = value;
}

fn isValidCoordinate(coord: Coord) bool {
    return coord.x >= 0 and coord.y >= 0 and coord.x < MAX_X and coord.y < MAX_Y;
}

fn getValue(map: *const Map, coord: Coord) ?u4 {
    return if (isValidCoordinate(coord)) map[@intCast(coord.y)][@intCast(coord.x)] else null;
}

const Direction = struct { dx: i16, dy: i16 };
const directions = [_]Direction{
    .{ .dx = -1, .dy = 0 },
    .{ .dx = 1, .dy = 0 },
    .{ .dx = 0, .dy = -1 },
    .{ .dx = 0, .dy = 1 },
};

fn scoreMap(map: *const Map, scoringStrategy: fn (*const Map, Coord, std.mem.Allocator) anyerror!u32, allocator: std.mem.Allocator) !u32 {
    var score: u32 = 0;
    for (map, 0..) |row, y| {
        if (row[0] == null) break;
        for (row, 0..) |cell, x| {
            if (cell == null) break;
            if (cell.? != 0) continue;
            const trailOrigin = Coord{ .x = @intCast(x), .y = @intCast(y) };
            score += try scoringStrategy(map, trailOrigin, allocator);
        }
    }
    return score;
}

fn scoreTrailByPeaks(map: *const Map, trailOrigin: Coord, allocator: std.mem.Allocator) !u32 {
    var distinctHighestPoints = AutoHashMap(Coord, void).init(allocator);
    defer distinctHighestPoints.deinit();

    const highestPoints = try scoreCoordinate(map, trailOrigin, allocator);
    defer highestPoints.deinit();

    for (highestPoints.items) |coord| {
        try distinctHighestPoints.put(coord, {});
    }

    return @intCast(distinctHighestPoints.count());
}

fn scoreTrailByRoutes(map: *const Map, trailOrigin: Coord, allocator: std.mem.Allocator) !u32 {
    const highestPoints = try scoreCoordinate(map, trailOrigin, allocator);
    defer highestPoints.deinit();
    return @intCast(highestPoints.items.len);
}

fn scoreCoordinate(map: *const Map, coord: Coord, allocator: std.mem.Allocator) !ArrayList(Coord) {
    var highest_points = ArrayList(Coord).init(allocator);
    const currentVal = getValue(map, coord) orelse return highest_points;

    if (currentVal == MAX_HEIGHT) {
        try highest_points.append(coord);
        return highest_points;
    }

    for (directions) |direction| {
        const newCoordinate = Coord{ .x = coord.x + direction.dx, .y = coord.y + direction.dy };
        const newValue = getValue(map, newCoordinate);
        if (newValue == null or newValue.? != currentVal + 1) continue;
        var subPoints = try scoreCoordinate(map, newCoordinate, allocator);
        defer subPoints.deinit();
        try highest_points.appendSlice(subPoints.items);
    }
    return highest_points;
}
