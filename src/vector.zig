const std = @import("std");
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();
var prng = std.Random.DefaultPrng.init(1234);
var rand = prng.random();

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn subtract(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vec3, factor: f32) Vec3 {
        return .{ .x = self.x * factor, .y = self.y * factor, .z = self.z * factor };
    }

    pub fn elementScale(self: Vec3, factor: Vec3) Vec3 {
        return .{ .x = self.x * factor.x, .y = self.y * factor.y, .z = self.z * factor.z };
    }

    pub fn distance(self: Vec3, other: Vec3) f32 {
        // euclidean distance
        return std.math.sqrt(std.math.pow(f32, self.x - other.x, 2) +
            std.math.pow(f32, self.y - other.y, 2) +
            std.math.pow(f32, self.z - other.z, 2));
    }

    pub fn lengthSq(self: Vec3) f32 {
        return std.math.pow(f32, self.x, 2) + std.math.pow(f32, self.y, 2) + std.math.pow(f32, self.z, 2);
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.y * other.z - self.z * other.y, .y = self.z * other.x - self.x * other.z, .z = self.x * other.y - self.y * other.z };
    }

    pub fn unit(self: Vec3) Vec3 {
        return self.scale(1 / self.distance(.{ .x = 0, .y = 0, .z = 0 }));
    }

    pub fn reflect(self: Vec3, normal: Vec3) Vec3 {
        return self.subtract(normal.scale(2 * self.dot(normal)));
    }

    pub fn refract(self: Vec3, normal: Vec3, eta_ratio: f32) Vec3 {
        const cos_theta = @min(normal.dot(self.scale(-1)), 1.0);
        const out_perp = self.add(normal.scale(cos_theta)).scale(eta_ratio);
        const out_para = normal.scale(-@sqrt(@abs(1.0 - out_perp.lengthSq())));
        return out_perp.add(out_para);
    }

    pub fn getColour(self: Vec3, allocator: std.mem.Allocator) ![]u8 {
        const r = linearToGamma(self.x);
        const g = linearToGamma(self.y);
        const b = linearToGamma(self.z);
        const clamp_r = std.math.clamp(r, 0.0, 1.0);
        const clamp_g = std.math.clamp(g, 0.0, 1.0);
        const clamp_b = std.math.clamp(b, 0.0, 1.0);
        return try std.fmt.allocPrint(allocator, "{d} {d} {d}", .{ @as(u8, @intFromFloat(clamp_r * 255.99)), @as(u8, @intFromFloat(clamp_g * 255.99)), @as(u8, @intFromFloat(clamp_b * 255.99)) });
    }

    pub fn randomColour() Vec3 {
        const r = std.Random.float(rand, f32);
        const g = std.Random.float(rand, f32);
        const b = std.Random.float(rand, f32);
        return Vec3.init(r * r, g * g, b * b);
    }

    pub fn randomNoRange() Vec3 {
        return .{ .x = std.Random.float(rand, f32), .y = std.Random.float(rand, f32), .z = std.Random.float(rand, f32) };
    }

    pub fn random(min: f32, max: f32) Vec3 {
        assert(max >= min);
        return .{ .x = std.Random.float(rand, f32) * (max - min) + min, .y = std.Random.float(rand, f32) * (max - min) + min, .z = std.Random.float(rand, f32) * (max - min) + min };
    }

    pub fn randomUnit() Vec3 {
        for (0..1000) |_| {
            const p = Vec3.random(-1.0, 1.0);
            const len_sq = p.dot(p);
            if (1e-60 < len_sq and len_sq <= 1.0) {
                return p.scale(1.0 / @sqrt(len_sq));
            }
        }
        @panic("Did not find unit vector within 1000 iterations");
    }

    pub fn randomUnitDisk() Vec3 {
        for (0..1000) |_| {
            const p = Vec3.init(std.Random.float(rand, f32) * 2 - 1, std.Random.float(rand, f32) * 2 - 1, 0);
            const len_sq = p.dot(p);
            if (1e-60 < len_sq and len_sq <= 1.0) {
                return p.scale(1.0 / @sqrt(len_sq));
            }
        }
        @panic("Did not find unit vector within 1000 iterations");
    }

    pub fn randomOnUnitHemisphere(normal: Vec3) Vec3 {
        const on_sphere = Vec3.randomUnit();
        if (on_sphere.dot(normal) > 0) {
            return on_sphere;
        } else {
            return on_sphere.scale(-1.0);
        }
    }
};

inline fn linearToGamma(lin_comp: f32) f32 {
    if (lin_comp > 0.0) {
        return @sqrt(lin_comp);
    }
    return 0.0;
}
