const std = @import("std");
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vector.zig").Vec3;
const sf = @import("surface.zig");
var prng = std.Random.DefaultPrng.init(1234);
var rand = prng.random();

pub const ScatterResult = struct {
    ray: Ray,
    attenuation: Vec3,
};

pub const Material = union(enum) {
    metal: Metal,
    lambertian: Lambertian,
    dielectric: Dielectric,
    pub fn scatter(self: Material, ray: Ray, hit: sf.Hit) ?ScatterResult {
        return switch (self) {
            .metal => |m| m.scatter(ray, hit),
            .lambertian => |l| l.scatter(hit),
            .dielectric => |d| d.scatter(ray, hit),
        };
    }
};

pub const Metal = struct {
    // Lambertian Metal Material
    albedo: Vec3,
    fuzz: f32,

    pub fn scatter(self: Metal, ray: Ray, hit: sf.Hit) ?ScatterResult {
        var reflected = ray.dir.reflect(hit.normal);
        reflected = reflected.unit().add(Vec3.randomUnit().scale(self.fuzz));
        if (reflected.dot(hit.normal) > 0) {
            return .{ .attenuation = self.albedo, .ray = Ray.init(hit.pos, reflected) };
        }
        return null;
    }
};

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn scatter(self: Lambertian, hit: sf.Hit) ?ScatterResult {
        var scatter_dir = hit.normal.add(Vec3.randomUnit());
        if (scatter_dir.dot(scatter_dir) < 0.001) {
            scatter_dir = hit.normal;
        }
        return .{ .attenuation = self.albedo, .ray = Ray.init(hit.pos, scatter_dir) };
    }
};

pub const Dielectric = struct {
    ref_ind: f32,

    pub fn scatter(self: Dielectric, ray: Ray, hit: sf.Hit) ?ScatterResult {
        var ri: f32 = undefined;
        if (hit.front_face) {
            ri = 1.0 / self.ref_ind;
        } else {
            ri = self.ref_ind;
        }
        const unit_dir = ray.dir.unit();
        const cos_theta = @min(hit.normal.dot(unit_dir.scale(-1)), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
        var dir: Vec3 = undefined;
        const cannot_refract = ri * sin_theta > 1.0;
        if (cannot_refract or reflectance(cos_theta, ri) > std.Random.float(rand, f32)) {
            // total internal reflection
            dir = unit_dir.reflect(hit.normal);
        } else {
            dir = unit_dir.refract(hit.normal, ri);
        }
        return .{ .attenuation = Vec3.init(1.0, 1.0, 1.0), .ray = Ray.init(hit.pos, dir) };
    }

    pub fn reflectance(cos: f32, ri: f32) f32 {
        var r0 = (1 - ri) / (1 + ri);
        r0 = r0 * r0;
        return r0 + (1 - r0) * std.math.pow(f32, (1 - cos), 5);
    }
};
