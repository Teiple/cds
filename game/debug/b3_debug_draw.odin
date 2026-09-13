package debug
import utils "../utils"
import b3 "vendor:box3d"
import rl "vendor:raylib"


color_from_hex :: proc "c" (hex: b3.HexColor, alpha: f32 = 1.0) -> rl.Color {
	r := u8((u32(hex) >> 16) & 0xFF)
	g := u8((u32(hex) >> 8) & 0xFF)
	b := u8(u32(hex) & 0xFF)
	return {r, g, b, u8(alpha * 255)}
}

debug_draw_segment :: proc "c" (p1, p2: b3.Pos, color: b3.HexColor, ctx: rawptr) {
	c := color_from_hex(color)
	rl.DrawLine3D(p1, p2, c)
}

debug_draw_box :: proc "c" (extents: b3.Vec3, transform: b3.WorldTransform, color: b3.HexColor, ctx: rawptr) {
	c := color_from_hex(color)

	if utils.draw_push_gl_transform(transform.p, transform.q) {
		rl.DrawCubeWires({0, 0, 0}, extents.x * 2, extents.y * 2, extents.z * 2, c)
	}
}

debug_draw_sphere :: proc "c" (p: b3.Pos, radius: f32, color: b3.HexColor, alpha: f32, ctx: rawptr) {
	c := color_from_hex(color, alpha)
	rl.DrawSphereWires(p, radius, 8, 8, c)
}

debug_draw_bounds :: proc "c" (aabb: b3.AABB, color: b3.HexColor, ctx: rawptr) {
	c := color_from_hex(color)
	center := (aabb.lowerBound + aabb.upperBound) * 0.5
	size := aabb.upperBound - aabb.lowerBound
	rl.DrawCubeWires(center, size.x, size.y, size.z, c)
}

make_b3_debug_draw :: proc() -> b3.DebugDraw {
	return b3.DebugDraw {
		DrawSegmentFcn = debug_draw_segment,
		DrawBoxFcn = debug_draw_box,
		DrawSphereFcn = debug_draw_sphere,
		DrawBoundsFcn = debug_draw_bounds,
		drawShapes = true,
		drawBounds = false,
		drawContacts = true,
		drawingBounds = {lowerBound = {-100, -100, -100}, upperBound = {100, 100, 100}},
	}
}
