pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var args_it = std.process.args();
    _ = args_it.skip();

    const filepath = args_it.next() orelse return 1;

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try file.readToEndAllocOptions(allocator, std.math.maxInt(i32), stat.size, @alignOf(u8), 0);

    var lexer: Lexer = .init(content);
    var tokens: std.ArrayList(Token) = .init(allocator);
    while (true) {
        const token = lexer.next();
        try tokens.append(token);

        if (token.type == .eof) break;
    }

    for (tokens.items) |token| {
        std.debug.print("{any}\n", .{token});
    }

    return 0;
}

const Lexer = struct {
    buffer: [:0]const u8,
    index: usize,

    const State = enum {
        start,
        identifier,
        constant,
        invalid,
    };

    fn init(data: [:0]const u8) Lexer {
        return .{
            .buffer = data,
            .index = 0,
        };
    }

    fn next(self: *Lexer) Token {
        var result: Token = .{
            .type = undefined,
            .start = self.index,
            .end = undefined,
        };

        state: switch (State.start) {
            .start => {
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index >= self.buffer.len) {
                            return .{
                                .type = .eof,
                                .start = self.index,
                                .end = self.index,
                            };
                        } else {
                            continue :state .invalid;
                        }
                    },
                    ' ', '\n', '\t', '\r', std.ascii.control_code.vt, std.ascii.control_code.ff => {
                        self.index += 1;
                        result.start = self.index;
                        continue :state .start;
                    },
                    'A'...'Z', 'a'...'z', '_' => {
                        result.type = .identifier;
                        self.index += 1;
                        continue :state .identifier;
                    },
                    '0'...'9' => {
                        result.type = .constant;
                        self.index += 1;
                        continue :state .constant;
                    },
                    '(' => {
                        result.type = .l_paren;
                        self.index += 1;
                    },
                    ')' => {
                        result.type = .r_paren;
                        self.index += 1;
                    },
                    '{' => {
                        result.type = .l_brace;
                        self.index += 1;
                    },
                    '}' => {
                        result.type = .r_brace;
                        self.index += 1;
                    },
                    ';' => {
                        result.type = .semicolon;
                        self.index += 1;
                    },
                    else => {
                        continue :state .invalid;
                    },
                }
            },
            .identifier => switch (self.buffer[self.index]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                    self.index += 1;
                    continue :state .identifier;
                },
                else => {
                    const ident = self.buffer[result.start..self.index];
                    if (Token.identifier_strings.get(ident)) |keyword| {
                        result.type = keyword;
                    }
                },
            },
            .constant => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    continue :state .constant;
                },
                else => {},
            },
            .invalid => {
                result.type = .invalid;
            },
        }

        result.end = self.index;

        return result;
    }
};

const Token = struct {
    type: Type,
    start: usize,
    end: usize,

    const Type = enum {
        invalid,
        identifier,
        constant,
        keyword_int,
        keyword_void,
        keyword_return,
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        semicolon,
        eof,
    };

    const identifier_strings: std.StaticStringMap(Type) = .initComptime(
        .{
            .{ "int", .keyword_int },
            .{ "void", .keyword_void },
            .{ "return", .keyword_return },
        },
    );
};

const std = @import("std");
