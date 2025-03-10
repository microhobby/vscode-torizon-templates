const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/libtoradex.zig"),
        .target = target,
        .optimize = optimize,
    });

    const binary = b.addExecutable(.{
        .name = "__change__",
        .root_source_file = b.path("src/main.zig"),
        // or (implicit LazyPath struct, w/ path field)
        // .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    binary.root_module.addImport("toradex", lib_mod);

    // build C and/or C++

    // Need use libc to C code build? uncomment below

    // binary.addIncludePath(b.path("myinclude"));
    // binary.addCSourceFile(.{ .file = b.path("src/main.c"), .flags = &.{ "-Wall", "-Wextra" } });
    // binary.addCSourceFiles(.{ .files = &.{ "foo.c", "bar.c" }, .flags = &.{ "-Wall", "-Wextra" } });

    // warning to mixing C and C++ code. Use same flags, but c++flags(exclusive) not working (e.g.: "-std=c++11")
    // binary.addCSourceFiles(.{ .files = &.{ "foo.cc", "bar.cc" }, .flags = &.{ "-Wall", "-Werror" } });

    // linking
    // binary.linklibC(); // get libc and c-stdlib
    // for C++
    // binary.linklibCpp(); // builtin llvm-libcxx/abi + libunwind (+ stl) + libc (avoid duplicate - no need linklibC())

    // copy binary from zig-cache to zig-out/bin [default]
    b.installArtifact(binary);

    // overwrite default output
    b.resolveInstallPrefix(b.fmt("zig-out/{s}/{s}", .{
        @tagName(binary.rootModuleTarget().cpu.arch),
        @tagName(optimize),
    }), .{});

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(binary);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc.`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", b.fmt("Run the {s} app", .{binary.name}));
    run_step.dependOn(&run_cmd.step);
}
