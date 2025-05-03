const std = @import("std");

const pa = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const sf = @import("surface.zig");
const Camera = @import("camera.zig").Camera;
const mat = @import("material.zig");
var prng = std.Random.DefaultPrng.init(1234);
var rand = prng.random();

pub fn main() !void {
    const look_from = Vec3.init(13.0, 2.0, 1.0);
    const look_at = Vec3.init(0, 0, 0);
    const vup = Vec3.init(0, 1, 0);
    const camera = Camera.init(600, 16.0 / 9.0, 20.0, look_from, look_at, vup, 10, 0.6);
    const mat_ground = mat.Material{ .lambertian = mat.Lambertian{ .albedo = Vec3.init(0.5, 0.5, 0.5) } };

    // Set up world objects:w
    var world = sf.SurfaceList.init(pa);
    try world.list.append(.{ .sphere = sf.Sphere.init(.{ .x = 0, .y = -1000, .z = 0 }, 1000, mat_ground) });

    const anchor = Vec3.init(4, 0.2, 0);
    for (0..22) |i| {
        const i_f = @as(f32, @floatFromInt(i)) - 11.0;
        for (0..22) |j| {
            const j_f = @as(f32, @floatFromInt(j)) - 11.0;
            const choose_mat = std.Random.float(rand, f32);
            const pos = Vec3.init(i_f + 0.9 * std.Random.float(rand, f32), 0.2, j_f + 0.9 * std.Random.float(rand, f32));

            if (pos.distance(anchor) > 0.9) {
                if (choose_mat < 0.8) {
                    const albedo = Vec3.randomColour();
                    const sphere_mat = mat.Material{ .lambertian = mat.Lambertian{ .albedo = albedo } };
                    try world.list.append(.{ .sphere = sf.Sphere.init(pos, 0.2, sphere_mat) });
                } else if (choose_mat < 0.95) {
                    const albedo = Vec3.randomColour();
                    const fuzz = std.Random.float(rand, f32) / 2.0;
                    const sphere_mat = mat.Material{ .metal = mat.Metal{ .albedo = albedo, .fuzz = fuzz } };
                    try world.list.append(.{ .sphere = sf.Sphere.init(pos, 0.2, sphere_mat) });
                } else {
                    const sphere_mat = mat.Material{ .dielectric = mat.Dielectric{ .ref_ind = 1.5 } };
                    try world.list.append(.{ .sphere = sf.Sphere.init(pos, 0.2, sphere_mat) });
                }
            }
        }
        const mat1 = mat.Material{ .dielectric = mat.Dielectric{ .ref_ind = 1.5 } };
        try world.list.append(.{ .sphere = sf.Sphere.init(Vec3.init(0, 1, 0), 1.0, mat1) });

        const mat2 = mat.Material{ .lambertian = mat.Lambertian{ .albedo = Vec3.init(0.4, 0.2, 0.1) } };
        try world.list.append(.{ .sphere = sf.Sphere.init(Vec3.init(-4, 1, 0), 1.0, mat2) });

        const mat3 = mat.Material{ .metal = mat.Metal{ .albedo = Vec3.init(0.7, 0.6, 0.5), .fuzz = 0.0 } };
        try world.list.append(.{ .sphere = sf.Sphere.init(Vec3.init(0, 1, 0), 1.0, mat3) });
    }
    // Render
    try camera.render(pa, world);
}
