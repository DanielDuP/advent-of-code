const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var line_buf: [2048]u8 = undefined;

    var count: i64 = 0;

    var terms = std.ArrayList(i64).init(allocator);
    defer terms.deinit();

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        terms.clearRetainingCapacity();
        var splitLine = std.mem.split(u8, line, ":");
        const target = try std.fmt.parseInt(i64, splitLine.next() orelse return error.InsufficientInput, 10);
        var termIterator = std.mem.tokenizeScalar(u8, splitLine.next() orelse return error.InsufficientInput, ' ');
        while (termIterator.next()) |term| {
            try terms.append(try std.fmt.parseInt(i64, term, 10));
        }
        if (try testSequence(terms.items, target, allocator)) {
            count += target;
        }
    }

    std.debug.print("Count: {}\n", .{count});
}

test {
    const allocator = testing.allocator;

    const TestCase = struct {
        terms: []const i64,
        target: i64,
        expected: bool,
    };

    const testCases = [_]TestCase{
        .{ .terms = &[_]i64{ 81, 40, 27 }, .target = 3267, .expected = true },
        .{ .terms = &[_]i64{ 11, 6, 16, 20 }, .target = 292, .expected = true },
        .{ .terms = &[_]i64{ 9, 7, 18, 13 }, .target = 21037, .expected = false },
        .{ .terms = &[_]i64{ 16, 10, 13 }, .target = 161011, .expected = false },
    };

    for (testCases) |tc| {
        std.debug.print("Testing case: terms={any}, target={}\n", .{ tc.terms, tc.target });
        const result = try testSequence(tc.terms, tc.target, allocator);
        try testing.expectEqual(tc.expected, result);
    }
}

const Operation = enum {
    MULTIPLICATION,
    ADDITION,
};

const TermArray = []const i64;

fn apply(terms: TermArray, operation: Operation, allocator: std.mem.Allocator) !TermArray {
    assert(terms.len >= 2);
    const term1 = terms[0];
    const term2 = terms[1];
    const result = switch (operation) {
        .MULTIPLICATION => term1 * term2,
        .ADDITION => term1 + term2,
    };

    var new_terms = try ArrayList(i64).initCapacity(allocator, terms.len - 1);
    errdefer new_terms.deinit();

    try new_terms.append(result);
    try new_terms.appendSlice(terms[2..]);

    return new_terms.toOwnedSlice();
}

fn testSequence(terms: TermArray, target: i64, allocator: std.mem.Allocator) !bool {
    if (terms.len == 1) {
        return terms[0] == target;
    }

    const mult_result = try apply(terms, .MULTIPLICATION, allocator);
    defer allocator.free(mult_result);

    if (try testSequence(mult_result, target, allocator)) return true;

    const add_result = try apply(terms, .ADDITION, allocator);
    defer allocator.free(add_result);

    return try testSequence(add_result, target, allocator);
}
