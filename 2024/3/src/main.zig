const std = @import("std");
const assert = std.debug.assert;

const SHORTEST_POSSIBLE_MUL = 8;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var buf: [1024]u8 = undefined;
    var total: i64 = 0;
    file_read: while (try reader.readUntilDelimiterOrEof(&buf, ')')) |line| {
        if (line.len < SHORTEST_POSSIBLE_MUL) continue :file_read;
        var cursor = line.len - 1;
        var first_argument = std.ArrayList(u8).init(std.heap.page_allocator);
        defer first_argument.deinit();
        var second_argument = std.ArrayList(u8).init(std.heap.page_allocator);
        defer second_argument.deinit();
        var is_second_arg = false;
        while (cursor > 0) {
            const current_char = line[cursor];
            switch (current_char) {
                '0'...'9' => {
                    if (is_second_arg) {
                        try second_argument.insert(0, current_char);
                    } else {
                        try first_argument.insert(0, current_char);
                    }
                },
                ',' => {
                    if (is_second_arg) {
                        continue :file_read;
                    }
                    is_second_arg = true;
                },
                '(' => {
                    if (cursor < 3) {
                        continue :file_read;
                    }
                    if (!std.mem.eql(u8, line[cursor - 3 .. cursor], "mul")) {
                        continue :file_read;
                    }
                    if (!is_second_arg) {
                        continue :file_read;
                    }
                    total += try mul(first_argument.items, second_argument.items);
                    continue :file_read;
                },
                else => continue :file_read,
            }
            cursor -= 1;
        }
    }
    std.debug.print("Total: {}\n", .{total});
}

pub fn mul(first_argument: []const u8, second_argument: []const u8) !i64 {
    const a = try std.fmt.parseInt(i64, first_argument, 10);
    const b = try std.fmt.parseInt(i64, second_argument, 10);
    return a * b;
}
