const std = @import("std");
const assert = std.debug.assert;

pub const Direction = enum {
    North,
    South,
    East,
    West,
};

pub const Cell = union(enum) {
    Empty,
    Obstacle,
};

pub const CoordinatePair = struct { x: usize, y: usize };

pub const Map = struct {
    data: [][]Cell,
    allocator: std.mem.Allocator,
    guardLocation: CoordinatePair,
    guardDirection: Direction,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Map {
        const data = try allocator.alloc([]Cell, rows + 1);
        errdefer allocator.free(data);

        for (data) |*row| {
            row.* = try allocator.alloc(Cell, cols + 1);
            @memset(row.*, .Empty);
        }

        return Map{
            .data = data,
            .allocator = allocator,
            .guardLocation = .{ .x = 0, .y = 0 },
            .guardDirection = .North,
        };
    }

    pub fn deinit(self: *Map) void {
        for (self.data) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.data);
        self.* = undefined;
    }

    pub fn setGuard(self: *Map, coordinates: CoordinatePair, direction: Direction) !void {
        if (self.get(coordinates) == Cell.Obstacle) {
            return error.OccupiedSpace;
        }
        self.guardLocation = coordinates;
        self.guardDirection = direction;
    }

    pub fn loadObstacle(self: *Map, coordinates: CoordinatePair) !void {
        if (coordinates.x == self.guardLocation.x and coordinates.y == self.guardLocation.y) {
            return error.OccupiedSpace;
        }
        if (self.get(coordinates) == Cell.Obstacle) {
            return error.OccupiedSpace;
        }
        self.set(coordinates, Cell.Obstacle);
    }

    pub fn clearObstacle(self: *Map, coordinates: CoordinatePair) !void {
        if (self.get(coordinates) != Cell.Obstacle) {
            return error.InvalidAction;
        }
        self.set(coordinates, Cell.Empty);
    }

    pub fn solveForDiscretePositions(self: *Map) !usize {
        var seen = std.AutoHashMap(struct { x: usize, y: usize }, void).init(self.allocator);
        defer seen.deinit();
        while (self.step()) |stepDetails| {
            const coord = stepDetails[0];
            try seen.put(.{ .x = coord.x, .y = coord.y }, {});
        }
        return seen.count();
    }

    pub fn testForLoop(self: *Map) !bool {
        var seen = std.AutoHashMap(struct { CoordinatePair, Direction }, void).init(self.allocator);
        defer seen.deinit();
        while (self.step()) |stepDetails| {
            const coord = stepDetails[0];
            const direction = stepDetails[1];
            const result = try seen.getOrPut(.{ coord, direction });
            if (result.found_existing) {
                return true;
            }
        }
        return false;
    }

    pub fn solveForLoop(self: *Map) !i64 {
        const currentGuardDirection = self.guardDirection;
        const currentGuardLocation = self.guardLocation;
        var count: i64 = 0;
        for (0..self.numCols()) |x| {
            for (0..self.numRows()) |y| {
                const newObstacle = .{ .x = x, .y = y };
                self.loadObstacle(newObstacle) catch continue;
                if (try self.testForLoop()) {
                    count += 1;
                }
                try self.clearObstacle(newObstacle);
                try self.setGuard(currentGuardLocation, currentGuardDirection);
            }
        }
        return count;
    }

    fn step(self: *Map) ?struct { CoordinatePair, Direction } {
        const nextCoordinates = self.getNextCoordinates() catch return null;
        if (self.evaluateMove(nextCoordinates)) {
            self.guardProceed(nextCoordinates);
        } else {
            self.guardRotate();
        }
        return .{ self.guardLocation, self.guardDirection };
    }

    fn guardProceed(self: *Map, newCoordinates: CoordinatePair) void {
        self.guardLocation = newCoordinates;
    }

    fn guardRotate(self: *Map) void {
        self.guardDirection = switch (self.guardDirection) {
            .North => .East,
            .East => .South,
            .South => .West,
            .West => .North,
        };
    }

    fn getNextCoordinates(self: *const Map) !CoordinatePair {
        switch (self.guardDirection) {
            .North => {
                if (self.guardLocation.y == 0) return error.OutOfBounds;
                return .{ .x = self.guardLocation.x, .y = self.guardLocation.y - 1 };
            },
            .South => {
                if (self.guardLocation.y == self.numRows() - 1) return error.OutOfBounds;
                return .{ .x = self.guardLocation.x, .y = self.guardLocation.y + 1 };
            },
            .East => {
                if (self.guardLocation.x == self.numCols() - 1) return error.OutOfBounds;
                return .{ .x = self.guardLocation.x + 1, .y = self.guardLocation.y };
            },
            .West => {
                if (self.guardLocation.x == 0) return error.OutOfBounds;
                return .{ .x = self.guardLocation.x - 1, .y = self.guardLocation.y };
            },
        }
    }

    fn evaluateMove(self: *const Map, coordinates: CoordinatePair) bool {
        return self.get(coordinates) != Cell.Obstacle;
    }

    fn get(self: *const Map, coordinates: CoordinatePair) Cell {
        return self.data[coordinates.y][coordinates.x];
    }

    fn set(self: *Map, coordinates: CoordinatePair, value: Cell) void {
        self.data[coordinates.y][coordinates.x] = value;
    }

    fn numRows(self: Map) usize {
        return self.data.len;
    }

    fn numCols(self: Map) usize {
        if (self.data.len == 0) return 0;
        return self.data[0].len;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var rows: usize = 0;
    var cols: usize = 0;

    var guardLocation: CoordinatePair = undefined;
    var guardDirection: Direction = undefined;
    var obstacles = std.ArrayList(CoordinatePair).init(allocator);
    var line_buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        rows += 1;
        cols = @max(cols, line.len);
        for (line, 0..) |char, col| {
            const pos = .{ .x = col, .y = rows };
            switch (char) {
                '#' => try obstacles.append(pos),
                '<' => {
                    guardLocation = pos;
                    guardDirection = .West;
                },
                '>' => {
                    guardLocation = pos;
                    guardDirection = .East;
                },
                '^' => {
                    guardLocation = pos;
                    guardDirection = .North;
                },
                'V', 'v' => {
                    guardLocation = pos;
                    guardDirection = .South;
                },
                else => {},
            }
        }
    }

    std.debug.print("Rows {}, Cols {}\n", .{ rows, cols });

    var map = try Map.init(allocator, rows, cols);
    defer map.deinit();
    for (obstacles.items) |obstacle| {
        try map.loadObstacle(obstacle);
    }
    try map.setGuard(guardLocation, guardDirection);

    const steps = map.solveForDiscretePositions();
    std.debug.print("Number of discrete steps: {any}\n", .{steps});

    try map.setGuard(guardLocation, guardDirection);
    const loopCount = map.solveForLoop();
    std.debug.print("Number of possible loops: {any}\n", .{loopCount});
}
