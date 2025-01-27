const std = @import("std");

pub fn main() !void {
    // Uncomment this block to pass the first stage
    const stdout = std.io.getStdOut().writer();
    try stdout.print("$ ", .{});

    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

    // TODO: Handle user input

    const stderr = std.io.getStdErr().writer();
    try stderr.print("{s}: command not found\n", .{user_input});
}
