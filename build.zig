const std = @import("std");
const builtin = @import("builtin");
const Feature = @import("std").Target.Cpu.Feature;

pub fn build(b: *std.build.Builder) !void {
    var features = Feature.Set.empty;
    features.addFeature(@enumToInt(std.Target.aarch64.Feature.strict_align));

    const target = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a53 },
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_features_add = features,
    };

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const elf = b.addExecutable(.{
        .name = "remoter",
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    elf.addAssemblyFileSource(.{ .path = "src/entry.S" });
    elf.setLinkerScriptPath(.{ .path = "src/link.ld" });

    b.installArtifact(elf);

    const run_objcopy = b.addObjCopy(elf.getOutputSource(), .{
        .basename = "kernel8.img",
        .format = std.build.ObjCopyStep.RawFormat.bin,
    });

    const copy_image = b.addInstallFile(run_objcopy.getOutputSource(), "kernel8.img");

    const image = b.step("image", "test");
    image.dependOn(&copy_image.step);

    var qemu_args = std.ArrayList([]const u8).init(b.allocator);
    try qemu_args.appendSlice(&[_][]const u8{
        "qemu-system-aarch64",
        "-kernel",
        "zig-out/kernel8.img",
        "-M",
        "raspi3b",
        "-serial",
        "mon:stdio",
        "-dtb",
        "bcm2710-rpi-3-b-plus.dtb",
    });

    const run_qemu = b.addSystemCommand(qemu_args.items);
    run_qemu.step.dependOn(&copy_image.step);

    const run_qemu_debug = b.addSystemCommand(qemu_args.items);
    run_qemu_debug.step.dependOn(&copy_image.step);
    run_qemu_debug.addArg("-S");
    run_qemu_debug.addArg("-s");

    const qemu = b.step("qemu", "Run remoter in QEMU");
    qemu.dependOn(&run_qemu.step);

    const qemu_debug = b.step("qemu_debug", "Debug remoter in QEMU");
    qemu_debug.dependOn(&run_qemu_debug.step);
}
