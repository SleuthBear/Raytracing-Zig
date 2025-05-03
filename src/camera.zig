const std = @import("std");
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const sf = @import("surface.zig");
const stdout = std.io.getStdOut().writer();
const cwd = std.fs.cwd();
var prng = std.Random.DefaultPrng.init(1234);
var rand = prng.random();
fn degToRad(deg: f32) f32 {
    return (deg / 360.0) * 2.0 * std.math.pi;
}

pub const Camera = struct {
    aspect_ratio: f32,
    image_width: u32,
    image_height: u32,
    center: Vec3,
    pixel00_loc: Vec3,
    pixel_delta_u: Vec3,
    pixel_delta_v: Vec3,
    max_depth: u16 = 50,
    ray_casts: u16 = 200,
    defocus_angle: f32 = 0,
    focus_dist: f32,
    defocus_disk_u: Vec3,
    defocus_disk_v: Vec3,
    pub fn init(image_width: u32, aspect_ratio: f32, vfov: f32, look_from: Vec3, look_at: Vec3, vup: Vec3, focus_dist: f32, defocus_angle: f32) Camera {
        // Set up viewport and camera
        const image_height: u32 = @max(1, @as(u32, @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio)));

        // Camera
        // const focal_length: f32 = look_from.subtract(look_at).distance(Vec3.init(0, 0, 0));
        const theta = degToRad(vfov);
        const h = @tan(theta / 2.0);
        const viewport_height: f32 = 2 * h * focus_dist;
        const viewport_width: f32 = viewport_height * @as(f32, @floatFromInt(image_width)) / @as(f32, @floatFromInt(image_height));
        const center = look_from;

        const w = look_from.subtract(look_at).unit();
        const u = w.cross(vup).unit();
        const v = u.cross(w);

        // Calculate horizontal and Vertical vectors down page
        const viewport_u = u.scale(viewport_width);
        const viewport_v = v.scale(-viewport_height);

        // Calculate horizontal and vertical delta vectors
        const pixel_delta_u = viewport_u.scale(1.0 / @as(f32, @floatFromInt(image_width)));
        const pixel_delta_v = viewport_v.scale(1.0 / @as(f32, @floatFromInt(image_height)));

        // Calculate upper left pixel location
        const viewport_upper_left = center.subtract(w.scale(focus_dist)).subtract(viewport_u.scale(0.5)).subtract(viewport_v.scale(0.5));
        const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

        const defocus_radius = focus_dist * @tan(degToRad(defocus_angle / 2.0));
        const defocus_disk_u = u.scale(defocus_radius);
        const defocus_disk_v = v.scale(defocus_radius);

        return .{
            .aspect_ratio = aspect_ratio,
            .image_width = image_width,
            .image_height = image_height,
            .center = center,
            .pixel00_loc = pixel00_loc,
            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,
            .defocus_disk_u = defocus_disk_u,
            .defocus_disk_v = defocus_disk_v,
            .focus_dist = focus_dist,
            .defocus_angle = @max(0.0, defocus_angle),
        };
    }

    pub fn render(self: Camera, allo: std.mem.Allocator, world: sf.SurfaceList) !void {
        const opt = std.Thread.Pool.Options{
            .n_jobs = 8,
            .allocator = allo,
        };
        var pool: std.Thread.Pool = undefined;
        try pool.init(opt);
        const file = try cwd.createFile("im.ppm", .{});
        defer file.close();
        const line_list = try allo.alloc([3]f32, self.image_height * self.image_width);
        defer allo.free(line_list);
        const fw = file.writer();
        const start_line = try std.fmt.allocPrint(allo, "P3 {d} {d} \n255\n", .{ self.image_width, self.image_height });
        defer allo.free(start_line);
        _ = try fw.write(start_line);
        // use a thread pool to process 1 line at a time. Add the result to an array of strings, in the correct position.
        for (0..self.image_height) |i| {
            try pool.spawn(processLine, .{ self, line_list, world, i });
        }
        pool.deinit();
        for (line_list) |line| {
            const col = Vec3.init(line[0], line[1], line[2]);
            _ = try fw.write(try col.getColour(allo));
            _ = try fw.write("\n");
        }
        _ = try stdout.writeAll("\n");
    }

    pub fn rayColour(ray: Ray, world: sf.SurfaceList, depth: u16) Vec3 {
        if (depth <= 0) {
            return Vec3.init(0, 0, 0);
        }
        if (world.hit(ray, 0.001, std.math.inf(f32))) |hit_point| {
            if (hit_point.mat.scatter(ray, hit_point)) |scatter_result| {
                return rayColour(scatter_result.ray, world, depth - 1).elementScale(scatter_result.attenuation);
            }
        }
        const a: f32 = 0.5 * (ray.dir.unit().y + 1.0);
        return Vec3.init(1, 1, 1).scale(1.0 - a).add(Vec3.init(0.5, 0.7, 1.0).scale(a));
    }

    pub fn getRay(self: Camera, i_f: f32, j_f: f32) Ray {
        const origin = self.defocusDiskSample();
        const offset_x = std.Random.float(rand, f32) - 0.5;
        const offset_y = std.Random.float(rand, f32) - 0.5;
        const pixel_sample = self.pixel00_loc.add(self.pixel_delta_u.scale(j_f + offset_x)).add(self.pixel_delta_v.scale(i_f + offset_y));
        return Ray.init(origin, pixel_sample.subtract(origin));
    }

    pub fn defocusDiskSample(self: Camera) Vec3 {
        const p = Vec3.randomUnitDisk();
        return self.center.add(self.defocus_disk_u.scale(p.x)).add(self.defocus_disk_v.scale(p.y));
    }

    pub fn processLine(self: Camera, line_list: [][3]f32, world: sf.SurfaceList, idx: usize) void {
        stdout.print("\rProcessing scanline {d}/{d}", .{ idx + 1, self.image_height }) catch {};
        const i_f = @as(f32, @floatFromInt(idx));
        for (0..self.image_width) |j| {
            const j_f = @as(f32, @floatFromInt(j));
            var pixel_colour = Vec3.init(0, 0, 0);
            for (0..self.ray_casts) |_| {
                const r = self.getRay(i_f, j_f);
                pixel_colour = pixel_colour.add(rayColour(r, world, self.max_depth));
            }
            pixel_colour = pixel_colour.scale(1.0 / @as(f32, @floatFromInt(self.ray_casts)));
            line_list[idx * self.image_width + j][0] = pixel_colour.x;
            line_list[idx * self.image_width + j][1] = pixel_colour.y;
            line_list[idx * self.image_width + j][2] = pixel_colour.z;
        }
    }
};
