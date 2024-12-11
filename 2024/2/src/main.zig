const std = @import("std");
const assert = std.debug.assert;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    // part 1
    try processFile(reader, 0);

    try file.seekTo(0);

    // part 2
    try processFile(reader, 1);
}

fn processFile(reader: anytype, dampened_levels: i8) !void {
    var buf: [1024]u8 = undefined;
    var safe_report_count: u32 = 0;
    var unsafe_report_count: u32 = 0;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var numbers = std.ArrayList(i16).init(std.heap.page_allocator);
        defer numbers.deinit();

        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        while (iter.next()) |num_str| {
            const num = try std.fmt.parseInt(i16, num_str, 10);
            try numbers.append(num);
        }

        if (try is_safe(&numbers, dampened_levels)) {
            safe_report_count += 1;
        } else {
            unsafe_report_count += 1;
        }
    }
    std.debug.print("safe reports: {}, unsafe reports: {}\n", .{ safe_report_count, unsafe_report_count });
}

fn is_safe(numbers: *std.ArrayList(i16), dampened_levels: i8) !bool {
    if (numbers.items.len < 2) return error.InsufficientNumbers;

    const multiplier: i16 = if (numbers.items[0] > numbers.items[1]) -1 else 1;

    var i: usize = 1;
    while (i < numbers.items.len) : (i += 1) {
        const difference = @as(i16, (numbers.items[i] - numbers.items[i - 1])) * multiplier;
        if (difference > 3 or difference <= 0) {
            if (dampened_levels <= 0) {
                return false;
            }

            var j: usize = 0;
            while (j < numbers.items.len) : (j += 1) {
                var variation = try numbers.clone();
                defer variation.deinit();
                _ = variation.orderedRemove(j);

                if (try is_safe(&variation, dampened_levels - 1)) {
                    return true;
                }
            }
            return false;
        }
    }
    return true;
}
