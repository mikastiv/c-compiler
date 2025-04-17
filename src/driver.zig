const compile_with_gcc = true;

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var args_it = std.process.args();
    _ = args_it.next();

    while (args_it.next()) |arg| {
        processFile(allocator, arg) catch {
            return 1;
        };
    }

    return 0;
}

fn processFile(allocator: Allocator, filepath: []const u8) !void {
    const preprocessed_file = try preprocessFile(allocator, filepath);

    const compiled_file = try compileFile(allocator, preprocessed_file);
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

fn compileFile(allocator: Allocator, filepath: []const u8) ![]const u8 {
    if (compile_with_gcc)
        return compileWithGcc(allocator, filepath)
    else
        @panic("unimplemented");
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

fn removeFileExtention(filepath: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, filepath, '.') orelse return filepath;
    return filepath[0..dot];
}

const std = @import("std");
const Allocator = std.mem.Allocator;
