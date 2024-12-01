const std = @import("std");
const assert = std.debug.assert;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var first_list = std.ArrayList(i32).init(allocator);
    defer first_list.deinit();
    var second_list = std.ArrayList(i32).init(allocator);
    defer second_list.deinit();

    // load into lists
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var iter = std.mem.split(u8, line, "   ");

        const first = try std.fmt.parseInt(i32, iter.next() orelse return error.InsufficientInput, 10);
        const second = try std.fmt.parseInt(i32, iter.next() orelse return error.InsufficientInput, 10);

        if (iter.next() != null) {
            return error.ExcessiveInput;
        }

        try first_list.append(first);
        try second_list.append(second);
    }

    // Part 1

    // sort lists
    std.mem.sort(i32, first_list.items, {}, std.sort.asc(i32));
    std.mem.sort(i32, second_list.items, {}, std.sort.asc(i32));

    // sum differences
    var sum: u32 = 0;
    for (first_list.items, second_list.items) |a, b| {
        sum += @abs(a - b);
    }

    std.debug.print("Total sum of differences {any}\n", .{sum});

    // Part 2

    // second list goes into a hash map
    var location_counts = std.AutoHashMap(i32, i32).init(allocator);
    defer location_counts.deinit();

    // Count the items from second_list
    for (second_list.items) |item| {
        const result = try location_counts.getOrPut(item);
        if (!result.found_existing) {
            result.value_ptr.* = 1;
        } else {
            result.value_ptr.* += 1;
        }
    }

    var total_difference: i64 = 0;
    for (first_list.items) |item| {
        const count = location_counts.get(item) orelse 0;
        const difference = item * count;
        total_difference += difference;
    }

    std.debug.print("Difference score: {any}\n", .{total_difference});
}
