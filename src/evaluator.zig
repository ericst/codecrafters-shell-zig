const std = @import("std");
const lexer = @import("lexer.zig");

const Writer = std.fs.File.Writer;
const Tokens = *std.ArrayList(lexer.Token);

pub const BuiltinFn = *const fn (self: *Evaluator, Tokens) anyerror!void;

pub const Evaluator = struct {
    builtins: std.StringHashMap(BuiltinFn),
    allocator: std.mem.Allocator,
    stdout: Writer,
    stderr: Writer,

    pub fn init(allocator: std.mem.Allocator, stdout: Writer, stderr: Writer) Evaluator {
        var result = Evaluator{
            .builtins = std.StringHashMap(BuiltinFn).init(allocator),
            .allocator = allocator,
            .stdout = stdout,
            .stderr = stderr,
        };

        result.registerBuiltins() catch {
            @panic("Couldn't register the builtins...");
        };

        return result;
    }

    pub fn deinit(self: *Evaluator) void {
        self.builtins.deinit();
    }

    // Register our builtin commands
    pub fn registerBuiltins(self: *Evaluator) !void {
        try self.builtins.put("exit", exit);
        try self.builtins.put("echo", echo);
        try self.builtins.put("type", typeBuiltin);
        // Add more builtins here
    }

    pub fn evaluate(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len == 0) return;

        // Get the command name from the first token
        const cmd = tokens.items[0].lexeme;

        // Look up in builtins
        if (self.builtins.get(cmd)) |builtin| {
            try builtin(self, tokens);
        } else {
            try self.stderr.print("{s}: command not found\n", .{cmd});
        }
    }

    // Builtins implementations

    fn exit(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len <= 1) {
            std.process.exit(0);
        } else if (tokens.items.len > 2) {
            try self.stderr.print("error: exit takes 0 or 1 argument.\n", .{});
            return;
        } else {
            const lexeme = tokens.items[1].lexeme;
            const exit_code = std.fmt.parseInt(u8, lexeme, 10) catch {
                try self.stderr.print("error: {s} is not a number between 0 and 255\n", .{lexeme});
                return;
            };
            std.process.exit(exit_code);
        }
    }

    fn echo(self: *Evaluator, tokens: Tokens) !void {
        for (tokens.items[1..]) |token| {
            try self.stdout.print("{s} ", .{token.lexeme});
        }
        try self.stdout.print("\n", .{});
    }

    fn typeBuiltin(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len <= 1 or tokens.items.len > 2) {
            try self.stderr.print("error: type takes exactly 1 argument.\n", .{});
        } else {
            const parameter = tokens.items[1].lexeme;

            if (self.builtins.get(parameter)) |_| {
                try self.stdout.print("{s} is a shell builtin\n", .{parameter});
            } else {
                try self.stdout.print("{s}: not found\n", .{parameter});
            }
        }
    }
};
