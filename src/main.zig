const std = @import("std");

/// Input Buffer ziye
const buffer_size = 1024;

const Command = enum { invalid_command, exit, echo, type };

const CommandLine = struct {
    command: Command,
    args: []const u8,

    pub fn init(input: []const u8) CommandLine {
        var command: Command = Command.invalid_command;

        var iter = std.mem.splitScalar(u8, input, ' ');
        const c = iter.first();
        if (std.mem.eql(u8, c, "exit")) {
            command = Command.exit;
        } else if (std.mem.eql(u8, c, "echo")) {
            command = Command.echo;
        } else if (std.mem.eql(u8, c, "type")) {
            command = Command.type;
        }

        return CommandLine{
            .command = command,
            .args = iter.rest(),
        };
    }
};

fn builtinExit(command_line: CommandLine) !void {
    if (command_line.args.len == 0) {
        std.process.exit(0);
    } else {
        const exit_code = try std.fmt.parseInt(u8, command_line.args, 10);
        std.process.exit(exit_code);
    }
}

fn builtinEcho(command_line: CommandLine) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{command_line.args});
}

fn builtinType(command_line: CommandLine) !void {
    const stdout = std.io.getStdOut().writer();

    const parameter = CommandLine.init(command_line.args);

    switch (parameter.command) {
        .exit, .echo, .type => try stdout.print("{s} is a shell builtin\n", .{command_line.args}),
        .invalid_command => try stdout.print("{s}: not found\n", .{command_line.args}),
    }
}

pub fn main() !void {
    std.process.exit(255);
    while (true) {
        const stderr = std.io.getStdErr().writer();
        const stdout = std.io.getStdOut().writer();

        // Print the prompt
        try stdout.print("$ ", .{});

        // Read the command line
        const stdin = std.io.getStdIn().reader();
        var buffer: [buffer_size]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');
        const command_line = CommandLine.init(user_input);

        // Process the command
        switch (command_line.command) {
            .exit => try builtinExit(command_line),
            .echo => try builtinEcho(command_line),
            .type => try builtinType(command_line),
            .invalid_command => try stderr.print("{s}: command not found\n", .{user_input}),
        }
    }
}
