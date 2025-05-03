const std = @import("std");
const assert = std.debug.assert;
const Vec3 = @import("vector.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;

pub const Hit = struct {
    pos: Vec3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    mat: Material,
    pub fn init(pos: Vec3, ray: Ray, outward_normal: Vec3, t: f32, mat: Material) Hit {
        const front_face = getFace(ray, outward_normal);
        const normal = getNormal(outward_normal, front_face);
        return .{ .pos = pos, .normal = normal, .t = t, .front_face = front_face, .mat = mat };
    }

    pub fn getFace(ray: Ray, outward_normal: Vec3) bool {
        return ray.dir.dot(outward_normal) < 0;
    }

    pub fn getNormal(outward_normal: Vec3, front_face: bool) Vec3 {
        if (front_face) {
            return outward_normal;
        } else {
            return outward_normal.scale(-1);
        }
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f32,
    mat: Material,
    pub fn init(center: Vec3, radius: f32, mat: Material) Sphere {
        assert(radius > 0);
        return .{ .center = center, .radius = radius, .mat = mat };
    }

    pub fn hit(self: Sphere, ray: Ray, t_min: f32, t_max: f32) ?Hit {
        assert(t_min >= 0);
        assert(t_max >= t_min);
        const oc = self.center.subtract(ray.ori);
        const a: f32 = ray.dir.dot(ray.dir); // equal to length squared
        const h = ray.dir.dot(oc);
        const c: f32 = oc.dot(oc) - self.radius * self.radius;
        const disc: f32 = h * h - a * c;
        // Hits or or two times, return true.
        if (disc < 0) {
            return null;
        }
        const sqrtd: f32 = @sqrt(disc);

        // Find nearest acceptable root.
        var root = (h - sqrtd) / a;
        if ((root <= t_min) or (t_max <= root)) {
            root = (h + sqrtd) / a;
            if ((root <= t_min) or (t_max <= root)) {
                return null;
            }
        }
        const pos = ray.at(root);
        return Hit.init(pos, ray, pos.subtract(self.center).scale(1.0 / self.radius), root, self.mat);
    }
};

pub const SurfaceType = union(enum) {
    sphere: Sphere,
    pub fn hit(self: SurfaceType, ray: Ray, t_min: f32, t_max: f32) ?Hit {
        return switch (self) {
            .sphere => |s| s.hit(ray, t_min, t_max),
        };
    }
};

pub const SurfaceList = struct {
    list: std.ArrayList(SurfaceType),
    pub fn init(allo: std.mem.Allocator) SurfaceList {
        return .{ .list = std.ArrayList(SurfaceType).init(allo) };
    }

    pub fn hit(self: SurfaceList, ray: Ray, t_min: f32, t_max: f32) ?Hit {
        var closest = t_max;
        var closest_hit: ?Hit = null;
        for (self.list.items) |surface| {
            if (surface.hit(ray, t_min, closest)) |value| {
                closest = value.t;
                closest_hit = value;
            }
        }
        return closest_hit;
    }
};
