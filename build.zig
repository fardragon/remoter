const std = @import("std");
const builtin = @import("builtin");
const Feature = @import("std").Target.Cpu.Feature;

pub fn build(b: *std.Build) !void {
    var features = Feature.Set.empty;
    features.addFeature(@intFromEnum(std.Target.aarch64.Feature.strict_align));

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
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
    });

    elf.addAssemblyFile(b.path("src/entry.S"));
    elf.setLinkerScriptPath(b.path("src/link.ld"));

    const copy_elf = b.addInstallArtifact(elf, .{});
    b.getInstallStep().dependOn(&copy_elf.step);

    const run_objcopy = b.addObjCopy(elf.getEmittedBin(), .{
        .basename = "kernel8.img",
        .format = std.Build.Step.ObjCopy.RawFormat.bin,
    });

    const copy_image = b.addInstallFile(run_objcopy.getOutputSource(), "kernel8.img");
    b.getInstallStep().dependOn(&copy_image.step);

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
        "-append",
        "\"console=ttyAMA0 root=/dev/mmcblk0p2 rw rootwait rootfstype=ext4\"",
    });

    const run_qemu = b.addSystemCommand(qemu_args.items);
    run_qemu.step.dependOn(&copy_image.step);
    run_qemu.step.dependOn(&copy_elf.step);

    const run_qemu_debug = b.addSystemCommand(qemu_args.items);
    run_qemu_debug.step.dependOn(&copy_image.step);
    run_qemu_debug.step.dependOn(&copy_elf.step);

    run_qemu_debug.addArg("-S");
    run_qemu_debug.addArg("-s");

    const qemu = b.step("qemu", "Run remoter in QEMU");
    qemu.dependOn(&run_qemu.step);

    const qemu_debug = b.step("qemu_debug", "Debug remoter in QEMU");
    qemu_debug.dependOn(&run_qemu_debug.step);
}
