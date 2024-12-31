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

    var grid = try allocator.alloc([]u8, @intCast(y));
    for (0..@intCast(y)) |i| {
        grid[i] = try allocator.alloc(u8, @intCast(max_x + 1));
        @memset(grid[i], '.');
    }

    for (labeledCoords.items) |labeled_coord| {
        grid[@intCast(labeled_coord.coord.y)][@intCast(labeled_coord.coord.x)] = labeled_coord.label;
    }

    var antiNodes = try calcAntiNodesForAllCoordinates(allocator, labeledCoords.items);
    defer antiNodes.deinit();
    constrainToMap(&antiNodes, max_x, y - 1);
    std.debug.print("anti node count: {}\n", .{antiNodes.count()});

    var antiNodesIterator = antiNodes.iterator();

    while (antiNodesIterator.next()) |labeled_coord| {
        const coord = labeled_coord.key_ptr.*;
        grid[@intCast(coord.y)][@intCast(coord.x)] = '#';
    }

    for (grid) |row| {
        std.debug.print("{s}\n", .{row});
    }

    for (grid) |row| {
        allocator.free(row);
    }
    allocator.free(grid);
}

fn constrainToMap(map: *std.AutoHashMap(Coords, void), max_x: i64, max_y: i64) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        const coord = entry.key_ptr.*;
        if (coord.x < 0 or coord.x > max_x or coord.y < 0 or coord.y > max_y) {
            _ = map.remove(coord);
        }
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

fn calcAntiNodesForAllCoordinates(allocator: std.mem.Allocator, labeledCoords: []const LabeledCoords) !std.AutoHashMap(Coords, void) {
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
        const coords = try calcAntiNodesForCoordinateSet(allocator, coordinates.items);
        defer allocator.free(coords);

        for (coords) |coord| {
            try coordinateHashMap.put(coord, {});
        }
    }

    return coordinateHashMap;
}

fn calcAntiNodesForCoordinatePair(coords: [2]Coords) [2]Coords {
    return .{
        .{ .x = 2 * coords[0].x - coords[1].x, .y = 2 * coords[0].y - coords[1].y },
        .{ .x = 2 * coords[1].x - coords[0].x, .y = 2 * coords[1].y - coords[0].y },
    };
}

fn calcAntiNodesForCoordinateSet(allocator: std.mem.Allocator, coords: []const Coords) ![]Coords {
    var result = std.ArrayList(Coords).init(allocator);
    errdefer result.deinit();

    for (coords, 0..) |firstCoordinate, i| {
        for (coords[i + 1 ..]) |secondCoordinate| {
            const antiNodes = calcAntiNodesForCoordinatePair(.{ firstCoordinate, secondCoordinate });
            try result.appendSlice(&antiNodes);
        }
    }

    return result.toOwnedSlice();
}
