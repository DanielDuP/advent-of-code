const std = @import("std");
const assert = std.debug.assert;

const NumberType = u32;
const Rule = [2]NumberType;
const Sequence = []const NumberType;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var rules = std.ArrayList(Rule).init(allocator);
    defer rules.deinit();
    var valid_sequences = std.ArrayList(Sequence).init(allocator);
    defer valid_sequences.deinit();
    var invalid_sequences = std.ArrayList(Sequence).init(allocator);
    defer invalid_sequences.deinit();

    try processInputFile(reader, &rules, &valid_sequences, &invalid_sequences, allocator);

    const valid_sum = calculateMiddleTermSum(valid_sequences);
    std.debug.print("Middle Term Sum of Valid Sequences: {}\n", .{valid_sum});

    const corrected_sum = try calculateCorrectedMiddleTermSum(invalid_sequences, rules, allocator);
    std.debug.print("Middle Term Sum of Corrected Sequences: {}\n", .{corrected_sum});
}

fn processInputFile(reader: anytype, rules: *std.ArrayList(Rule), valid_sequences: *std.ArrayList(Sequence), invalid_sequences: *std.ArrayList(Sequence), allocator: std.mem.Allocator) !void {
    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.indexOfScalar(u8, line, '|')) |_| {
            const rule = try parseRule(line);
            try rules.append(rule);
        } else {
            try processSequence(line, rules.items, valid_sequences, invalid_sequences, allocator);
        }
    }
}

fn parseRule(input: []const u8) !Rule {
    var iter = std.mem.splitScalar(u8, input, '|');
    const first = iter.next() orelse return error.InvalidInput;
    const second = iter.next() orelse return error.InvalidInput;
    return Rule{
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, first, " "), 10),
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, second, " "), 10),
    };
}

fn isValidRule(sequence: Sequence, rule: Rule) bool {
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

fn enforceRule(sequence: Sequence, rule: Rule, allocator: std.mem.Allocator) !?Sequence {
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
                std.mem.swap(NumberType, &result[first_index.?], &result[second_index.?]);
                return result;
            } else {
                return null;
            }
        }
    }

    return null;
}

fn processSequence(input: []const u8, rules: []const Rule, valid_sequences: *std.ArrayList(Sequence), invalid_sequences: *std.ArrayList(Sequence), allocator: std.mem.Allocator) !void {
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

    const is_valid = for (rules) |rule| {
        if (!isValidRule(numbers.items, rule)) break false;
    } else true;

    const sequence = try numbers.toOwnedSlice();
    try if (is_valid) valid_sequences.append(sequence) else invalid_sequences.append(sequence);
}

fn calculateMiddleTermSum(sequences: std.ArrayList(Sequence)) NumberType {
    var sum: NumberType = 0;
    for (sequences.items) |sequence| {
        sum += sequence[sequence.len / 2];
    }
    return sum;
}

fn calculateCorrectedMiddleTermSum(sequences: std.ArrayList(Sequence), rules: std.ArrayList(Rule), allocator: std.mem.Allocator) !NumberType {
    var sum: NumberType = 0;
    for (sequences.items) |sequence| {
        const corrected_sequence = try correctSequence(sequence, rules, allocator);
        defer allocator.free(corrected_sequence);
        sum += corrected_sequence[corrected_sequence.len / 2];
    }
    return sum;
}

fn correctSequence(sequence: Sequence, rules: std.ArrayList(Rule), allocator: std.mem.Allocator) !Sequence {
    var current_sequence = try allocator.dupe(NumberType, sequence);
    errdefer allocator.free(current_sequence);

    var rule_applied = true;
    while (rule_applied) {
        rule_applied = false;
        for (rules.items) |rule| {
            if (try enforceRule(current_sequence, rule, allocator)) |new_sequence| {
                allocator.free(current_sequence);
                current_sequence = try allocator.dupe(NumberType, new_sequence);
                rule_applied = true;
                break;
            }
        }
    }

    return current_sequence;
}
