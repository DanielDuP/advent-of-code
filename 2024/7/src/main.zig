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

    var basicCount: u64 = 0;
    var advancedCount: u64 = 0;

    var terms = std.ArrayList(u64).init(allocator);
    defer terms.deinit();

    const basicOperators = [_]Operation{ .MULTIPLICATION, .ADDITION };
    const advancedOperators = [_]Operation{ .MULTIPLICATION, .ADDITION, .CONCATENATION };

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        terms.clearRetainingCapacity();
        var splitLine = std.mem.split(u8, line, ":");
        const target = try std.fmt.parseInt(u64, splitLine.next() orelse return error.InsufficientInput, 10);
        var termIterator = std.mem.tokenizeScalar(u8, splitLine.next() orelse return error.InsufficientInput, ' ');
        while (termIterator.next()) |term| {
            try terms.append(try std.fmt.parseInt(u64, term, 10));
        }
        if (try testSequence(terms.items, target, &basicOperators, allocator)) {
            basicCount += target;
        }
        if (try testSequence(terms.items, target, &advancedOperators, allocator)) {
            advancedCount += target;
        }
    }

    std.debug.print("basic count: {}\n", .{basicCount});
    std.debug.print("advanced count: {}\n", .{advancedCount});
}

test {
    const allocator = testing.allocator;

    const TestCase = struct {
        terms: []const u64,
        target: u64,
        expected: bool,
    };

    const testCases = [_]TestCase{
        .{ .terms = &[_]u64{ 81, 40, 27 }, .target = 3267, .expected = true },
        .{ .terms = &[_]u64{ 11, 6, 16, 20 }, .target = 292, .expected = true },
        .{ .terms = &[_]u64{ 9, 7, 18, 13 }, .target = 21037, .expected = false },
        .{ .terms = &[_]u64{ 16, 10, 13 }, .target = 161011, .expected = false },
    };

    const operators = [_]Operation{ .MULTIPLICATION, .ADDITION };

    for (testCases) |tc| {
        std.debug.print("Testing case: terms={any}, target={}\n", .{ tc.terms, tc.target });
        const result = try testSequence(tc.terms, tc.target, &operators, allocator);
        try testing.expectEqual(tc.expected, result);
    }
}

const Operation = enum { MULTIPLICATION, ADDITION, CONCATENATION };

const TermArray = []const u64;

fn apply(terms: TermArray, operation: Operation, allocator: std.mem.Allocator) !TermArray {
    assert(terms.len >= 2);
    const term1 = terms[0];
    const term2 = terms[1];
    const result: u64 = switch (operation) {
        .MULTIPLICATION => term1 * term2,
        .ADDITION => term1 + term2,
        .CONCATENATION => blk: {
            const shift = @as(u6, @intCast(std.math.log10_int(term2) + 1));
            break :blk (term1 * std.math.pow(u64, 10, shift)) + term2;
        },
    };

    var new_terms = try ArrayList(u64).initCapacity(allocator, terms.len - 1);
    errdefer new_terms.deinit();

    try new_terms.append(result);
    try new_terms.appendSlice(terms[2..]);

    return new_terms.toOwnedSlice();
}

fn testSequence(terms: TermArray, target: u64, operators: []const Operation, allocator: std.mem.Allocator) !bool {
    if (terms.len == 1) {
        return terms[0] == target;
    }

    for (operators) |op| {
        const result = try apply(terms, op, allocator);
        defer allocator.free(result);

        if (try testSequence(result, target, operators, allocator)) return true;
    }

    return false;
}
