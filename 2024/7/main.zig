const std = @import("std");
const assert = std.debug.assert;

const SHORTEST_POSSIBLE_MUL = 8;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    var buf: [4096]u8 = undefined;
    var total: i64 = 0;
    var in_do_section = true;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = std.mem.split(u8, line, ")");
        while (parts.next()) |part| {
            if (part.len >= 3 and std.mem.eql(u8, part[part.len - 3 ..], "do(")) {
                in_do_section = true;
                continue;
            }
            if (part.len >= 6 and std.mem.eql(u8, part[part.len - 6 ..], "don't(")) {
                in_do_section = false;
                continue;
            }
            if (in_do_section) {
                if (part.len < SHORTEST_POSSIBLE_MUL) continue;
                total += (try processSection(part)) orelse 0;
            }
        }
    }
    std.debug.print("Total: {}\n", .{total});
}

fn processSection(line: []const u8) !?i64 {
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
                    return null;
                }
                is_second_arg = true;
            },
            '(' => {
                if (cursor < 3) {
                    return null;
                }
                if (!std.mem.eql(u8, line[cursor - 3 .. cursor], "mul")) {
                    return null;
                }
                if (!is_second_arg) {
                    return null;
                }
                return try mul(first_argument.items, second_argument.items);
            },
            else => return null,
        }
        cursor -= 1;
    }
    return null;
}

pub fn mul(first_argument: []const u8, second_argument: []const u8) !i64 {
    const a = try std.fmt.parseInt(i64, first_argument, 10);
    const b = try std.fmt.parseInt(i64, second_argument, 10);
    return a * b;
}
