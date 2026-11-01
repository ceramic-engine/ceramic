const std = @import("std");

/// Doc comment.
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var sum: u32 = 0;
    for ([_]u32{ 1, 2, 3 }) |n| {
        sum += n * 0x10;
    }
    try stdout.print("sum = {d}\n", .{sum});
}
