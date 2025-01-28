const std = @import("std");

pub fn main() !void {
    while (true) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        // Process the command...
        var iter = std.mem.splitScalar(u8, user_input, ' ');
        const command = iter.first();
        if (std.mem.eql(u8, command, "exit")) {
            _ = iter.next();
            const exit_code = try std.fmt.parseInt(u8, iter.next() orelse "0", 10);
            std.process.exit(exit_code);
            break;
        } else if (std.mem.eql(u8, command, "echo")) {
            try stdout.print("{s}\n", .{iter.rest()});
            continue;
        }

        const stderr = std.io.getStdErr().writer();
        try stderr.print("{s}: command not found\n", .{user_input});
    }
}
