const std = @import("std");
const Vec3 = @import("vector.zig").Vec3;
pub const Ray = struct {
    ori: Vec3,
    dir: Vec3,
    pub fn init(ori: Vec3, dir: Vec3) Ray {
        return .{ .ori = ori, .dir = dir };
    }

    pub fn at(self: Ray, t: f32) Vec3 {
        return self.ori.add(self.dir.scale(t));
    }

    // Return copy of the origin
    pub fn oriCopy(self: Ray) Vec3 {
        return Vec3.init(self.ori.x, self.ori.y, self.ori.z);
    }

    // Return copy of the direction
    pub fn dirCopy(self: Ray) Vec3 {
        return Vec3.init(self.dir.x, self.dir.y, self.dir.z);
    }

    pub fn colour(self: Ray) Vec3 {
        const unit_dir = self.dir.scale(1.0 / self.dir.distance(.{ .x = 0, .y = 0, .z = 0 }));
        const a = 0.5 * (unit_dir.y + 1);
        return Vec3.init(1, 1, 1).scale(1.0 - a).add(Vec3.init(0.5, 0.7, 1).scale(a));
    }
};
