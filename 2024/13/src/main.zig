const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

const BUTTON_A_PRICE = 3;
const BUTTON_B_PRICE = 1;

const MAX_INT = @as(i64, std.math.maxInt(i64));

const Button = struct { price: i64, delta: Delta, presses: i64 = 0 };

const Delta = struct {
    x: i64,
    y: i64,
};

const Coords = struct {
    x: i64,
    y: i64,

    fn init(x: i64, y: i64) Coords {
        return .{
            .x = x,
            .y = y,
        };
    }

    fn outOfBounds(self: Coords) bool {
        return self.x < 0 or self.y < 0;
    }

    fn atOrigin(self: Coords) bool {
        return self.x == 0 and self.y == 0;
    }

    fn shift(self: Coords, delta: Delta) Coords {
        return .{
            .x = self.x - delta.x,
            .y = self.y - delta.y,
        };
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;

    var total_price: i64 = 0;

    var line_count: usize = 0;
    var lines: [4][]const u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        lines[line_count] = try allocator.dupe(u8, line);
        line_count += 1;
        if (line_count == 4) {
            var buttons = [_]Button{
                try line_to_button(lines[0], BUTTON_A_PRICE),
                try line_to_button(lines[1], BUTTON_B_PRICE),
            };
            const prize_coords = try line_to_prize_coords(lines[2]);
            if (try calc(allocator, prize_coords, &buttons)) |price| {
                total_price += price;
            }

            line_count = 0;
        }
    }

    std.debug.print("Total price: {}\n", .{total_price});
}

fn line_to_button(line: []const u8, price: i64) !Button {
    var parts = std.mem.tokenize(u8, line, " +XYButonA,:");
    return Button{ .price = price, .delta = .{
        .x = try std.fmt.parseInt(i64, parts.next().?, 10),
        .y = try std.fmt.parseInt(i64, parts.next().?, 10),
    } };
}

test "line_to_button" {
    const input = "Button A: X+94, Y+34";
    const expected = Button{ .price = BUTTON_A_PRICE, .delta = .{ .x = 94, .y = 34 } };
    const result = try line_to_button(input, BUTTON_A_PRICE);
    try std.testing.expectEqual(expected, result);
}

fn line_to_prize_coords(line: []const u8) !Coords {
    var parts = std.mem.tokenize(u8, line, "Prize: X=,Y");
    return Coords{
        .x = try std.fmt.parseInt(i64, parts.next().?, 10),
        .y = try std.fmt.parseInt(i64, parts.next().?, 10),
    };
}

test "line_to_prize_coords" {
    const input = "Prize: X=8400, Y=5400";
    const expected = Coords{ .x = 8400, .y = 5400 };
    const result = try line_to_prize_coords(input);
    try std.testing.expectEqual(expected, result);
}

fn calc_from_position(pos: Coords, button_set: []Button, cache: *std.AutoHashMap(Coords, i64)) !i64 {
    if (pos.outOfBounds()) {
        return MAX_INT;
    }
    if (pos.atOrigin()) {
        return 0;
    }

    if (cache.get(pos)) |cached_value| {
        return cached_value;
    }

    var best_attempt = MAX_INT;
    for (button_set) |*button| {
        assert(button.presses <= 100);
        if (button.presses == 100) {
            continue;
        }
        button.presses += 1;
        const new_pos = pos.shift(button.delta);
        const attempt = try calc_from_position(new_pos, button_set, cache);
        if (attempt != MAX_INT) {
            best_attempt = @min(best_attempt, attempt + button.price);
        }
        button.presses -= 1;
    }

    try cache.put(pos, best_attempt);
    return best_attempt;
}

fn calc(allocator: std.mem.Allocator, target_position: Coords, button_set: []Button) !?i64 {
    var cache = std.AutoHashMap(Coords, i64).init(allocator);
    defer cache.deinit();
    const lowest_route_price = try calc_from_position(target_position, button_set, &cache);
    if (lowest_route_price == MAX_INT) return null;
    return lowest_route_price;
}

const expect = std.testing.expect;

test "calc" {
    const testCases = [_]struct {
        name: []const u8,
        target: Coords,
        buttons: [2]Button,
        expected: ?i64,
    }{
        .{
            .name = "Case 1",
            .target = Coords.init(5, 5),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 5, .y = 5 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 100, .y = 100 } },
            },
            .expected = BUTTON_A_PRICE,
        },
        .{
            .name = "Case 2",
            .target = Coords.init(5, 5),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 100, .y = 100 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 5, .y = 5 } },
            },
            .expected = BUTTON_B_PRICE,
        },
        .{
            .name = "Case 3",
            .target = Coords.init(14, 14),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 1, .y = 1 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 5, .y = 5 } },
            },
            .expected = BUTTON_B_PRICE * 2 + BUTTON_A_PRICE * 4,
        },
        .{
            .name = "Case 4",
            .target = Coords.init(8400, 5400),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 94, .y = 34 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 22, .y = 67 } },
            },
            .expected = 280,
        },
        .{
            .name = "Case 5",
            .target = Coords.init(12748, 12176),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 26, .y = 66 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 67, .y = 21 } },
            },
            .expected = null,
        },
        .{
            .name = "Case 6",
            .target = Coords.init(7870, 6450),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 17, .y = 86 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 84, .y = 37 } },
            },
            .expected = 200,
        },
        .{
            .name = "Case 7",
            .target = Coords.init(18641, 10279),
            .buttons = [_]Button{
                .{ .price = BUTTON_A_PRICE, .delta = .{ .x = 69, .y = 23 } },
                .{ .price = BUTTON_B_PRICE, .delta = .{ .x = 27, .y = 71 } },
            },
            .expected = null,
        },
    };

    for (testCases) |tc| {
        var buttons = tc.buttons;
        const result = try calc(testing.allocator, tc.target, &buttons);
        try expect(result == tc.expected);
    }
}
