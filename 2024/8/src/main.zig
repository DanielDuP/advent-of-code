const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

const Coords = struct {
    x: i64,
    y: i64,
};

const LabeledCoords = struct {
    coord: Coords,
    label: u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var line_buf: [2048]u8 = undefined;

    var labeledCoords = std.ArrayList(LabeledCoords).init(allocator);
    defer labeledCoords.deinit();

    var y: i64 = 0;
    var max_x: i64 = 0;
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        for (line, 0..) |char, x| {
            switch (char) {
                '.' => {},
                else => try labeledCoords.append(.{ .coord = .{ .x = @intCast(x), .y = y }, .label = char }),
            }
        }
        max_x = @intCast(line.len - 1);
        y += 1;
    }
    const max_y = y - 1;

    try processAntiNodes(allocator, labeledCoords.items, max_x, max_y, calcAntiNodePairForCoordinatePair, "Pair");
    try processAntiNodes(allocator, labeledCoords.items, max_x, max_y, calcAntiNodeSetForCoordinatePair, "Set");
}

fn processAntiNodes(allocator: std.mem.Allocator, labeledCoords: []const LabeledCoords, max_x: i64, max_y: i64, antiNodeCalculator: fn (allocator: std.mem.Allocator, coords: [2]Coords, max_x: i64, max_y: i64) anyerror![]Coords, strategy: []const u8) !void {
    var antiNodes = try calcAntiNodesForAllCoordinates(allocator, labeledCoords, max_x, max_y, antiNodeCalculator);
    defer antiNodes.deinit();
    std.debug.print("Anti node count ({s}): {}\n", .{ strategy, antiNodes.count() });

    try renderGrid(allocator, antiNodes, labeledCoords, max_x, max_y);
}

fn renderGrid(allocator: std.mem.Allocator, antiNodes: std.AutoHashMap(Coords, void), labeledCoords: []const LabeledCoords, max_x: i64, max_y: i64) !void {
    var grid = try allocator.alloc([]u8, @intCast(max_y + 1));
    defer {
        for (grid) |row| {
            allocator.free(row);
        }
        allocator.free(grid);
    }

    for (0..@intCast(max_y + 1)) |i| {
        grid[i] = try allocator.alloc(u8, @intCast(max_x + 1));
        @memset(grid[i], '.');
    }

    var antiNodesIterator = antiNodes.iterator();
    while (antiNodesIterator.next()) |labeled_coord| {
        const coord = labeled_coord.key_ptr.*;
        grid[@intCast(coord.y)][@intCast(coord.x)] = '#';
    }

    for (labeledCoords) |labeled_coord| {
        grid[@intCast(labeled_coord.coord.y)][@intCast(labeled_coord.coord.x)] = labeled_coord.label;
    }

    for (grid) |row| {
        std.debug.print("{s}\n", .{row});
    }
}

fn createLabelMap(allocator: std.mem.Allocator, labeledCoords: []const LabeledCoords) !std.AutoHashMap(u8, std.ArrayList(Coords)) {
    var labelMap = std.AutoHashMap(u8, std.ArrayList(Coords)).init(allocator);

    for (labeledCoords) |labeledCoordinatePair| {
        var coordList = try labelMap.getOrPut(labeledCoordinatePair.label);
        if (!coordList.found_existing) {
            coordList.value_ptr.* = std.ArrayList(Coords).init(allocator);
        }
        try coordList.value_ptr.append(labeledCoordinatePair.coord);
    }

    return labelMap;
}

fn calcAntiNodesForAllCoordinates(allocator: std.mem.Allocator, labeledCoords: []const LabeledCoords, max_x: i64, max_y: i64, antiNodeCalculator: fn (allocator: std.mem.Allocator, coords: [2]Coords, max_x: i64, max_y: i64) anyerror![]Coords) !std.AutoHashMap(Coords, void) {
    var coordinateHashMap = std.AutoHashMap(Coords, void).init(allocator);
    var labelMap = try createLabelMap(allocator, labeledCoords);
    defer {
        var labelIterator = labelMap.valueIterator();
        while (labelIterator.next()) |coordList| {
            coordList.deinit();
        }
        labelMap.deinit();
    }

    var labelIterator = labelMap.iterator();
    while (labelIterator.next()) |entry| {
        const coordinates = entry.value_ptr.*;
        const coords = try calcAntiNodesForCoordinateSet(allocator, coordinates.items, max_x, max_y, antiNodeCalculator);
        defer allocator.free(coords);

        for (coords) |coord| {
            try coordinateHashMap.put(coord, {});
        }
    }

    return coordinateHashMap;
}

fn calcAntiNodePairForCoordinatePair(allocator: std.mem.Allocator, coords: [2]Coords, max_x: i64, max_y: i64) ![]Coords {
    var result = std.ArrayList(Coords).init(allocator);
    errdefer result.deinit();

    for (coords, 0..) |coord, i| {
        const other = coords[1 - i];
        const anti = Coords{
            .x = 2 * coord.x - other.x,
            .y = 2 * coord.y - other.y,
        };
        if (anti.x >= 0 and anti.x <= max_x and anti.y >= 0 and anti.y <= max_y) {
            try result.append(anti);
        }
    }

    return result.toOwnedSlice();
}

fn calcAntiNodeSetForCoordinatePair(allocator: std.mem.Allocator, coords: [2]Coords, max_x: i64, max_y: i64) ![]Coords {
    var result = std.ArrayList(Coords).init(allocator);
    errdefer result.deinit();

    const dx = coords[0].x - coords[1].x;
    const dy = coords[0].y - coords[1].y;

    const movementPatterns = [_][2]i64{ .{ dx, dy }, .{ -dx, -dy } };

    outer: for (movementPatterns) |pattern| {
        var current_x = coords[0].x;
        var current_y = coords[0].y;

        while (true) {
            current_x += pattern[0];
            current_y += pattern[1];

            if (current_x < 0 or current_x > max_x or current_y < 0 or current_y > max_y) {
                continue :outer;
            }

            try result.append(.{ .x = current_x, .y = current_y });
        }
    }

    try result.appendSlice(&coords);

    return result.toOwnedSlice();
}

fn calcAntiNodesForCoordinateSet(allocator: std.mem.Allocator, coords: []const Coords, max_x: i64, max_y: i64, antiNodeCalculator: fn (allocator: std.mem.Allocator, coords: [2]Coords, max_x: i64, max_y: i64) anyerror![]Coords) ![]Coords {
    var result = std.ArrayList(Coords).init(allocator);
    errdefer result.deinit();

    for (coords, 0..) |firstCoordinate, i| {
        for (coords[i + 1 ..]) |secondCoordinate| {
            const antiNodes = try antiNodeCalculator(allocator, .{ firstCoordinate, secondCoordinate }, max_x, max_y);
            defer allocator.free(antiNodes);
            try result.appendSlice(antiNodes);
        }
    }

    return result.toOwnedSlice();
}
