const std = @import("std");
const assert = std.debug.assert;

fn calculateTotalSumOfDifferences(first_list: std.ArrayList(i32), second_list: std.ArrayList(i32)) u32 {
    assert(first_list.items.len == second_list.items.len);
    std.mem.sort(i32, first_list.items, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, second_list.items, {}, comptime std.sort.asc(i32));

    var sum: u32 = 0;
    for (first_list.items, second_list.items) |a, b| {
        sum += @abs(a - b);
    }
    return sum;
}

fn calculateDifferenceScore(first_list: std.ArrayList(i32), second_list: std.ArrayList(i32), allocator: std.mem.Allocator) !i64 {
    var location_counts = std.AutoHashMap(i32, i32).init(allocator);
    defer location_counts.deinit();

    for (second_list.items) |item| {
        const count = try location_counts.getOrPut(item);
        if (!count.found_existing) {
            count.value_ptr.* = 0;
        }
        count.value_ptr.* += 1;
    }

    var total_difference: i64 = 0;
    for (first_list.items) |item| {
        if (location_counts.get(item)) |count| {
            total_difference += @as(i64, item) * count;
        }
    }
    return total_difference;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // getting the lists
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var first_list = std.ArrayList(i32).init(allocator);
    var second_list = std.ArrayList(i32).init(allocator);

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        const first = try std.fmt.parseInt(i32, iter.next() orelse return error.InsufficientInput, 10);
        const second = try std.fmt.parseInt(i32, iter.next() orelse return error.InsufficientInput, 10);

        if (iter.next() != null) return error.ExcessiveInput;

        try first_list.append(first);
        try second_list.append(second);
    }

    // part 1
    const sum = calculateTotalSumOfDifferences(first_list, second_list);
    std.debug.print("Total sum of differences {}\n", .{sum});

    // part 2
    const total_difference = try calculateDifferenceScore(first_list, second_list, allocator);
    std.debug.print("Difference score: {}\n", .{total_difference});
}
