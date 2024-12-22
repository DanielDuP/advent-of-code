const std = @import("std");
const assert = std.debug.assert;

const NumberType = u32;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var ruleSet = std.ArrayList([2]NumberType).init(std.heap.page_allocator);
    defer ruleSet.deinit();
    var middleTermSum: NumberType = 0;

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.indexOfScalar(u8, line, '|')) |_| {
            const rule = try parseRuleSet(line);
            try ruleSet.append(rule);
        } else {
            middleTermSum += try assessLine(line, ruleSet);
        }
    }

    std.debug.print("Middle Term Sum: {}\n", .{middleTermSum});
}

fn parseRuleSet(input: []const u8) ![2]NumberType {
    var iter = std.mem.splitScalar(u8, input, '|');
    const first = iter.next() orelse return error.InvalidInput;
    const second = iter.next() orelse return error.InvalidInput;
    return [2]NumberType{
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, first, " "), 10),
        try std.fmt.parseInt(NumberType, std.mem.trim(u8, second, " "), 10),
    };
}

fn testRuleSet(input: []const NumberType, ruleSet: [2]NumberType) bool {
    var first_index: ?usize = null;
    var second_index: ?usize = null;

    for (input, 0..) |value, index| {
        if (value == ruleSet[0] and first_index == null) {
            first_index = index;
        } else if (value == ruleSet[1] and second_index == null) {
            second_index = index;
        }
    }

    if (first_index == null or second_index == null) {
        return true;
    }

    return first_index.? < second_index.?;
}

fn assessLine(input: []const u8, ruleSet: std.ArrayList([2]NumberType)) !NumberType {
    var numbers = std.ArrayList(NumberType).init(std.heap.page_allocator);
    defer numbers.deinit();

    var it = std.mem.tokenize(u8, input, ",");
    while (it.next()) |numStr| {
        const num = try std.fmt.parseInt(NumberType, numStr, 10);
        try numbers.append(num);
    }

    if (numbers.items.len == 0) {
        return 0;
    }

    for (ruleSet.items) |rule| {
        if (!testRuleSet(numbers.items, rule)) {
            return 0;
        }
    }

    return returnMiddleTerm(numbers.items);
}

fn returnMiddleTerm(input: []const NumberType) NumberType {
    return input[input.len / 2];
}
