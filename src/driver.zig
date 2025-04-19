const compile_with_gcc = true;

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var args_it = std.process.args();
    _ = args_it.skip();

    var option: ?Option = null;
    var output_assembly = false;
    var files: std.ArrayList([]const u8) = .init(allocator);

    while (args_it.next()) |arg| {
        const option_marker = "--";
        if (std.mem.startsWith(u8, arg, option_marker)) {
            option = parseOption(arg[option_marker.len..]) orelse return 1;
        } else if (std.mem.eql(u8, arg, "-S")) {
            output_assembly = true;
        } else {
            try files.append(arg);
        }
    }

    for (files.items) |file| {
        processFile(allocator, file, option) catch {
            return 1;
        };
    }

    return 0;
}

fn processFile(allocator: Allocator, filepath: []const u8, option: ?Option) !void {
    const preprocessed_file = try preprocessFile(allocator, filepath);

    const compiled_file = try compileFile(allocator, preprocessed_file, option);
    try std.fs.cwd().deleteFile(preprocessed_file);

    _ = try assembleAndLinkFile(allocator, compiled_file);
    try std.fs.cwd().deleteFile(compiled_file);
}

fn assembleAndLinkFile(allocator: Allocator, filepath: []const u8) ![]const u8 {
    const file_no_ext = removeFileExtention(filepath);

    const argv = &.{
        "gcc",
        filepath,
        "-o",
        file_no_ext,
    };

    var assembler = std.process.Child.init(argv, allocator);
    const assembler_result = try assembler.spawnAndWait();

    if (assembler_result.Exited != 0) {
        return error.AssemblerFailed;
    }

    return file_no_ext;
}

fn compileFile(allocator: Allocator, filepath: []const u8, option: ?Option) ![]const u8 {
    _ = option; // autofix
    if (compile_with_gcc) {
        return compileWithGcc(allocator, filepath);
    } else {
        const file_no_ext = removeFileExtention(filepath);
        const output = try std.mem.concat(allocator, u8, &.{ file_no_ext, ".s" });

        const argv = &.{
            "zig-out/bin/compiler",
            filepath,
        };

        var compiler = std.process.Child.init(argv, allocator);
        const compiler_result = try compiler.spawnAndWait();

        if (compiler_result.Exited != 0) {
            return error.CompilerFailed;
        }

        return output;
    }
}

fn compileWithGcc(allocator: Allocator, filepath: []const u8) ![]const u8 {
    const file_no_ext = removeFileExtention(filepath);
    const output = try std.mem.concat(allocator, u8, &.{ file_no_ext, ".s" });

    const argv = &.{
        "gcc",
        "-S",
        "-O",
        "-fno-asynchronous-unwind-tables",
        "-fcf-protection=none",
        filepath,
        "-o",
        output,
    };

    var compiler = std.process.Child.init(argv, allocator);
    const compiler_result = try compiler.spawnAndWait();

    if (compiler_result.Exited != 0) {
        return error.CompilerFailed;
    }

    return output;
}

fn preprocessFile(allocator: Allocator, filepath: []const u8) ![]const u8 {
    const file_no_ext = removeFileExtention(filepath);
    const output = try std.mem.concat(allocator, u8, &.{ file_no_ext, ".i" });

    const argv = &.{
        "gcc",
        "-E",
        "-P",
        filepath,
        "-o",
        output,
    };

    var preprocessor = std.process.Child.init(argv, allocator);
    const preprocessor_result = try preprocessor.spawnAndWait();

    if (preprocessor_result.Exited != 0) {
        return error.PreprocessorFailed;
    }

    return output;
}

const Option = enum {
    lex,
    parse,
    codegen,
};

fn parseOption(option: []const u8) ?Option {
    if (std.mem.eql(u8, option, "--lex")) {
        return .lex;
    } else if (std.mem.eql(u8, option, "--parse")) {
        return .parse;
    } else if (std.mem.eql(u8, option, "--codegen")) {
        return .codegen;
    } else {
        return null;
    }
}

fn removeFileExtention(filename: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, filename, '.') orelse return filename;
    return filename[0..dot];
}

const std = @import("std");
const Allocator = std.mem.Allocator;
