const std = @import("std");
const assert = std.debug.assert;

const NumberType = u32;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rules = std.ArrayList([2]NumberType).init(allocator);
    defer rules.deinit();
    var validSequences = std.ArrayList([]const NumberType).init(allocator);
    defer validSequences.deinit();
    var invalidSequences = std.ArrayList([]const NumberType).init(allocator);
    defer invalidSequences.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.indexOfScalar(u8, line, '|')) |_| {
            const rule = try parseRule(line);
            try rules.append(rule);
        } else {
            try processSequence(line, rules, &validSequences, &invalidSequences, allocator);
        }
    }

    const validSum = calculateMiddleTermSum(validSequences);
    std.debug.print("Middle Term Sum of Valid Sequences: {}\n", .{validSum});

    const correctedSum = try calculateCorrectedMiddleTermSum(invalidSequences, rules, allocator);
    std.debug.print("Middle Term Sum of Corrected Sequences: {}\n", .{correctedSum});
}

fn parseRule(input: []const u8) ![2]NumberType {
    var iter = std.mem.splitScalar(u8, input, '|');
    const first = iter.next() orelse return error.InvalidInput;
    const second = iter.next() orelse return error.InvalidInput;
    return [2]NumberType{
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, first, " "), 10),
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, second, " "), 10),
    };
}

fn isValidRule(sequence: []const NumberType, rule: [2]NumberType) bool {
    var first_index: ?usize = null;
    var second_index: ?usize = null;

    for (sequence, 0..) |value, index| {
        if (value == rule[0] and first_index == null) {
            first_index = index;
        } else if (value == rule[1] and second_index == null) {
            second_index = index;
        }
    }

    return (first_index == null or second_index == null) or (first_index.? < second_index.?);
}

fn enforceRule(sequence: []const NumberType, rule: [2]NumberType, allocator: std.mem.Allocator) !?[]NumberType {
    var result = try allocator.dupe(NumberType, sequence);
    errdefer allocator.free(result);

    var first_index: ?usize = null;
    var second_index: ?usize = null;

    for (sequence, 0..) |value, index| {
        if (value == rule[0]) {
            first_index = index;
        } else if (value == rule[1]) {
            second_index = index;
        }

        if (first_index != null and second_index != null) {
            if (first_index.? > second_index.?) {
                result[first_index.?] = sequence[second_index.?];
                result[second_index.?] = sequence[first_index.?];
                return result;
            } else {
                return null;
            }
        }
    }

    return null;
}

fn processSequence(input: []const u8, rules: std.ArrayList([2]NumberType), validSequences: *std.ArrayList([]const NumberType), invalidSequences: *std.ArrayList([]const NumberType), allocator: std.mem.Allocator) !void {
    var numbers = std.ArrayList(NumberType).init(allocator);
    defer numbers.deinit();

    var it = std.mem.tokenize(u8, input, ",");
    while (it.next()) |numStr| {
        const num = try std.fmt.parseInt(NumberType, numStr, 10);
        try numbers.append(num);
    }

    if (numbers.items.len == 0) {
        return;
    }

    const isValid = for (rules.items) |rule| {
        if (!isValidRule(numbers.items, rule)) break false;
    } else true;

    if (isValid) {
        try validSequences.append(try numbers.toOwnedSlice());
    } else {
        try invalidSequences.append(try numbers.toOwnedSlice());
    }
}

fn calculateMiddleTermSum(sequences: std.ArrayList([]const NumberType)) NumberType {
    var sum: NumberType = 0;
    for (sequences.items) |sequence| {
        sum += sequence[sequence.len / 2];
    }
    return sum;
}

// this is really ugly, but hey, it worked first time I tried it, so I'm moving on
fn calculateCorrectedMiddleTermSum(sequences: std.ArrayList([]const NumberType), rules: std.ArrayList([2]NumberType), allocator: std.mem.Allocator) !NumberType {
    var sum: NumberType = 0;
    for (sequences.items) |sequence| {
        var correctedSequence = sequence;
        var ruleApplied = true;
        while (ruleApplied) {
            ruleApplied = false;
            for (rules.items) |rule| {
                if (try enforceRule(correctedSequence, rule, allocator)) |newSequence| {
                    correctedSequence = newSequence;
                    ruleApplied = true;
                    break;
                }
            }
        }
        sum += correctedSequence[correctedSequence.len / 2];
    }
    return sum;
}
