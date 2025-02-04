const std = @import("std");

/// The different token types
pub const TokenType = enum {
    word,
    unknown,
};

/// Represents a token.
pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

/// The tokenizer is responsible for transforming a string into tokens.
pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator) Tokenizer {
        return .{
            .tokens = std.ArrayList(Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokens.deinit();
    }

    pub fn tokenize(self: *Tokenizer, line: []const u8) !*std.ArrayList(Token) {
        self.tokens.clearRetainingCapacity();

        var iter = std.mem.splitAny(u8, line, " \t\n");
        while (iter.next()) |word| {
            try self.tokens.append(Token{
                .kind = .word,
                .lexeme = word,
            });
        }

        return &self.tokens;
    }
};
