const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("llrbtree-zig", "src/lib.zig");
    lib.setBuildMode(mode);
    deps.addAllTo(lib);
    lib.install();

    const exe = b.addExecutable("llrbtree-example", "src/main.zig");
    exe.setBuildMode(mode);
    deps.addAllTo(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the example app using library");
    run_step.dependOn(&run_cmd.step);

    const lib_tests = b.addTest("src/lib.zig");
    lib_tests.setBuildMode(mode);
    deps.addAllTo(lib_tests);

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    deps.addAllTo(main_tests);

    const docs = b.addTest("src/lib.zig");
    docs.setBuildMode(mode);
    docs.emit_docs = .emit;
    deps.addAllTo(docs);

    const lib_step = b.step("lib", "Build static library");
    lib_step.dependOn(&lib.step);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);
    test_step.dependOn(&main_tests.step);

    const doc_step = b.step("doc", "Generate docs");
    doc_step.dependOn(&docs.step);
}
