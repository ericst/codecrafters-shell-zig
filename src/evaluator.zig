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
    path: std.ArrayList([]const u8),
    full_path: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, stdout: Writer, stderr: Writer) Evaluator {
        var result = Evaluator{
            .builtins = std.StringHashMap(BuiltinFn).init(allocator),
            .allocator = allocator,
            .stdout = stdout,
            .stderr = stderr,
            .path = std.ArrayList([]const u8).init(allocator),
            .full_path = std.ArrayList(u8).init(allocator),
        };

        // Populate the Builtins
        result.registerBuiltins() catch {
            @panic("Couldn't register the builtins...");
        };

        result.loadPath() catch {
            @panic("Problem loading the path");
        };

        return result;
    }

    pub fn deinit(self: *Evaluator) void {
        self.builtins.deinit();
        self.path.deinit();
        self.full_path.deinit();
    }

    pub fn evaluate(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len == 0) return;

        // Get the command name from the first token
        const cmd = tokens.items[0].lexeme;

        // Look up in builtins
        if (self.builtins.get(cmd)) |builtin| {
            try builtin(self, tokens);
        } else if (self.getCommandPath(cmd)) |_| {
            var argv = std.ArrayList([]const u8).init(self.allocator);
            for (tokens.items) |item| {
                try argv.append(item.lexeme);
            }

            var child = std.process.Child.init(argv.items, self.allocator);

            child.spawn() catch |err| {
                try self.stderr.print("error: {s}\n", .{@errorName(err)});
            };

            _ = child.wait() catch |err| {
                try self.stderr.print("error: {s}\n", .{@errorName(err)});
            };
        } else {
            try self.stderr.print("{s}: command not found\n", .{cmd});
        }
    }

    fn registerBuiltins(self: *Evaluator) !void {
        try self.builtins.put("exit", exit);
        try self.builtins.put("echo", echo);
        try self.builtins.put("type", typeBuiltin);
        try self.builtins.put("pwd", pwd);
        try self.builtins.put("cd", cd);
    }

    fn loadPath(self: *Evaluator) !void {
        if (std.posix.getenv("PATH")) |raw_path| {
            var iter = std.mem.splitScalar(u8, raw_path, ':');
            while (iter.next()) |dir| {
                try self.path.append(dir);
            }
        }
    }

    fn getCommandPath(self: *Evaluator, command: []const u8) ?[]const u8 {
        for (self.path.items) |dir| {
            self.full_path.clearRetainingCapacity();

            self.full_path.appendSlice(dir) catch continue;
            self.full_path.append('/') catch continue;
            self.full_path.appendSlice(command) catch continue;

            const file = std.fs.openFileAbsolute(self.full_path.items, .{ .mode = .read_only }) catch {
                continue;
            };
            defer file.close();

            const mode = file.mode() catch {
                continue;
            };

            const is_executable = mode & 0b001 != 0;

            if (is_executable) {
                return self.full_path.items;
            }
        }

        return null;
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
            } else if (self.getCommandPath(parameter)) |path| {
                try self.stdout.print("{s} is {s}\n", .{ parameter, path });
            } else {
                try self.stdout.print("{s}: not found\n", .{parameter});
            }
        }
    }

    fn pwd(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len > 1) {
            try self.stderr.print("error: pwd takes no arguments", .{});
        }

        var buffer: [1024]u8 = undefined;

        const wd = try std.posix.getcwd(&buffer);

        try self.stdout.print("{s}\n", .{wd});
    }

    fn cd(self: *Evaluator, tokens: Tokens) !void {
        if (tokens.items.len != 2) {
            try self.stderr.print("error: cd takes exactly 1 argument", .{});
        }

        const dir = tokens.items[1].lexeme;

        std.posix.chdir(dir) catch |err| {
            switch (err) {
                error.FileNotFound => try self.stderr.print("cd: {s}: No such file or directory\n", .{dir}),
                else => try self.stderr.print("error: {s}\n", .{@errorName(err)}),
            }
        };
    }
};
