const std = @import("std");
const lexer = @import("lexer.zig");
const Evaluator = @import("evaluator.zig").Evaluator;

/// Input Buffer size.
const buffer_size = 1024;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var tokenizer = lexer.Tokenizer.init(allocator);
    defer tokenizer.deinit();

    var eval = Evaluator.init(allocator, stdout, stderr);

    while (true) {
        // Print the prompt
        try stdout.print("$ ", .{});

        // Read the command line
        const stdin = std.io.getStdIn().reader();
        var buffer: [buffer_size]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        const tokens = try tokenizer.tokenize(user_input);

        try eval.evaluate(tokens);
    }
}
