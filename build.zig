const std = @import("std");
const builtin = @import("builtin");
const Feature = @import("std").Target.Cpu.Feature;

pub fn build(b: *std.build.Builder) void {
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

    const exe = b.addExecutable(.{
        .name = "remoter",
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addAssemblyFileSource(.{ .path = "src/entry.S" });
    exe.setLinkerScriptPath(.{ .path = "src/link.ld" });

    b.installArtifact(exe);
}
